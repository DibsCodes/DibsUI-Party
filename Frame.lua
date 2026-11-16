local _, ns = ...

local Layout = ns.Layout

-- Health, power, heal and absorb amounts can be secret. They only ever go straight into widgets or
-- curve calls: never compared, added up or tested in Lua. (DibsUI's rule.)
local SMOOTH = Enum.StatusBarInterpolation.ExponentialEaseOut
local IMMEDIATE = Enum.StatusBarInterpolation.Immediate

-- Alpha 0 at empty and 1 above it, so an empty bar shows no sliver of its slanted cap.
local VISIBLE_ABOVE_ZERO = C_CurveUtil.CreateCurve()
VISIBLE_ABOVE_ZERO:SetType(Enum.LuaCurveType.Step)
VISIBLE_ABOVE_ZERO:AddPoint(0, 0)
VISIBLE_ABOVE_ZERO:AddPoint(0.001, 1)

-- DibsUI's prediction colors: heals are the bar's color mixed toward the backing, absorbs are blue.
local HEAL_SHADE = 0.4
local BACKING = { 0.075, 0.09, 0.125 }
local ABSORB_COLOR = { 0.35, 0.72, 1.00 }
local GLOW_COLOR = CreateColor(1, 1, 1, 1)
local CLEAR = CreateColor(0, 0, 0, 0)
local MASK_REACH = 32 -- DibsUI's generate_art.py MASK_REACH

local OUT_OF_RANGE_ALPHA = 0.3 -- in range is full
local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"

-- Bars -----------------------------------------------------------------------------------------------

local function SetBarColor(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b)
	bar.cap:SetVertexColor(r, g, b)
	if bar.wedge then
		bar.wedge:SetVertexColor(r, g, b)
	end
	local heal = bar.heal
	if heal then
		r = r + (BACKING[1] - r) * HEAL_SHADE
		g = g + (BACKING[2] - g) * HEAL_SHADE
		b = b + (BACKING[3] - b) * HEAL_SHADE
		heal:SetStatusBarColor(r, g, b)
		heal.cap:SetVertexColor(r, g, b)
	end
end

local function CreateFillCap(bar, spec)
	local fill = bar:GetStatusBarTexture()
	local cap = ns.CreateArt(bar, "ARTWORK", "BarFillCap")
	cap:SetWidth(spec.capWidth)
	cap:SetPoint("TOPLEFT", fill, "TOPRIGHT")
	cap:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
	bar.cap = cap
end

-- The bar art is cut in three, as in DibsUI, so the width setting only stretches the straight middle and
-- keeps the slanted ends and double border in shape. Distances from the texture's start.
local function CreateArtSlices(parent, layer, fileName)
	local art = Layout.barArt
	local ranges = {
		{ 0, art.sliceInner },
		{ art.sliceInner, art.sliceInner + 4 }, -- a narrow band that only ever stretches
		{ art.sliceTip, art.width },
	}
	local slices = {}
	for i, range in ipairs(ranges) do
		local slice = ns.CreateArt(parent, layer, fileName)
		slice:SetTexCoord(range[1] / art.width, range[2] / art.width, 0, 1)
		slices[i] = slice
	end
	return slices
end

local function LayoutArtSlices(slices, origin, spec, growth)
	local art = Layout.barArt
	local edges = { 0, art.sliceInner, art.sliceTip + growth, art.width + growth }
	for i, slice in ipairs(slices) do
		slice:SetSize(edges[i + 1] - edges[i], spec.quadHeight)
		slice:ClearAllPoints()
		slice:SetPoint("LEFT", origin, "CENTER", edges[i], spec.yCenter)
	end
end

-- How much longer the Width setting makes a bar, in frame units. Negative means shorter.
function ns.GetBarGrowth(spec)
	return (ns.db.width - 1) * (spec.fillOuter - spec.fillInner)
end

-- Where a bar's tip reaches from the orb centre, with the Width setting.
function ns.GetBarTip(spec)
	return spec.tip + ns.GetBarGrowth(spec)
end

-- Applies the Width setting to a bar: its outline, art, fill and prediction.
local function LayoutBar(barObject)
	local spec, origin = barObject.spec, barObject.origin
	local growth = ns.GetBarGrowth(spec)
	barObject.body:SetSize(spec.tip + growth - spec.hitInner, spec.height)
	LayoutArtSlices(barObject.backSlices, origin, spec, growth)
	LayoutArtSlices(barObject.frameSlices, origin, spec, growth)
	local fillWidth = spec.fillOuter + growth - spec.fillInner
	barObject.bar:SetSize(fillWidth, spec.fillHeight)
	local prediction = barObject.prediction
	if prediction then
		prediction.heal:SetWidth(fillWidth)
		prediction.absorb:SetWidth(fillWidth)
	end
end

-- One of DibsUI's right wing bars, drawn from the orb centre (origin). The art and fill are on body, a
-- plain frame at the bar's outline, which takes the given frame level.
local function CreateBar(parent, origin, spec, level)
	local body = CreateFrame("Frame", nil, parent)
	body:SetFrameLevel(level)
	body:SetPoint("LEFT", origin, "CENTER", spec.hitInner, spec.yCenter)

	local backSlices = CreateArtSlices(body, "BACKGROUND", spec.back)

	local bar = CreateFrame("StatusBar", nil, body)
	bar:SetFrameLevel(level + 3)
	bar:SetStatusBarTexture(ns.Media("BarFill"))
	bar:SetFillStyle(Enum.StatusBarFillStyle.StandardNoRangeFill)
	bar:SetPoint("LEFT", origin, "CENTER", spec.fillInner, spec.yCenter)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	CreateFillCap(bar, spec)

	if spec.wedgeWidth then
		local wedge = ns.CreateArt(bar, "ARTWORK", spec.wedgeArt)
		wedge:SetWidth(spec.wedgeWidth)
		wedge:SetPoint("TOPRIGHT", bar, "TOPLEFT")
		wedge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT")
		bar.wedge = wedge
	end

	-- The double border sits above the fill and the prediction.
	local overlay = CreateFrame("Frame", nil, body)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(level + 5)
	local frameSlices = CreateArtSlices(overlay, "ARTWORK", spec.frame)

	local barObject = {
		body = body, bar = bar, overlay = overlay, spec = spec, origin = origin,
		backSlices = backSlices, frameSlices = frameSlices,
	}
	return barObject
end

-- Every bar, test and real, so the Width setting reaches them all.
local allBars = {}

function ns.LayoutAllBars()
	for _, barObject in ipairs(allBars) do
		LayoutBar(barObject)
	end
end

-- Heal and absorb prediction, as in DibsUI: each piece is a full width bar starting where the one before
-- ends, masked behind the cap in front, and clipped at the bar's end. See DibsUI's Bars.lua for why.
local function MaskBehindCap(segment, spec)
	local mask = segment:CreateMaskTexture(nil, "ARTWORK")
	mask:SetTexture(ns.Media("BarFillMaskRight"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetSize(spec.capWidth * MASK_REACH, spec.fillHeight)
	mask:SetPoint("TOPLEFT", segment, "TOPLEFT")
	segment:GetStatusBarTexture():AddMaskTexture(mask)
	segment.cap:AddMaskTexture(mask)
end

local function CreatePredictionSegment(parent, level, previous, spec)
	local segment = CreateFrame("StatusBar", nil, parent)
	segment:SetFrameLevel(level)
	segment:SetStatusBarTexture(ns.Media("BarFill"))
	segment:SetFillStyle(Enum.StatusBarFillStyle.StandardNoRangeFill)
	segment:SetHeight(spec.fillHeight)
	segment:SetPoint("LEFT", previous:GetStatusBarTexture(), "RIGHT")
	segment:SetMinMaxValues(0, 1)
	segment:SetValue(0)
	CreateFillCap(segment, spec)
	MaskBehindCap(segment, spec)
	return segment
end

local function CreateEndGlow(parent, health)
	local spec = health.spec
	local glow = ns.CreateArt(parent, "ARTWORK", "BarEndGlow")
	glow:SetBlendMode("ADD")
	glow:SetWidth(spec.capWidth * 2)
	glow:SetPoint("TOPRIGHT", health.bar, "TOPRIGHT", spec.capWidth, 0)
	glow:SetPoint("BOTTOMRIGHT", health.bar, "BOTTOMRIGHT", spec.capWidth, 0)
	glow:SetVertexColor(CLEAR:GetRGBA())
	return glow
end

local function CreatePrediction(health)
	local spec, bar, body = health.spec, health.bar, health.body
	local level = body:GetFrameLevel()

	local clip = CreateFrame("Frame", nil, body)
	clip:SetFrameLevel(level + 1)
	clip:SetClipsChildren(true)
	clip:SetPoint("TOPLEFT", bar, "TOPLEFT")
	clip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", spec.capWidth, 0)

	local heal = CreatePredictionSegment(clip, level + 2, bar, spec)
	local absorb = CreatePredictionSegment(clip, level + 1, heal, spec)
	absorb:SetStatusBarColor(ABSORB_COLOR[1], ABSORB_COLOR[2], ABSORB_COLOR[3])
	absorb.cap:SetVertexColor(ABSORB_COLOR[1], ABSORB_COLOR[2], ABSORB_COLOR[3])

	local glowFrame = CreateFrame("Frame", nil, clip)
	glowFrame:SetAllPoints()
	glowFrame:SetFrameLevel(level + 4)

	bar.heal = heal
	local prediction = {
		frame = clip,
		heal = heal,
		absorb = absorb,
		healGlow = CreateEndGlow(glowFrame, health),
		absorbGlow = CreateEndGlow(glowFrame, health),
	}
	if CreateUnitHealPredictionCalculator then
		local calculator = CreateUnitHealPredictionCalculator()
		calculator:SetIncomingHealClampMode(Enum.UnitIncomingHealClampMode.MissingHealth)
		calculator:SetIncomingHealOverflowPercent(1)
		calculator:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MissingHealth)
		prediction.calculator = calculator
	end
	health.prediction = prediction
end

-- The orb ---------------------------------------------------------------------------------------------

local function CreateLayer(parent, level)
	local layer = CreateFrame("Frame", nil, parent)
	layer:SetAllPoints()
	layer:SetFrameLevel(level)
	return layer
end

-- DibsUI's orb with the unit's portrait (or class icon) in the well where the liquid would be, and the
-- cast ring showing power. The ring is a radial status bar, which takes secret values like any bar.
local function CreateOrb(v, parent, origin, level)
	local orb = CreateFrame("Frame", nil, parent)
	orb:SetFrameLevel(level)
	orb:SetSize(Layout.orbQuad, Layout.orbQuad)
	orb:SetPoint("CENTER", origin, "CENTER")
	ns.CreateArt(orb, "BACKGROUND", "OrbBack"):SetAllPoints()

	local portrait = orb:CreateTexture(nil, "ARTWORK")
	portrait:SetSize(Layout.orbRadius * 2, Layout.orbRadius * 2)
	portrait:SetPoint("CENTER")
	local circle = orb:CreateMaskTexture()
	circle:SetAtlas("CircleMask")
	circle:SetAllPoints(portrait)
	portrait:AddMaskTexture(circle)

	local glass = CreateLayer(orb, level + 1)
	local glassArt = ns.CreateArt(glass, "ARTWORK", "OrbGlass")
	glassArt:SetAllPoints()

	local ring = CreateFrame("StatusBar", nil, orb)
	ring:SetAllPoints()
	ring:SetFrameLevel(level + 2)
	ring:SetStatusBarTexture(ns.Media("CastRing"))
	ring:SetRenderMode(Enum.StatusBarRenderMode.Radial)
	ring:SetMinMaxValues(0, 1)
	ring:SetValue(1)

	-- Test frames draw the ring as a held swipe instead, like DibsUI's cast ring: their numbers aren't
	-- secret, and the UIForever simulator doesn't draw radial bars.
	local testRing = CreateFrame("Cooldown", nil, orb)
	testRing:SetAllPoints()
	testRing:SetFrameLevel(level + 2)
	testRing:SetHideCountdownNumbers(true)
	testRing:SetDrawBling(false)
	testRing:SetDrawEdge(false)
	testRing:SetDrawSwipe(true)
	testRing:SetSwipeTexture(ns.Media("CastRing"), 1, 1, 1, 1)
	testRing:SetReverse(true)
	testRing:Hide()
	v.testRing = testRing

	local rim = CreateLayer(orb, level + 3)
	ns.CreateArt(rim, "ARTWORK", "OrbFrame"):SetAllPoints()

	v.orb, v.portrait, v.ring = orb, portrait, ring
	v.indicators = CreateLayer(orb, level + 4)
end

-- Indicators: leader crown and role at the left of the rim, raid marker on top, ready check over the
-- portrait. Sizes are in frame units.
local function CreateIndicators(v)
	local layer = v.indicators

	local leader = layer:CreateTexture(nil, "OVERLAY")
	leader:SetSize(40, 40)
	leader:SetPoint("CENTER", v.orb, "CENTER", -50, 50)
	leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	leader:Hide()

	local role = layer:CreateTexture(nil, "OVERLAY")
	role:SetSize(40, 40)
	role:SetPoint("CENTER", v.orb, "CENTER", -50, -50)
	role:Hide()

	local marker = layer:CreateTexture(nil, "OVERLAY")
	marker:SetSize(52, 52)
	marker:SetPoint("CENTER", v.orb, "CENTER", 0, 66)
	marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	marker:Hide()

	local ready = layer:CreateTexture(nil, "OVERLAY", nil, 2)
	ready:SetSize(76, 76)
	ready:SetPoint("CENTER", v.orb, "CENTER")
	ready:Hide()

	v.leader, v.role, v.marker, v.ready = leader, role, marker, ready
end

local ROLE_ATLAS = {
	TANK = "roleicon-tiny-tank",
	HEALER = "roleicon-tiny-healer",
	DAMAGER = "roleicon-tiny-dps",
}

-- The raid marker sheet is a 4 by 4 grid; markers 1 to 8 are its top two rows.
local function ShowMarker(texture, index)
	local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
	texture:SetTexCoord(column / 4, (column + 1) / 4, row / 4, (row + 1) / 4)
	texture:Show()
end

local READY_TEXTURES = {
	ready = READY_CHECK_READY_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-Ready",
	notready = READY_CHECK_NOT_READY_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-NotReady",
	waiting = READY_CHECK_WAITING_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-Waiting",
}

-- The visuals of one member -----------------------------------------------------------------------------

-- Builds everything one member shows, on parent, with origin as the orb centre. hoverOwner is the frame
-- that takes the mouse, for the health text's mouseover setting.
function ns.CreateVisual(parent, origin, hoverOwner)
	local v = { parent = parent, origin = origin }
	local base = parent:GetFrameLevel()

	v.health = CreateBar(parent, origin, Layout.health, base + 2)
	CreatePrediction(v.health)
	allBars[#allBars + 1] = v.health
	LayoutBar(v.health)
	CreateOrb(v, parent, origin, base + 12)
	CreateIndicators(v)

	-- The level at the top right of the orb, colored by how hard the unit is for the player, as DibsUI's target level.
	local levelSpec = ns.Text.level
	local level = ns.CreateText(v.indicators, levelSpec.size)
	level:SetPoint("CENTER", v.orb, "CENTER", levelSpec.x, levelSpec.y)
	v.level = level

	local overlay = v.health.overlay
	local nameSpec = ns.Text.name
	-- The name centres in this box. With last names on it's "First Last", the last name smaller.
	local box = CreateFrame("Frame", nil, overlay)
	box:SetPoint("BOTTOMLEFT", v.health.body, "TOPLEFT", 14, nameSpec.y)
	box:SetPoint("BOTTOMRIGHT", v.health.body, "TOPRIGHT", -24, nameSpec.y)
	box:SetHeight(1)
	local name = ns.CreateText(overlay, nameSpec.size)
	name:SetJustifyH("CENTER")
	name.box = box
	name.surname = ns.CreateSurnameText(overlay, name)
	v.name = name

	v.healthText = ns.CreateHealthText(overlay, v.health.body)

	hoverOwner:HookScript("OnEnter", function()
		v.hovered = true
		ns.SetHealthTextState(v.healthText, v.status, true)
	end)
	hoverOwner:HookScript("OnLeave", function()
		v.hovered = false
		ns.SetHealthTextState(v.healthText, v.status, false)
	end)
	return v
end

-- The pet's bar, on its own parent (the pet's click button), drawn from the owner's orb centre.
function ns.CreatePetVisual(parent, origin)
	local pet = CreateBar(parent, origin, Layout.pet, parent:GetFrameLevel() + 2)
	allBars[#allBars + 1] = pet
	LayoutBar(pet)
	local color = ns.Colors.petHealth
	SetBarColor(pet.bar, color[1], color[2], color[3])
	local name = ns.CreateText(pet.overlay, ns.Text.petName.size)
	name:SetPoint("CENTER", pet.body, "CENTER", ns.Text.petName.x, ns.Text.petName.y)
	name:Hide()
	pet.name = name
	parent:HookScript("OnEnter", function() name:Show() end)
	parent:HookScript("OnLeave", function() name:Hide() end)
	return pet
end

-- Shared drawing ------------------------------------------------------------------------------------

local function ShowStatus(v, status)
	v.status = status
	ns.SetHealthTextState(v.healthText, status, v.hovered)
	local greyed = status ~= nil
	v.portrait:SetDesaturated(greyed)
	v.health.bar:SetShown(status ~= "Dead" and status ~= "Ghost")
end

local function ShowPortrait(v, unit, classFile, testTexture)
	local portrait = v.portrait
	local coords = classFile and not issecretvalue(classFile) and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
	if ns.db.classIcons and coords then
		portrait:SetTexture(CLASS_ICONS)
		portrait:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	else
		portrait:SetTexCoord(0, 1, 0, 1)
		if unit then
			SetPortraitTexture(portrait, unit)
		elseif testTexture then
			portrait:SetTexture(testTexture)
		end
	end
end

local function ShowHealthColor(v, classFile, greyed)
	local color = not greyed and ns.GetClassColor(classFile)
	if color then
		SetBarColor(v.health.bar, color.r, color.g, color.b)
		v.name:SetTextColor(color.r, color.g, color.b)
	else
		local grey = ns.Colors.disabled
		SetBarColor(v.health.bar, grey[1], grey[2], grey[3])
		v.name:SetTextColor(0.75, 0.75, 0.75)
	end
end

-- Real units ------------------------------------------------------------------------------------------

local function GetStatus(unit)
	if not UnitIsConnected(unit) then
		return "Offline"
	elseif UnitIsGhost(unit) then
		return "Ghost"
	elseif UnitIsDead(unit) then
		return "Dead"
	end
end

function ns.UpdateHealth(v, unit, interpolation)
	local bar = v.health.bar
	bar:SetMinMaxValues(0, UnitHealthMax(unit))
	bar:SetValue(UnitHealth(unit), interpolation)
	bar.cap:SetAlpha(UnitHealthPercent(unit, true, VISIBLE_ABOVE_ZERO))
	ns.ShowHealth(v.healthText, unit)
	local status = GetStatus(unit)
	ShowStatus(v, status)
	local _, classFile = UnitClass(unit)
	ShowHealthColor(v, classFile, status ~= nil)
end

function ns.UpdatePrediction(v, unit, interpolation)
	local prediction = v.health.prediction
	if not ns.ShowHealPrediction() or not prediction.calculator then
		prediction.frame:Hide()
		return
	end
	local calculator = prediction.calculator
	UnitGetDetailedHealPrediction(unit, nil, calculator)
	local heals, _, _, healsClamped = calculator:GetIncomingHeals()
	local absorbs, absorbsClamped = calculator:GetDamageAbsorbs()
	local maxHealth = UnitHealthMax(unit)
	prediction.heal:SetMinMaxValues(0, maxHealth)
	prediction.heal:SetValue(heals, interpolation)
	prediction.absorb:SetMinMaxValues(0, maxHealth)
	prediction.absorb:SetValue(absorbs, interpolation)
	prediction.healGlow:SetVertexColorFromBoolean(healsClamped, GLOW_COLOR, CLEAR)
	prediction.absorbGlow:SetVertexColorFromBoolean(healsClamped, CLEAR, GLOW_COLOR)
	prediction.absorbGlow:SetAlphaFromBoolean(absorbsClamped, 1, 0)
	prediction.frame:SetShown(not UnitIsDeadOrGhost(unit))
end

function ns.UpdatePower(v, unit, interpolation)
	local powerType, powerToken = UnitPowerType(unit)
	if not powerType then
		return
	end
	local ring = v.ring
	ring:Show()
	v.testRing:Hide()
	ring:SetStatusBarColor(ns.GetPowerColor(powerToken))
	ring:SetMinMaxValues(0, UnitPowerMax(unit, powerType))
	ring:SetValue(UnitPower(unit, powerType), interpolation)
end

local function ShowLevel(v, unit)
	local level = UnitEffectiveLevel(unit)
	if issecretvalue(level) then
		v.level:SetText(level)
		v.level:SetTextColor(1, 0.82, 0)
		return
	end
	v.level:SetText(level and level > 0 and level or "??")
	local color = GetDifficultyColor and C_PlayerInfo.GetContentDifficultyCreatureForPlayer
		and GetDifficultyColor(C_PlayerInfo.GetContentDifficultyCreatureForPlayer(unit))
	if color then
		v.level:SetTextColor(color.r, color.g, color.b)
	else
		v.level:SetTextColor(1, 0.82, 0)
	end
end

function ns.UpdateIdentity(v, unit)
	ns.ShowName(v.name, UnitName(unit))
	ShowLevel(v, unit)
	local _, classFile = UnitClass(unit)
	ShowPortrait(v, unit, classFile)
end

function ns.UpdateIndicators(v, unit)
	v.leader:SetShown(UnitIsGroupLeader(unit))
	local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
	local atlas = role and ROLE_ATLAS[role]
	if atlas then
		v.role:SetAtlas(atlas)
	end
	v.role:SetShown(atlas ~= nil)
	local index = GetRaidTargetIndex(unit)
	if index and not issecretvalue(index) then
		ShowMarker(v.marker, index)
	else
		v.marker:Hide()
	end
end

function ns.UpdateReadyCheck(v, unit, finished)
	local status = GetReadyCheckStatus(unit)
	local texture = status and READY_TEXTURES[status]
	if texture then
		v.ready:SetTexture(texture)
		v.ready:SetAlpha(1)
	end
	v.ready:SetShown(texture ~= nil)
	if finished and texture then
		-- Blizzard leaves the result up for a few seconds after the check ends.
		C_Timer.After(5, function()
			v.ready:Hide()
		end)
	end
end

-- UnitInRange can be secret, so the client picks the alpha. checkedRange false means it can't be
-- checked (such as the player), which counts as in range.
function ns.UpdateRange(v, unit)
	local inRange, checked = UnitInRange(unit)
	if issecretvalue(inRange) or issecretvalue(checked) then
		v.parent:SetAlphaFromBoolean(inRange, 1, OUT_OF_RANGE_ALPHA)
	elseif checked and not inRange then
		v.parent:SetAlpha(OUT_OF_RANGE_ALPHA)
	else
		v.parent:SetAlpha(1)
	end
end

function ns.UpdatePet(pet, unit, interpolation)
	local bar = pet.bar
	bar:SetMinMaxValues(0, UnitHealthMax(unit))
	bar:SetValue(UnitHealth(unit), interpolation)
	bar.cap:SetAlpha(UnitHealthPercent(unit, true, VISIBLE_ABOVE_ZERO))
	pet.name:SetText(UnitName(unit))
end

ns.SMOOTH, ns.IMMEDIATE = SMOOTH, IMMEDIATE

-- Test data ----------------------------------------------------------------------------------------------

-- data: name, class, health (0..1), maxHealth, power (0..1), powerToken, heal and absorb (fractions of
-- max health), status, leader, role, marker, ready, outOfRange, portrait.
function ns.ShowTestVisual(v, data)
	local health = v.health
	health.bar:SetMinMaxValues(0, 1)
	health.bar:SetValue(data.health)
	health.bar.cap:SetAlpha(data.health > 0 and 1 or 0)
	ns.ShowTestHealth(v.healthText, data.health * 100, data.health * data.maxHealth)
	ShowStatus(v, data.status)
	ShowHealthColor(v, data.class, data.status ~= nil)

	local prediction = health.prediction
	prediction.frame:SetShown(ns.ShowHealPrediction() and data.status == nil)
	prediction.heal:SetValue(data.heal or 0)
	prediction.absorb:SetValue(data.absorb or 0)
	prediction.healGlow:SetVertexColor(CLEAR:GetRGBA())
	prediction.absorbGlow:SetVertexColor(CLEAR:GetRGBA())

	-- A swipe this long barely moves, so it holds at the power fraction.
	local held = 1e7
	v.ring:Hide()
	v.testRing:Show()
	local r, g, b = ns.GetPowerColor(data.powerToken)
	v.testRing:SetSwipeColor(r, g, b, 1)
	v.testRing:SetCooldown(GetTime() - (data.status and 0 or data.power) * held, held)

	ns.ShowName(v.name, data.name, data.surname)
	if data.unit then
		ShowLevel(v, data.unit)
	else
		v.level:SetText(data.level)
		local color = data.levelColor or { 1, 0.82, 0 }
		v.level:SetTextColor(color[1], color[2], color[3])
	end
	ShowPortrait(v, data.unit, data.class, data.portrait)

	v.leader:SetShown(data.leader == true)
	local atlas = data.role and ROLE_ATLAS[data.role]
	if atlas then
		v.role:SetAtlas(atlas)
	end
	v.role:SetShown(atlas ~= nil)
	if data.marker then
		ShowMarker(v.marker, data.marker)
	else
		v.marker:Hide()
	end
	local ready = data.ready and READY_TEXTURES[data.ready]
	if ready then
		v.ready:SetTexture(ready)
	end
	v.ready:SetShown(ready ~= nil)
	v.parent:SetAlpha(data.outOfRange and OUT_OF_RANGE_ALPHA or 1)
end

function ns.ShowTestPet(pet, data)
	pet.bar:SetMinMaxValues(0, 1)
	pet.bar:SetValue(data.health)
	pet.name:SetText(data.name)
end

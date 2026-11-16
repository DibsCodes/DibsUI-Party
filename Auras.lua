local _, ns = ...

local Layout = ns.Layout

-- Buffs under the bars, right then down, and debuffs past the bar's tip, right. Real members use
-- Blizzard's aura containers (Blizzard_AuraContainer), as DibsUI does: they keep showing auras in
-- combat, when aura details are secret and addon code can't read them. Test frames use DibsUI-Party's
-- own icons, built the same way so they look the same.
--
-- The counts are capped and the group reserves room for the caps (Group.lua). Each holder clips its
-- icons to its rows, so anything past the cap wraps onto a row that doesn't show.

local BORDER = 2 -- in frame units, about 1 px at the default size
local CLIP_MARGIN = 4 -- room round the icons inside the clip, for Masque skins that reach past the icon

local FLOW_AXIS = { horizontal = 0, vertical = 1 }
local FLOW_DIRECTION = { LEFT = -1, RIGHT = 1, UP = 1, DOWN = -1 }
local DISPEL_PRESERVE_ASSET = 3

-- Your own buffs on the member. Debuffs you can dispel come first ("RAID" on harmful auras), then the
-- rest in Blizzard's unit frame order (boss and priority debuffs first).
local BUFF_FILTER = "HELPFUL|PLAYER"
local DISPELLABLE_FILTER = "HARMFUL|RAID"
local OTHER_DEBUFF_FILTER = "HARMFUL|!RAID"

-- Masque groups, one for buffs and one for debuffs, set up at login once every addon has loaded.
local masqueGroups = {}
-- Every icon by kind ("buffs" or "debuffs"), test and real, for Masque and restyling.
local records = { buffs = {}, debuffs = {} }
local styleWaiting = false

-- Sizes and caps ---------------------------------------------------------------------------------------

-- A row of buffs runs from clear of the orb to the health bar's tip, so a longer bar fits more.
local function BuffsPerRow(tip)
	local room = tip - Layout.buffLeft + Layout.buffSpacing
	return math.max(1, math.floor(room / (Layout.buffSize + Layout.buffSpacing)))
end

function ns.GetBuffsPerRow()
	return BuffsPerRow(ns.GetBarTip(Layout.health))
end

function ns.GetMaxBuffs()
	return ns.GetBuffsPerRow() * Layout.buffRows
end

-- Enough test icons for the longest bar the Width setting allows.
local function GetIconsNeeded()
	local spec = Layout.health
	local longest = spec.tip + (ns.WidthRange.max - 1) * (spec.fillOuter - spec.fillInner)
	return BuffsPerRow(longest) * Layout.buffRows
end

-- The lowest bar's bottom edge, from the orb centre: the pet's while there's a pet.
function ns.GetBarsBottom(hasPet)
	local spec = hasPet and Layout.pet or Layout.health
	return spec.yCenter - spec.height / 2
end

-- How far the buff rows reach below the orb centre.
function ns.GetBuffsBottom(hasPet)
	local rows = Layout.buffRows
	return ns.GetBarsBottom(hasPet) - Layout.buffGap - rows * Layout.buffSize - (rows - 1) * Layout.buffSpacing
end

-- How far the debuff row reaches right of the orb centre.
function ns.GetDebuffsRight()
	local count = Layout.debuffMax
	return ns.GetBarTip(Layout.health) + Layout.debuffGap + count * Layout.debuffSize + (count - 1) * Layout.debuffSpacing
end

-- The length of a row of n icons.
local function Span(n, size, spacing)
	return n * (size + spacing) - spacing
end

-- Secrets ------------------------------------------------------------------------------------------------

-- While aura details are secret, in combat and some instances, addon code mustn't touch the buttons
-- in Blizzard's containers (DibsUI's rule). Restyling waits until they aren't.
local function AreAurasSecret()
	return C_Secrets ~= nil and C_Secrets.ShouldAurasBeSecret ~= nil and C_Secrets.ShouldAurasBeSecret() == true
end

-- Icons ------------------------------------------------------------------------------------------------

local function IsMasqueSkinned(kind)
	local group = masqueGroups[kind]
	return group ~= nil and not group.db.Disabled
end

-- The pieces of one icon. Blizzard fills in the icon, count, swipe and debuff type border on real ones.
local function CreateParts(button, kind)
	local parts = { button = button, kind = kind }
	parts.border = button:CreateTexture(nil, "BACKGROUND", nil, -8)
	parts.border:SetAllPoints()
	parts.border:SetColorTexture(0, 0, 0, 1)
	-- Over the black border, colored by debuff type where a debuff has one.
	if kind == "debuffs" then
		parts.dispel = button:CreateTexture(nil, "BACKGROUND", nil, -7)
		parts.dispel:SetColorTexture(1, 1, 1, 1)
		parts.dispel:Hide()
	end
	parts.icon = button:CreateTexture(nil, "ARTWORK")
	parts.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	parts.cooldown:SetDrawEdge(false)
	parts.cooldown:SetReverse(true)
	parts.cooldown:SetHideCountdownNumbers(true)
	-- The count sits over the swipe. Every text gets a font straight away, since Blizzard fills them in
	-- as soon as they're handed over.
	local countLayer = CreateFrame("Frame", nil, button)
	countLayer:SetAllPoints()
	countLayer:SetFrameLevel(parts.cooldown:GetFrameLevel() + 1)
	parts.count = countLayer:CreateFontString(nil, "OVERLAY")
	parts.count:SetFont(ns.Text.font, 16, "OUTLINE")
	return parts
end

-- DibsUI's look: a thin black border, with the icon's baked-in border cropped off. Under a Masque skin,
-- Masque draws the icon, border and count instead.
local function ApplyOwnSkin(parts)
	parts.border:Show()
	-- Masque moves the icon down a layer when its skin is turned off, which would put it under the border.
	parts.icon:SetDrawLayer("ARTWORK", 0)
	parts.icon:ClearAllPoints()
	parts.icon:SetPoint("TOPLEFT", BORDER, -BORDER)
	parts.icon:SetPoint("BOTTOMRIGHT", -BORDER, BORDER)
	parts.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	parts.count:ClearAllPoints()
	parts.count:SetPoint("BOTTOMRIGHT", -1, 2)
end

-- Masque fits its skin to a button's size, which Blizzard's aura buttons can keep secret, so it's told
-- the size DibsUI-Party set (as DibsUI does). Only for a button already in the group.
local function TellMasqueSize(parts, reskin)
	local group = masqueGroups[parts.kind]
	if group and group.SetFrameSize and group.Buttons and group.Buttons[parts.button] then
		group:SetFrameSize(parts.size, parts.size, parts.button, true, not reskin)
	end
end

local function StyleParts(parts)
	local size = parts.kind == "debuffs" and Layout.debuffSize or Layout.buffSize
	parts.button:SetSize(size, size)
	parts.size = size
	TellMasqueSize(parts, false)
	local skinned = IsMasqueSkinned(parts.kind)
	if skinned then
		parts.border:Hide()
	else
		ApplyOwnSkin(parts)
	end
	parts.cooldown:ClearAllPoints()
	parts.cooldown:SetAllPoints(parts.icon)
	-- Blizzard shows and colors the debuff type border itself. Under a skin it's tucked behind the icon.
	if parts.dispel then
		parts.dispel:ClearAllPoints()
		parts.dispel:SetAllPoints(skinned and parts.icon or parts.button)
	end
	local font = ns.GetFont()
	local countSize = math.max(math.floor(size * 0.45), 12)
	if not parts.count:SetFont(font, countSize, "OUTLINE") then
		parts.count:SetFont(ns.Text.font, countSize, "OUTLINE")
	end
end

-- The swipe and count stay DibsUI-Party's: Masque skins the icon and border.
local function AddToMasque(parts)
	local group = masqueGroups[parts.kind]
	if group then
		group:AddButton(parts.button, { Icon = parts.icon, Count = parts.count, Cooldown = parts.cooldown, Duration = false },
			parts.kind == "debuffs" and "Debuff" or "Buff")
		TellMasqueSize(parts, true)
	end
end

local function Register(parts)
	local list = records[parts.kind]
	list[#list + 1] = parts
	StyleParts(parts)
	AddToMasque(parts)
end

-- After a Masque skin change or a font change. Real icons wait while auras are secret.
function ns.RestyleAuras()
	if AreAurasSecret() then
		styleWaiting = true
		return
	end
	styleWaiting = false
	for kind, list in pairs(records) do
		for _, parts in ipairs(list) do
			StyleParts(parts)
		end
		if IsMasqueSkinned(kind) then
			masqueGroups[kind]:ReSkin()
		end
	end
end

-- Test icons ---------------------------------------------------------------------------------------------

local function OnTestIconEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetText(self.testName or "")
	GameTooltip:AddLine(self.testKind == "debuffs" and "Test debuff" or "Test buff", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function CreateTestIcon(holder, kind)
	local button = CreateFrame("Button", nil, holder)
	button.testKind = kind
	button:SetScript("OnEnter", OnTestIconEnter)
	button:SetScript("OnLeave", GameTooltip_Hide)
	local parts = CreateParts(button, kind)
	parts.isTest = true
	Register(parts)
	button:Hide()
	return parts
end

local function ShowTestIcon(parts, aura)
	local button = parts.button
	if not aura then
		button:Hide()
		return
	end
	button.testName = aura.name
	parts.icon:SetTexture(aura.icon)
	parts.count:SetText(aura.count and aura.count > 1 and aura.count or "")
	if parts.dispel then
		local color = aura.dispel and ns.Colors.dispel[aura.dispel]
		if color then
			parts.dispel:SetVertexColor(color[1], color[2], color[3], 1)
		end
		parts.dispel:SetShown(color ~= nil)
	end
	parts.cooldown:SetCooldown(GetTime() - (aura.duration - aura.remaining), aura.duration)
	button:Show()
end

local function PlaceTestIcons(auras)
	local perRow, step = ns.GetBuffsPerRow(), Layout.buffSize + Layout.buffSpacing
	for i, parts in ipairs(auras.testBuffs) do
		local column, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
		parts.button:ClearAllPoints()
		parts.button:SetPoint("TOPLEFT", auras.buffClip, "TOPLEFT", CLIP_MARGIN + column * step, -CLIP_MARGIN - row * step)
	end
	local debuffStep = Layout.debuffSize + Layout.debuffSpacing
	for i, parts in ipairs(auras.testDebuffs) do
		parts.button:ClearAllPoints()
		parts.button:SetPoint("TOPLEFT", auras.debuffClip, "TOPLEFT", CLIP_MARGIN + (i - 1) * debuffStep, -CLIP_MARGIN)
	end
end

function ns.ShowTestAuras(auras, buffs, debuffs)
	for i, parts in ipairs(auras.testBuffs) do
		ShowTestIcon(parts, buffs and i <= ns.GetMaxBuffs() and buffs[i])
	end
	for i, parts in ipairs(auras.testDebuffs) do
		ShowTestIcon(parts, debuffs and debuffs[i])
	end
end

-- Real units: Blizzard's containers ----------------------------------------------------------------------

local function InitContainerButton(button, kind)
	local ok, err = pcall(function()
		local parts = CreateParts(button, kind)
		button:SetIcon(parts.icon)
		button:SetApplicationCount(parts.count)
		button:SetDurationCooldown(parts.cooldown)
		if parts.dispel then
			local styles = Enum.CustomAuraButtonDispelTypeTextureStyle
			button:AddDispelTypeTexture(parts.dispel, { style = styles and styles.PreserveAsset or DISPEL_PRESERVE_ASSET })
		end
		Register(parts)
	end)
	if not ok then
		geterrorhandler()(err)
	end
end

local function NewContainer(clip, unit)
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, clip, "CustomAuraContainerTemplate")
	if not ok then
		geterrorhandler()(container)
		return nil
	end
	container:SetUnit(unit)
	container:SetPoint("TOPLEFT", clip, "TOPLEFT", CLIP_MARGIN, -CLIP_MARGIN)
	container:SetFlowLayoutAxis(FLOW_AXIS.horizontal)
	container:SetFlowLayoutGrowthDirection(FLOW_DIRECTION.RIGHT, FLOW_DIRECTION.DOWN)
	container:SetFlowLayoutAnchorPoint("TOPLEFT")
	return container
end

local function GroupLayout(size, spacing, layoutIndex)
	return {
		elementSpacing = spacing,
		lineSpacing = spacing,
		groupSpacing = 0, -- the flow layout already leaves the spacing after each icon
		groupLineSpacing = spacing,
		elementWidth = size,
		elementHeight = size,
		layoutIndex = layoutIndex,
	}
end

local function CreateContainers(auras, unit)
	local default = AuraContainerSortMethod and AuraContainerSortMethod.Default or 0
	local unitFrameOrder = AuraContainerSortMethod and AuraContainerSortMethod.UnitFrameDebuff or 2
	local normal = AuraContainerSortDirection and AuraContainerSortDirection.Normal or 0

	local buffs = NewContainer(auras.buffClip, unit)
	if buffs then
		buffs:AddAuraGroup("mine", BUFF_FILTER, {
			sortMethod = default,
			sortDirection = normal,
			maxFrameCount = ns.GetMaxBuffs(),
			layout = GroupLayout(Layout.buffSize, Layout.buffSpacing, 1),
			initializeFrame = function(button) InitContainerButton(button, "buffs") end,
		})
	end
	auras.buffContainer = buffs

	-- Each debuff group can fill the row on its own. Past four in all, they wrap out of the clip.
	local debuffs = NewContainer(auras.debuffClip, unit)
	if debuffs then
		debuffs:AddAuraGroup("dispellable", DISPELLABLE_FILTER, {
			sortMethod = default,
			sortDirection = normal,
			maxFrameCount = Layout.debuffMax,
			layout = GroupLayout(Layout.debuffSize, Layout.debuffSpacing, 1),
			initializeFrame = function(button) InitContainerButton(button, "debuffs") end,
		})
		debuffs:AddAuraGroup("others", OTHER_DEBUFF_FILTER, {
			sortMethod = unitFrameOrder,
			sortDirection = normal,
			maxFrameCount = Layout.debuffMax,
			layout = GroupLayout(Layout.debuffSize, Layout.debuffSpacing, 2),
			initializeFrame = function(button) InitContainerButton(button, "debuffs") end,
		})
		debuffs:SetFlowLayoutMaximumLineSize(Span(Layout.debuffMax, Layout.debuffSize, Layout.debuffSpacing) + 0.5)
	end
	auras.debuffContainer = debuffs
end

-- Blizzard's containers are made at login, as DibsUI makes its own, once Blizzard_AuraContainer can load.
function ns.CreateAuraContainers(auras)
	if C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
		pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
	end
	CreateContainers(auras, auras.unit)
end

-- party1 can be someone else after the roster changes, so the containers read every aura again.
function ns.RefreshAuraContainers(auras)
	for _, container in ipairs({ auras.buffContainer, auras.debuffContainer }) do
		if container then
			container:UpdateAllAuras()
		end
	end
end

-- Holders --------------------------------------------------------------------------------------------------

-- One clip for buffs and one for debuffs on a member's frame. unit is nil for test frames, which get
-- test icons instead of Blizzard's containers.
function ns.CreateAuras(parent, origin, unit)
	local auras = { origin = origin, unit = unit, testBuffs = {}, testDebuffs = {} }
	local level = parent:GetFrameLevel() + 20

	auras.buffClip = CreateFrame("Frame", nil, parent)
	auras.buffClip:SetFrameLevel(level)
	auras.buffClip:SetClipsChildren(true)

	auras.debuffClip = CreateFrame("Frame", nil, parent)
	auras.debuffClip:SetFrameLevel(level)
	auras.debuffClip:SetClipsChildren(true)
	auras.debuffClip:SetSize(Span(Layout.debuffMax, Layout.debuffSize, Layout.debuffSpacing) + 2 * CLIP_MARGIN,
		Layout.debuffSize + 2 * CLIP_MARGIN)

	if not unit then
		for i = 1, GetIconsNeeded() do
			auras.testBuffs[i] = CreateTestIcon(auras.buffClip, "buffs")
		end
		for i = 1, Layout.debuffMax do
			auras.testDebuffs[i] = CreateTestIcon(auras.debuffClip, "debuffs")
		end
	end
	return auras
end

-- Buffs start under the lowest bar, so they drop below a pet's bar, and wrap at the bar's tip. Debuffs
-- start past the tip. Both follow the Width setting. Out of combat only: it changes the container's caps.
function ns.PlaceAuras(auras, hasPet)
	local perRow = ns.GetBuffsPerRow()
	local rowLength = Span(perRow, Layout.buffSize, Layout.buffSpacing)
	auras.buffClip:SetSize(rowLength + 2 * CLIP_MARGIN,
		Span(Layout.buffRows, Layout.buffSize, Layout.buffSpacing) + 2 * CLIP_MARGIN)
	auras.buffClip:ClearAllPoints()
	auras.buffClip:SetPoint("TOPLEFT", auras.origin, "CENTER",
		Layout.buffLeft - CLIP_MARGIN, ns.GetBarsBottom(hasPet) - Layout.buffGap + CLIP_MARGIN)
	auras.debuffClip:ClearAllPoints()
	auras.debuffClip:SetPoint("LEFT", auras.origin, "CENTER",
		ns.GetBarTip(Layout.health) + Layout.debuffGap - CLIP_MARGIN, Layout.health.yCenter)

	if auras.buffContainer then
		auras.buffContainer:SetFlowLayoutMaximumLineSize(rowLength + 0.5)
		auras.buffContainer:SetAuraGroupMaxFrameCount("mine", perRow * Layout.buffRows)
	end
	if not auras.unit then
		PlaceTestIcons(auras)
	end
	auras.buffClip:SetShown(ns.db.showBuffs)
	auras.debuffClip:SetShown(ns.db.showDebuffs)
end

-- Masque -------------------------------------------------------------------------------------------------

local function SetUpMasque()
	local Masque = LibStub and LibStub("Masque", true)
	if not Masque then
		return
	end
	ns.hasMasque = true
	masqueGroups.buffs = Masque:Group(ns.ADDON_TITLE, "Buffs", "buffs")
	masqueGroups.debuffs = Masque:Group(ns.ADDON_TITLE, "Debuffs", "debuffs")
	for kind, group in pairs(masqueGroups) do
		-- Turning the skin off in Masque puts DibsUI-Party's own look back.
		group:RegisterCallback(function()
			ns.RestyleAuras()
		end)
		for _, parts in ipairs(records[kind]) do
			AddToMasque(parts)
		end
	end
	ns.RestyleAuras()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		SetUpMasque()
	elseif styleWaiting then
		ns.RestyleAuras()
	end
end)

local _, ns = ...

local Layout = ns.Layout

-- The group: one frame per party member and one for the player, laid out by the chosen layout. The
-- click buttons are secure, so they can't move, show or hide from addon code during combat. Anything
-- that changes the layout then waits for combat to end. Their visibility follows the unit (unit watch)
-- and the group hides itself in raids (state driver), both of which work in combat.

local group, mover
local members = {} -- party1 to party4, then the player
local pendingLayout = false

-- A member's space ----------------------------------------------------------------------------------------

-- Distances from the orb centre to the edges of the space a member needs, with room for the capped
-- auras, so no layout overlaps.
function ns.GetMemberExtents(hasPet)
	local left = Layout.orbReach
	local right = ns.db.showDebuffs and ns.GetDebuffsRight() or ns.GetBarTip(Layout.health)
	local top = Layout.orbReach
	local lowest = ns.db.showBuffs and ns.GetBuffsBottom(hasPet) or ns.GetBarsBottom(hasPet)
	local bottom = math.max(Layout.orbReach, -lowest)
	return left, right, top, bottom
end

-- Sizes a member's click area (or test frame) and its pet's to the bars, which follow the Width setting.
function ns.SizeMember(member)
	member.root:SetSize(Layout.orbReach + ns.GetBarTip(Layout.health), Layout.orbReach * 2)
	local spec = Layout.pet
	member.petRoot:SetSize(ns.GetBarTip(spec) - spec.hitInner, spec.height)
end

-- Places members (each { root, hasPet }) in holder and sizes it to fit them. Positions are worked out
-- from the box's top left, whatever corner the layout keeps still.
function ns.LayoutMembers(holder, list)
	local layout = ns.LayoutsByKey[ns.db.layout]
	local gap = Layout.frameGap
	local spots = {}
	local boxWidth, boxHeight = 0, 0

	if layout.axis == "vertical" then
		local y = 0
		for i, member in ipairs(list) do
			local left, right, top, bottom = ns.GetMemberExtents(member.hasPet)
			spots[i] = { x = left, top = top, bottom = bottom, offset = y }
			y = y + top + bottom + gap
			boxWidth = math.max(boxWidth, left + right)
		end
		boxHeight = math.max(y - gap, 0)
		for i, spot in ipairs(spots) do
			if layout.sign < 0 then
				spot.y = -(spot.offset + spot.top)
			else
				-- Growing up: the first member sits at the bottom.
				spot.y = -(boxHeight - spot.offset - spot.bottom)
			end
		end
	else
		local maxTop, maxBottom = 0, 0
		local widths = {}
		for i, member in ipairs(list) do
			local left, right, top, bottom = ns.GetMemberExtents(member.hasPet)
			widths[i] = { left = left, right = right }
			maxTop, maxBottom = math.max(maxTop, top), math.max(maxBottom, bottom)
			boxWidth = boxWidth + left + right + (i > 1 and gap or 0)
		end
		boxHeight = maxTop + maxBottom
		local x = 0
		for i, width in ipairs(widths) do
			local spot = { y = -maxTop }
			if layout.sign < 0 then
				-- Growing left: the first member sits at the right.
				spot.x = boxWidth - x - width.right
			else
				spot.x = x + width.left
			end
			x = x + width.left + width.right + gap
			spots[i] = spot
		end
	end

	for i, member in ipairs(list) do
		ns.SizeMember(member)
		member.root:ClearAllPoints()
		member.root:SetPoint("LEFT", holder, "TOPLEFT", spots[i].x - Layout.orbReach, spots[i].y)
	end
	holder:SetSize(math.max(boxWidth, 1), math.max(boxHeight, 1))
end

-- The frames' art is DibsUI's size, scaled down to Layout.scale, times the Scale setting.
function ns.GetScale()
	return Layout.scale * ns.db.scale
end

-- Scaling keeps the anchor corner still: its offset is in UIParent units, which don't change.
function ns.SetScale(scale)
	if InCombatLockdown() then
		return
	end
	ns.db.scale = math.min(math.max(scale, ns.ScaleRange.min), ns.ScaleRange.max)
	ns.ApplyPlacement()
end

-- Placement ---------------------------------------------------------------------------------------------

local holders = {}

-- Every holder (the real group and the test group) hangs from the same corner of the screen.
function ns.ApplyPlacement()
	local db = ns.db
	local point = ns.LayoutsByKey[db.layout].anchor
	for _, holder in ipairs(holders) do
		holder:ClearAllPoints()
		holder:SetScale(ns.GetScale())
		holder:SetPoint(point, UIParent, point, db.x / ns.GetScale(), db.y / ns.GetScale())
	end
end

function ns.AddHolder(holder)
	holder:SetScale(ns.GetScale())
	holder:SetFrameStrata("LOW")
	holder:SetClampedToScreen(true)
	holders[#holders + 1] = holder
end

-- Where a corner of a holder is, as an offset from the same corner of the screen, in UIParent units.
local function GetCornerOffset(holder, point)
	local scale = holder:GetScale()
	local left, right = holder:GetLeft() * scale, holder:GetRight() * scale
	local top, bottom = holder:GetTop() * scale, holder:GetBottom() * scale
	local width, height = UIParent:GetWidth(), UIParent:GetHeight()
	local x, y
	if point:find("LEFT") then
		x = left
	elseif point:find("RIGHT") then
		x = right - width
	else
		x = (left + right) / 2 - width / 2
	end
	if point:find("TOP") then
		y = top - height
	elseif point:find("BOTTOM") then
		y = bottom
	else
		y = (top + bottom) / 2 - height / 2
	end
	return x, y
end

-- Saves where the layout's anchor corner of the shown holder is now.
local function SavePosition(holder, layoutKey)
	local point = ns.LayoutsByKey[layoutKey].anchor
	if not holder:GetLeft() then
		return
	end
	ns.db.point = point
	ns.db.x, ns.db.y = GetCornerOffset(holder, point)
end

-- Real members ------------------------------------------------------------------------------------------

local UNIT_EVENTS = {
	"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER",
	"UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED",
	"UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_PET",
	"UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED",
}

local PET_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE" }

local function UpdateMember(member, interpolation)
	local unit, v = member.unit, member.v
	if not UnitExists(unit) then
		return
	end
	interpolation = interpolation or ns.IMMEDIATE
	ns.UpdateIdentity(v, unit)
	ns.UpdateHealth(v, unit, interpolation)
	ns.UpdatePrediction(v, unit, interpolation)
	ns.UpdatePower(v, unit, interpolation)
	ns.UpdateIndicators(v, unit)
	ns.UpdateReadyCheck(v, unit)
	ns.UpdateRange(v, unit)
	if UnitExists(member.petUnit) then
		ns.UpdatePet(member.pet, member.petUnit, interpolation)
	end
end

local function OnUnitEvent(member, event)
	local unit, v = member.unit, member.v
	if not UnitExists(unit) then
		return
	end
	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_CONNECTION" or event == "UNIT_FLAGS" then
		ns.UpdateHealth(v, unit, event == "UNIT_HEALTH" and ns.SMOOTH or ns.IMMEDIATE)
		ns.UpdatePrediction(v, unit, ns.IMMEDIATE)
	elseif event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" then
		ns.UpdatePrediction(v, unit, ns.SMOOTH)
	elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
		ns.UpdatePower(v, unit, ns.SMOOTH)
	elseif event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
		ns.UpdatePower(v, unit, ns.IMMEDIATE)
	elseif event == "UNIT_PET" then
		if UnitExists(member.petUnit) then
			ns.UpdatePet(member.pet, member.petUnit, ns.IMMEDIATE)
		end
		ns.RequestLayout()
	else
		ns.UpdateIdentity(v, unit)
	end
end

local function CreateMember(index, unit, petUnit)
	local button = CreateFrame("Button", "DibsUIParty" .. index, group, "SecureUnitButtonTemplate")
	button:RegisterForClicks("AnyUp")
	button:SetAttribute("unit", unit)
	button:SetAttribute("*type1", "target")
	button:SetAttribute("*type2", "togglemenu")

	local origin = CreateFrame("Frame", nil, button)
	origin:SetSize(1, 1)
	origin:SetPoint("CENTER", button, "LEFT", Layout.orbReach, 0)

	local member = { unit = unit, petUnit = petUnit, root = button, origin = origin }
	member.v = ns.CreateVisual(button, origin, button)

	local spec = Layout.pet
	local petButton = CreateFrame("Button", "DibsUIParty" .. index .. "Pet", button, "SecureUnitButtonTemplate")
	petButton:SetFrameLevel(button:GetFrameLevel() + 30)
	petButton:SetPoint("LEFT", button, "LEFT", Layout.orbReach + spec.hitInner, spec.yCenter)
	petButton:RegisterForClicks("AnyUp")
	petButton:SetAttribute("unit", petUnit)
	petButton:SetAttribute("*type1", "target")
	petButton:SetAttribute("*type2", "togglemenu")
	member.petRoot = petButton
	member.pet = ns.CreatePetVisual(petButton, origin)
	ns.SizeMember(member)
	RegisterUnitWatch(petButton)

	member.auras = ns.CreateAuras(button, origin, unit)

	local events = CreateFrame("Frame", nil, button)
	for _, event in ipairs(UNIT_EVENTS) do
		events:RegisterUnitEvent(event, unit)
	end
	events:SetScript("OnEvent", function(_, event)
		OnUnitEvent(member, event)
	end)
	local petEvents = CreateFrame("Frame", nil, petButton)
	for _, event in ipairs(PET_EVENTS) do
		petEvents:RegisterUnitEvent(event, petUnit)
	end
	petEvents:SetScript("OnEvent", function(_, event)
		if UnitExists(petUnit) then
			ns.UpdatePet(member.pet, petUnit, event == "UNIT_HEALTH" and ns.SMOOTH or ns.IMMEDIATE)
		end
	end)
	-- A member's frame catches up whenever it appears, such as when someone joins.
	button:HookScript("OnShow", function()
		UpdateMember(member)
	end)
	return member
end

-- The player's frame shows only in a party, and only with the setting on.
local function UpdatePlayerVisibility()
	local player = members[5]
	if ns.db.showPlayer then
		RegisterStateDriver(player.root, "visibility", "[group] show; hide")
	else
		UnregisterStateDriver(player.root, "visibility")
		player.root:Hide()
	end
end

-- Layout ------------------------------------------------------------------------------------------------

local function DoLayout()
	local list = {}
	local count = math.min(GetNumSubgroupMembers(), 4)
	-- Every party frame gets a spot, so someone joining mid-combat appears in place. The player comes
	-- after the members there are now.
	for i = 1, 4 do
		local member = members[i]
		member.hasPet = UnitExists(member.petUnit)
		ns.PlaceAuras(member.auras, member.hasPet)
		if i <= count then
			list[#list + 1] = member
		end
	end
	local player = members[5]
	player.hasPet = UnitExists("pet")
	ns.PlaceAuras(player.auras, player.hasPet)
	if ns.db.showPlayer then
		list[#list + 1] = player
	end
	-- Party frames that aren't showing get the spots after the list first, so someone joining
	-- mid-combat appears there (exactly for grow down and right, roughly for the others). Then the
	-- list is laid out on its own, which also sizes the box to who's showing.
	local all = {}
	for _, member in ipairs(list) do
		all[#all + 1] = member
	end
	for i = count + 1, 4 do
		all[#all + 1] = members[i]
	end
	ns.LayoutMembers(group, all)
	ns.LayoutMembers(group, list)
	UpdatePlayerVisibility()
	ns.ApplyPlacement()
end

function ns.RequestLayout()
	if InCombatLockdown() then
		pendingLayout = true
		return
	end
	pendingLayout = false
	DoLayout()
	ns.LayoutTestFrames()
	ns.UpdateMover()
end

-- Switching layouts keeps the new layout's anchor corner where it is now.
function ns.SetLayout(key)
	if InCombatLockdown() or not ns.LayoutsByKey[key] then
		return
	end
	SavePosition(ns.GetShownHolder(), key)
	ns.db.layout = key
	ns.RequestLayout()
end

function ns.GetShownHolder()
	if ns.AreTestFramesShown() then
		return ns.testHolder
	end
	return group
end

-- Showing the test frames hides the real ones, out of combat only.
function ns.SetRealGroupShown(shown)
	if InCombatLockdown() then
		return
	end
	if shown then
		RegisterStateDriver(group, "visibility", "[group:raid] hide; show")
	else
		UnregisterStateDriver(group, "visibility")
		group:Hide()
	end
end

-- Moving ---------------------------------------------------------------------------------------------

local function FinishMoving()
	if mover.isMoving then
		mover.isMoving = false
		local holder = ns.testHolder
		holder:StopMovingOrSizing()
		holder:SetUserPlaced(false)
		SavePosition(holder, ns.db.layout)
		ns.ApplyPlacement()
	end
end

function ns.UpdateMover()
	mover:SetShown(not ns.IsLocked() and not InCombatLockdown())
end

function ns.IsLocked()
	return ns.db.locked
end

function ns.SetLocked(locked)
	ns.db.locked = locked
	ns.UpdateTestFrames()
	ns.UpdateMover()
end

local function CreateMover()
	local holder = ns.testHolder
	mover = CreateFrame("Frame", nil, holder)
	mover:SetAllPoints()
	mover:SetFrameStrata("MEDIUM")
	mover:EnableMouse(true)
	mover:RegisterForDrag("LeftButton")
	holder:SetMovable(true)

	local tint = ns.CreateArt(mover, "BACKGROUND", "Flat")
	tint:SetAllPoints()
	tint:SetVertexColor(0.15, 0.45, 1, 0.3)

	local label = ns.CreateText(mover, ns.Text.mover.size)
	label:SetPoint("BOTTOM", mover, "TOP", 0, 6)
	label:SetText(ns.ADDON_TITLE .. ": drag to move")

	mover:SetScript("OnDragStart", function(self)
		self.isMoving = true
		holder:StartMoving()
	end)
	mover:SetScript("OnDragStop", FinishMoving)
	mover:Hide()
end

-- Setup -------------------------------------------------------------------------------------------------

local function CreateRangeTicker()
	C_Timer.NewTicker(0.25, function()
		for _, member in ipairs(members) do
			if member.root:IsVisible() then
				ns.UpdateRange(member.v, member.unit)
			end
		end
	end)
end

function ns.CreateGroup()
	group = CreateFrame("Frame", "DibsUIPartyGroup", UIParent)
	ns.AddHolder(group)
	ns.group = group
	for i = 1, 4 do
		members[i] = CreateMember(i, "party" .. i, "partypet" .. i)
		RegisterUnitWatch(members[i].root)
	end
	members[5] = CreateMember("Player", "player", "pet")
	members[5].root:Hide()
	ns.members = members
	RegisterStateDriver(group, "visibility", "[group:raid] hide; show")

	local events = CreateFrame("Frame")
	events:RegisterEvent("GROUP_ROSTER_UPDATE")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("PARTY_LEADER_CHANGED")
	events:RegisterEvent("PLAYER_ROLES_ASSIGNED")
	events:RegisterEvent("RAID_TARGET_UPDATE")
	events:RegisterEvent("READY_CHECK")
	events:RegisterEvent("READY_CHECK_CONFIRM")
	events:RegisterEvent("READY_CHECK_FINISHED")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			-- Fires just before the lockdown, so the test frames can still give way to the real ones.
			if mover.isMoving then
				FinishMoving()
			end
			ns.HideTestFramesForCombat()
			mover:Hide()
			return
		elseif event == "PLAYER_REGEN_ENABLED" then
			if pendingLayout then
				ns.RequestLayout()
			end
			ns.UpdateTestFrames()
			ns.UpdateMover()
			return
		end
		for _, member in ipairs(members) do
			if event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
				if UnitExists(member.unit) then
					ns.UpdateReadyCheck(member.v, member.unit, event == "READY_CHECK_FINISHED")
				end
			else
				UpdateMember(member)
			end
		end
		if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
			for _, member in ipairs(members) do
				ns.RefreshAuraContainers(member.auras)
			end
			ns.RequestLayout()
		end
	end)
	CreateRangeTicker()
end

-- At login: the real members' buffs and debuffs, then their caps and places.
function ns.CreateMemberAuras()
	for _, member in ipairs(members) do
		ns.CreateAuraContainers(member.auras)
	end
	ns.RequestLayout()
end

function ns.CreateGroupMover()
	CreateMover()
	ns.RequestLayout()
end

-- After a setting that changes how members draw, such as class icons.
function ns.RefreshMembers()
	for _, member in ipairs(members) do
		UpdateMember(member)
	end
	ns.UpdateTestFrames()
end

local addonName, ns = ...

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

function ns.Media(name)
	return MEDIA .. name
end

ns.ADDON_TITLE = "DibsUI-Party"

-- Every party frame is drawn with DibsUI's own numbers and art, in the same units, then the whole group
-- is scaled down by Layout.scale. Distances are from the orb centre, with y pointing up.
ns.Layout = {
	scale = 0.45,

	orbQuad = 160, -- size of every orb texture, as in DibsUI
	orbRadius = 53.5, -- the well inside the ring, where DibsUI's liquid is and the portrait goes
	orbReach = 75, -- the rim's outer edge with its shadow, for spacing frames

	-- The health bar is DibsUI's target health bar, the power bar art is DibsUI's target power bar, used
	-- for the pet. Both are drawn from the orb centre and cut in three for the Width setting, like DibsUI.
	-- Where the art starts and where it's cut (DibsUI's BAR_ART), in frame units from the texture's start:
	barArt = { width = 320, sliceInner = 75, sliceTip = 165 },
	-- yCenter/height/tip: the visible outline. fillInner/fillOuter: StatusBar span from the orb centre.
	-- fillHeight: inside the double border. capWidth: how far the slanted cap reaches past the fill.
	-- quadHeight: the art's height. The health bar is DibsUI's stretched to 1.5 times its height: art,
	-- outline and fill all stretch together, so the slanted caps still match the art's slant.
	health = {
		yCenter = 12, height = 51, quadHeight = 60, tip = 245, hitInner = 52,
		fillInner = 68, fillOuter = 224.59, fillHeight = 39, capWidth = 13.76, wedgeWidth = 14, wedgeArt = "BarFillInner",
		back = "BarHealthBack", frame = "BarHealthFrame",
	},
	-- 3 units under the health bar, like DibsUI's target power bar under its health bar.
	pet = {
		yCenter = -25.5, height = 18, quadHeight = 40, tip = 188, hitInner = 66,
		fillInner = 70, fillOuter = 176.66, fillHeight = 12, capWidth = 6.35,
		back = "BarPowerBack", frame = "BarPowerFrame",
	},

	-- Buffs sit under the bars, clear of the orb, and wrap after this many rows.
	buffSize = 36,
	buffSpacing = 4,
	buffRows = 2,
	buffGap = 6, -- between the lowest bar and the first row
	buffLeft = 75, -- from the orb centre, so the first icon clears the rim
	-- Debuffs sit past the bar's tip, one row level with the health bar and as tall as it.
	debuffSize = 51,
	debuffSpacing = 6,
	debuffGap = 10, -- from the bar's tip
	debuffMax = 4,

	frameGap = 14, -- between one member's space and the next
	nameRoom = 34, -- the name's height above the health bar, for the frame's top edge
}

-- Text sizes are in the frame's units, so they shrink with Layout.scale. 30 is about 13 px on screen.
ns.Text = {
	font = "Fonts\\FRIZQT__.TTF",
	defaultFont = ns.Media("Fonts\\BarlowSemiCondensed-Black.ttf"),
	outline = "OUTLINE",
	name = { size = 30, x = 0, y = 4 }, -- BOTTOM of the name to the TOP of the health bar
	health = { size = 26, x = -22, y = 0 }, -- RIGHT of the text to the RIGHT of the health bar
	lead = { scale = 1.4, x = -3, y = -1 }, -- the percent before the value, larger
	petName = { size = 22, x = 0, y = 0 }, -- CENTER of the pet bar, on mouseover
	status = { size = 28, x = -22, y = 0 },
	level = { size = 26, x = 54, y = 54 }, -- CENTER of the level to the orb centre: the top right of the rim -- "Dead", "Offline" in place of the health text
	auraTime = { size = 20 },
	mover = { size = 28 },
}

-- 999, 1.2k, 12k, 1.2m: the client does the shortening, since the numbers can be secret.
local ABBREVIATE_OPTIONS = {
	breakpointData = {
		{ breakpoint = 10000000, abbreviation = "m", significandDivisor = 1000000, fractionDivisor = 1, abbreviationIsGlobal = false },
		{ breakpoint = 1000000, abbreviation = "m", significandDivisor = 100000, fractionDivisor = 10, abbreviationIsGlobal = false },
		{ breakpoint = 10000, abbreviation = "k", significandDivisor = 1000, fractionDivisor = 1, abbreviationIsGlobal = false },
		{ breakpoint = 1000, abbreviation = "k", significandDivisor = 100, fractionDivisor = 10, abbreviationIsGlobal = false },
	},
}

function ns.Shorten(value)
	return AbbreviateNumbers(value, ABBREVIATE_OPTIONS)
end

ns.Colors = {
	disabled = { 0.50, 0.50, 0.50 },
	petHealth = { 0.20, 0.80, 0.28 },
	unknownPower = { 0.70, 0.70, 0.70 },
	-- DibsUI's: PowerBarColor's mana and energy are pure primaries, which turn muddy under the glass.
	power = {
		MANA = { 0.15, 0.45, 1.00 },
		RAGE = { 0.90, 0.15, 0.10 },
		ENERGY = { 1.00, 0.85, 0.20 },
	},
	-- Debuff borders by dispel type, Blizzard's own colors.
	dispel = {
		Magic = { 0.20, 0.60, 1.00 },
		Curse = { 0.60, 0.00, 1.00 },
		Disease = { 0.60, 0.40, 0.00 },
		Poison = { 0.00, 0.60, 0.00 },
		none = { 0.80, 0.00, 0.00 },
	},
}

function ns.GetPowerColor(powerToken)
	local color = ns.Colors.power[powerToken]
	if color then
		return color[1], color[2], color[3]
	end
	local info = PowerBarColor and powerToken and PowerBarColor[powerToken]
	if info then
		return info.r, info.g, info.b
	end
	color = ns.Colors.unknownPower
	return color[1], color[2], color[3]
end

-- nil if the class can't be read.
function ns.GetClassColor(classFile)
	if issecretvalue(classFile) or classFile == nil then
		return nil
	end
	return RAID_CLASS_COLORS[classFile]
end

-- A texture that stays crisp at any UI scale instead of snapping to the pixel grid.
function ns.CreateArt(parent, layer, fileName)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetTexture(ns.Media(fileName))
	texture:SetSnapToPixelGrid(false)
	texture:SetTexelSnappingBias(0)
	return texture
end

function ns.Print(message)
	print("|cffffd100" .. ns.ADDON_TITLE .. "|r: " .. message)
end

-- Blizzard's party frames ---------------------------------------------------------------------------

local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()

-- Blizzard's own party frames and its raid-style ones both go under a hidden parent, as DibsUI does
-- with the target frame. The raid-style frame is made the first time it's needed, so it's caught then.
local function HideCompactParty()
	if CompactPartyFrame and CompactPartyFrame:GetParent() ~= hiddenParent then
		CompactPartyFrame:SetParent(hiddenParent)
	end
end

-- Blizzard's raid frame manager, the tab at the left edge of the screen, shows whenever you're in a
-- group. In a party these frames replace it, so it's hidden there. In a raid the party frames hide and
-- Blizzard's raid frames take over, so it's left to show. It isn't a protected frame, so hiding it
-- works in combat too. Blizzard_CompactRaidFrames may load later than this addon, so it's caught then.
local function HideRaidManagerInParty()
	if CompactRaidFrameManager and not IsInRaid() then
		CompactRaidFrameManager:Hide()
	end
end

local function HookRaidManager()
	if ns.hookedRaidManager or not CompactRaidFrameManager_UpdateShown then
		return
	end
	ns.hookedRaidManager = true
	hooksecurefunc("CompactRaidFrameManager_UpdateShown", HideRaidManagerInParty)
	HideRaidManagerInParty()
end

local function HideBlizzardPartyFrames()
	if PartyFrame then
		PartyFrame:SetParent(hiddenParent)
	end
	HideCompactParty()
	HookRaidManager()
	if CompactPartyFrame_Generate and not ns.hookedCompactParty then
		ns.hookedCompactParty = true
		hooksecurefunc("CompactPartyFrame_Generate", function()
			if InCombatLockdown() then
				ns.hidePartyAfterCombat = true
			else
				HideCompactParty()
			end
		end)
	end
end

-- Startup -------------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "Blizzard_CompactRaidFrames" then
			HookRaidManager()
		elseif arg1 == addonName then
			ns.LoadSettings()
			ns.CreateGroup()
			ns.CreateTestFrames()
		end
	elseif event == "PLAYER_LOGIN" then
		ns.CreateMemberAuras()
		ns.CreateLook()
		if InCombatLockdown() then
			ns.hidePartyAfterCombat = true
		else
			HideBlizzardPartyFrames()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if ns.hidePartyAfterCombat then
			ns.hidePartyAfterCombat = false
			HideBlizzardPartyFrames()
		end
	end
end)

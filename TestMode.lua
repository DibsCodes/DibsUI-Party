local _, ns = ...

local Layout = ns.Layout

-- Sample members for setting the frames up alone. They show while "Show test frames" is on or the
-- frames are unlocked, in place of the real group, and go away when combat starts. Nothing here is
-- saved: the switch is off after a /reload.

local ICONS = "Interface\\Icons\\"

local BUFFS = {
	fortitude = { name = "Power Word: Fortitude", icon = ICONS .. "Spell_Holy_WordFortitude", duration = 1800, remaining = 1514 },
	renew = { name = "Renew", icon = ICONS .. "Spell_Holy_Renew", duration = 15, remaining = 11 },
	shield = { name = "Power Word: Shield", icon = ICONS .. "Spell_Holy_PowerWordShield", duration = 30, remaining = 24 },
	rejuv = { name = "Rejuvenation", icon = ICONS .. "Spell_Nature_Rejuvenation", duration = 12, remaining = 5 },
	motw = { name = "Mark of the Wild", icon = ICONS .. "Spell_Nature_Regeneration", duration = 1800, remaining = 960 },
	intellect = { name = "Arcane Intellect", icon = ICONS .. "Spell_Holy_MagicalSentry", duration = 1800, remaining = 1200 },
	shadowProt = { name = "Shadow Protection", icon = ICONS .. "Spell_Shadow_AntiShadow", duration = 600, remaining = 412 },
	might = { name = "Blessing of Might", icon = ICONS .. "Spell_Holy_FistOfJustice", duration = 300, remaining = 212 },
}

local DEBUFFS = {
	corruption = { name = "Corruption", icon = ICONS .. "Spell_Shadow_AbominationExplosion", duration = 18, remaining = 13, dispel = "Magic" },
	agony = { name = "Curse of Agony", icon = ICONS .. "Spell_Shadow_CurseOfSargeras", duration = 24, remaining = 20, dispel = "Curse" },
	poison = { name = "Deadly Poison", icon = ICONS .. "Ability_Rogue_DualWeild", duration = 12, remaining = 7, count = 3, dispel = "Poison" },
	plague = { name = "Plague", icon = ICONS .. "Spell_Shadow_CallofBone", duration = 180, remaining = 140, dispel = "Disease" },
	hamstring = { name = "Hamstring", icon = ICONS .. "Ability_ShockWave", duration = 15, remaining = 4 },
	rend = { name = "Rend", icon = ICONS .. "Ability_Gouge", duration = 21, remaining = 12 },
}

local PORTRAITS = "Interface\\CharacterFrame\\TemporaryPortrait-"

local SAMPLES = {
	{
		name = "Gorvak", surname = "Ironhide", level = 60, class = "WARRIOR", health = 0.82, maxHealth = 18400, power = 0.45, powerToken = "RAGE",
		absorb = 0.08, leader = true, role = "TANK", portrait = PORTRAITS .. "Male-Orc",
		buffs = { BUFFS.fortitude, BUFFS.shield, BUFFS.renew, BUFFS.motw },
		debuffs = { DEBUFFS.rend, DEBUFFS.agony },
	},
	{
		name = "Selwyn", surname = "Ashford", level = 60, class = "PRIEST", health = 0.64, maxHealth = 12100, power = 0.72, powerToken = "MANA",
		heal = 0.18, role = "HEALER", ready = "ready", portrait = PORTRAITS .. "Female-Human",
		buffs = { BUFFS.fortitude, BUFFS.renew, BUFFS.motw, BUFFS.intellect, BUFFS.shadowProt, BUFFS.might },
		debuffs = { DEBUFFS.corruption },
	},
	{
		name = "Kestra", level = 59, class = "ROGUE", health = 0.38, maxHealth = 13900, power = 0.9, powerToken = "ENERGY",
		role = "DAMAGER", marker = 8, portrait = PORTRAITS .. "Female-NightElf",
		buffs = { BUFFS.fortitude },
		debuffs = { DEBUFFS.poison, DEBUFFS.plague, DEBUFFS.agony, DEBUFFS.hamstring },
	},
	{
		name = "Varrok", level = 57, class = "HUNTER", health = 0.95, maxHealth = 14800, power = 0.55, powerToken = "MANA",
		role = "DAMAGER", outOfRange = true, portrait = PORTRAITS .. "Male-Tauren",
		pet = { name = "Fang", health = 0.7 },
		buffs = { BUFFS.fortitude, BUFFS.motw },
		debuffs = {},
	},
}

local holder
local testMembers = {}
local testModeOn = false

local function CreateTestMember(index)
	local root = CreateFrame("Frame", nil, holder)
	root:EnableMouse(true)

	local origin = CreateFrame("Frame", nil, root)
	origin:SetSize(1, 1)
	origin:SetPoint("CENTER", root, "LEFT", Layout.orbReach, 0)

	local member = { root = root, origin = origin, index = index }
	member.v = ns.CreateVisual(root, origin, root)

	local spec = Layout.pet
	local petRoot = CreateFrame("Frame", nil, root)
	petRoot:SetFrameLevel(root:GetFrameLevel() + 30)
	petRoot:SetPoint("LEFT", root, "LEFT", Layout.orbReach + spec.hitInner, spec.yCenter)
	petRoot:EnableMouse(true)
	member.petRoot = petRoot
	member.pet = ns.CreatePetVisual(petRoot, origin)
	ns.SizeMember(member)

	member.auras = ns.CreateAuras(root, origin)
	return member
end

-- The player's sample uses the real name, class and portrait.
local function GetPlayerSample()
	local _, classFile = UnitClass("player")
	local _, powerToken = UnitPowerType("player")
	return {
		unit = "player", name = UnitName("player"), surname = select(2, UnitName("player")), class = classFile, health = 0.9, maxHealth = 15000,
		power = 0.6, powerToken = powerToken,
		buffs = { BUFFS.fortitude, BUFFS.might }, debuffs = { DEBUFFS.corruption },
	}
end

local function GetSamples()
	local samples = {}
	for i, sample in ipairs(SAMPLES) do
		samples[i] = sample
	end
	if ns.db.showPlayer then
		samples[#samples + 1] = GetPlayerSample()
	end
	return samples
end

function ns.AreTestFramesShown()
	return holder ~= nil and holder:IsShown()
end

function ns.LayoutTestFrames()
	if not holder then
		return
	end
	local samples = GetSamples()
	local list = {}
	for i, member in ipairs(testMembers) do
		local sample = samples[i]
		member.root:SetShown(sample ~= nil)
		if sample then
			member.hasPet = sample.pet ~= nil
			member.petRoot:SetShown(member.hasPet)
			ns.PlaceAuras(member.auras, member.hasPet)
			list[#list + 1] = member
		end
	end
	ns.LayoutMembers(holder, list)
	ns.ApplyPlacement()
end

local function ShowSamples()
	local samples = GetSamples()
	for i, member in ipairs(testMembers) do
		local sample = samples[i]
		if sample then
			ns.ShowTestVisual(member.v, sample)
			if sample.pet then
				ns.ShowTestPet(member.pet, sample.pet)
			end
			ns.ShowTestAuras(member.auras, sample.buffs, sample.debuffs)
		end
	end
end

-- Shown while the switch is on or the frames are unlocked, out of combat.
function ns.UpdateTestFrames()
	if not holder or InCombatLockdown() then
		return
	end
	local shown = testModeOn or not ns.IsLocked()
	if shown then
		ns.LayoutTestFrames()
		ShowSamples()
	end
	holder:SetShown(shown)
	ns.SetRealGroupShown(not shown)
end

function ns.IsTestModeOn()
	return testModeOn
end

function ns.SetTestMode(on)
	testModeOn = on
	ns.UpdateTestFrames()
end

-- Combat ends test mode. The unlocked state stays, and the frames show again after combat.
function ns.HideTestFramesForCombat()
	testModeOn = false
	if holder and holder:IsShown() then
		holder:Hide()
		ns.SetRealGroupShown(true)
	end
	if ns.OnTestModeChanged then
		ns.OnTestModeChanged()
	end
end

function ns.CreateTestFrames()
	holder = CreateFrame("Frame", "DibsUIPartyTestGroup", UIParent)
	ns.AddHolder(holder)
	holder:Hide()
	ns.testHolder = holder
	for i = 1, #SAMPLES + 1 do
		testMembers[i] = CreateTestMember(i)
	end
	ns.CreateGroupMover()
	ns.UpdateTestFrames()
end

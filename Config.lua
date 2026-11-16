local _, ns = ...

local W = DibsUIOptions.Widgets

-- The settings: one page, "Party Frames", a tab in DibsUI-Options' window (registered in Settings.lua).

-- Setters ---------------------------------------------------------------------------------------------

function ns.SetShowPlayer(shown)
	ns.db.showPlayer = shown
	ns.RequestLayout()
	ns.UpdateTestFrames()
end

-- The bars' length. Their click areas follow after combat if it changes then (it's locked in combat).
function ns.SetWidth(width)
	if InCombatLockdown() then
		return
	end
	ns.db.width = math.min(math.max(width, ns.WidthRange.min), ns.WidthRange.max)
	ns.LayoutAllBars()
	ns.RequestLayout()
	ns.RefreshMembers() -- names fit their new width
end

function ns.SetClassIcons(on)
	ns.db.classIcons = on
	ns.RefreshMembers()
end

function ns.SetHealthMouseover(on)
	ns.db.healthMouseover = on
	ns.RefreshMembers()
end

function ns.SetBuffsShown(shown)
	ns.db.showBuffs = shown
	ns.RequestLayout()
	ns.UpdateTestFrames()
end

function ns.SetDebuffsShown(shown)
	ns.db.showDebuffs = shown
	ns.RequestLayout()
	ns.UpdateTestFrames()
end

-- The page --------------------------------------------------------------------------------------------

-- Builds the Party Frames page into content. Returns { Sync, SetCombatLocked, Layout }, as DibsUI-Options
-- expects of a tab.
function ns.BuildPartyPage(content)
	local framesCard = W.CreateCard(content, "Party frames")
	local test = framesCard:Add(W.CreateToggleRow(framesCard, "Show test frames", ns.SetTestMode))
	local player = framesCard:Add(W.CreateToggleRow(framesCard, "Show player in party", ns.SetShowPlayer))
	local classIcons = framesCard:Add(W.CreateToggleRow(framesCard, "Class icon portraits", ns.SetClassIcons))
	local layoutRow = framesCard:Add(W.CreateDropdownRow(framesCard, "Layout"), 4)
	local scale = framesCard:Add(W.CreateSliderRow(framesCard, "Scale", ns.ScaleRange,
		function(value) return string.format("%.2f", value) end,
		function() return ns.db.scale end, ns.SetScale), 4)
	local width = framesCard:Add(W.CreateSliderRow(framesCard, "Health bar width", ns.WidthRange,
		function(value) return string.format("%.2f", value) end,
		function() return ns.db.width end, ns.SetWidth), 4)
	framesCard:Add(W.CreateHint(framesCard,
		"Press Unlock frames at the top of this window to drag the party frames. Test frames show while they're unlocked."), 8)

	W.SetUpChoiceMenu(layoutRow.dropdown, ns.Layouts,
		function() return ns.db.layout end,
		function(key)
			ns.SetLayout(key)
			layoutRow.dropdown:GenerateMenu()
		end)

	local textCard = W.CreateCard(content, "Health text")
	local mouseover = textCard:Add(W.CreateToggleRow(textCard, "Show only on mouseover", ns.SetHealthMouseover))
	textCard:Add(W.CreateHint(textCard, "The health bar shows percent and value, like \"84% - 12.4k\"."), 4)

	local aurasCard = W.CreateCard(content, "Buffs & debuffs")
	local buffs = aurasCard:Add(W.CreateToggleRow(aurasCard, "Show buffs", ns.SetBuffsShown))
	local debuffs = aurasCard:Add(W.CreateToggleRow(aurasCard, "Show debuffs", ns.SetDebuffsShown))
	aurasCard:Add(W.CreateHint(aurasCard,
		"Buffs: the ones you cast, under each frame, up to two rows. Debuffs: all of them, dispellable ones first, up to four beside each frame."), 6)

	local options = {}

	function options.Sync()
		test.toggle:SetChecked(ns.IsTestModeOn())
		player.toggle:SetChecked(ns.db.showPlayer)
		classIcons.toggle:SetChecked(ns.db.classIcons)
		layoutRow.dropdown:GenerateMenu()
		scale:Sync()
		width:Sync()
		mouseover.toggle:SetChecked(ns.db.healthMouseover)
		buffs.toggle:SetChecked(ns.db.showBuffs)
		debuffs.toggle:SetChecked(ns.db.showDebuffs)
	end

	-- Anything that moves the secure click areas waits for combat to end.
	function options.SetCombatLocked(locked)
		for _, control in ipairs({ test, player, layoutRow, scale, width, buffs, debuffs }) do
			control:SetEnabled(not locked)
		end
	end

	-- Combat turns test mode off, so the switch follows.
	ns.OnTestModeChanged = function()
		test.toggle:SetChecked(ns.IsTestModeOn())
	end

	options.Layout = W.CreateFlow(content, { framesCard, textCard, aurasCard })
	return options
end


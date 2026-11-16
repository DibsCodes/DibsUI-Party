local _, ns = ...

-- The layouts, in the order the settings list them. anchor is the corner of the group that stays put
-- when frames come and go, and when switching layouts.
ns.Layouts = {
	{ key = "down", label = "Vertical, grow down", anchor = "TOPLEFT", axis = "vertical", sign = -1 },
	{ key = "up", label = "Vertical, grow up", anchor = "BOTTOMLEFT", axis = "vertical", sign = 1 },
	{ key = "right", label = "Horizontal, grow right", anchor = "TOPLEFT", axis = "horizontal", sign = 1 },
	{ key = "left", label = "Horizontal, grow left", anchor = "TOPRIGHT", axis = "horizontal", sign = -1 },
	{ key = "center", label = "Horizontal, centered", anchor = "TOP", axis = "horizontal", sign = 0 },
}

ns.LayoutsByKey = {}
for _, layout in ipairs(ns.Layouts) do
	ns.LayoutsByKey[layout.key] = layout
end

ns.ScaleRange = { min = 0.5, max = 2, step = 0.05 }
-- Shorter than 0.75 leaves no room for "84% - 12.4k" and the name.
ns.WidthRange = { min = 0.75, max = 2, step = 0.05 }

-- The party settings: DibsUI-Party's table in the DibsUI-Options profile this character uses.
local DEFAULTS = {
	showBuffs = true,
	showDebuffs = true,
	showPlayer = false,
	classIcons = false,
	healthMouseover = false,
	layout = "down",
	scale = 1,
	width = 1, -- the health and pet bars' length, as a multiple of DibsUI's
	locked = true,
	-- The layout's anchor corner, relative to the same corner of the screen, in UIParent units.
	point = "TOPLEFT",
	x = 24,
	y = -200,
}

local VALID_POINTS = {
	TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true,
	BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

function ns.CleanSettings(settings)
	if type(settings) ~= "table" then
		settings = {}
	end
	for key, default in pairs(DEFAULTS) do
		if type(settings[key]) ~= type(default) then
			settings[key] = default
		end
	end
	settings.scale = math.min(math.max(settings.scale, ns.ScaleRange.min), ns.ScaleRange.max)
	settings.width = math.min(math.max(settings.width, ns.WidthRange.min), ns.WidthRange.max)
	if not ns.LayoutsByKey[settings.layout] then
		settings.layout = DEFAULTS.layout
	end
	if not VALID_POINTS[settings.point] then
		settings.point, settings.x, settings.y = DEFAULTS.point, DEFAULTS.x, DEFAULTS.y
	end
	return settings
end

ns.MODULE_KEY = "DibsUI-Party"

-- Registers with DibsUI-Options, which holds the profiles and the settings window. The Party Frames
-- tab is built by Config.lua. Called at ADDON_LOADED, once every file has loaded.
function ns.LoadSettings()
	local options = DibsUIOptions
	options:RegisterModule({
		key = ns.MODULE_KEY,
		addon = ns.ADDON_TITLE,
		title = ns.ADDON_TITLE,
		order = 20,
		slash = "party", -- /dui party
		cleanProfile = ns.CleanSettings,
		tabs = { { label = "Party Frames", build = ns.BuildPartyPage } },
		onProfileChanged = function(settings)
			ns.db = settings
			ns.ApplyProfile()
		end,
		isLocked = function()
			return ns.IsLocked()
		end,
		setLocked = function(locked)
			ns.SetLocked(locked)
		end,
	})
	ns.db = options:GetProfile(ns.MODULE_KEY)
end

-- After a profile switch (never in combat): every size, place and look from the new settings.
function ns.ApplyProfile()
	ns.LayoutAllBars()
	ns.RequestLayout()
	ns.ApplyPlacement()
	ns.UpdateLook()
end

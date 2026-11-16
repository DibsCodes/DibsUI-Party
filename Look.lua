local _, ns = ...

-- With DibsUI installed, the party frames follow its master font and last names, read from DibsUI's
-- table in the same profile. Alone, they use DibsUI's font and no last names. DibsUI says when either
-- changes (DibsUI-Options' "SettingsChanged"), and a profile switch re-reads them. Heal prediction and
-- opacity are the party frames' own: prediction always shows, and members fade only when out of range.

local look = {
	font = nil, -- nil for the bundled font
	surnames = false,
}

local function ReadDibsUI()
	if not C_AddOns.IsAddOnLoaded("DibsUI") then
		return nil
	end
	local ok, settings = pcall(DibsUIOptions.GetProfile, DibsUIOptions, "DibsUI")
	return ok and type(settings) == "table" and settings or nil
end

local function ReadLook()
	local dibs = ReadDibsUI()
	look.font = dibs and type(dibs.masterFont) == "string" and dibs.masterFont or nil
	look.surnames = dibs ~= nil and dibs.showSurnames == true
end

function ns.GetFont()
	return look.font or ns.Text.defaultFont
end

function ns.ShowSurnames()
	return look.surnames
end

function ns.ShowHealPrediction()
	return true
end

-- Reads DibsUI's settings again and redraws what follows them.
function ns.UpdateLook()
	ReadLook()
	ns.RefreshFonts()
	ns.RestyleAuras()
	ns.RefreshMembers()
end

-- At login, when every addon has loaded.
function ns.CreateLook()
	if DibsUIOptions.RegisterCallback then
		DibsUIOptions:RegisterCallback("SettingsChanged", function(key)
			if key == "DibsUI" then
				ns.UpdateLook()
			end
		end)
	end
	ns.UpdateLook()
end

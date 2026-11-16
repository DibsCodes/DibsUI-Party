local _, ns = ...

-- Every font string, with its size, so a font change reaches them all.
local texts = {}

-- A font that's gone falls back to the game's.
local function ApplyFont(text)
	if not text:SetFont(ns.GetFont(), text.size, ns.Text.outline) then
		text:SetFont(ns.Text.font, text.size, ns.Text.outline)
	end
end

function ns.CreateText(parent, size, layer)
	local text = parent:CreateFontString(nil, layer or "OVERLAY")
	text:SetWordWrap(false)
	text.size = size
	ApplyFont(text)
	text:SetTextColor(1, 1, 1)
	texts[#texts + 1] = text
	return text
end

function ns.RefreshFonts()
	for _, text in ipairs(texts) do
		ApplyFont(text)
	end
end

-- Last names, as DibsUI shows them: off-white, 20% smaller, after the first name.
local SURNAME_SCALE = 0.8
local SURNAME_COLOR = { 0.88, 0.87, 0.82 }
local NAME_GAP = 4

function ns.CreateSurnameText(parent, nameText)
	local surname = ns.CreateText(parent, math.floor(nameText.size * SURNAME_SCALE + 0.5))
	surname:SetTextColor(SURNAME_COLOR[1], SURNAME_COLOR[2], SURNAME_COLOR[3])
	surname:SetPoint("BOTTOMLEFT", nameText, "BOTTOMRIGHT", NAME_GAP, 0)
	surname:Hide()
	return surname
end

-- The name centred in its box, or "First Last" when DibsUI's Last names setting is on. Both come straight
-- from UnitName. Centring the pair means measuring it, which can't be done while the text is secret,
-- so then only the first name shows. Party frames are narrow, so unlike DibsUI the last name is left
-- out when the pair won't fit, rather than cutting the first name short.
function ns.ShowName(text, name, surname)
	local box = text.box
	text:ClearAllPoints()
	local useRow = ns.ShowSurnames() and not issecretvalue(name) and not issecretvalue(surname)
		and type(name) == "string" and type(surname) == "string" and surname ~= ""
	if useRow then
		text:SetText(name)
		text.surname:SetText(surname)
		local nameWidth, surnameWidth = text:GetUnboundedStringWidth(), text.surname:GetUnboundedStringWidth()
		local boxWidth = box:GetWidth()
		if issecretvalue(nameWidth) or issecretvalue(surnameWidth) or issecretvalue(boxWidth) then
			useRow = false
		else
			local total = nameWidth + NAME_GAP + surnameWidth
			if boxWidth > 0 and total > boxWidth then
				useRow = false
			else
				text:SetWidth(nameWidth)
				text:SetPoint("BOTTOMLEFT", box, "BOTTOM", -total / 2, 0)
			end
		end
	end
	if not useRow then
		text:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT")
		text:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT")
		text:SetText(name)
	end
	text.surname:SetShown(useRow)
end

-- Health text: "84%" larger, then "- 12.4k", like DibsUI's target bar. Placed at the bar's right end.
function ns.CreateHealthText(parent, anchor)
	local spec, leadSpec = ns.Text.health, ns.Text.lead
	local value = ns.CreateText(parent, spec.size)
	value:SetPoint("RIGHT", anchor, "RIGHT", spec.x, spec.y)
	local lead = ns.CreateText(parent, math.floor(spec.size * leadSpec.scale + 0.5))
	lead:SetPoint("BOTTOMRIGHT", value, "BOTTOMLEFT", leadSpec.x, leadSpec.y)
	value.lead = lead

	-- "Dead", "Ghost" or "Offline", in place of the numbers.
	local status = ns.CreateText(parent, ns.Text.status.size)
	status:SetPoint("RIGHT", anchor, "RIGHT", ns.Text.status.x, ns.Text.status.y)
	status:SetTextColor(0.75, 0.75, 0.75)
	value.status = status
	return value
end

-- Health can be secret, so it only goes into the client's formatting.
function ns.ShowHealth(text, unit)
	text:SetText("- " .. ns.Shorten(UnitHealth(unit)))
	text.lead:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
end

function ns.ShowTestHealth(text, percent, value)
	text:SetText("- " .. ns.Shorten(value))
	text.lead:SetFormattedText("%.0f%%", percent)
end

-- Shows the numbers, a status word, or nothing (mouseover only and not hovered).
function ns.SetHealthTextState(text, status, hovered)
	local showNumbers = status == nil and (hovered or not ns.db.healthMouseover)
	text:SetShown(showNumbers)
	text.lead:SetShown(showNumbers)
	text.status:SetShown(status ~= nil)
	text.status:SetText(status or "")
end

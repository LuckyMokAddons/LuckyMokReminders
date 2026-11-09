local _, Private = ...
local L = Private.L

local floor = math.floor
local gmatch = string.gmatch
local ipairs = ipairs
local strlower = string.lower
local strtrim = strtrim
local tinsert = table.insert
local tonumber = tonumber

local CreateFrame = CreateFrame
local CreateMinimalSliderFormatter = CreateMinimalSliderFormatter
local DoesSpellExist = C_Spell.DoesSpellExist
local GetInventoryItemTexture = GetInventoryItemTexture
local GetSpellName = C_Spell.GetSpellName
local GetSpellTexture = C_Spell.GetSpellTexture
local InCombatLockdown = InCombatLockdown
local Settings = Settings

local ColorPickerFrame = ColorPickerFrame
local MinimalSliderWithSteppersMixin = MinimalSliderWithSteppersMixin
local INVSLOT_MAINHAND = INVSLOT_MAINHAND
local INVSLOT_OFFHAND = INVSLOT_OFFHAND

local widgets = {}

local function CreateTitle(parent, text, template)
	local title = parent:CreateFontString(nil, 'ARTWORK', template or 'GameFontNormal')
	title:SetText(text)
	return title
end

local function CreateCheckbox(parent, label, get, set)
	local check = CreateFrame('CheckButton', nil, parent, 'UICheckButtonTemplate')
	check:SetSize(26, 26)
	check.Text:SetFontObject('GameFontHighlight')
	check.Text:SetText(label)
	check:SetScript('OnClick', function(self) set(self:GetChecked()) end)
	check.Refresh = function(self) self:SetChecked(get()) end
	tinsert(widgets, check)
	return check
end

local function CreateSlider(parent, label, minValue, maxValue, step, get, set)
	local frame = CreateFrame('Frame', nil, parent)
	frame:SetSize(260, 46)

	local title = CreateTitle(frame, label)
	title:SetPoint('TOPLEFT')

	local slider = CreateFrame('Frame', nil, frame, 'MinimalSliderWithSteppersTemplate')
	slider:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', -4, -2)
	slider:SetSize(240, 24)
	slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
		value = floor(value / step + 0.5) * step
		if value ~= get() then
			set(value)
		end
	end, frame)

	local formatters = { [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right) }
	frame.Refresh = function() slider:Init(get(), minValue, maxValue, (maxValue - minValue) / step, formatters) end
	tinsert(widgets, frame)
	return frame
end

local function CreateDropdown(parent, label, options, width, get, set)
	local frame = CreateFrame('Frame', nil, parent)
	frame:SetSize(width + 8, label and 50 or 26)

	local dropdown = CreateFrame('DropdownButton', nil, frame, 'WowStyle1DropdownTemplate')
	dropdown:SetWidth(width)

	if label then
		local title = CreateTitle(frame, label)
		title:SetPoint('TOPLEFT')
		dropdown:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -4)
	else
		dropdown:SetPoint('LEFT')
	end

	local function IsSelected(value) return get() == value end

	dropdown:SetupMenu(function(_, rootDescription)
		for _, option in ipairs(options) do
			rootDescription:CreateRadio(option.text, IsSelected, set, option.value)
		end
	end)

	frame.Refresh = function() dropdown:GenerateMenu() end
	tinsert(widgets, frame)
	return frame
end

local function CreateEditBox(parent, width, get, set)
	local box = CreateFrame('EditBox', nil, parent, 'InputBoxTemplate')
	box:SetSize(width, 20)
	box:SetAutoFocus(false)

	local function Commit(self)
		local text = strtrim(self:GetText())
		if text ~= get() then
			set(text)
		end
	end

	box:SetScript('OnEnterPressed', function(self) Commit(self) self:ClearFocus() end)
	box:SetScript('OnEscapePressed', function(self) self:SetText(get()) self:ClearFocus() end)
	box:HookScript('OnEditFocusLost', Commit)
	box.Refresh = function(self) self:SetText(get()) end
	tinsert(widgets, box)
	return box
end

local function CreateColorSwatch(parent, label, get, set)
	local button = CreateFrame('Button', nil, parent)
	button:SetSize(20, 20)

	local border = button:CreateTexture(nil, 'BACKGROUND')
	border:SetAllPoints()
	border:SetColorTexture(0.6, 0.6, 0.6)

	local swatch = button:CreateTexture(nil, 'ARTWORK')
	swatch:SetPoint('TOPLEFT', 1, -1)
	swatch:SetPoint('BOTTOMRIGHT', -1, 1)

	local text = button:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	text:SetPoint('LEFT', button, 'RIGHT', 6, 0)
	text:SetText(label)

	local function Apply(r, g, b)
		set(r, g, b)
		swatch:SetColorTexture(r, g, b)
	end

	button:SetScript('OnClick', function()
		local color = get()
		ColorPickerFrame:SetupColorPickerAndShow({
			r = color.r, g = color.g, b = color.b,
			swatchFunc = function() Apply(ColorPickerFrame:GetColorRGB()) end,
			cancelFunc = function(previous) Apply(previous.r, previous.g, previous.b) end,
		})
	end)

	button.Refresh = function()
		local color = get()
		swatch:SetColorTexture(color.r, color.g, color.b)
	end

	tinsert(widgets, button)
	return button
end

local function CreateButton(parent, text, width, onClick)
	local button = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
	button:SetSize(width, 22)
	button:SetText(text)
	button:SetScript('OnClick', onClick)
	return button
end

local function RefreshWidgets()
	for _, widget in ipairs(widgets) do
		widget:Refresh()
	end
end

local GrowthOptions = {
	{ value = 'RIGHT', text = L["Right"] },
	{ value = 'LEFT', text = L["Left"] },
	{ value = 'DOWN', text = L["Down"] },
	{ value = 'UP', text = L["Up"] },
}

local TextPositionOptions = {
	{ value = 'BOTTOM', text = L["Below"] },
	{ value = 'TOP', text = L["Above"] },
	{ value = 'LEFT', text = L["Left"] },
	{ value = 'RIGHT', text = L["Right"] },
	{ value = 'CENTER', text = L["Center"] },
}

local OutlineOptions = {
	{ value = 'NONE', text = L["None"] },
	{ value = 'OUTLINE', text = L["Outline"] },
	{ value = 'THICKOUTLINE', text = L["Thick Outline"] },
}

local function CreateGeneralPanel()
	local db = Private.db
	local panel = CreateFrame('Frame')

	local title = CreateTitle(panel, Private.Name, 'GameFontNormalLarge')
	title:SetPoint('TOPLEFT', 16, -16)

	local function Option(key)
		return function() return db[key] end, function(value) db[key] = value Private:UpdateStyle() end
	end

	local enable = CreateCheckbox(panel, L["Enable"], Option('enabled'))
	enable:SetPoint('TOPLEFT', 16, -50)

	-- SetUnlocked keeps the label in sync, the slash command toggles it too
	local lock = CreateButton(panel, Private.unlocked and L["Lock"] or L["Unlock"], 120, function() Private:SetUnlocked(not Private.unlocked) end)
	lock:SetPoint('TOPLEFT', 20, -84)
	Private.LockButton = lock

	local reset = CreateButton(panel, L["Reset Position"], 120, function() Private:ResetPosition() end)
	reset:SetPoint('LEFT', lock, 'RIGHT', 8, 0)

	local hideCombat = CreateCheckbox(panel, L["Hide in Combat"], Option('hideCombat'))
	hideCombat:SetPoint('TOPLEFT', 16, -116)

	local hideResting = CreateCheckbox(panel, L["Hide While Resting"], Option('hideResting'))
	hideResting:SetPoint('TOPLEFT', 16, -144)

	local hideTaxi = CreateCheckbox(panel, L["Hide on Flight Paths"], Option('hideTaxi'))
	hideTaxi:SetPoint('TOPLEFT', 16, -172)

	local growth = CreateDropdown(panel, L["Growth Direction"], GrowthOptions, 160, Option('growth'))
	growth:SetPoint('TOPLEFT', 20, -210)

	local iconSize = CreateSlider(panel, L["Icon Size"], 16, 80, 1, Option('iconSize'))
	iconSize:SetPoint('TOPLEFT', 20, -270)

	local spacing = CreateSlider(panel, L["Spacing"], 0, 30, 1, Option('spacing'))
	spacing:SetPoint('TOPLEFT', 20, -326)

	local textTitle = CreateTitle(panel, L["Text"], 'GameFontNormalLarge')
	textTitle:SetPoint('TOPLEFT', 330, -50)

	local showText = CreateCheckbox(panel, L["Show Text"], Option('showText'))
	showText:SetPoint('TOPLEFT', 326, -76)

	local position = CreateDropdown(panel, L["Text Position"], TextPositionOptions, 160, Option('textPosition'))
	position:SetPoint('TOPLEFT', 330, -110)

	local size = CreateSlider(panel, L["Font Size"], 6, 32, 1, Option('textSize'))
	size:SetPoint('TOPLEFT', 330, -170)

	local outline = CreateDropdown(panel, L["Font Outline"], OutlineOptions, 160, Option('textOutline'))
	outline:SetPoint('TOPLEFT', 330, -226)

	local width = CreateSlider(panel, L["Text Width"], 20, 200, 1, Option('textWidth'))
	width:SetPoint('TOPLEFT', 330, -286)

	local color = CreateColorSwatch(panel, L["Text Color"], function() return db.textColor end, function(r, g, b)
		local textColor = db.textColor
		textColor.r, textColor.g, textColor.b = r, g, b
		Private:UpdateStyle()
	end)
	color:SetPoint('TOPLEFT', 334, -346)

	-- The settings panel calls OnRefresh on every display, OnShow misses the first one
	panel.OnRefresh = RefreshWidgets

	return panel
end

local function GetRowLabel(object)
	local def = object.def
	return def.label or GetSpellName(def.name or def.spells[1]) or '?'
end

local function GetRowIcon(object)
	local def = object.def
	if def.enchant then
		return GetInventoryItemTexture('player', def.enchant == 'MainHand' and INVSLOT_MAINHAND or INVSLOT_OFFHAND) or 134400
	end

	return GetSpellTexture(def.icon or def.spells[1]) or 134400
end

local function CreateRow(parent, settings)
	local row = CreateFrame('Frame', nil, parent)
	row:SetSize(620, 30)

	-- Set before the widgets, SetupMenu on a shown dropdown reads the getter right away
	row.settings = settings

	local icon = row:CreateTexture(nil, 'ARTWORK')
	icon:SetSize(22, 22)
	icon:SetPoint('LEFT', 4, 0)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.icon = icon

	local function Get(key) return function() return row.settings[key] end end
	local function Set(key) return function(value) row.settings[key] = value Private:UpdateStyle() end end

	row.enable = CreateCheckbox(row, '', Get('enabled'), Set('enabled'))
	row.enable:SetPoint('LEFT', icon, 'RIGHT', 4, 0)
	row.enable.Text:SetWidth(185)
	row.enable.Text:SetWordWrap(false)
	row.enable.Text:SetJustifyH('LEFT')

	row.load = CreateDropdown(row, nil, Private.LoadOptions, 150, Get('load'), Set('load'))
	row.load:SetPoint('LEFT', 250, 0)

	row.text = CreateEditBox(row, 110, Get('text'), Set('text'))
	row.text:SetPoint('LEFT', 420, 0)

	row.group = CreateCheckbox(row, L["Group"], Get('group'), Set('group'))
	row.group:SetPoint('LEFT', 540, 0)

	row.delete = CreateButton(row, L["Delete"], 70, function() Private:RemoveCustom(row.index) Private:RefreshReminderRows() end)
	row.delete:SetPoint('LEFT', 540, 0)

	return row
end

local function CreateRemindersPanel()
	local panel = CreateFrame('Frame')
	local rows = {}

	local title = CreateTitle(panel, L["Reminders"], 'GameFontNormalLarge')
	title:SetPoint('TOPLEFT', 16, -16)

	local note = CreateTitle(panel, L["Reminders work in combat. Group counts are hidden in combat and other restricted states."], 'GameFontHighlightSmall')
	note:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -6)
	note:SetWidth(600)
	note:SetJustifyH('LEFT')

	local scroll = CreateFrame('ScrollFrame', nil, panel, 'ScrollFrameTemplate')
	scroll:SetPoint('TOPLEFT', 8, -60)
	scroll:SetPoint('BOTTOMRIGHT', -30, 8)

	local content = CreateFrame('Frame', nil, scroll)
	content:SetSize(630, 100)
	scroll:SetScrollChild(content)

	local headers = {
		{ L["Reminder"], 34 },
		{ L["Load"], 254 },
		{ L["Custom Text"], 424 },
	}

	for _, header in ipairs(headers) do
		local text = CreateTitle(content, header[1])
		text:SetPoint('TOPLEFT', header[2], -4)
	end

	local customTitle = CreateTitle(content, L["Custom Reminders"], 'GameFontNormalLarge')
	local customNote = CreateTitle(content, L["Spell IDs separated by commas, any of them counts. Use one reminder per buff."], 'GameFontHighlightSmall')
	customNote:SetPoint('TOPLEFT', customTitle, 'BOTTOMLEFT', 0, -4)
	customNote:SetWidth(600)
	customNote:SetJustifyH('LEFT')

	local input = CreateFrame('EditBox', nil, content, 'InputBoxTemplate')
	input:SetSize(250, 20)
	input:SetAutoFocus(false)
	input:SetPoint('TOPLEFT', customNote, 'BOTTOMLEFT', 6, -8)

	local function AddCustom()
		local spells = {}
		for token in gmatch(input:GetText(), '%d+') do
			local spellID = tonumber(token)
			if #token <= 9 and DoesSpellExist(spellID) then
				tinsert(spells, spellID)
			else
				Private:Print(L["Unknown spell ID:"] .. ' ' .. token)
			end
		end

		if #spells > 0 then
			input:SetText('')
			input:ClearFocus()
			Private:AddCustom(spells)
			Private:RefreshReminderRows()
		end
	end

	input:SetScript('OnEnterPressed', AddCustom)
	input:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)

	local add = CreateButton(content, L["Add"], 80, AddCustom)
	add:SetPoint('LEFT', input, 'RIGHT', 8, 0)

	function Private:RefreshReminderRows()
		local entries = {}
		for _, object in ipairs(Private.BaseObjects) do
			if object.kind ~= 'group' then
				tinsert(entries, { object = object, settings = object.settings })
			end
		end

		local baseCount = #entries
		for index, entry in ipairs(Private.classDB.custom) do
			tinsert(entries, { custom = entry, index = index, settings = entry })
		end

		local y = -24
		for i, entry in ipairs(entries) do
			local row = rows[i]
			if not row then
				row = CreateRow(content, entry.settings)
				rows[i] = row
			end

			if i == baseCount + 1 then
				y = y - 16
				customTitle:ClearAllPoints()
				customTitle:SetPoint('TOPLEFT', 4, y)
				y = y - 72
			end

			row.settings = entry.settings
			row.index = entry.index

			local label, texture
			if entry.custom then
				label = GetSpellName(entry.custom.spells[1]) or '?'
				texture = GetSpellTexture(entry.custom.spells[1]) or 134400
			else
				label = GetRowLabel(entry.object)
				texture = GetRowIcon(entry.object)
			end

			row.icon:SetTexture(texture)
			row.enable.Text:SetText(label)
			row.group:SetShown(entry.object and entry.object.def.group and true or false)
			row.delete:SetShown(entry.custom and true or false)

			row:ClearAllPoints()
			row:SetPoint('TOPLEFT', 0, y)
			row:Show()
			y = y - 32
		end

		if baseCount == #entries then
			y = y - 16
			customTitle:ClearAllPoints()
			customTitle:SetPoint('TOPLEFT', 4, y)
			y = y - 72
		end

		for i = #entries + 1, #rows do
			rows[i]:Hide()
		end

		content:SetHeight(-y + 16)
		RefreshWidgets()
	end

	panel.OnRefresh = Private.RefreshReminderRows

	return panel
end

function Private:CreateOptions()
	local category = Settings.RegisterCanvasLayoutCategory(CreateGeneralPanel(), 'LuckyMokReminders')
	Settings.RegisterCanvasLayoutSubcategory(category, CreateRemindersPanel(), L["Reminders"])
	Settings.RegisterAddOnCategory(category)
	Private.Category = category
end

SLASH_LUCKYMOKREMINDERS1 = '/lmr'
SLASH_LUCKYMOKREMINDERS2 = '/luckymok'
SlashCmdList.LUCKYMOKREMINDERS = function(msg)
	if not Private.db then return end

	local command = strlower(strtrim(msg or ''))
	if command == 'unlock' or command == 'lock' or command == 'move' then
		Private:SetUnlocked(not Private.unlocked)
	elseif command == 'reset' then
		Private:ResetPosition()
	else
		if InCombatLockdown() then return end
		Settings.OpenToCategory(Private.Category:GetID())
	end
end

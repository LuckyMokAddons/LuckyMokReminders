local next = next
local print = print
local setmetatable = setmetatable
local type = type

local UnitClass = UnitClass

local _, Private = ...

-- Locales
local translations = {}
Private.L = setmetatable({}, {
	__index = function(_, key) return translations[key] or key end,
	__newindex = function(_, key, value) if value ~= true then translations[key] = value end end,
})

Private.Name = '|cff4beb2cLuckyMokReminders|r'

local _, class = UnitClass('player')
Private.Class = class

-- Account wide display settings, reminders are stored per class in classes
Private.Defaults = {
	enabled = true,
	point = 'CENTER',
	relativePoint = 'CENTER',
	x = 0,
	y = 200,
	growth = 'RIGHT',
	iconSize = 36,
	spacing = 6,
	hideCombat = false,
	hideResting = false,
	hideTaxi = true,
	showText = true,
	textPosition = 'BOTTOM',
	textSize = 11,
	textOutline = 'OUTLINE',
	textWidth = 70,
	textColor = { r = 1, g = 0.82, b = 0 },
}

function Private:Print(msg)
	print(Private.Name .. ': ' .. msg)
end

local function FillDefaults(db, defaults)
	for key, value in next, defaults do
		if type(value) == 'table' then
			if type(db[key]) ~= 'table' then
				db[key] = {}
			end

			FillDefaults(db[key], value)
		elseif db[key] == nil then
			db[key] = value
		end
	end
end

function Private:InitializeDB()
	if type(LuckyMokRemindersDB) ~= 'table' then
		LuckyMokRemindersDB = {}
	end

	local db = LuckyMokRemindersDB
	FillDefaults(db, Private.Defaults)

	if type(db.classes) ~= 'table' then
		db.classes = {}
	end

	local classDB = db.classes[class]
	if type(classDB) ~= 'table' then
		classDB = {}
		db.classes[class] = classDB
	end

	if type(classDB.reminders) ~= 'table' then
		classDB.reminders = {}
	end

	if type(classDB.custom) ~= 'table' then
		classDB.custom = {}
	end

	-- Per reminder defaults, class specific load and enable states come from Data.lua
	for _, def in next, Private.Reminders do
		if not def.class or def.class == class then
			local settings = classDB.reminders[def.key]
			if type(settings) ~= 'table' then
				settings = {}
				classDB.reminders[def.key] = settings
			end

			if settings.enabled == nil then
				settings.enabled = not (def.disabled or (def.classDisabled and def.classDisabled[class]))
			end

			if settings.load == nil then
				settings.load = (def.classLoad and def.classLoad[class]) or def.load or 'ALWAYS'
			end

			if type(settings.text) ~= 'string' then
				settings.text = ''
			end

			if def.group and settings.group == nil then
				settings.group = true
			end
		end
	end

	for _, custom in next, classDB.custom do
		if custom.enabled == nil then custom.enabled = true end
		if custom.load == nil then custom.load = 'ALWAYS' end
		if type(custom.text) ~= 'string' then custom.text = '' end
	end

	Private.db = db
	Private.classDB = classDB
end

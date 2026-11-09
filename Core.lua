local _, Private = ...
local L = Private.L

local ipairs = ipairs
local max = math.max
local strmatch = string.match
local tinsert = table.insert
local tremove = table.remove
local wipe = table.wipe

local C_Timer_After = C_Timer.After
local CreateFrame = CreateFrame
local GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemTexture = GetInventoryItemTexture
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetNumGroupMembers = GetNumGroupMembers
local GetSpellName = C_Spell.GetSpellName
local GetSpellTexture = C_Spell.GetSpellTexture
local GetUnitAuraBySpellID = C_UnitAuras.GetUnitAuraBySpellID
local InCombatLockdown = InCombatLockdown
local IsInGroup = IsInGroup
local IsInInstance = IsInInstance
local IsInRaid = IsInRaid
local IsMounted = IsMounted
local IsResting = IsResting
local IsSpellKnown = C_SpellBook.IsSpellKnown
local ShouldAurasBeSecret = C_Secrets.ShouldAurasBeSecret
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitIsConnected = UnitIsConnected
local UnitIsDead = UnitIsDead
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitOnTaxi = UnitOnTaxi
local issecretvalue = issecretvalue

local GameFontNormal = GameFontNormal
local UIParent = UIParent
local INVSLOT_MAINHAND = INVSLOT_MAINHAND
local INVSLOT_OFFHAND = INVSLOT_OFFHAND
local ItemEnchantmentSlot = AuraContainerItemEnchantmentSlot
local ItemClassWeapon = Enum.ItemClass.Weapon
local WeaponFishingPole = Enum.ItemWeaponSubclass.Fishingpole

-- Slot start point and the point it follows on the previous slot
-- The container point, the point it closes the slot on and the offset sign
local Growth = {
	RIGHT = { start = 'TOPLEFT', after = 'TOPRIGHT', box = 'TOPRIGHT', boxEnd = 'TOPLEFT', x = 1, y = 0 },
	LEFT = { start = 'TOPRIGHT', after = 'TOPLEFT', box = 'TOPLEFT', boxEnd = 'TOPRIGHT', x = -1, y = 0 },
	DOWN = { start = 'TOPLEFT', after = 'BOTTOMLEFT', box = 'BOTTOMLEFT', boxEnd = 'TOPLEFT', x = 0, y = -1, vertical = true },
	UP = { start = 'BOTTOMLEFT', after = 'TOPLEFT', box = 'TOPLEFT', boxEnd = 'BOTTOMLEFT', x = 0, y = 1, vertical = true },
}

local EnchantSlots = {
	MainHand = INVSLOT_MAINHAND,
	OffHand = INVSLOT_OFFHAND,
}

-- Display order, data reminders with their group counters, and the custom pool indexed like classDB.custom
local objects = {}
local baseObjects = {}
local customObjects = {}
Private.BaseObjects = baseObjects
local partyUnits, raidUnits = {}, {}
for i = 1, 4 do partyUnits[i] = 'party' .. i end
for i = 1, 40 do raidUnits[i] = 'raid' .. i end

local inCombat, instanceType, playerGUID, petMissing = false, 'none', nil, false
local layoutDirty, refreshPending, watchingGroup = true, false, false

local holder = CreateFrame('Frame', 'LuckyMokRemindersAnchor', UIParent)
holder:SetFrameStrata('MEDIUM')
holder:SetClampedToScreen(true)
holder:SetMovable(true)
holder:SetDontSavePosition(true)
holder:Hide()
Private.Holder = holder

-- Drag handle over the whole preview row, it only anchors to the holder and moves it
local mover = CreateFrame('Frame', nil, holder)
mover:SetFrameLevel(holder:GetFrameLevel() + 50)
mover:EnableMouse(true)
mover:RegisterForDrag('LeftButton')
mover:Hide()

local overlay = mover:CreateTexture(nil, 'OVERLAY')
overlay:SetAllPoints()
overlay:SetColorTexture(0.29, 0.92, 0.17, 0.35)

local overlayText = mover:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
overlayText:SetPoint('BOTTOM', mover, 'TOP', 0, 2)
overlayText:SetText(Private.Name)

mover:SetScript('OnDragStart', function()
	holder:StartMoving()
end)

mover:SetScript('OnDragStop', function()
	holder:StopMovingOrSizing()

	local db = Private.db
	local point, _, relativePoint, x, y = holder:GetPoint()
	db.point, db.relativePoint, db.x, db.y = point, relativePoint, x, y
end)

-- Aura buttons stay invisible, they only exist so the container resizes
local function InitializeAuraFrame(button)
	button:EnableMouse(false)
end

local function GetCellSize()
	local db = Private.db
	local size = db.iconSize

	if not db.showText then
		return size, size
	end

	local textHeight = db.textSize + 4
	if db.textPosition == 'CENTER' then
		return size, max(size, textHeight)
	end

	if db.textPosition == 'LEFT' or db.textPosition == 'RIGHT' then
		return size + 2 + db.textWidth, max(size, textHeight)
	end

	return max(size, db.textWidth), size + 2 + textHeight
end

local function SpellMap(spells)
	local map = {}
	for _, spellID in ipairs(spells) do
		map[spellID] = true
	end

	return map
end

local function CreateObject(kind, def, settings)
	local object = { kind = kind, def = def, settings = settings, active = false, missing = 0 }

	-- Slots clip their content, a slot squeezed to zero size by its container hides the reminder
	local slot = CreateFrame('Frame', nil, holder, 'DisableUntrustedLayoutScriptsTemplate')
	slot:SetClipsChildren(true)
	slot:Hide()
	object.slot = slot

	local content = CreateFrame('Frame', nil, slot, 'DisableUntrustedLayoutScriptsTemplate')
	object.content = content

	local border = content:CreateTexture(nil, 'BACKGROUND')
	border:SetColorTexture(0, 0, 0, 1)
	object.border = border

	local icon = content:CreateTexture(nil, 'ARTWORK')
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetPoint('TOPLEFT', border, 'TOPLEFT', 1, -1)
	icon:SetPoint('BOTTOMRIGHT', border, 'BOTTOMRIGHT', -1, 1)
	object.icon = icon

	local text = content:CreateFontString(nil, 'OVERLAY')
	text:SetWordWrap(false)
	object.text = text

	if kind == 'group' then
		local count = content:CreateFontString(nil, 'OVERLAY')
		count:SetPoint('BOTTOMRIGHT', border, 'BOTTOMRIGHT', -2, 3)
		count:SetTextColor(1, 1, 1)
		object.count = count
	elseif kind == 'aura' or kind == 'enchant' then
		-- Parented to UIParent so a hidden holder does not pause the container and leave a stale size
		local container = CreateFrame('AuraContainer', nil, UIParent, 'CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate')
		container:SetSize(1, 1)
		container:Hide()
		container:SetEditModePreviewEnabled(false)
		container:SetUnit('player')
		object.container = container

		if kind == 'enchant' then
			container:AddItemEnchantment(ItemEnchantmentSlot[def.enchant], { initializeFrame = InitializeAuraFrame })
		else
			container:AddAuraGroup('reminder', 'HELPFUL', {
				candidateFilters = { includeSpellIDs = SpellMap(def.spells) },
				initializeFrame = InitializeAuraFrame,
				maxFrameCount = 1,
			})
		end
	end

	return object
end

local function GetLabel(object)
	local text = object.settings.text
	if text ~= '' then
		return text
	end

	local def = object.def
	return def.label or GetSpellName(def.name or def.spells[1]) or ''
end

local function UpdateIcon(object)
	local def = object.def
	local texture

	if def.enchant then
		texture = GetInventoryItemTexture('player', EnchantSlots[def.enchant])
	else
		texture = GetSpellTexture(def.icon or def.spells[1])
	end

	object.icon:SetTexture(texture or 134400)
end

local function ApplyStyle(object, cellWidth, cellHeight, growth, extent)
	local db = Private.db
	local size = db.iconSize
	local textHeight = db.textSize + 4
	local position = db.showText and db.textPosition
	local border, text, content = object.border, object.text, object.content

	content:ClearAllPoints()
	content:SetPoint(growth.start, object.slot, growth.start)
	content:SetSize(cellWidth, cellHeight)

	border:ClearAllPoints()
	border:SetSize(size, size)
	text:ClearAllPoints()

	if position == 'BOTTOM' then
		border:SetPoint('TOP', content, 'TOP')
		text:SetPoint('TOP', border, 'BOTTOM', 0, -2)
		text:SetSize(cellWidth, textHeight)
		text:SetJustifyH('CENTER')
	elseif position == 'TOP' then
		border:SetPoint('BOTTOM', content, 'BOTTOM')
		text:SetPoint('BOTTOM', border, 'TOP', 0, 2)
		text:SetSize(cellWidth, textHeight)
		text:SetJustifyH('CENTER')
	elseif position == 'LEFT' then
		border:SetPoint('RIGHT', content, 'RIGHT')
		text:SetPoint('RIGHT', border, 'LEFT', -2, 0)
		text:SetSize(db.textWidth, textHeight)
		text:SetJustifyH('RIGHT')
	elseif position == 'RIGHT' then
		border:SetPoint('LEFT', content, 'LEFT')
		text:SetPoint('LEFT', border, 'RIGHT', 2, 0)
		text:SetSize(db.textWidth, textHeight)
		text:SetJustifyH('LEFT')
	else
		border:SetPoint('CENTER', content, 'CENTER')
		text:SetPoint('CENTER', border, 'CENTER')
		text:SetSize(size, textHeight)
		text:SetJustifyH('CENTER')
	end

	local font = GameFontNormal:GetFont()
	local color = db.textColor
	text:SetFont(font, db.textSize, db.textOutline == 'NONE' and '' or db.textOutline)
	text:SetTextColor(color.r, color.g, color.b)
	text:SetText(GetLabel(object))
	text:SetShown(db.showText)

	if object.count then
		object.count:SetFont(font, max(8, size * 0.45), 'OUTLINE')
	end

	UpdateIcon(object)

	-- Present aura makes the container exactly one stride plus the 1px empty size wide, closing the slot
	local container = object.container
	if container and object.extent ~= extent then
		object.extent = extent

		local layout = { elementWidth = extent, elementHeight = extent }
		if object.kind == 'enchant' then
			container:SetItemEnchantmentLayout(layout)
		else
			container:SetAuraGroupLayout('reminder', layout)
		end
	end
end

local function GetStride(cellWidth, cellHeight, growth)
	return (growth.vertical and cellHeight or cellWidth) + Private.db.spacing
end

function Private:UpdateStyle()
	local db = Private.db
	local growth = Growth[db.growth] or Growth.RIGHT
	local cellWidth, cellHeight = GetCellSize()
	local extent = GetStride(cellWidth, cellHeight, growth) + 1

	holder:SetSize(cellWidth, cellHeight)

	for _, object in ipairs(objects) do
		ApplyStyle(object, cellWidth, cellHeight, growth, extent)
	end

	layoutDirty = true
	Private:Refresh()
end

function Private:UpdatePosition()
	local db = Private.db
	holder:ClearAllPoints()
	holder:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
end

function Private:ResetPosition()
	local db, defaults = Private.db, Private.Defaults
	db.point, db.relativePoint, db.x, db.y = defaults.point, defaults.relativePoint, defaults.x, defaults.y
	Private:UpdatePosition()
end

function Private:SetUnlocked(unlocked)
	Private.unlocked = unlocked
	mover:SetShown(unlocked)

	local lockButton = Private.LockButton
	if lockButton then
		lockButton:SetText(unlocked and L["Lock"] or L["Unlock"])
	end

	layoutDirty = true
	Private:Refresh()
end

-- Chains every active slot to the previous one, container slots shrink to zero while their aura is present
function Private:Layout()
	layoutDirty = false

	local growth = Growth[Private.db.growth] or Growth.RIGHT
	local cellWidth, cellHeight = GetCellSize()
	local stride = GetStride(cellWidth, cellHeight, growth)
	local preview = Private.unlocked
	local previous, shown = nil, 0

	for _, object in ipairs(objects) do
		local slot, container = object.slot, object.container
		slot:ClearAllPoints()

		if container then
			container:ClearAllPoints()
		end

		if object.active then
			local anchor = previous or holder
			local anchorPoint = previous and growth.after or growth.start
			slot:SetPoint(growth.start, anchor, anchorPoint)

			if container and not preview then
				container:SetPoint(growth.box, anchor, anchorPoint, growth.x * (stride + 1), growth.y * (stride + 1))
				container:Show()
				slot:SetPoint(growth.after, container, growth.boxEnd)
			else
				if container then
					container:Hide()
				end

				if growth.vertical then
					slot:SetHeight(stride)
				else
					slot:SetWidth(stride)
				end
			end

			if growth.vertical then
				slot:SetWidth(cellWidth)
			else
				slot:SetHeight(cellHeight)
			end

			slot:Show()
			previous = slot
			shown = shown + 1
		else
			slot:Hide()

			if container then
				container:Hide()
			end
		end
	end

	-- Preview slots are all fixed size, so the drag handle can span the row without reading secret geometry
	if preview then
		local length = max(shown, 1) * stride
		mover:ClearAllPoints()
		mover:SetPoint(growth.start, holder, growth.start)
		mover:SetSize(growth.vertical and cellWidth or length, growth.vertical and length or cellHeight)
	end
end

local function CheckLoad(load)
	if load == 'GROUP' then
		return IsInGroup()
	elseif load == 'INSTANCE' then
		return instanceType == 'party' or instanceType == 'raid'
	elseif load == 'RAID' then
		return instanceType == 'raid'
	elseif load == 'COMBAT' then
		return inCombat
	end

	return true
end

local function HasAura(unit, spells)
	for _, spellID in ipairs(spells) do
		if GetUnitAuraBySpellID(unit, spellID) then
			return true
		end
	end

	return false
end

-- Only called while auras are not secret, a lookup on a secret aura would read as missing
local function CountMissing(def)
	local inRaid = IsInRaid()
	local units = inRaid and raidUnits or partyUnits
	local total = inRaid and GetNumGroupMembers() or (GetNumGroupMembers() - 1)
	local manaOnly = def.group == 'MANA'
	local playerMap = GetBestMapForUnit('player')
	local missing = 0

	for i = 1, total do
		local unit = units[i]
		if unit and UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
			local guid = UnitGUID(unit)
			local _, unitClass = UnitClass(unit)

			if not issecretvalue(guid) and guid ~= playerGUID and not issecretvalue(unitClass) and (not manaOnly or Private.ManaClasses[unitClass]) then
				-- Members on another map report no auras, skip them when both maps are known
				local unitMap = GetBestMapForUnit(unit)
				if not (unitMap and playerMap and unitMap ~= playerMap) and not HasAura(unit, def.spells) then
					missing = missing + 1
				end
			end
		end
	end

	return missing
end

local events = CreateFrame('Frame')

local function SetGroupWatch(watch)
	if watchingGroup == watch then return end
	watchingGroup = watch

	if watch then
		events:RegisterEvent('UNIT_AURA')
		events:RegisterEvent('UNIT_CONNECTION')
		events:RegisterEvent('UNIT_FLAGS')
	else
		events:UnregisterEvent('UNIT_AURA')
		events:UnregisterEvent('UNIT_CONNECTION')
		events:UnregisterEvent('UNIT_FLAGS')
	end
end

function Private:Refresh()
	refreshPending = false

	local db = Private.db
	if not db then return end

	local preview = Private.unlocked
	local hidden = not preview and (not db.enabled or UnitIsDeadOrGhost('player') or (db.hideTaxi and UnitOnTaxi('player')) or (db.hideResting and IsResting()) or (db.hideCombat and inCombat))
	holder:SetShown(not hidden)

	local restricted = ShouldAurasBeSecret()
	local mounted = IsMounted()
	local wantsGroup, changed = false, layoutDirty

	for _, object in ipairs(objects) do
		local settings, active = object.settings

		if object.kind == 'group' then
			local wanted = not hidden and not preview and object.parent.loaded and settings.group and IsInGroup()
			local missing = 0

			if wanted then
				wantsGroup = true

				if not restricted then
					missing = CountMissing(object.def)
				end
			end

			if object.missing ~= missing then
				object.missing = missing
				object.count:SetText(missing)
			end

			active = missing > 0
		else
			object.loaded = settings.enabled and object.available and CheckLoad(settings.load) and (not object.def.pet or (petMissing and not mounted)) or false

			if preview then
				active = settings.enabled and object.available or false
			else
				active = object.loaded
			end
		end

		if object.active ~= active then
			object.active = active
			changed = true
		end
	end

	SetGroupWatch(wantsGroup and not restricted)

	if changed then
		Private:Layout()
	end
end

function Private:ScheduleRefresh(delay)
	if refreshPending then return end
	refreshPending = true

	C_Timer_After(delay or 0.1, Private.Refresh)
end

local function IsKnown(spells)
	for _, spellID in ipairs(spells) do
		if IsSpellKnown(spellID) then
			return true
		end
	end

	return false
end

local function HasWeapon(slot)
	local itemID = GetInventoryItemID('player', slot)
	if not itemID then
		return false
	end

	local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID)
	return classID == ItemClassWeapon and subClassID ~= WeaponFishingPole
end

local function UpdateKnown()
	for _, object in ipairs(baseObjects) do
		if object.def.class and object.kind ~= 'group' then
			object.available = IsKnown(object.def.known or object.def.spells)
		end
	end
end

local function UpdateEquipment()
	for _, object in ipairs(baseObjects) do
		if object.kind == 'enchant' then
			object.available = HasWeapon(EnchantSlots[object.def.enchant])
			UpdateIcon(object)
		end
	end
end

local function UpdateZone()
	local _, zoneType = IsInInstance()
	instanceType = zoneType or 'none'
end

local function UpdatePet()
	local missing = not UnitExists('pet') or UnitIsDead('pet')
	if petMissing ~= missing then
		petMissing = missing
		Private:ScheduleRefresh()
	end
end

local function RebuildOrder()
	wipe(objects)

	for _, object in ipairs(baseObjects) do
		tinsert(objects, object)
	end

	local custom = Private.classDB.custom
	for i = 1, #custom do
		tinsert(objects, customObjects[i])
	end

	for i = #custom + 1, #customObjects do
		local object = customObjects[i]
		object.active = false
		object.slot:Hide()
		object.slot:ClearAllPoints()
		object.container:Hide()
		object.container:ClearAllPoints()
	end
end

-- Custom pool objects are reused, a new spell list only swaps the candidate filter
function Private:SyncCustom()
	for i, entry in ipairs(Private.classDB.custom) do
		local object = customObjects[i]
		local def = { spells = entry.spells }

		if not object then
			object = CreateObject('aura', def, entry)
			customObjects[i] = object
		elseif object.def.spells ~= entry.spells then
			object.container:SetAuraGroupCandidateFilters('reminder', { includeSpellIDs = SpellMap(entry.spells) })
		end

		object.def = def
		object.settings = entry
		object.available = true
	end

	RebuildOrder()
	Private:UpdateStyle()
end

function Private:AddCustom(spells)
	tinsert(Private.classDB.custom, { spells = spells, enabled = true, load = 'ALWAYS', text = '' })
	Private:SyncCustom()
end

function Private:RemoveCustom(index)
	tremove(Private.classDB.custom, index)
	Private:SyncCustom()
end

local function BuildObjects()
	local class = Private.Class
	local reminders = Private.classDB.reminders

	for _, def in ipairs(Private.Reminders) do
		if not def.class or def.class == class then
			local settings = reminders[def.key]
			local object = CreateObject((def.enchant and 'enchant') or (def.spells and 'aura') or 'plain', def, settings)
			object.available = not def.class and not def.enchant
			tinsert(baseObjects, object)

			if def.group then
				local counter = CreateObject('group', def, settings)
				counter.parent = object
				tinsert(baseObjects, counter)
			end
		end
	end
end

events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent', function(_, event, arg1)
	if event == 'UNIT_AURA' or event == 'UNIT_CONNECTION' or event == 'UNIT_FLAGS' then
		if arg1 and not issecretvalue(arg1) and (strmatch(arg1, '^party%d') or strmatch(arg1, '^raid%d')) then
			Private:ScheduleRefresh(1)
		end
	elseif event == 'UNIT_PET' or event == 'UNIT_HEALTH' then
		UpdatePet()
	elseif event == 'PLAYER_REGEN_DISABLED' then
		inCombat = true
		Private:Refresh()
	elseif event == 'PLAYER_REGEN_ENABLED' then
		inCombat = false
		Private:Refresh()
	elseif event == 'SPELLS_CHANGED' then
		UpdateKnown()
		Private:ScheduleRefresh()
	elseif event == 'PLAYER_EQUIPMENT_CHANGED' then
		UpdateEquipment()
		Private:ScheduleRefresh()
	elseif event == 'PLAYER_ENTERING_WORLD' or event == 'ZONE_CHANGED_NEW_AREA' then
		UpdateZone()
		UpdatePet()
		Private:ScheduleRefresh()
	elseif event == 'PLAYER_CONTROL_LOST' or event == 'PLAYER_CONTROL_GAINED' then
		-- Taxi state can lag behind the control event
		Private:ScheduleRefresh()
		C_Timer_After(1, Private.Refresh)
	elseif event == 'PLAYER_LOGIN' then
		Private:InitializeDB()

		playerGUID = UnitGUID('player')
		inCombat = InCombatLockdown()

		BuildObjects()
		UpdateKnown()
		UpdateEquipment()
		UpdateZone()
		UpdatePet()

		Private:UpdatePosition()
		Private:SyncCustom()
		Private:CreateOptions()

		events:RegisterEvent('PLAYER_ENTERING_WORLD')
		events:RegisterEvent('ZONE_CHANGED_NEW_AREA')
		events:RegisterEvent('GROUP_ROSTER_UPDATE')
		events:RegisterEvent('PLAYER_REGEN_DISABLED')
		events:RegisterEvent('PLAYER_REGEN_ENABLED')
		events:RegisterEvent('PLAYER_UPDATE_RESTING')
		events:RegisterEvent('PLAYER_DEAD')
		events:RegisterEvent('PLAYER_ALIVE')
		events:RegisterEvent('PLAYER_UNGHOST')
		events:RegisterEvent('PLAYER_CONTROL_LOST')
		events:RegisterEvent('PLAYER_CONTROL_GAINED')
		events:RegisterEvent('SPELLS_CHANGED')
		events:RegisterEvent('PLAYER_EQUIPMENT_CHANGED')
		events:RegisterEvent('ADDON_RESTRICTION_STATE_CHANGED')
		events:RegisterEvent('PLAYER_MOUNT_DISPLAY_CHANGED')

		for _, object in ipairs(baseObjects) do
			if object.def.pet then
				events:RegisterUnitEvent('UNIT_PET', 'player')
				events:RegisterUnitEvent('UNIT_HEALTH', 'pet')
				break
			end
		end
	else
		Private:ScheduleRefresh()
	end
end)

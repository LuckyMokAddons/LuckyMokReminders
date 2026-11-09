local _, Private = ...
local L = Private.L

-- Forever has one spell ID per rank: lists carry every rank plus the group version (Forever 1.60.1 DB2)
-- Name and icon are spell IDs for label and icon, group counts members missing it (ALL or MANA classes)
Private.Reminders = {
	-- Druid
	{
		key = 'markOfTheWild', class = 'DRUID', name = 1126, icon = 1126, group = 'ALL',
		spells = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 21849, 21850 },
	},

	-- Hunter
	{
		key = 'aspect', class = 'HUNTER', label = L["Aspect"], icon = 13165,
		spells = { 13165, 14318, 14319, 14320, 14321, 14322, 25296, 13163, 5118, 13159, 20043, 20190, 13161, 1299445, 1299446, 1299447, 469145, 415423 },
	},
	{
		key = 'trueshotAura', class = 'HUNTER', name = 19506, icon = 19506,
		spells = { 19506, 20905, 20906, 1299346, 1299348 },
	},
	{
		key = 'hunterPet', class = 'HUNTER', label = L["Pet"], icon = 883, pet = true,
		known = { 883 },
	},

	-- Mage
	{
		key = 'arcaneIntellect', class = 'MAGE', name = 1459, icon = 1459, group = 'MANA',
		spells = { 1459, 1460, 1461, 10156, 10157, 23028 },
	},
	{
		key = 'mageArmor', class = 'MAGE', label = L["Armor"], icon = 7302,
		spells = { 168, 7300, 7301, 7302, 7320, 10219, 10220, 6117, 22782, 22783 },
	},

	-- Paladin
	{
		key = 'blessing', class = 'PALADIN', label = L["Blessing"], icon = 19740,
		spells = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 19742, 19850, 19852, 19853, 19854, 25290, 20217, 25782, 25916, 25894, 25918, 25898 },
	},
	{
		key = 'paladinAura', class = 'PALADIN', label = L["Aura"], icon = 465,
		spells = { 465, 643, 1032, 10290, 10291, 10292, 10293, 7294, 10298, 10299, 10300, 10301, 19746, 19876, 19895, 19896, 19888, 19897, 19898, 19891, 19899, 19900 },
	},
	{
		key = 'righteousFury', class = 'PALADIN', name = 25780, icon = 25780, disabled = true,
		spells = { 25780, 407627 },
	},

	-- Priest
	{
		key = 'fortitude', class = 'PRIEST', name = 1243, icon = 1243, group = 'ALL',
		spells = { 1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564 },
	},
	{
		key = 'divineSpirit', class = 'PRIEST', name = 14752, icon = 14752, group = 'MANA',
		spells = { 14752, 14818, 14819, 27841, 27681 },
	},
	{
		key = 'shadowProtection', class = 'PRIEST', name = 976, icon = 976, group = 'ALL', disabled = true,
		spells = { 976, 10957, 10958, 27683 },
	},
	{
		key = 'innerFire', class = 'PRIEST', name = 588, icon = 588,
		spells = { 588, 7128, 602, 1006, 10951, 10952 },
	},

	-- Shaman
	{
		key = 'lightningShield', class = 'SHAMAN', name = 324, icon = 324, disabled = true,
		spells = { 324, 325, 905, 945, 8134, 10431, 10432 },
	},

	-- Warlock
	{
		key = 'demonArmor', class = 'WARLOCK', label = L["Armor"], icon = 706,
		spells = { 687, 696, 706, 1086, 11733, 11734, 11735, 403619 },
	},
	-- A Demonic Sacrifice buff counts as having the pet
	{
		key = 'warlockPet', class = 'WARLOCK', label = L["Pet"], icon = 688, pet = true,
		known = { 688, 697, 712, 691 },
		spells = { 18789, 18790, 18791, 18792 },
	},

	-- Warrior
	{
		key = 'battleShout', class = 'WARRIOR', name = 6673, icon = 6673, load = 'COMBAT',
		spells = { 6673, 5242, 6192, 11549, 11550, 11551, 25289 },
	},

	-- Consumables, every Well Fed aura plus the stat foods that use other names
	{
		key = 'food', label = L["Food"], icon = 19705, load = 'RAID',
		spells = {
			19705, 19706, 19708, 19709, 19710, 19711, 24799, 24870, 25694, 25941,
			1225778, 1225779, 1225780, 1225782, 1248406, 1248420, 1248421, 1248422, 1248688, 1249519,
			1249520, 1249521, 1249523, 1249907, 1249926, 1249927, 1283082, 1294007, 1302064, 1319310,
			25661, 18125, 18141, 18191,
		},
	},
	{
		key = 'flask', label = L["Flask"], icon = 17626, load = 'RAID',
		spells = { 17626, 17627, 17628, 17629, 1293740, 1293741, 1293742, 1293743 },
	},
	{
		key = 'mainHand', label = L["Main Hand"], enchant = 'MainHand', load = 'RAID',
		classLoad = { ROGUE = 'ALWAYS', SHAMAN = 'ALWAYS' }, classDisabled = { HUNTER = true },
	},
	{
		key = 'offHand', label = L["Off Hand"], enchant = 'OffHand', load = 'RAID',
		classLoad = { ROGUE = 'ALWAYS', SHAMAN = 'ALWAYS' }, classDisabled = { HUNTER = true },
	},
}

Private.ManaClasses = {
	DRUID = true,
	HUNTER = true,
	MAGE = true,
	PALADIN = true,
	PRIEST = true,
	SHAMAN = true,
	WARLOCK = true,
}

Private.LoadOptions = {
	{ value = 'ALWAYS', text = L["Always"] },
	{ value = 'GROUP', text = L["In Group"] },
	{ value = 'INSTANCE', text = L["In Dungeon or Raid"] },
	{ value = 'RAID', text = L["In Raid Instance"] },
	{ value = 'COMBAT', text = L["In Combat"] },
}

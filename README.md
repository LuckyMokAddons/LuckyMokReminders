LuckyMokReminders is a fun project by Luckyone and Permok, made for our own use and shared as is.

# LuckyMokReminders

Reminder icons for WoW: Forever that show when you are missing a class buff, buff food, a flask, a weapon enchant or your pet. Every icon can carry a text label, and the text is fully configurable.

## Features

- Class buffs your character can cast, only shown once you know the spell (any rank counts, group versions count too)
- Buff food, flasks and temporary weapon enchants (stones, oils, poisons, shaman imbues) for main hand and off hand
- Missing pet reminder for hunters and warlocks, a Demonic Sacrifice buff counts as having the pet
- Optional group count on group buffs: a second icon shows how many group members are missing your buff
- Custom reminders: enter any spell IDs and get a reminder while none of them is on you
- Reminders keep working in combat
- Per reminder load condition: Always, In Group, In Dungeon or Raid, In Raid Instance or In Combat
- Per reminder custom text
- Movable icon row with four growth directions, icon size and spacing
- Text options: show or hide, position (below, above, left, right, center), font size, outline, width and color
- Hide in combat, while resting or on flight paths, always hidden while dead
- English and German

## Reminders per Class

| Class | Reminders |
| --- | --- |
| Druid | Mark of the Wild (group count) |
| Hunter | Aspect, Trueshot Aura, Pet |
| Mage | Arcane Intellect (group count), Armor |
| Paladin | Blessing, Aura, Righteous Fury (off by default) |
| Priest | Power Word: Fortitude (group count), Divine Spirit (group count), Shadow Protection (off by default), Inner Fire |
| Shaman | Lightning Shield (off by default) |
| Warlock | Armor, Pet |
| Warrior | Battle Shout (in combat by default) |
| Everyone | Food, Flask, Main Hand and Off Hand weapon enchants |

Spell IDs come from the Forever game data, including every rank and the Forever only spells and foods.

## Usage

- `/lmr` or `/luckymok` opens the options (Game Menu, Options, AddOns, LuckyMokReminders)
- `/lmr unlock` shows a preview of all reminders that you can drag, run it again to lock
- `/lmr reset` moves the icons back to the default position

Settings for the icon row and text are shared by all characters. Reminder settings and custom reminders are saved per class.

## How It Works

Buff checks use Blizzard's aura containers, so the game itself decides whether a buff is on you. That is why the reminders keep working in combat and other restricted states, where addons cannot read aura data directly.

## Limitations

- Group counts are hidden in combat and other restricted states.
- In a raid, members on another map or out of range can count as missing.
- The addon only loads on WoW: Forever.
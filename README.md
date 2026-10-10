# Range Lens

Know what reaches before you press it. Range Lens puts a small icon for each spell you choose under every enemy nameplate and on a panel for your target. Full color means the spell can reach. Dark red means it can't, the same way the game's own Cooldown Manager shows out of range.

Made for WoW Forever (Interface 16001).

## Features

- **Range at a glance on every mob.** A row of spell icons under each enemy nameplate, so you can see what reaches the mob you are about to pull, not just the one you have targeted. The Where to show grid sets each part (spell icons, range text, aggro light) for every nameplate, your target, your focus and the target panel, and they can hide while a mob is in melee range.
- **Target panel.** A larger row of the same icons for your target, placed wherever you like.
- **Drawn like the Cooldown Manager.** The icons use Blizzard's own Cooldown Manager art: the same rounded icon, soft shadow, red out of range tint and a dark cooldown sweep that turns red while out of range, with the countdown on the panel.
- **Pick your spells.** The options list every spell in your spellbook that has a range. Tick the ones you want, and use < and > to put their icons in the order you like.
- **See it before you play.** The options show a nameplate preview that redraws as you change settings; drag its icons to reorder them.
- **Tune any spell.** Unlock a spell in the options to set its reach by hand with a slider or by typing the yards.
- **Range numbers.** Each icon shows the spell's range in yards, both ends for a spell with a minimum range (8-25 for Charge).
- **Too close in orange.** Inside a spell's minimum range the icon turns orange instead of red, so you know to back off rather than close in.
- **Or only what reaches.** Switch on Only show spells in range and an icon appears only while its spell can reach, with no red or orange at all.
- **Live distance.** A distance to your target above the panel, and to each mob beside its nameplate, shown as a bracket such as 10-20, or formatted your way (12, <12, ~10, with or without "yd"), in the color (or colored by distance), size, shadow and position you choose. Or show it as a light: green, yellow or red by distances you set.
- **Spells that hit around you too.** Frost Nova, Thunder Clap, Arcane Explosion, Psychic Scream, Consecration, Cone of Cold and the other area spells have no target range, so the game can't check them. Range Lens knows each one's radius from the game's own spell data and checks it with the nearest distance check that never lights early. Frost Nova starts 1 yard short, for its freeze, Arctic Reach is counted, and any of them can be unlocked and tuned.
- **Talents count.** Whether an icon is lit comes straight from the game's own range check, so range talents are always included.
- **Aggro warning.** An optional dungeon finder eye on red mobs: searching as you near their estimated aggro range, fixed on you inside it (out of stealth; an estimate from levels, since the game keeps the real range to itself).
- **Your look.** The Look section in the options picks the window style: Automatic, Blizzard or Dark, with an opacity slider for Dark. The range icons follow it, rounded like the Cooldown Manager in Blizzard and square in Dark and EllesmereUI.
- **Works with EllesmereUI.** The icons sit on EllesmereUI's nameplates, and the nameplate preview is drawn from its nameplate settings.
- **Per character.** Each character keeps its own spells, panel position and settings.
- **Safe in combat.** It never reads values the game keeps hidden in combat, and it skips the distance checks the game refuses on friendly units in combat.

## Install

Download it from CurseForge, or copy this repository into `_classic_beta_/Interface/AddOns/RangeLens`.

## How to use

- **Open the options:** left-click the minimap button, type `/rangelens`, or go to Options > AddOns > Range Lens.
- **Move the panel:** while it is unlocked it has a thin blue outline. Drag it, then lock it from the options or with a right-click on the minimap button.
- **Place the nameplate icons:** use the up / down, left / right and size sliders in the options.

### Commands

`/rl` works the same as `/rangelens` unless another addon already uses it (EllesmereUI and Leatrix Plus use `/rl` to reload the interface); `/rangelens help` says which.

| Command | What it does |
| --- | --- |
| `/rangelens` | Open or close the options |
| `/rangelens add <spell>` / `/rangelens remove <spell or number>` | Track a spell, or stop tracking it |
| `/rangelens list`, `/rangelens clear`, `/rangelens defaults` | Show, empty, or reset the list to your class's starting spells |
| `/rangelens plates`, `/rangelens panel`, `/rangelens enemy` | Toggle spell icons on every nameplate, on the target panel, enemies only |
| `/rangelens targetonly`, `/rangelens focusonly` | Toggle spell icons on your target's, your focus's nameplate |
| `/rangelens melee` | Toggle hiding nameplate icons in melee range |
| `/rangelens cooldowns`, `/rangelens range` | Toggle the cooldown sweep, the range number on icons |
| `/rangelens inrange` | Toggle showing only the spells that can reach |
| `/rangelens reach <spell> <yards>` | Set a spell's reach by hand; without a number, back to automatic |
| `/rangelens distance`, `/rangelens platedistance` | Toggle the range text on the panel, on every nameplate |
| `/rangelens lock`, `/rangelens unlock` | Lock the panel, or unlock it to drag |
| `/rangelens size <n>`, `/rangelens panelsize <n>` | Icon sizes |
| `/rangelens offset <n>`, `/rangelens offsetx <n>` | Nameplate row up / down, left / right |
| `/rangelens minimap` | Show or hide the minimap button |
| `/rangelens aggro` | Toggle the warning near and inside a red mob's estimated aggro range |
| `/rangelens debug` | Print what the game answers for your target and every nameplate |
| `/rangelens style [auto\|blizzard\|dark]` | Window and icon style |
| `/rangelens reset` | Restore the settings, keeping your spell list |

## Limits

- The game only answers "within this many yards?" for a few fixed distances, so the distance shows as a bracket, and a 10 yard spell's icon lights at 10 yards even when a talent makes the spell reach a little further. It never lights early.
- Cone of Cold is checked for distance only, not for which way you are facing.

## Reporting a problem

Stand near the mob in question, type `/rangelens debug`, and include what it prints.

## Credits

The distance checks follow [LibRangeCheck-3.0](https://github.com/WeakAuras/LibRangeCheck-3.0) by mitch0 and the WoWUIDev community (MIT license). Its in-game measurements and its list of items with known use ranges make the 10 yard checks and the distance readouts possible.

## License

MIT. See [LICENSE](LICENSE).

# Range Lens

Know what reaches before you press it. Range Lens puts a small icon for each spell you choose under every enemy nameplate and on a panel for your target. Full colour means the spell can reach. Dark red means it can't, the same way the game's own Cooldown Manager shows out of range.

Made for WoW Forever (Interface 16001).

## Features

- **Range at a glance on every mob.** A row of spell icons under each enemy nameplate, so you can see what reaches the mob you are about to pull, not just the one you have targeted.
- **Target panel.** A larger row of the same icons for your target, placed wherever you like.
- **Drawn like the Cooldown Manager.** The icons use Blizzard's own Cooldown Manager art: the same rounded icon, soft shadow, red out of range tint and cooldown sweep, with the countdown on the panel.
- **Pick your spells.** The options list every spell in your spellbook that has a range. Tick the ones you want; icons appear in the order you tick them.
- **Range numbers.** Each icon shows the spell's range in yards.
- **Live distance.** A distance to your target above the panel, and to each mob beside its nameplate, shown as a bracket such as 10-20.
- **10 yard spells too.** Frost Nova, Arcane Explosion, Cone of Cold, Blast Wave, Hellfire, Howl of Terror, Holy Nova and Intimidating Shout have no target range, so the game can't check them. Range Lens checks them at 10 yards instead, and knows that Arctic Reach widens Frost Nova and Cone of Cold. Frost Nova's icon is for the freeze, which lands a little short of the damage, so it lights 1 yard closer.
- **Talents count.** Whether an icon is lit comes straight from the game's own range check, so range talents are always included.
- **Safe in combat.** It never reads values the game keeps hidden in combat, and it skips the distance checks the game refuses on friendly units in combat.

## Install

Download it from CurseForge, or copy this repository into `_classic_beta_/Interface/AddOns/RangeLens`.

## How to use

- **Open the options:** left-click the minimap button, type `/rl`, or go to Options > AddOns > Range Lens.
- **Move the panel:** while it is unlocked it has a thin blue outline. Drag it, then lock it from the options or with a right-click on the minimap button.
- **Place the nameplate icons:** use the up / down, left / right and size sliders in the options.

### Commands

| Command | What it does |
| --- | --- |
| `/rl` | Open or close the options |
| `/rl add <spell>` / `/rl remove <spell or number>` | Track a spell, or stop tracking it |
| `/rl list`, `/rl clear`, `/rl defaults` | Show, empty, or reset the list to your class's starting spells |
| `/rl plates`, `/rl panel`, `/rl enemy` | Toggle nameplate icons, the target panel, enemies only |
| `/rl cooldowns`, `/rl range` | Toggle the cooldown sweep, the range number on icons |
| `/rl distance`, `/rl platedistance` | Toggle the distance on the panel, on nameplates |
| `/rl lock`, `/rl unlock` | Lock the panel, or unlock it to drag |
| `/rl size <n>`, `/rl panelsize <n>` | Icon sizes |
| `/rl offset <n>`, `/rl offsetx <n>` | Nameplate row up / down, left / right |
| `/rl minimap` | Show or hide the minimap button |
| `/rl debug` | Print what the game answers for your target and every nameplate |
| `/rl reset` | Restore the settings, keeping your spell list |

## Limits

- The game only answers "within this many yards?" for a few fixed distances, so the distance shows as a bracket, and a 10 yard spell's icon lights at 10 yards even when a talent makes the spell reach a little further. It never lights early.
- Cone of Cold is checked for distance only, not for which way you are facing.

## Reporting a problem

Stand near the mob in question, type `/rl debug`, and include what it prints.

## Credits

The distance checks follow [LibRangeCheck-3.0](https://github.com/WeakAuras/LibRangeCheck-3.0) by mitch0 and the WoWUIDev community (MIT licence). Its in-game measurements and its list of items with known use ranges make the 10 yard checks and the distance readouts possible.

## License

MIT. See [LICENSE](LICENSE).

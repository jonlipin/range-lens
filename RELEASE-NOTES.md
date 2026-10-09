## 1.16.2 - 2026-10-08

- Fixed: opening the options in combat gave a UI error, because the game does not let an addon open its options window during combat. The minimap button and `/rl` now say the options will open when combat ends, and open them then.
- Fixed: that blocked attempt also switched Range Lens's distance checks off for the rest of the session, so the range text and the aggro eye stopped showing until a reload. A blocked action no longer turns any checks off.
- Eye position: Eye left / right and Eye up / down sliders move the aggro eye from its place just left of the health bar, on nameplates, the target panel and the preview.

## 1.16.1 - 2026-10-08

- Glow on or off: Eye glow (under Aggro eye) turns the yellow or red glow behind the aggro eye on or off, and Light glow (under Range) the soft halo around the range light. Both are on unless you turn them off.

## 1.16.0 - 2026-10-08

- The aggro warning is the dungeon finder eye now, animated as the game animates it in its own queue button: searching, on a yellow glow, as you near a mob's estimated aggro range, and fixed on you, on a pulsing red glow, inside it. The size slider is now Aggro eye size (10 to 40, default 20).
- Range as a light: under Range, Show as switches between Numbers and Light. The light is green while the mob is within the first distance you set, yellow within the second, red beyond (Green up to and Yellow up to, default 10 and 30 yards), so you can set it to your spells instead of reading numbers. It sits where the range text would and follows the same Position and Text size. In the Where to show grid the row is now called Range.

## 1.15.0 - 2026-10-08

- Where to show: one grid in the options replaces the scattered on/off checkboxes. For each part (spell icons, range text and the aggro light) tick where it shows: All (every enemy nameplate), Target, Focus, and Panel (the target panel). Each part is set on its own, so for example the range text can show on every nameplate while the spell icons only show on your target. Your settings carry over.
- The aggro light is yellow when you near a mob's estimated aggro range and red inside it, and no longer green when you are clear (green read as safe to go). It is turned on in the grid, and a new Aggro light size slider sets its size.
- The slash commands that switched these parts now switch the matching grid boxes: `/rl plates`, `/rl targetonly`, `/rl focusonly`, `/rl panel` (spell icons), `/rl platedistance`, `/rl distance` (range text) and `/rl aggro` (aggro light on every nameplate and the panel).

## 1.14.4 - 2026-10-08

- The aggro light is a crisper circle now, a solid round light with a thin dark rim and a little glow behind it, and it sits directly left of the mob's health bar. On the target panel it sits just left of the icons.

## 1.14.3 - 2026-10-08

- The aggro warning is a glowing circle now, using the game's own soft glow: green while you are clear of a red mob's estimated aggro range, yellow within the warning distance, and red and pulsing inside it.
- ?? mobs are no longer all treated as 45 yards: a raid boss counts as 3 levels above you (about 23 yards at your level, as Classic's level 63 bosses), and any other ?? mob as 10 levels above (about 30 yards).

## 1.14.2 - 2026-10-08

- The aggro warning now warns before you reach a mob's aggro range, not once you are in it: a yellow "!" when you are within a set distance of its estimated edge, turning red once you are inside. Set the distance with the new Warn yards early slider (0 to 15, default 5). The option is now called Warn before aggro range, and `/rl debug` shows where the warning starts for each mob.

## 1.14.1 - 2026-10-08

- Fixed: the minimap button (and `/rl`) sometimes opened Range Lens's own standalone window instead of the game's options. The game's options window can take a moment to appear, and Range Lens checked too soon, decided it had failed, and used its own window for the rest of the session. It now always opens the game's options at the Range Lens page.

## 1.14.0 - 2026-10-08

- Aggro warning (off unless you switch it on, under Aggro warning in the options, or `/rl aggro`): a red "!" on a mob's icon row, and on the target panel, while you are inside its estimated aggro range. It is an estimate, because the game keeps the real range to itself: about 20 yards for a mob of your level, 1 yard less per level you are above it and 1 more per level below, kept within 5 to 45 yards (45 for ?? mobs). It only covers red mobs, only out of stealth, and not once the mob is fighting. It lights only when a distance check proves you are inside the estimate, so it can light a little late but never early. `/rl debug` shows each mob's estimate.

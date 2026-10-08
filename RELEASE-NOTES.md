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

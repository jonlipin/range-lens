## 1.14.1 - 2026-10-08

- Fixed: the minimap button (and `/rl`) sometimes opened Range Lens's own standalone window instead of the game's options. The game's options window can take a moment to appear, and Range Lens checked too soon, decided it had failed, and used its own window for the rest of the session. It now always opens the game's options at the Range Lens page.

## 1.14.0 - 2026-10-08

- Aggro warning (off unless you switch it on, under Aggro warning in the options, or `/rl aggro`): a red "!" on a mob's icon row, and on the target panel, while you are inside its estimated aggro range. It is an estimate, because the game keeps the real range to itself: about 20 yards for a mob of your level, 1 yard less per level you are above it and 1 more per level below, kept within 5 to 45 yards (45 for ?? mobs). It only covers red mobs, only out of stealth, and not once the mob is fighting. It lights only when a distance check proves you are inside the estimate, so it can light a little late but never early. `/rl debug` shows each mob's estimate.

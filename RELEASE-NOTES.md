## 1.6.0 - 2026-10-02

- Spells that hit around you now come from the game's own spell data instead of a short hand-written list: 24 spells across every class, each with Blizzard's radius. New ones include Thunder Clap, Psychic Scream, Consecration and Whirlwind (8 yards), Demoralizing Shout and Roar, Challenging Shout and Roar, Piercing Howl (10 yards), Holy Wrath (20) and Starfall (30).
- Fixed: Intimidating Shout was listed as a 10 yard spell around you. It is aimed at a target, so the game's own range check now handles it.
- Every one of these spells can be tuned. In the options list, the - and + buttons next to an area spell move its reach a yard at a time, and the label shows the data's radius when yours differs. Or type `/rl reach <spell> <yards>` (for example `/rl reach Thunder Clap -1`), and `/rl reach <spell>` to reset it. Tuning is shared by all your characters.
- Frost Nova keeps the tuning found in game: checked 1 yard short of its 10 yard radius, for the freeze. Its options label now reads "9 yd around you (data 10)".

# Changelog

All notable changes to Range Lens are listed here. The newest release is at the top.

## 1.2.0 - 2026-10-01

- New option, Target's nameplate only: the nameplate icons show under your current target's nameplate and nowhere else. The target panel is unchanged. Also `/rl targetonly`.
- New option, Hide nameplate icons in melee range: a nameplate's icons disappear while that mob is within 5 yards, and come back as it moves away. Also `/rl melee`.
- Both are off unless you switch them on, under Options > AddOns > Range Lens.

## 1.1.0 - 2026-09-29

- Too close shows in orange. A spell with a minimum range, such as Charge (8 to 25 yards), now tells you which side you are on: the icon and its cooldown sweep turn orange while you are inside the minimum, and stay red when you are too far. `/rl debug` adds "(too close)" to such a spell.

## 1.0.3 - 2026-09-29

- The cooldown sweep is dark now. It had been drawn pale; it is now black at 85% (the Cooldown Manager uses 70%), and it turns red while the spell is out of range.
- Fixed: switching cooldowns off, or a spell with no cooldown data, called a function the game reserves for its own code. The sweep is now simply hidden instead.

## 1.0.2 - 2026-09-29

- Frost Nova's freeze turned out to reach past 8 yards, so 1.0.1 lit its icon too late. The icon is now checked 1 yard short of the spell's radius: 9 yards, or 11 with Arctic Reach at 2/2 (checked at 10).
- New 9 yard check: the game's trade distance. It is checked against the 8 yard duel distance as it runs, and if it ever says a unit inside 8 yards is out of trade range, Range Lens stops using it for the session and Frost Nova falls back to 8 yards. `/rl debug` says when that happens.
- The distance readouts gain a 9 yard step.

## 1.0.1 - 2026-09-29

- Frost Nova's icon now lights when the freeze will land, not just the damage. On WoW Forever the freeze reaches 1 to 2 yards less than the damage, so the icon is checked 2 yards short of the spell's radius: 8 yards, or 10 with Arctic Reach at 2/2. The icon and the options show that reach (for example "8 yd freeze (10 yd damage)").

## 1.0.0 - 2026-09-28

First release.

- Spell icons under every enemy nameplate and on a movable target panel. Full colour means the spell can reach; dark red means it can't.
- Icons drawn with Blizzard's own Cooldown Manager art: rounded icon, soft shadow, out of range tint and cooldown sweep, with the countdown on the panel.
- Options on the game's own Options > AddOns > Range Lens page, opened from the minimap button or `/rl`: pick spells from your spellbook, display toggles, and sliders for icon sizes and for moving the nameplate icons.
- The spell's range in yards on each icon.
- A live distance to your target above the panel and to each mob beside its nameplate, shown as a bracket such as 10-20.
- Frost Nova, Arcane Explosion, Cone of Cold, Blast Wave, Hellfire, Howl of Terror, Holy Nova and Intimidating Shout checked at 10 yards, with Arctic Reach counted for Frost Nova and Cone of Cold.
- `/rl debug` prints what the game answers for your target and every nameplate.

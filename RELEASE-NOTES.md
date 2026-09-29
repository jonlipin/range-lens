## 1.0.2 - 2026-09-29

- Frost Nova's freeze turned out to reach past 8 yards, so 1.0.1 lit its icon too late. The icon is now checked 1 yard short of the spell's radius: 9 yards, or 11 with Arctic Reach at 2/2 (checked at 10).
- New 9 yard check: the game's trade distance. It is checked against the 8 yard duel distance as it runs, and if it ever says a unit inside 8 yards is out of trade range, Range Lens stops using it for the session and Frost Nova falls back to 8 yards. `/rl debug` says when that happens.
- The distance readouts gain a 9 yard step.

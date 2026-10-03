# Changelog

All notable changes to Range Lens are listed here. The newest release is at the top.

## 1.12.1 - 2026-10-03

- The distance text's Shadow depth option is now called Text shadow. It works the same: 0 for no shadow, up to 4.

## 1.12.0 - 2026-10-03

- Format the distance text. A new Distance text section in the options sets:
  - Format: 8-12 (the range), 12 (the far end), <12, or ~10 (the middle)
  - Position: right of the icons, below them or above them
  - Colour: white, gold, grey or light blue
  - Show "yd" after the number
  - Text size and text shadow, as sliders you can also type into
- These apply to the distance on nameplates and on the target panel, and the nameplate preview shows every change as you make it. Click a choice to step forward; right-click to step back.
- The target panel's distance now follows the Position setting too. It used to sit above the panel; choose Above icons to keep it there.

## 1.11.1 - 2026-10-02

- Type exact values: the number beside each size and position slider is now a box you can type in, negative numbers included. Press Enter (or click away) to apply it, and the slider moves to match. Typed values are kept inside the slider's range.

## 1.11.0 - 2026-10-02

- The settings are one column now, grouped under Icons, Which nameplates and Size and position, with their own scroll bar. The spell list gets the freed width, so long entries such as "Frost Nova 9 yd around you (data 10)" are readable in full.

## 1.10.8 - 2026-10-02

- Arcane Explosion reaches about 9.5 yards standing still on WoW Forever, short of the 10 in its spell data, so its icon lit a little early. It is now checked at 9 yards, like Frost Nova, and its options label reads "9 yd around you (data 10)". Unlock it to set a different reach.

## 1.10.7 - 2026-10-02

- Fixed: the preview's mob name and level number stayed the same size when you changed the game's nameplate Size. They now grow and shrink with it, by the same rule the game uses for its own nameplates.

## 1.10.6 - 2026-10-02

- Fixed: before a real nameplate had been measured, the preview's health bar came out too wide. The estimate now uses the bar's own width (130 at Medium size) rather than the whole plate's, which also holds the level badge, so it matches the game's own nameplate preview.

## 1.10.5 - 2026-10-02

- Fixed: the nameplate preview came out too small. It is now drawn at the options window's own scale, like the game's nameplate preview, instead of shrinking with the Range Lens page when that page is scaled to fit. Before a real nameplate has been measured, its size now comes from Blizzard's own nameplate sizes for your Size and Style.

## 1.10.4 - 2026-10-02

- Fixed: the nameplate preview came out larger than the game's own nameplate preview, and sat off-centre. It now takes a real nameplate's size relative to the nameplate itself and draws it in the options at that size, the way the game's preview does, so the two match. It is centred in its box. Earlier measurements are cleared once so they are taken again.

## 1.10.3 - 2026-10-02

- Fixed: the nameplate preview changed size from one visit to the next. The game shrinks nameplates with distance and enlarges your target's, and the preview copied whichever plate it had last seen. It now leaves that scaling out and draws the base size, the same as the game's own nameplate preview. Earlier measurements are cleared once so they are taken again.

## 1.10.2 - 2026-10-02

- The nameplate preview now runs across the whole top of the options page, with the settings and the spell list below it, so icons moved far left or right stay in view.
- The preview's nameplate is drawn at the real nameplate's scale as a whole: its name, health bar, level badge and icons all come out the size they are in game. Before, only the bar was scaled, and the name and badge came out small.
- The preview's level badge sits right beside the health bar, as on real nameplates.

## 1.10.1 - 2026-10-02

- The nameplate position sliders reach further: up / down from -100 to 100 (was -40 to 20) and left / right from -200 to 200 (was -80 to 80). The preview box is taller to show the extra room.

## 1.10.0 - 2026-10-02

- The nameplate preview follows the game's own nameplate settings (Options > Nameplates). Change Size or Style there and the preview redraws to match, including the Classic style's old bar and border. Range Lens measures a real nameplate under each Size and Style you use; until it has, the preview estimates from Blizzard's own scale tables and says so above the plate.

## 1.9.0 - 2026-10-02

- The nameplate preview now looks like the game's own nameplate: the same health bar and frame art, the level badge, and the nameplate fonts. Its size and scale are measured from a real nameplate the first time one is on screen, so your icon size and offsets show in the preview exactly as they will in game.
- Drop placeholder: while you drag an icon in the preview, the others slide apart and an outlined gap shows where it will land.
- Fixed: option names in the settings column overlapped the next column. The column is wider and its second half starts further right.

## 1.8.0 - 2026-10-02

- Nameplate preview in the options, above the spell list: a mock nameplate with your icon row exactly as it will look on real ones, with your icon size, range numbers, distance and position. It redraws as you change any option.
- Drag and drop to reorder: drag an icon in the preview along the row and drop it where you want it. The spell list and the real nameplates follow.

## 1.7.0 - 2026-10-02

- Unlock a spell to set its reach by hand. Every spell in the options list has an Unlock button: it opens a slider and a box with the reach in yards. Type a number or drag the slider, and each follows the other. Lock returns the spell to automatic. This works for spells you aim too: an unlocked one is checked with the distance checks at your number instead of the game's own range check. `/rl reach <spell> <yards>` does the same, and `/rl reach <spell>` locks it again. Hand-set reaches are shared by all your characters.
- The - and + buttons from 1.6.0 are replaced by Unlock. Any reach you tuned with them carries over.
- Change the order of your spells. Ticked spells now sit at the top of the list in the order their icons appear, and < and > move one a place left or right along the row.
- The options use the whole page: settings on the left, and the spell list filling the rest of the width and height on the right.

## 1.6.0 - 2026-10-02

- Spells that hit around you now come from the game's own spell data instead of a short hand-written list: 24 spells across every class, each with Blizzard's radius. New ones include Thunder Clap, Psychic Scream, Consecration and Whirlwind (8 yards), Demoralizing Shout and Roar, Challenging Shout and Roar, Piercing Howl (10 yards), Holy Wrath (20) and Starfall (30).
- Fixed: Intimidating Shout was listed as a 10 yard spell around you. It is aimed at a target, so the game's own range check now handles it.
- Every one of these spells can be tuned. In the options list, the - and + buttons next to an area spell move its reach a yard at a time, and the label shows the data's radius when yours differs. Or type `/rl reach <spell> <yards>` (for example `/rl reach Thunder Clap -1`), and `/rl reach <spell>` to reset it. Tuning is shared by all your characters.
- Frost Nova keeps the tuning found in game: checked 1 yard short of its 10 yard radius, for the freeze. Its options label now reads "9 yd around you (data 10)".

## 1.5.0 - 2026-10-02

- New option, Only show spells in range: a spell's icon shows only while it can reach, instead of turning red (or orange when too close). Each icon keeps its place, so the row doesn't shift as spells come and go. Works on the nameplates and the target panel. Also `/rl inrange`.
- The options are regrouped a little to make room for it.

## 1.4.0 - 2026-10-02

- New option, Only on focus's nameplate, next to Only on target's nameplate. Tick one to show the nameplate icons only there, tick both for your target and your focus, or leave both clear for every enemy nameplate. Also `/rl focusonly`.
- The melee option is now labelled Hide in melee range, and the nameplate options are grouped together with a note on how the two limits combine.

## 1.3.0 - 2026-10-01

- Settings are now saved per character: the panel's position, icon sizes, nameplate offsets and every option. The spell list already was. Each character starts from the settings you had before this update, so nothing resets, and from then on changing one character leaves the others alone.
- Fixed: characters set up with the very first version kept that version's faint out-of-range look (45% strength). It is now full strength, as intended. `/rl dim` still sets it.

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

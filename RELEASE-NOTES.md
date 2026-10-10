## 1.17.0 - 2026-10-10

- Window styles: a new Look section at the bottom of the options picks the Window style, Automatic, Blizzard or Dark (click to step forward, right-click to step back), with a Dark background opacity slider (0 to 100) for the Dark style. Automatic uses EllesmereUI's look when it is installed, otherwise Blizzard's. Changing style offers a reload. `/rangelens style` does the same from chat (`/rangelens style auto`, `blizzard` or `dark`).
- The range icons follow the style: the Cooldown Manager's rounded icons in Blizzard, and square icons with a thin black edge and a square cooldown sweep in Dark and EllesmereUI, the way EllesmereUI's own Cooldown Manager draws them. Red, orange and the sweep colors mean the same as before. The options page keeps the game's own look in every style.
- EllesmereUI nameplates: the icons, range text and aggro eye now sit on EllesmereUI's nameplates. Before, they were placed on the game's hidden nameplate underneath and showed up in the wrong place.
- The nameplate preview in the options is drawn from your EllesmereUI nameplate settings when you use them: bar size, colors, border, the name, level and health texts where you placed them, and your target as the sample mob. The label says it matches once it has read those settings and seen a real nameplate.
- New command: `/rangelens`. EllesmereUI and Leatrix Plus both use `/rl` to reload the interface, so `/rl debug` reloaded instead of printing. `/rl` still works for Range Lens when no other addon has it, and `/rangelens help` says which.
- The Range options show only what applies to how you show range: the light's settings appear with Show as Light, and the Range numbers group (format, color, "yd", text shadow) with Show as Numbers. Everything below closes up, so there are no gaps.
- Fixed: the options page could open empty, showing only its title, the first time you went to it through Esc > Options > AddOns. It now fills in on the first visit.
- Fixed: in the Dark style the black edge around nameplate icons could come out many pixels thick when the icons were first drawn. It is now sized again every time the icons are laid out.
- Fixed: the close button on the standalone options window now works in combat.
- American spelling throughout ("color", "gray", "center"). If you had picked the gray distance color, it is kept.

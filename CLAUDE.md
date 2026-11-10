# Archmage HUD

WoW Forever addon (interface 16001, Lua 5.1). English UI; the owner talks German.

## Check every change

1. `lua5.1 tests/run.lua` - offline client, secret values in combat; must print `all good`.
2. `node tests/render/shot.js` - renders the frames the addon really builds (anchors, sizes, colours, text)
   for the HUD of each spec in combat, the alerts, edit mode and every settings page into
   `tests/render/out/*.png`. **Open and look at every PNG** before calling a change done: overlaps,
   cut-off or misplaced text, empty rows, wrong icons. Send the relevant ones to the owner.
   Extend `tests/render/scene.lua` when a change adds a frame or state worth seeing.
   These are renders from the offline client, not in-game screenshots: say so.
   The run ends with a text check (text wider than its field, sticking out of its frame, cut off, or on
   top of another text; HUD frames covering each other): it must print `text check: all good`.
   The page font is DejaVu Serif, a little wider than the game's Friz Quadrata, so what fits here fits in game.

## Pitfalls already hit

- `bind()` (two return values) must be the last argument of a call, or only `get` arrives.
- Text with a TOPLEFT point plus a RIGHT point gets its vertical centre pinned too: use a width instead.
- `PLAYER_REGEN_DISABLED` fires before `InCombatLockdown()` is true: visibility uses `NS.InCombat()`.
- A value that may be secret is never compared, not even `== nil`: check `NS.IsSecret(v)` first.
- Setters that take secrets from addon code: `SetText`, `SetValue`, `SetMinMaxValues`, `SetStatusBarColor`.
  `StatusBar:SetTimerDuration` takes a secret duration only from Blizzard code: try it in `pcall`, keep a fallback.
- Text scales with Appearance > Text size (0.7 - 1.2x) inside frames of a fixed size: give a text field room for
  1.2x, or size the frame from `GetStringWidth()` (proc card, edit-mode overlays).
- Native aura slots: retry with `later()` when auras are secret out of combat, never `AfterCombat` alone.

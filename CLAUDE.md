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

## Pitfalls already hit

- `bind()` (two return values) must be the last argument of a call, or only `get` arrives.
- Text with a TOPLEFT point plus a RIGHT point gets its vertical centre pinned too: use a width instead.
- `PLAYER_REGEN_DISABLED` fires before `InCombatLockdown()` is true: visibility uses `NS.InCombat()`.
- Native aura slots: retry with `later()` when auras are secret out of combat, never `AfterCombat` alone.

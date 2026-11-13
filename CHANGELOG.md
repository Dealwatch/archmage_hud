# Changelog

## 0.2.1
Fix from the first in-game test.
- Lua error `Stacks.lua:281: calling 'SetStatusBarColor' on bad self (Attempt to access forbidden object ...)`,
  on every aura change: a bar, text, icon or swirl handed to the client's aura slot is forbidden to addon code
  from then on, and the stack bar was recoloured afterwards. The addon no longer touches such a widget after
  handing it over
- The same mistake had silently kept the debuff bars and the rotation marks from using the client's aura slots
  (they fell back to the addon's own timers, and the marks did not light up in combat). They are built in the
  right order now
- Gold at full stacks is the addon's own layer over the stack bar. The stack bar has its spec's accent colour
  from the start; a changed accent colour or text size reaches the bars the client draws after a /reload at the
  latest
- The offline test client forbids handed-over widgets like the game does, so this cannot come back unnoticed

## 0.2.0
The rotation, shown without more clutter, and a few things that make a mage's day easier. Nothing here decides for
you: the marks are a fixed list that the client lights up from your stacks (as it fills the stack bar), and the
opener follows only your own casts.
- Rotation marks under the stack bar: the icon of the spell to cast at that many stacks, grey until the client
  lights it up gold (Arcane: Arcane Wrath at 3, Arcane Power at 4; Fire: Pyroblast at 3; Frost: Cone of Cold at 5).
  Lit by the client, so they work in combat, where the stacks are hidden from addons and the gold bar and its hint
  cannot show
- Arcane: Heating Up is small pips in the row of the marks, with its own mark (Pyroblast at 3), instead of a number
  on a proc icon
- Opener: your spec's first casts in the place of the proc card before the pull, ticked off as you cast, the next
  one glowing gold, gone when it is through
- The column is ordered by what you do with it: proc card, stacks and marks, mana, cast bar and the cooldown row on
  top (act), your debuffs and the Polymorph timer below (watch). Gold always means "cast this"
- Larger numbers on the stack timer and the debuff bars, larger stack bar name; smaller countdown numbers on the
  small cooldown icons
- The stack bar's hint is the spell's name in your client's language, like the proc card ("Pyroblast!",
  "Arcane Wrath!", "Cone of Cold!"); text size starts at 0.8x (smaller was not readable); alert cards are a little
  taller so title and text keep apart at 1.2x
- The default font is the client's own standard font, so localized spell names have their glyphs on Russian,
  Korean and Chinese clients too
- `/mage legend` (also in Appearance): one sentence beside every HUD element for 10 seconds
- Mana gem and Evocation as two small icons at the end of the mana bar, with their cooldowns; the gem is grey when
  you have none. Evocation left the cooldown row
- Ready check: one card, "All set" or the consumables that are missing (weapon oil, mana potions, conjured water)
- Polymorph on your focus: a bar under the debuffs with the time left (only while you have a focus)
- Cooldown row in two tiers: your spec's cooldowns large, the shared ones small and dimmed
- Presets in the overview: Minimal (stack bar, procs, cast bar), Standard, Full (the default: everything above)
- Render check: settings pages are rendered scrolled to their end too, with the scroll area clipped as in game

## 0.1.0
First test build for WoW Forever, as Archmage HUD (`/mage` or `/amh`). Built on the Shammy Forever framework (settings window, edit mode, alerts,
native aura slots, probe).
- Spec switch: Auto (from your talents), Arcane, Fire, Frost. In the overview, or `/mage arcane|fire|frost|auto`.
  Procs, stack bar, debuffs, cooldowns and the accent colour follow the spec
- Stack bar: Arcane Blast (Arcane), Heating Up (Fire), Winter's Chill on the target (Frost), gold at full with glow,
  sound and hint
- Procs: only what is up right now (Missile Barrage, Clearcasting, Fingers of Frost, Combustion, Wake of Fire,
  Presence of Mind, Arcane Power), plus a big proc card while the client lights up a spell
- Target debuffs with the real time left: Fire Vulnerability, Fireball, Ignite, Pyroblast, Frostfire Bolt (Fire, the last
  only in the Frostfire build);
  Frost Nova, Frostbite (Frost: target frozen = Ice Lance window)
- Cooldown row: spec cooldowns plus Frost Nova, Blink, Counterspell, Ice Block, Evocation
- Arcane follows the Forever hybrid play: Heating Up in the proc row, Fire Blast in the cooldown row,
  time left of the Arcane Blast window next to the stack bar
- Automatic layout per spec: the HUD column closes up around what the spec uses (Fire 4 debuff rows, 5 with Frostfire,
  Frost 2, Arcane none; switched-off modules and unknown spells take no space). Moved frames are saved
  per spec; right-click in edit mode returns a frame to the automatic layout
- Ignite, Fire Vulnerability and Frostbite rows appear once you have the talent (Ignite, Improved Scorch, Frostbite);
  spec detection is deterministic for hybrid and low-level talent sets
- Mana bar
- New: cast bar in the HUD column under the mana bar (calm neutral colour, name and time left, channels
  drain, a finished cast stays full for a moment, red when interrupted, also out of combat). Fill from the
  client's duration object where the client allows it, else from the cast times, readable or secret
  (then without time text); `/mage probe` tells which. Blizzard's own cast bar is switched off while it is
  on, with C-side calls only (no taint); turning it back on needs a /reload. Aligned with Farseer's cast bar
- Fixes taken over from Farseer's in-game test: settings sliders save (they never did: `bind()` in the middle of
  an argument list yields one value), test that every slider saves; proc icon size applies without /reload;
  edit-mode grid redraws; settings text no longer runs under buttons; mana bar turns red in combat through a
  colour curve; native slots retry once per slot; `/mage probe` reports mana
- Cooldown icons flash once when the cooldown your cast started is over (Fire Blast and Ice Lance flash together)
- Frost: the absorb icon turns red and pulses while Ice Barrier is not up (buffs are secret in combat)
- WowUp: releases are built when a GitHub release is published (zip + release.json); MIT license
- Release check against renders of the real frame tree: text anchored with TOPLEFT plus RIGHT (which also pins
  the vertical centre) now uses widths instead (alerts, edit-mode header, overview, module cards, setting rows);
  setting rows grow with a wrapped description; debuff stacks sit on the bar; the stack timer clears the glow;
  edit-mode grid redraw fixed; Frostfire Bolt row only in the Frostfire build; tests for every switch
- Robust for the first test: frames are never really hidden while combat starts (a pull at 0 stacks
  kept the stack bar hidden), no endless retry when auras are secret out of combat (battlegrounds,
  encounters), unreadable buffs out of combat never warn, aura frames are only moved/resized out of
  combat, the proc card shows the newest lit spell, talent rows also appear once their debuff was seen
- Text and overlap check (renders with a font as wide as the game's, checked by a script): text size goes up to
  1.2x (above that, text ran over in alerts, the proc card and the settings window; use HUD scale for more);
  the proc card is as wide as its spell name; the stack bar's name gives way to the gold hint when both do not
  fit; edit-mode overlays are darker and at least as large as their name, the edit-mode header has room for two
  lines; overview tiles and module cards fit their longest text; slider values ("20 runes", "10m 00s") no longer
  touch the slider; the absorb icon sits left of the widest bar; debuff icons follow the height setting without
  a /reload; a spell pressed during a channel (Arcane Missiles) no longer shows "Failed" on the cast bar
- Reminders: Arcane Intellect, armor, Ice Barrier (Frost), mana gem, teleport/portal runes; absorb icon for Ice Barrier / Mana Shield
- Forever spell IDs: Arcane Blast, Arcane Wrath, Missile Barrage, Heating Up, Fingers of Frost, Ice Lance,
  Frostfire Bolt, Ignite, Wake of Fire, Teleport: Dalaran

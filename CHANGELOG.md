# Changelog

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
  drain, red flash when interrupted, also out of combat). Blizzard's own cast bar is switched off while it
  is on (setting). Works with secret cast times too (bar fills, no time text); `/mage probe` tells which
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
- Reminders: Arcane Intellect, armor, Ice Barrier (Frost), mana gem, teleport/portal runes; absorb icon for Ice Barrier / Mana Shield
- Forever spell IDs: Arcane Blast, Arcane Wrath, Missile Barrage, Heating Up, Fingers of Frost, Ice Lance,
  Frostfire Bolt, Ignite, Wake of Fire, Teleport: Dalaran

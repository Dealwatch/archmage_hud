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
- Target debuffs with the real time left: Fire Vulnerability, Fireball, Ignite, Pyroblast, Frostfire Bolt (Fire);
  Frost Nova, Frostbite (Frost: target frozen = Ice Lance window)
- Cooldown row: spec cooldowns plus Frost Nova, Blink, Counterspell, Ice Block, Evocation
- Arcane follows the Forever hybrid play: Heating Up in the proc row, Fire Blast in the cooldown row,
  time left of the Arcane Blast window next to the stack bar
- Automatic layout per spec: the HUD column closes up around what the spec uses (Fire 5 debuff rows,
  Frost 2, Arcane none; switched-off modules and unknown spells take no space). Moved frames are saved
  per spec; right-click in edit mode returns a frame to the automatic layout
- Ignite, Fire Vulnerability and Frostbite rows appear once you have the talent (Ignite, Improved Scorch, Frostbite);
  spec detection is deterministic for hybrid and low-level talent sets
- Mana bar
- Reminders: Arcane Intellect, armor, Ice Barrier (Frost), mana gem, teleport/portal runes; absorb icon for Ice Barrier / Mana Shield
- Forever spell IDs: Arcane Blast, Arcane Wrath, Missile Barrage, Heating Up, Fingers of Frost, Ice Lance,
  Frostfire Bolt, Ignite, Wake of Fire, Teleport: Dalaran

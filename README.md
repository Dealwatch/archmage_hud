# Mage Forever

Mage HUD for **WoW Forever** (interface 16001, build 1.60.1). Working title.

One clean HUD for Arcane, Fire and Frost. It shows procs, your spec's stacks, your debuffs on the target,
cooldowns and mana, plus reminders for Intellect, armor, mana gem and runes. You can switch the spec, and every
element can be moved, resized or switched off. The addon is in English.

Same look and handling as *Shammy Forever* (settings window, edit mode, alerts).

> Status: **0.1.0, first in-game test pending.** It is built against Blizzard's Forever UI code
> and an offline test client. Nothing is confirmed in the real game yet.

## Install

1. Download `MageForever-<version>.zip` (from a release, or the zip you were sent).
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns\` so that you get
   `...\AddOns\MageForever\MageForever.toc` (not `MageForever\MageForever\...`).
3. Restart the game completely. A `/reload` is not enough for a new addon.
4. Character select > **AddOns**: make sure *Mage Forever* is ticked.

## Specs

The spec is detected from your talents (**Auto**) or set by hand: `/mage arcane`, `/mage fire`, `/mage frost`,
`/mage auto`, or in the overview of `/mage`. The procs, stack bar, debuffs, cooldowns and accent colour all follow it.

| Spec | How it is played on Forever | What the HUD shows |
|---|---|---|
| **Arcane** | Build Arcane Blast stacks (4, 18 s), spend them on Arcane Wrath (6 s cooldown). Free, fast Arcane Missiles when Missile Barrage procs. Arcane Power + Presence of Mind for burst. | Stack bar: **Arcane Blast** (4). Procs: Missile Barrage, Clearcasting, Presence of Mind, Arcane Power. Cooldowns: Arcane Wrath, Arcane Power, Presence of Mind |
| **Fire** | Fire Blast on cooldown, crits build **Heating Up** (3 stacks, each -25% cast time on Pyroblast, which is a 6 s cast on Forever), then Pyroblast. Scorch keeps your Fire Vulnerability at 5 stacks. Ignite rolls. Fireball / Frostfire Bolt as filler. Combustion for burst. | Stack bar: **Heating Up** (3, "Pyroblast!"). Debuffs: Fire Vulnerability (stacks), Ignite, Pyroblast, Frostfire Bolt. Procs: Combustion, Wake of Fire, Clearcasting, Missile Barrage. Cooldowns: Fire Blast, Combustion, Blast Wave |
| **Frost** | Frostbolt filler. Ice Lance (x4 damage) on frozen targets (Frost Nova, Frostbite) or with Fingers of Frost charges. Frostbolt builds **Winter's Chill** (5 stacks) for a strong Cone of Cold. Keep Ice Barrier up. | Stack bar: **Winter's Chill** on the target (5, "Cone of Cold!"). Debuffs: Frost Nova and Frostbite (target frozen = Ice Lance window). Procs: Fingers of Frost (charges), Clearcasting, Missile Barrage, Presence of Mind. Cooldowns: Ice Lance, Ice Barrier, Cone of Cold, Cold Snap |

Every spec also gets Frost Nova, Blink, Counterspell, Ice Block and Evocation in the cooldown row. Only spells you
know are shown. Fire Blast and Ice Lance share one 8 s cooldown on Forever.

Not on Forever, so not tracked: Living Bomb, Icy Veins, Arcane Barrage, Brain Freeze, Molten Armor, Water Elemental and the SoD runes.

## Quick start

1. `/mage` opens the settings window. The overview has the spec switch, the state of your buffs and stacks,
   and one switch per module.
2. `/mage edit` (or **Edit layout**) shows every frame with a label. Drag them where you want them, then click **Done**.
3. Fight something. The HUD shows in combat and while an enemy is targeted. Out of combat it is hidden;
   only alerts stay on screen.

## Commands

| Command | |
|---|---|
| `/mage` (or `/mageforever`) | Settings window |
| `/mage arcane` / `fire` / `frost` / `auto` | Switch spec |
| `/mage edit` | Edit mode: drag frames (snaps to the grid, Shift = free), arrow keys nudge (Shift = 10px), right-click resets a frame |
| `/mage test` | Preview the alerts for 8 seconds |
| `/mage probe` | Shows what Forever lets the addon read right now. Run it once out of combat and once **in combat** |
| `/mage spells` | Copyable list of your spellbook with spell IDs |
| `/mage reset confirm` | Reset all settings and positions |

The addon also has an entry in the minimap's addon compartment.

## Default layout

```
          [Pyroblast!]                Proc card: while the client lights up a spell
        [MB][CC][AP]                  Procs: only what is up right now (centred)
Heating Up              Pyroblast!
[=======|=======|       ]             Stack bar (Arcane Blast 4 / Heating Up 3 / Winter's Chill 5)
[==============          ]            Mana
[F][=============   22.1]             Your debuffs on the target, one bar each
[I][======          2.3]

[FB][CB][BW][FN][BL][CS][IB][EV]  [IB]
            Cooldowns              Absorb (Ice Barrier / Mana Shield)
```

Alerts stack at the top of the screen. All positions are saved per account.

## Modules

| Module | What it shows | Settings |
|---|---|---|
| **Mana Bar** | Thin mana bar, red when low, hidden at full mana out of combat | width, height, red below %, percentage text, hide at full |
| **Procs** | One centred row that shows only active procs and burst buffs of your spec, with a time-left swipe and stacks. A big card ("Pyroblast!", "Ice Lance!") while the client lights up one of your spells, with an optional sound | icon size (after /reload), card on/off, sound |
| **Stack Bar** | Segmented bar for your spec's stacks, gold at full with a glow, a sound and a hint | width, height, glow, sound, hide at zero |
| **Target Debuffs** | Fire: Fire Vulnerability, Ignite, Pyroblast, Frostfire Bolt. Frost: Frost Nova, Frostbite. One bar per debuff of yours on the target, with the real time left and stacks | width, height |
| **Cooldowns** | Your spec's cooldowns plus the shared ones; the GCD is ignored. An icon glows while the client lights it up | icon size |
| **Reminders** | Alerts: Arcane Intellect missing, no armor spell, no mana gem, low on Runes of Teleportation/Portals. Absorb icon for Ice Barrier / Mana Shield with time left | each reminder on/off, also in combat, rune threshold, absorb icon and size, snooze time |

**Appearance:** accent colour (Mage, *Follow spec*, Arcane, Fire, Frost), font, text size, bar texture, sounds,
out-of-combat opacity (0% = hidden), show the HUD when an enemy is targeted, HUD scale, edit mode grid,
reset positions.

## How it copes with Forever's addon limits

Forever runs the modern engine. There is no combat log, and in combat auras and cooldown timings reach addons
as *secret values*: they can be shown but not compared or calculated with. Your own mana is secret too.
Mage Forever therefore

- lets the client draw: Blizzard's native aura container (`Blizzard_AuraContainer`) fills the stack bar,
  the proc row, the debuff bars and the absorb icon, even while the values are secret;
- uses events that are never secret: your own casts, spell activation glows (proc card, glowing cooldowns);
- hands secret values straight to widgets: duration objects for the cooldown swirls;
- never shows or hides those frames in combat (they fade instead) and re-reads exact state when combat ends;
- treats "unknown" as unknown: a value it cannot read never triggers a "missing" warning.

## Spells and IDs

Spells are found in your spellbook by name, so every rank and every client language works. Aura filters
need IDs, so the addon also carries the known IDs, including the Forever-only ones:

| Spell | ID (talent / buff) |
|---|---|
| Arcane Blast | 400574 / 400573 |
| Arcane Wrath | 1326079 - 1326082 |
| Missile Barrage | 400588 / 400589 |
| Heating Up | 400624 / 400625 |
| Fingers of Frost | 400647 / 400669 |
| Ice Lance | 1312002, 400640, 1240044 - 1240047 |
| Frostfire Bolt | 401502, 1237312, 1237313 |
| Ignite | 412538 |
| Wake of Fire | 1312934 |
| Teleport: Dalaran | 1297659 |

Plus every Classic rank of the other spells (see `Spells.lua`). `/mage spells` prints the IDs your client really uses.

## Testing in game

1. Optional but helpful: install **BugGrabber + BugSack**, or type `/console scriptErrors 1`.
2. Out of combat: `/mage` (screenshot the overview: is the spec right?), `/mage spells`, `/mage probe`,
   `/mage edit` (screenshot), `/mage test`.
3. Fight a few mobs for 2-3 minutes in your spec: proc row, stack bar (does it fill and turn gold?), proc card,
   debuff bars (Fire), cooldown swirls, absorb icon after Ice Barrier / Mana Shield.
4. **In combat**, with a few stacks up: `/mage probe`. Screenshot the HUD.
5. `/reload`, then send `World of Warcraft\_forever_\WTF\Account\<account>\SavedVariables\MageForever.lua`
   (it holds both probes and the spell list), the screenshots and any Lua errors.

### Troubleshooting

- `/mage` does nothing: the addon is not loaded. Check the folder path and the AddOns list at character select.
- Wrong spec: pick it by hand in `/mage` or with `/mage fire` etc.
- An alert or module gets in the way: switch it off in `/mage`, then keep testing the rest.
- A frame is off screen: `/mage edit` > **Reset all**.

### Open points for the first test

- Whether the native aura container works in the real client (`/mage probe` shows `native` per slot).
- Whether the client lights up spells for Heating Up / Missile Barrage / Fingers of Frost (proc card).
- The mana bar's red tint and "hide at full" need readable mana; with secret mana the bar just stays blue and visible.
- The debuff lists (Fire Vulnerability is personal on Forever and filtered as yours; Frostbite/Frost Nova count as yours).

## Project layout

```
MageForever.toc     load order, interface 16001
Core.lua            namespace, events, settings, spec switch, modules, slash commands, secret-value helpers
Spells.lua          spell table, what each spec watches, spellbook lookup, spec detection
UI/                 Theme (look, rounded textures), Movers (edit mode), Alerts, Native (aura container),
                    Widgets and Options (settings window)
Modules/            Mana, Procs, Stacks, Debuffs, Cooldowns, Reminders
Probe.lua           /mage probe and /mage spells
Media/              rounded-corner textures (TGA)
tests/run.lua       offline test client
```

## Development

`lua5.1 tests/run.lua` loads the addon into a fake client, including secret values in combat and the native
aura container. It drives login, every settings page, the spec switch, edit mode, the reminders, the stack bar,
the mana bar, a combat sequence with the proc card, and the fade. Any Lua error fails the run.

Releases: write the notes in `CHANGELOG.md` and push a tag `vX.Y.Z`. The GitHub Action runs the test and builds
the release zip (`.pkgmeta` leaves out `tests` and `.github`).

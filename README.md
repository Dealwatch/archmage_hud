# Archmage HUD

Arcane, Fire & Frost HUD for **WoW Forever** (interface 16001, build 1.60.1).

One clean HUD for Arcane, Fire and Frost. It shows procs, your spec's stacks, your debuffs on the target,
cooldowns and mana, plus reminders for Intellect, armor, mana gem and runes. You can switch the spec, and every
element can be moved, resized or switched off. The addon is in English.

Same look and handling as *Shammy Forever* (settings window, edit mode, alerts).

> Status: **0.1.0, first in-game test pending.** It is built against Blizzard's Forever UI code
> and an offline test client. Nothing is confirmed in the real game yet.

## Install

**WowUp:** *My Addons* > *Install from URL* > paste the GitHub address of this repository. Updates then show up
in WowUp by themselves (every published release).

**Manual:**

1. Download `ArchmageHUD-<version>.zip` (from a release, or the zip you were sent).
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns\` so that you get
   `...\AddOns\ArchmageHUD\ArchmageHUD.toc` (not `ArchmageHUD\ArchmageHUD\...`).
3. Restart the game completely. A `/reload` is not enough for a new addon.
4. Character select > **AddOns**: make sure *Archmage HUD* is ticked.

## Specs

The spec is detected from your talents (**Auto**) or set by hand: `/mage arcane`, `/mage fire`, `/mage frost`,
`/mage auto`, or in the overview of `/mage`. The procs, stack bar, debuffs, cooldowns and accent colour all follow it.

| Spec | How it is played on Forever | What the HUD shows |
|---|---|---|
| **Arcane** | Build Arcane Blast stacks (4, 18 s window). Clearcasting goes on Arcane Blast, Missile Barrage on Arcane Missiles, Arcane Wrath at 3-4 stacks (twice per window). Level 60 builds dip into Fire: Fire Blast on cooldown builds Heating Up, then Pyroblast at 4 stacks. Arcane Power / Presence of Mind at 4 stacks. | Stack bar: **Arcane Blast** (4) with the time left of the window. Procs: Missile Barrage, Clearcasting, Heating Up, Arcane Power, Presence of Mind. Cooldowns: Arcane Wrath, Fire Blast, Arcane Power, Presence of Mind |
| **Fire** | Scorch to 5 Improved Scorch stacks, Fire Blast on cooldown, crits build **Heating Up** (3 stacks, each -25% cast time on Pyroblast, a 6 s cast on Forever), then Pyroblast. Fireball filler. Fire Power rewards Fireball DoT, Improved Scorch, Ignite and Pyroblast DoT on the target. Combustion for burst. Frostfire variant: Frostfire Bolt filler, Ice Lance on Fingers of Frost. | Stack bar: **Heating Up** (3, "Pyroblast!"). Debuffs: Fire Vulnerability (stacks), Fireball, Ignite, Pyroblast, Frostfire Bolt. Procs: Combustion, Wake of Fire, Clearcasting, Missile Barrage, Fingers of Frost. Cooldowns: Fire Blast, Ice Lance, Combustion, Blast Wave |
| **Frost** | Frostbolt filler. Ice Lance (x4 damage) on Fingers of Frost, Frostbite or after Frost Nova. Arcane Missiles on Missile Barrage. Winter's Chill build: Cone of Cold at 5 stacks. Keep Arcane Intellect and Ice Barrier up at all times. | Stack bar: **Winter's Chill** on the target (5, "Cone of Cold!"). Debuffs: Frost Nova and Frostbite (target frozen = Ice Lance window). Procs: Fingers of Frost (charges), Clearcasting, Missile Barrage, Presence of Mind. Cooldowns: Ice Lance, Ice Barrier, Cone of Cold, Cold Snap. Alert when Ice Barrier is not up |

Every spec also gets Frost Nova, Blink, Counterspell, Ice Block and Evocation in the cooldown row. Only spells you
know are shown. Fire Blast and Ice Lance share one 8 s cooldown on Forever.

Rotations follow the Warcraft Tavern Forever guides (Nov 2026); spells, cooldowns and durations were checked against
Wowhead's Forever data. Not on Forever, so not tracked: Living Bomb, Icy Veins, Arcane Barrage, Brain Freeze, Molten Armor, Water Elemental and the SoD runes.

## Quick start

1. `/mage` opens the settings window. The overview has the spec switch, the state of your buffs and stacks,
   and one switch per module.
2. Nothing to arrange: the HUD lays itself out for your spec. `/mage edit` only if you want something elsewhere.
3. Fight something. The HUD shows in combat and while an enemy is targeted. Out of combat it is hidden;
   only alerts stay on screen.

## Commands

| Command | |
|---|---|
| `/mage` (or `/amh`) | Settings window |
| `/mage arcane` / `fire` / `frost` / `auto` | Switch spec |
| `/mage edit` | Optional edit mode: drag frames (saved per spec, snaps to the grid, Shift = free), arrow keys nudge, right-click = back to the auto layout |
| `/mage test` | Preview the alerts for 8 seconds |
| `/mage probe` | Shows what Forever lets the addon read right now. Run it once out of combat and once **in combat** |
| `/mage spells` | Copyable list of your spellbook with spell IDs |
| `/mage reset confirm` | Reset all settings and positions |

The addon also has an entry in the minimap's addon compartment.

## Layout: arranges itself per spec

You do not have to arrange anything. The HUD column under your character lays itself out for the active spec
and closes up: rows a spec does not use, modules you switched off and spells you do not know take no space.

```
          [Pyroblast!]                Proc card: while the client lights up a spell
        [Cb][WF][MB]                  Procs: only what is up right now (centred)
     Heating Up         Pyroblast!
[Ab] [=======|=======|=======] 16.2   Stack bar + time left; absorb icon on the left
     [==============          ]       Mana
     [Fireball======          2.1]    Cast bar (only while you cast)
     [F][============   24.3]         Your debuffs on the target: Fire 4 (5 with Frostfire), Frost 2, Arcane none
     [F][=====           4.4]
     ...
     [FB][CB][BW][FN][BL][CS][EV]     Cooldowns: spec first, then the shared ones
```

The stack bar (Arcane Blast, Heating Up, Winter's Chill) sits in the middle of your view because it drives every
spec's next cast. Alerts stack at the top of the screen.

If you do drag a frame in edit mode, that spot is saved **for that spec only**; right-click it in edit mode to
hand it back to the automatic layout. Appearance > **Auto layout** drops all moved frames.

## Modules

| Module | What it shows | Settings |
|---|---|---|
| **Cast Bar** | Your casts and channels right under the mana bar, in a calm neutral colour: spell name, time left; channels drain; red for a moment when interrupted. Only while you cast, also out of combat (Teleport, conjures). Switches Blizzard's own cast bar off so there is only one (back on: /reload) | width, height, time left, hide Blizzard's cast bar |
| **Mana Bar** | Thin mana bar, red when low, hidden at full mana out of combat | width, height, red below %, percentage text, hide at full |
| **Procs** | One centred row that shows only active procs and burst buffs of your spec, with a time-left swipe and stacks. A big card ("Pyroblast!", "Ice Lance!") while the client lights up one of your spells, with an optional sound | icon size, card on/off, sound |
| **Stack Bar** | Segmented bar for your spec's stacks, gold at full with a glow, a sound and a hint | width, height, glow, sound, hide at zero |
| **Target Debuffs** | Fire: Fire Vulnerability, Fireball, Ignite, Pyroblast, Frostfire Bolt (only in the Frostfire build, i.e. with Ice Lance). Frost: Frost Nova, Frostbite. One bar per debuff of yours on the target, with the real time left and stacks | width, height |
| **Cooldowns** | Your spec's cooldowns plus the shared ones; the GCD is ignored. An icon glows while the client lights it up and flashes once when the cooldown your cast started is over | icon size, ready flash |
| **Reminders** | Alerts: Arcane Intellect missing, no armor spell, Ice Barrier not up (Frost), no mana gem, low on Runes of Teleportation/Portals. Absorb icon for Ice Barrier / Mana Shield with time left; for Frost it turns red and pulses while Ice Barrier is not up (in combat, where buffs are secret) | each reminder on/off, also in combat, rune threshold, absorb icon and size, snooze time |

**Appearance:** accent colour (Mage, *Follow spec*, Arcane, Fire, Frost), font, text size (0.7 - 1.2x), bar texture, sounds,
out-of-combat opacity (0% = hidden), show the HUD when an enemy is targeted, HUD scale, edit mode grid,
reset positions.

## How it copes with Forever's addon limits

Forever runs the modern engine. There is no combat log, and in combat auras and cooldown timings reach addons
as *secret values*: they can be shown but not compared or calculated with. Your own mana is secret too.
Archmage HUD therefore

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
5. `/reload`, then send `World of Warcraft\_forever_\WTF\Account\<account>\SavedVariables\ArchmageHUD.lua`
   (it holds both probes and the spell list), the screenshots and any Lua errors.

### Troubleshooting

- `/mage` does nothing: the addon is not loaded. Check the folder path and the AddOns list at character select.
- Wrong spec: pick it by hand in `/mage` or with `/mage fire` etc.
- An alert or module gets in the way: switch it off in `/mage`, then keep testing the rest.
- A frame is off screen: `/mage` > Appearance > **Auto layout**.

### Open points for the first test

- Whether the native aura container works in the real client (`/mage probe` shows `native` per slot).
- Whether the client lights up spells for Heating Up / Missile Barrage / Fingers of Frost (proc card).
- Cast bar: `/mage probe` after a cast in combat shows how the bar ran: `native` (the client's duration object),
  `readable` (with time text) or `secret` (bar still fills, no time text), and whether Blizzard's cast bar was
  found to switch off.
- Mana: when the value is secret the client colours the bar through a colour curve (works in Farseer); "hide at
  full" needs readable mana, so with secret mana the bar stays visible.
- The debuff lists (Fire Vulnerability is personal on Forever and filtered as yours; Frostbite/Frost Nova count as yours).
- Whether the client reports passive talents as known (`/mage probe` line "talents known"): the Ignite, Fire Vulnerability
  and Frostbite rows appear only with the talent.

## Project layout

```
ArchmageHUD.toc     load order, interface 16001
Core.lua            namespace, events, settings, spec switch, modules, slash commands, secret-value helpers
Spells.lua          spell table, what each spec watches, spellbook lookup, spec detection
UI/                 Theme (look, rounded textures), Movers (edit mode), Layout (automatic spec layout), Alerts,
                    Native (aura container),
                    Widgets and Options (settings window)
Modules/            Mana, Castbar, Procs, Stacks, Debuffs, Cooldowns, Reminders
Probe.lua           /mage probe and /mage spells
Media/              rounded-corner textures (TGA)
tests/run.lua       offline test client
tests/render/       renders the addon's frames to PNG and checks that no text or frame overlaps
```

## Development

`lua5.1 tests/run.lua` loads the addon into a fake client, including secret values in combat and the native
aura container. It drives login, every settings page, the spec switch, edit mode, the reminders, the stack bar,
the mana bar, a combat sequence with the proc card, and the fade. Any Lua error fails the run.

`node tests/render/shot.js` renders what the addon really builds (HUD per spec in combat, alerts, edit mode,
every settings page) from the offline client into `tests/render/out/*.png` (needs Playwright with Chromium and
network for the spell icons). It then checks every text (wider than its field, cut off, sticking out of its frame,
on top of another text) and that no HUD frame covers another, and prints `text check: all good`. Look at the
images after every change.

## Blizzard's own displays

Forever has a Cooldown Manager (Options > Gameplay Enhancements). It is off unless you turned it on, and it is not
needed alongside this HUD.

## Releases

When Blizzard patches Forever, bump `## Interface` in the TOC to the new number and release, so the addon never
shows as out of date.

Write the notes in `CHANGELOG.md` and bump `## Version` in the TOC, then on GitHub go to *Releases* >
*Draft a new release*, create the tag `vX.Y.Z` on `main` and publish. The GitHub Action runs the offline test and
attaches the addon zip and `release.json` (flavor `forever`, used by WowUp) to that release
(`.pkgmeta` leaves out `tests` and `.github`).

## License

MIT, see [LICENSE](LICENSE).

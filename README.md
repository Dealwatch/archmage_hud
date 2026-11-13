# Archmage HUD

Arcane, Fire & Frost HUD for **WoW Forever** (interface 16001, build 1.60.1).

One clean HUD for Arcane, Fire and Frost, built to answer two questions at a glance: what can I cast, and what
should I cast. It shows procs, your spec's stacks with marks that light up when a spell is due, your cast,
cooldowns, mana and your debuffs on the target, plus reminders for Intellect, armor, mana gem and runes. You can
switch the spec, and every element can be moved, resized or switched off. The addon is in English; spell names
come from your client, in its language.

Same look and handling as *Shammy Forever* (settings window, edit mode, alerts).

> Status: **0.2.1, in-game testing has started.** It is built against Blizzard's Forever UI code and an offline
> test client. Confirmed in the real game so far: the addon loads and the client's aura slot for the stack bar is
> created. Everything else is still open (see *Open points*).

## Install

**WowUp:** *My Addons* > *Install from URL* > paste the GitHub address of this repository. Updates then show up
in WowUp by themselves (every published release).

**Manual:**

1. Download `ArchmageHUD-<version>-forever.zip` (from a release, or the zip you were sent).
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns\` so that you get
   `...\AddOns\ArchmageHUD\ArchmageHUD.toc` (not `ArchmageHUD\ArchmageHUD\...`).
3. Restart the game completely. A `/reload` is not enough for a new addon.
4. Character select > **AddOns**: make sure *Archmage HUD* is ticked.

## Specs

The spec is detected from your talents (**Auto**) or set by hand: `/mage arcane`, `/mage fire`, `/mage frost`,
`/mage auto`, or in the overview of `/mage`. The procs, stack bar, debuffs, cooldowns and accent colour all follow it.

| Spec | How it is played on Forever | What the HUD shows |
|---|---|---|
| **Arcane** | Build Arcane Blast stacks (4, 18 s window). Clearcasting goes on Arcane Blast, Missile Barrage on Arcane Missiles, Arcane Wrath at 3-4 stacks (twice per window). Level 60 builds dip into Fire: Fire Blast on cooldown builds Heating Up, then Pyroblast at 3 Heating Up while 3-4 Arcane Blast stacks are up. Arcane Power / Presence of Mind at 4 stacks. | Stack bar: **Arcane Blast** (4, "Arcane Wrath!") with the time left of the window, and small pips for **Heating Up** (3). Procs: Missile Barrage, Clearcasting, Arcane Power, Presence of Mind. Cooldowns: Arcane Wrath, Fire Blast, Arcane Power, Presence of Mind |
| **Fire** | Scorch to 5 Improved Scorch stacks, Fire Blast on cooldown, crits build **Heating Up** (3 stacks, each -25% cast time on Pyroblast, a 6 s cast on Forever), then Pyroblast. Fireball filler. Fire Power rewards Fireball DoT, Improved Scorch, Ignite and Pyroblast DoT on the target. Combustion for burst. Frostfire variant: Frostfire Bolt filler, Ice Lance on Fingers of Frost. | Stack bar: **Heating Up** (3, "Pyroblast!"). Debuffs: Fire Vulnerability (stacks), Fireball, Ignite, Pyroblast, Frostfire Bolt. Procs: Combustion, Wake of Fire, Clearcasting, Missile Barrage, Fingers of Frost. Cooldowns: Fire Blast, Ice Lance, Combustion, Blast Wave |
| **Frost** | Frostbolt filler. Ice Lance (x4 damage) on Fingers of Frost, Frostbite or after Frost Nova. Arcane Missiles on Missile Barrage. Winter's Chill build: Cone of Cold at 5 stacks. Keep Arcane Intellect and Ice Barrier up at all times. | Stack bar: **Winter's Chill** on the target (5, "Cone of Cold!"). Debuffs: Frost Nova and Frostbite (target frozen = Ice Lance window). Procs: Fingers of Frost (charges), Clearcasting, Missile Barrage, Presence of Mind. Cooldowns: Ice Lance, Ice Barrier, Cone of Cold, Cold Snap. Alert when Ice Barrier is not up |

Every spec also gets Frost Nova, Blink, Counterspell and Ice Block as small icons beside the spec's cooldowns;
Evocation and the mana gem sit at the end of the mana bar. Only spells you know are shown. Fire Blast and Ice Lance
share one 8 s cooldown on Forever.

Rotations follow the Warcraft Tavern Forever guides (Nov 2026), the openers also mmonster's rotation trainer;
spells, cooldowns and durations were checked against Wowhead's Forever data. Not on Forever, so not tracked:
Living Bomb, Icy Veins, Arcane Barrage, Brain Freeze, Molten Armor, Water Elemental and the SoD runes.

## Quick start

1. `/mage` opens the settings window. The overview has the spec switch, the presets, the state of your buffs
   and stacks, and one switch per module.
2. Nothing to arrange: the HUD lays itself out for your spec. `/mage edit` only if you want something elsewhere,
   `/mage legend` tells you what each element is for. Too much on screen? Pick the *Minimal* or *Standard* preset
   in the overview.
3. Fight something. The HUD shows in combat and while an enemy is targeted. Out of combat it is hidden;
   only alerts (and the cast bar while you cast) stay on screen.

## Commands

| Command | |
|---|---|
| `/mage` (or `/amh`) | Settings window |
| `/mage arcane` / `fire` / `frost` / `auto` | Switch spec |
| `/mage edit` | Optional edit mode: drag frames (saved per spec, snaps to the grid, Shift = free), arrow keys nudge, right-click = back to the auto layout |
| `/mage legend` | What each HUD element is for: one sentence beside it, for 10 seconds |
| `/mage test` | Preview the alerts for 8 seconds |
| `/mage probe` | Shows what Forever lets the addon read right now. Run it once out of combat and once **in combat** |
| `/mage spells` | Copyable list of your spellbook with spell IDs |
| `/mage reset confirm` | Reset all settings and positions |
| `/mage help` | List of the commands |

The addon also has an entry in the minimap's addon compartment.

## Layout: arranges itself per spec

You do not have to arrange anything. The HUD column under your character lays itself out for the active spec
and closes up: rows a spec does not use, modules you switched off and spells you do not know take no space.

```
          [Pyroblast!]                Proc card: cast this now (before the pull: your opener)
        [Cb][WF][MB]                  Procs: only what is up right now (centred)
     Heating Up         Pyroblast!
[Ab] [=======|=======|=======] 16.2   Stack bar + time left; absorb icon on the left
                         [Py]         Rotation marks: an icon lights up gold when its stacks are reached
     [==============          ][G][E] Mana, with mana gem and Evocation at its end
     [Fireball======          2.1]    Cast bar (only while you cast)
     [FB][CB][BW]  [fn][bl][cs]       Cooldowns: your spec's large, the shared ones small
     [F][============   24.3]         Your debuffs on the target: Fire 4 (5 with Frostfire), Frost 2, Arcane none
     [F][=====           4.4]
     ...
     [P][============   31.0]         Polymorph on your focus (only while you have one)
```

What you act on is on top (proc card, stacks and their marks, mana, cast bar, cooldowns), what you watch is below
(debuffs, Polymorph). **Gold always means "cast this"**: the proc card, a lit rotation mark, a glowing cooldown,
the next icon of the opener.

The rotation marks are lit by the client itself, so they also work in combat, where the stacks are hidden from
addons and the gold bar and its hint cannot show. Arcane has the Heating Up pips in the same row, with their own
mark: Pyroblast at 3 Heating Up.

**Presets** (overview): *Minimal* is the stack bar, procs and cast bar. *Standard* adds mana, debuffs, cooldowns and
reminders. *Full* (the default) adds the rotation marks, the opener and the Polymorph timer.

The stack bar (Arcane Blast, Heating Up, Winter's Chill) sits in the middle of your view because it drives every
spec's next cast. Alerts stack at the top of the screen.

If you do drag a frame in edit mode, that spot is saved **for that spec only**; right-click it in edit mode to
hand it back to the automatic layout. Appearance > **Auto layout** drops all moved frames.

## Modules

| Module | What it shows | Settings |
|---|---|---|
| **Cast Bar** | Your casts and channels right under the mana bar, in a calm neutral colour: spell name, time left; channels drain; red for a moment when interrupted. Only while you cast, also out of combat (Teleport, conjures). Switches Blizzard's own cast bar off so there is only one (back on: /reload) | width, height, time left, hide Blizzard's cast bar |
| **Mana Bar** | Thin mana bar, red when low, hidden at full mana out of combat. Mana gem (grey: none in the bags) and Evocation as two small icons at its end, with their cooldowns | width, height, red below %, percentage text, hide at full, gem and Evocation icons |
| **Procs** | One centred row that shows only active procs and burst buffs of your spec, with a time-left swipe and stacks. A big card ("Pyroblast!", "Ice Lance!") while the client lights up one of your spells, with an optional sound | icon size, card on/off, sound |
| **Stack Bar** | Segmented bar for your spec's stacks. Gold at full with a glow, a sound and a hint whenever the addon can read the stacks (in combat it often cannot: then the marks tell you). Rotation marks under the segments, grey until the client lights them up gold at their stacks: Arcane has Arcane Wrath at 3 and Arcane Power at 4, plus Pyroblast at 3 Heating Up (its pips sit in the same row); Fire has Pyroblast at 3; Frost has Cone of Cold at 5 | width, height, glow, sound, hide at zero, rotation marks |
| **Target Debuffs** | Fire: Fire Vulnerability, Fireball, Ignite, Pyroblast, Frostfire Bolt (only in the Frostfire build, i.e. with Ice Lance). Frost: Frost Nova, Frostbite. One bar per debuff of yours on the target, with the real time left and stacks. Polymorph on your focus: one more bar under the debuffs | width, height, Polymorph on the focus |
| **Cooldowns** | Your spec's cooldowns large, the shared ones small and dimmed beside them; the GCD is ignored. An icon glows while the client lights it up and flashes once when the cooldown your cast started is over | icon size, ready flash |
| **Opener** | The first casts of a fight for your spec, in the place of the proc card before the pull: each icon dims when you have cast it, the next one glows gold, and it is gone when the opener is through (or 20 s into the fight). It steps aside while the proc card shows. Arcane: Arcane Blast, Fire Blast, Arcane Blast, Arcane Wrath. Fire: Pyroblast, Fireball, Scorch, Fire Blast. Frost: Frostbolt, Frost Nova, Ice Lance, Frostbolt | on/off |
| **Reminders** | Alerts: Arcane Intellect missing, no armor spell, Ice Barrier not up (Frost), no mana gem, low on Runes of Teleportation/Portals. At a ready check one more card: "All set", or the consumables that are missing (weapon oil, mana potions, conjured water). Absorb icon for Ice Barrier / Mana Shield with time left; for Frost it turns red and pulses while Ice Barrier is not up (in combat, where buffs are secret) | each reminder on/off, also in combat, rune threshold, ready check, absorb icon and size, snooze time |

**Appearance:** accent colour (Mage, *Follow spec*, Arcane, Fire, Frost), font, text size (0.8 - 1.2x), bar
texture, sounds, out-of-combat opacity (0% = hidden), show the HUD when an enemy is targeted, HUD scale, edit mode
grid, legend, reset positions.

**Fonts:** the default is your client's own standard font (Friz Quadrata on English and German clients, the
matching font on Russian, Korean and Chinese ones, so localized spell names always have their glyphs). Arial
Narrow, Skurri and Morpheus can be picked instead. Text on the HUD has an outline and is 11 px or larger at text
size 1.0x (the mana percentage: 10 px). Text size goes from 0.8x (smaller is not readable) up to 1.2x (the cards
and the settings window have fixed sizes); for a bigger HUD use the HUD scale.

## How it copes with Forever's addon limits

Forever runs the modern engine. There is no combat log, and in combat auras and cooldown timings reach addons
as *secret values*: they can be shown but not compared or calculated with. Your own mana is secret too.
Archmage HUD therefore

- lets the client draw: Blizzard's native aura container (`Blizzard_AuraContainer`) fills the stack bar, lights
  up the rotation marks, and fills the proc row, the debuff bars and the absorb icon, even while the values are
  secret;
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
   `/mage edit` (screenshot), `/mage legend` (screenshot), `/mage test`.
3. Target an enemy before the pull: is the opener there, and does each icon dim when you cast it?
4. Fight a few mobs for 2-3 minutes in your spec: proc row, stack bar (does it fill?), **rotation marks (does the
   icon turn gold exactly at its stack count: Pyroblast at 3 Heating Up, Arcane Wrath at 3 Arcane Blast, Cone of
   Cold at 5 Winter's Chill?)**, proc card, cast bar, cooldown swirls and their numbers (readable on the small
   icons?), debuff bars (Fire), absorb icon after Ice Barrier / Mana Shield.
5. Use a mana gem (does its icon at the mana bar start a cooldown?), set a focus and Polymorph it, and have
   someone start a ready check.
6. **In combat**, with a few stacks up: `/mage probe`. Screenshot the HUD.
7. `/reload`, then send `World of Warcraft\_forever_\WTF\Account\<account>\SavedVariables\ArchmageHUD.lua`
   (it holds both probes and the spell list), the screenshots and any Lua errors.

### Troubleshooting

- `/mage` does nothing: the addon is not loaded. Check the folder path and the AddOns list at character select.
- Wrong spec: pick it by hand in `/mage` or with `/mage fire` etc.
- An alert or module gets in the way: switch it off in `/mage`, then keep testing the rest.
- A frame is off screen: `/mage` > Appearance > **Auto layout**.

### Open points for the first test

- Whether every native aura slot builds in the real client: `/mage probe` must show `native` for each slot, with
  no text after it. The first test (0.2.0) raised a Lua error because the stack bar was recoloured after it was
  handed to the client (such a widget is forbidden to addons from then on); fixed in 0.2.1, where the addon never
  touches a handed-over widget again.
- A changed accent colour or text size may reach the bars and texts the client draws only after a /reload.
- Whether the client lights up spells for Heating Up / Missile Barrage / Fingers of Frost (proc card).
- Cast bar: `/mage probe` after a cast in combat shows how the bar ran: `native` (the client's duration object),
  `readable` (with time text) or `secret` (bar still fills, no time text), and whether Blizzard's cast bar was
  found to switch off.
- Mana: when the value is secret the client colours the bar through a colour curve (works in Farseer); "hide at
  full" needs readable mana, so with secret mana the bar stays visible.
- The debuff lists (Fire Vulnerability is personal on Forever and filtered as yours; Frostbite/Frost Nova count as yours).
- New in 0.2.0, all unconfirmed in game:
  - the rotation marks light up through a native aura slot whose stack bar runs from n - 1 to n stacks (if the
    client fills it differently, a mark stays grey or lights up early);
  - the item IDs behind the ready check (mana potions, conjured water) and the mana gem's cooldown (started by
    your own "Replenish Mana" cast) are the Classic ones;
  - the Polymorph timer needs the `focus` unit and its auras to work like the target's;
  - the ready-check card needs the `READY_CHECK` events;
  - the small cooldown icons ask for a smaller countdown font (`NumberFontNormalSmall`); if the client ignores
    that, the numbers on them are large.
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
Modules/            Mana, Castbar, Procs, Stacks, Debuffs, Cooldowns, Opener, Reminders
Probe.lua           /mage probe and /mage spells
Media/              rounded-corner textures (TGA)
tests/run.lua       offline test client
tests/render/       renders the addon's frames to PNG and checks that no text or frame overlaps
```

## Development

`lua5.1 tests/run.lua` loads the addon into a fake client, including secret values in combat and the native
aura container. It drives login, every settings page, the spec switch, edit mode, the legend, the presets, the
opener, the reminders and the ready check, the stack bar with its marks, the mana bar, a combat sequence with the
proc card, and the fade. Any Lua error fails the run.

`node tests/render/shot.js` renders what the addon really builds (HUD per spec in combat, also with the stacks
secret, the opener before the pull, alerts, the ready check, edit mode, the legend, every settings page, also
scrolled to its end) from the offline client into `tests/render/out/*.png` (needs Playwright with Chromium and
network for the spell icons). It then checks every text (wider than its field, cut off, sticking out of its frame,
on top of another text) and that no HUD frame covers another, and prints `text check: all good`. Look at the
images after every change. The page font is DejaVu Serif, about 6% wider than Friz Quadrata, so what fits there
fits in game; the client's cooldown numbers are not rendered.

## Blizzard's own displays

Forever has a Cooldown Manager (Options > Gameplay Enhancements). It is off unless you turned it on, and it is not
needed alongside this HUD.

## Releases

When Blizzard patches Forever, bump `## Interface` in the TOC to the new number and release, so the addon never
shows as out of date.

Write the notes in `CHANGELOG.md` (the packager ships it as the release's changelog) and bump `## Version` in
the TOC, then on GitHub go to *Releases* >
*Draft a new release*, create the tag `vX.Y.Z` on `main` and publish. The GitHub Action runs the offline test and
attaches the addon zip and `release.json` (flavor `forever`, used by WowUp) to that release
(`.pkgmeta` leaves out `tests` and `.github`).

## License

MIT, see [LICENSE](LICENSE).

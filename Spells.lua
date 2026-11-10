--[[
    ArchmageHUD - spells
    Forever's spell IDs are not published anywhere we can read, so nothing here
    depends on one exact ID. Every spell has a few candidate IDs (Classic Era
    ranks, later versions) and its English name. At login we read the player's
    spellbook and match by the localized name the client gives for those IDs,
    so any rank, any client language and any Forever-only ID resolves.
    `/mage spells` prints the real IDs if something does not resolve.
]]

local _, NS = ...

local Spells = {}
NS.Spells = Spells

-- key = { en = English name, ids = candidate IDs, [aura = aura IDs if they differ],
--         [dur = default debuff seconds], [from = cast that applies it], [color = bar colour],
--         [needs = spell key that marks the build using this debuff row], [talent = ID of the talent that
--         causes this debuff: talent effects are never castable, so the row shows once you have the talent],
--         [group = "teleport" | "portal"], [tree = spec, tier = talent depth for spec detection] }
-- Forever-only IDs (400xxx, 12xxxxx, 13xxxxx) were checked against Wowhead's
-- Forever data and the wowsims/forever client dump (Nov 2026). Not on Forever
-- and left out on purpose: Living Bomb, Icy Veins, Arcane Barrage, Brain
-- Freeze, Molten Armor, Water Elemental, Dragon's Breath, the SoD runes.
local DEFS = {
    -- Arcane
    arcaneBlast     = { en = "Arcane Blast",      ids = { 400574, 1239696, 1239697, 1239699, 1239700 }, aura = { 400573 },
                        tree = "arcane", tier = 1 },                             -- 4 stacks, 18 s
    arcaneWrath     = { en = "Arcane Wrath",      ids = { 1326079, 1326080, 1326081, 1326082 }, tree = "arcane", tier = 2 },
    missileBarrage  = { en = "Missile Barrage",   ids = { 400588 }, aura = { 400589 } },
    arcaneMissiles  = { en = "Arcane Missiles",   ids = { 5143, 5144, 5145, 8416, 8417, 10211, 10212, 25345 } },
    arcaneExplosion = { en = "Arcane Explosion",  ids = { 1449, 8437, 8438, 8439, 10201, 10202 } },
    clearcasting    = { en = "Clearcasting",      ids = { 12536 } },                 -- Arcane Concentration proc
    presenceOfMind  = { en = "Presence of Mind",  ids = { 12043 }, tree = "arcane", tier = 3 },
    arcanePower     = { en = "Arcane Power",      ids = { 12042 }, tree = "arcane", tier = 4 },
    evocation       = { en = "Evocation",         ids = { 12051 } },
    blink           = { en = "Blink",             ids = { 1953 } },
    counterspell    = { en = "Counterspell",      ids = { 2139 } },

    -- Fire
    fireball        = { en = "Fireball",          ids = { 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306 },
                        dur = 8, color = { 1, 0.62, 0.20 } },                     -- DoT counts for Fire Power
    frostfireBolt   = { en = "Frostfire Bolt",    ids = { 401502, 1237312, 1237313 }, dur = 9, color = { 0.75, 0.45, 1 },
                        needs = "iceLance" },   -- has a DoT; trained by every mage at 40, a row only for the Frostfire build
    fireBlast       = { en = "Fire Blast",        ids = { 2136, 2137, 2138, 8412, 8413, 10197, 10199 } },   -- shares its 8 s cooldown with Ice Lance
    scorch          = { en = "Scorch",            ids = { 2948, 8444, 8445, 8446, 10205, 10206, 10207 } },
    flamestrike     = { en = "Flamestrike",       ids = { 2120, 2121, 8422, 8423, 10215, 10216 } },
    pyroblast       = { en = "Pyroblast",         ids = { 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809 }, tree = "fire", tier = 2,
                        dur = 12, color = { 1, 0.55, 0.15 } },
    heatingUp       = { en = "Heating Up",        ids = { 400624 }, aura = { 400625 } },   -- 3 stacks: fast Pyroblast
    blastWave       = { en = "Blast Wave",        ids = { 11113, 13018, 13019, 13020, 13021 }, tree = "fire", tier = 3 },
    combustion      = { en = "Combustion",        ids = { 11129 }, aura = { 11129, 28682 }, tree = "fire", tier = 4 },
    wakeOfFire      = { en = "Wake of Fire",      ids = { 1312934 } },               -- after a kill: next Fire Blast +50% crit
    ignite          = { en = "Ignite",            ids = { 412538 }, talent = 11119, dur = 4, color = { 1, 0.30, 0.10 } },
    fireVuln        = { en = "Fire Vulnerability", ids = { 22959 }, talent = 11095, from = "scorch", dur = 30, color = { 1, 0.70, 0.25 } },   -- Improved Scorch, personal on Forever

    -- Frost
    frostbolt       = { en = "Frostbolt",         ids = { 116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304 } },
    iceLance        = { en = "Ice Lance",         ids = { 1312002, 400640, 1240044, 1240045, 1240046, 1240047 }, tree = "frost", tier = 1 },
    fingersOfFrost  = { en = "Fingers of Frost",  ids = { 400647 }, aura = { 400669, 400670 } },   -- 1-2 charges
    frostNova       = { en = "Frost Nova",        ids = { 122, 865, 6131, 10230 }, dur = 8, color = { 0.55, 0.86, 1 } },   -- target frozen: Ice Lance x4
    frostbite       = { en = "Frostbite",         ids = { 12494 }, talent = 11071, dur = 5, color = { 0.40, 0.70, 1 } },
    coneOfCold      = { en = "Cone of Cold",      ids = { 120, 8492, 10159, 10160, 10161 } },
    blizzard        = { en = "Blizzard",          ids = { 10, 6141, 8427, 10185, 10186, 10187 } },
    coldSnap        = { en = "Cold Snap",         ids = { 12472 }, tree = "frost", tier = 2 },
    iceBlock        = { en = "Ice Block",         ids = { 11958 } },
    iceBarrier      = { en = "Ice Barrier",       ids = { 11426, 13031, 13032, 13033 }, tree = "frost", tier = 4 },
    wintersChill    = { en = "Winter's Chill",    ids = { 12579 } },                 -- stacks boost your next Cone of Cold

    -- Self buffs
    arcaneIntellect = { en = "Arcane Intellect",  ids = { 1459, 1460, 1461, 10156, 10157 } },
    arcaneBrilliance = { en = "Arcane Brilliance", ids = { 23028 } },
    frostArmor      = { en = "Frost Armor",       ids = { 168, 7300, 7301 } },
    iceArmor        = { en = "Ice Armor",         ids = { 7302, 7320, 10219, 10220 } },
    mageArmor       = { en = "Mage Armor",        ids = { 6117, 22782, 22783 } },
    manaShield      = { en = "Mana Shield",       ids = { 1463, 8494, 8495, 10191, 10192, 10193 } },
    conjureGem      = { en = "Conjure Mana Agate", ids = { 759, 3552, 10053, 10054 } },  -- every rank has its own name
    gemUse          = { en = "Replenish Mana",    ids = { 5405, 10052, 10057, 10058 } },   -- using a mana gem: your own cast starts its 2 min cooldown
    polymorph       = { en = "Polymorph",         ids = { 118, 12824, 12825, 12826, 28270, 28271, 28272 }, dur = 50, color = { 0.80, 0.55, 1 } },

    -- Travel (only used to know whether the rune reminder applies)
    teleStormwind   = { en = "Teleport: Stormwind",     ids = { 3561 },  group = "teleport" },
    teleIronforge   = { en = "Teleport: Ironforge",     ids = { 3562 },  group = "teleport" },
    teleDarnassus   = { en = "Teleport: Darnassus",     ids = { 3565 },  group = "teleport" },
    teleDalaran     = { en = "Teleport: Dalaran",       ids = { 1297659 }, group = "teleport" },
    teleOrgrimmar   = { en = "Teleport: Orgrimmar",     ids = { 3567 },  group = "teleport" },
    teleUndercity   = { en = "Teleport: Undercity",     ids = { 3563 },  group = "teleport" },
    teleThunderBluff = { en = "Teleport: Thunder Bluff", ids = { 3566 }, group = "teleport" },
    portalStormwind = { en = "Portal: Stormwind",       ids = { 10059 }, group = "portal" },
    portalIronforge = { en = "Portal: Ironforge",       ids = { 11416 }, group = "portal" },
    portalDarnassus = { en = "Portal: Darnassus",       ids = { 11419 }, group = "portal" },
    portalOrgrimmar = { en = "Portal: Orgrimmar",       ids = { 11417 }, group = "portal" },
    portalUndercity = { en = "Portal: Undercity",       ids = { 11418 }, group = "portal" },
    portalThunderBluff = { en = "Portal: Thunder Bluff", ids = { 11420 }, group = "portal" },
}
Spells.DEFS = DEFS

-- What each spec watches (how the spec is played on Forever):
--   Arcane  build Arcane Blast stacks (4, 18 s window), Clearcasting on Arcane Blast, Arcane
--           Missiles on Missile Barrage, Arcane Wrath at 3-4 stacks (twice per window). Level 60
--           builds dip into Fire: Fire Blast on cooldown -> Heating Up -> Pyroblast at 4 stacks.
--           Arcane Power / Presence of Mind at 4 stacks. (Warcraft Tavern Forever guides, Nov 2026)
--   Fire    Fire Blast on cooldown and crits build Heating Up (3 stacks, -25% Pyroblast cast each;
--           Pyroblast is a 6 s cast on Forever) -> Pyroblast; keep your
--           Fire Vulnerability (Improved Scorch) at 5 stacks; Fire Power rewards Fireball DoT,
--           Improved Scorch, Ignite and Pyroblast DoT on the target; Combustion for burst.
--           Frostfire variant: Frostfire Bolt filler, Ice Lance on Fingers of Frost.
--   Frost   Frostbolt filler; Ice Lance (x4) on frozen targets (Frost Nova, Frostbite) or with
--           Fingers of Frost charges; Frostbolt
--           builds Winter's Chill (5 stacks) for Cone of Cold (Winter's Chill build);
--           Arcane Missiles on Missile Barrage; keep Arcane Intellect and Ice Barrier up at all times.
-- Lists only name spells; ones you do not know are skipped.
--   procs     buffs on you for the proc row (only shown while up)
--   stacks    one stacking aura for the segmented bar: { key, unit, filter, max, full = hint text }
--   debuffs   your debuffs on the target, one bar each
--   cooldowns spec cooldowns, in front of the shared ones
--   card      spell shown on the proc card in edit mode
--   stacks.marks  rotation marks under the stack bar: { stacks at which to cast, spell keys (the first one
--                 you know) }; the client lights the icon up at that many stacks. stacks.tip: /mage legend
--   second    a second stacking aura, as small pips in the row of the marks, with its own mark
--             (Arcane hybrid: Pyroblast at 3 Heating Up)
--   opener    the first casts of a fight, in order (Warcraft Tavern / mmonster Forever guides, Nov 2026)
Spells.SPEC_DATA = {
    arcane = {
        procs = { "missileBarrage", "clearcasting", "arcanePower", "presenceOfMind" },
        stacks = { key = "arcaneBlast", unit = "player", filter = "HELPFUL", max = 4, full = "Spend: Arcane Wrath",
                   marks = { { 3, "arcaneWrath" }, { 4, "arcanePower", "presenceOfMind" } },   -- Fire Blast: on cooldown, see the cooldown row
                   tip = "A lit icon below: cast it. The small pips are Heating Up" },
        second = { key = "heatingUp", unit = "player", filter = "HELPFUL", max = 3, mark = "pyroblast" },
        opener = { "arcaneBlast", "fireBlast", "arcaneBlast", "arcaneWrath" },
        debuffs = {},
        cooldowns = { "arcaneWrath", "fireBlast", "arcanePower", "presenceOfMind" },
        card = "arcaneMissiles",
    },
    fire = {
        procs = { "combustion", "wakeOfFire", "clearcasting", "missileBarrage", "fingersOfFrost" },
        stacks = { key = "heatingUp", unit = "player", filter = "HELPFUL", max = 3, full = "Pyroblast!",
                   marks = { { 3, "pyroblast" } }, tip = "Heating Up: the Pyroblast icon lights up at 3" },
        opener = { "pyroblast", "fireball", "scorch", "fireBlast" },
        debuffs = { "fireVuln", "fireball", "ignite", "pyroblast", "frostfireBolt" },
        cooldowns = { "fireBlast", "iceLance", "combustion", "blastWave" },
        card = "pyroblast",
    },
    frost = {
        procs = { "fingersOfFrost", "clearcasting", "missileBarrage", "presenceOfMind" },
        stacks = { key = "wintersChill", unit = "target", filter = "HARMFUL|PLAYER", max = 5, full = "Cone of Cold!",
                   marks = { { 5, "coneOfCold" } }, tip = "Winter's Chill: the Cone of Cold icon lights up at 5" },
        opener = { "frostbolt", "frostNova", "iceLance", "frostbolt" },
        debuffs = { "frostNova", "frostbite" },
        cooldowns = { "iceLance", "iceBarrier", "coneOfCold", "coldSnap" },
        card = "iceLance",
    },
}
Spells.SHARED_COOLDOWNS = { "frostNova", "blink", "counterspell", "iceBlock", "evocation" }

Spells.MANA_GEMS = { 5514, 5513, 8007, 8008 }      -- Agate, Jade, Citrine, Ruby
Spells.MANA_POTIONS = { 2455, 3385, 3827, 6149, 13443, 13444 }          -- Minor ... Major
Spells.WATER = { 5350, 2288, 2136, 3772, 8077, 8078, 8079 }             -- conjured water, every rank
Spells.RUNE_TELEPORT = 17031
Spells.RUNE_PORTALS = 17032

local byName = {}       -- localized or English name -> key
local book = {}         -- spellbook: name -> spellID

local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and n and not NS.IsSecret(n) then return n end
    end
    if GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, id)
        if ok and n then return n end
    end
end
Spells.NameOf = spellName

function Spells.TextureOf(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, id)
        if ok and t then return t end
    end
end

local function scanBook()
    wipe(book)
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return end
    local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info then
            local first = (info.itemIndexOffset or 0) + 1
            local last = (info.itemIndexOffset or 0) + (info.numSpellBookItems or 0)
            for i = first, last do
                local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
                if item and item.name and item.spellID then
                    book[item.name] = item.spellID
                end
            end
        end
    end
end

local function isKnown(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and known then return true end
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, id)
        if ok and known then return true end
    end
    return false
end

-- Fills each def with: name (localized when possible), id (the player's
-- castable ID, or the first candidate the client knows), known, icon.
function Spells:Resolve()
    wipe(byName)
    scanBook()
    for key, def in pairs(DEFS) do
        def.key = key
        def.known, def.id, def.name = false, nil, nil
        local names = {}
        for _, id in ipairs(def.ids) do
            local n = spellName(id)
            if n then names[#names + 1] = n end
            if not def.known and isKnown(id) then def.known, def.id = true, id end
        end
        names[#names + 1] = def.en
        for _, n in ipairs(names) do
            byName[n] = key
            if not def.known and book[n] then
                def.known, def.id, def.name = true, book[n], n
            end
        end
        def.name = def.name or (def.id and spellName(def.id)) or names[1]
        def.id = def.id or def.ids[1]
        def.icon = Spells.TextureOf(def.id)
    end
end

function Spells:Get(key) return DEFS[key] end

-- How many of these items are in the bags.
function Spells.ItemCount(ids)
    local n = 0
    for _, id in ipairs(ids) do n = n + (NS.Readable(NS.Try(C_Item and C_Item.GetItemCount, id)) or 0) end   -- a hidden count is no count
    return n
end

-- Every ID an aura of this spell may carry (all ranks, buff IDs, the
-- resolved one), as an array for the native aura filters.
function Spells:AuraIDs(...)
    local out, seen = {}, {}
    local function add(id) if id and not seen[id] then seen[id] = true; out[#out + 1] = id end end
    for i = 1, select("#", ...) do
        local def = DEFS[select(i, ...)]
        if def then
            for _, id in ipairs(def.aura or def.ids) do add(id) end
            if not def.aura then add(def.id) end
        end
    end
    return out
end
function Spells:Known(key) return DEFS[key] and DEFS[key].known or false end

-- Key for a spell ID or name we saw (own casts, readable auras), or nil.
function Spells:KeyFor(spellIDorName)
    if spellIDorName == nil or NS.IsSecret(spellIDorName) then return nil end
    local name = spellIDorName
    if type(spellIDorName) == "number" then name = spellName(spellIDorName) end
    return name and byName[name]
end

function Spells:BookSnapshot()
    scanBook()
    return book
end

function Spells:KnownAny(group)
    for _, def in pairs(DEFS) do
        if def.group == group and def.known then return def end
    end
end

-- Spec cooldowns first, then the shared ones, without duplicates.
function Spells:CooldownsFor(spec)
    local out, seen = {}, {}
    local d = self.SPEC_DATA[spec] or {}
    for _, list in ipairs({ d.cooldowns or {}, self.SHARED_COOLDOWNS }) do
        for _, key in ipairs(list) do
            if not seen[key] then seen[key] = true; out[#out + 1] = key end
        end
    end
    return out
end

-- A debuff row shows when you can cast the spell, or you have the talent that causes it
-- (Ignite 11119, Improved Scorch 11095, Frostbite 11071 - single-rank talents on Forever).
function Spells:DebuffShown(key)
    local d = DEFS[key]
    if not d then return false end
    if NS.editing then return true end
    if d.needs and not (DEFS[d.needs] and DEFS[d.needs].known) then return false end
    if d.known then return true end
    if d.talent and isKnown(d.talent) then return true end
    -- the client may not report passive talents as known: a debuff of yours we have seen counts too
    return NS.db and NS.db.learned.seen[key] or false
end

function Spells:DebuffsFor(spec)
    local d = self.SPEC_DATA[spec]
    return d and d.debuffs or {}
end

-- Spec from the talent spells you know: each tree scores the depth of its known
-- talents (31-point talents count most), the highest score wins; a tie goes to the
-- deepest single talent, then Arcane > Fire > Frost. Falls back to the client's
-- spec API, then Frost.
function Spells:DetectSpec()
    local score, deepest = {}, {}
    for _, def in pairs(DEFS) do
        if def.tree and def.known then
            score[def.tree] = (score[def.tree] or 0) + def.tier
            deepest[def.tree] = math.max(deepest[def.tree] or 0, def.tier)
        end
    end
    local best
    for _, sp in ipairs(NS.SPECS) do
        local k = sp.key
        if score[k] and (not best or score[k] > score[best]
            or (score[k] == score[best] and deepest[k] > deepest[best])) then best = k end
    end
    if best then return best end
    local idx = NS.Try(_G.GetSpecialization)
    if type(idx) == "number" and NS.SPECS[idx] then return NS.SPECS[idx].key end
    return "frost"
end

-- Aura IDs the probe checks for secrecy: the stack aura, procs and debuffs of every spec.
function Spells:ProbeAuraIDs()
    local out, seen = {}, {}
    for _, d in pairs(self.SPEC_DATA) do
        local keys = { unpack(d.procs) }
        for _, k in ipairs(d.debuffs) do keys[#keys + 1] = k end
        if d.stacks then keys[#keys + 1] = d.stacks.key end
        for _, k in ipairs(keys) do
            local def = DEFS[k]
            local id = def.aura and def.aura[1] or def.id or def.ids[1]
            if not seen[id] then seen[id] = true; out[#out + 1] = id end
        end
    end
    return out
end

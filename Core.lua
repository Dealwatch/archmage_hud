--[[
    ArchmageHUD - core
    Namespace, event bus, saved settings, module registry, slash commands and
    the secret-value helpers every module uses.

    WoW Forever runs the 12.x engine: in combat (and in encounters / PvP) many
    values reach addons as "secrets". A secret may be handed to a widget
    (FontString:SetText, StatusBar:SetValue, Texture:SetTexture, ...) but
    comparing it or doing arithmetic on it is a hard Lua error. So: logic only
    ever runs on NS.Readable() values, and secrets go straight into widgets.
]]

local ADDON, NS = ...
_G.ArchmageHUD = NS

NS.ADDON = ADDON
NS.TITLE = "Archmage HUD"
NS.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "dev"
NS.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\"

---------------------------------------------------------------------------
-- Secrets
---------------------------------------------------------------------------

local issecretvalue = _G.issecretvalue

local issecrettable = _G.issecrettable

function NS.IsSecret(v)
    if issecretvalue ~= nil and issecretvalue(v) == true then return true end
    return issecrettable ~= nil and type(v) == "table" and issecrettable(v) == true
end

-- The value, or nil when the client hides it from us right now.
function NS.Readable(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- Calls a client API defensively: missing function or a refusal -> nil.
function NS.Try(fn, ...)
    if not fn then return nil end
    local res = { pcall(fn, ...) }
    if not res[1] then return nil end
    return unpack(res, 2)
end

-- For visibility: NS.combat is set first thing at PLAYER_REGEN_DISABLED, before the lockdown starts.
function NS.InCombat()
    return NS.combat or InCombatLockdown()
end

---------------------------------------------------------------------------
-- Printing
---------------------------------------------------------------------------

function NS.Print(...)
    print("|cff69ccf0Archmage|r |cffe8eaedHUD|r:", ...)
end

---------------------------------------------------------------------------
-- Event bus (game events and our own "MF_" messages share it)
---------------------------------------------------------------------------

local bus = CreateFrame("Frame")
local handlers = {}

local function dispatch(list, event, ...)
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then geterrorhandler()(err) end
    end
end

bus:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if list then dispatch(list, event, ...) end
end)

-- Game event or internal message. Unknown game events are ignored so a
-- client that lacks one does not break the addon.
function NS:On(event, fn)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        if not event:find("^MF_") then pcall(bus.RegisterEvent, bus, event) end
    end
    list[#list + 1] = fn
end

-- Unit-filtered events get their own frame so RegisterUnitEvent applies.
function NS:OnUnit(event, unit, fn)
    local f = CreateFrame("Frame")
    if pcall(f.RegisterUnitEvent, f, event, unit) then
        f:SetScript("OnEvent", function(_, ...)
            local ok, err = pcall(fn, ...)
            if not ok then geterrorhandler()(err) end
        end)
    end
end

function NS:Send(msg, ...)
    local list = handlers[msg]
    if list then dispatch(list, msg, ...) end
end

---------------------------------------------------------------------------
-- Work that must wait until combat ends (secure attributes, frame moves)
---------------------------------------------------------------------------

local afterCombat = {}

-- True from PLAYER_REGEN_DISABLED on. InCombatLockdown() is still false while that
-- event's handlers run, so nothing reacting to it may hide frames for real. Registered
-- first, so the flag is set before any other handler and cleared before AfterCombat work.
NS.combat = false
NS:On("PLAYER_REGEN_DISABLED", function() NS.combat = true end)
NS:On("PLAYER_REGEN_ENABLED", function() NS.combat = false end)

function NS.AfterCombat(key, fn)
    if not InCombatLockdown() then
        fn()
    else
        afterCombat[key] = fn
    end
end

NS:On("PLAYER_REGEN_ENABLED", function()
    for key, fn in pairs(afterCombat) do
        afterCombat[key] = nil
        local ok, err = pcall(fn)
        if not ok then geterrorhandler()(err) end
    end
end)

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

-- One clean HUD column (240 wide) under your character, one icon size (30)
-- for the proc row and the spec's cooldowns (the shared cooldowns are smaller). Positions are CENTER offsets on UIParent.
NS.defaults = {
    spec = "auto",              -- "auto" (from talents) | "arcane" | "fire" | "frost"
    modules = {
        mana = true, castbar = true, procs = true, stacks = true, debuffs = true,
        cooldowns = true, opener = true, reminders = true,
    },
    positions = {},
    appearance = {
        accent = "spec",        -- follows the active spec
        scale = 1.0,
        fontScale = 1.0,
        font = "Fonts\\FRIZQT__.TTF",
        texture = "smooth",
        sounds = true,
        grid = 16,
        idleAlpha = 0,          -- HUD opacity out of combat (0 = hidden; alerts stay)
        showOnTarget = true,    -- out of combat, show the HUD while an enemy is targeted (pre-pull)
    },
    mana = {
        width = 240, height = 8,
        showText = false,       -- percentage on the bar
        hideFull = true,        -- hide out of combat at full mana
        lowPct = 25,            -- bar turns red below this
        tools = true,           -- mana gem and Evocation as two small icons at the end of the bar
    },
    castbar = {
        width = 240, height = 14,
        showTime = true,        -- time left on the bar (when the client lets us read it)
        hideBlizzard = true,    -- switch off Blizzard's own player cast bar while ours is on
    },
    procs = {
        size = 30,              -- icon size
        card = true,            -- big card when the client lights up a spell (instant Pyroblast, ...)
        sound = true,
    },
    stacks = {
        width = 240, height = 10,
        glow = true,            -- glow at full stacks
        sound = true,
        hideEmpty = true,       -- hide out of combat at 0 stacks
        marks = true,           -- rotation marks under the segments (what to cast at which stack)
    },
    debuffs = {
        width = 240, height = 16,
        focus = true,           -- Polymorph timer for your focus
    },
    cooldowns = {
        size = 30,
        readyFlash = true,      -- an icon flashes once when the cooldown your cast started is over
    },
    reminders = {
        intellect = true,       -- Arcane Intellect / Brilliance missing
        barrier = true,         -- Frost: Ice Barrier not up (keep it up at all times)
        armor = true,           -- no armor spell up
        gem = true,             -- no mana gem in the bags
        reagents = true,        -- low on teleport / portal runes
        reagentMin = 3,
        ready = true,           -- at a ready check: "all set" or the consumables that are missing
        inCombat = false,       -- buff reminders also in combat
        snooze = 60,
        absorbIcon = true,      -- Ice Barrier / Mana Shield icon (native aura slot)
        absorbSize = 30,
    },
    learned = {
        durations = {},         -- spell name -> seconds, learned from readable auras
        seen = {},              -- debuff key -> true once seen from you on a target (talent effects)
    },
}

local function fill(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            fill(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function copy(src)
    local t = {}
    for k, v in pairs(src) do t[k] = type(v) == "table" and copy(v) or v end
    return t
end

function NS:InitDB()
    if type(_G.ArchmageHUDDB) ~= "table" then _G.ArchmageHUDDB = {} end
    fill(_G.ArchmageHUDDB, self.defaults)
    self.db = _G.ArchmageHUDDB
end

function NS:ResetDB()
    _G.ArchmageHUDDB = copy(self.defaults)
    self.db = _G.ArchmageHUDDB
end

---------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------

NS.modules = {}
NS.moduleOrder = {}

-- info: { title, desc, icon }. A module may define:
--   :Init()   build frames, register events (once, at login)
--   :Apply()  re-read settings, show/hide (after every settings change)
function NS:NewModule(key, info)
    local m = info or {}
    m.key = key
    self.modules[key] = m
    self.moduleOrder[#self.moduleOrder + 1] = key
    return m
end

function NS:IsEnabled(key)
    return self.db and self.db.modules[key] and self.isMage or false
end

---------------------------------------------------------------------------
-- Spec: picked in the settings, or "auto" from the talents you have.
-- Modules read NS.spec and get an "MF_SPEC" message when it changes.
---------------------------------------------------------------------------

NS.SPECS = {
    { key = "arcane", label = "Arcane", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
    { key = "fire",   label = "Fire",   icon = "Interface\\Icons\\Spell_Fire_FireBolt02" },
    { key = "frost",  label = "Frost",  icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" },
}

function NS:SpecInfo(key)
    for _, s in ipairs(self.SPECS) do if s.key == (key or self.spec) then return s end end
    return self.SPECS[3]
end

function NS:UpdateSpec()
    local want = self.db.spec
    local spec = want ~= "auto" and want or self.Spells:DetectSpec()
    self.specAuto = want == "auto"
    if spec ~= self.spec then
        self.spec = spec
        self:Send("MF_SPEC", spec)
        if self.UI then self.UI:ApplyAppearance() end
        self:ApplyAll()
    end
end

function NS:SetSpec(key)
    self.db.spec = key
    self:UpdateSpec()
end

function NS:SetModuleEnabled(key, on)
    self.db.modules[key] = on and true or false
    self:ApplyAll()
end

-- Presets: how much HUD, as one switch in the overview. The one whose values all match is active.
-- extras: rotation marks under the stack bar and the Polymorph timer.
NS.PRESETS = {
    { key = "minimal",  label = "Minimal",  modules = "castbar procs stacks", extras = false },
    { key = "standard", label = "Standard", modules = "mana castbar procs stacks debuffs cooldowns reminders", extras = false },
    { key = "full",     label = "Full",     modules = "mana castbar procs stacks debuffs cooldowns reminders opener", extras = true },
}

local function presetValues(p)   -- { { section, key, value }, ... }
    local out = { { "stacks", "marks", p.extras }, { "debuffs", "focus", p.extras } }
    for key in pairs(NS.defaults.modules) do
        out[#out + 1] = { "modules", key, (" " .. p.modules .. " "):find(" " .. key .. " ", 1, true) ~= nil }
    end
    return out
end

function NS:Preset()
    for _, p in ipairs(self.PRESETS) do
        local match = true
        for _, v in ipairs(presetValues(p)) do if self.db[v[1]][v[2]] ~= v[3] then match = false end end
        if match then return p.key end
    end
end

function NS:SetPreset(key)
    for _, p in ipairs(self.PRESETS) do
        if p.key == key then
            for _, v in ipairs(presetValues(p)) do self.db[v[1]][v[2]] = v[3] end
        end
    end
    self:ApplyAll()
end

function NS:ApplyAll()
    for _, key in ipairs(self.moduleOrder) do
        local m = self.modules[key]
        if m.Apply then
            local ok, err = pcall(m.Apply, m)
            if not ok then geterrorhandler()(err) end
        end
    end
    self:Send("MF_APPLIED")
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

NS:On("PLAYER_LOGIN", function()
    NS:InitDB()
    local _, class = UnitClass("player")
    NS.isMage = class == "MAGE"

    NS.Spells:Resolve()
    NS.spec = NS.db.spec ~= "auto" and NS.db.spec or NS.Spells:DetectSpec()
    NS.specAuto = NS.db.spec == "auto"
    if NS.UI then NS.UI:ApplyAppearance() end

    for _, key in ipairs(NS.moduleOrder) do
        local m = NS.modules[key]
        if m.Init and NS.isMage then
            local ok, err = pcall(m.Init, m)
            if not ok then geterrorhandler()(err) end
        end
    end
    NS:ApplyAll()

    if not NS.isMage then
        NS.Print("not a Mage - modules are off. /mage still opens the settings.")
    end
end)

local function onSpellsChanged()
    if not NS.db then return end
    NS.Spells:Resolve()
    NS:Send("MF_SPELLS")
    NS:UpdateSpec()
end
NS:On("SPELLS_CHANGED", onSpellsChanged)
NS:On("PLAYER_TALENT_UPDATE", onSpellsChanged)
NS:On("LEARNED_SPELL_IN_SKILL_LINE", onSpellsChanged)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local commands = {}
NS.commands = commands

commands[""] = function() if NS.Options then NS.Options:Toggle() end end
commands["edit"] = function() if NS.Movers then NS.Movers:Toggle() end end
commands["test"] = function() if NS.Alerts then NS.Alerts:Test() end end
commands["legend"] = function()
    if NS.Options and NS.Options:IsShown() then NS.Options:Toggle() end   -- the window would cover the HUD
    NS.Movers:Toggle(true, true)
end
for _, sp in ipairs(NS.SPECS) do
    commands[sp.key] = function() NS:SetSpec(sp.key); NS.Print("spec: " .. sp.label) end
end
commands["auto"] = function() NS:SetSpec("auto"); NS.Print("spec: auto (" .. NS:SpecInfo().label .. ")") end
commands["reset"] = function(arg)
    if arg ~= "confirm" then
        NS.Print("type |cffffd100/mage reset confirm|r to reset all settings and positions.")
        return
    end
    NS:ResetDB()
    NS:UpdateSpec()
    if NS.Movers then NS.Movers:RestoreAll() end
    if NS.UI then NS.UI:ApplyAppearance() end
    NS:ApplyAll()
    NS.Print("settings reset.")
end
commands["help"] = function()
    NS.Print("commands:")
    print("  /mage - settings window")
    print("  /mage arcane | fire | frost | auto - switch spec")
    print("  /mage edit - move frames")
    print("  /mage legend - what each HUD element is for (10 seconds)")
    print("  /mage test - preview alerts")
    print("  /mage probe - what Forever lets the addon read (use it in combat too)")
    print("  /mage spells - copyable list of your spells and their IDs")
    print("  /mage reset confirm - reset everything")
end

SLASH_ARCHMAGEHUD1 = "/mage"
SLASH_ARCHMAGEHUD2 = "/amh"
SlashCmdList.ARCHMAGEHUD = function(msg)
    msg = (msg or ""):lower()
    local cmd, arg = msg:match("^%s*(%S*)%s*(.-)%s*$")
    local fn = commands[cmd or ""] or commands.help
    if not NS.db then return end
    fn(arg)
end

function _G.ArchmageHUD_OnAddonCompartmentClick()
    commands[""]()
end

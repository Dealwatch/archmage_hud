--[[
    Offline smoke test: loads the addon into a fake WoW client and drives it
    through login, every settings page, edit mode, combat (with secret values)
    and the diagnostics. Any Lua error fails the run.

        lua5.1 tests/run.lua
]]

local ROOT = (arg and arg[0] or ""):match("^(.*)tests[/\\]run%.lua$") or "./"

---------------------------------------------------------------------------
-- Secret values: userdata that errors on comparison, arithmetic, concat
---------------------------------------------------------------------------

local secrets = setmetatable({}, { __mode = "k" })
local function secret()
    local u = newproxy(true)
    local mt = getmetatable(u)
    local function boom() error("secret value used in logic", 2) end
    mt.__lt, mt.__le, mt.__add, mt.__sub, mt.__mul, mt.__div, mt.__concat, mt.__unm = boom, boom, boom, boom, boom, boom, boom, boom
    mt.__tostring = boom
    mt.__index = boom
    secrets[u] = true
    return u
end
function issecretvalue(v) return secrets[v] == true end

local combat = false
local function S(v) if combat then return secret() end return v end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

local now = 1000
local eventFrames = {}     -- event -> { frame = true }
local unitEventFrames = {}
local allFrames = {}

local Object = {}
Object.__index = function(self, k)
    local m = Object[k]
    if m ~= nil then return m end
    if type(k) == "string" and k:match("^%u") then
        return function() end   -- unknown widget method: no-op
    end
end

local function newObject(kind, parent)
    local o = setmetatable({ _kind = kind, _shown = true, _w = 0, _h = 0, _parent = parent, _scripts = {}, _attr = {}, _alpha = 1, _min = 0, _max = 1, _val = 0, _scroll = 0 }, Object)
    allFrames[#allFrames + 1] = o
    return o
end

function Object:SetSize(w, h) self._w, self._h = w, h end
function Object:SetWidth(w) self._w = w end
function Object:SetHeight(h) self._h = h end
function Object:GetWidth() return self._w end
function Object:GetHeight() return self._h end
function Object:GetSize() return self._w, self._h end
function Object:Show() self._shown = true end
function Object:Hide()
    local was = self._shown
    self._shown = false
    if was and self._scripts.OnHide then self._scripts.OnHide(self) end
end
function Object:SetShown(v) if v then self:Show() else self:Hide() end end
function Object:IsShown() return self._shown end
function Object:IsVisible() return self._shown end
function Object:SetScript(name, fn) self._scripts[name] = fn end
function Object:GetScript(name) return self._scripts[name] end
function Object:HookScript(name, fn) self._scripts[name] = fn end
function Object:GetCenter() return 500, 400 end
function Object:GetEffectiveScale() return 1 end
function Object:GetScale() return 1 end
function Object:GetFrameLevel() return 1 end
function Object:GetParent() return self._parent end
function Object:SetAttribute(k, v) self._attr[k] = v end
function Object:GetAttribute(k) return self._attr[k] end
function Object:SetAlpha(a) self._alpha = a end
function Object:GetAlpha() return self._alpha end
function Object:SetMinMaxValues(a, b) self._min, self._max = a, b end
function Object:GetMinMaxValues() return self._min, self._max end
function Object:SetValue(v)
    assert(not issecretvalue(v) or self._kind == "StatusBar", "secret into non-statusbar")
    self._val = v
    if self._scripts.OnValueChanged then self._scripts.OnValueChanged(self, v, false) end
end
function Object:GetValue() return self._val end
function Object:SetText(t) self._text = t end
function Object:GetText() return self._text end
function Object:SetFont() return true end
function Object:GetVerticalScroll() return self._scroll end
function Object:SetVerticalScroll(v) self._scroll = v end
function Object:SetScrollChild(c) self._child = c end
function Object:GetScrollChild() return self._child end
function Object:GetThumbTexture() return self._thumb end
function Object:SetThumbTexture() self._thumb = newObject("Texture", self) end
function Object:RegisterEvent(e)
    eventFrames[e] = eventFrames[e] or {}
    eventFrames[e][self] = true
end
function Object:RegisterUnitEvent(e, unit)
    unitEventFrames[e] = unitEventFrames[e] or {}
    unitEventFrames[e][self] = unit
end
function Object:CreateTexture() return newObject("Texture", self) end
function Object:CreateFontString() return newObject("FontString", self) end
function Object:CreateAnimationGroup() return newObject("AnimationGroup", self) end
function Object:CreateAnimation() return newObject("Animation", self) end
function Object:SetCooldown(start, dur)
    assert(type(start) == "number" and type(dur) == "number", "SetCooldown needs numbers")
end
function Object:SetCooldownFromDurationObject(d) assert(type(d) == "table" and d._duration, "needs duration object") end
function Object:SetTimerDuration(d) assert(type(d) == "table" and d._duration, "needs duration object") end
function Object:SetTexture(t) self._tex = t end

-- Blizzard_AuraContainer (CustomAuraContainerTemplate)
local function kindIs(o, kind) return type(o) == "table" and o._kind == kind end
function Object:AddAuraSlot(key, filter, opts)
    assert(type(key) == "string" and type(filter) == "string", "slot key/filter")
    local ids = opts and opts.candidateFilters and opts.candidateFilters.includeSpellIDs
    assert(type(ids) == "table" and next(ids), "includeSpellIDs map")
    self._ids = ids
    local b = newObject("Button", self)
    if opts.initializeFrame then opts.initializeFrame(b) end
    return b
end
function Object:AddAuraGroup(key, filter, opts)
    assert(type(key) == "string" and type(filter) == "string", "group key/filter")
    local ids = opts and opts.candidateFilters and opts.candidateFilters.includeSpellIDs
    assert(type(ids) == "table" and next(ids), "group includeSpellIDs map")
    assert(opts.layout and opts.layout.elementWidth, "group layout")
    self._ids = ids
    for _ = 1, 2 do opts.initializeFrame(newObject("Button", self)) end
end
function Object:SetApplicationBar(bar, o) assert(kindIs(bar, "StatusBar") and o and o.maxApplications, "application bar") end
function Object:SetApplicationCount(fs) assert(kindIs(fs, "FontString"), "application count") end
function Object:SetDurationBar(bar) assert(kindIs(bar, "StatusBar"), "duration bar") end
function Object:SetDurationText(fs) assert(kindIs(fs, "FontString"), "duration text") end
function Object:SetDurationCooldown(cd) assert(kindIs(cd, "Cooldown"), "duration cooldown") end
function Object:SetIcon(t) assert(kindIs(t, "Texture"), "icon texture") end
function Object:IsMouseOver() return false end

function CreateFrame(kind, name, parent, template)
    local f = newObject(kind, parent)
    if name then _G[name] = f end
    f._template = template
    return f
end

UIParent = newObject("Frame")
UIParent._w, UIParent._h = 1920, 1080
GameTooltip = newObject("GameTooltip")
ChatFontNormal = {}
UISpecialFrames = {}
SlashCmdList = {}
SOUNDKIT = { RAID_WARNING = 8959, ALARM_CLOCK_WARNING_2 = 18871, ALARM_CLOCK_WARNING_3 = 12889, IG_MAINMENU_OPTION_CHECKBOX_ON = 856 }

---------------------------------------------------------------------------
-- Client API
---------------------------------------------------------------------------

local errors = {}
function geterrorhandler() return function(e) errors[#errors + 1] = e; print("ERROR: " .. tostring(e)) end end
function GetTime() return now end
function date(fmt) return os.date(fmt) end
function GetLocale() return "enUS" end
function GetBuildInfo() return "1.60.1", "70862", "Nov 7 2026", 16001 end
function UnitClass() return "Mage", "MAGE" end
function UnitLevel() return 40 end
function UnitName(u) if u == "target" then return S("Kobold Miner") end return "Tester" end
function UnitExists() return true end
function UnitAffectingCombat() return combat end
function UnitIsDeadOrGhost() return false end
function IsMounted() return false end
function IsShiftKeyDown() return false end
function InCombatLockdown() return combat end
function UnitCastingInfo() return nil end
function GetInventoryItemID(_, slot) return 1000 + slot end
GetBindingKey = function() return nil end
local mana = 1000
function UnitPower() return S(mana) end
function UnitPowerMax() return S(1000) end
function UnitCanAttack() return S(true) end
function PlaySound() end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
unpack = unpack or table.unpack

local SPELLS = {
    [133] = "Fireball", [116] = "Frostbolt", [5143] = "Arcane Missiles", [2136] = "Fire Blast", [2948] = "Scorch",
    [11366] = "Pyroblast", [11129] = "Combustion", [12654] = "Ignite", [22959] = "Fire Vulnerability",
    [1459] = "Arcane Intellect", [168] = "Frost Armor", [7302] = "Ice Armor", [1953] = "Blink", [2139] = "Counterspell",
    [122] = "Frost Nova", [12051] = "Evocation", [11426] = "Ice Barrier", [1463] = "Mana Shield",
    [759] = "Conjure Mana Agate", [3561] = "Teleport: Stormwind", [12536] = "Clearcasting", [12579] = "Winter's Chill",
    [90002] = "Frostfire Bolt", [11119] = "Ignite", [11095] = "Improved Scorch", [11071] = "Frostbite", [400625] = "Heating Up", [400573] = "Arcane Blast",
}
-- player knows these (spellbook, Forever-style unknown ID for Frostfire Bolt)
local BOOK = { 133, 116, 5143, 2136, 2948, 11366, 11129, 1459, 168, 7302, 1953, 2139, 122, 12051, 1463, 759, 3561, 90002, 11119, 11095, 11071 }

C_Spell = {
    GetSpellName = function(id) return SPELLS[id] end,
    GetSpellTexture = function(id) return SPELLS[id] and 1000 + id end,
    GetSpellCooldown = function() return { startTime = S(0), duration = S(0) } end,
    GetSpellCooldownDuration = function() return { _duration = true } end,
    IsSpellUsable = function() return true, false end,
    GetSpellDisplayCount = function() return S("") end,
    GetSpellCastCount = function() return S(0) end,
}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { name = "Fire", itemIndexOffset = 0, numSpellBookItems = #BOOK } end,
    GetSpellBookItemInfo = function(i) local id = BOOK[i]; return id and { name = SPELLS[id], spellID = id, actionID = id, subName = "", isPassive = false } end,
    IsSpellKnown = function(id) for _, b in ipairs(BOOK) do if b == id then return true end end return false end,
}
local playerAuras = {}
local targetAuras = {}
C_UnitAuras = {
    GetAuraDataByIndex = function(unit, i)
        local a = unit == "player" and playerAuras[i]
        if not a then return nil end
        if combat and not a.whitelisted then return { name = secret(), spellId = secret(), applications = secret() } end
        return a
    end,
    GetPlayerAuraBySpellID = function(id)
        for _, a in ipairs(playerAuras) do if a.spellId == id and (a.whitelisted or not combat) then return a end end
    end,
    GetAuraDataBySpellName = function(unit, name)
        if combat then return nil end
        for _, a in ipairs(unit == "player" and playerAuras or targetAuras) do if a.name == name then return a end end
    end,
}
C_Secrets = { ShouldAurasBeSecret = function() return combat end, ShouldCooldownsBeSecret = function() return combat end }
local bag = { [17031] = 10, [17032] = 0 }
C_Item = { GetItemCount = function(id) return bag[id] or 0 end }
C_SpellActivationOverlay = { IsSpellOverlayed = function() return false end }
C_AddOns = { GetAddOnMetadata = function() return "0.1.0-test" end }
local timers = {}
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTicker = function(_, fn) timers[#timers + 1] = fn; return { Cancel = function() end } end,
}
Enum = {
    PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 },
    SpellBookSpellBank = { Player = 0, Pet = 1 },
    WeaponSlot = { MainHand = 0, OffHand = 1 },
    ItemEnchantType = { None = 0, Permanent = 1, Temporary = 2, Imbue = 3 },
    StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
    StatusBarInterpolation = { Immediate = 0 },
}

---------------------------------------------------------------------------
-- Driver
---------------------------------------------------------------------------

local function fire(event, ...)
    for f in pairs(eventFrames[event] or {}) do
        local fn = f._scripts.OnEvent
        if fn then fn(f, event, ...) end
    end
    for f, unit in pairs(unitEventFrames[event] or {}) do
        local u = ...
        if u == unit then
            local fn = f._scripts.OnEvent
            if fn then fn(f, event, ...) end
        end
    end
end

local function runTimers()
    local list = timers
    timers = {}
    for _, fn in ipairs(list) do fn() end
end

local function tick(dt)
    now = now + (dt or 0.1)
    for _, f in ipairs(allFrames) do
        if f._shown and f._scripts.OnUpdate then f._scripts.OnUpdate(f, dt or 0.1) end
    end
end

-- load the addon in TOC order
local NS = {}
local toc = assert(io.open(ROOT .. "ArchmageHUD.toc")):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^##") and line:match("%.lua$") then
        local path = ROOT .. line:gsub("\\", "/")
        local chunk = assert(loadfile(path))
        chunk("ArchmageHUD", NS)
    end
end

local step
local function check(name)
    if #errors > 0 then
        print(("FAIL after step '%s': %d error(s)"):format(name, #errors))
        os.exit(1)
    end
    print("ok  " .. name)
end
local function run(name, fn)
    step = name
    local ok, err = pcall(fn)
    if not ok then errors[#errors + 1] = err; print("ERROR: " .. tostring(err)) end
    runTimers()
    check(name)
end

run("login", function()
    fire("PLAYER_LOGIN")
    fire("PLAYER_ENTERING_WORLD")
    assert(NS.db and NS.isMage, "db/mage")
    assert(NS.Spells:Get("fireball").known, "fireball resolved")
    assert(NS.Spells:Get("frostfireBolt").known and NS.Spells:Get("frostfireBolt").id == 90002, "resolved by name from spellbook")
    assert(not NS.Spells:Get("iceBarrier").known, "unknown spell stays unknown")
    assert(NS.spec == "fire", "auto spec from talent spells: " .. tostring(NS.spec))
    for _, key in ipairs({ "stacks_fire", "stacks_frost", "procs_fire", "debuff_frostfireBolt", "debuff_fireVuln", "stacks_arcane", "absorb" }) do
        assert(NS.Native.slots[key] and NS.Native.slots[key]:Active(), "native slot " .. key)
    end
    assert(NS.Native.slots.stacks_fire.container._ids[400625], "heating up buff id in filter")
    assert(NS.Native.slots.stacks_arcane.container._ids[400573], "arcane blast buff id in filter")
    assert(NS.Native.slots.debuff_ignite.container._ids[412538], "forever ignite id in filter")
    assert(NS.Native.slots.debuff_fireball:Active(), "fireball dot bar (Fire Power)")
    assert(NS.Native.slots.absorb.container._ids[13033] and NS.Native.slots.absorb.container._ids[10193], "absorb ranks in filter")
    assert(_G.ArchmageHUDAlerts:GetParent() == UIParent, "alerts stay outside the HUD root")
end)

run("settings window, every page", function()
    SlashCmdList.ARCHMAGEHUD("")
    for _, key in ipairs({ "overview", "mana", "procs", "stacks", "debuffs", "cooldowns", "reminders", "appearance" }) do
        NS.Options:Show(key)
    end
    NS.Options:Toggle()
end)

run("spec switch", function()
    for _, spec in ipairs({ "arcane", "frost", "fire", "auto" }) do
        SlashCmdList.ARCHMAGEHUD(spec)
        NS.Options:Show("overview")
        NS.Options:Show("procs")
        NS.Options:Show("debuffs")
    end
    assert(NS.spec == "fire" and NS.db.spec == "auto", "back to auto")
    NS:SetSpec("frost")
    assert(NS.spec == "frost", "manual frost")
    assert(NS.UI:Accent() == 0.55, "accent follows spec")
    NS:SetSpec("auto")
    NS.Options:Toggle()
end)

run("automatic layout per spec", function()
    local L = NS.Layout
    local cd = {}
    for _, spec in ipairs({ "fire", "frost", "arcane" }) do
        NS:SetSpec(spec)
        cd[spec] = L.Column().cooldowns[4]
        if spec == "fire" then assert(L.DebuffRows() == 5, "fire: 5 debuff rows (Ignite/Fire Vulnerability are talent effects) " .. L.DebuffRows()) end
        if spec == "frost" then
            assert(L.DebuffRows() == 2, "frost: Frost Nova + Frostbite (talent known)")
            BOOK[#BOOK] = nil   -- unlearn Frostbite
            NS.Spells:Resolve()
            assert(L.DebuffRows() == 1, "no Frostbite row without the talent")
            BOOK[#BOOK + 1] = 11071
            NS.Spells:Resolve()
        end
        if spec == "arcane" then assert(L.DebuffRows() == 0, "arcane: no debuff rows") end
    end
    assert(cd.arcane > cd.frost and cd.frost > cd.fire, "cooldown row closes up when a spec has fewer rows")
    NS:SetModuleEnabled("mana", false)
    assert(L.Column().cooldowns[4] > cd.arcane, "switched-off module takes no space")
    NS:SetModuleEnabled("mana", true)
    -- a moved frame is saved for that spec only
    NS.Movers.Positions().mana = { x = 10, y = -300 }
    NS:SetSpec("frost")
    assert(NS.Movers.Positions().mana == nil, "frost keeps the automatic spot")
    NS:SetSpec("arcane")
    assert(NS.Movers.Positions().mana.y == -300, "arcane keeps your spot")
    NS.Movers.Positions().mana = nil
    NS:SetSpec("auto")
end)

run("settings change", function()
    NS.db.appearance.accent = "arcane"
    NS.UI:ApplyAppearance()
    NS:SetModuleEnabled("debuffs", false)
    NS:SetModuleEnabled("debuffs", true)
    NS.db.stacks.width = 300
    NS:ApplyAll()
end)

run("edit mode", function()
    SlashCmdList.ARCHMAGEHUD("edit")
    tick(0.1)
    assert(_G.ArchmageHUDProcCard:IsShown(), "proc card preview in edit mode")
    NS.Movers:Toggle(false)
    assert(not _G.ArchmageHUDProcCard:IsShown(), "proc card hidden again")
end)

run("out of combat reminders", function()
    fire("UNIT_AURA", "player", {})
    assert(NS.Alerts.active.intellect, "missing arcane intellect")
    assert(NS.Alerts.active.armor, "missing armor")
    assert(NS.Alerts.active.gem, "no mana gem")
    assert(not NS.Alerts.active.runes, "enough teleport runes, portals unknown")
    playerAuras[1] = { name = "Arcane Intellect", spellId = 1459, duration = 1800 }
    playerAuras[2] = { name = "Ice Armor", spellId = 7302, duration = 1800 }
    fire("UNIT_AURA", "player", {})
    assert(not NS.Alerts.active.intellect and not NS.Alerts.active.armor, "buffs read")
    bag[5514] = 1
    fire("BAG_UPDATE_DELAYED")
    assert(not NS.Alerts.active.gem, "gem in bags")
    bag[17031] = 1
    fire("BAG_UPDATE_DELAYED")
    assert(NS.Alerts.active.runes, "low on runes")
    SlashCmdList.ARCHMAGEHUD("probe")
    SlashCmdList.ARCHMAGEHUD("spells")
    SlashCmdList.ARCHMAGEHUD("test")
end)

run("stacks out of combat", function()
    playerAuras[3] = { name = "Heating Up", spellId = 400625, applications = 3, duration = 20 }
    fire("UNIT_AURA", "player", {})
    local st = NS.modules.stacks.state
    assert(st.stacks == 3 and st.full, "three Heating Up stacks read")
    assert(NS.modules.stacks.hint:IsShown(), "Pyroblast hint at full stacks")
    playerAuras[3] = nil
    fire("UNIT_AURA", "player", {})
    assert(st.stacks == 0 and not st.full, "gone")
    -- Frost: Winter's Chill on the target
    NS:SetSpec("frost")
    targetAuras[1] = { name = "Winter's Chill", spellId = 12579, applications = 2, duration = 15, expirationTime = now + 15 }
    fire("UNIT_AURA", "target", {})
    assert(st.stacks == 2 and not st.full, "winter's chill stacks on target")
    targetAuras[1] = nil
    NS:SetSpec("auto")
end)

run("mana bar", function()
    mana = 1000
    NS.modules.mana:Update()
    assert(not _G.ArchmageHUDMana:IsShown(), "hidden at full mana out of combat")
    mana = 200
    NS.modules.mana:Update()
    assert(_G.ArchmageHUDMana:IsShown(), "shown when not full")
    assert(NS.modules.mana.Fraction() == 0.2, "fraction")
end)

run("combat with secrets", function()
    fire("PLAYER_REGEN_DISABLED")
    combat = true
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 90002)   -- Frostfire Bolt
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 133)     -- Fireball
    fire("UNIT_POWER_FREQUENT", "player", "MANA")               -- secret mana in combat
    assert(_G.ArchmageHUDDebuffs:IsShown() and _G.ArchmageHUDDebuffs:GetAlpha() == 1, "debuff bars")
    assert(NS.UI.root:GetAlpha() == 1, "HUD not faded in combat")
    fire("SPELL_UPDATE_COOLDOWN")
    fire("UNIT_AURA", "player", {})
    fire("UNIT_AURA", "target", {})
    fire("PLAYER_TARGET_CHANGED")
    assert(NS.modules.stacks.state.stacks == nil, "stacks unknown while secret")
    assert(not NS.Alerts.active.intellect, "secret buffs never warn")
    -- Hot Streak: the client lights Pyroblast
    fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 11366)
    assert(_G.ArchmageHUDProcCard:IsShown() and _G.ArchmageHUDProcCard.text:GetText() == "Pyroblast!", "proc card")
    fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 11366)
    assert(not _G.ArchmageHUDProcCard:IsShown(), "proc card gone")
    tick(0.2)
    SlashCmdList.ARCHMAGEHUD("probe")
    NS.Options:Show("overview")
    tick(1)
end)

run("leave combat", function()
    combat = false
    fire("PLAYER_REGEN_ENABLED")
    tick(2)
    assert(NS.db.probe.combat and NS.db.probe.outOfCombat and NS.db.probe.spells, "probe saved")
    _G.ArchmageHUDOptions:Hide()   -- an open settings window keeps the HUD visible
    UnitCanAttack = function() return false end
    fire("PLAYER_TARGET_CHANGED")
    assert(not NS.UI.root:IsShown(), "HUD hidden out of combat without an enemy")
    UnitCanAttack = function() return true end
    fire("PLAYER_TARGET_CHANGED")
    assert(NS.UI.root:IsShown() and NS.UI.root:GetAlpha() == 1, "enemy targeted out of combat: HUD shown")
end)

run("reset", function()
    SlashCmdList.ARCHMAGEHUD("reset confirm")
    assert(NS.db.spec == "auto", "reset spec")
end)

print("all good")

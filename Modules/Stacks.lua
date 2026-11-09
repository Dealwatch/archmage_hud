--[[
    ArchmageHUD - stack bar
    One segmented bar for the stacking thing your spec watches (see
    Spells.SPEC_DATA[spec].stacks), e.g. Arcane Blast stacks on you or the
    Fire Vulnerability / Winter's Chill stacks on your target. Gold at full
    stacks, with an optional glow and sound.

    The client fills the bar itself through a native aura slot, so it is right
    even while the aura is secret in combat. Glow and sound need us to *know*
    the stacks, which works whenever the aura is readable. Without a native
    slot the bar falls back to our own pips.
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local St = NS:NewModule("stacks", {
    title = "Stack Bar",
    desc = "Arcane Blast / Fire Vulnerability / Winter's Chill stacks",
    icon = "Interface\\Icons\\Spell_Arcane_Blast",
})

local GOLD = { 1, 0.82, 0.25 }
local GAP = 3
local MAX_PIPS = 5

local state = { stacks = nil, full = false, source = "none", readableInCombat = false }
St.state = state

local frame
local pips = {}
local hosts = {}      -- spec -> { frame, native, bar }

local function def(spec)
    local d = Spells.SPEC_DATA[spec or NS.spec]
    return d and d.stacks
end

local function geometry(max)
    local db = NS.db.stacks
    local pipW = (db.width - GAP * (max - 1)) / max
    return db.width, db.height, pipW
end

-- Readable stacks of the current spec's aura, or nil when we cannot tell.
function St.Read()
    local s = def()
    if not s then return nil end
    local d = Spells:Get(s.key)
    if not (d and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return nil end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, s.unit, d.name, s.filter)
    if not ok or NS.IsSecret(aura) then return nil end
    if aura then
        local n = NS.Readable(aura.applications)
        if n then return math.max(n, 1) end
        return nil
    end
    -- "none" is only trustworthy while auras are not secret
    if InCombatLockdown() then return nil end
    if s.unit == "target" and not UnitExists("target") then return 0 end
    return 0
end

local function buildHost(spec, s)
    local host = CreateFrame("Frame", nil, frame)
    host:SetAllPoints()
    host:Hide()
    UI:NativeHost(host)
    local h = { frame = host }
    h.native = NS.Native:Slot({
        key = "stacks_" .. spec, parent = host, unit = s.unit, filter = s.filter, level = 3,
        ids = function() return Spells:AuraIDs(s.key) end,
        init = function(b)
            local w, ht = geometry(s.max)
            b:SetSize(w, ht)
            local bar = CreateFrame("StatusBar", nil, b)
            bar:SetPoint("TOPLEFT", 1, -1)
            bar:SetPoint("BOTTOMRIGHT", -1, 1)
            bar:SetStatusBarTexture(UI.WHITE)
            bar:SetStatusBarColor(UI:Accent())
            b:SetApplicationBar(bar, { minApplications = 0, maxApplications = s.max })
            -- time left of the stack aura (Arcane Blast's 18 s window), right of the bar
            local time = UI:Text(b, 10, UI.palette.text, "OUTLINE")
            time:SetPoint("LEFT", b, "RIGHT", 4, 0)
            b:SetDurationText(time)
            h.bar = bar
        end,
        onBuilt = function() St:Apply() end,
    })
    hosts[spec] = h
    h.native:Build()
end

function St:Init()
    frame = CreateFrame("Frame", "ArchmageHUDStacks", UIParent)
    frame:Hide()
    UI:NativeHost(frame)
    self.frame = frame

    -- fallback pips (also the edit-mode preview)
    for i = 1, MAX_PIPS do
        local p = CreateFrame("Frame", nil, frame)
        UI:Skin(p, UI.palette.track, UI.palette.border, "xs")
        p.fill = p:CreateTexture(nil, "ARTWORK")
        if not UI.Sliced(p.fill, "Fill", "xs") then p.fill:SetTexture(UI.WHITE) end
        p.fill:SetPoint("TOPLEFT", 1, -1)
        p.fill:SetPoint("BOTTOMRIGHT", -1, 1)
        pips[i] = p
    end

    -- native mode: one bar the client fills, cut into segments by dividers
    self.track = CreateFrame("Frame", nil, frame)
    self.track:SetAllPoints()
    UI:Skin(self.track, UI.palette.track, UI.palette.border, "xs")
    self.track:Hide()
    self.dividers = CreateFrame("Frame", nil, frame)
    self.dividers:SetAllPoints()
    self.dividers:SetFrameLevel(frame:GetFrameLevel() + 10)
    self.dividers.lines = {}
    for i = 1, MAX_PIPS - 1 do
        local t = self.dividers:CreateTexture(nil, "OVERLAY")
        t:SetTexture(UI.WHITE)
        t:SetVertexColor(UI.palette.track[1], UI.palette.track[2], UI.palette.track[3], 1)
        self.dividers.lines[i] = t
    end
    self.dividers:Hide()

    self.label = UI:Text(frame, 10, UI.palette.textDim, "OUTLINE")
    self.label:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 3)
    self.hint = UI:Text(frame, 11, { GOLD[1], GOLD[2], GOLD[3], 1 }, "OUTLINE")
    self.hint:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 3)
    self.hint:SetJustifyH("RIGHT")
    self.hint:Hide()
    NS.Movers:Register(frame, "stacks", "Stacks", NS.Layout.For("stacks"))

    for _, sp in ipairs(NS.SPECS) do
        local s = def(sp.key)
        if s then buildHost(sp.key, s) end
    end

    local function update() self:Update() end
    NS:OnUnit("UNIT_AURA", "player", update)
    NS:OnUnit("UNIT_AURA", "target", update)
    NS:On("PLAYER_TARGET_CHANGED", function()
        for _, h in pairs(hosts) do h.native:Refresh() end
        update()
    end)
    NS:On("PLAYER_REGEN_ENABLED", update)
    NS:On("PLAYER_REGEN_DISABLED", update)
    NS:On("MF_SPEC", function() self:Apply() end)
end

function St:Update()
    if not frame then return end
    local s = def()
    local stacks = St.Read()
    if stacks then
        state.source = "aura"
        if InCombatLockdown() and stacks > 0 then state.readableInCombat = true end
    end
    local wasFull = state.full
    state.stacks = stacks
    state.full = s and stacks and stacks >= s.max or false
    if state.full and not wasFull and NS.db.stacks.sound and NS:IsEnabled("stacks") then UI:Sound("ALARM_CLOCK_WARNING_2") end
    self:Draw()
end

function St:Draw()
    local db = NS.db.stacks
    local s = def()
    local stacks = state.stacks
    if NS.editing and not stacks then stacks = 3 end
    local show = s and NS:IsEnabled("stacks") and (NS.editing or not db.hideEmpty or InCombatLockdown()
        or (stacks or 0) > 0) or false
    UI:SafeShow(frame, show)
    for spec, h in pairs(hosts) do UI:SafeShow(h.frame, show and spec == NS.spec and not NS.editing) end
    if not show then return end

    local h = hosts[NS.spec]
    local native = h and h.native:Active() and not NS.editing
    self.track:SetShown(native and true or false)
    self.dividers:SetShown(native and true or false)
    local r, g, b = UI:Accent()
    if h and h.bar then
        if state.full then h.bar:SetStatusBarColor(GOLD[1], GOLD[2], GOLD[3]) else h.bar:SetStatusBarColor(r, g, b) end
    end
    local filled = stacks or 0
    for i = 1, MAX_PIPS do
        local p = pips[i]
        p:SetShown(not native and i <= s.max)
        p.fill:SetShown(i <= filled)
        if state.full then p.fill:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1) else p.fill:SetVertexColor(r, g, b, 1) end
    end
    local d = Spells:Get(s.key)
    self.label:SetText(d and d.name or "")
    self.hint:SetText(s.full or "")
    self.hint:SetShown(state.full and s.full ~= nil)
    if state.full and db.glow then UI:Glow(frame, GOLD[1], GOLD[2], GOLD[3]) else UI:Glow(frame) end
end

function St:Apply()
    if not frame then return end
    local s = def()
    local max = s and s.max or MAX_PIPS
    local w, h, pipW = geometry(max)
    frame:SetSize(w, h)
    for i, p in ipairs(pips) do
        p:SetSize(pipW, h)
        p:ClearAllPoints()
        p:SetPoint("LEFT", frame, "LEFT", (i - 1) * (pipW + GAP), 0)
    end
    for i, t in ipairs(self.dividers.lines) do
        t:ClearAllPoints()
        t:SetPoint("TOP", frame, "TOPLEFT", i * (pipW + GAP) - GAP / 2, 0)
        t:SetSize(GAP, h)
        t:SetShown(i < max)
    end
    for spec, hs in pairs(hosts) do
        local sd = def(spec)
        hs.native:Restyle(function(b) b:SetSize(geometry(sd.max)) end)
    end
    self:Update()
end

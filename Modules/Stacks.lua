--[[
    ArchmageHUD - stack bar
    One segmented bar for the stacking thing your spec watches (see
    Spells.SPEC_DATA[spec].stacks): Arcane Blast or Heating Up stacks on you,
    Winter's Chill stacks on your target. Gold at full
    stacks, with an optional glow and sound.

    The client fills the bar itself through a native aura slot, so it is right
    even while the aura is secret in combat. Gold, hint, glow and sound need
    us to *know* the stacks, which works whenever the aura is readable.
    Without a native slot the bar falls back to our own pips.

    Under the bar: the rotation marks (buildMark), icons the client lights up
    gold at their stack count, also while the stacks are secret; and for
    Arcane the pips of a second aura, Heating Up (buildSecond).
]]

local _, NS = ...
local UI, Spells, Layout = NS.UI, NS.Spells, NS.Layout

local St = NS:NewModule("stacks", {
    title = "Stack Bar",
    desc = "Arcane Blast, Heating Up, Winter's Chill",
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
local marks = {}      -- rotation marks under the segments: the spell to cast at that many stacks
local seconds = {}    -- spec -> { frame, native, lines }: the pips of a second stack aura, in the row of the marks
local MARK = Layout.MARKS - 5
local SECOND_H = Layout.SECOND - 5
local SECOND_COLOR = { 1, 0.49, 0.18 }   -- Heating Up: fire
local DIM = 0.55

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
            local time = UI:Text(b, 12, UI.palette.text, "OUTLINE")
            time:SetPoint("LEFT", b, "RIGHT", 8, 0)   -- clear of the full-stacks glow
            b:SetDurationText(time)
            h.bar = bar
        end,
        onBuilt = function() St:Apply() end,
    })
    hosts[spec] = h
    h.native:Build()
end

-- A rotation mark: the icon of the spell to cast at n stacks, under the segment that completes them.
-- Small and grey until then. At n stacks the client itself lights it up: a native slot on the same
-- aura whose application bar runs from n - 1 to n. The bar is the gold frame ("cast this", like the
-- proc card and a lit cooldown) and the bright icon rides on its fill. So it works while the stacks
-- are secret in combat, where our own gold bar and hint cannot.
local function buildMark(spec, s, n, keys, second)
    local m = CreateFrame("Frame", nil, frame)
    m:SetSize(MARK, MARK)
    m:Hide()
    UI:NativeHost(m)
    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetPoint("TOPLEFT", 3, -3)
    m.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    m.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    m.spec, m.n, m.keys, m.second = spec, n, keys, second or false
    m.native = NS.Native:Slot({
        key = (second and "mark2_" or "mark_") .. spec .. n, parent = m, unit = s.unit, filter = s.filter, level = 3,
        ids = function() return Spells:AuraIDs(s.key) end,
        init = function(b)
            b:SetSize(MARK, MARK)
            local bar = CreateFrame("StatusBar", nil, b)
            bar:SetAllPoints()
            bar:SetStatusBarTexture(UI.WHITE)
            bar:SetStatusBarColor(GOLD[1], GOLD[2], GOLD[3])
            b:SetApplicationBar(bar, { minApplications = n - 1, maxApplications = n })
            -- anchored to the fill with an inset: no fill, no icon (its anchors cross, so it is not drawn)
            local fill = bar:GetStatusBarTexture()
            m.lit = bar:CreateTexture(nil, "OVERLAY")
            m.lit:SetPoint("TOPLEFT", fill, "TOPLEFT", 2, -2)
            m.lit:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", -2, 2)
            m.lit:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end,
        onBuilt = function() St:Apply() end,
    })
    marks[#marks + 1] = m
    m.native:Build()
end

-- The pips of a second stack aura (Arcane hybrid: Heating Up next to the Arcane Blast stacks).
-- Native only: without the client's aura slot there is nothing to fill them from.
local function buildSecond(spec, s)
    local host = CreateFrame("Frame", nil, frame)
    host:Hide()
    UI:NativeHost(host)
    local bg = host:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(UI.WHITE)
    bg:SetVertexColor(UI.palette.track[1], UI.palette.track[2], UI.palette.track[3], UI.palette.track[4])
    local div = CreateFrame("Frame", nil, host)   -- dividers above the bar the client fills
    div:SetAllPoints()
    div:SetFrameLevel(host:GetFrameLevel() + 10)
    local h = { frame = host, lines = {} }
    for i = 1, s.max - 1 do
        h.lines[i] = div:CreateTexture(nil, "OVERLAY")
        h.lines[i]:SetTexture(UI.WHITE)
        h.lines[i]:SetVertexColor(UI.palette.track[1], UI.palette.track[2], UI.palette.track[3], 1)
    end
    h.native = NS.Native:Slot({
        key = "stacks2_" .. spec, parent = host, unit = s.unit, filter = s.filter, level = 3,
        ids = function() return Spells:AuraIDs(s.key) end,
        init = function(b)
            b:SetSize(NS.db.stacks.width, SECOND_H)
            local bar = CreateFrame("StatusBar", nil, b)
            bar:SetAllPoints()
            bar:SetStatusBarTexture(UI.WHITE)
            bar:SetStatusBarColor(SECOND_COLOR[1], SECOND_COLOR[2], SECOND_COLOR[3])
            b:SetApplicationBar(bar, { minApplications = 0, maxApplications = s.max })
        end,
        onBuilt = function() St:Apply() end,
    })
    seconds[spec] = h
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

    self.label = UI:Text(frame, 11, UI.palette.textDim, "OUTLINE")
    self.label:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 3)
    self.hint = UI:Text(frame, 11, { GOLD[1], GOLD[2], GOLD[3], 1 }, "OUTLINE")
    self.hint:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 3)
    self.hint:SetJustifyH("RIGHT")
    self.hint:Hide()
    NS.Movers:Register(frame, "stacks", "Stacks", NS.Layout.For("stacks"))

    self.marks = marks

    for _, sp in ipairs(NS.SPECS) do
        local s = def(sp.key)
        if s then
            buildHost(sp.key, s)
            for _, mark in ipairs(s.marks or {}) do buildMark(sp.key, s, mark[1], { unpack(mark, 2) }) end
        end
        local s2 = Spells.SPEC_DATA[sp.key].second
        if s2 then
            buildSecond(sp.key, s2)
            buildMark(sp.key, s2, s2.max, { s2.mark }, true)
        end
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
    local show = s and NS:IsEnabled("stacks") and (NS.editing or not db.hideEmpty or NS.InCombat()
        or (stacks or 0) > 0) or false
    UI:SafeShow(frame, show)
    for spec, h in pairs(hosts) do UI:SafeShow(h.frame, show and spec == NS.spec and not NS.editing) end
    for spec, h in pairs(seconds) do UI:SafeShow(h.frame, show and spec == NS.spec) end
    for _, m in ipairs(marks) do UI:SafeShow(m, show and db.marks and m.spec == NS.spec and m.def ~= nil) end
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
    for _, m in ipairs(marks) do   -- without a native slot: lit from the stacks we can read
        local lit = not m.native:Active() and not m.second and filled >= m.n
        m.icon:SetDesaturated(not lit)
        m.icon:SetAlpha(lit and 1 or DIM)
    end
    local d = Spells:Get(s.key)
    self.label:SetText(d and d.name or "")
    local fd = Spells:Get(s.full)
    self.hint:SetText(fd and (fd.name or fd.en) .. "!" or "")
    local hint = state.full and s.full ~= nil and self.hint:GetStringWidth() <= db.width   -- a bar too narrow for it: the lit mark says it
    self.hint:SetShown(hint)
    -- narrow bar or large text: the hint wins, the name would run into it
    self.label:SetShown(not hint or self.label:GetStringWidth() + self.hint:GetStringWidth() + 8 <= db.width)
    if state.full and db.glow then UI:Glow(frame, GOLD[1], GOLD[2], GOLD[3]) else UI:Glow(frame) end
end

function St:Apply()
    if not frame then return end
    if InCombatLockdown() then   -- geometry of an aura container host: only out of combat
        NS.AfterCombat("stacksApply", function() self:Apply() end)
        return self:Update()
    end
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
    -- rotation marks: the first spell of each mark that you know, under the segment that completes it
    local row = NS.db.stacks.marks
    for _, m in ipairs(marks) do
        m.def = nil
        for _, key in ipairs(m.keys) do
            local c = Spells:Get(key)
            if not m.def and c and (c.known or NS.editing) then m.def = c end
        end
        if m.def then
            m.icon:SetTexture(m.def.icon)
            if m.lit then m.lit:SetTexture(m.def.icon) end
        end
        if m.spec == NS.spec then
            m:ClearAllPoints()   -- the second aura's mark follows its pips, under the first two segments
            m:SetPoint("TOP", frame, "BOTTOMLEFT", (m.second and 1.5 or m.n - 0.5) * (pipW + GAP) - GAP / 2, -5)
        end
    end
    for spec, h2 in pairs(seconds) do
        local s2 = Spells.SPEC_DATA[spec].second
        -- in the row of the marks: from the left edge up to its own mark, centred on the row
        local sw = row and math.max(1.5 * (pipW + GAP) - GAP / 2 - MARK / 2 - 4, 12) or w
        local segW = (sw - GAP * (s2.max - 1)) / s2.max
        h2.frame:ClearAllPoints()
        h2.frame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -5 - ((row and MARK or SECOND_H) - SECOND_H) / 2)
        h2.frame:SetSize(sw, SECOND_H)
        for i, t in ipairs(h2.lines) do
            t:ClearAllPoints()
            t:SetPoint("TOP", h2.frame, "TOPLEFT", i * (segW + GAP) - GAP / 2, 0)
            t:SetSize(GAP, SECOND_H)
        end
        h2.native:Restyle(function(b) b:SetSize(sw, SECOND_H) end)
    end
    self:Update()
end

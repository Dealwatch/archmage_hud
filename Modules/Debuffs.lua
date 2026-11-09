--[[
    MageForever - target debuffs
    One bar per debuff your spec keeps on the target (Spells.SPEC_DATA[spec]
    .debuffs), e.g. Living Bomb or Ignite: icon, time left and stacks.

    Each bar is a native aura slot on the target ("HARMFUL|PLAYER"), so the
    client draws the real time left even while the debuff is secret in
    combat. Without a native slot a bar falls back to a timer started from
    your own cast (target debuffs are secret in combat), corrected from the
    real aura whenever it is readable.
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local Db = NS:NewModule("debuffs", {
    title = "Target Debuffs",
    desc = "Your DoTs and debuffs on the target, with real time left",
    icon = "Interface\\Icons\\Spell_Fire_Incinerate",
})

local GAP = 2
local frame
local rows = {}         -- key -> row (shared between specs)
local timers = {}       -- key -> { start, ends }

local function list(spec) return Spells:DebuffsFor(spec or NS.spec) end

local function duration(key)
    local d = Spells:Get(key)
    return (d and NS.db.learned.durations[d.name]) or (d and d.dur) or 12
end

local function buildRow(key)
    local db = NS.db.debuffs
    local h = db.height
    local r = CreateFrame("Frame", nil, frame)
    r:SetSize(db.width, h)
    r:Hide()
    UI:NativeHost(r)
    r.key = key
    -- fallback widgets (and the edit-mode preview)
    r.iconFrame = UI:Icon(r, h)
    r.iconFrame:SetPoint("LEFT")
    r.bar = UI:Bar(r, db.width - h - 2, h)
    r.bar:SetPoint("LEFT", r.iconFrame, "RIGHT", 2, 0)
    r.time = UI:Text(r.bar, 10, UI.palette.text, "OUTLINE")
    r.time:SetPoint("RIGHT", -4, 0)
    r.time:SetJustifyH("RIGHT")

    local d = Spells:Get(key)
    local color = d and d.color or { 1, 0.45, 0.16 }
    r.bar:SetStatusBarColor(color[1], color[2], color[3])
    r.native = NS.Native:Slot({
        key = "debuff_" .. key, parent = r, unit = "target", filter = "HARMFUL|PLAYER",
        ids = function() return Spells:AuraIDs(key) end,
        init = function(b)
            local bw, bh = NS.db.debuffs.width, NS.db.debuffs.height
            b:SetSize(bw, bh)
            local iconFrame = CreateFrame("Frame", nil, b)
            iconFrame:SetSize(bh, bh)
            iconFrame:SetPoint("LEFT")
            UI:Skin(iconFrame, UI.palette.track, UI.palette.border)
            local tex = iconFrame:CreateTexture(nil, "ARTWORK")
            tex:SetPoint("TOPLEFT", 1, -1)
            tex:SetPoint("BOTTOMRIGHT", -1, 1)
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            b:SetIcon(tex)
            local bar = CreateFrame("StatusBar", nil, b)
            bar:SetPoint("LEFT", iconFrame, "RIGHT", 2, 0)
            bar:SetSize(bw - bh - 2, bh)
            UI:Skin(bar, UI.palette.track, UI.palette.border, bh >= 12 and "sm" or "xs")
            bar:SetStatusBarTexture(UI:BarTexture())
            bar:SetStatusBarColor(color[1], color[2], color[3])
            b:SetDurationBar(bar, { direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or 1 })
            local time = UI:Text(bar, 10, UI.palette.text, "OUTLINE")
            time:SetPoint("RIGHT", -4, 0)
            time:SetJustifyH("RIGHT")
            b:SetDurationText(time)
            local count = UI:Text(iconFrame, 11, UI.palette.text, "OUTLINE")
            count:SetPoint("BOTTOMRIGHT", 1, 0)
            b:SetApplicationCount(count)
            r.nativeBar = bar
        end,
        onBuilt = function() Db:Apply() end,
    })
    r:SetScript("OnUpdate", function() Db:DrawRow(r) end)
    rows[key] = r
    timers[key] = { start = 0, ends = 0 }
    r.native:Build()
    return r
end

function Db:DrawRow(r)
    local native = r.native:Active() and not NS.editing
    r.iconFrame:SetShown(not native)
    r.bar:SetShown(not native)
    if native then return end   -- the client draws it
    local t = timers[r.key]
    local left = t.ends - GetTime()
    if NS.editing and left <= 0 then
        r.bar:SetValue(0.6); r.time:SetText("7.2")
        return
    end
    if left <= 0 then
        r.bar:SetValue(0); r.time:SetText("")
        r.iconFrame:SetAlpha(0.35)
        return
    end
    r.iconFrame:SetAlpha(1)
    r.bar:SetValue(left / math.max(t.ends - t.start, 0.1))
    r.time:SetText(string.format("%.1f", left))
end

-- Correct the fallback timers from the real debuffs when the client lets us.
local function readTarget()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return end
    for key, t in pairs(timers) do
        local d = Spells:Get(key)
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "target", d.name, "HARMFUL|PLAYER")
        if ok and aura and not NS.IsSecret(aura) then
            local dur, exp = NS.Readable(aura.duration), NS.Readable(aura.expirationTime)
            if dur and exp and dur > 0 then
                NS.db.learned.durations[d.name] = dur
                t.start, t.ends = exp - dur, exp
            end
        elseif ok and not aura and not InCombatLockdown() then
            t.ends = 0   -- readable and gone (or a new target)
        end
    end
end

function Db:Init()
    frame = CreateFrame("Frame", "MageForeverDebuffs", UIParent)
    frame:SetSize(NS.db.debuffs.width, NS.db.debuffs.height)
    frame:Hide()
    UI:NativeHost(frame)
    self.frame = frame
    NS.Movers:Register(frame, "debuffs", "Target debuffs", NS.Layout.For("debuffs"))   -- grows down

    for _, sp in ipairs(NS.SPECS) do
        for _, key in ipairs(list(sp.key)) do
            if not rows[key] then buildRow(key) end
        end
    end

    NS:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, _, spellID)
        local cast = Spells:KeyFor(spellID)
        if not cast then return end
        for key, t in pairs(timers) do
            local d = Spells:Get(key)
            if key == cast or d.from == cast then
                t.start = GetTime()
                t.ends = t.start + duration(key)
                rows[key].iconFrame.icon:SetTexture(d.icon)
                rows[key].native:Refresh()
            end
        end
    end)
    NS:OnUnit("UNIT_AURA", "target", readTarget)
    NS:On("PLAYER_TARGET_CHANGED", function()
        for key, t in pairs(timers) do t.ends = 0 end
        readTarget()
        for _, r in pairs(rows) do r.native:Refresh() end
    end)
    NS:On("MF_SPEC", function() self:Apply() end)
    NS:On("MF_SPELLS", function() self:Apply() end)
end

function Db:Apply()
    if not frame then return end
    local db = NS.db.debuffs
    local on = NS:IsEnabled("debuffs")
    local active = {}
    for _, key in ipairs(list()) do
        if rows[key] and Spells:DebuffShown(key) then active[key] = true end   -- rows may still be building
    end
    local y, n = 0, 0
    for _, key in ipairs(list()) do
        if active[key] then
            local r = rows[key]
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
            y = y + db.height + GAP
            n = n + 1
        end
    end
    NS.AfterCombat("debuffsize", function() frame:SetSize(db.width, math.max(y - GAP, db.height)) end)
    UI:SafeShow(frame, on and n > 0)
    for key, r in pairs(rows) do
        local d = Spells:Get(key)
        r.iconFrame.icon:SetTexture(d.icon)
        r:SetSize(db.width, db.height)
        r.iconFrame:SetSize(db.height, db.height)
        r.bar:SetSize(db.width - db.height - 2, db.height)
        UI:SafeShow(r, on and active[key] or false)
        r.native:Restyle(function(b)
            b:SetSize(db.width, db.height)
            if r.nativeBar then r.nativeBar:SetSize(db.width - db.height - 2, db.height) end
        end)
    end
end

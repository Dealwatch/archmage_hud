--[[
    ArchmageHUD - cast bar
    Your casts and channels in the HUD column, right under the mana bar: spell
    name left, time left on the right, in a calm neutral colour (channels drain).
    Only shown while you cast (also out of combat, e.g. Teleport), red for a
    moment when a cast is interrupted.

    Times come from UnitCastingInfo / UnitChannelInfo. When they are readable
    the bar runs on our numbers (channels drain). When the client makes them
    secret they go straight into SetMinMaxValues / SetValue, which take secrets
    from addons: the bar still fills, only the time text is left out.
    (StatusBar:SetTimerDuration takes secret durations only from Blizzard code.)
]]

local _, NS = ...
local UI = NS.UI

local Cb = NS:NewModule("castbar", {
    title = "Cast Bar",
    desc = "Your casts and channels in the HUD column",
    icon = "Interface\\Icons\\Spell_Fire_FlameBolt",
})

local frame, bar
local cast = {}          -- { channel, start, ends (seconds, readable) or secret = true }
local failUntil = 0
local COLOR = { 0.80, 0.83, 0.88 }   -- calm neutral: the coloured signals (stacks, procs, debuffs) stay in front
local lastEnd = 0        -- STOP can arrive before INTERRUPTED: a cast that just ended can still turn red

local function readInfo()
    local name, _, _, startMS, endMS = NS.Try(UnitCastingInfo, "player")
    local channel = false
    if name == nil then
        name, _, _, startMS, endMS = NS.Try(UnitChannelInfo, "player")
        channel = true
    end
    if name == nil then return nil end
    return name, startMS, endMS, channel
end

function Cb:Start()
    local name, startMS, endMS, channel = readInfo()
    if name == nil then return self:Stop() end
    failUntil = 0
    wipe(cast)
    cast.channel = channel
    local s, e = NS.Readable(startMS), NS.Readable(endMS)
    Cb.lastMode = (s and e and "readable" or "secret") .. (InCombatLockdown() and " (in combat)" or " (out of combat)")
    if s and e then
        cast.start, cast.ends = s / 1000, e / 1000
        bar:SetMinMaxValues(0, math.max(cast.ends - cast.start, 0.01))
    else
        cast.secret = true
        pcall(bar.SetMinMaxValues, bar, startMS, endMS)   -- secret values are fine here
    end
    bar:SetStatusBarColor(COLOR[1], COLOR[2], COLOR[3])
    bar.name:SetText(name)                                 -- SetText takes a secret name too
    bar.time:SetText("")
    frame:Show()
    self:OnUpdate()
end

function Cb:Stop(failed)
    if failed then
        -- a spell pressed while casting also fails; the cast that is still running is fine
        if readInfo() ~= nil then return end
        if not (cast.start or cast.secret or GetTime() - lastEnd < 0.3) then return end
        bar:SetStatusBarColor(UI.palette.danger[1], UI.palette.danger[2], UI.palette.danger[3])
        bar.name:SetText(failed)
        bar.time:SetText("")
        failUntil = GetTime() + 0.6
        if not cast.secret then bar:SetValue(select(2, bar:GetMinMaxValues())) end
        wipe(cast)
        frame:Show()
        C_Timer.After(0.65, function() if GetTime() >= failUntil and not cast.start and not cast.secret then Cb:Draw() end end)
        return
    end
    if cast.start or cast.secret then lastEnd = GetTime() end
    wipe(cast)
    self:Draw()
end

function Cb:OnUpdate()
    if cast.secret then
        pcall(bar.SetValue, bar, GetTime() * 1000)        -- min/max are the secret start/end in ms
    elseif cast.start then
        local now = GetTime()
        local total = cast.ends - cast.start
        local left = math.max(cast.ends - now, 0)
        bar:SetValue(cast.channel and left or math.min(now - cast.start, total))
        bar.time:SetText(NS.db.castbar.showTime and string.format("%.1f", left) or "")
    end
end

function Cb:Draw()
    local busy = cast.start or cast.secret or GetTime() < failUntil
    local preview = NS.editing and not busy
    if preview then
        bar:SetMinMaxValues(0, 1); bar:SetValue(0.6)
        bar:SetStatusBarColor(COLOR[1], COLOR[2], COLOR[3])
        bar.name:SetText("Pyroblast"); bar.time:SetText(NS.db.castbar.showTime and "2.4" or "")
    end
    frame:SetShown(NS:IsEnabled("castbar") and (busy or preview) and true or false)
end

-- Blizzard's own player cast bar: switched off while ours is on (no second bar)
-- (modern name PlayerCastingBarFrame with :SetUnit, classic CastingBarFrame with CastingBarFrame_SetUnit)
local function blizzardBar(hide)
    local f = _G.PlayerCastingBarFrame or _G.CastingBarFrame
    local setUnit = f and (f.SetUnit or _G.CastingBarFrame_SetUnit)
    if not setUnit then return end
    NS.AfterCombat("blizzcastbar", function()
        if hide then pcall(setUnit, f, nil) else pcall(setUnit, f, "player", true, false) end
    end)
end

function Cb:Init()
    local db = NS.db.castbar
    frame = CreateFrame("Frame", "ArchmageHUDCastbar", UIParent)
    frame:SetSize(db.width, db.height)
    frame:Hide()
    self.frame = frame
    bar = UI:Bar(frame, db.width, db.height)
    bar:SetAllPoints()
    self.bar = bar
    bar.name = UI:Text(bar, 11, UI.palette.text, "OUTLINE")
    bar.name:SetPoint("LEFT", 5, 0)
    bar.name:SetWidth(db.width - 50)
    bar.time = UI:Text(bar, 11, UI.palette.text, "OUTLINE")
    bar.time:SetPoint("RIGHT", -5, 0)
    bar.time:SetJustifyH("RIGHT")
    -- outside the fading HUD root: casts out of combat (Teleport, conjures) show too
    NS.Movers:Register(frame, "castbar", "Cast bar", NS.Layout.For("castbar"), true)
    frame:SetScript("OnUpdate", function() Cb:OnUpdate() end)

    local function start() self:Start() end
    for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE" }) do
        NS:OnUnit(e, "player", start)
    end
    NS:OnUnit("UNIT_SPELLCAST_STOP", "player", function() if not cast.channel then self:Stop() end end)
    NS:OnUnit("UNIT_SPELLCAST_CHANNEL_STOP", "player", function() self:Stop() end)
    NS:OnUnit("UNIT_SPELLCAST_INTERRUPTED", "player", function() self:Stop("Interrupted") end)
    NS:OnUnit("UNIT_SPELLCAST_FAILED", "player", function() self:Stop("Failed") end)
end

function Cb:Apply()
    if not frame then return end
    local db = NS.db.castbar
    NS.AfterCombat("castbarsize", function() frame:SetSize(db.width, db.height) end)
    bar.spark:SetHeight(db.height)
    bar.name:SetWidth(db.width - 50)
    blizzardBar(NS:IsEnabled("castbar") and db.hideBlizzard)
    self:Draw()
end

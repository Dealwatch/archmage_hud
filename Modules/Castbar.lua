--[[
    ArchmageHUD - cast bar
    Your casts and channels in the HUD column, right under the mana bar: spell
    name left, time left on the right, in a calm neutral colour (channels
    drain). Only shown while you cast (also out of combat, e.g. Teleport); a
    finished cast stays full for a moment, an interrupted one turns red.

    Fill, best first:
      1. the client's duration object (UnitCastingDuration / UnitChannelDuration
         -> StatusBar:SetTimerDuration): runs even when the times are secret;
         the API may refuse a secret one from addon code, so it is only tried
      2. readable UnitCastingInfo times: we fill it ourselves
      3. secret times: they go into SetMinMaxValues / SetValue, which take
         secrets from addons, so the bar still fills (no time text)
    Never compare a value that may be secret: only a readable nil means "no cast".
]]

local _, NS = ...
local UI = NS.UI

local Cb = NS:NewModule("castbar", {
    title = "Cast Bar",
    desc = "Your casts and channels in the HUD column",
    icon = "Interface\\Icons\\Spell_Fire_FlameBolt",
})

local COLOR = { 0.80, 0.83, 0.88 }   -- calm neutral: the coloured signals (stacks, procs, debuffs) stay in front
local HOLD_DONE, HOLD_FAIL = 0.3, 0.8

local frame, bar
-- mode: "native" | "readable" | "secret"; guid: castGUID of the start event (own cast events are not secret)
local state = { active = false, channel = false, holdUntil = 0 }
Cb.state = state

local function colour(c) bar:SetStatusBarColor(c[1], c[2], c[3]) end

local function begin(channel, guid)
    local info = channel and UnitChannelInfo or UnitCastingInfo
    local name, _, _, startMS, endMS = NS.Try(info, "player")
    if not NS.IsSecret(name) and name == nil then return false end
    wipe(state)
    state.active, state.channel, state.guid, state.holdUntil = true, channel, guid, 0
    local s, e = NS.Readable(startMS), NS.Readable(endMS)
    state.startT, state.endT = s and s / 1000, e and e / 1000

    local durFn = channel and _G.UnitChannelDuration or _G.UnitCastingDuration
    local Dir = Enum.StatusBarTimerDirection
    if durFn and bar.SetTimerDuration and Dir and pcall(function()
        bar:SetTimerDuration(durFn("player"), Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0,
            channel and Dir.RemainingTime or Dir.ElapsedTime)
    end) then
        state.mode = "native"
    elseif state.startT and state.endT then
        state.mode = "readable"
        bar:SetMinMaxValues(state.startT, state.endT)
    else
        state.mode = "secret"
        pcall(bar.SetMinMaxValues, bar, startMS, endMS)   -- secret ms values are fine here
    end
    Cb.lastMode = state.mode .. (InCombatLockdown() and " (in combat)" or " (out of combat)")
    colour(COLOR)
    bar.name:SetText(name)                                  -- SetText takes a secret name too
    bar.time:SetText("")
    Cb:OnUpdate()
    Cb:Draw()
    return true
end

local function finish(failed, guid)
    if not state.active and state.holdUntil == 0 then return end
    -- "failed" also fires for a spell pressed while casting: only the running cast counts
    if failed and not state.channel and guid and state.guid and guid ~= state.guid then return end
    if state.failed then return end                         -- interrupted and failed both fire: the first stays
    state.active = false
    if failed then
        state.failed = true
        colour(UI.palette.danger)
        bar.name:SetText(failed)
        state.holdUntil = GetTime() + HOLD_FAIL
    elseif state.holdUntil == 0 then
        state.holdUntil = GetTime() + HOLD_DONE
    end
    -- full bar for the moment it stays up
    if bar.SetToTargetValue then pcall(bar.SetToTargetValue, bar) end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar.time:SetText("")
    Cb:Draw()
end

function Cb:OnUpdate()
    local now = GetTime()
    if state.active then
        if state.mode == "readable" then
            bar:SetValue(state.channel and (state.endT - now + state.startT) or now)
        elseif state.mode == "secret" then
            pcall(bar.SetValue, bar, now * 1000)           -- min/max are the secret start/end in ms
        end
        local left = state.endT and state.endT - now
        bar.time:SetText(NS.db.castbar.showTime and left and left > 0 and string.format("%.1f", left) or "")
    elseif state.holdUntil > 0 and now >= state.holdUntil then
        wipe(state)
        state.holdUntil = 0
        self:Draw()
    end
end

function Cb:Draw()
    local busy = state.active or state.holdUntil > 0
    local preview = NS.editing and not busy
    if preview then
        bar:SetMinMaxValues(0, 1); bar:SetValue(0.6)
        colour(COLOR)
        bar.name:SetText("Pyroblast"); bar.time:SetText(NS.db.castbar.showTime and "2.4" or "")
    end
    frame:SetShown(NS:IsEnabled("castbar") and (busy or preview) and true or false)
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

    NS:OnUnit("UNIT_SPELLCAST_START", "player", function(_, _, guid) begin(false, guid) end)
    NS:OnUnit("UNIT_SPELLCAST_DELAYED", "player", function() if state.active and not state.channel then begin(false, state.guid) end end)
    NS:OnUnit("UNIT_SPELLCAST_CHANNEL_START", "player", function(_, _, guid) begin(true, guid) end)
    NS:OnUnit("UNIT_SPELLCAST_CHANNEL_UPDATE", "player", function() if state.active and state.channel then begin(true, state.guid) end end)
    NS:OnUnit("UNIT_SPELLCAST_STOP", "player", function() if not state.channel then finish(nil) end end)
    NS:OnUnit("UNIT_SPELLCAST_CHANNEL_STOP", "player", function() if state.channel then finish(nil) end end)
    NS:OnUnit("UNIT_SPELLCAST_INTERRUPTED", "player", function(_, _, guid) finish("Interrupted", guid) end)
    -- not for channels: a spell pressed during Arcane Missiles fails too, and a channel has no castGUID to tell them apart
    NS:OnUnit("UNIT_SPELLCAST_FAILED", "player", function(_, _, guid) if not state.channel then finish("Failed", guid) end end)
    -- after a /reload or a loading screen in the middle of a cast
    NS:On("PLAYER_ENTERING_WORLD", function() if not begin(false) then begin(true) end end)
end

-- Blizzard's own player cast bar: switched off while ours is on, with C-side calls only
-- (UnregisterAllEvents + Hide), so Blizzard's Lua state stays untouched (no taint).
-- Bringing it back needs a /reload.
local warned
function Cb:Apply()
    if not frame then return end
    local db = NS.db.castbar
    NS.AfterCombat("castbarsize", function() frame:SetSize(db.width, db.height) end)
    bar.spark:SetHeight(db.height)
    bar.name:SetWidth(db.width - 50)
    local b = _G.PlayerCastingBarFrame or _G.CastingBarFrame
    if b then
        if NS:IsEnabled("castbar") and db.hideBlizzard then
            NS.AfterCombat("blizzcastbar", function() b:UnregisterAllEvents(); b:Hide() end)
            self.blizzardHidden = true
        elseif self.blizzardHidden and not warned then
            warned = true
            NS.Print("type /reload to bring Blizzard's cast bar back.")
        end
    end
    self:Draw()
end

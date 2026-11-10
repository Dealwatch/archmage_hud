--[[
    ArchmageHUD - opener
    The first casts of a fight for your spec (Spells.SPEC_DATA[spec].opener),
    in the place of the proc card: there before the pull, each icon dims when
    you have cast it, the next one glows gold, and the strip is gone once the
    opener is through. While the proc card shows it steps aside: the card
    names the cast of this moment. It only follows your own casts (never
    secret) and a fixed list: it shows a plan, it does not read the fight.
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local Op = NS:NewModule("opener", {
    title = "Opener",
    desc = "Your first casts before the pull, ticked off as you cast",
    icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
})

local SIZE, GAP = 26, 8     -- the gap leaves room for the glow of the next icon
local STALE = 20            -- seconds into a fight after which an unfinished opener goes away
local frame
local icons = {}
local state = { step = 1, started = nil }
Op.state = state

-- the spells of the opener that you know, in order
local function list()
    local out = {}
    for _, key in ipairs(Spells.SPEC_DATA[NS.spec].opener or {}) do
        local d = Spells:Get(key)
        if d and d.known then out[#out + 1] = d end
    end
    return out
end

function Op:Draw()
    if not frame then return end
    local l = list()
    local card = _G.ArchmageHUDProcCard
    local running = state.step <= #l and (not state.started or GetTime() - state.started < STALE)
    local show = NS:IsEnabled("opener") and running and not NS.editing and not (card and card:IsShown())
    frame:SetShown(show and true or false)
    if not show then return end
    for i, f in ipairs(icons) do
        local d = l[i]
        f:SetShown(d ~= nil)
        if d then
            f.icon:SetTexture(d.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            f:SetAlpha(i < state.step and 0.3 or 1)
            f.icon:SetDesaturated(i < state.step)
            if i == state.step then UI:Glow(f, 1, 0.82, 0.25) else UI:Glow(f) end   -- gold: cast this
        end
    end
    frame:SetSize(#l * (SIZE + GAP) - GAP, SIZE)
end

local function reset() state.step, state.started = 1, nil; Op:Draw() end

function Op:Init()
    frame = CreateFrame("Frame", "ArchmageHUDOpener", UI.root)
    frame:SetSize(SIZE, SIZE)
    frame:SetPoint("CENTER", _G.ArchmageHUDProcCard, "CENTER")   -- moves (and scales) with the proc card
    frame:Hide()
    UI:RegisterHUD(frame)
    self.frame = frame
    for i = 1, 5 do
        icons[i] = UI:Icon(frame, SIZE)
        icons[i]:SetPoint("LEFT", frame, "LEFT", (i - 1) * (SIZE + GAP), 0)
    end

    NS:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, _, spellID)
        local next = list()[state.step]
        if next and Spells:KeyFor(spellID) == next.key then state.step = state.step + 1; self:Draw() end
    end)
    NS:On("PLAYER_REGEN_DISABLED", function()
        state.started = GetTime()
        C_Timer.After(STALE + 0.1, function() self:Draw() end)
    end)
    NS:On("PLAYER_REGEN_ENABLED", reset)
    NS:On("PLAYER_TARGET_CHANGED", function() if NS.InCombat() then self:Draw() else reset() end end)
    NS:On("MF_SPEC", reset)
    NS:On("MF_SPELLS", reset)
end

function Op:Apply() self:Draw() end

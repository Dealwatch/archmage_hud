--[[
    ArchmageHUD - procs
      * One centred row that shows only what is up right now: the procs and
        burst buffs of your spec (Spells.SPEC_DATA[spec].procs), each with its
        time-left swipe and stacks. The client fills the row itself (native
        aura group), so it works while the buffs are secret in combat.
      * A big card ("Pyroblast!") while the client lights up one of your
        spells (spell activation overlay: Heating Up, Missile Barrage, ... -
        never secret), with an optional sound.
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local Procs = NS:NewModule("procs", {
    title = "Procs",
    desc = "Active procs, big card for instant casts",
    icon = "Interface\\Icons\\Spell_Shadow_ManaBurn",
})

local GOLD = { 1, 0.82, 0.25 }
local frame, card
local hosts = {}        -- spec -> { frame, native }
local preview = {}
local lit = {}          -- spellID -> true while the client glows it

local function buildHost(spec, size)
    local host = CreateFrame("Frame", nil, frame)
    host:SetAllPoints()
    host:Hide()
    UI:NativeHost(host)
    local h = { frame = host }
    h.native = NS.Native:Slot({
        key = "procs_" .. spec, parent = host, unit = "player", filter = "HELPFUL", level = 3,
        group = { size = size, spacing = 4 },
        ids = function() return Spells:AuraIDs(unpack(Spells.SPEC_DATA[spec].procs)) end,
        init = function(b)
            b:SetSize(NS.db.procs.size, NS.db.procs.size)
            UI:Skin(b, UI.palette.track, UI.palette.border)
            local tex = b:CreateTexture(nil, "ARTWORK")
            tex:SetPoint("TOPLEFT", 1, -1)
            tex:SetPoint("BOTTOMRIGHT", -1, 1)
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            b:SetIcon(tex)
            local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
            cd:SetAllPoints(tex)
            cd:SetDrawEdge(false)
            cd:SetReverse(true)
            cd:SetHideCountdownNumbers(true)
            b:SetDurationCooldown(cd)
            local count = UI:Text(b, 13, UI.palette.text, "OUTLINE")
            count:SetPoint("BOTTOMRIGHT", -2, 2)
            b:SetApplicationCount(count)
        end,
        onBuilt = function() Procs:Apply() end,
    })
    hosts[spec] = h
    h.native:Build()
end

local function buildCard()
    card = CreateFrame("Frame", "ArchmageHUDProcCard", UIParent)
    card:SetSize(190, 40)
    UI:Skin(card, UI.palette.surface, UI.palette.border, "lg")
    card.iconFrame = UI:Icon(card, 32)
    card.iconFrame:SetPoint("LEFT", 4, 0)
    card.text = UI:Text(card, 15, { GOLD[1], GOLD[2], GOLD[3], 1 }, "OUTLINE")
    card.text:SetPoint("LEFT", card.iconFrame, "RIGHT", 8, 0)
    card:Hide()
    NS.Movers:Register(card, "proccard", "Proc card", NS.Layout.For("proccard"))
end

-- The newest lit spell we know, shown on the card (else any other still lit).
local newest
function Procs:DrawCard()
    local db = NS.db.procs
    local def = newest and lit[newest] and Spells:Get(Spells:KeyFor(newest))
    if not def then
        for id in pairs(lit) do
            local key = Spells:KeyFor(id)
            if key then def = Spells:Get(key) end
        end
    end
    if NS.editing and not def then def = Spells:Get(Spells.SPEC_DATA[NS.spec].card or "fireball") end
    local show = NS:IsEnabled("procs") and db.card and def ~= nil
    card:SetShown(show and true or false)
    if not show then UI:Glow(card.iconFrame) return end
    card.iconFrame.icon:SetTexture(def.icon)
    card.text:SetText((def.name or def.en) .. "!")
    card:SetWidth(4 + 32 + 8 + card.text:GetStringWidth() + 12)   -- hugs the name: any length fits, and it stays centred
    UI:Glow(card.iconFrame, GOLD[1], GOLD[2], GOLD[3])
end

function Procs:Init()
    local size = NS.db.procs.size
    frame = CreateFrame("Frame", "ArchmageHUDProcs", UIParent)
    frame:SetSize(4 * size + 12, size)
    frame:Hide()
    UI:NativeHost(frame)
    self.frame = frame

    -- edit-mode preview only
    for i = 1, 3 do
        local f = UI:Icon(frame, size)
        f:SetPoint("CENTER", frame, "CENTER", (i - 2) * (size + 4), 0)
        f.icon:SetTexture(({ "Interface\\Icons\\Spell_Shadow_ManaBurn", "Interface\\Icons\\Spell_Nature_EnchantArmor",
            "Interface\\Icons\\Spell_Fire_SealOfFire" })[i])
        f:Hide()
        preview[i] = f
    end
    NS.Movers:Register(frame, "procs", "Procs", NS.Layout.For("procs"))
    buildCard()

    for _, sp in ipairs(NS.SPECS) do buildHost(sp.key, size) end

    NS:On("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", function(_, spellID)
        if not spellID or NS.IsSecret(spellID) or not Spells:KeyFor(spellID) then return end
        if not lit[spellID] and NS:IsEnabled("procs") and NS.db.procs.card and NS.db.procs.sound then
            UI:Sound("ALARM_CLOCK_WARNING_3")
        end
        lit[spellID] = true
        newest = spellID
        self:DrawCard()
    end)
    NS:On("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", function(_, spellID)
        if spellID and not NS.IsSecret(spellID) then lit[spellID] = nil else wipe(lit) end
        self:DrawCard()
    end)
    NS:On("MF_SPEC", function() self:Apply() end)
end

function Procs:Apply()
    if not frame then return end
    local on = NS:IsEnabled("procs")
    UI:SafeShow(frame, on)
    for spec, h in pairs(hosts) do UI:SafeShow(h.frame, on and spec == NS.spec and not NS.editing) end
    for _, f in ipairs(preview) do f:SetShown(on and NS.editing or false) end
    -- icon size, live: our frames, then the rows the client lays out
    local size = NS.db.procs.size
    NS.AfterCombat("procslayout", function()
        frame:SetSize(4 * size + 12, size)
        for i, f in ipairs(preview) do
            f:SetSize(size, size)
            f:SetPoint("CENTER", frame, "CENTER", (i - 2) * (size + 4), 0)
        end
    end)
    for spec, h in pairs(hosts) do
        if h.native:Active() then
            h.native:Restyle(function(c)
                local key = "procs_" .. spec
                c:SetAuraGroupLayout(key, { elementSpacing = 4, elementWidth = size, elementHeight = size })
                for i = 1, c:GetAuraGroupFrameCount(key) or 0 do
                    local b = c:GetAuraGroupFrame(key, i)
                    if b then b:SetSize(size, size) end
                end
            end)
        end
    end
    self:DrawCard()
end

function Procs.Lit() return lit end

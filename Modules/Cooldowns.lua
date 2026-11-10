--[[
    ArchmageHUD - cooldown row
    One row of icons in two tiers: the cooldowns of your spec large, the ones
    every mage uses (Spells:CooldownsFor) small and dimmed beside them. Only
    spells you know are shown. An icon glows while the client lights up that
    spell (spell activation overlay, never secret).
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local Cd = NS:NewModule("cooldowns", {
    title = "Cooldowns",
    desc = "Spec cooldowns plus Blink, Counterspell, ...",
    icon = "Interface\\Icons\\Spell_Arcane_Blink",
})

local row
local icons = {}        -- key -> icon (created on first use)
local lit = {}          -- spellID -> true while the client glows it
local SHARED = { fireBlast = "iceLance", iceLance = "fireBlast" }   -- one 8 s cooldown on Forever

local function icon(key)
    local f = icons[key]
    if not f then
        f = UI:Icon(row, NS.db.cooldowns.size)
        f.cd = UI:Cooldown(f)
        f.key = key
        -- flash once when the cooldown that your own cast started runs out
        f.cd:SetScript("OnCooldownDone", function()
            if f.armed and NS.db.cooldowns.readyFlash and f:IsShown() then UI:Flash(f) end
            f.armed = false
        end)
        icons[key] = f
    end
    return f
end

function Cd:Update()
    if not row then return end
    local size = NS.db.cooldowns.size
    local want = {}
    local x = 0
    local rotation, utility = {}, false
    for _, key in ipairs(Spells.SPEC_DATA[NS.spec].cooldowns) do rotation[key] = true end
    local small = math.floor(size * 0.7 + 0.5)
    local atMana = NS:IsEnabled("mana") and NS.db.mana.tools   -- Evocation sits at the mana bar then
    for _, key in ipairs(Spells:CooldownsFor(NS.spec)) do
        local def = Spells:Get(key)
        if def and (def.known or (NS.editing and x == 0)) and not (key == "evocation" and atMana) then
            want[key] = true
            local f = icon(key)
            local s = rotation[key] and size or small
            if not rotation[key] and not utility then utility = true; if x > 0 then x = x + 6 end end   -- a little air between the tiers
            f:Show()
            f:SetSize(s, s)
            f:SetAlpha(rotation[key] and 1 or 0.75)
            f:ClearAllPoints()
            f:SetPoint("LEFT", row, "LEFT", x, 0)
            x = x + s + 4
            f.icon:SetTexture(def.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            UI:SpellCooldown(f.cd, def.id)
            local usable = true
            if C_Spell.IsSpellUsable then
                local ok, u = pcall(C_Spell.IsSpellUsable, def.id)
                if ok and NS.Readable(u) == false then usable = false end
            end
            f.icon:SetDesaturated(not usable)
            if lit[def.id] then UI:Glow(f, 1, 0.82, 0.25) else UI:Glow(f) end
        end
    end
    for key, f in pairs(icons) do if not want[key] then f:Hide() end end
    row:SetSize(math.max(x - 4, 1), size)
    row:SetShown(NS:IsEnabled("cooldowns") and x > 0 or false)
end

function Cd:Init()
    row = CreateFrame("Frame", "ArchmageHUDCooldowns", UIParent)
    row:SetSize(100, NS.db.cooldowns.size)
    row:Hide()
    self.frame = row
    NS.Movers:Register(row, "cooldowns", "Cooldowns", NS.Layout.For("cooldowns"))

    local function update() self:Update() end
    NS:On("SPELL_UPDATE_COOLDOWN", update)
    NS:On("SPELL_UPDATE_USABLE", update)
    NS:On("MF_SPELLS", update)
    NS:On("MF_SPEC", update)
    NS:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, _, spellID)
        local key = Spells:KeyFor(spellID)
        for _, k in ipairs({ key, key and SHARED[key] }) do
            if icons[k] then icons[k].armed = true end
        end
    end)
    NS:On("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", function(_, spellID)
        if spellID and not NS.IsSecret(spellID) then lit[spellID] = true; update() end
    end)
    NS:On("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", function(_, spellID)
        if spellID and not NS.IsSecret(spellID) then lit[spellID] = nil else wipe(lit) end
        update()
    end)
end

function Cd:Apply() self:Update() end

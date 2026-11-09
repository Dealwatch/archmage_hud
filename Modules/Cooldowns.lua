--[[
    MageForever - cooldown row
    One row of icons for the cooldowns of your spec plus the ones every mage
    uses (Spells:CooldownsFor). Only spells you know are shown.
    GetSpellCooldownDuration returns a duration object the cooldown swirl
    takes even when the numbers are secret. An icon glows while the client
    lights up that spell (spell activation overlay, never secret).
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local Cd = NS:NewModule("cooldowns", {
    title = "Cooldowns",
    desc = "Your spec's cooldowns plus Blink, Counterspell, Ice Block, ...",
    icon = "Interface\\Icons\\Spell_Arcane_Blink",
})

local row
local icons = {}        -- key -> icon (created on first use)
local lit = {}          -- spellID -> true while the client glows it

local function icon(key)
    local f = icons[key]
    if not f then
        f = UI:Icon(row, NS.db.cooldowns.size)
        f.cd = UI:Cooldown(f)
        f.key = key
        icons[key] = f
    end
    return f
end

local function setCooldown(f, def)
    if C_Spell.GetSpellCooldownDuration then
        local ok, d = pcall(C_Spell.GetSpellCooldownDuration, def.id, true)   -- true: ignore the GCD
        if ok and d and pcall(f.cd.SetCooldownFromDurationObject, f.cd, d, true) then return end
    end
    local ok, info = pcall(C_Spell.GetSpellCooldown, def.id)
    if ok and info then
        local start, dur = NS.Readable(info.startTime), NS.Readable(info.duration)
        if start and dur and dur > 1.5 then f.cd:SetCooldown(start, dur) else f.cd:Clear() end   -- 1.5: skip the GCD
    end
end

function Cd:Update()
    if not row then return end
    local size = NS.db.cooldowns.size
    local want = {}
    local x = 0
    for _, key in ipairs(Spells:CooldownsFor(NS.spec)) do
        local def = Spells:Get(key)
        if def and (def.known or (NS.editing and x == 0)) then
            want[key] = true
            local f = icon(key)
            f:Show()
            f:SetSize(size, size)
            f:ClearAllPoints()
            f:SetPoint("LEFT", row, "LEFT", x, 0)
            x = x + size + 4
            f.icon:SetTexture(def.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            setCooldown(f, def)
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
    row = CreateFrame("Frame", "MageForeverCooldowns", UIParent)
    row:SetSize(100, NS.db.cooldowns.size)
    row:Hide()
    self.frame = row
    NS.Movers:Register(row, "cooldowns", "Cooldowns", { "CENTER", "CENTER", 0, -222 })

    local function update() self:Update() end
    NS:On("SPELL_UPDATE_COOLDOWN", update)
    NS:On("SPELL_UPDATE_USABLE", update)
    NS:On("MF_SPELLS", update)
    NS:On("MF_SPEC", update)
    NS:On("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", function(_, spellID)
        if spellID and not NS.IsSecret(spellID) then lit[spellID] = true; update() end
    end)
    NS:On("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", function(_, spellID)
        if spellID and not NS.IsSecret(spellID) then lit[spellID] = nil else wipe(lit) end
        update()
    end)
end

function Cd:Apply() self:Update() end

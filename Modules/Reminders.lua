--[[
    MageForever - reminders
      * Arcane Intellect / Arcane Brilliance missing.
      * No armor spell up (Frost / Ice / Mage Armor, whichever you know).
      * Frost: Ice Barrier not up (guides: keep it up at all times).
      * No mana gem in your bags (when you can conjure one).
      * Low on Runes of Teleportation / Portals (when you know those spells).
      * Absorb icon: Ice Barrier or Mana Shield with time left, drawn by the
        client (native aura slot), also in combat.
    Buffs are secret in combat, so their state is the last readable answer,
    updated by your own casts and re-read the moment combat ends.
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local R = NS:NewModule("reminders", {
    title = "Reminders",
    desc = "Intellect, armor, mana gem, runes; absorb shield icon",
    icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
})

local BUFFS = {
    intellect = { keys = { "arcaneIntellect", "arcaneBrilliance" }, setting = "intellect" },
    armor     = { keys = { "mageArmor", "iceArmor", "frostArmor" }, setting = "armor" },
    barrier   = { keys = { "iceBarrier" }, setting = "barrier", spec = "frost" },
}
local state = {}        -- buff -> true / false / nil (unknown)
R.state = state

local function knownAny(keys)
    for _, k in ipairs(keys) do if Spells:Known(k) then return Spells:Get(k) end end
end

-- true / false, or nil when the client does not tell us right now.
local function readBuff(keys)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return nil end
    for _, k in ipairs(keys) do
        local d = Spells:Get(k)
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", d.name, "HELPFUL")
        if not ok or NS.IsSecret(aura) then return nil end
        if aura then return true end
    end
    -- "nothing" is only trustworthy when auras are not restricted right now
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, restricted = pcall(C_Secrets.ShouldAurasBeSecret)
        if not ok or NS.IsSecret(restricted) or restricted then return nil end
    elseif InCombatLockdown() then
        return nil
    end
    return false
end

local function itemCount(ids)
    local n = 0
    for _, id in ipairs(ids) do n = n + (NS.Try(C_Item and C_Item.GetItemCount, id) or 0) end
    return n
end

function R:Update()
    local db = NS.db.reminders
    local on = NS:IsEnabled("reminders")
    local inCombat = InCombatLockdown()
    local A = NS.Alerts
    local quiet = UnitIsDeadOrGhost("player") or IsMounted() or (inCombat and not db.inCombat)

    for name, b in pairs(BUFFS) do
        local read = readBuff(b.keys)
        if read ~= nil then state[name] = read end
        local def = knownAny(b.keys)
        if on and db[b.setting] and def and state[name] == false and not quiet and (not b.spec or b.spec == NS.spec) then
            A:Set(name, { title = "No " .. (def.name or def.en), text = "Rebuff yourself", icon = def.icon, priority = 4 })
        else
            A:Clear(name)
        end
    end

    -- mana gem: any rank in the bags
    local gemSpell = knownAny({ "conjureGem" })
    R.gems = itemCount(Spells.MANA_GEMS)
    if on and db.gem and gemSpell and not inCombat and R.gems == 0 and not quiet then
        A:Set("gem", { title = "No mana gem", text = "Conjure one before the pull", icon = gemSpell.icon, priority = 3 })
    else
        A:Clear("gem")
    end

    -- teleport / portal runes
    local tele, portal = Spells:KnownAny("teleport"), Spells:KnownAny("portal")
    local runeT, runeP = NS.Try(C_Item and C_Item.GetItemCount, Spells.RUNE_TELEPORT) or 0, NS.Try(C_Item and C_Item.GetItemCount, Spells.RUNE_PORTALS) or 0
    R.runes = runeT .. "/" .. runeP
    local low = (tele and runeT < db.reagentMin and "Teleportation") or (portal and runeP < db.reagentMin and "Portals")
    if on and db.reagents and low and not inCombat then
        A:Set("runes", { title = "Low on Runes of " .. low, text = "Buy more at a reagent vendor", icon = "Interface\\Icons\\INV_Misc_Rune_06", priority = 1 })
    else
        A:Clear("runes")
    end
end

-- Absorb icon: the client shows your Ice Barrier / Mana Shield with time
-- left, even in combat; our own dimmed icon underneath means "none up".
function R:BuildAbsorb()
    local size = NS.db.reminders.absorbSize
    local f = UI:Icon(UIParent, size)
    f:Hide()
    UI:NativeHost(f)
    f.icon:SetDesaturated(true)
    f.icon:SetAlpha(0.35)
    self.absorbFrame = f
    NS.Movers:Register(f, "absorb", "Absorb", { "CENTER", "CENTER", -140, -134 })   -- left of the column
    self.absorbNative = NS.Native:Slot({
        key = "absorb", parent = f, unit = "player", filter = "HELPFUL", level = 3,
        ids = function() return Spells:AuraIDs("iceBarrier", "manaShield") end,
        init = function(b)
            b:SetSize(NS.db.reminders.absorbSize, NS.db.reminders.absorbSize)
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
            cd:SetHideCountdownNumbers(false)
            b:SetDurationCooldown(cd)
        end,
        onBuilt = function() R:Apply() end,
    })
    self.absorbNative:Build()
end

function R:DrawAbsorb()
    local f = self.absorbFrame
    if not f then return end
    local db = NS.db.reminders
    local def = knownAny({ "iceBarrier", "manaShield" })
    local show = NS:IsEnabled("reminders") and db.absorbIcon and (def or NS.editing) and true or false
    UI:SafeShow(f, show)
    if not show then return end
    f.icon:SetTexture(def and def.icon or "Interface\\Icons\\Spell_Ice_Lament")
    f:SetSize(db.absorbSize, db.absorbSize)
    if self.absorbNative:Active() then
        self.absorbNative:Restyle(function(b) b:SetSize(db.absorbSize, db.absorbSize) end)
    end
end

function R:Init()
    self:BuildAbsorb()
    local function update() self:Update() end
    NS:OnUnit("UNIT_AURA", "player", update)
    NS:On("PLAYER_REGEN_DISABLED", update)
    NS:On("PLAYER_REGEN_ENABLED", update)
    NS:On("BAG_UPDATE_DELAYED", update)
    NS:On("PLAYER_ENTERING_WORLD", update)
    NS:On("PLAYER_MOUNT_DISPLAY_CHANGED", update)
    NS:On("PLAYER_DEAD", update)
    NS:On("PLAYER_ALIVE", update)
    NS:On("PLAYER_UNGHOST", update)
    NS:On("MF_SPELLS", function() self:Apply() end)
    NS:On("MF_SPEC", update)
    NS:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, _, spellID)
        local key = Spells:KeyFor(spellID)
        if not key then return end
        for name, b in pairs(BUFFS) do
            for _, k in ipairs(b.keys) do if k == key then state[name] = true end end
        end
        update()
    end)
end

function R:Apply() self:Update(); self:DrawAbsorb() end

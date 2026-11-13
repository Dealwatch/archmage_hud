--[[
    ArchmageHUD - reminders
      * Arcane Intellect / Arcane Brilliance missing.
      * No armor spell up (Frost / Ice / Mage Armor, whichever you know).
      * Frost: Ice Barrier not up (guides: keep it up at all times).
      * No mana gem in your bags (when you can conjure one).
      * Low on Runes of Teleportation / Portals (when you know those spells).
      * Ready check: one card, "All set" or the consumables that are missing
        (weapon oil, mana potions, conjured water).
      * Absorb icon: Ice Barrier or Mana Shield with time left, drawn by the
        client (native aura slot), also in combat.
    Buffs are secret in combat, so their state is the last readable answer,
    updated by your own casts and re-read the moment combat ends.
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local R = NS:NewModule("reminders", {
    title = "Reminders",
    desc = "Intellect, armor, mana gem, runes, absorb icon",
    icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
})

local BUFFS = {
    intellect = { keys = { "arcaneIntellect", "arcaneBrilliance" }, setting = "intellect" },
    armor     = { keys = { "mageArmor", "iceArmor", "frostArmor" }, setting = "armor" },
    barrier   = { keys = { "iceBarrier" }, setting = "barrier", spec = "frost" },
}
local state = {}        -- buff -> true / false / nil (unknown)
R.state = state
local ready, readyN = false, 0   -- a ready check runs; its number, so an old timer never ends a newer check
local READY_ICON = "Interface\\Icons\\INV_Potion_76"

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

function R:Update()
    local db = NS.db.reminders
    local on = NS:IsEnabled("reminders")
    local inCombat = NS.InCombat()
    local A = NS.Alerts
    local quiet = UnitIsDeadOrGhost("player") or IsMounted() or (inCombat and not db.inCombat)

    for name, b in pairs(BUFFS) do
        local read = readBuff(b.keys)
        if read ~= nil then state[name] = read
        elseif not InCombatLockdown() then state[name] = nil end   -- secret out of combat (BG, encounter): unknown
        local def = knownAny(b.keys)
        if on and db[b.setting] and def and state[name] == false and not quiet and (not b.spec or b.spec == NS.spec) then
            A:Set(name, { title = "No " .. (def.name or def.en), text = "Rebuff yourself", icon = def.icon, priority = 4 })
        else
            A:Clear(name)
        end
    end

    -- mana gem: any rank in the bags
    local gemSpell = knownAny({ "conjureGem" })
    R.gems = Spells.ItemCount(Spells.MANA_GEMS)
    if on and db.gem and gemSpell and not inCombat and R.gems == 0 and not quiet then
        A:Set("gem", { title = "No mana gem", text = "Conjure one before the pull", icon = gemSpell.icon, priority = 3 })
    else
        A:Clear("gem")
    end

    -- teleport / portal runes
    local tele, portal = Spells:KnownAny("teleport"), Spells:KnownAny("portal")
    local runeT, runeP = NS.Try(C_Item and C_Item.GetItemCount, Spells.RUNE_TELEPORT) or 0, NS.Try(C_Item and C_Item.GetItemCount, Spells.RUNE_PORTALS) or 0
    R.runes = runeT .. "/" .. runeP
    local low = (tele and runeT < db.reagentMin and "teleport") or (portal and runeP < db.reagentMin and "portal")
    if on and db.reagents and low and not inCombat then
        A:Set("runes", { title = "Low on " .. low .. " runes", text = "Buy more at a reagent vendor", icon = "Interface\\Icons\\INV_Misc_Rune_06", priority = 1 })
    else
        A:Clear("runes")
    end

    -- ready check: what the cards above do not cover, or "All set" when nothing is missing at all
    A:Clear("ready")
    if on and db.ready and ready and not inCombat then
        local miss = {}
        if GetWeaponEnchantInfo and not GetWeaponEnchantInfo() then miss[#miss + 1] = "oil" end
        if Spells.ItemCount(Spells.MANA_POTIONS) == 0 then miss[#miss + 1] = "potions" end
        if Spells.ItemCount(Spells.WATER) == 0 then miss[#miss + 1] = "water" end
        if #miss > 0 then
            A:Set("ready", { title = "Ready check", text = "Missing: " .. table.concat(miss, ", "), icon = READY_ICON, priority = 9 })
        elseif not (A.active.intellect or A.active.armor or A.active.barrier or A.active.gem) then
            A:Set("ready", { title = "Ready check", text = "All set", icon = READY_ICON, color = UI.palette.good, priority = 9 })
        end
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
    -- The client covers this icon with the live Ice Barrier / Mana Shield and its visibility
    -- is secret to us, so whatever shows through is the in-combat "no barrier" alert.
    local ag = f.icon:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0.9)
    a:SetToAlpha(0.3)
    a:SetDuration(0.6)
    f.pulse = ag
    self.absorbFrame = f
    NS.Movers:Register(f, "absorb", "Absorb", NS.Layout.For("absorb"))   -- left of the stack bar
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
            local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
            cd:SetPoint("TOPLEFT", 1, -1)
            cd:SetPoint("BOTTOMRIGHT", -1, 1)
            cd:SetDrawEdge(false)
            cd:SetReverse(true)
            cd:SetHideCountdownNumbers(false)
            -- handed over last: icon and swirl are the client's from here on (see NS.Attempt)
            b:SetIcon(tex)
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
    NS.AfterCombat("absorbSize", function() f:SetSize(db.absorbSize, db.absorbSize) end)
    if self.absorbNative:Active() then
        self.absorbNative:Restyle(function(b) b:SetSize(db.absorbSize, db.absorbSize) end)
    end
    local warn = NS.spec == "frost" and db.barrier and Spells:Known("iceBarrier") and self.absorbNative:Active()
    local c = warn and UI.palette.danger or UI.palette.border
    UI:SetBorderColor(f, c[1], c[2], c[3], 1)
    if warn then f.pulse:Play() else f.pulse:Stop() end
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
    NS:On("MF_SPEC", function() self:Apply() end)
    NS:On("READY_CHECK", function()
        ready, readyN = true, readyN + 1
        local mine = readyN
        update()
        C_Timer.After(35, function() if readyN == mine then ready = false; update() end end)   -- if "finished" never arrives
    end)
    NS:On("READY_CHECK_FINISHED", function() ready, readyN = false, readyN + 1; update() end)
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

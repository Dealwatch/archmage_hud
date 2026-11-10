--[[
    ArchmageHUD - diagnostics
    /mage probe   what the client lets addons read right now (run it once out
                  of combat and once in combat while hitting something)
    /mage spells  every spell in your spellbook with its ID
    Both open a copy box and are also saved in the SavedVariables file
    (WTF\Account\<account>\SavedVariables\ArchmageHUD.lua).
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local box

local function copyBox(title, text)
    if not box then
        box = CreateFrame("Frame", "ArchmageHUDCopy", UIParent)
        box:SetSize(640, 460)
        box:SetPoint("CENTER")
        box:SetFrameStrata("DIALOG")
        box:EnableMouse(true)
        box:SetMovable(true)
        box:RegisterForDrag("LeftButton")
        box:SetScript("OnDragStart", box.StartMoving)
        box:SetScript("OnDragStop", box.StopMovingOrSizing)
        UI:Skin(box, UI.palette.surface, UI.palette.border, "lg")
        UI:Shadow(box)
        box.title = UI:Text(box, 15)
        box.title:SetPoint("TOPLEFT", 16, -14)
        box.hint = UI:Text(box, 11, UI.palette.textDim)
        box.hint:SetPoint("TOPLEFT", box.title, "BOTTOMLEFT", 0, -4)
        box.hint:SetText("Ctrl+A, Ctrl+C to copy. Also saved in SavedVariables\\ArchmageHUD.lua")
        local close = CreateFrame("Button", nil, box)
        close:SetSize(24, 24)
        close:SetPoint("TOPRIGHT", -10, -10)
        close.t = UI:Text(close, 16, UI.palette.textDim)
        close.t:SetPoint("CENTER")
        close.t:SetText("x")
        close:SetScript("OnClick", function() box:Hide() end)
        local sf = CreateFrame("ScrollFrame", nil, box)
        sf:SetPoint("TOPLEFT", 16, -56)
        sf:SetPoint("BOTTOMRIGHT", -16, 16)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetWidth(600)
        eb:SetFontObject(ChatFontNormal)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); box:Hide() end)
        sf:SetScrollChild(eb)
        sf:EnableMouseWheel(true)
        sf:SetScript("OnMouseWheel", function(self, d)
            local max = math.max(0, eb:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 40)))
        end)
        box.eb = eb
        tinsert(UISpecialFrames, "ArchmageHUDCopy")
    end
    box.title:SetText(title)
    box.eb:SetText(text)
    box:Show()
    box.eb:SetFocus()
    box.eb:HighlightText()
end

local function v(x)
    if NS.IsSecret(x) then return "<secret>" end
    if x == nil then return "nil" end
    return tostring(x)
end

local function try(fn, ...)
    if not fn then return "<missing>" end
    local res = { pcall(fn, ...) }
    if not res[1] then return "<error: " .. tostring(res[2]) .. ">" end
    local out = {}
    for i = 2, math.max(#res, 2) do out[#out + 1] = v(res[i]) end
    return table.concat(out, ", ")
end

local function probe()
    local L = {}
    local function add(...) L[#L + 1] = table.concat({ ... }, " ") end
    local build, _, _, iface = GetBuildInfo()
    local inCombat = InCombatLockdown()
    add("Archmage HUD", NS.VERSION, "| build", v(build), "| interface", v(iface), "| locale", GetLocale())
    add("level", v(UnitLevel("player")), "| in combat:", tostring(inCombat), "| time", date("%Y-%m-%d %H:%M:%S"))
    add("issecretvalue:", tostring(_G.issecretvalue ~= nil))
    if C_Secrets then
        add("ShouldAurasBeSecret:", try(C_Secrets.ShouldAurasBeSecret), "| ShouldCooldownsBeSecret:", try(C_Secrets.ShouldCooldownsBeSecret))
    end

    add("")
    add("== Spec")
    add("active:", v(NS.spec), "| setting:", v(NS.db.spec), "| detected from talents:", v(Spells:DetectSpec()))
    add("GetSpecialization:", try(GetSpecialization), "| talent tabs:", try(function()
        local out = {}
        for tab = 1, 3 do out[#out + 1] = table.concat({ tostring(select(1, GetTalentTabInfo(tab))), tostring(select(3, GetTalentTabInfo(tab))), tostring(select(5, GetTalentTabInfo(tab))) }, "/") end
        return table.concat(out, "  ")
    end))
    add("")
    add("== Player buffs")
    local total, secret = 0, 0
    for i = 1, 40 do
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok then add("aura scan error:", tostring(a)) break end
        if not a then break end
        total = total + 1
        if NS.IsSecret(a.spellId) then
            secret = secret + 1
        else
            add("  ", v(a.name), "id", v(a.spellId), "stacks", v(a.applications), "dur", v(a.duration))
        end
    end
    add("buffs:", total, "| secret:", secret)
    local st = NS.modules.stacks and NS.modules.stacks.state
    add("Stacks: source", v(st and st.source), "| stacks", v(st and st.stacks), "| readable in combat", v(st and st.readableInCombat))
    if C_SpellActivationOverlay then
        local lit = {}
        for key, d in pairs(Spells.DEFS) do
            if d.known and NS.Try(C_SpellActivationOverlay.IsSpellOverlayed, d.id) == true then lit[#lit + 1] = key end
        end
        add("spells lit by the client right now:", #lit > 0 and table.concat(lit, ", ") or "none")
    end

    add("")
    add("== Native aura slots (Blizzard_AuraContainer)")
    for key, h in pairs(NS.Native.slots) do
        add("  " .. key .. ":", h.status, h.err and ("| " .. h.err) or "")
    end
    if C_Secrets then
        for _, id in ipairs(Spells:ProbeAuraIDs()) do
            add("  aura secrecy", id, v(Spells.NameOf(id)), ":", try(C_Secrets.GetSpellAuraSecrecy, id),
                "| secret now:", try(C_Secrets.ShouldSpellAuraBeSecret, id))
        end
    end

    add("")
    add("== Cooldowns")
    for _, key in ipairs(Spells:CooldownsFor(NS.spec)) do
        local d = Spells:Get(key)
        if d.known then
            local ok, info = pcall(C_Spell.GetSpellCooldown, d.id)
            local cd = ok and info and (v(info.startTime) .. " / " .. v(info.duration)) or "-"
            add(d.name, "id", d.id, "| cooldown", cd, "| duration object:", type(select(2, pcall(C_Spell.GetSpellCooldownDuration or error, d.id))),
                "| usable:", try(C_Spell.IsSpellUsable, d.id))
        end
    end
    add("GCD 61304:", try(function() local i = C_Spell.GetSpellCooldown(61304); return i and i.duration end),
        "| GCD 29515:", try(function() local i = C_Spell.GetSpellCooldown(29515); return i and i.duration end))

    add("")
    add("== Other")
    add("mana gems:", v(NS.modules.reminders and NS.modules.reminders.gems), "| runes (teleport/portal):", v(NS.modules.reminders and NS.modules.reminders.runes))
    for _, key in ipairs(Spells:DebuffsFor(NS.spec)) do
        local d = Spells:Get(key)
        add("target " .. key .. ":", try(function()
            local a = C_UnitAuras.GetAuraDataBySpellName("target", d.name, "HARMFUL|PLAYER")
            return a and (v(a.duration) .. "s, stacks " .. v(a.applications)) or "none"
        end))
    end
    add("target name:", try(UnitName, "target"))
    add("mana:", try(UnitPower, "player", 0), "/", try(UnitPowerMax, "player", 0), "| percent:", UnitPowerPercent and try(UnitPowerPercent, "player", 0) or "-")
    add("cast bar: last cast times", v(NS.modules.castbar and NS.modules.castbar.lastMode or "no cast yet"),
        "| Blizzard cast bar:", _G.PlayerCastingBarFrame and "PlayerCastingBarFrame" or _G.CastingBarFrame and "CastingBarFrame" or "not found")
    add("talents known (Ignite 11119 / Improved Scorch 11095 / Frostbite 11071):",
        try(IsPlayerSpell, 11119), "/", try(IsPlayerSpell, 11095), "/", try(IsPlayerSpell, 11071))
    add("")
    add("== Resolved spells (key: name / id / known)")
    local keys = {}
    for k in pairs(Spells.DEFS) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local d = Spells.DEFS[k]
        add("  " .. k .. ":", v(d.name), "/", v(d.id), "/", tostring(d.known))
    end

    local text = table.concat(L, "\n")
    NS.db.probe = NS.db.probe or {}
    NS.db.probe[inCombat and "combat" or "outOfCombat"] = text
    return text, inCombat
end

local function spells()
    local L = {}
    local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    for line = 1, (C_SpellBook.GetNumSpellBookSkillLines() or 0) do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info then
            L[#L + 1] = "== " .. tostring(info.name)
            for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local it = C_SpellBook.GetSpellBookItemInfo(i, bank)
                if it then
                    L[#L + 1] = string.format("%s | %s | id %s%s", tostring(it.name), tostring(it.subName or ""), tostring(it.spellID or it.actionID), it.isPassive and " | passive" or "")
                end
            end
        end
    end
    local text = table.concat(L, "\n")
    NS.db.probe = NS.db.probe or {}
    NS.db.probe.spells = text
    return text
end

NS.commands.probe = function()
    local text, inCombat = probe()
    copyBox("Client probe (" .. (inCombat and "in combat" or "out of combat") .. ")", text)
end

NS.commands.spells = function()
    copyBox("Spellbook", spells())
end

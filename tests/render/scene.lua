-- Scenes for the render check: HUD per spec in combat (the client's native aura
-- slots filled the way the client would), alerts, edit mode, every settings page.
local ROOT = (arg and arg[0] or ""):match("^(.*)tests[/\\]render[/\\]") or "./"
arg[0] = ROOT .. "tests/render/render.lua"
local X = dofile(ROOT .. "tests/render/render.lua")
local C = X.C
local NS = C.NS
local DEFS = NS.Spells.DEFS

-- every candidate ID gets its name, so the fake spellbook resolves like the real one
for _, d in pairs(DEFS) do for _, id in ipairs(d.ids) do C.SPELLS[id] = C.SPELLS[id] or d.en end end
C.SPELLS[11119], C.SPELLS[11095], C.SPELLS[11071] = "Ignite", "Improved Scorch", "Frostbite"

local BASE = { 133, 116, 5143, 2136, 2948, 122, 120, 1953, 2139, 12051, 1459, 6117, 1463, 759, 3561 }
local SPEC = {
    arcane = { 400574, 1326079, 12043, 12042, 11366 },
    fire = { 11366, 11113, 11129, 401502, 11119, 11095 },
    frost = { 1312002, 12472, 11426, 11958, 11071, 12043 },
}
local function book(spec)
    for i = #C.BOOK, 1, -1 do C.BOOK[i] = nil end
    for _, id in ipairs(BASE) do C.BOOK[#C.BOOK + 1] = id end
    for _, id in ipairs(SPEC[spec]) do C.BOOK[#C.BOOK + 1] = id end
    C.fire("SPELLS_CHANGED")
    NS:SetSpec(spec)
end

local function kids(parent, pred)
    local out = {}
    for _, o in ipairs(C.allFrames) do if o._parent == parent and (not pred or pred(o)) then out[#out + 1] = o end end
    return out
end
local function tex(key) local d = DEFS[key]; return 1000 + (d.aura and d.aura[1] or d.ids[1]) end
local function mana(v, low)   -- the client draws secret mana and colours it through the curve
    local bar = NS.modules.mana.bar; bar:SetMinMaxValues(0, 1000); bar:SetValue(v)
    if low then bar:SetStatusBarColor(0.969, 0.357, 0.357) else bar:SetStatusBarColor(0.25, 0.55, 1.0) end
end

-- what the client would draw into the native slots
local function fillStacks(spec, n, time)
    local h = NS.Native.slots["stacks_" .. spec]
    local b = h.button
    b:Show()
    b._nAppBar:SetMinMaxValues(0, b._nMax); b._nAppBar:SetValue(n)
    b._nDurText:SetText(time)
    for s, hh in pairs(NS.Native.slots) do if s:match("^stacks_") and s ~= "stacks_" .. spec then hh.button:Hide() end end
end
local function fillProcs(spec, list)
    local c = NS.Native.slots["procs_" .. spec].container
    local size = NS.db.procs.size
    c:SetSize(#list * (size + 4) - 4, size)
    local btns = kids(c)
    for i, b in ipairs(btns) do
        local p = list[i]
        if p then
            b:Show(); b:ClearAllPoints(); b:SetPoint("TOPLEFT", c, "TOPLEFT", (i - 1) * (size + 4), 0)
            b._nIcon:SetTexture(tex(p[1])); b._nCount:SetText(p[2] or "")
        else b:Hide() end
    end
    -- the mock made two buttons per group; add more if needed
    for i = #btns + 1, #list do
        local b = CreateFrame("Button", nil, c)
        NS.UI:Skin(b, NS.UI.palette.track, NS.UI.palette.border)
        local t = b:CreateTexture(nil, "ARTWORK"); t:SetPoint("TOPLEFT", 1, -1); t:SetPoint("BOTTOMRIGHT", -1, 1); t:SetTexture(tex(list[i][1]))
        b:SetSize(size, size); b:SetPoint("TOPLEFT", c, "TOPLEFT", (i - 1) * (size + 4), 0)
    end
end
local function fillDebuff(key, frac, time, count)
    local h = NS.Native.slots["debuff_" .. key]
    local b = h.button
    if not frac then b:Hide() return end
    b:Show()
    b._nIcon:SetTexture(tex(key))
    b._nDurBar:SetMinMaxValues(0, 1); b._nDurBar:SetValue(frac)
    b._nDurText:SetText(time); b._nCount:SetText(count or "")
end
local function fillAbsorb(key)
    local b = NS.Native.slots.absorb.button
    if not key then b:Hide() return end
    b:Show(); b._nIcon:SetTexture(tex(key))
end

C.run("login", function() C.fire("PLAYER_LOGIN"); C.fire("PLAYER_ENTERING_WORLD") end)
C.playerAuras[1] = { name = "Arcane Intellect", spellId = 1459, duration = 3600 }
C.playerAuras[2] = { name = "Mage Armor", spellId = 6117, duration = 1800 }
C.bag[5514] = 1
C.fire("UNIT_AURA", "player", {}); C.fire("BAG_UPDATE_DELAYED")

local HUD = "620,500,680,420"     -- x,y,w,h crop around the HUD column
local function combat(on)
    if on then C.fire("PLAYER_REGEN_DISABLED"); C.setCombat(true); C.fire("PLAYER_ENTER_COMBAT")
    else C.setCombat(false); C.fire("PLAYER_REGEN_ENABLED") end
end

-- FIRE
book("fire")
C.setMana(620)
combat(true)
C.fire("UNIT_POWER_FREQUENT", "player", "MANA")
fillStacks("fire", 3, "16.2"); mana(620)
NS.modules.stacks.state.full = true; NS.modules.stacks:Draw()     -- readable full stacks (glow + hint)
fillProcs("fire", { { "combustion", "2" }, { "wakeOfFire" }, { "missileBarrage" } })
fillDebuff("fireVuln", .81, "24.3", "5"); fillDebuff("fireball", .55, "4.4"); fillDebuff("ignite", .52, "2.1")
fillDebuff("pyroblast", .78, "9.4"); fillDebuff("frostfireBolt", nil)
fillAbsorb(nil)
C.fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 11366)
C.fire("SPELL_UPDATE_COOLDOWN")
C.tick(0.1); X.render("hud_fire", "Fire, in combat: Heating Up 3/3, four debuffs, proc card", HUD)
C.fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 11366)
combat(false)

-- FROST
book("frost")
combat(true)
fillStacks("frost", 3, "11.8"); mana(710)
NS.modules.stacks.state.full = false; NS.modules.stacks:Draw()
fillProcs("frost", { { "fingersOfFrost", "2" }, { "clearcasting" } })
fillDebuff("frostNova", .72, "5.8"); fillDebuff("frostbite", nil)
fillAbsorb(nil)          -- Ice Barrier gone: the red pulsing icon shows through
C.fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 1312002)
C.tick(0.1); X.render("hud_frost", "Frost, in combat: Winter's Chill 3/5, target frozen, Ice Barrier missing", HUD)
C.fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 1312002)
combat(false)

-- ARCANE
book("arcane")
C.setMana(240)
combat(true)
C.fire("UNIT_POWER_FREQUENT", "player", "MANA")
fillStacks("arcane", 4, "11.4"); mana(240, true)
NS.modules.stacks.state.full = true; NS.modules.stacks:Draw()
fillProcs("arcane", { { "missileBarrage" }, { "heatingUp", "2" }, { "arcanePower" } })
fillAbsorb("manaShield")
C.fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 5143)
C.tick(0.1); X.render("hud_arcane", "Arcane, in combat: 4 Arcane Blast stacks, low mana", HUD)
C.fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 5143)
combat(false)

-- out of combat: alerts
C.playerAuras[1], C.playerAuras[2] = nil, nil
C.bag[5514] = 0; C.bag[17031] = 1
C.fire("UNIT_AURA", "player", {}); C.fire("BAG_UPDATE_DELAYED")
UnitCanAttack = function() return false end
C.fire("PLAYER_TARGET_CHANGED")
X.render("alerts", "Out of combat, no enemy targeted: HUD hidden, only alerts", "560,0,800,420")
UnitCanAttack = function() return true end
C.fire("PLAYER_TARGET_CHANGED")

-- edit mode
book("fire")
SlashCmdList.ARCHMAGEHUD("edit")
X.render("edit", "Edit mode (Fire)", "0,0,1920,1080")
NS.Movers:Toggle(false)

-- settings window, every page
SlashCmdList.ARCHMAGEHUD("")
for _, p in ipairs({ "overview", "mana", "procs", "stacks", "debuffs", "cooldowns", "reminders", "appearance" }) do
    NS.Options:Show(p)
    X.render("opt_" .. p, "Settings: " .. p, "490,210,940,660")
end
print("rendered")

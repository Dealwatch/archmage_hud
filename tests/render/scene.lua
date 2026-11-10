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

local BASE = { 133, 116, 5143, 2136, 2948, 122, 120, 1953, 2139, 12051, 1459, 6117, 1463, 759, 3561, 118 }
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
local function fillSecond(spec, n)   -- the thin second stack bar (Arcane: Heating Up)
    local b = NS.Native.slots["stacks2_" .. spec].button
    b:Show(); b._nAppBar:SetMinMaxValues(0, b._nMax); b._nAppBar:SetValue(n)
end
-- rotation marks: the client lights one up when the stacks reach its number (n2: the second aura's stacks)
local function fillMarks(spec, n, n2)
    for key, h in pairs(NS.Native.slots) do
        local second = key:match("^mark2_" .. spec)
        if second or key:match("^mark_" .. spec) then
            local b = h.button
            b:Show(); b._nAppBar:SetMinMaxValues(b._nMin, b._nMax); b._nAppBar:SetValue(second and n2 or n)
        end
    end
end
-- nothing up: what the client shows in the native slots out of combat
local function clearNative()
    for key, h in pairs(NS.Native.slots) do
        if key:match("^procs_") then for _, b in ipairs(kids(h.container)) do b:Hide() end
        elseif h.button then h.button:Hide() end
    end
end
local function fillAbsorb(key)
    local b = NS.Native.slots.absorb.button
    if not key then b:Hide() return end
    b:Show(); b._nIcon:SetTexture(tex(key))
end

-- a focus only where a scene says so (the fake client's UnitExists is always true)
local hasFocus = false
UnitExists = function(unit) if unit == "focus" then return hasFocus end return true end
local function focus(on) hasFocus = on; C.fire("PLAYER_FOCUS_CHANGED") end

C.run("login", function() C.fire("PLAYER_LOGIN"); C.fire("PLAYER_ENTERING_WORLD") end)
C.playerAuras[1] = { name = "Arcane Intellect", spellId = 1459, duration = 3600 }
C.playerAuras[2] = { name = "Mage Armor", spellId = 6117, duration = 1800 }
C.bag[5514] = 1
C.fire("UNIT_AURA", "player", {}); C.fire("BAG_UPDATE_DELAYED")

-- a cast as the client reports it (times readable: the bar shows the time left too)
local function castNow(name, id, total, done, channel)
    local t = C.now() * 1000
    local info = { name, t - done * 1000, t + (total - done) * 1000, id }
    C.setCombat(false)
    if channel then C.setChannel(info); C.fire("UNIT_SPELLCAST_CHANNEL_START", "player", "g", id)
    else C.setCast(info); C.fire("UNIT_SPELLCAST_START", "player", "g", id) end
    C.setCombat(true)
    -- client-driven fill (duration object): draw what the client would
    local cb = NS.modules.castbar
    if cb.state.mode == "native" then
        cb.bar:SetMinMaxValues(0, total); cb.bar:SetValue(channel and total - done or done)
    end
end
local function castEnd()
    C.setCast(nil); C.setChannel(nil)
    C.fire("UNIT_SPELLCAST_STOP", "player", "g", 0); C.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "g", 0)
    C.tick(1)   -- past the short hold of a finished cast
end

local HUD = "620,500,680,420"     -- x,y,w,h crop around the HUD column
-- frame check: no HUD frame may cover another one (text is checked by shot.js)
local function shot(file, title, crop)
    X.render(file, title, crop)
    local seen = {}
    for _, e in ipairs(NS.Movers.list) do
        local f, r = e.frame, X.rect(e.frame)
        local vis = true
        local o = f; while o do if o._shown == false or (o._alpha or 1) < 0.01 then vis = false end o = o._parent end
        if vis and r.r > r.l and r.t > r.b then
            for _, s in ipairs(seen) do
                if r.l < s.r.r - 0.5 and s.r.l < r.r - 0.5 and r.b < s.r.t - 0.5 and s.r.b < r.t - 0.5 then
                    print("  ! " .. file .. ": frame " .. e.label .. " covers " .. s.label)
                end
            end
            seen[#seen + 1] = { label = e.label, r = r }
        end
    end
end
local function combat(on)
    if on then
        C.fire("PLAYER_REGEN_DISABLED"); C.setCombat(true); C.fire("PLAYER_ENTER_COMBAT")
        C.tick(25); NS.modules.opener:Draw()   -- mid-fight: the opener strip is long gone
    else C.setCombat(false); C.fire("PLAYER_REGEN_ENABLED") end
end

-- FIRE
book("fire")
C.setMana(620)
combat(true)
C.fire("UNIT_POWER_FREQUENT", "player", "MANA")
fillStacks("fire", 3, "16.2"); fillMarks("fire", 3); mana(620)
NS.modules.stacks.state.full = true; NS.modules.stacks:Draw()     -- readable full stacks (glow + hint)
fillProcs("fire", { { "combustion", "2" }, { "wakeOfFire" }, { "missileBarrage" } })
fillDebuff("fireVuln", .81, "24.3", "5"); fillDebuff("fireball", .55, "4.4"); fillDebuff("ignite", .52, "2.1")
fillDebuff("pyroblast", .78, "9.4"); fillDebuff("frostfireBolt", nil); fillDebuff("polymorph", nil)
fillAbsorb(nil)
C.fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 11366)
C.fire("SPELL_UPDATE_COOLDOWN")
castNow("Fireball", 25306, 3.5, 1.3)
C.tick(0.1); shot("hud_fire", "Fire, in combat: Heating Up 3/3, four debuffs, proc card", HUD)
-- the same moment as the addon really gets it in combat: stacks secret, the client does not light
-- Pyroblast up. No gold bar, no hint, no card - the mark the client lights is what tells you
C.fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 11366)
NS.modules.stacks.state.full = false; NS.modules.stacks:Draw()
shot("hud_fire_secret", "Fire, in combat, stacks secret and no spell glow: the lit mark still says Pyroblast", HUD)
C.fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 11366); castEnd()
combat(false)

-- FROST
book("frost")
focus(true)
combat(true)
fillStacks("frost", 3, "11.8"); fillMarks("frost", 3); mana(710)
NS.modules.stacks.state.full = false; NS.modules.stacks:Draw()
fillProcs("frost", { { "fingersOfFrost", "2" }, { "clearcasting" } })
fillDebuff("frostNova", .72, "5.8"); fillDebuff("frostbite", nil); fillDebuff("polymorph", .62, "31.0")
fillAbsorb(nil)          -- Ice Barrier gone: the red pulsing icon shows through
C.fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 1312002)
castNow("Frostbolt", 25304, 3.0, 2.1)
C.tick(0.1); shot("hud_frost", "Frost, in combat: Winter's Chill 3/5, target frozen, Ice Barrier missing, focus sheeped", HUD)
C.fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 1312002); castEnd()
combat(false)
focus(false)

-- ARCANE
book("arcane")
C.setMana(240)
combat(true)
C.fire("UNIT_POWER_FREQUENT", "player", "MANA")
fillStacks("arcane", 4, "11.4"); mana(240, true)
NS.modules.stacks.state.full = true; NS.modules.stacks:Draw()
fillSecond("arcane", 2); fillMarks("arcane", 4, 2)
fillProcs("arcane", { { "missileBarrage" }, { "clearcasting" }, { "arcanePower" } })
fillDebuff("polymorph", nil)
fillAbsorb("manaShield")
C.fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 5143)
castNow("Arcane Missiles", 5143, 2.5, 1.0, true)
C.tick(0.1); shot("hud_arcane", "Arcane, in combat: 4 Arcane Blast stacks (Wrath and Arcane Power lit), 2 Heating Up (Pyroblast not yet), low mana", HUD)
C.fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 5143); castEnd()
combat(false)

-- before the pull: enemy targeted out of combat, two casts into the opener
book("frost")
clearNative()
C.setMana(1000); C.fire("UNIT_POWER_FREQUENT", "player", "MANA")
C.fire("PLAYER_TARGET_CHANGED")
C.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 116); C.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 122)
C.tick(0.1); shot("prepull", "Frost, before the pull: opener two casts in (Frostbolt, Frost Nova done; Ice Lance next)", HUD)
book("fire")

-- out of combat: alerts
C.playerAuras[1], C.playerAuras[2] = nil, nil
C.bag[5514] = 0; C.bag[17031] = 1
C.fire("UNIT_AURA", "player", {}); C.fire("BAG_UPDATE_DELAYED")
UnitCanAttack = function() return false end
C.fire("PLAYER_TARGET_CHANGED")
shot("alerts", "Out of combat, no enemy targeted: HUD hidden, only alerts", "560,0,800,420")
GetWeaponEnchantInfo = function() return false end
C.fire("READY_CHECK")
shot("ready", "Ready check: one card with the consumables that are missing", "560,0,800,470")
C.fire("READY_CHECK_FINISHED")
UnitCanAttack = function() return true end
C.fire("PLAYER_TARGET_CHANGED")

-- edit mode
book("fire")
SlashCmdList.ARCHMAGEHUD("edit")
C.tick(0.1); shot("edit", "Edit mode (Fire)", "0,0,1920,1080")
NS.Movers:Toggle(false)

-- legend: one sentence beside every element
SlashCmdList.ARCHMAGEHUD("legend")
C.tick(0.1); shot("legend", "Legend (/mage legend), Fire", "440,150,1040,800")
NS.Movers:Toggle(false)

-- settings window, every page
SlashCmdList.ARCHMAGEHUD("")
for _, p in ipairs({ "overview", "mana", "castbar", "procs", "stacks", "debuffs", "cooldowns", "reminders", "appearance" }) do
    NS.Options:Show(p)
    X.render("opt_" .. p, "Settings: " .. p, "490,210,940,660")
    -- a page longer than the window: once more, scrolled to its end
    local scroll = _G.ArchmageHUDOptions.scroll
    local view = X.rect(scroll)
    local more = scroll:GetScrollChild():GetHeight() - (view.t - view.b)
    if more > 0 then
        scroll:SetVerticalScroll(more)
        X.render("opt_" .. p .. "_2", "Settings: " .. p .. " (scrolled to the end)", "490,210,940,660")
        scroll:SetVerticalScroll(0)
    end
end
print("rendered")

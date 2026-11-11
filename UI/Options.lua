--[[
    ArchmageHUD - settings window (/mage)
    Navigation on the left, pages of cards on the right. Every page is built
    once and refreshed whenever it is shown or a setting changes.
]]

local _, NS = ...
local UI, W, Spells = NS.UI, NS.Widgets, NS.Spells
local P = UI.palette

local Options = {}
NS.Options = Options

local WIN_W, WIN_H, NAV_W = 920, 640, 230
local win, pages, navButtons, current = nil, {}, {}, nil

---------------------------------------------------------------------------
-- Setting bindings
---------------------------------------------------------------------------

local function bind(section, key, after)
    return function() return NS.db[section][key] end,
        function(v)
            NS.db[section][key] = v
            if after then after(v) end
            NS:ApplyAll()
            if current then current:Refresh() end
        end
end

local function bindAppearance(key)
    return bind("appearance", key, function() UI:ApplyAppearance(); Options:Restyle() end)
end

local function bindModule(key)
    return function() return NS.db.modules[key] end,
        function(v) NS:SetModuleEnabled(key, v); if current then current:Refresh() end end
end

local function secs(v)
    if v >= 60 then return string.format("%dm %02ds", math.floor(v / 60), v % 60) end
    return v .. "s"
end
local function px(v) return tostring(v) end
local function mult(v) return string.format("%.2fx", v) end
local function oneDec(v) return string.format("%.1fs", v) end

---------------------------------------------------------------------------
-- Page framework
---------------------------------------------------------------------------

local function newPage(key, title, sub, icon)
    local p = { key = key, title = title, sub = sub, icon = icon, blocks = {} }
    function p:Add(block) self.blocks[#self.blocks + 1] = block; return block end
    function p:Layout()
        local width = win.scroll:GetWidth() - 8
        local y = 0
        for _, b in ipairs(self.blocks) do
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
            y = y + b:Layout(width) + 14
        end
        self.content:SetSize(width, y)
    end
    function p:Refresh()
        for _, b in ipairs(self.blocks) do if b.Refresh then b:Refresh() end end
    end
    pages[#pages + 1] = p
    return p
end

---------------------------------------------------------------------------
-- Overview blocks
---------------------------------------------------------------------------

local function buildInfo()
    local _, build, _, iface = GetBuildInfo()
    local forever = iface and iface >= 16000 and iface < 20000
    return build, iface, forever
end

local function heroBlock(parent)
    local h = CreateFrame("Frame", nil, parent)
    UI:Skin(h, P.surface2, P.border, "lg")
    h.logo = UI:Icon(h, 72)
    h.logo:SetPoint("TOPLEFT", 20, -20)
    h.logo.icon:SetTexture(NS:SpecInfo().icon)
    h.edit = W.Button(h, "Edit layout", true, function() NS.Movers:Toggle(true) end, 140)
    h.edit:SetPoint("TOPRIGHT", -20, -20)
    h.test = W.Button(h, "Test alerts", false, function() NS.Alerts:Test() end, 140)
    h.test:SetPoint("TOPRIGHT", h.edit, "BOTTOMRIGHT", 0, -8)
    -- text column between the logo and the buttons, so nothing runs under them
    h.title = UI:Text(h, 24)
    h.title:SetPoint("TOPLEFT", h.logo, "TOPRIGHT", 18, -2)
    h.ver = UI:Text(h, 13, P.textDim)
    h.ver:SetPoint("BOTTOMLEFT", h.title, "BOTTOMRIGHT", 10, 3)
    h.line1 = UI:Text(h, 12)
    h.line1:SetPoint("TOPLEFT", h.title, "BOTTOMLEFT", 0, -8)
    h.line2 = UI:Text(h, 12, P.textDim)
    h.line2:SetPoint("TOPLEFT", h.line1, "BOTTOMLEFT", 0, -6)
    h.line2:SetWordWrap(true)
    h.line2:SetText("/mage opens this window, /mage edit moves frames, /mage probe tests the client")
    function h:Layout(width)
        self:SetSize(width, 116)
        -- text column between logo and buttons (widths, not RIGHT anchors: those pin the vertical centre)
        local textW = width - (20 + 72 + 18) - (140 + 20 + 16)
        self.line1:SetWidth(textW); self.line2:SetWidth(textW)
        return 116
    end
    function h:Refresh()
        local r, g, b = UI:Accent()
        self.title:SetText(string.format("|cff%02x%02x%02xArchmage|r HUD", r * 255, g * 255, b * 255))
        self.logo.icon:SetTexture(NS:SpecInfo().icon)
        self.ver:SetText("v" .. NS.VERSION)
        local build, iface, forever = buildInfo()
        self.line1:SetText(string.format("%s  |  build %s  |  interface %s", forever and "WoW Forever" or "WoW", tostring(build), tostring(iface)))
        self.edit:Refresh(); self.test:Refresh()
    end
    return h
end

local function buffText(name)
    local v = NS.modules.reminders.state[name]
    if v == true then return "|cff55d985up|r" elseif v == false then return "|cffff5555missing|r" end
    return "unknown"
end

local function tilesBlock(parent)
    local t = CreateFrame("Frame", nil, parent)
    t.tiles = {}
    local defs = {
        { label = "SPEC", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry", value = function()
            return NS:SpecInfo().label .. (NS.specAuto and " (auto)" or "")
        end, iconFn = function() return NS:SpecInfo().icon end },
        { label = "INT / ARMOR", icon = "Interface\\Icons\\Spell_Frost_FrostArmor02", value = function()
            return buffText("intellect") .. " / " .. buffText("armor")
        end },
        { label = "STACKS", icon = "Interface\\Icons\\Spell_Arcane_Blast", value = function()
            local st = NS.modules.stacks.state
            local h = NS.Native.slots["stacks_" .. tostring(NS.spec)]
            if h and h:Active() then return "native stack bar" end
            if st.source == "aura" then return st.readableInCombat and "exact stacks" or "exact when idle" end
            return "not seen yet"
        end },
    }
    for i, d in ipairs(defs) do
        local f = CreateFrame("Frame", nil, t)
        UI:Skin(f, P.surface2, P.border, "lg")
        f.iconFrame = UI:Icon(f, 40)
        f.iconFrame:SetPoint("LEFT", 14, 0)
        f.iconFrame.icon:SetTexture(d.icon)
        f.label = UI:Text(f, 11, P.textDim)
        f.label:SetPoint("TOPLEFT", f.iconFrame, "TOPRIGHT", 12, -2)
        f.label:SetText(d.label)
        f.value = UI:Text(f, 13)
        f.value:SetPoint("BOTTOMLEFT", f.iconFrame, "BOTTOMRIGHT", 12, 2)
        f.def = d
        t.tiles[i] = f
    end
    function t:Layout(width)
        local x = 0
        for i, f in ipairs(self.tiles) do
            local w = (width - 2 * 14) * ({ 0.305, 0.355, 0.34 })[i]   -- by their longest value ("missing / missing")
            f:SetSize(w, 70)
            f.value:SetWidth(w - (14 + 40 + 12) - 8)   -- width, not a RIGHT anchor
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", x, 0)
            x = x + w + 14
        end
        self:SetSize(width, 70)
        return 70
    end
    function t:Refresh()
        for _, f in ipairs(self.tiles) do
            f.value:SetText(f.def.value())
            if f.def.iconFn then f.iconFrame.icon:SetTexture(f.def.iconFn()) end
        end
    end
    return t
end

local function specBlock(parent)
    local c = W.Card(parent, "Spec and preset", "Interface\\Icons\\INV_Misc_Book_09")
    local opts = { { value = "auto", label = "Auto" } }
    for _, sp in ipairs(NS.SPECS) do opts[#opts + 1] = { value = sp.key, label = sp.label } end
    c:Add(W.Segment(c, "Active spec", "Auto follows your talents. Also: /mage arcane, /mage fire, /mage frost, /mage auto.", opts,
        function() return NS.db.spec end,
        function(v) NS:SetSpec(v); Options:Restyle() end))
    local presets = {}
    for _, p in ipairs(NS.PRESETS) do presets[#presets + 1] = { value = p.key, label = p.label } end
    c:Add(W.Segment(c, "Preset", "How much HUD. Minimal: stack bar, procs and cast bar. Full adds rotation marks, opener and Polymorph timer.", presets,
        function() return NS:Preset() end,
        function(v) NS:SetPreset(v); if current then current:Refresh() end end))
    return c
end

local function modulesBlock(parent)
    local m = CreateFrame("Frame", nil, parent)
    m.header = UI:Text(m, 14, P.textDim)
    m.header:SetPoint("TOPLEFT", 0, 0)
    m.header:SetText("MODULES")
    m.cards = {}
    for _, key in ipairs(NS.moduleOrder) do
        local mod = NS.modules[key]
        local c = CreateFrame("Frame", nil, m)
        UI:Skin(c, P.surface2, P.border, "lg")
        c.iconFrame = UI:Icon(c, 36)
        c.iconFrame:SetPoint("TOPLEFT", 14, -14)
        c.iconFrame.icon:SetTexture(mod.icon)
        c.title = UI:Text(c, 14)
        c.title:SetPoint("TOPLEFT", c.iconFrame, "TOPRIGHT", 12, 0)
        c.title:SetText(mod.title)
        c.desc = UI:Text(c, 11, P.textDim)
        c.desc:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -3)
        c.desc:SetWordWrap(true)
        if c.desc.SetMaxLines then c.desc:SetMaxLines(2) end
        c.desc:SetText(mod.desc)
        local get, set = bindModule(key)
        c.switch = W.Switch(c, get, set)
        c.switch:SetPoint("RIGHT", -14, 0)
        m.cards[#m.cards + 1] = c
    end
    function m:Layout(width)
        local w = (width - 14) / 2
        for i, c in ipairs(self.cards) do
            local col, rowI = (i - 1) % 2, math.floor((i - 1) / 2)
            c:SetSize(w, 64)
            c.desc:SetWidth(w - (14 + 36 + 12) - 70)   -- up to the switch
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", col * (w + 14), -26 - rowI * 76)
        end
        local h = 26 + math.ceil(#self.cards / 2) * 76
        self:SetSize(width, h)
        return h
    end
    function m:Refresh() for _, c in ipairs(self.cards) do c.switch:Refresh() end end
    return m
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------

local function buildPages()
    local p

    p = newPage("overview", "Overview", "One HUD for Arcane, Fire and Frost, built for WoW Forever.", "Interface\\Icons\\Spell_Holy_MagicalSentry")
    p.build = function(self, parent)
        self:Add(heroBlock(parent))
        self:Add(specBlock(parent))
        self:Add(tilesBlock(parent))
        self:Add(modulesBlock(parent))
    end

    p = newPage("mana", "Mana Bar", "A thin mana bar in the HUD column.", "Interface\\Icons\\INV_Misc_Gem_Emerald_01")
    p.build = function(self, parent)
        local c = self:Add(W.Card(parent, "Mana bar", self.icon, bindModule("mana")))
        c:Add(W.Slider(c, "Width", nil, 120, 420, 10, px, bind("mana", "width")))
        c:Add(W.Slider(c, "Height", nil, 3, 24, 1, px, bind("mana", "height")))
        c:Add(W.Slider(c, "Red below", nil, 5, 60, 5, function(v) return v .. "%" end, bind("mana", "lowPct")))
        c:Add(W.Toggle(c, "Show percentage", "Needs a height of 9 or more.", bind("mana", "showText")))
        c:Add(W.Toggle(c, "Hide at full mana out of combat", nil, bind("mana", "hideFull")))
        c:Add(W.Toggle(c, "Mana gem and Evocation", "Two small icons at the end of the bar, with their cooldowns. The gem is grey when you have none.", bind("mana", "tools")))
    end

    p = newPage("castbar", "Cast Bar", "Your casts and channels, right under the mana bar. Shown only while you cast.", "Interface\\Icons\\Spell_Fire_FlameBolt")
    p.build = function(self, parent)
        local c = self:Add(W.Card(parent, "Cast bar", self.icon, bindModule("castbar")))
        c:Add(W.Slider(c, "Width", nil, 120, 420, 10, px, bind("castbar", "width")))
        c:Add(W.Slider(c, "Height", nil, 10, 30, 1, px, bind("castbar", "height")))
        c:Add(W.Toggle(c, "Time left", "Needs the cast times to be readable; in combat the client may hide them.", bind("castbar", "showTime")))
        c:Add(W.Toggle(c, "Hide Blizzard's cast bar", "So there is only one cast bar. Turning it back on needs a /reload.", bind("castbar", "hideBlizzard")))
    end

    p = newPage("procs", "Procs", "Only what is up right now, and a big card when a spell turns instant.", "Interface\\Icons\\Spell_Shadow_ManaBurn")
    p.build = function(self, parent)
        local c = self:Add(W.Card(parent, "Procs", self.icon, bindModule("procs")))
        c:Add(W.Slider(c, "Icon size", nil, 20, 48, 1, px, bind("procs", "size")))
        c:Add(W.Toggle(c, "Proc card", "\"Pyroblast!\" while the client lights up a spell (Heating Up, Missile Barrage, ...).", bind("procs", "card")))
        c:Add(W.Toggle(c, "Sound with the card", nil, bind("procs", "sound")))
        local info = c:Add(W.ButtonRow(c, "Tracked", "", "Test alerts", function() NS.Alerts:Test() end))
        local base = info.Refresh
        function info:Refresh()
            base(self)
            local names = {}
            for _, key in ipairs(Spells.SPEC_DATA[NS.spec].procs) do
                local d = Spells:Get(key)
                names[#names + 1] = d.name or d.en   -- talent procs are never "known" spells: no learned marker
            end
            self.desc:SetText(table.concat(names, ", "))
        end
    end

    p = newPage("stacks", "Stack Bar", "Arcane Blast stacks (Arcane), Heating Up (Fire), Winter's Chill (Frost).", "Interface\\Icons\\Spell_Arcane_Blast")
    p.build = function(self, parent)
        local c = self:Add(W.Card(parent, "Stack bar", self.icon, bindModule("stacks")))
        c:Add(W.Slider(c, "Width", nil, 100, 420, 10, px, bind("stacks", "width")))
        c:Add(W.Slider(c, "Height", nil, 4, 30, 1, px, bind("stacks", "height")))
        c:Add(W.Toggle(c, "Glow at full stacks", nil, bind("stacks", "glow")))
        c:Add(W.Toggle(c, "Sound at full stacks", nil, bind("stacks", "sound")))
        c:Add(W.Toggle(c, "Hide at zero stacks out of combat", nil, bind("stacks", "hideEmpty")))
        c:Add(W.Toggle(c, "Rotation marks", "Icons under the stack bar that light up when it is time to cast them.", bind("stacks", "marks")))
        local info = c:Add(W.ButtonRow(c, "Detection", "The client fills the bar itself (native aura slot), also in combat. Glow and sound need the aura to be readable.", "Run probe", function() NS.commands.probe() end))
        local base = info.Refresh
        function info:Refresh()
            base(self)
            local h = NS.Native.slots["stacks_" .. tostring(NS.spec)]
            local st = NS.modules.stacks.state
            self.label:SetText("Detection: " .. (h and h:Active() and "native stack bar" or st.source == "aura" and "exact stacks" or "not seen yet"))
        end
    end

    p = newPage("debuffs", "Target Debuffs", "Your debuffs on the target with the real time left.", "Interface\\Icons\\Spell_Fire_Incinerate")
    p.build = function(self, parent)
        local c = self:Add(W.Card(parent, "Target debuffs", self.icon, bindModule("debuffs")))
        c:Add(W.Slider(c, "Width", nil, 120, 360, 10, px, bind("debuffs", "width")))
        c:Add(W.Slider(c, "Height", nil, 8, 30, 1, px, bind("debuffs", "height")))
        c:Add(W.Toggle(c, "Polymorph on your focus", "A bar under the debuffs with the time left of your Polymorph on the focus target.", bind("debuffs", "focus")))
        local info = c:Add(W.ButtonRow(c, "Tracked", "", "Edit layout", function() NS.Movers:Toggle(true) end))
        local base = info.Refresh
        function info:Refresh()
            base(self)
            local names = {}
            for _, key in ipairs(Spells:DebuffsFor(NS.spec)) do
                local d = Spells:Get(key)
                if Spells:DebuffShown(key) then names[#names + 1] = d.name or d.en end
            end
            self.desc:SetText(#names > 0 and table.concat(names, ", ") or "Nothing for this spec (yet).")
        end
    end

    p = newPage("cooldowns", "Cooldowns", "Your spec's cooldowns plus the ones every mage uses.", "Interface\\Icons\\Spell_Arcane_Blink")
    p.build = function(self, parent)
        local c = self:Add(W.Card(parent, "Cooldown row", self.icon, bindModule("cooldowns")))
        c:Add(W.Slider(c, "Icon size", nil, 20, 56, 1, px, bind("cooldowns", "size")))
        c:Add(W.Toggle(c, "Flash when a spell is ready again", "The icon lights up once when the cooldown your cast started is over. Fire Blast and Ice Lance share one cooldown: both flash.", bind("cooldowns", "readyFlash")))
    end

    p = newPage("reminders", "Reminders", "Alerts stack in one place. Right-click an alert to snooze it.", "Interface\\Icons\\Spell_Holy_MagicalSentry")
    p.build = function(self, parent)
        local c = self:Add(W.Card(parent, "Reminders", self.icon, bindModule("reminders")))
        c:Add(W.Toggle(c, "Arcane Intellect missing", nil, bind("reminders", "intellect")))
        c:Add(W.Toggle(c, "No armor spell up", "Frost, Ice or Mage Armor.", bind("reminders", "armor")))
        c:Add(W.Toggle(c, "Frost: Ice Barrier not up", "Keep Ice Barrier up at all times (it also adds Frost damage). In combat addons can't read your buffs: the absorb icon turns red and pulses instead.", bind("reminders", "barrier")))
        c:Add(W.Toggle(c, "Buff reminders in combat too", nil, bind("reminders", "inCombat")))
        c:Add(W.Toggle(c, "No mana gem", "Out of combat, when you can conjure one.", bind("reminders", "gem")))
        c:Add(W.Toggle(c, "Low on teleport / portal runes", nil, bind("reminders", "reagents")))
        c:Add(W.Slider(c, "Warn below", nil, 1, 20, 1, function(v) return v .. " runes" end, bind("reminders", "reagentMin")))
        c:Add(W.Toggle(c, "Ready check", "One card at a ready check: all set, or what is missing (weapon oil, mana potions, water).", bind("reminders", "ready")))
        c:Add(W.Toggle(c, "Absorb icon", "Ice Barrier or Mana Shield with time left, straight from the client, also in combat.", bind("reminders", "absorbIcon")))
        c:Add(W.Slider(c, "Absorb icon size", nil, 20, 60, 1, px, bind("reminders", "absorbSize")))
        c:Add(W.Slider(c, "Snooze on right-click", nil, 15, 600, 15, secs, bind("reminders", "snooze")))
    end

    p = newPage("appearance", "Appearance", "Look and feel for every Archmage HUD frame.", "Interface\\Icons\\Spell_Nature_EnchantArmor")
    p.build = function(self, parent)
        local look = self:Add(W.Card(parent, "Look", "Interface\\Icons\\INV_Misc_Gem_Sapphire_02"))
        local accents = {}
        for _, a in ipairs(UI.ACCENTS) do accents[#accents + 1] = { value = a.key, label = a.label } end
        local fonts = {}
        for _, f in ipairs(UI.FONTS) do fonts[#fonts + 1] = { value = f.key, label = f.label } end
        local textures = {}
        for _, t in ipairs(UI.TEXTURES) do textures[#textures + 1] = { value = t.key, label = t.label } end
        look:Add(W.Dropdown(look, "Accent colour", "Follow spec: purple for Arcane, orange for Fire, ice blue for Frost.", accents, bindAppearance("accent")))
        look:Add(W.Dropdown(look, "Font", nil, fonts, bindAppearance("font")))
        -- up to 1.2: the cards and the settings window have fixed sizes (bigger: HUD scale).
        -- from 0.8: below that the 11 px HUD text is too small to read
        look:Add(W.Slider(look, "Text size", nil, 0.8, 1.2, 0.05, mult, bindAppearance("fontScale")))
        look:Add(W.Dropdown(look, "Bar texture", nil, textures, bindAppearance("texture")))
        look:Add(W.Toggle(look, "Play sounds", nil, bind("appearance", "sounds")))
        look:Add(W.Slider(look, "Out of combat", "HUD opacity out of combat. 0% = hidden: only alerts stay.", 0, 1.0, 0.05, function(v) return v < 0.01 and "hidden" or (math.floor(v * 100 + 0.5) .. "%") end, bind("appearance", "idleAlpha")))
        look:Add(W.Toggle(look, "Show the HUD when an enemy is targeted", "Out of combat too, so you see stacks and cooldowns before the pull.", bind("appearance", "showOnTarget")))

        local layout = self:Add(W.Card(parent, "Layout", "Interface\\Icons\\INV_Misc_Map_01"))
        layout:Add(W.Slider(layout, "HUD scale", nil, 0.5, 2.0, 0.05, mult, bindAppearance("scale")))
        layout:Add(W.Slider(layout, "Edit mode grid", nil, 0, 64, 4, px, bind("appearance", "grid")))
        layout:Add(W.ButtonRow(layout, "Frames", nil, "Open Edit Mode", function() NS.Movers:Toggle(true) end))
        layout:Add(W.ButtonRow(layout, "Legend", "What each HUD element is for, written beside it for 10 seconds. Also: /mage legend.", "Show legend", function() NS.commands.legend() end))
        layout:Add(W.ButtonRow(layout, "Positions", "The HUD lays itself out for each spec. This drops every frame you moved (all specs) and goes back to the automatic layout.", "Auto layout", function()
            wipe(NS.db.positions); NS.Movers:RestoreAll()
        end))

        local diag = self:Add(W.Card(parent, "Diagnostics", "Interface\\Icons\\INV_Misc_Spyglass_03"))
        diag:Add(W.ButtonRow(diag, "Client probe", "What Forever lets the addon read right now. Run it in combat too.", "Run probe", function() NS.commands.probe() end))
        diag:Add(W.ButtonRow(diag, "Spell list", "Copyable list of your spells and their IDs.", "Show spells", function() NS.commands.spells() end))
    end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function navButton(page, i)
    local b = CreateFrame("Button", nil, win.nav)
    b:SetSize(NAV_W - 24, 40)
    b:SetPoint("TOPLEFT", 12, -96 - (i - 1) * 44)
    b.bg = UI:ShapeTexture(b, "lg")
    b.bg:SetAllPoints()
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetTexture(UI.WHITE)
    b.bar:SetPoint("TOPLEFT", 0, -10); b.bar:SetPoint("BOTTOMLEFT", 0, 10); b.bar:SetWidth(3)
    b.iconFrame = UI:Icon(b, 24)
    b.iconFrame:SetPoint("LEFT", 14, 0)
    b.iconFrame.icon:SetTexture(page.icon)
    b.text = UI:Text(b, 14)
    b.text:SetPoint("LEFT", b.iconFrame, "RIGHT", 12, 0)
    b.text:SetText(page.title)
    b:SetScript("OnClick", function() Options:Show(page.key) end)
    b:SetScript("OnEnter", function(self) if current ~= page then self.bg:SetVertexColor(1, 1, 1, 0.03) end end)
    b:SetScript("OnLeave", function() Options:Restyle() end)
    b.page = page
    navButtons[#navButtons + 1] = b
end

local function build()
    win = CreateFrame("Frame", "ArchmageHUDOptions", UIParent)
    win:SetSize(WIN_W, WIN_H)
    win:SetPoint("CENTER")
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    UI:Skin(win, P.surface, P.border, "lg")
    UI:Shadow(win)
    tinsert(UISpecialFrames, "ArchmageHUDOptions")

    -- navigation
    win.nav = CreateFrame("Frame", nil, win)
    win.nav:SetPoint("TOPLEFT"); win.nav:SetPoint("BOTTOMLEFT"); win.nav:SetWidth(NAV_W)
    -- darker nav panel: rounded on the outer corners, a separator line inside
    win.navBg = win:CreateTexture(nil, "BACKGROUND", nil, -6)
    if not UI.Sliced(win.navBg, "Fill", "lg") then win.navBg:SetTexture(UI.WHITE) end
    win.navBg:SetPoint("TOPLEFT", win, "TOPLEFT", 1, -1)
    win.navBg:SetPoint("BOTTOMRIGHT", win, "BOTTOMLEFT", NAV_W + 12, 1)
    win.navBg:SetVertexColor(P.bg[1], P.bg[2], P.bg[3], 1)
    win.navCover = win:CreateTexture(nil, "BACKGROUND", nil, -5)
    win.navCover:SetTexture(UI.WHITE)
    win.navCover:SetPoint("TOPLEFT", NAV_W, -1)
    win.navCover:SetPoint("BOTTOMLEFT", NAV_W, 1)
    win.navCover:SetWidth(14)
    win.navCover:SetVertexColor(P.surface[1], P.surface[2], P.surface[3], 1)
    win.navLine = win:CreateTexture(nil, "BORDER")
    win.navLine:SetTexture(UI.WHITE)
    win.navLine:SetPoint("TOPLEFT", NAV_W, -1)
    win.navLine:SetPoint("BOTTOMLEFT", NAV_W, 1)
    win.navLine:SetWidth(1)
    win.navLine:SetVertexColor(P.border[1], P.border[2], P.border[3], 1)
    win.logo = UI:Icon(win.nav, 44)
    win.logo:SetPoint("TOPLEFT", 18, -22)
    win.logo.icon:SetTexture("Interface\\Icons\\Spell_Holy_MagicalSentry")
    win.name = UI:Text(win.nav, 16)
    win.name:SetPoint("TOPLEFT", win.logo, "TOPRIGHT", 12, -3)
    win.name:SetText(NS.TITLE)
    win.ver = UI:Text(win.nav, 11, P.textDim)
    win.ver:SetPoint("TOPLEFT", win.name, "BOTTOMLEFT", 0, -4)
    for i, page in ipairs(pages) do navButton(page, i) end

    win.status = CreateFrame("Frame", nil, win.nav)
    win.status:SetSize(NAV_W - 24, 30)
    win.status:SetPoint("BOTTOMLEFT", 12, 58)
    UI:Skin(win.status, P.surface, P.border, "lg")
    win.status.dot = win.status:CreateTexture(nil, "ARTWORK")
    win.status.dot:SetTexture(NS.MEDIA .. "Media\\Circle")
    win.status.dot:SetSize(8, 8)
    win.status.dot:SetPoint("LEFT", 12, 0)
    win.status.text = UI:Text(win.status, 12)
    win.status.text:SetPoint("LEFT", win.status.dot, "RIGHT", 10, 0)
    win.editBtn = W.Button(win.nav, "Edit layout", true, function() NS.Movers:Toggle(true) end, NAV_W - 24)
    win.editBtn:SetPoint("BOTTOMLEFT", 12, 14)

    -- page area
    win.titleText = UI:Text(win, 26)
    win.titleText:SetPoint("TOPLEFT", NAV_W + 28, -24)
    win.subText = UI:Text(win, 13, P.textDim)
    win.subText:SetPoint("TOPLEFT", win.titleText, "BOTTOMLEFT", 0, -6)
    win.close = CreateFrame("Button", nil, win)
    win.close:SetSize(28, 28)
    win.close:SetPoint("TOPRIGHT", -14, -14)
    win.close.text = UI:Text(win.close, 18, P.textDim)
    win.close.text:SetPoint("CENTER")
    win.close.text:SetText("x")
    win.close:SetScript("OnClick", function() win:Hide() end)

    win.scroll = CreateFrame("ScrollFrame", nil, win)
    win.scroll:SetPoint("TOPLEFT", NAV_W + 28, -96)
    win.scroll:SetPoint("BOTTOMRIGHT", -24, 20)
    win.scroll:EnableMouseWheel(true)
    win.scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, (self:GetScrollChild() and self:GetScrollChild():GetHeight() or 0) - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 50)))
    end)

    for _, page in ipairs(pages) do
        page.content = CreateFrame("Frame", nil, win.scroll)
        page.content:SetSize(WIN_W - NAV_W - 60, 10)
        page:build(page.content)
        page.content:Hide()
    end
    win:SetScript("OnHide", function() W.CloseMenu(); UI:UpdateFade() end)
    win:SetScript("OnShow", function() UI:UpdateFade() end)
    win:Hide()
end

function Options:Restyle()
    if not win then return end
    local r, g, b = UI:Accent()
    for _, nb in ipairs(navButtons) do
        if nb.page == current then
            nb.bg:SetVertexColor(1, 1, 1, 0.06)
            nb.bar:SetVertexColor(r, g, b, 1)
            nb.bar:Show()
        else
            nb.bg:SetVertexColor(0, 0, 0, 0)
            nb.bar:Hide()
        end
    end
    local _, iface, forever = buildInfo()
    win.status.dot:SetVertexColor(forever and r or P.warn[1], forever and g or P.warn[2], forever and b or P.warn[3], 1)
    win.status.text:SetText(forever and "WoW Forever detected" or ("Interface " .. tostring(iface)))
    win.ver:SetText("v" .. NS.VERSION .. "  -  " .. NS:SpecInfo().label)
    win.logo.icon:SetTexture(NS:SpecInfo().icon)
    win.editBtn:Refresh()
    if current then current:Refresh() end
end

function Options:Show(key)
    if not win then
        buildPages()
        build()
    end
    local page = pages[1]
    for _, p in ipairs(pages) do if p.key == key then page = p end end
    if current and current ~= page then current.content:Hide() end
    current = page
    win.titleText:SetText(page.title)
    win.subText:SetText(page.sub)
    win.scroll:SetScrollChild(page.content)
    win.scroll:SetVerticalScroll(0)
    page.content:Show()
    win:Show()
    page:Layout()
    self:Restyle()
end

function Options:IsShown() return win ~= nil and win:IsShown() end

function Options:Toggle()
    if win and win:IsShown() then win:Hide() else self:Show(current and current.key or "overview") end
end

-- keep the overview tiles live while the window is open
C_Timer.NewTicker(1, function()
    if win and win:IsShown() and current and current.key == "overview" then current:Refresh() end
end)

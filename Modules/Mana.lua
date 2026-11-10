--[[
    ArchmageHUD - mana bar
    A thin bar in the HUD column. Your own mana can be secret in combat on
    Forever: the values still go straight into the bar (StatusBar setters
    accept secrets) and the client tints it through a colour curve; only the
    percentage and "hide at full" need readable numbers.
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local Mana = NS:NewModule("mana", {
    title = "Mana Bar",
    desc = "Thin mana bar, red when low, hides at full",
    icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_01",
})

local frame, bar, curve
local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
local COLOR = { 0.25, 0.55, 1.0 }
local tools = {}      -- mana gem and Evocation: two small icons at the end of the bar, where you look at low mana
local TOOL = 14
local GEM_CD = 120    -- seconds

function Mana:Init()
    frame = CreateFrame("Frame", "ArchmageHUDMana", UIParent)
    frame:Hide()
    self.frame = frame
    bar = UI:Bar(frame, NS.db.mana.width, NS.db.mana.height)
    bar:SetAllPoints()
    bar:SetStatusBarColor(COLOR[1], COLOR[2], COLOR[3])
    self.bar = bar
    bar.text = UI:Text(bar, 10, UI.palette.text, "OUTLINE")
    bar.text:SetPoint("CENTER")
    bar.text:SetJustifyH("CENTER")
    NS.Movers:Register(frame, "mana", "Mana", NS.Layout.For("mana"))

    for i, key in ipairs({ "conjureGem", "evocation" }) do
        local f = UI:Icon(frame, TOOL)
        f.cd = UI:Cooldown(f)
        if f.cd.SetHideCountdownNumbers then f.cd:SetHideCountdownNumbers(true) end   -- too small for numbers
        f.key = key
        tools[i] = f
    end
    self.tools = tools
    local function drawTools() self:Tools() end
    NS:On("SPELL_UPDATE_COOLDOWN", drawTools)
    NS:On("BAG_UPDATE_DELAYED", drawTools)
    NS:On("MF_SPELLS", drawTools)
    -- using a gem is your own cast (never secret): its cooldown runs here even if item cooldowns are hidden
    NS:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, _, spellID)
        if Spells:KeyFor(spellID) == "gemUse" then tools[1].cd:SetCooldown(GetTime(), GEM_CD) end
    end)

    local function update() self:Update() end
    NS:OnUnit("UNIT_POWER_FREQUENT", "player", update)
    NS:OnUnit("UNIT_MAXPOWER", "player", update)
    NS:OnUnit("UNIT_DISPLAYPOWER", "player", update)
    NS:On("PLAYER_REGEN_DISABLED", function() self:Update(true) end)
    NS:On("PLAYER_REGEN_ENABLED", update)
    NS:On("PLAYER_ENTERING_WORLD", update)
end

-- When the mana value is secret the client colours the bar itself through a
-- step colour curve (red below the threshold, blue above).
local function buildCurve(lowPct)
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local ok, c = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not c then return nil end
    local d = UI.palette.danger
    local okType = pcall(c.SetType, c, Enum.LuaCurveType and Enum.LuaCurveType.Step or 1)
    local ok1 = pcall(c.AddPoint, c, 0, CreateColor(d[1], d[2], d[3], 1))
    local ok2 = pcall(c.AddPoint, c, lowPct / 100, CreateColor(COLOR[1], COLOR[2], COLOR[3], 1))
    return (okType and ok1 and ok2) and c or nil
end

local function colourFromCurve()
    if not (curve and UnitPowerPercent) then return false end
    return pcall(function()
        local col = UnitPowerPercent("player", MANA, false, curve)
        if col.GetRGB then bar:SetStatusBarColor(col:GetRGB()) else bar:SetStatusBarColor(col.r, col.g, col.b) end
    end)
end

-- Returns the readable fraction (0..1) or nil.
function Mana.Fraction()
    local cur, max = UnitPower("player", MANA), UnitPowerMax("player", MANA)
    cur, max = NS.Readable(cur), NS.Readable(max)
    if cur and max and max > 0 then return cur / max end
end

function Mana:Update(enteringCombat)
    if not frame then return end
    local db = NS.db.mana
    local cur, max = UnitPower("player", MANA), UnitPowerMax("player", MANA)
    pcall(bar.SetMinMaxValues, bar, 0, max)
    pcall(bar.SetValue, bar, cur)

    local frac = Mana.Fraction()
    if NS.editing then frac = frac or 0.7 end
    local inCombat = enteringCombat or NS.InCombat()
    local full = frac and frac >= 0.999
    local show = NS:IsEnabled("mana") and (NS.editing or inCombat or not db.hideFull or not full)
    frame:SetShown(show and true or false)
    if not show then return end

    if frac then
        if frac * 100 < db.lowPct then
            bar:SetStatusBarColor(UI.palette.danger[1], UI.palette.danger[2], UI.palette.danger[3])
        else
            bar:SetStatusBarColor(COLOR[1], COLOR[2], COLOR[3])
        end
    elseif not colourFromCurve() then
        bar:SetStatusBarColor(COLOR[1], COLOR[2], COLOR[3])
    end
    bar.text:SetShown(db.showText and db.height >= 9)
    bar.text:SetText(frac and string.format("%d%%", math.floor(frac * 100 + 0.5)) or "")
end

function Mana:Tools()
    if not frame then return end
    local x = 6
    for _, f in ipairs(tools) do
        local def = Spells:Get(f.key)
        local show = NS.db.mana.tools and (def.known or NS.editing) or false
        f:SetShown(show)
        if show then
            f:ClearAllPoints()
            f:SetPoint("LEFT", frame, "RIGHT", x, 0)
            x = x + TOOL + 4
            f.icon:SetTexture(def.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            if f.key == "evocation" then
                UI:SpellCooldown(f.cd, def.id)
            else
                f.icon:SetDesaturated(Spells.ItemCount(Spells.MANA_GEMS) == 0)   -- grey: no gem in the bags
            end
        end
    end
end

function Mana:Apply()
    if not frame then return end
    local db = NS.db.mana
    frame:SetSize(db.width, db.height)
    curve = buildCurve(db.lowPct)
    bar.spark:SetHeight(db.height)
    self:Tools()
    self:Update()
end

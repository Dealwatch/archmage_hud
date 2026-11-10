--[[
    ArchmageHUD - automatic layout
    The HUD column under your character is laid out for the active spec, so
    you never have to arrange it: rows that a spec does not use (no debuffs
    for Arcane, two for Frost, five for Fire), modules you switched off and
    spells you do not know take no space, and the rest closes up.

    Top to bottom, what you act on first: proc card, proc row, stack bar
    (most important for every spec, in the middle of your view) with its
    rotation marks, mana, cast bar, the cooldown row. Then what you watch:
    your debuffs on the target and the Polymorph timer of your focus. Before
    the pull the opener takes the place of the proc card. The absorb icon sits
    left of the stack bar.

    A frame you drag in edit mode keeps that spot (saved per spec); a right-
    click in edit mode hands it back to this layout.
]]

local _, NS = ...
local Spells = NS.Spells

local Layout = {}
NS.Layout = Layout

local GAP = 6
local LABEL = 14     -- room for the stack bar's name / hint above it
Layout.MARKS = 27    -- row of rotation marks under the stack bar: 5 gap (clear of the full-stacks glow) + 22 icon
Layout.SECOND = 11   -- the same row with the marks off: 5 gap + the 6 px pips of a second stack aura

-- Number of debuff rows the active spec shows (same rule as Modules/Debuffs).
function Layout.DebuffRows()
    if not NS:IsEnabled("debuffs") then return 0 end
    local n = 0
    for _, key in ipairs(Spells:DebuffsFor(NS.spec)) do
        if Spells:DebuffShown(key) then n = n + 1 end
    end
    return n
end

-- The Polymorph row is there: you know the spell and have a focus (or are arranging frames).
function Layout.FocusRow()
    return NS:IsEnabled("debuffs") and NS.db.debuffs.focus and Spells:DebuffShown("polymorph")
        and (NS.editing or UnitExists("focus")) or false
end

-- { key = { point, relativePoint, x, y } } for the active spec, on UIParent.
function Layout.Column()
    local db = NS.db
    local out = {}
    out.proccard = { "CENTER", "CENTER", 0, -40 }
    local size = db.procs.size
    out.procs = { "TOP", "CENTER", 0, -65 }
    local y = -65 - size - GAP          -- y = top of the next free spot
    -- the absorb icon sits left of the widest bar, so a large icon never covers one
    local left = -math.max(db.stacks.width, db.mana.width, db.castbar.width, db.debuffs.width) / 2 - 8

    if NS:IsEnabled("stacks") and Spells.SPEC_DATA[NS.spec].stacks then
        y = y - LABEL
        out.stacks = { "TOP", "CENTER", 0, y }
        out.absorb = { "TOPRIGHT", "CENTER", left, y + 2 }
        y = y - db.stacks.height - GAP
        if db.stacks.marks and Spells.SPEC_DATA[NS.spec].stacks.marks then y = y - Layout.MARKS
        elseif Spells.SPEC_DATA[NS.spec].second then y = y - Layout.SECOND end
    else
        out.stacks = { "TOP", "CENTER", 0, y - LABEL }
        out.absorb = { "TOPRIGHT", "CENTER", left, y }
    end

    out.mana = { "TOP", "CENTER", 0, y }
    if NS:IsEnabled("mana") then y = y - db.mana.height - GAP end

    out.castbar = { "TOP", "CENTER", 0, y }   -- space kept while idle, so nothing jumps at a cast
    if NS:IsEnabled("castbar") then y = y - db.castbar.height - GAP - 4 end   -- a little air: yours above, the target's below

    -- what you can cast sits with what you are casting; the target's debuffs come below
    out.cooldowns = { "TOP", "CENTER", 0, y }
    if NS:IsEnabled("cooldowns") then y = y - db.cooldowns.size - GAP - 4 end

    out.debuffs = { "TOP", "CENTER", 0, y }
    local rows = Layout.DebuffRows()
    if rows > 0 then y = y - rows * (db.debuffs.height + 2) + 2 - GAP end

    out.focus = { "TOP", "CENTER", 0, y }
    return out
end

-- default for Movers:Register, evaluated every time the frame is placed
function Layout.For(key)
    return function() return Layout.Column()[key] end
end

NS:On("MF_SPELLS", function() if NS.Movers then NS.Movers:RestoreAll() end end)

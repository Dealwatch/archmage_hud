-- Renders the frames the addon really creates (offline test client) to HTML:
-- real anchors, sizes, colours, textures and text of every visible frame.
-- Used by tests/render/scene.lua; run everything with  node tests/render/shot.js
local ROOT = (arg and arg[0] or ""):match("^(.*)tests[/\\]render[/\\]") or "./"
local R = ROOT .. "tests/render/"
local OUT = R .. "out/"

-- the fake client = tests/run.lua up to its first test step
local src = assert(io.open(ROOT .. "tests/run.lua")):read("*a")
src = src:sub(1, assert(src:find('\nrun%("login"')))
src = src:gsub('local ROOT = [^\n]*', 'local ROOT = "' .. ROOT .. '"', 1)
src = src:gsub("%-%- load the addon in TOC order", "HOOK(Object)\n-- load the addon in TOC order", 1)
src = src .. [==[
return { Object = Object, allFrames = allFrames, fire = fire, tick = tick, run = run, NS = NS,
    BOOK = BOOK, SPELLS = SPELLS, playerAuras = playerAuras, targetAuras = targetAuras, bag = bag,
    setCombat = function(v) combat = v end, setMana = function(v) mana = v end,
    setCast = function(c) casting = c end, setChannel = function(c) channeling = c end, now = function() return now end }
]==]
local ICON = {}
for id, name in assert(io.open(R .. "iconmap.json")):read("*a"):gmatch('"(%d+)":%s*"([%w_]+)"') do ICON[tonumber(id)] = name end
local cache, RECT
local Object
function HOOK(obj) Object = obj; INSTALL() end

---------------------------------------------------------------------------
-- record what the widget API is told
---------------------------------------------------------------------------
local function rec(name, fn) Object[name] = fn end
local level
function INSTALL()
rec("SetPoint", function(self, p, a, b, c, d)
    local rel, rp, x, y = self._parent, p, 0, 0
    if type(a) == "number" then x, y = a, b or 0
    elseif a ~= nil then
        rel = type(a) == "string" and _G[a] or a
        if type(b) == "string" then rp, x, y = b, c or 0, d or 0 else x, y = b or 0, c or 0 end
    end
    self._pts = self._pts or {}
    for i = #self._pts, 1, -1 do if self._pts[i][1] == p then table.remove(self._pts, i) end end
    self._pts[#self._pts + 1] = { p, rel, rp, x, y }
end)
rec("ClearAllPoints", function(self) self._pts = {} end)
rec("SetAllPoints", function(self, rel)
    rel = rel or self._parent
    self._pts = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } }
end)
rec("SetParent", function(self, p) self._parent = p end)
rec("SetVertexColor", function(self, r, g, b, a) self._vc = { r, g, b, a or 1 } end)
rec("SetColorTexture", function(self, r, g, b, a) self._tex = "COLOR"; self._vc = { r, g, b, a or 1 } end)
rec("SetStatusBarColor", function(self, r, g, b, a) self._sbc = { r, g, b, a or 1 } end)
rec("SetStatusBarTexture", function(self, t) self._sbt = t end)
rec("SetTextColor", function(self, r, g, b, a) self._tc = { r, g, b, a or 1 } end)
rec("SetFont", function(self, path, size, flags) self._fs, self._fl = size, flags; return true end)
rec("SetJustifyH", function(self, j) self._jh = j end)
rec("SetWordWrap", function(self, w) self._wrap = w end)
rec("SetMaxLines", function(self, n) self._maxLines = n end)
rec("GetStringHeight", function(self)
    local size = self._fs or 12
    local plain = tostring(self._text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local w = self._w or 0
    local lines = (self._wrap and w > 0) and math.max(1, math.ceil(#plain * size * 0.52 / w)) or 1
    return lines * size * 1.25
end)
rec("SetDesaturated", function(self, d) self._desat = d end)
rec("SetFrameLevel", function(self, l) self._level = l end)
rec("SetFrameStrata", function(self, s) self._strata = s end)
rec("SetDrawLayer", function(self, l) self._layer = l end)
rec("SetTextureSliceMargins", function(self) self._sliced = true end)
rec("SetScale", function(self, s) self._scale = s end)
level = function(o)
    if o._level then return o._level end
    if not o._parent then return 0 end
    return level(o._parent) + 1
end
rec("GetFrameLevel", function(self) return level(self) end)
-- like WoW: a frame sized by its anchors reports that size
rec("GetWidth", function(self)
    if (self._w or 0) > 0 or not self._pts or #self._pts < 2 then return self._w or 0 end
    local saved = cache; cache = {}; local r = RECT(self); cache = saved; return r.r - r.l
end)
rec("GetHeight", function(self)
    if (self._h or 0) > 0 or not self._pts or #self._pts < 2 then return self._h or 0 end
    local saved = cache; cache = {}; local r = RECT(self); cache = saved; return r.t - r.b
end)
rec("SetScrollChild", function(self, c)
    self._child = c
    c._pts = c._pts and #c._pts > 0 and c._pts or { { "TOPLEFT", self, "TOPLEFT", 0, 0 } }
    c._scrollParent = self
end)
-- native aura buttons: remember what the client would fill
rec("SetIcon", function(self, t) self._nIcon = t end)
rec("SetApplicationCount", function(self, fs) self._nCount = fs end)
rec("SetApplicationBar", function(self, bar, o) self._nAppBar, self._nMax = bar, o.maxApplications end)
rec("SetDurationBar", function(self, bar) self._nDurBar = bar end)
rec("SetDurationText", function(self, fs) self._nDurText = fs end)
rec("SetDurationCooldown", function(self, cd) self._nCd = cd end)
local layerOf = {}
local oldCT, oldCF = Object.CreateTexture, Object.CreateFontString
rec("CreateTexture", function(self, name, layer, inh, sub) local t = oldCT(self); t._layer = layer; t._sub = sub or 0; return t end)
rec("CreateFontString", function(self, name, layer) local t = oldCF(self); t._layer = layer or "OVERLAY"; return t end)
end
local C = assert(loadstring(src, "client"))()
local all, NS = C.allFrames, C.NS

---------------------------------------------------------------------------
-- layout resolution (WoW coordinates: origin bottom-left, y up)
---------------------------------------------------------------------------
local FR = {
    TOPLEFT = { 0, 1 }, TOP = { .5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, .5 }, CENTER = { .5, .5 },
    RIGHT = { 1, .5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { .5, 0 }, BOTTOMRIGHT = { 1, 0 },
}
local W, H = 1920, 1080
local function rect(o)
    cache = cache or {}
    if o == UIParent then return { l = 0, b = 0, r = W, t = H } end
    if cache[o] then return cache[o] end
    cache[o] = { l = 0, b = 0, r = 0, t = 0 }   -- cycle guard
    local xs, ys = {}, {}
    for _, p in ipairs(o._pts or {}) do
        local rr = rect(p[2] or UIParent)
        local fr, fp = FR[p[3]] or FR.CENTER, FR[p[1]] or FR.CENTER
        xs[#xs + 1] = { fp[1], rr.l + fr[1] * (rr.r - rr.l) + p[4] }
        ys[#ys + 1] = { fp[2], rr.b + fr[2] * (rr.t - rr.b) + p[5] }
    end
    local function solve(cons, size)
        if #cons >= 2 then
            local a, b = cons[1], cons[#cons]
            for _, c in ipairs(cons) do if c[1] ~= a[1] then b = c end end
            if a[1] ~= b[1] then
                local lo = a[2] - a[1] * ((b[2] - a[2]) / (b[1] - a[1]))
                local hi = lo + (b[2] - a[2]) / (b[1] - a[1])
                return lo, hi
            end
        end
        if #cons >= 1 then local lo = cons[1][2] - cons[1][1] * size; return lo, lo + size end
        return nil
    end
    local pr = rect(o._parent or UIParent)
    local ow, oh = o._w or 0, o._h or 0
    if o._kind == "FontString" then
        -- WoW sizes a FontString from its text; estimate it (Friz Quadrata ~0.52 em per char)
        local size = o._fs or 12
        local plain = tostring(o._text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        local tw = #plain * size * 0.52
        if ow == 0 then
            if #xs >= 2 then local lo, hi = solve(xs, 0); ow = hi - lo else ow = tw end
        end
        local lines = (o._wrap and ow > 0) and math.max(1, math.ceil(tw / ow)) or 1
        if o._maxLines then lines = math.min(lines, o._maxLines) end
        if oh == 0 then oh = lines * size * 1.25 end
    end
    local l, r = solve(xs, ow)
    local b, t = solve(ys, oh)
    local res = { l = l or pr.l, r = r or (l and l + (o._w or 0)) or pr.r, b = b or pr.b, t = t or (b and b + (o._h or 0)) or pr.t,
        nopts = not o._pts or #o._pts == 0, oneX = #xs < 2 }
    cache[o] = res
    return res
end

RECT = rect
local function visible(o)
    local a = 1
    while o do
        if o._shown == false then return false end
        a = a * (o._alpha or 1)
        o = o._parent
    end
    return a > 0.01, a
end

---------------------------------------------------------------------------
-- HTML
---------------------------------------------------------------------------
local function css(c, mul)
    c = c or { 1, 1, 1, 1 }
    return string.format("rgba(%d,%d,%d,%.2f)", c[1] * 255, c[2] * 255, c[3] * 255, (c[4] or 1) * (mul or 1))
end
-- icon URL, or "spell:<id>" for an ID not in iconmap.json yet (shot.js looks it up and caches it)
local ZAM = "https://wow.zamimg.com/images/wow/icons/large/"
local function iconFile(t)
    if type(t) == "number" then
        local id = t > 1000 and t - 1000 or t   -- the fake client's GetSpellTexture returns 1000 + spellID
        return ICON[id] and (ZAM .. ICON[id] .. ".jpg") or ("spell:" .. id)
    end
    if type(t) == "string" then
        local n = t:match("[Ii]cons\\(.+)$")
        if n then return ZAM .. n:lower() .. ".jpg" end
    end
end
local RAD = { lg = 10, sm = 4, xs = 2 }
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, TOOLTIP = 7 }
local LAYER = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4 }
local function strata(o) while o do if o._strata then return STRATA[o._strata] or 3 end o = o._parent end return 3 end
local function esc(s) return (tostring(s):gsub("|c%x%x(%x%x%x%x%x%x)(.-)|r", '<span style="color:#%1">%2</span>'):gsub("|r", "")) end

local function draw(o, list, idx)
    local vis, alpha = visible(o)
    if not vis then return end
    local r = rect(o)
    local w, h = r.r - r.l, r.t - r.b
    local x, y = r.l, H - r.t
    local key = { strata(o), level(o), 0, o._sub or 0, idx }
    local html
    if o._kind == "Texture" then
        if r.nopts then return end
        key[2] = level(o._parent); key[3] = LAYER[o._layer or "ARTWORK"] or 3
        local t = o._tex
        local file = iconFile(t)
        local style = string.format("left:%.1fpx;top:%.1fpx;width:%.1fpx;height:%.1fpx;", x, y, w, h)
        if file then
            html = string.format('<img src="%s" style="position:absolute;%sobject-fit:cover;opacity:%.2f;%s">', file, style, alpha * ((o._vc or {})[4] or 1),
                o._desat and "filter:grayscale(1);" or "")
        elseif type(t) == "string" and t:find("Media") then
            local base, shape = t:match("Media\\(%a+)_(%a+)$")
            local name = t:match("Media\\(%a+)$")
            local rad = RAD[shape] or (name == "Circle" and 999) or 0
            if base == "Border" then
                html = string.format('<div style="position:absolute;%sborder:1px solid %s;border-radius:%dpx"></div>', style, css(o._vc, alpha), rad)
            elseif base == "Glow" then
                html = string.format('<div style="position:absolute;%sborder:2px solid %s;border-radius:%dpx;box-shadow:0 0 6px %s"></div>', style, css(o._vc, alpha), rad + 2, css(o._vc, alpha))
            else
                html = string.format('<div style="position:absolute;%sbackground:%s;border-radius:%dpx"></div>', style, css(o._vc, alpha), rad)
            end
        elseif t then
            html = string.format('<div style="position:absolute;%sbackground:%s"></div>', style, css(o._vc, alpha))
        end
    elseif o._kind == "FontString" then
        if not o._text or o._text == "" or r.nopts then return end
        key[2] = level(o._parent); key[3] = LAYER[o._layer or "OVERLAY"] or 4
        local size = o._fs or 12
        local fp = FR[o._pts[1][1]] or FR.CENTER
        local align = (o._jh and o._jh:lower()) or (r.oneX and (fp[1] == 0 and "left" or fp[1] == 1 and "right" or "center")) or "left"
        if r.oneX then align = fp[1] == 0 and "left" or fp[1] == 1 and "right" or "center" end
        local just = align == "left" and "flex-start" or align == "right" and "flex-end" or "center"
        local shadow = (o._fl or ""):find("OUTLINE") and "text-shadow:0 0 2px #000,0 0 2px #000,0 0 1px #000;" or ""
        local wrap = o._wrap and "white-space:normal;" or "white-space:nowrap;"
        html = string.format('<div style="position:absolute;left:%.1fpx;top:%.1fpx;width:%.1fpx;height:%.1fpx;display:flex;align-items:center;justify-content:%s;text-align:%s;font-size:%.1fpx;line-height:1.2;color:%s;%s%s"><span>%s</span></div>',
            r.l, H - r.t, r.r - r.l, r.t - r.b, just, align, size, css(o._tc, alpha), wrap, shadow, esc(o._text))
    elseif o._kind == "StatusBar" and o._sbc then
        local lo, hi, v = o._min or 0, o._max or 1, o._val or 0
        if type(v) ~= "number" or type(hi) ~= "number" then return end
        local frac = hi > lo and math.max(0, math.min(1, (v - lo) / (hi - lo))) or 0
        key[3] = 3.5
        html = string.format('<div style="position:absolute;left:%.1fpx;top:%.1fpx;width:%.1fpx;height:%.1fpx;background:%s;border-radius:2px"></div>',
            x + 1, y + 1, math.max(0, (w - 2) * frac), math.max(0, h - 2), css(o._sbc, alpha))
    end
    if html then list[#list + 1] = { key = key, html = html } end
end

local function render(file, title, crop)
    cache = {}
    local list = {}
    for i, o in ipairs(all) do draw(o, list, i) end
    table.sort(list, function(a, b)
        for i = 1, 5 do if a.key[i] ~= b.key[i] then return a.key[i] < b.key[i] end end
        return false
    end)
    local out = {}
    out[#out + 1] = '<!doctype html><meta charset="utf-8"><style>body{margin:0;background:#000;font-family:"Friz Quadrata TT",Georgia,serif;overflow:hidden}'
        .. '#s{position:relative;width:' .. W .. 'px;height:' .. H .. 'px;background:radial-gradient(ellipse at 50% 40%,#3b4a3c 0%,#1f2b24 50%,#0e1411 100%)}</style>'
        .. '<div id="s"><div style="position:absolute;left:12px;top:10px;font:600 14px system-ui;color:#fff;background:rgba(0,0,0,.6);padding:4px 9px;border-radius:6px;z-index:9">'
        .. title .. '</div><div style="position:absolute;right:12px;top:10px;font:13px system-ui;color:#ffd7a0;background:rgba(0,0,0,.6);padding:4px 9px;border-radius:6px;z-index:9">Rendered from the addon\'s frames (offline client) - not an in-game screenshot</div>'
    for _, e in ipairs(list) do out[#out + 1] = e.html end
    out[#out + 1] = '</div>'
    os.execute('mkdir -p "' .. OUT .. '"')
    local f = assert(io.open(OUT .. file .. ".html", "w"))
    f:write(table.concat(out, "\n"))
    f:close()
    io.open(OUT .. file .. ".crop", "w"):write(crop or "0,0,1920,1080")
end

return { C = C, render = render, rect = function(o) cache = {}; return rect(o) end }

// Render check: builds the scenes (tests/render/scene.lua) and screenshots them to
// tests/render/out/*.png. Look at every PNG after a change.
//   node tests/render/shot.js        (needs lua5.1, Playwright with Chromium, network for icons)
// Spell icons come from Wowhead's Forever data; new spell IDs are looked up once and cached
// in iconmap.json (commit it).
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const dir = __dirname;
const root = path.resolve(dir, '..', '..');
const out = path.join(dir, 'out');
const mapFile = path.join(dir, 'iconmap.json');

(async () => {
  execFileSync('lua5.1', [path.join(root, 'tests', 'render', 'scene.lua')], { cwd: root, stdio: 'inherit' });
  const map = JSON.parse(fs.readFileSync(mapFile, 'utf8'));
  let changed = false, warnings = 0;
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 2 });
  for (const f of fs.readdirSync(out).filter(f => f.endsWith('.html')).sort()) {
    const name = f.replace(/\.html$/, '');
    let html = fs.readFileSync(path.join(out, f), 'utf8');
    for (const id of new Set([...html.matchAll(/src="spell:(\d+)"/g)].map(m => m[1]))) {
      if (!map[id]) {
        try {
          const r = await fetch(`https://nether.wowhead.com/forever/tooltip/spell/${id}`);
          const icon = (await r.json()).icon;
          if (icon) { map[id] = icon; changed = true; }
        } catch (e) { /* offline: the icon stays empty */ }
      }
      if (map[id]) html = html.split(`src="spell:${id}"`).join(`src="https://wow.zamimg.com/images/wow/icons/large/${map[id]}.jpg"`);
    }
    await page.setContent(html, { waitUntil: 'networkidle' });
    // text check: wider than its field, sticking out of its frame, or on top of another text
    for (const m of await page.evaluate(() => {
      const out = [], T = [];
      // plates: nearly opaque surfaces; a text on one covers what lies beneath (edit-mode overlays)
      const all = [...document.querySelectorAll('#s > *')], plates = [];
      all.forEach((e, i) => {
        const m = e.className !== 't' && getComputedStyle(e).backgroundColor.match(/rgba?\(([^)]+)\)/);
        const c = m && m[1].split(',').map(Number);
        if (c && (c.length < 4 || c[3] >= 0.7)) plates.push({ i, r: e.getBoundingClientRect() });
      });
      for (const d of document.querySelectorAll('.t')) {
        const s = d.firstChild, r = s.getBoundingClientRect(), b = d.getBoundingClientRect();
        const [pl, pr] = d.dataset.p.split(',').map(Number), text = JSON.stringify(s.textContent);
        const nowrap = getComputedStyle(d).whiteSpace === 'nowrap';
        if (d.dataset.fixed === '1' && nowrap && r.width > b.width + 1) out.push(`${text} is ${Math.round(r.width - b.width)}px wider than its field`);
        else if (s.scrollHeight > s.clientHeight + 1) out.push(`${text} is cut off (more lines than it may show)`);
        else if (r.right > pl && r.left < pr && (r.left < pl - 1 || r.right > pr + 1)) out.push(`${text} sticks out of its frame`);
        T.push({ text, i: all.indexOf(d), z: d.dataset.z, l: r.left, r: Math.min(r.right, d.dataset.fixed === '1' && nowrap ? b.right : 1e9), t: r.top + r.height * 0.15, b: r.bottom - r.height * 0.15 });
      }
      for (let i = 0; i < T.length; i++) for (let j = i + 1; j < T.length; j++) {
        const a = T[i], c = T[j];   // same strata only: a window may cover the HUD
        if (!(a.z === c.z && a.l < c.r - 1 && c.l < a.r - 1 && a.t < c.b - 1 && c.t < a.b - 1)) continue;
        if (plates.some(p => p.i > a.i && p.i < c.i && p.r.left <= c.l + 1 && p.r.right >= c.r - 1 && p.r.top <= c.t + 1 && p.r.bottom >= c.b - 1)) continue;
        out.push(`${a.text} overlaps ${c.text}`);
      }
      return out;
    })) { console.log(`  ! ${name}: ${m}`); warnings++; }
    const [x, y, w, h] = fs.readFileSync(path.join(out, name + '.crop'), 'utf8').split(',').map(Number);
    await page.screenshot({ path: path.join(out, name + '.png'), clip: { x, y, width: w, height: h } });
    console.log('out/' + name + '.png');
  }
  await browser.close();
  console.log(warnings ? `text check: ${warnings} to look at` : 'text check: all good');
  if (changed) fs.writeFileSync(mapFile, JSON.stringify(map, null, 1) + '\n');
})();

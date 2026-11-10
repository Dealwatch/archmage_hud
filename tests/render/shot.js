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
  let changed = false;
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
    const [x, y, w, h] = fs.readFileSync(path.join(out, name + '.crop'), 'utf8').split(',').map(Number);
    await page.screenshot({ path: path.join(out, name + '.png'), clip: { x, y, width: w, height: h } });
    console.log('out/' + name + '.png');
  }
  await browser.close();
  if (changed) fs.writeFileSync(mapFile, JSON.stringify(map, null, 1) + '\n');
})();

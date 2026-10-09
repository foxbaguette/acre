// Imports the island renderer from topdown/tiles.html into the game page:
//   src/game/renderer.js   the page script as one function, startIsland({ tiles, mapId, weather })
//   public/art/tiles/...   the tile art it draws with
// Run from web/: node scripts/import-renderer.mjs  (re-run after changing tiles.html)
//
// The renderer keeps its own element ids (#view, #field, #fx, #live, #weather, #labels, #zin, #zout, #zfit,
// [data-weather] buttons and a few hidden switches); src/components/GamePage.tsx renders them.
import { cpSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs'

const page = readFileSync('../topdown/tiles.html', 'utf8')
let js = page.slice(page.indexOf('<script>\n') + 9, page.indexOf('\n</script>'))
const rep = (a, b) => {
  if (!js.includes(a)) throw new Error('renderer changed, marker not found: ' + a.slice(0, 60))
  js = js.replace(a, b)
}

// the art sheet's galleries are not part of the game
js = js.split('\n').filter((l) => !/^document\.getElementById\('(grass|fences|bridges|other)'\)\.innerHTML/.test(l)).join('\n')
// art lives under /art; a fixed version so the browser may cache it
rep('const v = Date.now();', 'const v = 1;')
rep('const src = n => `../tiles/${n}.svg?v=${v}`;', 'const src = n => `/art/tiles/${n}.svg?v=${v}`;')
rep('const cropSrc = (c, st) => `../crops/${c}/${st}.svg?v=${v}`;', 'const cropSrc = (c, st) => `/art/crops/${c}/${st}.svg?v=${v}`;')
rep('const spriteUrl = k => `${k}/top.svg?v=${v}`;', 'const spriteUrl = k => `/art/topdown/${k}/top.svg?v=${v}`;')
// game settings: the island only, and no creatures the player does not own; never the art sheet's saved settings
rep("try { Object.assign(CFG, JSON.parse(localStorage.getItem('island-cfg') || '{}')); } catch (e) {}",
  "Object.assign(CFG, CFG_PRESETS['Just the island'], { landCreatures: false, waterCreatures: false, flyers: false }, opts.cfg || {});")
// start with the given map instead of the art sheet's map picker, framed on the island
rep('buildPanel(); applyLook(); startAnim(); loadMaps();', `applyLook();
CHAIN.map = { map_id: Number(opts.mapId) }; CHAIN.raw = opts.tiles; mode = 'mixed'; CAM.z = 0;
const ready = build().then(() => new Promise(r => {           // the island shows once its masks are built and the first view is fully painted
  const t0 = performance.now(), chk = () => (VIEW_PENDING && performance.now() - t0 < 3000 ? requestAnimationFrame(chk) : r()); requestAnimationFrame(chk); }));
{ // frame the land, with a little sea around it
  let x0 = COLS, y0 = ROWS, x1 = 0, y1 = 0;
  MAP.cells.forEach((c, i) => { if (c.ocean) return; const x = i % COLS, y = (i - x) / COLS; x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); });
  const W = view().clientWidth, H = view().clientHeight;
  if (x1 >= x0) { CAM.z = Math.max(zMin(), Math.min(W / (x1 - x0 + 14), H / (y1 - y0 + 14))); CAM.x = (x0 + x1 + 1) / 2 - W / CAM.z / 2; CAM.y = (y0 + y1 + 1) / 2 - H / CAM.z / 2; clampCam(); redraw(); }
}
startAnim();
if (WX[opts.weather]) setWeather(opts.weather);
if (DAYS[opts.daytime]) setDaytime(opts.daytime);
return { setWeather, setDaytime, fit, zoomAt, redraw, ready, debug: { CAM, FX, PAINT, PERF, RASTER, LOW, CHUNKS, SKIP, LIVE, setLowTier, DPR, visible, paintChunk, paintGround, bmpCache, MAP: () => MAP, CH, tileLevel, boxPaths, loopsInBox, BOXPATHS, chunkTiles } };`)
rep("{ const h = new URLSearchParams(location.hash.slice(1)); if (WX[h.get('weather')]) setWeather(h.get('weather')); if (DAYS[h.get('daytime')]) setDaytime(h.get('daytime')); }   // e.g. tiles.html#weather=storm&daytime=night", '')

mkdirSync('src/game', { recursive: true })
writeFileSync('src/game/renderer.js', `// Imported from topdown/tiles.html by scripts/import-renderer.mjs. Do not edit here.
/* eslint-disable */
// @ts-nocheck
export function startIsland(opts) {
${js}
}
`)
cpSync('../tiles', 'public/art/tiles', { recursive: true })
console.log('renderer', js.length, 'chars; tiles copied')

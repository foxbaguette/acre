// The island as data: ground types, mountains, forests, the tile picked for every cell, small details, lush and dry
// grass, and where trees, butterflies and fireflies live. Built from a map's tile bytes on the chain.
//
// Every random choice comes from one generator seeded with the map id, in the same order as the old canvas
// renderer (topdown/tiles.html) made them, so a map looks exactly as it did there, down to each tree and flower.

export const COLS = 100
export const ROWS = 100

/** Ground types, as the renderer knows them. */
export const T = { grass: 0, sand: 1, rock: 2, soil: 3, path: 4, water: 5 } as const
export type Ground = (typeof T)[keyof typeof T]
export const TYPE_NAMES = ['grass', 'sand', 'rock', 'soil', 'path', 'water'] as const

export const GRASS = Array.from({ length: 20 }, (_, i) => `grass-${String(i + 1).padStart(2, '0')}`)
export const PATH = ['path-01', 'path-02', 'path-03', 'path-04']
export const WATER = Array.from({ length: 6 }, (_, i) => `water-${String(i + 1).padStart(2, '0')}`)
export const SAND = ['sand-01', 'sand-02', 'sand-03', 'sand-04']
export const SEA = Array.from({ length: 6 }, (_, i) => `sea-0${i + 1}`)
export const ROCK = ['rock-01', 'rock-02', 'rock-03', 'rock-04']
export const TREES = ['tree-01', 'tree-02', 'tree-03', 'tree-04', 'tree-05', 'tree-06']
/** Every ground tile, in the order of the GPU's tile array. */
export const GROUND_TILES = [...GRASS, ...PATH, ...WATER, ...SAND, ...SEA, ...ROCK, 'soil']
export const tileIndex = new Map(GROUND_TILES.map((n, i) => [n, i]))
/** The crops a random farm picks its favourites from (only their count matters here: it moves the random stream on). */
const CROP_COUNT = 46

/** Height of one mountain level, in tiles. */
export const LIFT = 0.42

export interface Decor { x: number; y: number; name: string; sc: number; under: boolean }
export interface Tree { x: number; y: number; lift: number; name: string; sc: number; sw: number; phase: number }
export interface Fly { cx: number; cy: number; a: number; b: number; sp: number; ci: number }
export interface Swarm { cx: number; cy: number; a: number; sp: number; flies: { r: number; a0: number; w: number; b: number; bob: number }[] }

export interface World {
  cols: number
  rows: number
  /** ground type per cell (T) */
  type: Uint8Array
  /** water joined to the open sea */
  ocean: Uint8Array
  /** mountain height 0-5 */
  elev: Uint8Array
  /** 1 forest on grass, 2 forest on a mountain, 3 a lone tree */
  forest: Uint8Array
  /** tile array index of each cell's own tile */
  tile: Uint8Array
  /** the tile below a cell's edges: grass under most things, or the neighbouring ground */
  under: Uint8Array
  /** for each cell, the tile it shows where another ground reaches into it: rock, sand, path, water */
  fillRock: Uint8Array
  fillSand: Uint8Array
  fillPath: Uint8Array
  fillWater: Uint8Array
  decor: Decor[]
  /** lush and dry grass: premultiplied rgba per cell, already softened */
  tint: Float32Array
  /** the soft wobble of every edge: a noise grid at half-tile spacing */
  noise: Float32Array
  nw: number
  nh: number
  trees: Tree[]
  flies: Fly[]
  swarms: Swarm[]
  /** which ground types are present at all */
  has: boolean[]
}

/** The generator the old renderer used, so the same seed gives the same numbers. */
export const seeded = (seed: number) => {
  let s = seed | 0
  return () => {
    s = (s + 0x6d2b79f5) | 0
    let t = Math.imul(s ^ (s >>> 15), 1 | s)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

/** What the generator may do. The game shows the island only: no farms, no roads, no ambient creatures. */
export const CFG = {
  mountainChance: 75, riverChance: 35, lakeChance: 50, pondsMin: 1, pondsMax: 6,
  forestEdges: true, decor: true, decorDensity: 100, meadows: true, meadowAmount: 100, grassTint: true, tintStrength: 100,
  butterflies: true,
}

/** Builds the island from the chain's tile bytes (bits 0-2 ground, 3-5 mountain height, 6 trees). */
export function buildWorld(raw: Uint8Array, mapId: number): World {
  const R = seeded(mapId * 7919 + 17)
  const cols = COLS, rows = ROWS, N = cols * rows
  const at = (x: number, y: number) => y * cols + x
  const inside = (x: number, y: number) => x >= 0 && y >= 0 && x < cols && y < rows
  const pick = <V>(a: readonly V[]) => a[Math.floor(R() * a.length)]
  const rint = (a: number, b: number) => a + Math.floor(R() * (b - a + 1))
  const chance = (pct: number) => R() * 100 < pct
  const between = (lo: number, hi: number) => { const a = Math.min(lo, hi), b = Math.max(lo, hi); return a + R() * (b - a) }
  const smooth = (sc: number) => {                              // smooth value noise, sc = cells per noise step
    const gw = Math.ceil(cols / sc) + 2, gh = Math.ceil(rows / sc) + 2, g = Float32Array.from({ length: gw * gh }, () => R() * 2 - 1)
    return (x: number, y: number) => {
      const fx = x / sc, fy = y / sc, ix = Math.floor(fx), iy = Math.floor(fy), tx = fx - ix, ty = fy - iy, sx = tx * tx * (3 - 2 * tx), sy = ty * ty * (3 - 2 * ty)
      const n = (i: number, j: number) => g[(iy + j) * gw + ix + i]
      return (n(0, 0) * (1 - sx) + n(1, 0) * sx) * (1 - sy) + (n(0, 1) * (1 - sx) + n(1, 1) * sx) * sy
    }
  }

  // the recipe: rolled even for a chain map, which uses none of it, because the old renderer did
  chance(CFG.mountainChance); chance(CFG.riverChance); chance(CFG.lakeChance)
  Math.round(between(CFG.pondsMin, CFG.pondsMax)); rint(5, 9); rint(2, 5)

  const type = new Uint8Array(N), ocean = new Uint8Array(N), elev = new Uint8Array(N), forest = new Uint8Array(N), lake = new Uint8Array(N)
  const GROUND = [T.water, T.water, T.sand, T.grass, T.rock, T.soil, T.path]   // 0 sea, 1 fresh water, 2 beach, 3 grass, 4 mountain, 5 field, 6 road
  for (let i = 0; i < N; i++) {
    const b = raw[i], g = b & 7
    type[i] = GROUND[g] ?? T.grass
    if (g <= 1) lake[i] = 1
    if (g === 0) ocean[i] = 1
    if (g === 4) elev[i] = Math.min(5, (b >> 3) & 7)
    if (b & 64) forest[i] = g === 4 ? 2 : g === 3 ? 1 : 0
  }
  for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {   // a tree with no wooded neighbour is a lone tree at a forest edge
    const i = at(x, y)
    if (forest[i] === 1 && ![[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => inside(x + dx, y + dy) && forest[at(x + dx, y + dy)])) forest[i] = 3
  }
  const near = (x: number, y: number, t: number, d = 1) => { for (let j = -d; j <= d; j++) for (let i = -d; i <= d; i++) if (inside(x + i, y + j) && type[at(x + i, y + j)] === t) return true; return false }

  // forest edges, small details and lush/dry grass
  const D = CFG.decorDensity / 100, decor: Decor[] = [], pond = (i: number) => type[i] === T.water && !ocean[i]
  const nearF = (x: number, y: number, d: number) => { for (let j = -d; j <= d; j++) for (let k = -d; k <= d; k++) if (inside(x + k, y + j) && forest[at(x + k, y + j)]) return true; return false }
  const nearP = (x: number, y: number, d: number) => { for (let j = -d; j <= d; j++) for (let k = -d; k <= d; k++) if (inside(x + k, y + j) && pond(at(x + k, y + j))) return true; return false }
  const put = (x: number, y: number, name: string, sc: number) => { const dx = (R() - 0.5) * 0.5, dy = (R() - 0.5) * 0.5; decor.push({ x: x + dx, y: y + dy, name: 'decor-' + name, sc, under: false }) }
  const freeGrass = (i: number) => type[i] === T.grass && !forest[i]
  if (CFG.forestEdges) for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
    const i = at(x, y); if (!freeGrass(i) || !nearF(x, y, 2)) continue
    const r = R()
    if (r >= 0.13 && r < 0.22) { const n = pick(['bush-1', 'bush-2']); put(x, y, n, 0.55 + R() * 0.25) }
  }
  if (CFG.decor) for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
    const i = at(x, y), t = type[i], r = R()
    if (t === T.water && pond(i) && r < 0.1 * D && near(x, y, T.grass, 1)) put(x, y, 'lily', 0.55)
    else if ((t === T.grass || t === T.sand) && !forest[i] && nearP(x, y, 1) && r < 0.4 * D) { const n = pick(['reeds-1', 'reeds-2']); put(x, y, n, 0.6 + R() * 0.25) }
    else if (freeGrass(i) && r < 0.035 * D) { const n = pick(['bush-1', 'bush-2', 'flowers-1', 'flowers-2', 'flowers-1', 'stone-1', 'stone-2', 'stump']); put(x, y, n, 0.45 + R() * 0.3) }
    else if (t === T.sand && r < 0.03 * D) { const n = pick(['driftwood', 'stone-2', 'driftwood']); put(x, y, n, 0.5 + R() * 0.2) }
    else if (t === T.rock && elev[i] === 0 && r < 0.06 * D) { const n = pick(['stone-1', 'stone-2']); put(x, y, n, 0.5) }
  }
  if (CFG.meadows) {                                           // meadow patches: one kind per patch, on open grass only
    const m1 = smooth(8), m2 = smooth(19), A = CFG.meadowAmount / 100, th = 0.55 - 0.25 * A
    const kinds = ['meadow-yellow', 'meadow-white', 'meadow-purple', 'meadow-tall', 'meadow-clover']
    for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
      const i = at(x, y)
      if (!freeGrass(i) || m1(x, y) < th || R() > 0.8) continue
      const k = kinds[Math.max(0, Math.min(kinds.length - 1, Math.floor((m2(x, y) + 1) / 2 * kinds.length)))]
      put(x, y, k, 1.05 + R() * 0.15); decor[decor.length - 1].under = true
    }
  }
  decor.sort((a, b) => (Number(b.under) - Number(a.under)) || a.y - b.y)   // meadow carpets first, then the rest top to bottom
  const tint = new Float32Array(N * 4)
  { const n1 = smooth(14), k = CFG.tintStrength / 100
    for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
      const v = n1(x, y) * 0.55 + (nearP(x, y, 3) ? 0.45 : 0) + (nearF(x, y, 2) ? 0.35 : 0) - (near(x, y, T.sand, 2) ? 0.45 : 0)
      const [r, g, b, a] = v >= 0 ? [40, 74, 30, Math.min(0.22, v * 0.27) * k] : [196, 176, 104, Math.min(0.24, -v * 0.3) * k]
      const o = (y * cols + x) * 4; tint[o] = r / 255 * a; tint[o + 1] = g / 255 * a; tint[o + 2] = b / 255 * a; tint[o + 3] = a
    }
    blurGrid(tint, cols, rows, 4, 2.5)                          // the patches fade into each other over a couple of tiles
  }

  { const st: number[] = []; for (let i = 0; i < N; i++) if (ocean[i]) st.push(i)   // any water joined to the sea is sea, not a pond
    while (st.length) { const j = st.pop()!, x = j % cols, y = (j - x) / cols
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const nx = x + dx, ny = y + dy; if (!inside(nx, ny)) continue; const q = at(nx, ny); if (!ocean[q] && type[q] === T.water) { ocean[q] = 1; st.push(q) } } } }

  // the tile of every cell, and what shows where another ground reaches in
  const pickGrass = () => R() < 0.55 ? GRASS[[0, 1, 2, 12][Math.floor(R() * 4)]] : GRASS[Math.floor(R() * 20)]
  const idx = (n: string) => tileIndex.get(n)!
  const tile = new Uint8Array(N), under = new Uint8Array(N), fillRock = new Uint8Array(N), fillSand = new Uint8Array(N), fillPath = new Uint8Array(N), fillWater = new Uint8Array(N)
  for (let i = 0; i < N; i++) {
    const t = type[i]
    tile[i] = idx(t === T.soil ? 'soil' : t === T.rock ? pick(ROCK) : t === T.sand ? pick(SAND) : t === T.path ? pick(PATH) : t === T.water ? pick(WATER) : pickGrass())
    under[i] = idx(pickGrass())
    fillRock[i] = idx(pick(ROCK)); fillSand[i] = idx(pick(SAND)); fillPath[i] = idx(pick(PATH)); fillWater[i] = idx(pick(WATER))
  }
  for (let i = 0; i < N; i++) {                                // the open sea gets its own darker, wavier tiles
    const x = i % cols, y = (i - x) / cols; let nearSea = false
    for (let j = -2; j <= 2 && !nearSea; j++) for (let k = -2; k <= 2 && !nearSea; k++) if (inside(x + k, y + j) && ocean[at(x + k, y + j)]) nearSea = true
    let nearPond = false; for (let j = -1; j <= 1 && !nearPond; j++) for (let k = -1; k <= 1 && !nearPond; k++) { const q = at(x + k, y + j); if (inside(x + k, y + j) && type[q] === T.water && !ocean[q]) nearPond = true }
    if (nearSea && !nearPond) fillWater[i] = idx(pick(SEA))
    if (ocean[i] && type[i] === T.water) tile[i] = fillWater[i]
  }
  { const n = rint(5, 9); for (let k = 0; k < n; k++) Math.floor(R() * CROP_COUNT) }   // this farm's main crops (none on a chain map)
  const nw = cols * 2 + 3, nh = rows * 2 + 3
  const noise = Float32Array.from({ length: nw * nh }, () => R() * 2 - 1)

  // Under the edge between two kinds of ground, grass must not peek through: below a sand, rock, field or path cell
  // that borders another kind lies its own kind, and below water that borders such ground lies that ground; not where
  // grass is also next door, since that border needs grass below its curve. Open sea lies on sea.
  const PREF = [T.sand, T.rock, T.soil, T.path] as number[]
  for (let i = 0; i < N; i++) {
    const t = type[i]; if (t === T.grass) continue
    const x = i % cols, y = (i - x) / cols; let other = -1
    for (let j = -1; j <= 1; j++) for (let k = -1; k <= 1; k++) { const X = x + k, Y = y + j
      if ((j || k) && inside(X, Y)) { const n = type[Y * cols + X]; if (n !== T.grass && n !== t && (other < 0 || PREF.indexOf(n) < PREF.indexOf(type[other]))) other = Y * cols + X } }
    if (other >= 0) {
      let grassNear = false; for (let j = -1; j <= 1 && !grassNear; j++) for (let k = -1; k <= 1; k++) { const X = x + k, Y = y + j; if (inside(X, Y) && type[Y * cols + X] === T.grass) { grassNear = true; break } }
      if (grassNear) continue
      const ot = type[other]
      under[i] = t === T.water ? (ot === T.rock ? fillRock[i] : ot === T.sand ? fillSand[i] : ot === T.path ? fillPath[i] : ot === T.soil ? idx('soil') : fillWater[i]) : tile[i]
      continue
    }
    if (ocean[i]) { let allSea = true; for (let j = -1; j <= 1 && allSea; j++) for (let k = -1; k <= 1; k++) { const X = x + k, Y = y + j; if (inside(X, Y) && !ocean[Y * cols + X]) { allSea = false; break } } if (allSea) under[i] = tile[i] }
  }

  // the water's glints were placed here once; they are on the GPU now, but the random stream still steps past them
  for (let i = 0; i < N; i++) if (type[i] === T.water) { for (let k = 0; k < 4 * 5 + 2 * 4; k++) R(); if (R() < 0.35) for (let k = 0; k < 4; k++) R() }

  // trees in the woods (taller than a tile)
  const trees: Tree[] = []
  for (let i = 0; i < N; i++) {
    const f = forest[i], t = type[i]; if (!f || (t !== T.grass && !(f === 2 && t === T.rock))) continue
    const e = f === 2 ? elev[i] : 0
    for (let k = 0, n = f >= 2 ? 1 : R() < 0.45 ? 2 : 1; k < n; k++) {
      const name = f === 2 && e >= 1 ? TREES[3 + Math.floor(R() * 3)] : pick(TREES)
      const x = i % cols + (R() - 0.5) * 0.5, y = Math.floor(i / cols) + (R() - 0.5) * 0.5 + k * 0.3, sc = 1.25 + R() * 0.3, phase = R() * 6.28
      trees.push({ lift: 0, name, x, y, sc, sw: 0.35, phase })   // trees stand on the relief where they grow: no plateau to lift onto
    }
  }
  trees.sort((a, b) => a.y - b.y)

  // butterflies stay over the island: they circle grass at least 3 tiles from the sea
  const home: [number, number][] = []
  if (CFG.butterflies) for (let y = 3; y < rows - 3; y++) for (let x = 3; x < cols - 3; x++) {
    if (type[y * cols + x] !== T.grass) continue
    let sea = false; for (let j = -3; j <= 3 && !sea; j++) for (let k = -3; k <= 3 && !sea; k++) sea = !!ocean[(y + j) * cols + x + k]
    if (!sea) home.push([x, y])
  }
  const flies: Fly[] = Array.from({ length: Math.round(home.length / 35) }, () => { const [x, y] = pick(home)
    const cx = x + R(), cy = y + R(), a = R() * 6.28, b = R() * 6.28, sp = 0.15 + R() * 0.15, ci = Math.floor(R() * 4); return { cx, cy, a, b, sp, ci } })
  // fireflies: little swarms of one to five on the banks of ponds and lakes and, less often, along the shore
  const banks: [number, number][] = []
  for (let y = 1; y < rows - 1; y++) for (let x = 1; x < cols - 1; x++) {
    const t = type[y * cols + x]; if (t !== T.grass && t !== T.sand) continue
    let fresh = false, sea = false
    for (let j = -2; j <= 2; j++) for (let k = -2; k <= 2; k++) { const X = x + k, Y = y + j; if (!inside(X, Y)) continue; const q = Y * cols + X; if (type[q] === T.water) { if (ocean[q]) sea = true; else fresh = true } }
    if (fresh) banks.push([x, y], [x, y], [x, y]); else if (sea && t === T.grass) banks.push([x, y])
  }
  const swarms: Swarm[] = Array.from({ length: Math.min(48, Math.round(banks.length / 24)) }, () => {
    const [x, y] = pick(banks), n = 1 + Math.floor(R() * 5)
    const cx = x + R(), cy = y + R(), a = R() * 6.28, sp = 0.04 + R() * 0.05
    const fl = Array.from({ length: n }, () => { const r = 0.12 + R() * 0.4, a0 = R() * 6.28, w = (0.2 + R() * 0.3) * (R() < 0.5 ? 1 : -1), b = R() * 6.28, bob = 0.04 + R() * 0.08; return { r, a0, w, b, bob } })
    return { cx, cy, a, sp, flies: fl }
  })

  const has = TYPE_NAMES.map((_, t) => type.some((v) => v === t))
  return { cols, rows, type, ocean, elev, forest, tile, under, fillRock, fillSand, fillPath, fillWater, decor, tint, noise, nw, nh, trees, flies, swarms, has }
}

/** A gaussian-like blur of an interleaved float grid (three box passes), clamped at the borders. sigma in cells. */
export function blurGrid(a: Float32Array, w: number, h: number, ch: number, sigma: number) {
  if (sigma <= 0.3) return
  const boxes = boxSizes(sigma), tmp = new Float32Array(a.length)
  for (const r of boxes) { boxPass(a, tmp, w, h, ch, r, true); boxPass(tmp, a, w, h, ch, r, false) }
}
/** Box radii whose three passes approximate a gaussian of this sigma. */
export function boxSizes(sigma: number): number[] {
  const n = 3, wIdeal = Math.sqrt((12 * sigma * sigma / n) + 1)
  let wl = Math.floor(wIdeal); if (wl % 2 === 0) wl--
  const wu = wl + 2, mIdeal = (12 * sigma * sigma - n * wl * wl - 4 * n * wl - 3 * n) / (-4 * wl - 4), m = Math.round(mIdeal)
  return Array.from({ length: n }, (_, i) => ((i < m ? wl : wu) - 1) / 2)
}
function boxPass(src: Float32Array, dst: Float32Array, w: number, h: number, ch: number, r: number, horizontal: boolean) {
  // a running sum along each line; the ends are clamped (the edge value repeats outside the grid)
  const n = horizontal ? w : h, lines = horizontal ? h : w, d = 2 * r + 1, inv = 1 / d
  const step = (horizontal ? 1 : w) * ch, lineStep = (horizontal ? w : 1) * ch, last = (n - 1) * step
  for (let line = 0; line < lines; line++) for (let c = 0; c < ch; c++) {
    const o = line * lineStep + c, first = src[o], end = src[o + last]
    let acc = first * (r + 1)
    for (let k = 1; k <= r; k++) acc += src[o + Math.min(k, n - 1) * step]
    for (let k = 0, at = o; k < n; k++, at += step) {
      dst[at] = acc * inv
      const add = k + r + 1, sub = k - r
      acc += (add < n ? src[o + add * step] : end) - (sub > 0 ? src[o + sub * step] : first)
    }
  }
}

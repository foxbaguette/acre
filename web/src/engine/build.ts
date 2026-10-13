// Building on the island: fences, paths, soil, crops, and erasing (builds, and the island's own trees and bushes). The
// chain's map stays as it is; the player's builds are kept per tile and laid over it (kept by the page; the contract
// has no action for them yet). Laying them always starts again from the island as the chain made it, so taking a
// build back is just laying a smaller set.
import { PATH, T, tileIndex, type World } from './world'

export type BuildTool = 'fence' | 'path' | 'soil' | 'crop' | 'tree' | 'erase' | 'harvest' | Building | 'upgrade'
export type Building = 'farmhouse' | 'lab' | 'nest' | 'silo' | 'bakery' | 'kitchen' | 'torch' | 'market'
/** The buildings: footprint in tiles (w across, h down, as drawn: entrance facing south), how many stages they can be
 *  upgraded through, and for those with a door, the column of the tile just in front of it (that tile must reach a path). */
export const BUILDINGS: Record<Building, { w: number; h: number; stages: number; art: (stage: number) => string; door?: number; doorY?: number; main?: boolean }> = {
  farmhouse: { w: 3, h: 4, stages: 5, art: (s) => `building-farmhouse-${s}`, door: 1, doorY: 3.72 },   // stage n: n farmers live there
  lab: { w: 4, h: 4, stages: 1, art: () => 'building-lab', door: 2, doorY: 3.5 },
  nest: { w: 2, h: 2, stages: 1, art: () => 'building-nest' },
  silo: { w: 2, h: 2, stages: 1, art: () => 'building-silo' },
  bakery: { w: 2, h: 2, stages: 1, art: () => 'building-bakery', door: 1, doorY: 1.8 },
  kitchen: { w: 3, h: 2, stages: 1, art: () => 'building-kitchen' },
  torch: { w: 1, h: 1, stages: 1, art: () => 'building-torch' },
  market: { w: 4, h: 5, stages: 1, art: () => 'building-market', door: 2, doorY: 4.9, main: true },   // open to the south; the main building: it needs no path, the others' paths come to it
}

/** What the player made on one tile. */
export interface CellBuild {
  /** the ground laid there */
  g?: 'soil' | 'path'
  /** a fence piece stands there */
  f?: 1
  /** a crop is growing there, and when it was sown (ms since 1970) */
  c?: string
  t?: number
  /** the crop is marked for harvest: a farmer will come for it */
  h?: 1
  /** a tree the player planted here (its kind: 1-3 broadleaf, 4-6 conifer) */
  p?: number
  /** cleared: the island's own trees, bushes and flowers there are gone */
  x?: 1
  /** a building stands here, its top-left tile at this index (on every tile it covers) */
  u?: number
  /** on a building's top-left tile: which building, and its stage */
  s?: Building
  lv?: number
  /** on a building's top-left tile: how it is turned, in quarter turns clockwise (0 entrance south, 1 west, 2 north, 3 east) */
  o?: number
  /** on a building's top-left tile: the path tiles laid to join its door to the paths */
  l?: number[]
}
/** Per tile index. */
export type Builds = Record<number, CellBuild>

/** The island as the chain made it, before any build. */
export interface Pristine { type: Uint8Array; tile: Uint8Array; forest: Uint8Array; trees: World['trees']; decor: World['decor']; hasSoil: boolean; hasPath: boolean }

export const pristineOf = (world: World): Pristine => ({
  type: world.type.slice(), tile: world.tile.slice(), forest: world.forest.slice(), trees: world.trees.slice(), decor: world.decor.slice(),
  hasSoil: world.has[T.soil], hasPath: world.has[T.path],
})

/** The smallest enclosure: three by three tiles, so there is ground inside the fence. */
export const MIN_ENCLOSURE = 3

/** A crop's stages from sown to ripe, and how long it takes to grow (for now one pace for every crop). */
export const STAGES = ['2-sown', '3-first-growth', '4-second-growth', '5-third-growth', '6-harvest'] as const
export const GROW_MS = 4 * 10 * 1000          // for now: a new stage every 10 seconds, ripe after 40; ripe crops stay ripe (they never wilt)
export const cropStage = (sown: number, now: number) => STAGES[Math.max(0, Math.min(STAGES.length - 1, Math.floor((now - sown) / GROW_MS * (STAGES.length - 1))))]

/** What may be built where, on the island as it is now. (The hills no longer limit building; the mountain reading stays for later.) */
export function rules(world: World, builds: () => Builds, _mountain: (i: number) => number) {
  const open = (i: number) => !world.ocean[i]                            // hills are gentle: all of them can be built on
  // tiles marked as mountain on the chain but where the mountain has not risen yet are grass to look at, and to build on
  const t = (i: number) => (world.type[i] === T.rock ? T.grass : world.type[i])   // the chain's mountain tiles are grassy hills now
  // the tiles inside an enclosure: not reached from the map's edge without crossing a fence (worked out again when the fences change)
  let penDirty = true, pen = new Uint8Array(0)
  const inPen = (i: number) => {
    if (penDirty) {
      penDirty = false
      const b = builds(), fences: number[] = []
      for (const k in b) if (b[k].f) fences.push(Number(k))
      const { cols, rows } = world, N = cols * rows, wall = new Uint8Array(N), out = new Uint8Array(N), q: number[] = []
      for (const k of fences) wall[k] = 1
      for (let x = 0; x < cols; x++) for (const y of [0, rows - 1]) { const j = y * cols + x; if (!wall[j] && !out[j]) { out[j] = 1; q.push(j) } }
      for (let y = 0; y < rows; y++) for (const x of [0, cols - 1]) { const j = y * cols + x; if (!wall[j] && !out[j]) { out[j] = 1; q.push(j) } }
      for (let h = 0; h < q.length; h++) { const j = q[h], x = j % cols, y = (j - x) / cols
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const X = x + dx, Y = y + dy; if (X < 0 || Y < 0 || X >= cols || Y >= rows) continue; const n = Y * cols + X; if (!wall[n] && !out[n]) { out[n] = 1; q.push(n) } } }
      pen = new Uint8Array(N); for (let j = 0; j < N; j++) pen[j] = !wall[j] && !out[j] ? 1 : 0
    }
    return pen[i] === 1
  }
  return {
    open,
    inPen,
    /** the builds changed: work the enclosures out again when next asked */
    changed: () => { penDirty = true },
    /** open grass, not in the woods, and not inside an enclosure (that is the creatures' ground) */
    soil: (i: number) => open(i) && t(i) === T.grass && !world.forest[i] && !inPen(i),
    /** grass, soil or sand without a crop or fence on it; trees there make way */
    path: (i: number) => open(i) && (t(i) === T.grass || t(i) === T.soil || t(i) === T.sand) && !builds()[i]?.c && !builds()[i]?.f && builds()[i]?.u === undefined,
    /** any dry, walkable ground without a crop; trees there make way */
    fence: (i: number) => open(i) && (t(i) === T.grass || t(i) === T.soil || t(i) === T.sand || t(i) === T.path) && !builds()[i]?.c && builds()[i]?.u === undefined,
    /** a building's tile: open grass or sand, nothing built there yet (trees there make way) */
    building: (i: number) => open(i) && (t(i) === T.grass || t(i) === T.sand) && !builds()[i]?.c && !builds()[i]?.f && !builds()[i]?.g && builds()[i]?.u === undefined,
    /** grass with nothing built or growing on it: room for a tree */
    tree: (i: number) => open(i) && t(i) === T.grass && !builds()[i]?.g && !builds()[i]?.f && !builds()[i]?.c && !builds()[i]?.p && builds()[i]?.u === undefined,
    /** soil with nothing on it yet */
    crop: (i: number) => open(i) && t(i) === T.soil && !builds()[i]?.c && !builds()[i]?.f && builds()[i]?.u === undefined,
  }
}

/** The tiles a fence round this rectangle stands on. */
export function ring([x0, y0, x1, y1]: [number, number, number, number], cols: number): number[] {
  const out: number[] = []
  for (let x = x0; x <= x1; x++) out.push(y0 * cols + x)
  for (let y = y0 + 1; y <= y1; y++) out.push(y * cols + x1)
  for (let x = x1 - 1; x >= x0; x--) out.push(y1 * cols + x)
  for (let y = y1 - 1; y > y0; y--) out.push(y * cols + x0)
  return out
}

/** Lays the builds over the island as the chain made it. Returns which tiles carry a fence. */
export function applyBuilds(world: World, pristine: Pristine, builds: Builds): Uint8Array {
  const { cols } = world, N = world.type.length, fence = new Uint8Array(N), soilTile = tileIndex.get('soil')!
  world.type.set(pristine.type); world.tile.set(pristine.tile); world.forest.set(pristine.forest)
  let soil = pristine.hasSoil, path = pristine.hasPath
  for (const k in builds) {
    const i = Number(k), b = builds[i]
    if (b.g === 'soil') { world.type[i] = T.soil; world.tile[i] = soilTile; soil = true }
    else if (b.g === 'path') { world.type[i] = T.path; world.tile[i] = tileIndex.get(PATH[i % PATH.length])!; path = true }
    if (b.f) fence[i] = 1
    if (b.x || b.g || b.f || b.u !== undefined) world.forest[i] = 0
  }
  world.has[T.soil] = soil; world.has[T.path] = path
  // nothing grows or lies where the player built or cleared: trees, bushes and flowers there make way
  const cleared = (x: number, y: number) => { const b = builds[Math.round(y) * cols + Math.round(x)]; return !!b && !!(b.x || b.g || b.f || b.c || b.u !== undefined) }
  world.trees = pristine.trees.filter((t) => !cleared(t.x, t.y))
  for (const k in builds) { const b = builds[k]; if (!b.p || b.g || b.f || b.c || b.u !== undefined) continue   // the player's own trees
    const i = Number(k), x = i % cols, y = (i - x) / cols, h = ((i * 2654435761) >>> 0) / 4294967296
    world.trees.push({ lift: 0, name: 'tree-0' + b.p, x: x + (h - 0.5) * 0.3, y: y + (((h * 7.31) % 1) - 0.5) * 0.3, sc: 1.25 + ((h * 13.7) % 1) * 0.3, sw: 0.35, phase: h * 6.28 }) }
  world.trees.sort((a, b) => a.y - b.y)
  world.decor = pristine.decor.filter((d) => !cleared(d.x, d.y))
  return fence
}

/** What an erase can take from a tile. */
export type EraseKind = 'building' | 'fence' | 'crop' | 'path' | 'soil' | 'nature'

/** Whether the island's own trees, bushes or flowers still stand on this tile. */
function natureOn(world: World, builds: Builds, i: number) {
  if (builds[i]?.p) return true
  if (builds[i]?.x) return false
  const x = i % world.cols, y = (i - x) / world.cols, here = (q: { x: number; y: number }) => Math.round(q.x) === x && Math.round(q.y) === y
  return world.trees.some(here) || world.decor.some(here)
}

/** The thing an erase that starts on this tile is after: the topmost there (fence, crop, path, soil, then trees and
 *  plants), or null on a tile with nothing to erase (then the erase takes whatever it finds). */
export function eraseKindAt(world: World, builds: Builds, i: number): EraseKind | null {
  const b = builds[i]
  if (b?.u !== undefined) return 'building'
  if (b?.f) return 'fence'
  if (b?.c) return 'crop'
  if (b?.g === 'path') return 'path'
  if (b?.g === 'soil') return 'soil'
  return natureOn(world, builds, i) ? 'nature' : null
}

/** Whether this tile holds something of that kind (any kind, with null) to erase. */
export function erasable(world: World, builds: Builds, i: number, kind: EraseKind | null = null): boolean {
  const b = builds[i]
  if (kind === null) return !!(b && (b.g || b.f || b.c || b.u !== undefined)) || natureOn(world, builds, i)
  if (kind === 'building') return b?.u !== undefined
  if (kind === 'fence') return !!b?.f
  if (kind === 'crop') return !!b?.c
  if (kind === 'path' || kind === 'soil') return b?.g === kind
  return natureOn(world, builds, i)
}

/** Erases that kind from a tile; with null, the player's builds there, or on a tile with none, its trees and plants. */
export function erase(world: World, builds: Builds, i: number, kind: EraseKind | null = null) {
  if (!erasable(world, builds, i, kind)) return
  if (builds[i]?.u !== undefined && (kind === 'building' || kind === null)) { removeBuilding(world, builds, builds[i].u!); return }
  const b = builds[i] ?? {}
  if (kind === null) {
    if (b.g || b.f || b.c) { delete b.g; delete b.f; delete b.c; delete b.t } else { delete b.p; b.x = 1 }
  }
  else if (kind === 'fence') delete b.f
  else if (kind === 'crop') { delete b.c; delete b.t }
  else if (kind === 'path') delete b.g
  else if (kind === 'soil') { delete b.g; delete b.c; delete b.t }       // a crop cannot stay without its soil
  else { delete b.p; b.x = 1 }
  if (Object.keys(b).length) builds[i] = b; else delete builds[i]
}

/** A building's size on the map as turned: [across, down]. */
export const dims = (kind: Building, o = 0): [number, number] => { const { w, h } = BUILDINGS[kind]; return o % 2 ? [h, w] : [w, h] }
/** A point given in the building's own drawing (tiles from its top-left, entrance south), on the map as turned (tiles
 *  from the turned footprint's top-left). */
export function turn(kind: Building, o: number, x: number, y: number): [number, number] {
  const { w, h } = BUILDINGS[kind], [W, H] = dims(kind, o)
  let u = x - w / 2, v = y - h / 2
  for (let k = 0; k < (o & 3); k++) [u, v] = [-v, u]
  return [W / 2 + u, H / 2 + v]
}
/** The tile just in front of a building's door (it may lie off the map: then -1), or -1 if it has no door. */
export function entrance(kind: Building, at: number, cols: number, rows: number, o = 0): number {
  const door = BUILDINGS[kind].door; if (door === undefined) return -1
  const [ex, ey] = turn(kind, o, door + 0.5, BUILDINGS[kind].h + 0.5), x = at % cols + Math.floor(ex), y = (at - at % cols) / cols + Math.floor(ey)
  return x < 0 || y < 0 || x >= cols || y >= rows ? -1 : y * cols + x
}
/** The tiles a building with this top-left tile covers. */
export function footprint(kind: Building, at: number, cols: number, o = 0): number[] {
  const [w, h] = dims(kind, o), x0 = at % cols, y0 = (at - x0) / cols, out: number[] = []
  for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) out.push(y * cols + x)
  return out
}
/** Puts up a building with its top-left tile here (the caller checked the ground). */
export function placeBuilding(world: World, builds: Builds, kind: Building, at: number, o = 0) {
  for (const i of footprint(kind, at, world.cols, o)) builds[i] = { ...builds[i], u: at }
  builds[at] = { ...builds[at], s: kind, lv: 1, ...(o ? { o } : {}) }
}
function removeBuilding(world: World, builds: Builds, at: number) {
  const kind = builds[at]?.s; if (!kind) return
  for (const i of footprint(kind, at, world.cols, builds[at].o ?? 0)) {
    const b = builds[i]; if (!b) continue
    delete b.u; delete b.s; delete b.lv; delete b.o; delete b.l
    if (Object.keys(b).length) builds[i] = b; else delete builds[i]
  }
}
/** Which tiles carry a building. */
export function buildingTiles(builds: Builds, n: number): Uint8Array {
  const out = new Uint8Array(n)
  for (const k in builds) if (builds[k].u !== undefined) out[Number(k)] = 1
  return out
}

/** Saved builds: the current form, or the first one (a list of actions) turned into it. */
export function loadBuilds(raw: unknown, cols: number): Builds {
  if (raw && typeof raw === 'object' && !Array.isArray(raw) && (raw as { v?: number }).v === 2) return { ...((raw as { cells: Builds }).cells ?? {}) }
  const out: Builds = {}
  if (Array.isArray(raw)) for (const a of raw as { kind: string; cells?: number[]; rect?: [number, number, number, number] }[]) {
    if (a.kind === 'soil') for (const i of a.cells ?? []) out[i] = { ...out[i], g: 'soil' }
    if (a.kind === 'fence' && a.rect) for (const i of ring(a.rect, cols)) out[i] = { ...out[i], f: 1 }
  }
  return out
}
export const saveForm = (builds: Builds) => ({ v: 2, cells: builds })

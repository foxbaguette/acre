// Building on the island: fences, paths, soil, crops, and erasing (builds, and the island's own trees and bushes). The
// chain's map stays as it is; the player's builds are kept per tile and laid over it (kept by the page; the contract
// has no action for them yet). Laying them always starts again from the island as the chain made it, so taking a
// build back is just laying a smaller set.
import { PATH, T, tileIndex, type World } from './world'

export type BuildTool = 'fence' | 'path' | 'soil' | 'crop' | 'erase' | Building | 'upgrade'
export type Building = 'farmhouse' | 'lab' | 'nest'
/** The buildings: footprint in tiles (w across, h down) and how many stages they can be upgraded through. */
export const BUILDINGS: Record<Building, { w: number; h: number; stages: number; art: (stage: number) => string }> = {
  farmhouse: { w: 3, h: 4, stages: 5, art: (s) => `building-farmhouse-${s}` },   // stage n: n farmers live there
  lab: { w: 4, h: 4, stages: 1, art: () => 'building-lab' },
  nest: { w: 2, h: 2, stages: 1, art: () => 'building-nest' },
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
  /** cleared: the island's own trees, bushes and flowers there are gone */
  x?: 1
  /** a building stands here, its top-left tile at this index (on every tile it covers) */
  u?: number
  /** on a building's top-left tile: which building, and its stage */
  s?: Building
  lv?: number
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
export const GROW_MS = 10 * 60 * 1000
export const cropStage = (sown: number, now: number) => STAGES[Math.max(0, Math.min(STAGES.length - 1, Math.floor((now - sown) / GROW_MS * (STAGES.length - 1))))]

/** What may be built where, on the island as it is now. `mountain(i)` says how much of a mountain shows on tile i (0..1). */
export function rules(world: World, builds: () => Builds, mountain: (i: number) => number) {
  const open = (i: number) => !world.ocean[i] && mountain(i) < 0.75   // the grassy foot of a mountain is fine, its slopes are not
  // tiles marked as mountain on the chain but where the mountain has not risen yet are grass to look at, and to build on
  const t = (i: number) => (world.type[i] === T.rock && mountain(i) < 0.5 ? T.grass : world.type[i])
  return {
    open,
    /** open grass, not in the woods */
    soil: (i: number) => open(i) && t(i) === T.grass && !world.forest[i],
    /** grass, soil or sand without a crop or fence on it; trees there make way */
    path: (i: number) => open(i) && (t(i) === T.grass || t(i) === T.soil || t(i) === T.sand) && !builds()[i]?.c && !builds()[i]?.f && builds()[i]?.u === undefined,
    /** any dry, walkable ground without a crop; trees there make way */
    fence: (i: number) => open(i) && (t(i) === T.grass || t(i) === T.soil || t(i) === T.sand || t(i) === T.path) && !builds()[i]?.c && builds()[i]?.u === undefined,
    /** a building's tile: open grass or sand, nothing built there yet (trees there make way) */
    building: (i: number) => open(i) && (t(i) === T.grass || t(i) === T.sand) && !builds()[i]?.c && !builds()[i]?.f && !builds()[i]?.g && builds()[i]?.u === undefined,
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
  world.decor = pristine.decor.filter((d) => !cleared(d.x, d.y))
  return fence
}

/** What an erase can take from a tile. */
export type EraseKind = 'building' | 'fence' | 'crop' | 'path' | 'soil' | 'nature'

/** Whether the island's own trees, bushes or flowers still stand on this tile. */
function natureOn(world: World, builds: Builds, i: number) {
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
    if (b.g || b.f || b.c) { delete b.g; delete b.f; delete b.c; delete b.t } else b.x = 1
  }
  else if (kind === 'fence') delete b.f
  else if (kind === 'crop') { delete b.c; delete b.t }
  else if (kind === 'path') delete b.g
  else if (kind === 'soil') { delete b.g; delete b.c; delete b.t }       // a crop cannot stay without its soil
  else b.x = 1
  if (Object.keys(b).length) builds[i] = b; else delete builds[i]
}

/** The tiles a building with this top-left tile covers. */
export function footprint(kind: Building, at: number, cols: number): number[] {
  const { w, h } = BUILDINGS[kind], x0 = at % cols, y0 = (at - x0) / cols, out: number[] = []
  for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) out.push(y * cols + x)
  return out
}
/** Puts up a building with its top-left tile here (the caller checked the ground). */
export function placeBuilding(world: World, builds: Builds, kind: Building, at: number) {
  for (const i of footprint(kind, at, world.cols)) builds[i] = { ...builds[i], u: at }
  builds[at] = { ...builds[at], s: kind, lv: 1 }
}
function removeBuilding(world: World, builds: Builds, at: number) {
  const kind = builds[at]?.s; if (!kind) return
  for (const i of footprint(kind, at, world.cols)) {
    const b = builds[i]; if (!b) continue
    delete b.u; delete b.s; delete b.lv
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

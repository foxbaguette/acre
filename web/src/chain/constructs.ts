import { BUILDINGS, footprint, type Building, type Builds, type CellBuild } from '@/engine/build'

import { CHUNK, CONTRACT, MAP_SIZE } from './config'
import { readTable } from './rpc'

// What is built on a map (and the trees it grew with), kept by land.acre in table "constructs" (scope = map id), in the same chunks as the land:
// row id = chunk id (cy * 10 + cx), 4 bytes per tile (tile = ty * 10 + tx), row by row:
//   byte 0  flags: bits 0-1 ground (0 none, 1 soil, 2 path), bit 2 fence, bit 3 a building's top-left tile, bit 4 a tree
//   byte 1  the tree's kind: 1-6 planted by the player, 7 grown with the island (createmap)
//   byte 2  building kind (bits 0-3) and stage (bits 4-6), on its top-left tile (kinds as in buildcfg: 1 farmhouse ... 8 market)
//   byte 3  building rotation (bits 0-1), on its top-left tile
// One construct a tile at most, and none on a building's other tiles. Crops are not constructions: they grow on soil and
// stay on this device for now.

const TILE_BYTES = 4
const CELLS = CHUNK * CHUNK
const PER_ROW = MAP_SIZE / CHUNK
/** Building kinds on chain (0: none). Only ever append: the numbers are stored. */
export const KINDS: Building[] = ['farmhouse', 'lab', 'nest', 'silo', 'bakery', 'kitchen', 'torch', 'market']

/** A map tile index (y * 100 + x) as the contract names it: chunk id * 100 + tile in the chunk. */
export const chainTile = (i: number) => {
  const x = i % MAP_SIZE, y = (i - x) / MAP_SIZE
  return (Math.floor(y / CHUNK) * PER_ROW + Math.floor(x / CHUNK)) * CELLS + (y % CHUNK) * CHUNK + (x % CHUNK)
}
export const mapTile = (chunk: number, cell: number) => {
  const cx = chunk % PER_ROW, cy = Math.floor(chunk / PER_ROW)
  return (cy * CHUNK + Math.floor(cell / CHUNK)) * MAP_SIZE + cx * CHUNK + (cell % CHUNK)
}

/** One tile's 4 bytes. */
export function encodeTile(b: CellBuild | undefined): number[] {
  if (!b) return [0, 0, 0, 0]
  let flags = b.g === 'soil' ? 1 : b.g === 'path' ? 2 : 0
  if (b.f) flags |= 4
  const kind = b.s ? KINDS.indexOf(b.s) + 1 : 0
  if (kind) flags |= 8
  if (b.p) flags |= 16
  return [flags, b.p ?? 0, kind ? kind | (Math.min(b.lv ?? 1, 7) << 4) : 0, kind ? (b.o ?? 0) & 3 : 0]
}

interface ConstructRow {
  id: number
  tiles: string | number[]
}

/** Everything built on a map, as the page keeps it (crops not included). */
export async function fetchConstructs(mapId: string): Promise<Builds> {
  const rows = await readTable<ConstructRow>('constructs', mapId)
  const out: Builds = {}
  const put = (i: number, b: CellBuild) => { out[i] = { ...out[i], ...b } }
  for (const row of rows) {
    const bytes = typeof row.tiles === 'string' ? (row.tiles.match(/../g) ?? []).map((h) => parseInt(h, 16)) : row.tiles
    if (bytes.length !== CELLS * TILE_BYTES || row.id >= PER_ROW * PER_ROW) continue
    for (let cell = 0; cell < CELLS; cell++) {
      const [flags, tree, kind, rot] = bytes.slice(cell * TILE_BYTES, cell * TILE_BYTES + TILE_BYTES)
      if (!flags) continue
      const i = mapTile(row.id, cell), b: CellBuild = {}
      if ((flags & 3) === 1) b.g = 'soil'
      else if ((flags & 3) === 2) b.g = 'path'
      if (flags & 4) b.f = 1
      if (flags & 16 && tree) b.p = tree
      const s = flags & 8 ? KINDS[(kind & 15) - 1] : undefined
      if (s) {
        const o = rot & 3, lv = Math.max(1, Math.min((kind >> 4) & 7, BUILDINGS[s].stages))
        Object.assign(b, { s, lv, ...(o ? { o } : {}) })
        for (const k of footprint(s, i, MAP_SIZE, o)) put(k, { u: i })
      }
      put(i, b)
    }
  }
  return out
}

/** Only what the contract keeps of the builds: no crops, harvest marks or remembered door paths. */
export function chainPart(builds: Builds): Builds {
  const out: Builds = {}
  for (const k in builds) {
    const { c: _c, t: _t, h: _h, l: _l, ...rest } = builds[k]
    if (Object.keys(rest).length) out[Number(k)] = rest
  }
  return out
}

/** The actions that take the chain from `was` to `next`: setconstr for every tile whose bytes change (an island's own
 *  tree is a construct too, so taking one away is one more tile set to nothing). Empty when only crops changed. */
export function saveActions(mapId: string, who: { actor: string; permission: string }, was: Builds, next: Builds) {
  const set: { tile: number; bytes: number[] }[] = []
  const keys = new Set([...Object.keys(was), ...Object.keys(next)].map(Number))
  for (const i of keys) {
    const a = encodeTile(was[i]), b = encodeTile(next[i])
    if (a.some((v, k) => v !== b[k])) set.push({ tile: chainTile(i), bytes: b })
  }
  set.sort((p, q) => p.tile - q.tile)
  const BATCH = 120, actions = []
  for (let k = 0; k < set.length; k += BATCH) {
    const part = set.slice(k, k + BATCH)
    actions.push({ account: CONTRACT, name: 'setconstr', authorization: [who], data: { wallet: who.actor, map_id: mapId, tiles: part.map((p) => p.tile), data: part.flatMap((p) => p.bytes).map((v) => v.toString(16).padStart(2, '0')).join('') } })
  }
  return actions
}

/** An enclosure land.acre keeps (table enclosures, scope = map id): its id, how many tiles lie inside the fence, and its
 *  first tile as a map index (y * 100 + x). */
export interface Enclosure { id: string; tiles: number; at: number; water: boolean }

interface EnclosureRow {
  id: number | string
  tile_count: number
  anchor: number
  /** a pond: made with the map, for water creatures, never removed (missing on rows from before) */
  is_water?: boolean | number
}

/** The enclosures land.acre counted on a map. */
export async function fetchEnclosures(mapId: string): Promise<Enclosure[]> {
  const rows = await readTable<EnclosureRow>('enclosures', mapId)
  return rows.map((r) => ({ id: String(r.id), tiles: Number(r.tile_count), at: mapTile(Math.floor(r.anchor / CELLS), r.anchor % CELLS), water: !!r.is_water }))
}

interface BuildCfgRow { kind: number; allowed_inside_enclosures: number | boolean }

/** The buildings land.acre lets stand inside an enclosure (null when its buildcfg cannot be read or is empty). */
export async function fetchInsideOk(): Promise<Building[] | null> {
  const rows = await readTable<BuildCfgRow>('buildcfg', CONTRACT)
  if (!rows.length) return null
  return rows.filter((r) => !!Number(r.allowed_inside_enclosures)).map((r) => KINDS[r.kind - 1]).filter(Boolean)
}

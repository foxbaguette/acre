import { CHUNK, CONTRACT, MAP_SIZE } from './config'
import { readTable } from './rpc'

export interface MapRow {
  map_id: number | string
  owner: string
  playertag: string
  map_name: string
  /** where it lies on the world map (missing on maps from before) */
  x?: number
  y?: number
  /** its soil (missing on maps from before) */
  nutrients?: number
  moisture?: number
  acidity?: number
}

export interface PlayerMap {
  id: string
  owner: string
  name: string
  playertag: string
  /** where it lies on the world map (land.acre maps: a square spiral out from 0, 0), null on maps from before */
  at: { x: number; y: number } | null
  /** its soil, rolled when it was charted: nutrients and moisture 1-100, acidity as pH x 10 (10-140, 70 neutral); null on
   *  maps from before */
  soil: { nutrients: number; moisture: number; acidity: number } | null
}

/** A soil's acidity in words, from its pH. */
export const acidWord = (acidity: number) => { const ph = acidity / 10
  return ph < 4.5 ? 'very acid' : ph < 6 ? 'acid' : ph < 6.6 ? 'slightly acid' : ph <= 7.4 ? 'neutral' : ph <= 8.5 ? 'slightly alkaline' : ph <= 10 ? 'alkaline' : 'very alkaline' }

/** A place on the world map, as players read it: "0, 0", "3 east, 2 north". y grows to the south, like the islands. */
export const placeWords = (at: { x: number; y: number } | null) => {
  if (!at) return 'no place on the world map yet'
  if (!at.x && !at.y) return 'the middle of the world'
  const ew = at.x ? `${Math.abs(at.x)} ${at.x > 0 ? 'east' : 'west'}` : '', ns = at.y ? `${Math.abs(at.y)} ${at.y > 0 ? 'south' : 'north'}` : ''
  return [ew, ns].filter(Boolean).join(', ')
}

/** Ground types in bits 0-2 of a tile byte. */
export const GROUND = { sea: 0, freshWater: 1, beach: 2, grass: 3, mountain: 4, field: 5, road: 6 } as const

const toMap = (row: MapRow): PlayerMap => ({
  id: String(row.map_id),
  owner: row.owner,
  name: row.map_name,
  playertag: row.playertag,
  at: row.x === undefined || row.y === undefined ? null : { x: Number(row.x), y: Number(row.y) },
  soil: row.nutrients === undefined ? null : { nutrients: Number(row.nutrients), moisture: Number(row.moisture), acidity: Number(row.acidity) }
})

/** The maps a wallet owns, oldest first. */
export async function fetchPlayerMaps(owner: string): Promise<PlayerMap[]> {
  const rows = await readTable<MapRow>('maps', CONTRACT)
  return rows
    .filter((row) => row.owner === owner)
    .map(toMap)
    .sort((a, b) => Number(a.id) - Number(b.id))
}

interface ChunkRow {
  id: number
  tiles: string | number[]
}

/** Chunk rows to one byte per tile, or null while any chunk is missing or malformed. */
function decodeChunks(rows: ChunkRow[]): Uint8Array | null {
  const tiles = new Uint8Array(MAP_SIZE * MAP_SIZE)
  const perRow = MAP_SIZE / CHUNK
  const seen = new Set<number>()
  for (const row of rows) {
    const bytes = typeof row.tiles === 'string' ? (row.tiles.match(/../g) ?? []).map((h) => parseInt(h, 16)) : row.tiles
    const cx = row.id % perRow
    const cy = Math.floor(row.id / perRow)
    if (bytes.length !== CHUNK * CHUNK || cy >= perRow) continue
    for (let k = 0; k < CHUNK * CHUNK; k++) {
      tiles[(cy * CHUNK + Math.floor(k / CHUNK)) * MAP_SIZE + cx * CHUNK + (k % CHUNK)] = bytes[k]
    }
    seen.add(row.id)
  }
  return seen.size === perRow * perRow ? tiles : null
}

const tileCache = new Map<string, Promise<Uint8Array>>()

/** All 10,000 tile bytes of a map (bits 0-2 ground, 3-5 mountain height, 6 tree). */
export function fetchMapTiles(mapId: string): Promise<Uint8Array> {
  let pending = tileCache.get(mapId)
  if (!pending) {
    pending = readTable<ChunkRow>('chunks', mapId, (rows) => decodeChunks(rows) !== null).then((rows) => decodeChunks(rows)!)
    pending.catch(() => tileCache.delete(mapId))
    tileCache.set(mapId, pending)
  }
  return pending
}

/** Reads the map's tiles anew next time (after clearnature changed them). */
export const forgetMapTiles = (mapId: string) => { tileCache.delete(mapId) }

/** A generator config (land.acre table genconfig): createmap is told which one to chart an island with. */
export interface GenConfig {
  index: string
  width: number
  height: number
  land_min: number
  land_max: number
  mountain_chance: number
  lake_chance: number
  river_chance: number
  ponds_min: number
  ponds_max: number
  islets_max: number
  forests: boolean | number
  forest_min: number
  forest_max: number
}

/** The generator configs the contract has, by index. */
export async function fetchGenConfigs(): Promise<GenConfig[]> {
  const rows = await readTable<GenConfig & { index: number | string }>('genconfig', CONTRACT)
  return rows.map((r) => ({ ...r, index: String(r.index) })).sort((a, b) => Number(a.index) - Number(b.index))
}

export interface MapStats {
  land: number
  forest: number
  mountain: number
  beach: number
  freshWater: number
}

/** Shares of the whole map, 0-1. */
export function mapStats(tiles: Uint8Array): MapStats {
  let land = 0, forest = 0, mountain = 0, beach = 0, freshWater = 0
  for (const byte of tiles) {
    const ground = byte & 7
    if (ground !== GROUND.sea) land++
    if (byte & 64) forest++
    if (ground === GROUND.mountain) mountain++
    if (ground === GROUND.beach) beach++
    if (ground === GROUND.freshWater) freshWater++
  }
  const n = tiles.length
  return { land: land / n, forest: forest / n, mountain: mountain / n, beach: beach / n, freshWater: freshWater / n }
}

/** Every map, all owners, by id. */
export async function fetchAllMaps(): Promise<PlayerMap[]> {
  const rows = await readTable<MapRow>('maps', CONTRACT)
  return rows.map(toMap).sort((a, b) => Number(a.id) - Number(b.id))
}

/** Place n of the world map's square spiral out from 0, 0, as land.acre counts it (next_place): 0, 0 then 1, 0, 1, 1,
 *  0, 1, -1, 1, -1, 0, -1, -1, 0, -1, 1, -1, then the next ring round. */
export function spiralPlace(n: number): { x: number; y: number } {
  let k = 0
  while ((2 * k + 1) ** 2 <= n) k++
  if (!k) return { x: 0, y: 0 }
  const side = 2 * k, d = (2 * k + 1) ** 2 - 1 - n
  if (d < side) return { x: k - d, y: -k }
  if (d < 2 * side) return { x: -k, y: -k + (d - side) }
  if (d < 3 * side) return { x: -k + (d - 2 * side), y: k }
  return { x: k, y: k - (d - 3 * side) }
}

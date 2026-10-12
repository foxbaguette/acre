import { CHUNK, CONTRACT, MAP_SIZE } from './config'
import { readTable } from './rpc'

export interface MapRow {
  map_id: number | string
  owner: string
  playertag: string
  map_name: string
}

export interface PlayerMap {
  id: string
  owner: string
  name: string
  playertag: string
}

/** Ground types in bits 0-2 of a tile byte. */
export const GROUND = { sea: 0, freshWater: 1, beach: 2, grass: 3, mountain: 4, field: 5, road: 6 } as const

const toMap = (row: MapRow): PlayerMap => ({
  id: String(row.map_id),
  owner: row.owner,
  name: row.map_name,
  playertag: row.playertag
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

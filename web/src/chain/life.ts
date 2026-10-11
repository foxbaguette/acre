import { LIFE_CONTRACT } from './config'
import { readTable } from './rpc'
import type { Lifeform } from '@/engine/types'

/** A row of life.acre's creatures table (only the fields the island needs are typed). */
interface CreatureRow {
  creature_id: number | string
  species_id: number | string
  owner: string
  map_id: number | string
  hatched: boolean | number
  creator: string
  creation_time: string
  hatch_time: string
  adulthood_time: string
  breeding_cooldown: string
  ancestors: unknown[]
  children: unknown[]
  sell_value: number | string
  creature_name: string
  color1: string
  color2: string
  color3: string
  color4: string
  color5: string
  size: number
  mass: number
  speed: number
  sex: number
}

/** A creature as the island page shows it: what the renderer needs, plus the details for its notes card. */
export interface Creature extends Lifeform {
  name: string
  speciesName: string
  owner: string
  creator: string
  mass: number
  sex: number
  born: Date
  adult: Date
  breedReady: Date
  ancestors: number
  children: number
  sellValue: number
}

/** A row of life.acre's species table. */
interface SpeciesRow {
  species_id: number | string
  species_name: string
}

let speciesCache: Promise<Map<string, string>> | null = null

/** species id to species name; the name picks the creature's sprite. */
function speciesNames(): Promise<Map<string, string>> {
  speciesCache ??= readTable<SpeciesRow>('species', LIFE_CONTRACT, () => true, { code: LIFE_CONTRACT })
    .then((rows) => new Map(rows.map((r) => [String(r.species_id), r.species_name])))
    .catch((err) => { speciesCache = null; throw err })
  return speciesCache
}

/** vector<uint8_t> comes back as a hex string ("516a47"); older nodes may send a number array. */
const hex = (v: unknown): string =>
  Array.isArray(v) ? v.map((n) => Number(n).toString(16).padStart(2, '0')).join('') : String(v ?? '')

/** Chain times are UTC without a zone ("2026-10-10T07:18:57"). */
const chainTime = (t: string): Date => new Date(String(t).endsWith('Z') ? t : t + 'Z')

/** The hatched creatures living on a map, read through the creatures table's by_map index. */
export async function fetchLifeforms(mapId: string): Promise<Creature[]> {
  const [rows, names] = await Promise.all([
    readTable<CreatureRow>('creatures', LIFE_CONTRACT, () => true, { code: LIFE_CONTRACT, index: 3, keyType: 'i64', lower: mapId, upper: mapId }),
    speciesNames()
  ])
  return rows
    .filter((r) => String(r.map_id) === mapId && Boolean(r.hatched))
    .map((r) => ({
      id: r.creature_id,
      species: names.get(String(r.species_id)) ?? r.creature_name,
      colors: [r.color1, r.color2, r.color3, r.color4, r.color5].map(hex),
      size: Number(r.size),
      speed: Number(r.speed),
      name: r.creature_name,
      speciesName: names.get(String(r.species_id)) ?? r.creature_name,
      owner: r.owner,
      creator: r.creator,
      mass: Number(r.mass),
      sex: Number(r.sex),
      born: chainTime(r.creation_time),
      adult: chainTime(r.adulthood_time),
      breedReady: chainTime(r.breeding_cooldown),
      ancestors: Array.isArray(r.ancestors) ? r.ancestors.length : 0,
      children: Array.isArray(r.children) ? r.children.length : 0,
      sellValue: Number(r.sell_value) || 0
    }))
}

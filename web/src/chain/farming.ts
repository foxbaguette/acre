// Farming on land.acre: the crops that can be sown (cropcfg), how long a harvest takes (harvestcfg), what grows on a map
// (plants, scope = map id), the farmers' jobs (workqueue, scope = map id) and the crops each player holds (cropstore).
import type { Job } from '@/engine/farmers'

import { CONTRACT } from './config'
import { chainTile, mapTile } from './constructs'
import { fetchPlayerMaps } from './maps'
import { contractTables, readTable } from './rpc'

const ms = (t: string) => Date.parse(t.endsWith('Z') ? t : t + 'Z')

export interface CropCfg {
  id: string; name: string; yield: number; growth: number; seasons: string[]; daytimes: string[]; weathers: string[]
  /** the soil it likes best: nutrients 1-100, moisture 1-100, acidity 10-140 (pH × 10); null on crops from before */
  prefers: { nutrients: number; moisture: number; acidity: number } | null
  /** the seeds a tile brings when harvested for seeds */
  seedYield: number
  /** only once unlocked in the research lab (false: every player may sow it) */
  labUnlock: boolean
}

interface CropRow { crop_id: number; crop_name: string; yield: number | string; growth_time_sec: number | string; seasons?: string[]; daytimes?: string[]; weathers?: string[]; pref_nutrients?: number; pref_moisture?: number; pref_acidity?: number; seed_yield?: number | string; lab_unlock?: number | boolean }

/** The crops that can be sown; growth in seconds. An empty list of seasons, daytimes or weathers is any. */
export async function fetchCropCfg(): Promise<CropCfg[]> {
  const t = await contractTables(); if (t && !t.includes('cropcfg')) return []   // not in the deployed contract yet
  const rows = await readTable<CropRow>('cropcfg', CONTRACT)
  return rows.map((r) => ({ id: String(r.crop_id), name: r.crop_name, yield: Number(r.yield), growth: Number(r.growth_time_sec), seasons: r.seasons ?? [], daytimes: r.daytimes ?? [], weathers: r.weathers ?? [],
    prefers: r.pref_nutrients === undefined ? null : { nutrients: Number(r.pref_nutrients), moisture: Number(r.pref_moisture), acidity: Number(r.pref_acidity) },
    seedYield: Number(r.seed_yield ?? 0), labUnlock: !!Number(r.lab_unlock ?? 0) }))
    .sort((a, b) => Number(a.id) - Number(b.id))
}

export interface HarvestCfg { harvest_sec_field: number; distance_sec: number; offload_sec: number; rest_sec: number }

export async function fetchHarvestCfg(): Promise<HarvestCfg | null> {
  const t = await contractTables(); if (t && !t.includes('harvestcfg')) return null
  const rows = await readTable<Record<string, number | string>>('harvestcfg', CONTRACT)
  const r = rows.find((x) => Number(x.index) === 0); if (!r) return null
  return { harvest_sec_field: Number(r.harvest_sec_field), distance_sec: Number(r.distance_sec), offload_sec: Number(r.offload_sec), rest_sec: Number(r.rest_sec) }
}

/** The seeds of a crop a player starts with (land.acre START_SEEDS): of each crop unlocked from the start with their
 *  first island, of a lab crop once they unlock it. */
export const START_SEEDS = 4

/** Whether the deployed land.acre has farming yet (its plants and workqueue tables). */
export async function hasFarming(): Promise<boolean> {
  const t = await contractTables(); return !t || (t.includes('plants') && t.includes('workqueue'))
}

export interface Plant { tile: number; crop: string; planted: number; harvestId: string }

/** What grows on a map, by map index; crop is the crop id. */
export async function fetchPlants(mapId: string): Promise<Plant[]> {
  const rows = await readTable<{ tile: number; crop_id: number; planted_at: string; harvest_id: number | string }>('plants', mapId)
  return rows.map((r) => ({ tile: mapTile(Math.floor(Number(r.tile) / 100), Number(r.tile) % 100), crop: String(r.crop_id), planted: ms(r.planted_at), harvestId: String(r.harvest_id) }))
}

interface JobRow {
  id: number | string; farmhouse: number | string; worker: number; silo: number | string; crop_id: number; tiles: number[]; amount: number | string; claimed: number | boolean; seeds?: number | boolean
  start: string; at_field: string; harvested: string; at_silo: string; offloaded: string; home: string; rested: string
}

/** The farmers' jobs on a map; crop is the crop id (the page names it). */
export async function fetchJobs(mapId: string): Promise<Job[]> {
  const rows = await readTable<JobRow>('workqueue', mapId)
  const at = (t: number | string) => mapTile(Math.floor(Number(t) / 100), Number(t) % 100)
  return rows.map((r) => ({
    id: String(r.id), farmhouse: at(r.farmhouse), worker: Number(r.worker), silo: at(r.silo), crop: String(r.crop_id), tiles: r.tiles.map(at), amount: Number(r.amount), claimed: !!Number(r.claimed), seeds: !!Number(r.seeds ?? 0),
    start: ms(r.start), atField: ms(r.at_field), harvested: ms(r.harvested), atSilo: ms(r.at_silo), offloaded: ms(r.offloaded), home: ms(r.home), rested: ms(r.rested),
  }))
}

/** The crops a player holds, by crop id: what all the islands they own hold (land.acre stored, island by island). */
export async function fetchPlayerStore(wallet: string): Promise<Record<string, number>> {
  const islands = await fetchPlayerMaps(wallet), out: Record<string, number> = {}
  for (const held of await Promise.all(islands.map((m) => fetchStored(m.id)))) for (const [id, n] of Object.entries(held)) out[id] = (out[id] ?? 0) + n
  return out
}

/** The seeds a player holds, by crop id (land.acre seeds, scope = the player); null when the table is not deployed yet. */
export async function fetchSeeds(wallet: string): Promise<Record<string, number> | null> {
  const t = await contractTables(); if (t && !t.includes('seeds')) return null
  const rows = await readTable<{ crop_id: number; amount: number | string }>('seeds', wallet)
  return Object.fromEntries(rows.map((r) => [String(r.crop_id), Number(r.amount)]))
}

type Who = { actor: string; permission: string }
const act = (who: Who, name: string, data: Record<string, unknown>) => ({ account: CONTRACT, name, authorization: [who], data: { wallet: who.actor, ...data } })

/** Sowing: one plant action for each crop, up to 500 tiles each. */
export function plantActions(mapId: string, who: Who, byCrop: Record<string, number[]>) {
  const out = []
  for (const [crop, tiles] of Object.entries(byCrop)) for (let k = 0; k < tiles.length; k += 500) out.push(act(who, 'plant', { map_id: mapId, crop_id: crop, tiles: tiles.slice(k, k + 500).map(chainTile) }))
  return out
}
export function unplantActions(mapId: string, who: Who, tiles: number[]) {
  const out = []
  for (let k = 0; k < tiles.length; k += 500) out.push(act(who, 'unplant', { map_id: mapId, tiles: tiles.slice(k, k + 500).map(chainTile) }))
  return out
}
/** One farmer for each crop's tiles (up to 200 a farmer); for the store, or for seeds (forSeeds only goes to a contract
 *  that takes it). */
export function harvestActions(mapId: string, who: Who, byCrop: Record<string, number[]>, forSeeds?: boolean) {
  const out = []
  for (const tiles of Object.values(byCrop)) for (let k = 0; k < tiles.length; k += 200) out.push(act(who, 'harvest', { map_id: mapId, tiles: tiles.slice(k, k + 200).map(chainTile), ...(forSeeds === undefined ? {} : { for_seeds: forSeeds }) }))
  return out
}
/** Calls off the harvest of tiles no farmer has set out for yet (up to 500 a time). */
export function cancelHarvestActions(mapId: string, who: Who, tiles: number[]) {
  const out = []
  for (let k = 0; k < tiles.length; k += 500) out.push(act(who, 'cancelharv', { map_id: mapId, tiles: tiles.slice(k, k + 500).map(chainTile) }))
  return out
}
export const claimAction = (mapId: string, who: Who, id: string) => act(who, 'claim', { map_id: mapId, id })

/** Whether a crop may be sown now: its lists against the island clock's names (home.acre's: spring, morning, sunny…). */
export function sowable(c: CropCfg, now: { season: string; daytime: string; weather: string } | null) {
  if (!now) return true
  const ok = (list: string[], v: string) => !list.length || list.includes(v)
  return ok(c.seasons, now.season) && ok(c.daytimes, now.daytime) && ok(c.weathers, now.weather)
}

/** How much an island can store and how much its harvests filled (land.acre storage); null: not counted yet. */
export async function fetchStorage(mapId: string): Promise<{ capacity: number; used: number } | null> {
  const t = await contractTables(); if (t && !t.includes('storage')) return null
  const rows = await readTable<{ map_id: number | string; capacity: number | string; used: number | string }>('storage', CONTRACT, () => true, { lower: mapId, upper: mapId })
  const r = rows.find((x) => String(x.map_id) === mapId); return r ? { capacity: Number(r.capacity), used: Number(r.used) } : { capacity: 0, used: 0 }   // no row yet: nothing built that stores
}

/** What an island holds, by crop id (land.acre stored, scope = map id); empty when the table is not deployed yet. */
export async function fetchStored(mapId: string): Promise<Record<string, number>> {
  const t = await contractTables(); if (t && !t.includes('stored')) return {}
  const rows = await readTable<{ crop_id: number; amount: number | string }>('stored', mapId)
  return Object.fromEntries(rows.map((r) => [String(r.crop_id), Number(r.amount)]))
}

/** What an island's soil does to a crop, as land.acre counts it (soil_effect), against the soil the crop likes best:
 *  each point off, nutrients 2% less yield, acidity 1% less (each down to none), moisture 5% longer growth, acidity 3%
 *  longer, one after the other. Both in percent of the crop's own; 0 yield: it cannot be sown there. */
export function soilEffect(crop: CropCfg, soil: { nutrients: number; moisture: number; acidity: number } | null): { yieldPct: number; growthPct: number } {
  if (!soil || !crop.prefers) return { yieldPct: 100, growthPct: 100 }
  const dn = Math.abs(soil.nutrients - crop.prefers.nutrients), dm = Math.abs(soil.moisture - crop.prefers.moisture), da = Math.abs(soil.acidity - crop.prefers.acidity)
  return { yieldPct: Math.floor((Math.max(0, 100 - 2 * dn) * Math.max(0, 100 - da)) / 100), growthPct: Math.floor(((100 + 5 * dm) * (100 + 3 * da)) / 100) }
}
/** A crop's growth time on an island (seconds), rounded down as the contract does. */
export const growthOn = (crop: CropCfg, soil: { nutrients: number; moisture: number; acidity: number } | null) => Math.floor((crop.growth * soilEffect(crop, soil).growthPct) / 100)

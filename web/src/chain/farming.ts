// Farming on land.acre: the crops that can be sown (cropcfg), how long a harvest takes (harvestcfg), what grows on a map
// (plants, scope = map id), the farmers' jobs (workqueue, scope = map id) and the crops each player holds (cropstore).
import type { Job } from '@/engine/farmers'

import { CONTRACT } from './config'
import { chainTile, mapTile } from './constructs'
import { fetchPlayerMaps } from './maps'
import { contractTables, readTable } from './rpc'

const ms = (t: string) => Date.parse(t.endsWith('Z') ? t : t + 'Z')

export interface CropCfg { id: string; name: string; yield: number; growth: number; seasons: string[]; daytimes: string[]; weathers: string[] }

interface CropRow { crop_id: number; crop_name: string; yield: number | string; growth_time_sec: number | string; seasons?: string[]; daytimes?: string[]; weathers?: string[] }

/** The crops that can be sown; growth in seconds. An empty list of seasons, daytimes or weathers is any. */
export async function fetchCropCfg(): Promise<CropCfg[]> {
  const t = await contractTables(); if (t && !t.includes('cropcfg')) return []   // not in the deployed contract yet
  const rows = await readTable<CropRow>('cropcfg', CONTRACT)
  return rows.map((r) => ({ id: String(r.crop_id), name: r.crop_name, yield: Number(r.yield), growth: Number(r.growth_time_sec), seasons: r.seasons ?? [], daytimes: r.daytimes ?? [], weathers: r.weathers ?? [] }))
    .sort((a, b) => Number(a.id) - Number(b.id))
}

export interface HarvestCfg { harvest_sec_field: number; distance_sec: number; offload_sec: number; rest_sec: number }

export async function fetchHarvestCfg(): Promise<HarvestCfg | null> {
  const t = await contractTables(); if (t && !t.includes('harvestcfg')) return null
  const rows = await readTable<Record<string, number | string>>('harvestcfg', CONTRACT)
  const r = rows.find((x) => Number(x.index) === 0); if (!r) return null
  return { harvest_sec_field: Number(r.harvest_sec_field), distance_sec: Number(r.distance_sec), offload_sec: Number(r.offload_sec), rest_sec: Number(r.rest_sec) }
}

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
  id: number | string; farmhouse: number | string; worker: number; silo: number | string; crop_id: number; tiles: number[]; amount: number | string; claimed: number | boolean
  start: string; at_field: string; harvested: string; at_silo: string; offloaded: string; home: string; rested: string
}

/** The farmers' jobs on a map; crop is the crop id (the page names it). */
export async function fetchJobs(mapId: string): Promise<Job[]> {
  const rows = await readTable<JobRow>('workqueue', mapId)
  const at = (t: number | string) => mapTile(Math.floor(Number(t) / 100), Number(t) % 100)
  return rows.map((r) => ({
    id: String(r.id), farmhouse: at(r.farmhouse), worker: Number(r.worker), silo: at(r.silo), crop: String(r.crop_id), tiles: r.tiles.map(at), amount: Number(r.amount), claimed: !!Number(r.claimed),
    start: ms(r.start), atField: ms(r.at_field), harvested: ms(r.harvested), atSilo: ms(r.at_silo), offloaded: ms(r.offloaded), home: ms(r.home), rested: ms(r.rested),
  }))
}

/** The crops a player holds, by crop id: what all the islands they own hold (land.acre stored, island by island). */
export async function fetchPlayerStore(wallet: string): Promise<Record<string, number>> {
  const islands = await fetchPlayerMaps(wallet), out: Record<string, number> = {}
  for (const held of await Promise.all(islands.map((m) => fetchStored(m.id)))) for (const [id, n] of Object.entries(held)) out[id] = (out[id] ?? 0) + n
  return out
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
/** One farmer for each crop's tiles (up to 200 a farmer). */
export function harvestActions(mapId: string, who: Who, byCrop: Record<string, number[]>) {
  const out = []
  for (const tiles of Object.values(byCrop)) for (let k = 0; k < tiles.length; k += 200) out.push(act(who, 'harvest', { map_id: mapId, tiles: tiles.slice(k, k + 200).map(chainTile) }))
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

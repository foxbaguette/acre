import { CONTRACT } from './config'
import { contractTables, readTable } from './rpc'
import { KINDS } from './constructs'
import type { Building } from '@/engine/build'
import type { Inventory } from '@/engine/types'

/** The things that are not buildings, as land.acre names them in an inventory. */
export const GROUND_ITEMS = ['soil', 'path', 'fence', 'tree'] as const

interface InventoryRow { wallet: string; items: { building_name: string; amount: number }[] }

/** What a player holds (land.acre, table inventory); null when the deployed contract has no inventory yet (then
 *  nothing is limited). A player without a row holds nothing. */
export async function fetchInventory(wallet: string): Promise<Inventory | null> {
  const tables = await contractTables(); if (tables && !tables.includes('inventory')) return null
  const rows = await readTable<InventoryRow>('inventory', CONTRACT, () => true, { index: 1, keyType: 'name', lower: wallet, upper: wallet })
  const out: Inventory = {}
  for (const it of rows.find((r) => r.wallet === wallet)?.items ?? []) out[it.building_name] = (out[it.building_name] ?? 0) + Number(it.amount)
  return out
}

interface BuildCfgRow { building_name: string; building_display_name: string; kind: number }

/** Each building's name in an inventory (buildcfg's building_name, found by its kind). */
export async function fetchItemNames(): Promise<Partial<Record<Building, string>>> {
  const rows = await readTable<BuildCfgRow>('buildcfg', CONTRACT)
  const out: Partial<Record<Building, string>> = {}
  for (const r of rows) { const k = KINDS[Number(r.kind) - 1]; if (k) out[k] = r.building_name }
  return out
}

/** The buildings in buildcfg, for picking what a first island brings. */
export async function fetchBuildCfgNames(): Promise<{ name: string; display: string }[]> {
  const rows = await readTable<BuildCfgRow>('buildcfg', CONTRACT)
  return rows.map((r) => ({ name: r.building_name, display: r.building_display_name || r.building_name }))
}

/** What a player gets with the first island they ever chart (land.acre, table startitems); null when not deployed. */
export async function fetchStartItems(): Promise<{ name: string; amount: number }[] | null> {
  const tables = await contractTables(); if (tables && !tables.includes('startitems')) return null
  const rows = await readTable<{ building_name: string; amount: number }>('startitems', CONTRACT)
  return rows.map((r) => ({ name: r.building_name, amount: Number(r.amount) }))
}

export interface BuildCfg { name: string; display: string; kind: number; building?: Building; main: boolean; mainAccess: boolean; insideOk: boolean; w: number; h: number; requiresPath: boolean; workers: number; storage: number }

/** Every building in buildcfg, with all its settings (building: the site's picture for its kind). */
export async function fetchBuildCfg(): Promise<BuildCfg[]> {
  const rows = await readTable<Record<string, unknown>>('buildcfg', CONTRACT)
  const b = (v: unknown) => v === true || Number(v) === 1
  return rows.map((r) => ({
    name: String(r.building_name), display: String(r.building_display_name ?? ''), kind: Number(r.kind), building: KINDS[Number(r.kind) - 1],
    main: b(r.is_main_building), mainAccess: b(r.needs_main_access), insideOk: b(r.allowed_inside_enclosures), w: Number(r.x_size), h: Number(r.y_size),
    requiresPath: b(r.requires_path), workers: Number(r.workers ?? 0), storage: Number(r.storage ?? 0),
  })).sort((a, z) => a.kind - z.kind)
}

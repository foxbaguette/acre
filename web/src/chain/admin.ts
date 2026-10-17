import { CONTRACT, LIFE_CONTRACT } from './config'
import { readTable } from './rpc'

/** Whether a wallet is one of land.acre's authorizers (table uauth): only they may change the game's settings. */
export async function fetchIsAuthorizer(account: string): Promise<boolean> {
  try {
    const rows = await readTable<{ wallet: string }>('uauth', CONTRACT)
    return rows.some((r) => r.wallet === account)
  } catch {
    return false
  }
}

/** One generator config as land.acre keeps it (table genconfig): its index and every setting. */
export type GenRow = { index: string; [setting: string]: string | number | boolean }

export async function fetchGenRows(): Promise<GenRow[]> {
  const rows = await readTable<Record<string, unknown>>('genconfig', CONTRACT)
  return rows
    .map((r) => {
      const out: GenRow = { index: String(r.index) }
      for (const f of GEN_FIELDS) out[f.name] = f.kind === 'bool' ? r[f.name] === true || r[f.name] === 1 : Number(r[f.name] ?? 0)
      return out
    })
    .sort((a, b) => Number(a.index) - Number(b.index))
}

export interface GenField { name: string; label: string; kind: 'int' | 'bool'; group: string; hint: string; max?: number }

/** Every setting of a generator config, in the contract's order, with what it does (from land.acre's genconfig_t). */
export const GEN_FIELDS: GenField[] = [
  { name: 'gen_version', label: 'generator version', kind: 'int', group: 'the map', hint: 'which version of the generator', max: 255 },
  { name: 'width', label: 'width', kind: 'int', group: 'the map', hint: 'map width in tiles (at least 20)', max: 255 },
  { name: 'height', label: 'height', kind: 'int', group: 'the map', hint: 'map height in tiles (at least 20)', max: 255 },
  { name: 'land_min', label: 'land, at least', kind: 'int', group: 'the land', hint: 'land share of the map (%)', max: 100 },
  { name: 'land_max', label: 'land, at most', kind: 'int', group: 'the land', hint: 'land share of the map (%)', max: 100 },
  { name: 'pen_min', label: 'peninsulas, at least', kind: 'int', group: 'the land', hint: 'peninsulas', max: 255 },
  { name: 'pen_max', label: 'peninsulas, at most', kind: 'int', group: 'the land', hint: 'peninsulas', max: 255 },
  { name: 'bays_min', label: 'bays, at least', kind: 'int', group: 'the land', hint: 'bays', max: 255 },
  { name: 'bays_max', label: 'bays, at most', kind: 'int', group: 'the land', hint: 'bays', max: 255 },
  { name: 'long_chance', label: 'long island', kind: 'int', group: 'the land', hint: 'chance of a long, thin island (%)', max: 100 },
  { name: 'lagoon_chance', label: 'lagoon', kind: 'int', group: 'the land', hint: 'chance of an inner lagoon (%)', max: 100 },
  { name: 'islets_max', label: 'islets, at most', kind: 'int', group: 'the land', hint: 'offshore islets', max: 255 },
  { name: 'beaches', label: 'beaches', kind: 'bool', group: 'the land', hint: 'sand along the coast' },
  { name: 'lake_chance', label: 'lake', kind: 'int', group: 'water', hint: 'chance of a lake (%)', max: 100 },
  { name: 'river_chance', label: 'river', kind: 'int', group: 'water', hint: 'chance of a river (%)', max: 100 },
  { name: 'ponds_min', label: 'ponds, at least', kind: 'int', group: 'water', hint: 'ponds', max: 255 },
  { name: 'ponds_max', label: 'ponds, at most', kind: 'int', group: 'water', hint: 'ponds', max: 255 },
  { name: 'mountain_chance', label: 'hills', kind: 'int', group: 'hills', hint: 'chance of hills (%)', max: 100 },
  { name: 'mountain_min', label: 'hills, at least', kind: 'int', group: 'hills', hint: 'hill share of the land (%)', max: 100 },
  { name: 'mountain_max', label: 'hills, at most', kind: 'int', group: 'hills', hint: 'hill share of the land (%)', max: 100 },
  { name: 'wooded_chance', label: 'wooded slopes', kind: 'int', group: 'hills', hint: 'chance the slopes are wooded (%)', max: 100 },
  { name: 'forests', label: 'forests', kind: 'bool', group: 'forests', hint: 'forests at all' },
  { name: 'forest_min', label: 'forest, at least', kind: 'int', group: 'forests', hint: 'forest share of the grass (%)', max: 100 },
  { name: 'forest_max', label: 'forest, at most', kind: 'int', group: 'forests', hint: 'forest share of the grass (%)', max: 100 },
  { name: 'forest_edges', label: 'lone trees', kind: 'bool', group: 'forests', hint: 'lone trees at forest edges' },
  { name: 'decor', label: 'details', kind: 'bool', group: 'looks', hint: 'small details (visual only)' },
  { name: 'decor_density', label: 'detail density', kind: 'int', group: 'looks', hint: 'detail density (%, visual only)', max: 255 },
  { name: 'meadows', label: 'meadows', kind: 'bool', group: 'looks', hint: 'meadow patches (visual only)' },
  { name: 'meadow_amount', label: 'meadow amount', kind: 'int', group: 'looks', hint: 'meadow amount (%, visual only)', max: 255 },
  { name: 'grass_tint', label: 'lush and dry grass', kind: 'bool', group: 'looks', hint: 'lush and dry grass areas (visual only)' },
  { name: 'tint_strength', label: 'tint strength', kind: 'int', group: 'looks', hint: 'lush and dry grass strength (%, visual only)', max: 255 },
]

/** A config to start from when nothing is copied: the contract's documented defaults. */
export const GEN_DEFAULTS: Record<string, number | boolean> = {
  gen_version: 1, width: 100, height: 100, land_min: 31, land_max: 62, pen_min: 3, pen_max: 7, bays_min: 2, bays_max: 5, long_chance: 35, lagoon_chance: 15,
  islets_max: 4, beaches: true, lake_chance: 50, river_chance: 35, ponds_min: 1, ponds_max: 6, mountain_chance: 75, mountain_min: 10, mountain_max: 22,
  wooded_chance: 65, forests: true, forest_min: 8, forest_max: 24, forest_edges: true, decor: true, decor_density: 100, meadows: true, meadow_amount: 100,
  grass_tint: true, tint_strength: 100,
}

/** What setgenconfig would refuse (the same checks the contract makes), or null. */
export function genProblem(v: Record<string, number | boolean>): string | null {
  const n = (k: string) => Number(v[k])
  for (const f of GEN_FIELDS) if (f.kind === 'int' && (!Number.isInteger(n(f.name)) || n(f.name) < 0 || n(f.name) > (f.max ?? 255))) return `${f.label}: a whole number from 0 to ${f.max ?? 255}`
  if (n('width') < 20 || n('height') < 20) return 'the map must be at least 20 × 20'
  if (!(n('land_min') <= n('land_max'))) return 'land: at least must be no more than at most'
  if (!(n('pen_min') <= n('pen_max'))) return 'peninsulas: at least must be no more than at most'
  if (!(n('bays_min') <= n('bays_max'))) return 'bays: at least must be no more than at most'
  if (!(n('ponds_min') <= n('ponds_max'))) return 'ponds: at least must be no more than at most'
  if (!(n('mountain_min') <= n('mountain_max'))) return 'hills: at least must be no more than at most'
  if (!(n('forest_min') <= n('forest_max'))) return 'forest: at least must be no more than at most'
  return null
}

/** Whether a wallet is one of life.acre's authorizers (its own table uauth). */
export async function fetchIsLifeAuthorizer(account: string): Promise<boolean> {
  try {
    const rows = await readTable<{ wallet: string }>('uauth', LIFE_CONTRACT, () => true, { code: LIFE_CONTRACT })
    return rows.some((r) => r.wallet === account)
  } catch {
    return false
  }
}

/** One species as life.acre keeps it (table species). environments is not set by setspecies: it is only shown. */
export type SpeciesRow = { species_id: string; environments: string[]; [field: string]: string | number | string[] }

export async function fetchSpeciesRows(): Promise<SpeciesRow[]> {
  const rows = await readTable<Record<string, unknown>>('species', LIFE_CONTRACT, () => true, { code: LIFE_CONTRACT })
  return rows
    .map((r) => {
      const out: SpeciesRow = { species_id: String(r.species_id), environments: Array.isArray(r.environments) ? (r.environments as string[]) : [] }
      for (const f of SPECIES_FIELDS) out[f.name] = f.kind === 'int' ? Number(r[f.name] ?? 0) : String(r[f.name] ?? '')
      return out
    })
    .sort((a, b) => Number(a.species_id) - Number(b.species_id))
}

export interface SpeciesField { name: string; label: string; kind: 'int' | 'text' | 'name'; group: string; hint: string; max?: number }

/** Every setting setspecies takes after the id, in the contract's order (from life.acre's species_t). */
export const SPECIES_FIELDS: SpeciesField[] = [
  { name: 'species_name', label: 'species name', kind: 'text', group: 'the species', hint: 'the name picks its picture on the island, e.g. pegasus or sea serpent' },
  { name: 'food_type', label: 'food type', kind: 'name', group: 'the species', hint: 'what it eats: a WAX name (a–z, 1–5 and dots, up to 12)' },
  { name: 'min_size', label: 'size, at least', kind: 'int', group: 'its body', hint: 'size of a new creature (1000 is the picture’s own size)', max: 65535 },
  { name: 'max_size', label: 'size, at most', kind: 'int', group: 'its body', hint: 'size of a new creature', max: 65535 },
  { name: 'min_mass', label: 'mass, at least', kind: 'int', group: 'its body', hint: 'mass of a new creature', max: 65535 },
  { name: 'max_mass', label: 'mass, at most', kind: 'int', group: 'its body', hint: 'mass of a new creature', max: 65535 },
  { name: 'min_speed', label: 'speed, at least', kind: 'int', group: 'its body', hint: 'speed of a new creature (1000 is the usual pace)', max: 65535 },
  { name: 'max_speed', label: 'speed, at most', kind: 'int', group: 'its body', hint: 'speed of a new creature', max: 65535 },
  { name: 'breeding_cooldown', label: 'breeding cooldown', kind: 'int', group: 'its rhythm', hint: 'seconds before it can breed again' },
  { name: 'food_cooldown', label: 'food cooldown', kind: 'int', group: 'its rhythm', hint: 'seconds before it is hungry again' },
]

/** A species to start from when nothing is copied. */
export const SPECIES_DEFAULTS: Record<string, number | string> = {
  species_name: '', food_type: '', min_size: 800, max_size: 1200, min_mass: 800, max_mass: 1200, min_speed: 800, max_speed: 1200, breeding_cooldown: 86400, food_cooldown: 21600,
}

/** What setspecies would refuse (the same checks the contract makes, and a valid name), or null. */
export function speciesProblem(v: Record<string, number | string>): string | null {
  const n = (k: string) => Number(v[k])
  for (const f of SPECIES_FIELDS) if (f.kind === 'int' && (!Number.isInteger(n(f.name)) || n(f.name) < 0 || (f.max !== undefined && n(f.name) > f.max))) return `${f.label}: a whole number${f.max !== undefined ? ` from 0 to ${f.max}` : ' of 0 or more'}`
  if (!String(v.species_name).trim()) return 'the species needs a name'
  if (!/^[a-z1-5.]{0,12}$/.test(String(v.food_type)) || String(v.food_type).endsWith('.')) return 'food type: a WAX name (a–z, 1–5 and dots, up to 12, not ending in a dot)'
  if (!(n('min_size') <= n('max_size'))) return 'size: at least must be no more than at most'
  if (!(n('min_mass') <= n('max_mass'))) return 'mass: at least must be no more than at most'
  if (!(n('min_speed') <= n('max_speed'))) return 'speed: at least must be no more than at most'
  return null
}

/** Whether a wallet is one of lab.acre's authorizers (its own table uauth); false while the lab is not on the chain. */
export async function fetchIsLabAuthorizer(account: string): Promise<boolean> {
  try {
    const rows = await readTable<{ wallet: string }>('uauth', 'lab.acre', () => true, { code: 'lab.acre' })
    return rows.some((r) => r.wallet === account)
  } catch {
    return false
  }
}

// The research lab (lab.acre): upgrades for the farmers (walk, harvest, rest: FEN), a crop's yield (+2% a stage, up to
// 300%: paid with the crop from an island's storage), species to unlock (FEN). Research belongs to the player; one at a
// time, each finished with complete once its time is up. Crops land.acre keeps for the lab (cropcfg lab_unlock) are
// unlocked here for FEN; only then can the player sow them, and they get its starting seeds.
import { contractTables, readTable } from './rpc'

export const LAB_CONTRACT = 'lab.acre'
/** the Fenmark's token contract and symbol, as lab.acre takes them */
export const FEN_CONTRACT = 'fen.acre'
export const FEN_DECIMALS = 4
const q = { code: LAB_CONTRACT }

/** The three upgrades land.acre knows, in the order the lab shows them. */
export const UPGRADES = [
  { key: 'walk', word: 'walking', hint: 'farmers walk faster' },
  { key: 'harvest', word: 'harvesting', hint: 'farmers harvest a tile faster' },
  { key: 'rest', word: 'resting', hint: 'farmers rest shorter between rounds' },
] as const

export interface UpgradeCfg { key: string; name: string; effectBp: number; maxStages: number; startCost: number; costBp: number; startTime: number; timeBp: number }
/** One of a crop's research tracks: yield (+2% a stage, 100 stages) or growth (effectBp faster a stage, maxStages). */
export interface CropRes { cropId: string; track: 'yield' | 'growth'; effectBp: number; maxStages: number; startCost: number; costBp: number; startTime: number; timeBp: number }
export interface SpeciesUnlock { speciesId: string; price: number; time: number }
/** A crop to unlock (lab.acre cropunlock): its price in FEN units and how long its research takes. */
export interface CropUnlock { cropId: string; price: number; time: number }
export type LabConfig = { upgrades: UpgradeCfg[]; crops: CropRes[]; species: SpeciesUnlock[]; cropUnlocks: CropUnlock[] }
export const NO_LAB_CONFIG: LabConfig = { upgrades: [], crops: [], species: [], cropUnlocks: [] }
export interface Research { kind: 'upgrade' | 'crop' | 'cropgrow' | 'species' | 'cropunlock'; key: string; stage: number; started: number; done: number }
export interface Progress { upgrades: Record<string, { stage: number; totalBp: number }>; crops: Record<string, { yield: number; growth: number; growthBp: number }>; species: Set<string>
  /** the crops unlocked (by crop id) */
  cropsUnlocked: Set<string>; research: Research | null }

const ms = (t: string) => Date.parse(t.endsWith('Z') ? t : t + 'Z')
/** "12.5000 FEN" to its units (1 FEN = 10^4). */
const units = (a: string) => Math.round(parseFloat(a) * 10 ** FEN_DECIMALS)
/** Units to "12.5000 FEN". */
export const fenText = (u: number) => `${(u / 10 ** FEN_DECIMALS).toFixed(FEN_DECIMALS)} FEN`

/** Whether lab.acre is on the chain yet. */
export async function hasLab(): Promise<boolean> {
  try { const t = await contractTables(LAB_CONTRACT); return !!t && t.includes('inprogress') } catch { return false }
}

export async function fetchLabConfig(): Promise<LabConfig> {
  const tables = await contractTables(LAB_CONTRACT)
  const [u, c, sp, cu] = await Promise.all([
    readTable<Record<string, string | number>>('upgradecfg', LAB_CONTRACT, () => true, q),
    readTable<Record<string, string | number>>('cropres', LAB_CONTRACT, () => true, q),
    readTable<Record<string, string | number>>('speciescfg', LAB_CONTRACT, () => true, q),
    tables && !tables.includes('cropunlock') ? Promise.resolve([]) : readTable<Record<string, string | number>>('cropunlock', LAB_CONTRACT, () => true, q),   // came with an update
  ])
  return {
    upgrades: u.map((r) => ({ key: String(r.upgrade), name: String(r.display_name || r.upgrade), effectBp: Number(r.effect_bp), maxStages: Number(r.max_stages), startCost: units(String(r.start_cost)), costBp: Number(r.cost_increase_bp), startTime: Number(r.start_time_sec), timeBp: Number(r.time_increase_bp) })),
    crops: c.map((r) => ({ cropId: String(r.crop_id), track: (String(r.track) === 'growth' ? 'growth' : 'yield') as CropRes['track'], effectBp: Number(r.effect_bp ?? 200), maxStages: Number(r.max_stages ?? 100), startCost: Number(r.start_cost), costBp: Number(r.cost_increase_bp), startTime: Number(r.start_time_sec), timeBp: Number(r.time_increase_bp) })),
    species: sp.map((r) => ({ speciesId: String(r.species_id), price: units(String(r.price)), time: Number(r.time_sec) })),
    cropUnlocks: cu.map((r) => ({ cropId: String(r.crop_id), price: units(String(r.price)), time: Number(r.time_sec) })),
  }
}

/** What a player has researched, and the research under way. */
export async function fetchProgress(wallet: string): Promise<Progress> {
  const tables = await contractTables(LAB_CONTRACT)
  const [u, c, s, ip, uc] = await Promise.all([
    readTable<{ upgrade: string; stage: number; total_bp: number }>('playerupg', wallet, () => true, q),
    readTable<{ crop_id: number; stage: number; growth_stage?: number; growth_bp?: number }>('playercrops', wallet, () => true, q),
    readTable<{ species_id: number | string }>('unlocked', wallet, () => true, q),
    readTable<{ wallet: string; kind: string; key: number | string; stage: number; started: string; done: string }>('inprogress', LAB_CONTRACT, () => true, { ...q, lower: wallet, upper: wallet, index: 1, keyType: 'name' }),
    tables && !tables.includes('unlockedcrop') ? Promise.resolve([]) : readTable<{ crop_id: number | string }>('unlockedcrop', wallet, () => true, q),
  ])
  const r = ip.find((x) => x.wallet === wallet)
  return {
    upgrades: Object.fromEntries(u.map((x) => [x.upgrade, { stage: Number(x.stage), totalBp: Number(x.total_bp) }])),
    crops: Object.fromEntries(c.map((x) => [String(x.crop_id), { yield: Number(x.stage), growth: Number(x.growth_stage ?? 0), growthBp: Number(x.growth_bp ?? 0) }])),
    species: new Set(s.map((x) => String(x.species_id))),
    cropsUnlocked: new Set(uc.map((x) => String(x.crop_id))),
    research: r ? { kind: r.kind as Research['kind'], key: r.kind === 'upgrade' ? nameOf(String(r.key)) : String(r.key), stage: Number(r.stage), started: ms(r.started), done: ms(r.done) } : null,
  }
}

/** What a stage costs or takes: the start, grown by bp (hundredths of a percent) for every stage before it, as the
 *  contract counts it (rounding down each time). */
export function grown(start: number, bp: number, stage: number): number {
  let v = BigInt(Math.round(start))
  for (let k = 0; k < stage; k++) v = (v * BigInt(10000 + bp)) / 10000n
  return Number(v)
}

/** A name's number (uint64, as the chain keeps it in inprogress.key) back to its letters. */
function nameOf(value: string): string {
  const chars = '.12345abcdefghijklmnopqrstuvwxyz'
  let v = BigInt(value), out = ''
  for (let i = 0; i < 13; i++) {
    const c = i === 0 ? v & 0x0fn : v & 0x1fn
    out = chars[Number(c)] + out
    v >>= i === 0 ? 4n : 5n
  }
  return out.replace(/\.+$/, '')
}

type Who = { actor: string; permission: string }
/** FEN to the lab for an upgrade's next stage, a species or a crop to unlock: exactly what it costs. */
export const payFen = (who: Who, units: number, memo: string) => ({
  account: FEN_CONTRACT, name: 'transfer', authorization: [who],
  data: { from: who.actor, to: LAB_CONTRACT, quantity: fenText(units), memo },
})
export const researchCrop = (who: Who, cropId: string, track: CropRes['track'], mapId: string) => ({ account: LAB_CONTRACT, name: 'researchcrop', authorization: [who], data: { wallet: who.actor, crop_id: cropId, track, map_id: mapId } })
export const completeResearch = (who: Who) => ({ account: LAB_CONTRACT, name: 'complete', authorization: [who], data: { wallet: who.actor } })

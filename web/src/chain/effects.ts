// What makes a crop's growth time and yield, and a farmer's round, what they are on an island: the crop's or the
// harvest's own numbers, then the island's soil, then the owner's research in the lab, each step as land.acre counts it
// (rounding down where it does), with words for each step so the page can show why.
import type { CropCfg, HarvestCfg } from './farming'
import type { Progress } from './lab'

type Soil = { nutrients: number; moisture: number; acidity: number } | null
export interface Step { what: string; factor: string }
export interface Worked { value: number; steps: Step[] }

const pctText = (p: number) => `${p}%`
const faster = (sec: number, bp: number) => Math.floor((sec * 10000) / (10000 + bp))
const bpText = (bp: number) => `${+(bp / 100).toFixed(2)}%`

/** A crop's growth time on the island (seconds), and how it comes about. */
export function growthWorked(crop: CropCfg, soil: Soil, lab: Progress | null): Worked {
  const steps: Step[] = [{ what: 'the crop’s own', factor: '' }]
  let g = crop.growth
  if (soil && crop.prefers) {
    const dm = Math.abs(soil.moisture - crop.prefers.moisture), da = Math.abs(soil.acidity - crop.prefers.acidity)
    const pct = Math.floor(((100 + 5 * dm) * (100 + 3 * da)) / 100)
    g = Math.floor((g * pct) / 100)
    if (dm) steps.push({ what: `moisture ${dm} off what it likes`, factor: `+${5 * dm}%` })
    if (da) steps.push({ what: `acidity ${da} off`, factor: `+${3 * da}%` })
  }
  const bp = lab?.crops[crop.id]?.growthBp ?? 0
  if (bp) { g = faster(g, bp); steps.push({ what: `growth research, stage ${lab!.crops[crop.id].growth}`, factor: `${bpText(bp)} faster` }) }
  return { value: g, steps }
}

/** What a tile of a crop yields on the island, and how it comes about. */
export function yieldWorked(crop: CropCfg, soil: Soil, lab: Progress | null): Worked {
  const steps: Step[] = [{ what: 'the crop’s own', factor: '' }]
  let y = crop.yield
  if (soil && crop.prefers) {
    const dn = Math.abs(soil.nutrients - crop.prefers.nutrients), da = Math.abs(soil.acidity - crop.prefers.acidity)
    const pct = Math.floor((Math.max(0, 100 - 2 * dn) * Math.max(0, 100 - da)) / 100)
    y = Math.floor((y * pct) / 100)
    if (dn) steps.push({ what: `nutrients ${dn} off what it likes`, factor: `−${Math.min(100, 2 * dn)}%` })
    if (da) steps.push({ what: `acidity ${da} off`, factor: `−${Math.min(100, da)}%` })
  }
  const stage = lab?.crops[crop.id]?.yield ?? 0
  if (stage) { y = Math.floor((y * (100 + 2 * Math.min(100, stage))) / 100); steps.push({ what: `yield research, stage ${stage}`, factor: `+${2 * Math.min(100, stage)}%` }) }
  return { value: y, steps }
}

/** A farmer's round on the island's owner's research: walking (ms a tile), harvesting and resting (s), and why. */
export function roundWorked(hc: HarvestCfg, lab: Progress | null) {
  const bp = (k: string) => lab?.upgrades[k]?.totalBp ?? 0
  const part = (base: number, key: string, word: string): Worked => {
    const b = bp(key), v = b ? faster(base, b) : base
    return { value: v, steps: [{ what: 'the harvest’s own', factor: '' }, ...(b ? [{ what: `${word} research, stage ${lab!.upgrades[key].stage}`, factor: `${bpText(b)} faster` }] : [])] }
  }
  return { walkMs: part(hc.distance_sec * 1000, 'walk', 'walking'), harvest: part(hc.harvest_sec_field, 'harvest', 'harvesting'), offload: hc.offload_sec, rest: part(hc.rest_sec, 'rest', 'resting') }
}

/** A time in words. */
export const timeWords = (s: number) => (s >= 3600 ? `${+(s / 3600).toFixed(1)} h` : s >= 60 ? `${+(s / 60).toFixed(1)} min` : `${+s.toFixed(1)} s`)
/** "10 min (the crop’s own) → moisture 4 off what it likes +20% → …" */
export const stepsText = (w: Worked, show: (v: number) => string, base: number) =>
  [`${show(base)} ${w.steps[0].what}`, ...w.steps.slice(1).map((s) => `${s.what} ${s.factor}`)].join(' · ')
export { pctText }

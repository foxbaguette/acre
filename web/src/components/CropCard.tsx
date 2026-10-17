import { soilEffect, START_SEEDS, type CropCfg } from '@/chain/farming'
import { growthWorked, timeWords, yieldWorked } from '@/chain/effects'
import type { Progress } from '@/chain/lab'

type Soil = { nutrients: number; moisture: number; acidity: number } | null
type Clock = { season: string; daytime: string; weather: string } | null
type Tone = 'good' | 'warn' | 'bad'

const word = (c: string) => c.replace(/-/g, ' ')
const ph = (a: number) => (a / 10).toFixed(1)

/**
 * The card for the crop picked in the build tools, the same for every crop: whether it can be sown here and now and,
 * if not, the one thing in the way; what a tile yields and how long it grows on this island; the island's soil against
 * the soil it likes, value by value, with what each does; the research that counts; when it may be sown; the seeds.
 */
export function CropCard({ crop, soil, research, clock, seeds, locked }: {
  crop: CropCfg; soil: Soil; research: Progress | null; clock: Clock
  /** the seeds of it left to sow (null: not counted on the chain yet) */
  seeds: number | null
  /** only once unlocked in the research lab, and not unlocked yet */
  locked: boolean
}) {
  const fx = soilEffect(crop, soil), y = yieldWorked(crop, soil, research), g = growthWorked(crop, soil, research)
  const lab = research?.crops[crop.id]

  // the island's soil against what it likes: each value, and what being off does
  const rows: { name: string; here: string; likes: string; effect: string; tone: Tone }[] = []
  if (soil && crop.prefers) {
    const dn = Math.abs(soil.nutrients - crop.prefers.nutrients), da = Math.abs(soil.acidity - crop.prefers.acidity), dm = Math.abs(soil.moisture - crop.prefers.moisture)
    const yieldLoss = (p: number) => (p >= 100 ? 'no yield' : `${p}% less yield`)
    rows.push({ name: 'Nutrients', here: `${soil.nutrients}%`, likes: `${crop.prefers.nutrients}%`, effect: dn ? yieldLoss(Math.min(100, 2 * dn)) : 'just right', tone: !dn ? 'good' : 2 * dn >= 100 ? 'bad' : 'warn' })
    rows.push({ name: 'Acidity', here: `pH ${ph(soil.acidity)}`, likes: `pH ${ph(crop.prefers.acidity)}`, effect: da ? `${yieldLoss(Math.min(100, da))}, grows ${3 * da}% longer` : 'just right', tone: !da ? 'good' : da >= 100 ? 'bad' : 'warn' })
    rows.push({ name: 'Moisture', here: `${soil.moisture}%`, likes: `${crop.prefers.moisture}%`, effect: dm ? `grows ${5 * dm}% longer` : 'just right', tone: dm ? 'warn' : 'good' })
  }
  // when it may be sown: only the lists it has, against the island clock now
  const times = ([['Season', crop.seasons, clock?.season], ['Time of day', crop.daytimes, clock?.daytime], ['Weather', crop.weathers, clock?.weather]] as const)
    .filter(([, list]) => list.length).map(([name, list, now]) => ({ name, list: list.join(', '), now, ok: !now || list.includes(now) }))

  // the one thing in the way, the first that counts
  const worst = rows.filter((r) => r.tone === 'bad').map((r) => r.name.toLowerCase())
  const status: { tone: Tone; chip: string; text: string } =
    locked ? { tone: 'bad', chip: 'locked', text: `Unlock it in the research lab first. Unlocking it brings ${START_SEEDS} seeds.` }
    : fx.yieldPct <= 0 ? { tone: 'bad', chip: 'cannot grow here', text: `Nothing would grow here: ${worst.length ? `the ${worst.join(' and the ')} ${worst.length > 1 || worst[0] === 'nutrients' ? 'are' : 'is'}` : 'the soil is'} too far from what it likes.` }
    : times.some((t) => !t.ok) ? { tone: 'warn', chip: 'not now', text: `It cannot be sown at the moment: ${times.filter((t) => !t.ok).map((t) => `it is ${t.now}`).join(', ')}. See below for when.` }
    : seeds !== null && seeds <= 0 ? { tone: 'warn', chip: 'no seeds', text: 'You have no seeds of it left. Harvest a ripe one for seeds to sow more.' }
    : { tone: 'good', chip: 'can be sown', text: seeds === null ? 'Drag over soil to sow it.' : `Drag over soil to sow it: ${seeds} seed${seeds === 1 ? '' : 's'} left, one a tile.` }

  return (
    <div className="crop-card">
      <div className="cc-head">
        <b>{word(crop.name)}</b>
        <span className={`cc-chip is-${status.tone}`}>{status.chip}</span>
      </div>
      <p className="cc-status">{status.text}</p>

      <div className="cc-nums">
        <div><small>a tile yields</small><b className={y.value <= 0 ? 'is-bad' : ''}>{y.value > 0 ? y.value : 'none'}</b><small>its own {crop.yield}</small></div>
        <div><small>grows in</small><b>{timeWords(g.value)}</b><small>its own {timeWords(crop.growth)}</small></div>
      </div>

      {rows.length > 0 && (<>
        <h4>The soil here</h4>
        <table className="cc-soil">
          <thead><tr><th /><th>here</th><th>likes</th><th>so</th></tr></thead>
          <tbody>
            {rows.map((r) => <tr key={r.name} className={`is-${r.tone}`}><th>{r.name}</th><td>{r.here}</td><td>{r.likes}</td><td>{r.effect}</td></tr>)}
          </tbody>
        </table>
      </>)}

      {lab && (lab.yield > 0 || lab.growthBp > 0) && (<>
        <h4>Your research</h4>
        <ul className="cc-list">
          {lab.yield > 0 && <li><span>yield, stage {lab.yield}</span><b>+{2 * Math.min(100, lab.yield)}%</b></li>}
          {lab.growthBp > 0 && <li><span>growth, stage {lab.growth}</span><b>{+(lab.growthBp / 100).toFixed(2)}% faster</b></li>}
        </ul>
      </>)}

      {times.length > 0 && (<>
        <h4>When it can be sown</h4>
        <ul className="cc-list">
          {times.map((t) => <li key={t.name} className={t.ok ? '' : 'is-bad'}><span>{t.name}</span><b>{t.list}</b>{t.now && <small>now {t.now}</small>}</li>)}
        </ul>
      </>)}

      {seeds !== null && !locked && <p className={`cc-seeds${seeds <= 0 ? ' is-bad' : ''}`}><span>Your seeds</span><b>{seeds > 0 ? seeds : 'none'}</b>{crop.seedYield > 0 && <small>a harvest for seeds brings {crop.seedYield} a tile</small>}</p>}
    </div>
  )
}

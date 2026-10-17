import { useEffect, useState } from 'react'

import type { Job } from '@/engine/farmers'
import { timeWords, type roundWorked } from '@/chain/effects'

const cropWord = (c: string) => c.replace(/-/g, ' ')
const inTime = (ms: number) => { const s = Math.max(0, Math.ceil(ms / 1000)); return s >= 3600 ? `${Math.floor(s / 3600)} h ${Math.ceil((s % 3600) / 60)} min` : s >= 60 ? `${Math.floor(s / 60)} min ${s % 60} s` : `${s} s` }

/** Where a farmer is in a job: the part of the round it is in, how long that part has left, and (until it can be
 *  claimed) how long until then. From the chain's times, so it needs no reading. */
export function jobState(j: Job, now: number): { text: string; claimIn: string | null; claimable: boolean } {
  const claimIn = !j.claimed && now < j.offloaded ? inTime(j.offloaded - now) : null
  if (j.claimed) return { text: now < j.home ? `claimed · walking home, ${inTime(j.home - now)}` : now < j.rested ? `claimed · resting, ${inTime(j.rested - now)}` : 'claimed', claimIn, claimable: false }
  if (now < j.start) return { text: `waiting for a free farmer · out in ${inTime(j.start - now)}`, claimIn, claimable: false }
  if (now < j.atField) return { text: `walking to the field · ${inTime(j.atField - now)} left`, claimIn, claimable: false }
  if (now < j.harvested) { const n = j.tiles.length, done = Math.min(n - 1, Math.floor(((now - j.atField) / (j.harvested - j.atField)) * n))
    // (a job of one tile, as every job is now, only says how long; an older job of several says how far it is)
    return { text: n === 1 ? `harvesting · ${inTime(j.harvested - now)} left` : `harvesting, ${done} of ${n} tiles done · ${inTime(j.harvested - now)} left of it`, claimIn, claimable: false } }
  if (now < j.atSilo) return { text: `carrying it to the silo · ${inTime(j.atSilo - now)} left`, claimIn, claimable: false }
  if (now < j.offloaded) return { text: `offloading · ${inTime(j.offloaded - now)} left`, claimIn, claimable: false }
  return { text: 'at the silo: ready to claim', claimIn, claimable: true }
}

/** The farmers' card: every job in the worker queue with where its farmer is, what it brings in (the yield the chain
 *  wrote into the job), a claim for what is at the silo, and the crops the owner holds. */
export function FarmPanel({ onCancel, jobs, cropName, store, seeds, storage, round, canAct, note, onClaim, onClaimAll, onClose }: {
  /** how long a farmer's round takes on this island, and why (the harvest's own, the owner's research) */
  round: ReturnType<typeof roundWorked> | null
  jobs: Job[]; cropName: (id: string) => string; store: Record<string, number>
  /** the owner's seeds by crop id (null: not on the chain yet) */
  seeds: Record<string, number> | null; storage: { capacity: number; used: number } | null; canAct: boolean; note: string | null
  /** calls off a job no farmer has set out for yet */
  onCancel: (job: Job) => void
  onClaim: (job: Job) => void; onClaimAll: (jobs: Job[]) => void; onClose: () => void
}) {
  const [now, setNow] = useState(Date.now())
  useEffect(() => { const t = window.setInterval(() => setNow(Date.now()), 1000); return () => window.clearInterval(t) }, [])
  const list = [...jobs].sort((a, b) => a.start - b.start)
  const held = Object.entries(store).filter(([, n]) => n > 0), sow = Object.entries(seeds ?? {}).filter(([, n]) => n > 0)
  const ready = list.filter((j) => jobState(j, now).claimable), readyAmount = ready.reduce((n, j) => n + j.amount, 0)
  // one row a crop (and one for its seeds): what all its jobs bring in, claimed together, with a line for each farmer;
  // the crops with something to claim first, then by the first farmer out
  const groups = new Map<string, Job[]>()
  for (const j of list) { const k = j.crop + (j.seeds ? ':seeds' : ''); groups.set(k, [...(groups.get(k) ?? []), j]) }
  const rows = [...groups.entries()].map(([key, js]) => ({ key, js, ready: js.filter((j) => jobState(j, now).claimable), waiting: js.filter((j) => !j.claimed && now < j.start) }))
    .sort((p, q) => Number(q.ready.length > 0) - Number(p.ready.length > 0) || p.js[0].start - q.js[0].start)
  return (
    <div className="build-card farm-card" id="farm-card" role="region" aria-label="The farmers">
      <div className="farm-h"><h2>The farmers</h2><button type="button" className="build-link" onClick={onClose}>done</button></div>
      {list.length === 0 && <p className="build-hint hand">No farmer is out. Pick “harvest” under farming, or click the sickle over a ripe field.</p>}
      {rows.filter((r) => r.ready.length).length > 1 && (
        <div className="farm-all"><span className="hand">{ready.length} tiles at the silo · {readyAmount} in all</span>
          <button type="button" className="build-confirm" disabled={!canAct} onClick={() => onClaimAll(ready)}>claim all</button></div>
      )}
      {list.length > 0 && (
        <ul className="farm-jobs">
          {rows.map(({ key, js, ready: here, waiting }) => { const j = js[0], open = js.filter((q) => !q.claimed)
            const amount = open.reduce((n, q) => n + q.amount, 0), ready = here.reduce((n, q) => n + q.amount, 0)
            const what = `${cropWord(cropName(j.crop))}${j.seeds ? ' seeds' : ''}`
            const next = open.filter((q) => now < q.offloaded).sort((p, q) => p.offloaded - q.offloaded)[0]
            return (
              <li key={key} className={`farm-group${here.length ? ' is-ready' : open.length ? '' : ' is-claimed'}`}>
                <div className="farm-row">
                  <img src={`art/crops/${cropName(j.crop)}/7-harvest-front.svg?v=1`} alt="" loading="lazy" />
                  <span className="farm-what">
                    <b>{open.length ? `${amount} ${what}` : what}</b>
                    <small>{j.seeds ? 'harvesting for seeds · ' : ''}{open.length ? `${open.length} tile${open.length === 1 ? '' : 's'}` : 'all claimed'}{ready ? ` · ${ready} at the silo` : ''}</small>
                    {next && <small className="farm-when">{ready ? 'more' : 'can be claimed'} in {jobState(next, now).claimIn}</small>}
                  </span>
                  {here.length > 0 && <button type="button" className="build-confirm" disabled={!canAct} onClick={() => (here.length === 1 ? onClaim(here[0]) : onClaimAll(here))}>claim {ready}</button>}
                </div>
                {/* a line for each farmer still at work (what is at the silo is in the claim above) */}
                {js.some((q) => !jobState(q, now).claimable) && <ul className="farm-hands">
                  {js.filter((q) => !jobState(q, now).claimable).map((q) => <li key={q.id} className={q.claimed ? 'is-claimed' : ''}><span>{q.amount}</span>{jobState(q, now).text}</li>)}
                </ul>}
                {waiting.length > 0 && <button type="button" className="build-link farm-off" disabled={!canAct} title="no farmer has set out for these yet" onClick={() => onCancel({ ...waiting[0], tiles: waiting.flatMap((q) => q.tiles) })}>call off {waiting.length} waiting</button>}
              </li>
            ) })}
        </ul>
      )}
      {note && <p className="build-hint hand" role="status">{note}</p>}
      {round && (
        <details className="farm-why">
          <summary>how long a round takes</summary>
          <ul>
            {[['walking', round.walkMs, (v: number) => `${timeWords(v / 1000)} a tile`], ['harvesting', round.harvest, (v: number) => `${timeWords(v)} a tile`], ['resting', round.rest, (v: number) => timeWords(v)]].map(([word, w, show]) => {
              const worked = w as { value: number; steps: { what: string; factor: string }[] }, fmt = show as (v: number) => string
              return <li key={word as string}><b>{word as string}</b> {fmt(worked.value)}{worked.steps.length > 1 ? <small> · {worked.steps.slice(1).map((s) => `${s.what} ${s.factor}`).join(' · ')}</small> : <small> · as set, no research yet</small>}</li>
            })}
            <li><b>offloading</b> {timeWords(round.offload)}</li>
          </ul>
          <small>Walking is counted in straight steps between the farmer’s home, the tile and the silo or market; the farmers on the island walk the real way at the pace that fits.</small>
        </details>
      )}
      {storage && (
        <div className="farm-storage" title="what the island's buildings can store, and what its harvests filled">
          <span>storage</span><b>{storage.used} / {storage.capacity}</b>
          <i style={{ width: `${storage.capacity ? Math.min(100, (storage.used / storage.capacity) * 100) : 100}%` }} className={storage.used >= storage.capacity ? 'is-full' : ''} />
        </div>
      )}
      <p className="farm-store hand">{held.length ? <>On all your islands: {held.map(([id, n]) => `${n} ${cropWord(cropName(id))}`).join(', ')}.</> : 'Nothing stored on your islands yet.'}</p>
      {seeds && <p className="farm-store hand">{sow.length ? <>Your seeds: {sow.map(([id, n]) => `${n} ${cropWord(cropName(id))}`).join(', ')}.</> : 'No seeds left: harvest a ripe crop for seeds to sow more.'}</p>}
      {!canAct && <p className="rec-foot">Only the island’s owner, signed in, sends farmers and claims what they bring in.</p>}
    </div>
  )
}

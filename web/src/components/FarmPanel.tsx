import { useEffect, useState } from 'react'

import type { Job } from '@/engine/farmers'

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
    return { text: `harvesting, ${done} of ${n} tile${n === 1 ? '' : 's'} done · ${inTime(j.harvested - now)} left of it`, claimIn, claimable: false } }
  if (now < j.atSilo) return { text: `carrying it to the silo · ${inTime(j.atSilo - now)} left`, claimIn, claimable: false }
  if (now < j.offloaded) return { text: `offloading · ${inTime(j.offloaded - now)} left`, claimIn, claimable: false }
  return { text: 'at the silo: ready to claim', claimIn, claimable: true }
}

/** The farmers' card: every job in the worker queue with where its farmer is, what it brings in (the yield the chain
 *  wrote into the job), a claim for what is at the silo, and the crops the owner holds. */
export function FarmPanel({ jobs, cropName, store, storage, canAct, note, onClaim, onClaimAll, onClose }: {
  jobs: Job[]; cropName: (id: string) => string; store: Record<string, number>; storage: { capacity: number; used: number } | null; canAct: boolean; note: string | null
  onClaim: (job: Job) => void; onClaimAll: (jobs: Job[]) => void; onClose: () => void
}) {
  const [now, setNow] = useState(Date.now())
  useEffect(() => { const t = window.setInterval(() => setNow(Date.now()), 1000); return () => window.clearInterval(t) }, [])
  const list = [...jobs].sort((a, b) => a.start - b.start)
  const held = Object.entries(store).filter(([, n]) => n > 0)
  const ready = list.filter((j) => jobState(j, now).claimable), readyAmount = ready.reduce((n, j) => n + j.amount, 0)
  return (
    <div className="build-card farm-card" id="farm-card" role="region" aria-label="The farmers">
      <div className="farm-h"><h2>The farmers</h2><button type="button" className="build-link" onClick={onClose}>done</button></div>
      {list.length === 0 && <p className="build-hint hand">No farmer is out. Pick “harvest” in the build tools, or click the sickle over a ripe field.</p>}
      {ready.length > 1 && (
        <div className="farm-all"><span className="hand">{ready.length} tiles at the silo · {readyAmount} in all</span>
          <button type="button" className="build-confirm" disabled={!canAct} onClick={() => onClaimAll(ready)}>claim all</button></div>
      )}
      {list.length > 0 && (
        <ul className="farm-jobs">
          {list.map((j) => { const st = jobState(j, now)
            return (
              <li key={j.id} className={st.claimable ? 'is-ready' : j.claimed ? 'is-claimed' : ''}>
                <img src={`art/crops/${cropName(j.crop)}/7-harvest-front.svg?v=1`} alt="" loading="lazy" />
                <span className="farm-what"><b>{j.amount} {cropWord(cropName(j.crop))}</b><small>{st.text}</small>{st.claimIn && <small className="farm-when">can be claimed in {st.claimIn}</small>}</span>
                {st.claimable && <button type="button" className="build-confirm" disabled={!canAct} onClick={() => onClaim(j)}>claim</button>}
              </li>
            ) })}
        </ul>
      )}
      {note && <p className="build-hint hand" role="status">{note}</p>}
      {storage && (
        <div className="farm-storage" title="what the island's buildings can store, and what its harvests filled">
          <span>storage</span><b>{storage.used} / {storage.capacity}</b>
          <i style={{ width: `${storage.capacity ? Math.min(100, (storage.used / storage.capacity) * 100) : 100}%` }} className={storage.used >= storage.capacity ? 'is-full' : ''} />
        </div>
      )}
      <p className="farm-store hand">{held.length ? <>On all your islands: {held.map(([id, n]) => `${n} ${cropWord(cropName(id))}`).join(', ')}.</> : 'Nothing stored on your islands yet.'}</p>
      {!canAct && <p className="rec-foot">Only the island’s owner, signed in, sends farmers and claims what they bring in.</p>}
    </div>
  )
}

import { useEffect, useRef, useState } from 'react'

import type { Job } from '@/engine/farmers'

const cropWord = (c: string) => c.replace(/-/g, ' ')

/** The island's storage: a small tag (how full) that opens a card with what fills it, what is on its way, which
 *  buildings give the room, and what the player holds over all their islands. */
export function StorageTag({ storage, stored, jobs, buildings, store, cropName }: {
  storage: { capacity: number; used: number } | null
  /** what the island holds, by crop id (claimed here) */
  stored: Record<string, number>
  jobs: Job[]
  /** the buildings that give room or take in the harvest: name, how many, room each */
  buildings: { name: string; count: number; each: number; dropOff: boolean }[]
  store: Record<string, number>
  cropName: (id: string) => string
}) {
  const [open, setOpen] = useState(false)
  const box = useRef<HTMLDivElement>(null)
  useEffect(() => {   // a click anywhere else, or Escape, closes the card
    if (!open) return
    const off = (e: Event) => { if (e instanceof KeyboardEvent ? e.key === 'Escape' : !box.current?.contains(e.target as Node)) setOpen(false) }
    document.addEventListener('pointerdown', off); document.addEventListener('keydown', off)
    return () => { document.removeEventListener('pointerdown', off); document.removeEventListener('keydown', off) }
  }, [open])
  if (!storage) return null
  const { capacity, used } = storage, free = Math.max(0, capacity - used), full = used >= capacity
  const fill = capacity ? Math.min(100, (used / capacity) * 100) : 100
  // what it holds, what is on its way (with the farmers, not claimed yet), both by crop; and what the player holds over
  // all their islands, when they have more than this one with anything in it
  const here = Object.entries(stored).filter(([, n]) => n > 0).sort((a, b) => b[1] - a[1])
  const onWay: Record<string, number> = {}; for (const j of jobs) if (!j.claimed) onWay[j.crop] = (onWay[j.crop] ?? 0) + j.amount
  const coming = Object.values(onWay).reduce((n, v) => n + v, 0)
  const held = Object.entries(store).filter(([, n]) => n > 0)
  const elsewhere = held.some(([id, n]) => n !== (stored[id] ?? 0))
  const row = (id: string, n: number, sign = '') => <li key={id}><span><img src={`art/crops/${cropName(id)}/7-harvest-front.svg?v=1`} alt="" />{cropWord(cropName(id))}</span><b>{sign}{n}</b></li>
  return (
    <div className="store-wrap" ref={box}>
      <button type="button" className={`store-tag${full ? ' is-full' : ''}`} aria-expanded={open} aria-controls="store-card" title="The island’s storage" onClick={() => setOpen(!open)}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M3 10l9-6 9 6M5 9v11h14V9M9 20v-6h6v6M9 14l6 6M15 14l-6 6" /></svg>
        <span><b>{used} / {capacity}</b><small>storage</small></span>
        <i style={{ width: `${fill}%` }} />
      </button>
      {open && (
        <div className="store-card" id="store-card" role="dialog" aria-label="The island’s storage">
          <h2>The island’s storage</h2>
          <div className={`store-bar${full ? ' is-full' : ''}`}><i style={{ width: `${fill}%` }} /></div>
          <p className="store-nums"><b>{used}</b> of <b>{capacity}</b> filled · <b>{free}</b> free</p>
          {full && <p className="store-warn hand">Full: no harvest can start until there is more room. Put up a silo, or more of them.</p>}
          <h3>What it holds</h3>
          {here.length ? <ul className="store-list">{here.map(([id, n]) => row(id, n))}</ul> : <p className="store-note">Nothing yet: what the farmers bring in lands here once it is claimed.</p>}
          {coming > 0 && (<>
            <h3>On its way</h3>
            <ul className="store-list">{Object.entries(onWay).map(([id, n]) => row(id, n, '+'))}</ul>
            <p className="store-note">With the farmers, not claimed yet; it takes its room from the moment they are sent.</p>
          </>)}
          <h3>Its room</h3>
          {buildings.length ? (
            <ul className="store-list">
              {buildings.map((b) => <li key={b.name}><span>{b.count > 1 ? `${b.count} × ` : ''}{b.name}</span><b>{b.each ? `+${b.each * b.count}` : 'takes it in'}</b></li>)}
            </ul>
          ) : <p className="store-note">No building gives room yet: a silo does, and the market takes the harvest in.</p>}
          {elsewhere && (<>
            <h3>All your islands</h3>
            <ul className="store-list">{held.map(([id, n]) => row(id, n))}</ul>
          </>)}
        </div>
      )}
    </div>
  )
}

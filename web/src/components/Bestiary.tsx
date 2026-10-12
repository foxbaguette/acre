import { useEffect, useMemo, useState } from 'react'

import type { Creature } from '@/chain/life'
import { BEASTS } from '@/engine/creatures'

/** Where a species lives, in the journal's words. */
const HOMES = { land: 'on the land', water: 'in the water', air: 'in the sky' } as const
const TABS: ['all' | 'land' | 'water' | 'air', string][] = [['all', 'all'], ['land', 'land'], ['water', 'water'], ['air', 'sky']]

/** "deepsea__crystal-crab-polished" -> "Crystal Crab" */
export const speciesTitle = (key: string) =>
  key.split('__')[1].replace(/-polished$/, '').split('-').map((w) => w[0].toUpperCase() + w.slice(1)).join(' ')

const sizeWords = (s: number) => (s < 0.75 ? 'tiny' : s < 1.1 ? 'small' : s < 1.5 ? 'middling' : s < 2 ? 'large' : 'huge')

const SEEN_KEY = 'ua-bestiary'
/** For now every species is shown in full; false hides the ones not met yet behind their shadow again. */
const REVEAL_ALL = true
/** The species the player has come across on any island (kept on this device). */
export function seenSpecies(): Set<string> {
  try { return new Set(JSON.parse(localStorage.getItem(SEEN_KEY) ?? '[]') as string[]) } catch { return new Set() }
}
/** Notes these species as come across. */
export function noteSeen(keys: string[]) {
  const seen = seenSpecies(), before = seen.size
  for (const k of keys) seen.add(k)
  if (seen.size !== before) try { localStorage.setItem(SEEN_KEY, JSON.stringify([...seen])) } catch { /* private window: only for this visit */ }
}

/**
 * The bestiary: every species of the islands on the pages of a field journal. Those met (here or on another island)
 * are drawn in full; the others only as a shadow, with where they are said to live. A species' page lists the ones on
 * this island, each with a button to find it.
 */
export function Bestiary({ creatures, keyOf, onFind, onClose }: {
  creatures: Creature[]
  keyOf: (speciesName: string) => string | null
  onFind: (id: number | string) => void
  onClose: () => void
}) {
  const [tab, setTab] = useState<'all' | 'land' | 'water' | 'air'>('all')
  const [open, setOpen] = useState<string | null>(null)
  const here = useMemo(() => {
    const m = new Map<string, Creature[]>()
    for (const c of creatures) { const k = keyOf(c.speciesName); if (k) m.set(k, [...(m.get(k) ?? []), c]) }
    return m
  }, [creatures, keyOf])
  const seen = useMemo(() => { const s = REVEAL_ALL ? new Set(BEASTS.map((b) => b[0])) : seenSpecies(); for (const k of here.keys()) s.add(k); return s }, [here])
  useEffect(() => {
    const key = (e: KeyboardEvent) => { if (e.key === 'Escape') { e.stopPropagation(); if (open) setOpen(null); else onClose() } }
    window.addEventListener('keydown', key, true)
    return () => window.removeEventListener('keydown', key, true)
  }, [open, onClose])
  const list = BEASTS.filter((b) => tab === 'all' || b[1] === tab)
  const page = open ? BEASTS.find((b) => b[0] === open) ?? null : null
  return (
    <div className="bestiary-shade" onClick={onClose}>
      <section className="bestiary" role="dialog" aria-modal="true" aria-label="Bestiary" onClick={(e) => e.stopPropagation()}>
        <header>
          <div>
            <small>field journal</small>
            <h2>Bestiary</h2>
            <p className="hand">{REVEAL_ALL ? BEASTS.length + ' species' : seen.size + ' of ' + BEASTS.length + ' species met'}{here.size ? `, ${here.size} of them on this island` : ''}.</p>
          </div>
          <button type="button" className="hint-close" onClick={onClose} aria-label="Close the bestiary">&times;</button>
        </header>
        {page ? (
          <div className="bestiary-page">
            <button type="button" className="build-link" onClick={() => setOpen(null)}>&larr; all species</button>
            <div className="bp-body">
              <div className={`bp-portrait${seen.has(page[0]) ? '' : ' unknown'}`}>
                <img src={`art/topdown/${page[0]}/side.svg?v=1`} alt={seen.has(page[0]) ? speciesTitle(page[0]) : 'An unknown species'} />
              </div>
              <div>
                <h3>{seen.has(page[0]) ? speciesTitle(page[0]) : 'Not yet met'}</h3>
                <p className="hand">{seen.has(page[0]) ? `A ${sizeWords(page[2])} creature that lives ${HOMES[page[1]]}.` : `Said to live ${HOMES[page[1]]}. Its shape is all the journal knows of it.`}</p>
                {(here.get(page[0]) ?? []).length > 0 ? (
                  <>
                    <p className="bp-count">On this island: {(here.get(page[0]) ?? []).length}</p>
                    <ul className="bp-list">
                      {(here.get(page[0]) ?? []).map((c) => (
                        <li key={String(c.id)}>
                          <span><b>{c.name}</b> <small>no. {String(c.id)}</small></span>
                          <span className="bp-swatch">{c.colors.slice(0, 3).map((h, i) => <i key={i} style={{ background: `#${h}` }} />)}</span>
                          <button type="button" className="build-link" onClick={() => onFind(c.id)}>find</button>
                        </li>
                      ))}
                    </ul>
                  </>
                ) : <p className="bp-count">None on this island.</p>}
              </div>
            </div>
          </div>
        ) : (
          <>
            <div className="bestiary-tabs" role="tablist" aria-label="Where they live">
              {TABS.map(([id, label]) => (
                <button key={id} type="button" role="tab" aria-selected={tab === id} onClick={() => setTab(id)}>{label}</button>
              ))}
            </div>
            <ul className="bestiary-grid">
              {list.map(([key, home]) => {
                const known = seen.has(key), n = here.get(key)?.length ?? 0
                return (
                  <li key={key}>
                    <button type="button" className={known ? '' : 'unknown'} onClick={() => setOpen(key)}>
                      <span className="bg-art"><img src={`art/topdown/${key}/side.svg?v=1`} alt="" loading="lazy" /></span>
                      <b>{known ? speciesTitle(key) : '? ? ?'}</b>
                      <small>{home === 'air' ? 'sky' : home}{n ? ` · ${n} here` : ''}</small>
                    </button>
                  </li>
                )
              })}
            </ul>
          </>
        )}
      </section>
    </div>
  )
}

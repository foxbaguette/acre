import { useEffect, useRef, useState, type CSSProperties } from 'react'

import { chainPart, fetchConstructs, fetchEnclosures, saveActions } from '@/chain/constructs'
import { fetchLifeforms, type Creature } from '@/chain/life'
import { Bestiary, noteSeen } from '@/components/Bestiary'
import { CreatureCard } from '@/components/CreatureCard'
import { fetchMapTiles, fetchPlayerMaps, forgetMapTiles, mapStats, type MapStats } from '@/chain/maps'
import { startEngine } from '@/engine'
import { loadBuilds as readBuilds, saveForm } from '@/engine/build'
import { CROPS } from '@/engine/crops'
import type { Builds, BuildTool, IslandView } from '@/engine/types'
import { AccountTag } from '@/journal/Header'
import { friendlyError, signer, transact } from '@/wallet/session'

type Save = { state: 'idle' } | { state: 'signing' } | { state: 'error'; message: string }

type Load = { state: 'reading' } | { state: 'drawing' } | { state: 'ready' } | { state: 'error'; message: string }

const HINT_KEY = 'ua-island-hint-seen'
const seenHint = () => {
  try {
    return localStorage.getItem(HINT_KEY) === '1'
  } catch {
    return false
  }
}

const pct = (v: number) => `${Math.round(v * 1000) / 10}%`

// The player's builds on each island: the island shows only what land.acre keeps (table constructs). This browser keeps
// the crops, which are not constructions. On an island the signed-in wallet does not own, builds last only this visit.
const buildKey = (mapId: string) => `ua-builds-${mapId}`
const loadBuilds = (mapId: string): Builds => {
  try {
    return readBuilds(JSON.parse(localStorage.getItem(buildKey(mapId)) ?? 'null'), 100)
  } catch {
    return {}
  }
}
const saveBuilds = (mapId: string, builds: Builds) => {
  try {
    localStorage.setItem(buildKey(mapId), JSON.stringify(saveForm(builds)))
  } catch {
    /* kept for this visit only */
  }
}
/** The chain's builds, with this browser's crops laid back on the chain's soil. */
const withCrops = (chain: Builds, local: Builds): Builds => {
  const out: Builds = JSON.parse(JSON.stringify(chain))
  for (const k in local) { const { c, t, h } = local[k]; if (c && out[k]?.g === 'soil') out[k] = { ...out[k], c, ...(t ? { t } : {}), ...(h ? { h } : {}) } }
  return out
}
const cropName = (c: string) => c.replace(/-/g, ' ')
/** Everyone living in the island's farmhouses: one farmer per stage. */
const farmersIn = (b: Builds) => Object.values(b).reduce((n, c) => n + (c.s === 'farmhouse' ? c.lv ?? 1 : 0), 0)

const TOOLS: { id: BuildTool; label: string; hint: string; icon: string }[] = [
  { id: 'fence', label: 'enclosure', hint: 'Drag to draw a fence, any shape; close the loop and it is an enclosure. To enlarge one, draw the new side out from the old fence and erase the old stretch. Shift + drag: a rectangle.', icon: 'M3 20V8l2-3 2 3v12M17 20V8l2-3 2 3v12M3 11h18M3 16h18' },
  { id: 'path', label: 'path', hint: 'Drag to lay a path where you go, over grass, soil or sand; trees in the way make room. Shift + drag: a whole area.', icon: 'M7 21c0-4 3-5 3-9S7 7 7 3M17 21c0-4-3-5-3-9s3-5 3-9M12 6v1M12 11v1M12 16v1' },
  { id: 'soil', label: 'soil', hint: 'Drag over open grass to turn it into soil, ready for sowing.', icon: 'M3 17c3-2 6-2 9 0s6 2 9 0M3 12c3-2 6-2 9 0s6 2 9 0M8 7l1-3M15 7l1-3' },
  { id: 'crop', label: 'crops', hint: 'Pick a crop, then drag over soil to sow it. It grows a stage every ten seconds and is ready in under a minute.', icon: 'M12 21V10M12 14c-4 0-6-3-6-6 3 0 6 2 6 6zM12 11c0-4 2-7 6-7 0 4-2 7-6 7z' },
  { id: 'farmhouse', label: 'farmhouse', hint: 'Click to put up a farmhouse (3 × 4 tiles) on open grass; R turns it. Its door must reach a path: one up to two tiles away is joined to it. One farmer moves in; upgrade it for more.', icon: 'M3 11l9-7 9 7M5 10v10h14V10M10 20v-6h4v6' },
  { id: 'upgrade', label: 'upgrade', hint: 'Click a farmhouse to raise it a stage: each stage houses one more farmer, up to five.', icon: 'M12 20V6M6 12l6-6 6 6M5 21h14' },
  { id: 'lab', label: 'observatory', hint: 'Click to put up an observatory (4 × 4 tiles) on open grass; R turns it. Its door must reach a path: one up to two tiles away is joined to it.', icon: 'M4 20h16M5 20v-6h14v6M5 14a7 7 0 0 1 14 0M12 7l5-4M10 20v-3h4v3' },
  { id: 'silo', label: 'silo', hint: 'Click to put up a silo (2 × 2 tiles) on open grass, to store the harvest.', icon: 'M7 21V9a5 5 0 0 1 10 0v12M7 21h10M7 13h10M7 17h10M12 4V2' },
  { id: 'bakery', label: 'bakery', hint: 'Click to put up a bakery (2 × 2 tiles) on open grass; R turns it. Its door must reach a path: one up to two tiles away is joined to it.', icon: 'M4 20h16M5 20v-7l7-5 7 5v7M15 9V5h2v5.5M9 20v-4h3v4' },
  { id: 'market', label: 'market', hint: 'Click to lay out a market (4 × 5 tiles) on open grass: a market hall with a cobbled square, stalls and a fountain; R turns it. Its square must reach a path: one up to two tiles away is joined to it.', icon: 'M4 21V11M20 21V11M3 11l3-6h12l3 6zM3 11h18M8 21v-5h8v5M12 5V3' },
  { id: 'kitchen', label: 'kitchen', hint: 'Click to lay out an outdoor kitchen (3 × 2 tiles) on open grass: a bread oven, a hearth and a table; R turns it.', icon: 'M4 20h16M6 20v-6a6 6 0 0 1 12 0v6M10 20v-3h4v3M17 8c0-2 1-3 0-5' },
  { id: 'torch', label: 'torch', hint: 'Click to set up a torch (1 tile). It burns through the evening and the night.', icon: 'M12 21v-9M8 8h8l-1.5 4h-5zM12 8c-2-2-1-4 0-6 1 2 2 4 0 6' },
  { id: 'nest', label: 'nest', hint: 'Click to lay a straw hatching nest (2 × 2 tiles) on open grass.', icon: 'M3 13c0 4 4 7 9 7s9-3 9-7M3 13c3 2 15 2 18 0M9 11a3 4 0 1 0 6 0a3 4 0 1 0-6 0' },
  { id: 'tree', label: 'trees', hint: 'Drag over open grass to plant trees, one a tile: mostly broadleaf, now and then a conifer.', icon: 'M12 21v-5M12 3c-4 0-7 3-7 6.5S8 16 12 16s7-3 7-6.5S16 3 12 3z' },
  { id: 'harvest', label: 'harvest', hint: 'Drag over crops to mark the ripe ones for harvest; the farmers bring them to a silo. Start on a mark to take marks back. A ripe field also shows a sickle: click it to harvest the whole field.', icon: 'M5 19l5-5M10 14c1-6 6-9 10-8-3 1-6 4-6 8' },
  { id: 'erase', label: 'erase', hint: 'Drag to clear tiles. Start on a fence and only fences go; start on a tree and only trees and plants go (the same for buildings, crops, paths and soil).', icon: 'M15 4l5 5-9 9H6l-2-2 11-12zM9 9l6 6M4 20h16' },
]

/**
 * The island itself, full screen. The journal only shows up in small pieces around the edges: the island's
 * name tag, who is signed in, zoom, the time of day, the weather and a field-notes card.
 */
export function GamePage({ mapId, account, wallet, onSignOut, onLeave }: {
  mapId: string
  account: string
  wallet: string | null
  onSignOut: () => void
  onLeave: () => void
}) {
  const [load, setLoad] = useState<Load>({ state: 'reading' })
  const [name, setName] = useState(`Island ${mapId}`)
  const [stats, setStats] = useState<MapStats | null>(null)
  const [notesOpen, setNotesOpen] = useState(false)
  const [lifeforms, setLifeforms] = useState<number | null>(null)
  const [creatures, setCreatures] = useState<Creature[]>([])
  const [selected, setSelected] = useState<string | null>(null)
  const [hint, setHint] = useState(!seenHint())
  const [buildOpen, setBuildOpen] = useState(false)
  const [bestiaryOpen, setBestiaryOpen] = useState(false)
  const [tool, setTool] = useState<BuildTool | null>(null)
  const [undoable, setUndoable] = useState(false)
  const [pending, setPending] = useState(0)
  const [planKind, setPlanKind] = useState<'build' | 'erase' | 'both'>('build')
  const confirmWords = planKind === 'erase' ? 'confirm erasing' : planKind === 'both' ? 'confirm changes' : 'confirm building'
  const [farmers, setFarmers] = useState(0)
  const [store, setStore] = useState<Record<string, number>>({})
  const [crop, setCrop] = useState<string>('wheat')
  const started = useRef<IslandView | null>(null)
  const [save, setSave] = useState<Save>({ state: 'idle' })
  const [owner, setOwner] = useState<string | null>(null)
  /** what land.acre holds for this island, as the page keeps it (null until read) */
  const onChain = useRef<Builds | null>(null)
  const who = signer()
  const toChain = !!who && who.actor === owner && onChain.current !== null
  const selectedCreature = selected === null ? null : creatures.find((c) => String(c.id) === selected) ?? null

  useEffect(() => {
    let live = true
    fetchPlayerMaps(account).then((maps) => {
      const m = maps.find((x) => x.id === mapId)
      if (live && m?.name) setName(m.name)
      if (live && m) setOwner(m.owner)
    }, () => undefined)
    Promise.all([fetchMapTiles(mapId), fetchConstructs(mapId)]).then(
      ([tiles, chain]) => {
        if (!live || started.current) return
        setStats(mapStats(tiles))
        setLoad({ state: 'drawing' })
        // let the "sketching" note paint before the first build starts
        setTimeout(() => {
          if (!live || started.current) return
          try {
            // what the chain holds, with this browser's crops on its soil
            onChain.current = chain
            const saved = withCrops(chain, loadBuilds(mapId))
            started.current = startEngine({ tiles, mapId, builds: saved })
            if (import.meta.env.DEV) (window as unknown as { __island: IslandView }).__island = started.current
            const view = started.current
            view.ready.then(() => {
              if (!live) return
              setLoad({ state: 'ready' })
              // the creatures living here, from life.acre; the island stays usable if this read fails
              view.onSelect((id) => setSelected(id === null ? null : String(id)))
              setFarmers(farmersIn(saved))
              view.onStore(setStore)
              view.onBuild((builds, canUndo, planned, kind) => { saveBuilds(mapId, builds); setUndoable(canUndo); setPending(planned); setPlanKind(kind); setFarmers(farmersIn(builds)) })
              fetchEnclosures(mapId).then((list) => live && view.setEnclosures(list), (err) => console.warn('Could not read the enclosures', err))
              fetchLifeforms(mapId)
                .then((list) => { if (live) setCreatures(list); noteSeen(list.map((c) => view.spriteFor(c.speciesName)).filter((k): k is string => !!k)); return view.setLifeforms(list) })
                .then((n) => live && setLifeforms(n), (err) => { console.warn('Could not load the lifeforms', err); if (live) setLifeforms(null) })
            })
          } catch (err) {
            setLoad({ state: 'error', message: err instanceof Error ? err.message : String(err) })
          }
        }, 60)
      },
      (err) => live && setLoad({ state: 'error', message: err instanceof Error ? err.message : String(err) })
    )
    return () => {
      live = false
    }
  }, [account, mapId])

  // the picked tool goes to the island; Esc puts it away
  useEffect(() => { started.current?.setBuildTool(tool, crop) }, [tool, crop])
  useEffect(() => {
    const key = (e: KeyboardEvent) => { if (e.key === 'Escape') setTool(null) }
    document.addEventListener('keydown', key)
    return () => document.removeEventListener('keydown', key)
  }, [])
  const closeBuild = () => { setTool(null); setBuildOpen(false) }
  useEffect(() => {                                              // a right click on the map (not a right-drag) puts the build tools away
    if (!tool) return
    let at: [number, number] | null = null
    const down = (e: PointerEvent) => { at = e.button === 2 && (e.target as HTMLElement).tagName === 'CANVAS' ? [e.clientX, e.clientY] : null }
    const up = (e: PointerEvent) => { if (e.button === 2 && at && Math.hypot(e.clientX - at[0], e.clientY - at[1]) < 6) closeBuild(); at = null }
    window.addEventListener('pointerdown', down, true); window.addEventListener('pointerup', up, true)
    return () => { window.removeEventListener('pointerdown', down, true); window.removeEventListener('pointerup', up, true) }
  }, [tool])

  /** Confirms the plan: on the owner's island land.acre is asked first (one transaction), and only once it is signed
   *  does the plan stand. Crops and anything on another's island stay in this browser. */
  const confirm = async () => {
    const view = started.current, w = signer()
    if (!view || save.state === 'signing') return
    if (!w || w.actor !== owner || !onChain.current) { view.confirmBuild(); return }
    const next = chainPart(view.plan()), actions = saveActions(mapId, w, onChain.current, next)
    if (!actions.length) { view.confirmBuild(); return }
    setSave({ state: 'signing' }); setTool(null)
    try {
      await transact(actions)
    } catch (err) {
      setSave({ state: 'error', message: friendlyError(err) })
      return
    }
    const fenced = Object.keys({ ...onChain.current, ...next }).some((k) => !!onChain.current![Number(k)]?.f !== !!next[Number(k)]?.f)
    onChain.current = next
    if (actions.some((a) => a.name === 'clearnature')) forgetMapTiles(mapId)
    view.confirmBuild(); setSave({ state: 'idle' })
    // the contract counts the enclosures anew when fences change: read them once a node has the block
    if (fenced) { view.setEnclosures([]); setTimeout(() => fetchEnclosures(mapId).then((list) => view.setEnclosures(list), () => undefined), 2500) }
  }
  const confirmLabel = save.state === 'signing' ? 'signing…' : confirmWords
  const saveNote = save.state === 'error' ? <p className="build-error" role="alert">{save.message}</p> : null

  const closeHint = () => {
    setHint(false)
    try {
      localStorage.setItem(HINT_KEY, '1')
    } catch {
      /* the hint simply shows again next time */
    }
  }

  return (
    <div className="game">
      <h1 className="sr-only">{name}</h1>
      <div className="view" id="view" aria-label={`${name}, seen from above. Drag to look around, scroll or pinch to zoom.`} role="img">
      </div>

      {load.state !== 'ready' && (
        <div className="game-veil" role="status">
          <svg className="veil-stamp" aria-hidden="true">
            <use href="#stamp" />
          </svg>
          {load.state === 'error' ? (
            <>
              <p className="hand">This island could not be opened.</p>
              <p className="veil-small">{load.message}</p>
              <button type="button" className="btn small" onClick={onLeave}>
                Back to the journal
              </button>
            </>
          ) : (
            <p className="hand">{load.state === 'reading' ? 'Reading the chart…' : 'Sketching the island…'}</p>
          )}
        </div>
      )}

      {/* ---------- the island's name tag, top left ---------- */}
      <div className="hud hud-tl">
        <div className="isle-tag">
          <svg className="isle-tag-mark" aria-hidden="true">
            <use href="#stamp-mark" />
          </svg>
          <span>
            <small>map no. {mapId}</small>
            <b>{name}</b>
          </span>
        </div>
        <button type="button" className="back-link" onClick={onLeave}>
          <svg width="30" height="16" viewBox="0 0 34 18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true">
            <path d="M32 10C24 7 14 6 3 9M9 3C6.5 5 4.5 7 3 9c2.5 1.3 5 3 7 5" />
          </svg>
          back to the journal
        </button>
        {load.state === 'ready' && (
          <div className="build">
            <button type="button" className="wx-tag build-toggle" aria-expanded={buildOpen} aria-controls="build-card" onClick={() => (buildOpen ? closeBuild() : setBuildOpen(true))}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M14 6l4 4M3 21l9-9M12.5 4.5l3-1.5 5.5 5.5-1.5 3-3-3-1 1-3-3 1-1z" />
              </svg>
              build
            </button>
            {buildOpen && (
              <div className="build-card" id="build-card">
                <div className="build-tools" role="group" aria-label="What to build">
                  {TOOLS.map((t) => (
                    <button key={t.id} type="button" className="build-tool" aria-pressed={tool === t.id} onClick={() => setTool(tool === t.id ? null : t.id)}>
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                        <path d={t.icon} />
                      </svg>
                      {t.label}
                    </button>
                  ))}
                </div>
                <p className="build-hint hand">{tool ? TOOLS.find((t) => t.id === tool)!.hint : 'Pick what to build, then drag across the island.'}</p>
                {tool === 'crop' && (
                  <div className="crop-pick" role="radiogroup" aria-label="Which crop to sow">
                    {CROPS.map((c) => (
                      <button key={c} type="button" role="radio" aria-checked={crop === c} className="crop-seed" title={cropName(c)} onClick={() => setCrop(c)}>
                        <img src={`art/crops/${c}/7-harvest-front.svg?v=1`} alt={cropName(c)} loading="lazy" />
                      </button>
                    ))}
                  </div>
                )}
                {tool === 'crop' && <p className="crop-name">{cropName(crop)}</p>}
                {(tool === 'farmhouse' || tool === 'lab' || tool === 'nest' || tool === 'silo' || tool === 'bakery' || tool === 'kitchen' || tool === 'market') && <button type="button" className="build-link" onClick={() => started.current?.rotateBuild()}>rotate (R)</button>}
                <div className="build-actions">
                  <button type="button" className="build-link" disabled={!undoable} onClick={() => started.current?.undoBuild()}>undo</button>
                  <button type="button" className="build-link" onClick={closeBuild}>done</button>
                </div>
                <p className="build-plan hand">{pending ? `${pending} tile${pending === 1 ? '' : 's'} planned: blue goes up, red comes down. Click a mark again to take it back.` : 'Nothing planned yet. What you mark shows as a hologram until you confirm it.'}</p>
                <div className="build-actions">
                  <button type="button" className="build-confirm" disabled={!pending || save.state === 'signing'} onClick={confirm}>{confirmLabel}</button>
                  <button type="button" className="build-link" disabled={!pending || save.state === 'signing'} onClick={() => { setSave({ state: 'idle' }); started.current?.discardBuild() }}>discard</button>
                </div>
                {saveNote}
                <p className="rec-foot">{toChain ? 'Confirming saves to the chain (your wallet signs); crops stay on this device.' : 'Not saved: only the island’s owner, signed in, saves to the chain. Gone when you leave.'} Right-drag moves the map; a right click puts the tools away.</p>
              </div>
            )}
            <button type="button" className="wx-tag bestiary-toggle" aria-haspopup="dialog" onClick={() => { closeBuild(); setBestiaryOpen(true) }}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M4 5c3-1.5 5.5-1.5 8 0v14c-2.5-1.5-5-1.5-8 0zM20 5c-3-1.5-5.5-1.5-8 0v14c2.5-1.5 5-1.5 8 0z" />
              </svg>
              bestiary
            </button>
            {!buildOpen && pending > 0 && (
              <div className="build-pending">
                <span className="hand">{pending} planned</span>
                <button type="button" className="build-confirm" disabled={save.state === 'signing'} onClick={confirm}>{confirmLabel}</button>
                <button type="button" className="build-link" disabled={save.state === 'signing'} onClick={() => { setSave({ state: 'idle' }); started.current?.discardBuild() }}>discard</button>
                {saveNote}
              </div>
            )}
          </div>
        )}
        <span className="hud-fps" id="fps" aria-live="off" />
      </div>

      {/* ---------- who is signed in, top right ---------- */}
      <div className="hud hud-tr">
        <AccountTag account={account} wallet={wallet} onSignOut={onSignOut} />
      </div>

      {/* ---------- zoom, right edge ---------- */}
      <div className="hud hud-r" role="group" aria-label="Zoom">
        <button type="button" className="knob" id="zin" aria-label="Zoom in">
          +
        </button>
        <button type="button" className="knob" id="zout" aria-label="Zoom out">
          &minus;
        </button>
        <button type="button" className="knob knob-fit" id="zfit" aria-label="Show the whole map">
          <svg viewBox="0 0 100 100" fill="none" stroke="currentColor" aria-hidden="true">
            <circle cx="50" cy="50" r="34" strokeWidth="5" />
            <path d="M50 10 58 50 50 90 42 50Z" fill="currentColor" fillOpacity=".25" strokeWidth="4" />
            <path d="M50 10 58 50H42Z" fill="currentColor" />
          </svg>
        </button>
      </div>

      {/* ---------- time of day and weather, bottom left ---------- */}
      <div className="hud hud-bl">
        <div className="hud-row" role="group" aria-label="Time of day">
          <span className="hud-label">daytime</span>
          <button type="button" className="wx-tag" data-daytime="morning" aria-pressed="false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
              <path d="M4 16h16M7 16a5 5 0 0 1 10 0M12 4v3M5.5 8.5l2 2M18.5 8.5l-2 2M2 20h20" />
            </svg>
            morning
          </button>
          <button type="button" className="wx-tag" data-daytime="day" aria-pressed="true">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
              <circle cx="12" cy="12" r="4" />
              <path d="M12 2.5v2.5M12 19v2.5M2.5 12H5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M5.3 18.7l1.8-1.8M16.9 7.1l1.8-1.8" />
            </svg>
            day
          </button>
          <button type="button" className="wx-tag" data-daytime="evening" aria-pressed="false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
              <path d="M4 16h16M8 16a4 4 0 0 1 8 0M2 20h20M12 7v3M6 10l1.5 1.5M18 10l-1.5 1.5" />
            </svg>
            evening
          </button>
          <button type="button" className="wx-tag" data-daytime="night" aria-pressed="false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="M19 14.5A7.5 7.5 0 0 1 9.5 5a7.5 7.5 0 1 0 9.5 9.5z" />
              <path d="M17 3l.6 1.4L19 5l-1.4.6L17 7l-.6-1.4L15 5l1.4-.6z" />
            </svg>
            night
          </button>
        </div>
        <div className="hud-row" role="group" aria-label="Weather">
        <span className="hud-label">weather</span>
        <button type="button" className="wx-tag" data-weather="sun" aria-pressed="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
            <circle cx="12" cy="12" r="4" />
            <path d="M12 2.5v2.5M12 19v2.5M2.5 12H5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M5.3 18.7l1.8-1.8M16.9 7.1l1.8-1.8" />
          </svg>
          sunny
        </button>
        <button type="button" className="wx-tag" data-weather="cloudy" aria-pressed="false">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M7 18a4 4 0 0 1 .5-8 5.5 5.5 0 0 1 10.4 1.6A3.5 3.5 0 0 1 17.5 18z" />
            <path d="M3.5 13.5a3 3 0 0 1 2-5" />
          </svg>
          cloudy
        </button>
        <button type="button" className="wx-tag" data-weather="rain" aria-pressed="false">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
            <path d="M7 15a4 4 0 0 1 .5-8 5.5 5.5 0 0 1 10.4 1.6A3.5 3.5 0 0 1 17.5 15z" />
            <path d="M9 18l-1 3M13 18l-1 3M17 18l-1 3" />
          </svg>
          light rain
        </button>
        <button type="button" className="wx-tag" data-weather="storm" aria-pressed="false">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M7 14a4 4 0 0 1 .5-8 5.5 5.5 0 0 1 10.4 1.6A3.5 3.5 0 0 1 17.5 14z" />
            <path d="M12.5 14l-2.5 4h3l-2 4" />
          </svg>
          storm
        </button>
        </div>
      </div>

      {/* ---------- field notes, bottom right ---------- */}
      <div className="hud hud-br">
        {selectedCreature ? (
          <CreatureCard creature={selectedCreature} art={started.current?.spriteFor(selectedCreature.speciesName) ?? null} onClose={() => started.current?.selectCreature(null)} />
        ) : (
        <div className={`notes-card${notesOpen ? ' is-open' : ''}`}>
          <button type="button" className="notes-toggle" aria-expanded={notesOpen} aria-controls="field-notes" onClick={() => setNotesOpen((o) => !o)}>
            <span>Field notes</span>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
              <path d={notesOpen ? 'M6 15l6-6 6 6' : 'M6 9l6 6 6-6'} />
            </svg>
          </button>
          <div id="field-notes" hidden={!notesOpen}>
            {stats ? (
              <ul className="rec">
                {([
                  ['land', stats.land, 'var(--moss)'], ['forest', stats.forest, '#3d6a3a'], ['mountain', stats.mountain, 'var(--ink-soft)'],
                  ['beach', stats.beach, '#b8892f'], ['fresh water', stats.freshWater, '#2f6f86']
                ] as [string, number, string][]).map(([label, v, c]) => (
                  <li key={label}>
                    <b>{label}</b>
                    <span className="bar" aria-hidden="true">
                      <i style={{ '--v': `${Math.min(100, v * 100)}%`, '--c': c } as CSSProperties} />
                    </span>
                    <span>{pct(v)}</span>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="hand">Reading the survey…</p>
            )}
            <p className="rec-foot">Shares of the whole chart, sea included.</p>
            {farmers > 0 && <p className="rec-foot">{farmers === 1 ? 'One farmer lives here.' : `${farmers} farmers live here.`}</p>}
            {Object.keys(store).length > 0 && <p className="rec-foot">In the silos: {Object.entries(store).map(([c, n]) => `${n} ${cropName(c)}`).join(', ')}.</p>}
            {lifeforms !== null && (
              <p className="rec-foot">{lifeforms === 0 ? 'No creatures live here yet.' : lifeforms === 1 ? 'One creature lives here.' : `${lifeforms} creatures live here.`}</p>
            )}
          </div>
        </div>
        )}
      </div>

      {bestiaryOpen && (
        <Bestiary
          creatures={creatures}
          keyOf={(n) => started.current?.spriteFor(n) ?? null}
          onFind={(id) => { setBestiaryOpen(false); started.current?.showCreature(id) }}
          onClose={() => setBestiaryOpen(false)}
        />
      )}

      {hint && load.state === 'ready' && (
        <div className="hud hud-hint">
          <p className="hint-note">
            <span className="pin" aria-hidden="true" />
            drag to look around &middot; scroll or pinch to zoom &middot; double-click to look closer
            <button type="button" className="hint-close" onClick={closeHint} aria-label="Dismiss the hint">
              &times;
            </button>
          </p>
        </div>
      )}
    </div>
  )
}

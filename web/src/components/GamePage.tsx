import { useEffect, useRef, useState } from 'react'

import { chainPart, fetchConstructs, fetchEnclosures, fetchInsideOk, saveActions } from '@/chain/constructs'
import { fetchBuildCfg, fetchInventory, fetchItemNames } from '@/chain/inventory'
import { claimAction, fetchCropCfg, fetchPlayerStore, fetchStorage, fetchStored, fetchJobs, fetchPlants, harvestActions, hasFarming, plantActions, sowable, unplantActions, type CropCfg, type Plant } from '@/chain/farming'
import { FarmPanel, jobState } from '@/components/FarmPanel'
import { StorageTag } from '@/components/StorageTag'
import { GiveItem } from '@/components/GiveItem'
import type { BuildCfg } from '@/chain/inventory'
import type { Job } from '@/engine/farmers'
import { clockAt, fetchHomeClock, namesAt, type Conditions, type HomeClock } from '@/chain/home'
import { fetchLifeforms, type Creature } from '@/chain/life'
import { Bestiary, noteSeen } from '@/components/Bestiary'
import { CreatureCard } from '@/components/CreatureCard'
import { FenPurse } from '@/components/FenPurse'
import { IslandClock } from '@/components/IslandClock'
import { fetchMapTiles, fetchPlayerMaps, placeWords } from '@/chain/maps'
import { startEngine } from '@/engine'
import { insideOk, loadBuilds as readBuilds, saveForm, setInsideOk, setPathRule, type Building } from '@/engine/build'
import { CROPS } from '@/engine/crops'
import type { Builds, BuildTool, Inventory, IslandView, PenLoss } from '@/engine/types'
import { friendlyError, signer, transact } from '@/wallet/session'

type Save = { state: 'idle' } | { state: 'signing' } | { state: 'error'; message: string }

type Load = { state: 'reading' } | { state: 'drawing' } | { state: 'ready' } | { state: 'error'; message: string }

const HINT_KEY = 'ua-island-hint-seen'
// how the island's tools are laid out: in the corners, or in a margin down the left
type Layout = 'corners' | 'margin'
const LAYOUT_KEY = 'ua-ui-layout'
const firstLayout = (): Layout => {
  const q = new URLSearchParams(location.search).get('ui')
  if (q === 'corners' || q === 'margin') { try { localStorage.setItem(LAYOUT_KEY, q) } catch { /* fine */ } return q }
  try { return localStorage.getItem(LAYOUT_KEY) === 'margin' ? 'margin' : 'corners' } catch { return 'corners' }
}
/** The frame counter, only when asked for (?fps). */
const showFps = new URLSearchParams(location.search).has('fps')
const seenHint = () => {
  try {
    return localStorage.getItem(HINT_KEY) === '1'
  } catch {
    return false
  }
}


// The player's builds on each island: the island shows only what land.acre keeps (tables constructs and plants). This
// browser keeps only the flowers and bushes cleared, which are looks. On an island the signed-in wallet does not own,
// builds last only this visit.
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
/** The chain's builds with what grows on its soil (land.acre plants, crops named), and the flowers and bushes this
 *  browser cleared (only looks, not constructs). Without farming on the chain yet, this browser's own crops stay. */
const withCrops = (chain: Builds, local: Builds, plants: Record<number, { c: string; t: number }> | null): Builds => {
  const out: Builds = JSON.parse(JSON.stringify(chain))
  for (const k in local) { const { c, t, x } = local[k]; if (!plants && c && out[k]?.g === 'soil') out[k] = { ...out[k], c, ...(t ? { t } : {}) }; if (x) out[k] = { ...out[k], x } }
  for (const k in plants ?? {}) if (out[Number(k)]?.g === 'soil') out[Number(k)] = { ...out[Number(k)], ...plants![Number(k)] }
  return out
}
/** What grows, by map index, crops named by cropcfg; a tile its farmer has cut already is bare soil (the chain lets it be
 *  sown again before the claim). */
const plantsByTile = (list: Plant[], crops: CropCfg[], jobs: Job[]) => {
  const out: Record<number, { c: string; t: number }> = {}, now = Date.now()
  for (const p of list) {
    if (p.harvestId !== '0') { const j = jobs.find((q) => q.id === p.harvestId); if (!j || j.harvested <= now) continue }
    const c = crops.find((q) => q.id === p.crop); if (c) out[p.tile] = { c: c.name, t: p.planted }
  }
  return out
}
const WEATHER_WORDS: Record<string, string> = { sun: 'sunny', cloudy: 'cloudy', rain: 'light rain', storm: 'storm' }
const SNOW_WORDS: Record<string, string> = { rain: 'light snow', storm: 'snowstorm' }
const weatherWord = (c: Conditions) => (c.season === 'winter' && SNOW_WORDS[c.weather]) || WEATHER_WORDS[c.weather] || c.weather
const cropWord = (c: string) => c.replace(/-/g, ' ')

/** The inventory name of what a tool builds (null: a tool that takes nothing from the inventory). */
const itemOf = (tool: BuildTool, names: Partial<Record<Building, string>>): string | null => {
  if (tool === 'soil' || tool === 'path' || tool === 'fence' || tool === 'tree') return tool
  if (['farmhouse', 'lab', 'nest', 'silo', 'bakery', 'kitchen', 'torch', 'market'].includes(tool)) return names[tool as Building] ?? tool
  return null
}
/** For a tool with nothing left: say so. */
const outWord = (tool: BuildTool, left: Inventory | null, names: Partial<Record<Building, string>>) => {
  const item = itemOf(tool, names); if (!left || !item) return ''
  const n = left[item] ?? 0
  return n <= 0 ? ' None left in your inventory: erasing one gives it back.' : ` ${n} left in your inventory.`
}

/** For a building: whether it may stand inside an enclosure. */
const insideWord = (tool: BuildTool) => {
  if (!['farmhouse', 'lab', 'nest', 'silo', 'bakery', 'kitchen', 'torch', 'market'].includes(tool)) return ''
  return insideOk.has(tool as Building) ? ' It may stand inside an enclosure.' : ' Not inside an enclosure: one closed round it takes it down.'
}

/** What the planned fences take away, said plainly before it is confirmed. */
function fenceWarning(loss: PenLoss) {
  if (!loss.soil && !loss.buildings.length) return null
  const names = [...new Set(loss.buildings)].map((k) => { const n = loss.buildings.filter((b) => b === k).length, w = TOOLS.find((t) => t.id === k)?.label ?? k; return n === 1 ? `the ${w}` : `${n} ${w}s` })
  const what = [...(loss.soil ? [`${loss.soil} soil tile${loss.soil === 1 ? '' : 's'}`] : []), ...names]
  const list = what.length === 1 ? what[0] : `${what.slice(0, -1).join(', ')} and ${what[what.length - 1]}`
  return <p className="build-warn hand" role="alert">Confirming takes away {list}: an enclosure is the creatures’ ground, so they cannot stay inside the new fence. They go back to your inventory.</p>
}

/** The build tools in groups, in a fixed order (so nothing moves as what is left changes). */
const TOOL_GROUPS: { title: string; ids: BuildTool[] }[] = [
  { title: 'ground', ids: ['path', 'soil', 'fence', 'tree'] },
  { title: 'buildings', ids: ['market', 'farmhouse', 'silo', 'bakery', 'kitchen', 'lab', 'nest', 'torch'] },
  { title: 'farming', ids: ['crop', 'harvest'] },
  { title: 'changes', ids: ['upgrade', 'erase'] },
]

const TOOLS: { id: BuildTool; label: string; hint: string; icon: string }[] = [
  { id: 'fence', label: 'enclosure', hint: 'Drag to draw a fence, any shape; close the loop and it is an enclosure. To enlarge one, draw the new side out from the old fence and erase the old stretch. Shift + drag: a rectangle. An enclosure is the creatures’ ground: closing one round soil, or round a building not made for it, takes them away.', icon: 'M3 20V8l2-3 2 3v12M17 20V8l2-3 2 3v12M3 11h18M3 16h18' },
  { id: 'path', label: 'path', hint: 'Drag to lay a path where you go, over grass, soil or sand; trees in the way make room. Shift + drag: a whole area.', icon: 'M7 21c0-4 3-5 3-9S7 7 7 3M17 21c0-4-3-5-3-9s3-5 3-9M12 6v1M12 11v1M12 16v1' },
  { id: 'soil', label: 'soil', hint: 'Drag over open grass to turn it into soil, ready for sowing. Not inside an enclosure, and not where something is built.', icon: 'M3 17c3-2 6-2 9 0s6 2 9 0M3 12c3-2 6-2 9 0s6 2 9 0M8 7l1-3M15 7l1-3' },
  { id: 'crop', label: 'crops', hint: 'Pick a crop, then drag over soil to sow it. It grows a stage every ten seconds and is ready in under a minute.', icon: 'M12 21V10M12 14c-4 0-6-3-6-6 3 0 6 2 6 6zM12 11c0-4 2-7 6-7 0 4-2 7-6 7z' },
  { id: 'farmhouse', label: 'farmhouse', hint: 'Click to put up a farmhouse (3 × 4 tiles) on open grass; R turns it. Its door must reach a path: one up to two tiles away is joined to it. One farmer moves in; upgrade it for more.', icon: 'M3 11l9-7 9 7M5 10v10h14V10M10 20v-6h4v6' },
  { id: 'upgrade', label: 'upgrade', hint: 'Click a farmhouse to raise it a stage: each stage houses one more farmer, up to five.', icon: 'M12 20V6M6 12l6-6 6 6M5 21h14' },
  { id: 'lab', label: 'observatory', hint: 'Click to put up an observatory (4 × 4 tiles) on open grass; R turns it. Its door must reach a path: one up to two tiles away is joined to it.', icon: 'M4 20h16M5 20v-6h14v6M5 14a7 7 0 0 1 14 0M12 7l5-4M10 20v-3h4v3' },
  { id: 'silo', label: 'silo', hint: 'Click to put up a silo (2 × 2 tiles) on open grass, to store the harvest.', icon: 'M7 21V9a5 5 0 0 1 10 0v12M7 21h10M7 13h10M7 17h10M12 4V2' },
  { id: 'bakery', label: 'bakery', hint: 'Click to put up a bakery (2 × 2 tiles) on open grass; R turns it. Its door must reach a path: one up to two tiles away is joined to it.', icon: 'M4 20h16M5 20v-7l7-5 7 5v7M15 9V5h2v5.5M9 20v-4h3v4' },
  { id: 'market', label: 'market', hint: 'Click to lay out a market (4 × 5 tiles) on open grass: a market hall with a cobbled square, stalls and a fountain; R turns it. It is the main building: it needs no path, the other buildings’ paths lead to it (one up to two tiles away is joined to it).', icon: 'M4 21V11M20 21V11M3 11l3-6h12l3 6zM3 11h18M8 21v-5h8v5M12 5V3' },
  { id: 'kitchen', label: 'kitchen', hint: 'Click to lay out an outdoor kitchen (3 × 2 tiles) on open grass: a bread oven, a hearth and a table; R turns it.', icon: 'M4 20h16M6 20v-6a6 6 0 0 1 12 0v6M10 20v-3h4v3M17 8c0-2 1-3 0-5' },
  { id: 'torch', label: 'torch', hint: 'Click to set up a torch (1 tile). It burns through the evening and the night.', icon: 'M12 21v-9M8 8h8l-1.5 4h-5zM12 8c-2-2-1-4 0-6 1 2 2 4 0 6' },
  { id: 'nest', label: 'nest', hint: 'Click to lay a straw hatching nest (2 × 2 tiles) on open grass.', icon: 'M3 13c0 4 4 7 9 7s9-3 9-7M3 13c3 2 15 2 18 0M9 11a3 4 0 1 0 6 0a3 4 0 1 0-6 0' },
  { id: 'tree', label: 'trees', hint: 'Drag over open grass to plant trees, one a tile: mostly broadleaf, now and then a conifer.', icon: 'M12 21v-5M12 3c-4 0-7 3-7 6.5S8 16 12 16s7-3 7-6.5S16 3 12 3z' },
  { id: 'harvest', label: 'harvest', hint: 'Drag over crops to mark the ripe ones for harvest; the farmers bring them to a silo. Start on a mark to take marks back. A ripe field also shows a sickle: click it to harvest the whole field.', icon: 'M5 19l5-5M10 14c1-6 6-9 10-8-3 1-6 4-6 8' },
  { id: 'erase', label: 'erase', hint: 'Drag to clear tiles. Start on a fence and only fences go; start on a tree and only trees and plants go (the same for buildings, crops, paths and soil).', icon: 'M15 4l5 5-9 9H6l-2-2 11-12zM9 9l6 6M4 20h16' },
]

/**
 * The island itself, full screen. The journal only shows up in small pieces around the edges: the island's
 * name tag and the build, weather and bestiary buttons, the player's Fenmarks and the island's time, zoom, and the card of
 * a creature picked.
 */
export function GamePage({ mapId, account, onLeave }: {
  mapId: string
  account: string
  onLeave: () => void
}) {
  const [load, setLoad] = useState<Load>({ state: 'reading' })
  const [name, setName] = useState(`Island ${mapId}`)
  const [creatures, setCreatures] = useState<Creature[]>([])
  const [selected, setSelected] = useState<string | null>(null)
  const [hint, setHint] = useState(!seenHint())
  const [buildOpen, setBuildOpen] = useState(false)
  const [bestiaryOpen, setBestiaryOpen] = useState(false)
  const [tool, setTool] = useState<BuildTool | null>(null)
  const [undoable, setUndoable] = useState(false)
  const [pending, setPending] = useState(0)
  const [planKind, setPlanKind] = useState<'build' | 'erase' | 'both'>('build')
  const [fenced, setFenced] = useState<PenLoss>({ soil: 0, buildings: [] })
  // what the island's owner holds once the plan is built (null: no inventory to keep to), and each building's name in it
  const [left, setLeft] = useState<Inventory | null>(null)
  const [itemNames, setItemNames] = useState<Partial<Record<Building, string>>>({})
  const [, setInsideRead] = useState(0)
  const confirmWords = planKind === 'erase' ? 'confirm erasing' : planKind === 'both' ? 'confirm changes' : 'confirm building'
  const [crop, setCrop] = useState<string>('wheat')
  const started = useRef<IslandView | null>(null)
  const [layout, setLayoutState] = useState<Layout>(firstLayout)
  const setLayout = (l: Layout) => { setLayoutState(l); try { localStorage.setItem(LAYOUT_KEY, l) } catch { /* only for this visit */ } }
  // the island's season, daytime and weather: what is shown, and what the island clock (home.acre) says it is now
  const [shown, setShown] = useState<Conditions | null>(null)
  const [island, setIsland] = useState<Conditions | null>(null)
  const [skyOpen, setSkyOpen] = useState(false)
  const homeClock = useRef<HomeClock | null>(null)
  const [clockReady, setClockReady] = useState<HomeClock | null>(null)
  const ownPick = !!shown && !!island && (shown.season !== island.season || shown.daytime !== island.daytime || shown.weather !== island.weather)
  const followClock = () => {
    const view = started.current, c = homeClock.current; if (!view || !c) return
    const { now } = clockAt(c, Date.now()); view.setSeason(now.season); view.setDaytime(now.daytime); view.setWeather(now.weather)
  }
  const [save, setSave] = useState<Save>({ state: 'idle' })
  const [owner, setOwner] = useState<string | null>(null)
  /** where the island lies on the world map */
  const [place, setPlace] = useState<{ x: number; y: number } | null>(null)
  /** what land.acre holds for this island, as the page keeps it (null until read) */
  const onChain = useRef<Builds | null>(null)
  // farming on land.acre: the crops (null: not on the chain yet), what grows there by tile (crop name), the farmers' jobs,
  // the owner's crop store
  const [crops, setCrops] = useState<CropCfg[] | null>(null)
  const onChainPlants = useRef<Record<number, string>>({})
  const [jobs, setJobsState] = useState<Job[]>([])
  const [store, setStore] = useState<Record<string, number>>({})
  const [farmOpen, setFarmOpen] = useState(false)
  const [farmNote, setFarmNote] = useState<string | null>(null)
  const [storage, setStorage] = useState<{ capacity: number; used: number } | null>(null)
  const [stored, setStored] = useState<Record<string, number>>({})
  // what stands on the island (to show which buildings give it room) and every building's settings
  const [standing, setStanding] = useState<Builds>({})
  const [buildCfg, setBuildCfg] = useState<BuildCfg[]>([])
  const farm = useRef<{ crops: CropCfg[] | null; owner: string | null }>({ crops: null, owner: null })
  farm.current = { crops, owner }
  const cropName = (id: string) => crops?.find((c) => c.id === id)?.name ?? id
  const [, setTick] = useState(0)
  const who = signer()
  const toChain = !!who && who.actor === owner && onChain.current !== null
  const selectedCreature = selected === null ? null : creatures.find((c) => String(c.id) === selected) ?? null

  useEffect(() => {
    let live = true, clockTimer = 0
    fetchPlayerMaps(account).then((maps) => {
      const m = maps.find((x) => x.id === mapId)
      if (live && m?.name) setName(m.name)
      if (live && m) { setOwner(m.owner); setPlace(m.at) }
    }, () => undefined)
    // farming, if the chain has it: the crops, what grows and the farmers' jobs (the island opens without it)
    const farming = hasFarming().then((ok) => (ok ? Promise.all([fetchCropCfg(), fetchPlants(mapId), fetchJobs(mapId)]) : null)).catch(() => null)
    Promise.all([fetchMapTiles(mapId), fetchConstructs(mapId), farming]).then(
      ([tiles, chain, farmed]) => {
        if (!live || started.current) return
        setLoad({ state: 'drawing' })
        // let the "sketching" note paint before the first build starts
        setTimeout(() => {
          if (!live || started.current) return
          try {
            // what the chain holds, with what grows on its soil
            onChain.current = chain
            const grows = farmed ? plantsByTile(farmed[1], farmed[0], farmed[2]) : null
            if (farmed) { setCrops(farmed[0]); onChainPlants.current = Object.fromEntries(Object.entries(grows!).map(([k, v]) => [k, v.c])) }
            const saved = withCrops(chain, loadBuilds(mapId), grows)
            started.current = startEngine({ tiles, mapId, builds: saved })
            if (farmed) { started.current.setGrowth(Object.fromEntries(farmed[0].map((c) => [c.name, c.growth * 1000])))
              const named = farmed[2].map((j) => ({ ...j, crop: farmed[0].find((c) => c.id === j.crop)?.name ?? j.crop }))
              started.current.setJobs(named); setJobsState(farmed[2]) }
            if (import.meta.env.DEV) (window as unknown as { __island: IslandView }).__island = started.current
            const view = started.current
            view.ready.then(() => {
              if (!live) return
              setLoad({ state: 'ready' })
              // the creatures living here, from life.acre; the island stays usable if this read fails
              view.onSelect((id) => setSelected(id === null ? null : String(id)))
              view.onConditions((c) => live && setShown(c))
              // the island clock: whenever a season, daytime or weather comes round, it is shown (over a pick of one's own)
              fetchHomeClock().then((c) => {
                if (!live) return
                homeClock.current = c; setClockReady(c)
                let last: ReturnType<typeof clockAt>['turn'] | null = null
                const tick = () => {
                  if (!live) return
                  clearTimeout(clockTimer)
                  const { now, turn, next } = clockAt(c, Date.now())
                  if (!last || turn.season !== last.season) view.setSeason(now.season)
                  if (!last || turn.daytime !== last.daytime) view.setDaytime(now.daytime)
                  if (!last || turn.weather !== last.weather || turn.season !== last.season) view.setWeather(now.weather)
                  last = turn; setIsland(now)
                  clockTimer = window.setTimeout(tick, Math.max(500, next - Date.now() + 250))
                }
                tick()
                document.addEventListener('visibilitychange', () => { if (!document.hidden) tick() })   // timers sleep in a hidden tab
              }, (err) => console.warn('Could not read the island clock', err))
              view.onHarvest((tiles) => sendHarvest(tiles))
              view.onBuild((builds, canUndo, planned, kind, loss, rest) => { saveBuilds(mapId, builds); setStanding(builds); setUndoable(canUndo); setPending(planned); setPlanKind(kind); setFenced(loss); setLeft(rest) })
              fetchInsideOk().then((list) => { if (live && list) { setInsideOk(list); setInsideRead((n) => n + 1) } }, () => undefined)
              // which buildings need a path touching them (buildcfg), as land.acre checks it
              fetchBuildCfg().then((cfg) => { if (live) setBuildCfg(cfg); if (live && cfg.length) setPathRule(cfg.filter((c) => c.requiresPath && c.building).map((c) => c.building!)) }, () => undefined)
              fetchEnclosures(mapId).then((list) => live && view.setEnclosures(list), (err) => console.warn('Could not read the enclosures', err))
              fetchLifeforms(mapId)
                .then((list) => { if (live) setCreatures(list); noteSeen(list.map((c) => view.spriteFor(c.speciesName)).filter((k): k is string => !!k)); return view.setLifeforms(list) })
                .catch((err) => console.warn('Could not load the lifeforms', err))
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
      clearTimeout(clockTimer)
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
  /** Reads what the owner holds into the island (the plan is held to it). */
  const readInventory = () => {
    const view = started.current; if (!view || !owner) return
    Promise.all([fetchInventory(owner), fetchItemNames()]).then(([held, names]) => { setItemNames(names); view.setInventory(held, names) }, (err) => console.warn('Could not read the inventory', err))
  }
  useEffect(() => { if (load.state === 'ready') readInventory() }, [load.state, owner])   // eslint-disable-line react-hooks/exhaustive-deps

  /** Reads what grows and the farmers' jobs again (after a change, and now and then). */
  const readFarm = () => {
    const view = started.current, list = farm.current.crops; if (!view || !list) return
    Promise.all([fetchPlants(mapId), fetchJobs(mapId)]).then(([plants, js]) => {
      const grows = plantsByTile(plants, list, js)
      onChainPlants.current = Object.fromEntries(Object.entries(grows).map(([k, v]) => [k, v.c]))
      view.setPlants(grows)
      view.setJobs(js.map((j) => ({ ...j, crop: list.find((c) => c.id === j.crop)?.name ?? j.crop }))); setJobsState(js)
    }, (err) => console.warn('Could not read the farm', err))
  }
  const readStore = () => { const o = farm.current.owner; if (o && farm.current.crops) fetchPlayerStore(o).then(setStore, () => undefined)
    fetchStorage(mapId).then(setStorage, () => undefined); fetchStored(mapId).then(setStored, () => undefined) }
  useEffect(() => { if (load.state === 'ready') readStore() }, [load.state, owner])   // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (load.state !== 'ready' || !crops) return
    readStore()
    const t = window.setInterval(readFarm, 60_000)   // someone else's change now and then; the farmers' times need no reading
    return () => window.clearInterval(t)
  }, [load.state, crops, owner])   // eslint-disable-line react-hooks/exhaustive-deps
  // when a farmer reaches the silo, the claim shows
  useEffect(() => {
    const now = Date.now(), next = jobs.filter((j) => !j.claimed && j.offloaded > now).map((j) => j.offloaded).sort((a, b) => a - b)[0]
    if (!next) return
    const t = window.setTimeout(() => setTick((n) => n + 1), next - now + 300); return () => window.clearTimeout(t)
  })
  const claimable = jobs.filter((j) => jobState(j, Date.now()).claimable).length
  const roomBuildings = (() => {
    const out = new Map<string, { name: string; count: number; each: number; dropOff: boolean }>()
    for (const k in standing) { const b = standing[k]; if (!b.s) continue
      const c = buildCfg.find((q) => q.building === b.s); if (!c || (!c.storage && !c.main)) continue
      const name = c.display || c.name, e = out.get(name) ?? { name, count: 0, each: c.storage, dropOff: true }; e.count++; out.set(name, e) }
    return [...out.values()].sort((a, b) => b.each - a.each)
  })()
  const storageTag = <StorageTag storage={storage} stored={stored} jobs={jobs} buildings={roomBuildings} store={store} cropName={cropName} />

  /** A farmer is asked for these fully grown tiles: one harvest action for each crop. */
  const sendHarvest = async (tiles: number[]) => {
    const view = started.current, w = signer(), list = farm.current.crops; if (!view) return
    setFarmOpen(true)
    if (!list) { setFarmNote('Harvesting comes with land.acre’s farming update.'); return }
    if (!w || w.actor !== farm.current.owner) { setFarmNote('Only the island’s owner, signed in, sends farmers.'); return }
    const plan = view.plan(), byCrop: Record<string, number[]> = {}
    for (const i of tiles) { const c = list.find((q) => q.name === plan[i]?.c); if (c) (byCrop[c.id] ??= []).push(i) }
    if (!Object.keys(byCrop).length) return
    const brings = Object.entries(byCrop).reduce((n, [id, ts]) => n + (list.find((q) => q.id === id)?.yield ?? 0) * ts.length, 0)
    if (storage && storage.used + brings > storage.capacity) { setFarmNote(`The island’s storage is full: ${Math.max(0, storage.capacity - storage.used)} left, this harvest brings ${brings}. Put up more storage first.`); return }
    setFarmNote('Waiting for your wallet…')
    try {
      await transact(harvestActions(mapId, w, byCrop))
      setFarmNote('A farmer is on the way.'); setTimeout(() => { readFarm(); readStore() }, 2500)
    } catch (err) { setFarmNote(friendlyError(err)) }
  }
  /** What the farmers brought to the silo into the store: one claim each, in one transaction. */
  const claim = async (job: Job | Job[]) => {
    const w = signer(), list = Array.isArray(job) ? job : [job]; if (!w || w.actor !== owner || !list.length) return
    setFarmNote('Waiting for your wallet…')
    try {
      await transact(list.map((j) => claimAction(mapId, w, j.id)))
      const byCrop: Record<string, number> = {}; for (const j of list) byCrop[j.crop] = (byCrop[j.crop] ?? 0) + j.amount
      setFarmNote(Object.entries(byCrop).map(([c, n]) => `${n} ${cropName(c).replace(/-/g, ' ')}`).join(', ') + ' into your store.')
      const ids = new Set(list.map((j) => j.id))
      setJobsState((js) => js.map((q) => (ids.has(q.id) ? { ...q, claimed: true } : q)))
      setTimeout(() => { readFarm(); readStore() }, 2500)
    } catch (err) { setFarmNote(friendlyError(err)) }
  }

  const confirm = async () => {
    const view = started.current, w = signer()
    if (!view || save.state === 'signing') return
    if (!w || w.actor !== owner || !onChain.current) { view.confirmBuild(); return }
    const plan = view.plan(), next = chainPart(plan)
    // what is sown and taken off soil that stays: plant and unplant, with the season, daytime and weather checked first
    const sow: Record<string, number[]> = {}, unsow: number[] = []
    if (crops) {
      const clock = clockReady ? namesAt(clockReady, Date.now()) : null
      for (const k in plan) { const i = Number(k), c = plan[i].c; if (!c || onChainPlants.current[i] === c) continue
        const cfg = crops.find((q) => q.name === c)
        if (!cfg) { setSave({ state: 'error', message: `${cropWord(c)} is not a crop the chain knows.` }); return }
        if (!sowable(cfg, clock)) { setSave({ state: 'error', message: `${cropWord(c)} cannot be sown now (${clock?.season}, ${clock?.daytime}, ${clock?.weather}).` }); return }
        if (onChainPlants.current[i]) unsow.push(i)
        ;(sow[cfg.id] ??= []).push(i) }
      for (const k in onChainPlants.current) { const i = Number(k); if (!plan[i]?.c && plan[i]?.g === 'soil') unsow.push(i) }
    }
    const actions = [...unplantActions(mapId, w, unsow), ...saveActions(mapId, w, onChain.current, next), ...plantActions(mapId, w, sow)]
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
    view.confirmBuild(); setSave({ state: 'idle' })
    setTimeout(() => { readInventory(); readStore(); readFarm() }, 2500)   // what the contract counted (inventory, storage, the farmers' jobs planned again), once a node has the block
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

  // the two layouts share these: the three tools, and the cards they open (the weather card always in the page)
  const toolClass = layout === 'corners' ? 'wx-tag tool-tag' : 'margin-tool'
  // the crops to sow: the chain's (those with a picture), each sowable now or not (home.acre's clock); without farming
  // on the chain, every crop with a picture (sown on this device only)
  const clockNames = clockReady ? namesAt(clockReady, Date.now()) : null
  const seedList = crops
    ? crops.filter((q) => (CROPS as readonly string[]).includes(q.name)).map((q) => ({ c: q.name, ok: sowable(q, clockNames), why: `sown only in ${[q.seasons.join(' or '), q.daytimes.join(' or '), q.weathers.join(' or ')].filter(Boolean).join(', ')}` }))
    : CROPS.map((c) => ({ c: c as string, ok: true, why: '' }))
  const seedInfo = (c: string) => { const q = crops?.find((x) => x.name === c); return q ? ` · grows in ${q.growth >= 3600 ? `${+(q.growth / 3600).toFixed(1)} h` : q.growth >= 60 ? `${Math.round(q.growth / 60)} min` : `${q.growth} s`} · ${q.yield} a tile` : '' }
  const toolButtons = (
    <>
      <button type="button" className={`${toolClass} build-toggle`} aria-expanded={buildOpen} aria-controls="build-card" onClick={() => { setSkyOpen(false); if (buildOpen) closeBuild(); else setBuildOpen(true) }}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M14 6l4 4M3 21l9-9M12.5 4.5l3-1.5 5.5 5.5-1.5 3-3-3-1 1-3-3 1-1z" />
        </svg>
        <span>build</span>
      </button>
      <button type="button" className={`${toolClass} sky-toggle`} aria-expanded={skyOpen} aria-controls="sky-panel" onClick={() => { closeBuild(); setSkyOpen(!skyOpen) }}
        title={ownPick ? 'Your own pick: the island’s clock takes over again when the next change comes round' : 'Season, daytime and weather, as the island’s clock has them now'}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
          <circle cx="9" cy="9" r="3.2" />
          <path d="M9 2.5v1.5M2.5 9H4M4.4 4.4l1 1M13.6 4.4l-1 1M8 20h9a3.5 3.5 0 0 0 .4-7 5 5 0 0 0-9.6 1.4A2.8 2.8 0 0 0 8 20z" />
        </svg>
        <span>weather</span>
        {ownPick && <span className="sky-own" aria-label="your own pick">•</span>}
      </button>
      <button type="button" className={`${toolClass} farm-toggle`} aria-expanded={farmOpen} aria-controls="farm-card" onClick={() => { closeBuild(); setSkyOpen(false); setFarmOpen(!farmOpen) }}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M5 19l5-5M10 14c1-6 6-9 10-8-3 1-6 4-6 8" />
        </svg>
        <span>farmers</span>
        {claimable > 0 && <span className="sky-own" aria-label={`${claimable} to claim`}>{claimable}</span>}
      </button>
      <button type="button" className={`${toolClass} bestiary-toggle`} aria-haspopup="dialog" onClick={() => { closeBuild(); setSkyOpen(false); setBestiaryOpen(true) }}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M4 5c3-1.5 5.5-1.5 8 0v14c-2.5-1.5-5-1.5-8 0zM20 5c-3-1.5-5.5-1.5-8 0v14c2.5-1.5 5-1.5 8 0z" />
        </svg>
        <span>bestiary</span>
      </button>
    </>
  )
  const cardsAndSky = (
    <>
      {load.state === 'ready' && farmOpen && !buildOpen && (
        <div className="build"><FarmPanel jobs={jobs} cropName={cropName} store={store} storage={storage} canAct={!!who && who.actor === owner && !!crops} note={farmNote} onClaim={claim} onClaimAll={claim} onClose={() => { setFarmOpen(false); setFarmNote(null) }} /></div>
      )}
      {load.state === 'ready' && (
        <div className="build">
          {buildOpen && (
            <div className="build-card" id="build-card">
              {TOOL_GROUPS.map((g) => (
              <div key={g.title} className="build-tools" role="group" aria-label={g.title}>
                <span className="build-group">{g.title}</span>
                {g.ids.map((id) => TOOLS.find((t) => t.id === id)!).map((t) => { const item = itemOf(t.id, itemNames), out = !!left && !!item && (left[item] ?? 0) <= 0
                  return (
                  <button key={t.id} type="button" className={`build-tool${out ? ' is-out' : ''}`} aria-pressed={tool === t.id} title={out ? 'none left in your inventory' : undefined} onClick={() => setTool(tool === t.id ? null : t.id)}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                      <path d={t.icon} />
                    </svg>
                    {t.label}
                    {left && item && <small className={`tool-left${out ? ' is-out' : ''}`} aria-label={`${left[item] ?? 0} left`}>{left[item] ?? 0}</small>}
                  </button>
                ) })}
              </div>
              ))}
              <p className="build-hint hand">{tool ? TOOLS.find((t) => t.id === tool)!.hint + insideWord(tool) + outWord(tool, left, itemNames) : 'Pick what to build, then drag across the island.'}</p>
              {tool === 'crop' && (
                <div className="crop-pick" role="radiogroup" aria-label="Which crop to sow">
                  {seedList.map(({ c, ok, why }) => (
                    <button key={c} type="button" role="radio" aria-checked={crop === c} className="crop-seed" title={ok ? cropWord(c) : `${cropWord(c)}: ${why}`} disabled={!ok} onClick={() => setCrop(c)}>
                      <img src={`art/crops/${c}/7-harvest-front.svg?v=1`} alt={cropWord(c)} loading="lazy" />
                    </button>
                  ))}
                  {seedList.length === 0 && <p className="build-hint hand">No crops yet: they are added in the admin panel (Farming › Crops).</p>}
                </div>
              )}
              {tool === 'crop' && <p className="crop-name">{cropWord(crop)}{seedInfo(crop)}</p>}
              {(tool === 'farmhouse' || tool === 'lab' || tool === 'nest' || tool === 'silo' || tool === 'bakery' || tool === 'kitchen' || tool === 'market') && <button type="button" className="build-link" onClick={() => started.current?.rotateBuild()}>rotate (R)</button>}
              <div className="build-actions">
                <button type="button" className="build-link" disabled={!undoable} onClick={() => started.current?.undoBuild()}>undo</button>
                <button type="button" className="build-link" onClick={closeBuild}>done</button>
              </div>
              {fenceWarning(fenced)}
              <p className="build-plan hand">{pending ? `${pending} tile${pending === 1 ? '' : 's'} planned: blue goes up, red comes down. Click a mark again to take it back.` : 'Nothing planned yet. What you mark shows as a hologram until you confirm it.'}</p>
              <div className="build-actions">
                <button type="button" className="build-confirm" disabled={!pending || save.state === 'signing'} onClick={confirm}>{confirmLabel}</button>
                <button type="button" className="build-link" disabled={!pending || save.state === 'signing'} onClick={() => { setSave({ state: 'idle' }); started.current?.discardBuild() }}>discard</button>
              </div>
              {saveNote}
              <GiveItem owner={owner} buildCfg={buildCfg} onGiven={readInventory} />
              <p className="rec-foot">{toChain ? 'Confirming saves to the chain (your wallet signs); crops stay on this device.' : 'Not saved: only the island’s owner, signed in, saves to the chain. Gone when you leave.'} Right-drag moves the map; a right click puts the tools away.</p>
            </div>
          )}
          {!buildOpen && pending > 0 && (
            <div className="build-pending">
              <span className="hand">{pending} planned</span>
              {fenceWarning(fenced)}
              <button type="button" className="build-confirm" disabled={save.state === 'signing'} onClick={confirm}>{confirmLabel}</button>
              <button type="button" className="build-link" disabled={save.state === 'signing'} onClick={() => { setSave({ state: 'idle' }); started.current?.discardBuild() }}>discard</button>
              {saveNote}
            </div>
          )}
        </div>
      )}
      <div className="sky-panel" id="sky-panel" hidden={!skyOpen || load.state !== 'ready'}>
        <p className="sky-now hand">{shown ? `${shown.season} · ${shown.daytime} · ${weatherWord(shown)}` : 'reading the island’s clock…'}{ownPick ? ' (your own pick)' : ''}</p>
      <div className="hud-row" role="group" aria-label="Season">
        <span className="hud-label">season</span>
        <button type="button" className="wx-tag" data-season="spring" aria-pressed={shown?.season === 'spring'}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
            <circle cx="12" cy="9" r="2" />
            <path d="M12 7c0-3 3-4 3-4s1 3-1.5 4.5M14 9c3 0 4 3 4 3s-3 1-4.5-1.5M10 9c-3 0-4 3-4 3s3 1 4.5-1.5M12 11v10M12 17c-2-2-5-2-5-2s1 3 5 3" />
          </svg>
          spring
        </button>
        <button type="button" className="wx-tag" data-season="summer" aria-pressed={shown?.season === 'summer'}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
            <path d="M4 20h16M6 20c1-5 3-8 6-8s5 3 6 8M12 8V3M8 9 6 6M16 9l2-3" />
          </svg>
          summer
        </button>
        <button type="button" className="wx-tag" data-season="autumn" aria-pressed={shown?.season === 'autumn'}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M5 19C5 10 10 4 20 4c0 10-6 15-15 15zM5 19l9-9M9 15h4M11 13V9" />
          </svg>
          autumn
        </button>
        <button type="button" className="wx-tag" data-season="winter" aria-pressed={shown?.season === 'winter'}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
            <path d="M12 2v20M3.3 7l17.4 10M3.3 17 20.7 7M9 4l3 2 3-2M9 20l3-2 3 2M4 10.5l3.4-.4L6.6 7M20 13.5l-3.4.4.8 3.1M4 13.5l3.4.4-.8 3.1M20 10.5l-3.4-.4.8-3.1" />
          </svg>
          winter
        </button>
      </div>
      <div className="hud-row" role="group" aria-label="Time of day">
        <span className="hud-label">daytime</span>
        <button type="button" className="wx-tag" data-daytime="morning" aria-pressed={shown?.daytime === 'morning'}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
            <path d="M4 16h16M7 16a5 5 0 0 1 10 0M12 4v3M5.5 8.5l2 2M18.5 8.5l-2 2M2 20h20" />
          </svg>
          morning
        </button>
        <button type="button" className="wx-tag" data-daytime="day" aria-pressed={shown?.daytime === 'day'}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
            <circle cx="12" cy="12" r="4" />
            <path d="M12 2.5v2.5M12 19v2.5M2.5 12H5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M5.3 18.7l1.8-1.8M16.9 7.1l1.8-1.8" />
          </svg>
          day
        </button>
        <button type="button" className="wx-tag" data-daytime="evening" aria-pressed={shown?.daytime === 'evening'}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
            <path d="M4 16h16M8 16a4 4 0 0 1 8 0M2 20h20M12 7v3M6 10l1.5 1.5M18 10l-1.5 1.5" />
          </svg>
          evening
        </button>
        <button type="button" className="wx-tag" data-daytime="night" aria-pressed={shown?.daytime === 'night'}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M19 14.5A7.5 7.5 0 0 1 9.5 5a7.5 7.5 0 1 0 9.5 9.5z" />
            <path d="M17 3l.6 1.4L19 5l-1.4.6L17 7l-.6-1.4L15 5l1.4-.6z" />
          </svg>
          night
        </button>
      </div>
      <div className="hud-row" role="group" aria-label="Weather">
      <span className="hud-label">weather</span>
      <button type="button" className="wx-tag" data-weather="sun" aria-pressed={shown?.weather === 'sun'}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2.5v2.5M12 19v2.5M2.5 12H5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M5.3 18.7l1.8-1.8M16.9 7.1l1.8-1.8" />
        </svg>
        sunny
      </button>
      <button type="button" className="wx-tag" data-weather="cloudy" aria-pressed={shown?.weather === 'cloudy'}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M7 18a4 4 0 0 1 .5-8 5.5 5.5 0 0 1 10.4 1.6A3.5 3.5 0 0 1 17.5 18z" />
          <path d="M3.5 13.5a3 3 0 0 1 2-5" />
        </svg>
        cloudy
      </button>
      <button type="button" className="wx-tag" data-weather="rain" aria-pressed={shown?.weather === 'rain'}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
          <path d="M7 15a4 4 0 0 1 .5-8 5.5 5.5 0 0 1 10.4 1.6A3.5 3.5 0 0 1 17.5 15z" />
          <path d="M9 18l-1 3M13 18l-1 3M17 18l-1 3" />
        </svg>
        light rain
      </button>
      <button type="button" className="wx-tag" data-weather="storm" aria-pressed={shown?.weather === 'storm'}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M7 14a4 4 0 0 1 .5-8 5.5 5.5 0 0 1 10.4 1.6A3.5 3.5 0 0 1 17.5 14z" />
          <path d="M12.5 14l-2.5 4h3l-2 4" />
        </svg>
        storm
      </button>
      </div>
      {ownPick && (
        <button type="button" className="sky-follow hand" onClick={followClock}>
          back to the island’s own {island && island.season === shown?.season && island.daytime === shown?.daytime ? 'weather' : 'time'}: {island?.season} · {island?.daytime} · {island && weatherWord(island)}
        </button>
      )}
        <p className="sky-view">view: {(['corners', 'margin'] as const).map((l, i) => <span key={l}>{i ? ' · ' : ''}<button type="button" aria-pressed={layout === l} onClick={() => setLayout(l)}>{l}</button></span>)}</p>
      </div>
      {showFps && <span className="hud-fps" id="fps" aria-live="off" />}
    </>
  )

  return (
    <div className={`game ui-${layout}`} onContextMenu={(e) => e.preventDefault()}>
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

      {/* ---------- the tools and the island's name: in the corners, or in a margin down the left (the weather card can switch) ---------- */}
      {layout === 'corners' ? (
        <>
          <div className="hud hud-tl">
            <div className="isle-tag">
              <svg className="isle-tag-mark" aria-hidden="true">
                <use href="#stamp-mark" />
              </svg>
              <span>
                <small title={`its place on the world map: ${placeWords(place)}`}>map no. {mapId}{place ? ` · at ${place.x}, ${place.y}` : ''}</small>
                <b>{name}</b>
              </span>
              <button type="button" className="isle-back" onClick={onLeave} aria-label="Back to the journal">
                <svg className="isle-back-corner" viewBox="0 0 24 24" aria-hidden="true"><path d="M14 6l-6 6 6 6" /></svg>
                <span className="isle-back-label" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M14 6l-6 6 6 6" /></svg><span><small>back to the</small><b>journal</b></span></span>
              </button>
            </div>
            {load.state === 'ready' && <div className="hud-buttons">{toolButtons}</div>}
            {cardsAndSky}
          </div>
          <div className="hud hud-tr">
            <FenPurse account={account} />
            {clockReady && island && <IslandClock clock={clockReady} season={island.season} />}
            {load.state === 'ready' && storageTag}
          </div>
        </>
      ) : (
        <>
          <aside className="hud margin" aria-label={name}>
            <div className="margin-title">
              <svg className="isle-tag-mark" aria-hidden="true">
                <use href="#stamp-mark" />
              </svg>
              <b>{name}</b>
              <small title={`its place on the world map: ${placeWords(place)}`}>map no. {mapId}{place ? ` · at ${place.x}, ${place.y}` : ''}</small>
            </div>
            {load.state === 'ready' && <div className="margin-tools">{toolButtons}</div>}
            <div className="margin-foot">
              {clockReady && island && <IslandClock clock={clockReady} season={island.season} />}
              <button type="button" className="margin-back hand" onClick={onLeave}>← back to the journal</button>
            </div>
          </aside>
          <div className="hud margin-cards">{cardsAndSky}</div>
          <div className="hud hud-tr"><FenPurse account={account} />{load.state === 'ready' && storageTag}</div>
        </>
      )}

      {/* ---------- zoom, right edge: one paper tag, in and out ---------- */}
      <div className="hud hud-r zoom-tag" role="group" aria-label="Zoom">
        <button type="button" className="zoom-btn" id="zin" aria-label="Zoom in">
          <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M10 4v12M4 10h12" /></svg>
        </button>
        <span className="zoom-rule" aria-hidden="true" />
        <button type="button" className="zoom-btn" id="zout" aria-label="Zoom out">
          <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M4 10h12" /></svg>
        </button>
      </div>

      {/* ---------- the creature picked, bottom right ---------- */}
      {selectedCreature && (
        <div className="hud hud-br">
          <CreatureCard creature={selectedCreature} art={started.current?.spriteFor(selectedCreature.speciesName) ?? null} onClose={() => started.current?.selectCreature(null)} />
        </div>
      )}

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

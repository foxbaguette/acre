import { useCallback, useEffect, useRef, useState } from 'react'

import { CONTRACT } from '@/chain/config'
import { contractActions, contractTables, readTable, tableScopes } from '@/chain/rpc'
import { friendlyError, signer, transact } from '@/wallet/session'

/** How much a clear would take: rows left, or null when the table cannot be read (not in the deployed contract). */
type Count = number | null
/** For all maps at once: the rows left on each map that has any. */
type PerMap = Record<string, number>
/** player: what players made (islands and all on them, inventories, stores); config: the settings made in the other pages.
 *  wipe: where it comes in "clear all player data" (none: not part of it). */
type Clear = { action: string; title: string; note: string; group: 'player' | 'config'; wipe?: number; danger?: boolean; perMap?: boolean; tables?: string[]; count: (mapId: string) => Promise<Count> }

const rows = async (table: string, scope: string, keep: (r: Record<string, unknown>) => boolean = () => true): Promise<Count> => {
  const known = await contractTables(); if (known && !known.includes(table)) return null   // not in the deployed contract: nothing to read
  try { return (await readTable<Record<string, unknown>>(table, scope)).filter(keep).length } catch { return null }
}
const fenced = (r: Record<string, unknown>) => !r.is_water
const sum = (...c: Count[]): Count => (c.every((v) => v === null) ? null : c.reduce<number>((a, v) => a + (v ?? 0), 0))

/** Every clear land.acre has, what it removes, and how to count what is left (tables: where a map's rows for it live). */
const CLEARS: Clear[] = [
  // player data, all maps at once: the farmers' jobs and what grows go first, the land last; then the contract-wide rows
  { action: 'clrworkq', group: 'player', wipe: 1, title: 'The farmers’ jobs', note: 'the map’s worker queue, claimed or not (what they were sent for can be harvested again)', perMap: true, tables: ['workqueue'], count: (m) => rows('workqueue', m) },
  { action: 'clrplants', group: 'player', wipe: 2, title: 'What grows', note: 'the map’s sown crops (its soil stays)', perMap: true, tables: ['plants'], count: (m) => rows('plants', m) },
  { action: 'clearconstr', group: 'player', title: 'Everything built (the owner’s reset)', note: 'the map’s builds, its buildings and its fenced enclosures, given back to the owner’s inventory; the island’s own trees and the ponds stay', perMap: true, tables: ['constructs', 'buildings', 'enclosures'],
    count: async (m) => sum(await rows('constructs', m), await rows('buildings', m), await rows('enclosures', m, fenced)) },
  { action: 'clrconstrs', group: 'player', wipe: 3, title: 'Builds and buildings', note: 'the map’s constructs, the island’s own trees too, and its buildings (its enclosures are left as they are)', perMap: true, tables: ['constructs', 'buildings'],
    count: async (m) => sum(await rows('constructs', m), await rows('buildings', m)) },
  { action: 'clrencls', group: 'player', wipe: 4, title: 'Fenced enclosures', note: 'the map’s enclosures drawn by fences; the ponds stay', perMap: true, tables: ['enclosures'], count: (m) => rows('enclosures', m, fenced) },
  { action: 'clrstored', group: 'player', wipe: 4.5, title: 'What the island holds', note: 'the crops its farmers brought in and were claimed there', perMap: true, tables: ['stored'], count: (m) => rows('stored', m) },
  { action: 'clrchunks', group: 'player', wipe: 5, title: 'The land itself', note: 'the map’s chunks: its whole island, tile by tile; it cannot be opened again', danger: true, perMap: true, tables: ['chunks'], count: (m) => rows('chunks', m) },
  { action: 'clrmaps', group: 'player', wipe: 6, title: 'The list of maps', note: 'every row of maps: no island can be opened any more; their land, builds and enclosures stay until cleared map by map', danger: true, count: () => rows('maps', CONTRACT) },
  { action: 'clrinventory', group: 'player', wipe: 7, title: 'Every inventory', note: 'what every player holds; their next island counts as their first and brings the starting items', danger: true, count: () => rows('inventory', CONTRACT) },
  { action: 'clrseeds', group: 'player', wipe: 6.5, title: 'Every player’s seeds', note: 'the seeds every player holds (of every player with an inventory, so before the inventories go); sowing then waits for a harvest for seeds or for seeds given', count: async () => { const k = await contractTables(); if (k && !k.includes('seeds')) return null; return (await tableScopes('seeds')).reduce((n, x) => n + x.count, 0) } },
  { action: 'clrcropstore', group: 'player', wipe: 8, title: 'The old crop stores', note: 'from before the islands held their own crops (no longer filled: a player now holds what their islands hold)', count: () => rows('cropstore', CONTRACT) },
  { action: 'clrstorage', group: 'player', wipe: 9, title: 'Every island’s storage count', note: 'what each island can store and has filled; worked out again at its next build or harvest', count: () => rows('storage', CONTRACT) },
  // configs
  { action: 'cleargencfg', group: 'config', title: 'Generator configs', note: 'every config in genconfig; islands already charted stay as they are', count: () => rows('genconfig', CONTRACT) },
  { action: 'clrbuildcfg', group: 'config', title: 'Building definitions', note: 'every building in buildcfg (what can be built, its size, its rules, workers and storage)', count: () => rows('buildcfg', CONTRACT) },
  { action: 'clrcropcfg', group: 'config', title: 'Crops', note: 'every crop in cropcfg (what can be sown)', count: () => rows('cropcfg', CONTRACT) },
]

const WAITING = 'Waiting for your wallet…'
const ALL = 'all'

/** Lands › Clearing: each clear with what is left for it; per map, or for all maps at once, for the tables kept per map. */
export function AdminClear() {
  const [actions, setActions] = useState<string[] | null>(null)
  const [maps, setMaps] = useState<{ map_id: string; owner: string; map_name: string }[]>([])
  const [mapId, setMapId] = useState('')
  const [mapsRead, setMapsRead] = useState(false)
  const [counts, setCounts] = useState<Record<string, Count | undefined>>({})
  const [spread, setSpread] = useState<Record<string, PerMap>>({})
  const [status, setStatus] = useState<{ action: string; text: string; error?: boolean } | null>(null)
  // each clear's latest count: an older one (say for the map shown before) finishing late must not overwrite it
  const asked = useRef<Record<string, number>>({})

  useEffect(() => {
    contractActions().then(setActions)
    readTable<{ map_id: number | string; owner: string; map_name: string }>('maps', CONTRACT).then((r) => {
      const list = r.map((m) => ({ ...m, map_id: String(m.map_id) })).sort((a, b) => Number(a.map_id) - Number(b.map_id))
      setMaps(list); setMapId((cur) => cur || (list[0]?.map_id ?? '0')); setMapsRead(true)
    }, () => { setMapId((cur) => cur || '0'); setMapsRead(true) })
  }, [])

  /** For all maps: the maps that may hold rows for a clear (those in the list, those the chain shows rows for, and no. 0,
   *  which the chain's listing of scopes leaves out), and what each holds. */
  const countAll = useCallback(async (c: Clear): Promise<PerMap> => {
    const ids = new Set(['0', ...maps.map((m) => m.map_id)])
    for (const t of c.tables ?? []) for (const s of await tableScopes(t)) if (s.count > 0) ids.add(s.scope)
    const out: PerMap = {}
    await Promise.all([...ids].map(async (id) => { const n = await c.count(id); if (n) out[id] = n }))
    return out
  }, [maps])

  const recount = useCallback((which: Clear[]) => {
    for (const c of which) {
      if (c.perMap && mapId === '') continue
      setCounts((o) => ({ ...o, [c.action]: undefined }))
      const ask = (asked.current[c.action] ?? 0) + 1, latest = () => asked.current[c.action] === ask
      asked.current[c.action] = ask
      if (c.perMap && mapId === ALL) countAll(c).then((per) => { if (!latest()) return; setSpread((o) => ({ ...o, [c.action]: per })); setCounts((o) => ({ ...o, [c.action]: Object.values(per).reduce((a, n) => a + n, 0) })) })
      else c.count(mapId).then((n) => { if (latest()) setCounts((o) => ({ ...o, [c.action]: n })) })
    }
  }, [mapId, countAll])
  useEffect(() => { recount(CLEARS.filter((c) => !c.perMap)) }, [])   // (the contract-wide ones once; the map's whenever the map changes)
  useEffect(() => { if (mapId !== '') recount(CLEARS.filter((c) => c.perMap)) }, [mapId, recount])

  /** Clear all player data: for each player clear, the maps that hold anything for it (per map) or whether anything is
   *  left (the contract-wide ones), in the order the wipe sends them. */
  const [wipe, setWipe] = useState<{ action: string; map: string | null; n: number }[] | null>(null)
  const planWipe = useCallback(async () => {
    setWipe(null)
    const plan: { action: string; map: string | null; n: number }[] = []
    const steps = CLEARS.filter((c) => c.wipe !== undefined).sort((a, b) => a.wipe! - b.wipe!)
    const found = await Promise.all(steps.map(async (c) => (c.perMap ? Object.entries(await countAll(c)).map(([m, n]) => ({ action: c.action, map: m as string | null, n })) : [{ action: c.action, map: null, n: (await c.count('')) ?? 0 }])))
    for (const list of found) for (const p of list) if (p.n > 0 && actions?.includes(p.action)) plan.push(p)
    setWipe(plan)
  }, [countAll, actions])
  useEffect(() => { if (mapsRead && actions) planWipe() }, [mapsRead, actions, planWipe])
  const runWipe = async () => {
    const who = signer(); if (!who) { setStatus({ action: 'wipe', text: 'Sign in with a wallet first.', error: true }); return }
    if (!wipe?.length) return
    setStatus({ action: 'wipe', text: WAITING })
    try {
      await transact(wipe.map((p) => ({ account: CONTRACT, name: p.action, authorization: [who], data: p.map === null ? { wallet: who.actor } : { wallet: who.actor, map_id: p.map } })))
      setStatus({ action: 'wipe', text: 'All player data cleared.' })
      const again = () => { recount(CLEARS); planWipe() }
      setTimeout(again, 1500); setTimeout(again, 4000)
    } catch (e) { setStatus({ action: 'wipe', text: friendlyError(e), error: true }) }
  }
  const wipeMaps = new Set((wipe ?? []).filter((p) => p.map !== null).map((p) => p.map)).size
  const wipeRows = (wipe ?? []).reduce((a, p) => a + p.n, 0)

  const run = async (c: Clear) => {
    // straight to the wallet: its own signing screen is where it is confirmed
    const who = signer(); if (!who) { setStatus({ action: c.action, text: 'Sign in with a wallet first.', error: true }); return }
    // for all maps: one action for each map that has anything to clear, in one transaction
    const targets = !c.perMap ? [null] : mapId === ALL ? Object.keys(spread[c.action] ?? {}).sort((a, b) => Number(a) - Number(b)) : [mapId]
    if (!targets.length) return
    setStatus({ action: c.action, text: WAITING })
    try {
      await transact(targets.map((m) => ({ account: CONTRACT, name: c.action, authorization: [who], data: m === null ? { wallet: who.actor } : { wallet: who.actor, map_id: m } })))
      setStatus({ action: c.action, text: targets.length > 1 ? `Cleared on ${targets.length} maps.` : 'Cleared.' })
      const again = () => { recount([c]); if (c.group === 'player') planWipe() }
      setTimeout(again, 1500); setTimeout(again, 4000)   // once a node has the block
    } catch (e) { setStatus({ action: c.action, text: friendlyError(e), error: true }) }
  }

  const line = (c: Clear) => {
    const deployed = actions === null ? null : actions.includes(c.action), n = counts[c.action]
    const on = c.perMap && mapId === ALL ? Object.keys(spread[c.action] ?? {}) : null
    const where = on && on.length ? ` on ${on.length} map${on.length === 1 ? '' : 's'}` : ''
    const state = deployed === false ? 'not in the deployed contract yet' : n === undefined ? 'counting…' : n === null ? 'cannot be read' : n === 0 ? 'already clear' : `${n} row${n === 1 ? '' : 's'} to clear${where}`
    const cls = deployed === false || n === null ? 'is-missing' : n === 0 ? 'is-clear' : n === undefined ? '' : 'is-full'
    return (
      <li key={c.action} className={cls}>
        <span className="clr-what"><b>{c.title}</b> <code>{c.action}</code><small>{c.note}</small>
          {on && on.length > 0 && <small className="clr-on">maps {on.sort((a, b) => Number(a) - Number(b)).map((id) => `no. ${id} (${spread[c.action][id]})`).join(', ')}</small>}</span>
        <span className="clr-state">{state}</span>
        <span className="clr-act">
          <button type="button" className={`btn small${c.danger ? ' danger' : ''}`} disabled={!deployed || !n || status?.text === WAITING} onClick={() => run(c)}>{on ? 'clear all' : 'clear'}</button>
          {status?.action === c.action && <small className={status.error ? 'clr-err' : 'clr-ok'} role="status">{status.text}</small>}
        </span>
      </li>
    )
  }

  return (
    <section className="admin-section">
      <div className="admin-h"><h1>Clearing</h1></div>
      <p className="admin-lede">Every clear land.acre has, with what is left for it. Only the contract’s authorizers may run them (and an owner the reset of their own map). Player data is what players made; configs are the settings made in the other admin pages.</p>

      <div className="clr-part">
        <h2 className="clr-part-h">Player data</h2>
        <div className="clr-wipe">
          <span className="clr-what"><b>Clear all player data</b>
            <small>Every island and everything on it (land, builds, enclosures, what grows, the farmers’ jobs, what it holds), the list of maps, every inventory, crop store and storage count: all in one transaction. The configs stay. (The creatures live in life.acre: Life › Clearing.)</small>
            {wipe && wipe.length > 0 && <small className="clr-on">{wipeRows} row{wipeRows === 1 ? '' : 's'}{wipeMaps ? ` on ${wipeMaps} map${wipeMaps === 1 ? '' : 's'}` : ''} · {wipe.length} action{wipe.length === 1 ? '' : 's'}: {[...new Set(wipe.map((p) => p.action))].join(', ')}</small>}</span>
          <span className="clr-state">{wipe === null ? 'counting…' : wipe.length ? 'player data to clear' : 'already clear'}</span>
          <span className="clr-act">
            <button type="button" className="btn small danger" disabled={!wipe?.length || status?.text === WAITING} onClick={runWipe}>clear all player data</button>
            {status?.action === 'wipe' && <small className={status.error ? 'clr-err' : 'clr-ok'} role="status">{status.text}</small>}
          </span>
        </div>
        <h3 className="clr-h">The whole contract</h3>
        <ul className="clr-list">{CLEARS.filter((c) => c.group === 'player' && !c.perMap).map(line)}</ul>
        <div className="clr-h clr-map">
          <h3>{mapId === ALL ? 'All maps' : 'One map'}</h3>
          <label>
            <span>map</span>
            <select value={mapId} onChange={(e) => setMapId(e.target.value)}>
              <option value={ALL}>all maps at once</option>
              {maps.map((m) => <option key={m.map_id} value={m.map_id}>no. {m.map_id}{m.map_name ? ` · ${m.map_name}` : ''} · {m.owner}</option>)}
              {mapId !== '' && mapId !== ALL && !maps.some((m) => m.map_id === mapId) && <option value={mapId}>no. {mapId} (not in the list of maps)</option>}
            </select>
          </label>
          {mapId !== ALL && (
            <label>
              <span>or any no.</span>
              <input type="number" min={0} step={1} value={mapId} onChange={(e) => setMapId(e.target.value.replace(/\D/g, ''))} />
            </label>
          )}
        </div>
        {mapId === ALL && <p className="admin-lede">Every map that has anything for a clear, also those no longer in the list of maps; each clear sends one action per map, all in one transaction.</p>}
        <ul className="clr-list">{CLEARS.filter((c) => c.perMap).map(line)}</ul>
      </div>

      <div className="clr-part clr-configs">
        <h2 className="clr-part-h">Configs</h2>
        <p className="admin-lede">The settings made in the other admin pages. Cleared, nothing can be charted, built or sown until they are set again.</p>
        <ul className="clr-list">{CLEARS.filter((c) => c.group === 'config').map(line)}</ul>
      </div>
    </section>
  )
}

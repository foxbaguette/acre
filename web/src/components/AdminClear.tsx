import { useCallback, useEffect, useRef, useState } from 'react'

import { CONTRACT } from '@/chain/config'
import { contractActions, contractTables, readTable, tableScopes } from '@/chain/rpc'
import { friendlyError, signer, transact } from '@/wallet/session'

/** How much a clear would take: rows left, or null when the table cannot be read (not in the deployed contract). */
type Count = number | null
/** For all maps at once: the rows left on each map that has any. */
type PerMap = Record<string, number>
type Clear = { action: string; title: string; note: string; danger?: boolean; perMap?: boolean; tables?: string[]; count: (mapId: string) => Promise<Count> }

const rows = async (table: string, scope: string, keep: (r: Record<string, unknown>) => boolean = () => true): Promise<Count> => {
  const known = await contractTables(); if (known && !known.includes(table)) return null   // not in the deployed contract: nothing to read
  try { return (await readTable<Record<string, unknown>>(table, scope)).filter(keep).length } catch { return null }
}
const fenced = (r: Record<string, unknown>) => !r.is_water
const sum = (...c: Count[]): Count => (c.every((v) => v === null) ? null : c.reduce<number>((a, v) => a + (v ?? 0), 0))

/** Every clear land.acre has, what it removes, and how to count what is left (tables: where a map's rows for it live). */
const CLEARS: Clear[] = [
  { action: 'cleargencfg', title: 'Generator configs', note: 'every config in genconfig; islands already charted stay as they are', count: () => rows('genconfig', CONTRACT) },
  { action: 'clrmaps', title: 'The list of maps', note: 'every row of maps: no island can be opened any more; their land, builds and enclosures stay until cleared map by map', danger: true, count: () => rows('maps', CONTRACT) },
  { action: 'clrbuildcfg', title: 'Building definitions', note: 'every building in buildcfg (what can be built, its size and its rules)', count: () => rows('buildcfg', CONTRACT) },
  { action: 'clearconstr', title: 'Everything built (the owner’s reset)', note: 'the map’s builds, its buildings and its fenced enclosures; the ponds stay', perMap: true, tables: ['constructs', 'buildings', 'enclosures'],
    count: async (m) => sum(await rows('constructs', m), await rows('buildings', m), await rows('enclosures', m, fenced)) },
  { action: 'clrconstrs', title: 'Builds and buildings', note: 'the map’s constructs and buildings (its enclosures are left as they are)', perMap: true, tables: ['constructs', 'buildings'],
    count: async (m) => sum(await rows('constructs', m), await rows('buildings', m)) },
  { action: 'clrencls', title: 'Fenced enclosures', note: 'the map’s enclosures drawn by fences; the ponds stay', perMap: true, tables: ['enclosures'], count: (m) => rows('enclosures', m, fenced) },
  { action: 'clrchunks', title: 'The land itself', note: 'the map’s chunks: its whole island, tile by tile; it cannot be opened again', danger: true, perMap: true, tables: ['chunks'], count: (m) => rows('chunks', m) },
]

const WAITING = 'Waiting for your wallet…'
const ALL = 'all'

/** Lands › Clearing: each clear with what is left for it; per map, or for all maps at once, for the tables kept per map. */
export function AdminClear() {
  const [actions, setActions] = useState<string[] | null>(null)
  const [maps, setMaps] = useState<{ map_id: string; owner: string; map_name: string }[]>([])
  const [mapId, setMapId] = useState('')
  const [counts, setCounts] = useState<Record<string, Count | undefined>>({})
  const [spread, setSpread] = useState<Record<string, PerMap>>({})
  const [status, setStatus] = useState<{ action: string; text: string; error?: boolean } | null>(null)
  // each clear's latest count: an older one (say for the map shown before) finishing late must not overwrite it
  const asked = useRef<Record<string, number>>({})

  useEffect(() => {
    contractActions().then(setActions)
    readTable<{ map_id: number | string; owner: string; map_name: string }>('maps', CONTRACT).then((r) => {
      const list = r.map((m) => ({ ...m, map_id: String(m.map_id) })).sort((a, b) => Number(a.map_id) - Number(b.map_id))
      setMaps(list); setMapId((cur) => cur || (list[0]?.map_id ?? '0'))
    }, () => setMapId((cur) => cur || '0'))
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
      setTimeout(() => recount([c]), 1500); setTimeout(() => recount([c]), 4000)   // once a node has the block
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
      <p className="admin-lede">Every clear land.acre has, with what is left for it. Only the contract’s authorizers may run them (and an owner the reset of their own map).</p>
      <h2 className="clr-h">The whole contract</h2>
      <ul className="clr-list">{CLEARS.filter((c) => !c.perMap).map(line)}</ul>
      <div className="clr-h clr-map">
        <h2>{mapId === ALL ? 'All maps' : 'One map'}</h2>
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
    </section>
  )
}

import { useEffect, useState } from 'react'

import { CONTRACT } from '@/chain/config'
import { KINDS } from '@/chain/constructs'
import { fetchBuildCfg, type BuildCfg } from '@/chain/inventory'
import { actionFields, contractActions } from '@/chain/rpc'
import { BUILDINGS } from '@/engine/build'
import { friendlyError, signer, transact } from '@/wallet/session'

type Status = { state: 'idle' } | { state: 'busy' } | { state: 'error'; message: string } | { state: 'done'; message: string }
type Draft = Omit<BuildCfg, 'building'> & { editing: boolean; copiedFrom: string | null }
const WAITING = 'Waiting for your wallet…'

/** A building to start from for a kind: the site's own picture for it (its size, whether it is the market). */
const fresh = (kind: number): Draft => {
  const k = KINDS[kind - 1], b = k ? BUILDINGS[k] : null
  return { name: k ?? '', display: k ?? '', kind, main: !!b?.main, mainAccess: false, insideOk: k === 'nest', w: b?.w ?? 1, h: b?.h ?? 1,
    requiresPath: !!b && b.door !== undefined && !b.main, workers: k === 'farmhouse' ? 1 : 0, storage: k === 'silo' ? 100 : 0, editing: false, copiedFrom: null }
}

/** Lands › Buildings: what can be built (land.acre buildcfg), with its rules, its workers and its storage. */
export function AdminBuildings() {
  const [rows, setRows] = useState<BuildCfg[] | null>(null)
  const [readError, setReadError] = useState<string | null>(null)
  const [actions, setActions] = useState<string[] | null>(null)
  const [full, setFull] = useState<boolean | null>(null)
  const [draft, setDraft] = useState<Draft | null>(null)
  const [status, setStatus] = useState<Status>({ state: 'idle' })

  const load = () => fetchBuildCfg().then((r) => { setRows(r); setReadError(null) }, (e) => setReadError(friendlyError(e)))
  useEffect(() => {
    load(); contractActions().then(setActions)
    actionFields('setbuildcfg').then((f) => setFull(f.includes('workers')))   // workers, storage and the path rule came with the update
  }, [])
  const deployed = actions === null ? null : actions.includes('setbuildcfg')
  const busy = status.state === 'busy'
  const freeKind = () => { for (let k = 1; k <= 15; k++) if (!rows?.some((r) => r.kind === k)) return k; return 1 }

  const send = async (name: string, data: Record<string, unknown>, done: string) => {
    // straight to the wallet: its own signing screen is where it is confirmed
    const who = signer(); if (!who) { setStatus({ state: 'error', message: 'Sign in with a wallet first.' }); return false }
    setStatus({ state: 'busy' })
    try {
      await transact([{ account: CONTRACT, name, authorization: [who], data: { wallet: who.actor, ...data } }])
      setStatus({ state: 'done', message: done }); setTimeout(load, 1500); setTimeout(load, 4000); return true
    } catch (e) { setStatus({ state: 'error', message: friendlyError(e) }); return false }
  }
  const save = async () => {
    if (!draft) return
    if (!/^[a-z1-5.]{1,12}$/.test(draft.name) || draft.name.endsWith('.')) { setStatus({ state: 'error', message: 'building name: a WAX name (a–z, 1–5 and dots, up to 12)' }); return }
    if (rows?.some((r) => r.kind === draft.kind && r.name !== draft.name)) { setStatus({ state: 'error', message: `kind ${draft.kind} belongs to another building already` }); return }
    for (const [v, what, max] of [[draft.w, 'width', 255], [draft.h, 'depth', 255], [draft.workers, 'workers', 65535], [draft.storage, 'storage', 4294967295]] as const)
      if (!Number.isInteger(v) || v < 0 || v > max || ((what === 'width' || what === 'depth') && v < 1)) { setStatus({ state: 'error', message: `${what}: a whole number up to ${max}` }); return }
    const data: Record<string, unknown> = { building_name: draft.name, building_display_name: draft.display, kind: draft.kind, is_main_building: draft.main, needs_main_access: draft.mainAccess, allowed_inside_enclosures: draft.insideOk, x_size: draft.w, y_size: draft.h }
    if (full) Object.assign(data, { requires_path: draft.requiresPath, workers: draft.workers, storage: draft.storage })
    if (await send('setbuildcfg', data, `${draft.display || draft.name} saved.`)) setDraft(null)
  }
  const from = (r: BuildCfg, copy: boolean): Draft => ({ ...r, editing: !copy, copiedFrom: copy ? r.name : null, ...(copy ? { name: '', kind: freeKind() } : {}) })
  const tick = (key: 'main' | 'mainAccess' | 'insideOk' | 'requiresPath', label: string, hint: string, needsFull = false) => draft && (
    <label className="gen-bool" title={hint}><input type="checkbox" disabled={needsFull && !full} checked={draft[key]} onChange={(e) => setDraft({ ...draft, [key]: e.target.checked })} /><span>{label}</span><small>{hint}</small></label>
  )
  const num = (key: 'w' | 'h' | 'workers' | 'storage', label: string, hint: string, needsFull = false) => draft && (
    <label title={hint}><span>{label}</span><input type="number" min={0} step={1} disabled={needsFull && !full} value={draft[key]} onChange={(e) => setDraft({ ...draft, [key]: Number(e.target.value) })} /><small>{hint}</small></label>
  )

  return (
    <section className="admin-section">
      <div className="admin-h">
        <h1>Buildings</h1>
        <span>
          <button type="button" className="btn small" disabled={busy || rows === null || !deployed} onClick={() => { setDraft(fresh(freeKind())); setStatus({ state: 'idle' }) }}>new building</button>{' '}
          <button type="button" className="btn small danger" disabled={busy || !rows?.length || !deployed} onClick={() => send('clrbuildcfg', {}, 'Every building cleared.')}>clear all</button>
        </span>
      </div>
      <p className="admin-lede">What can be built (land.acre, table buildcfg). The kind is the number the island stores for it and picks its picture; workers are the farmers who live in it (sent out while it is joined to the market), storage what it adds to its island’s storage (harvests fill it, and a building with storage takes them in).</p>
      {full === false && <p className="admin-note">The deployed setbuildcfg has no path rule, workers or storage yet: they come with the contract’s update.</p>}
      {readError && <p className="admin-error" role="alert">Could not read the buildings: {readError}</p>}
      {rows === null && !readError && <p className="hand">Reading the buildings…</p>}
      {rows && rows.length === 0 && <p className="hand">No buildings yet: nothing can be built until they are here.</p>}
      {rows && rows.length > 0 && (
        <ul className="gen-list">
          {rows.map((r) => (
            <li key={r.name} className={draft?.editing && draft.name === r.name ? 'is-open' : ''}>
              <span className="gen-no">kind {r.kind}</span>
              <span className="gen-sum"><b>{r.display || r.name}</b> <code>{r.name}</code> · {r.w} × {r.h}{r.building ? '' : ' · no picture for this kind'}{r.main ? ' · the market' : ''}{r.requiresPath ? ' · needs a path' : ''}{r.insideOk ? ' · may stand in an enclosure' : ''}{r.workers ? ` · ${r.workers} worker${r.workers === 1 ? '' : 's'}` : ''}{r.storage ? ` · stores ${r.storage}` : ''}</span>
              <span className="gen-acts">
                <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft(from(r, false)); setStatus({ state: 'idle' }) }}>edit</button>
                <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft(from(r, true)); setStatus({ state: 'idle' }) }}>copy</button>
                <button type="button" className="build-link danger" disabled={busy || !deployed} onClick={() => send('delbuildcfg', { building_name: r.name }, `${r.display || r.name} deleted.`)}>delete</button>
              </span>
            </li>
          ))}
        </ul>
      )}
      {status.state === 'busy' && <p className="admin-note" role="status">{WAITING}</p>}
      {status.state === 'done' && <p className="admin-done" role="status">{status.message}</p>}
      {status.state === 'error' && <p className="admin-error" role="alert">{status.message}</p>}

      {draft && (
        <form className="gen-edit" onSubmit={(e) => { e.preventDefault(); save() }}>
          <div className="admin-h"><h2>{draft.editing ? `Changing ${draft.display || draft.name}` : draft.copiedFrom ? `A new building, copied from ${draft.copiedFrom}` : 'A new building'}</h2></div>
          <fieldset>
            <legend>the building</legend>
            <div className="gen-grid">
              <label><span>building name</span><input type="text" maxLength={12} disabled={draft.editing} value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value.toLowerCase() })} /><small>a WAX name: also its name in inventories</small></label>
              <label><span>shown as</span><input type="text" maxLength={64} value={draft.display} onChange={(e) => setDraft({ ...draft, display: e.target.value })} /><small>its name for players</small></label>
              <label><span>kind</span>
                <select value={draft.kind} onChange={(e) => { const k = Number(e.target.value), b = KINDS[k - 1] ? BUILDINGS[KINDS[k - 1]] : null; setDraft({ ...draft, kind: k, ...(b && !draft.editing ? { w: b.w, h: b.h } : {}) }) }}>
                  {Array.from({ length: 15 }, (_, i) => i + 1).map((k) => <option key={k} value={k}>{k}{KINDS[k - 1] ? ` · ${KINDS[k - 1]}` : ''}{rows?.some((r) => r.kind === k && r.name !== draft.name) ? ' (taken)' : ''}</option>)}
                </select><small>the picture the island draws for it</small></label>
              {num('w', 'width', 'tiles across, entrance facing south')}
              {num('h', 'depth', 'tiles down')}
            </div>
          </fieldset>
          <fieldset>
            <legend>its rules</legend>
            <div className="gen-grid">
              {tick('requiresPath', 'requires a path', 'it can only be put up with a path touching it', true)}
              {tick('main', 'the main building', 'the market: the other buildings’ paths lead to it')}
              {tick('mainAccess', 'needs the market', 'its entrance must reach the main building')}
              {tick('insideOk', 'may stand in an enclosure', 'otherwise an enclosure closed round it takes it down')}
            </div>
          </fieldset>
          <fieldset>
            <legend>workers and storage</legend>
            <div className="gen-grid">
              {num('workers', 'workers', 'the farmers who live in it, sent out while it is joined to the market', true)}
              {num('storage', 'storage', 'what it adds to its island’s storage; harvests go to the nearest building with storage', true)}
            </div>
          </fieldset>
          <div className="gen-foot">
            <button type="submit" className="btn" disabled={busy || !deployed}>{busy ? WAITING : draft.editing ? 'save' : 'add'}</button>
            <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft(null); setStatus({ state: 'idle' }) }}>cancel</button>
          </div>
        </form>
      )}
    </section>
  )
}

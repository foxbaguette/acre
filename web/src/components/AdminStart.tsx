import { useEffect, useState } from 'react'

import { CONTRACT } from '@/chain/config'
import { fetchBuildCfgNames, fetchStartItems, GROUND_ITEMS } from '@/chain/inventory'
import { contractActions } from '@/chain/rpc'
import { friendlyError, signer, transact } from '@/wallet/session'

type Status = { state: 'idle' } | { state: 'busy' } | { state: 'error'; message: string } | { state: 'done'; message: string }
const WAITING = 'Waiting for your wallet…'

/** Lands › First island: what a player gets with the first island they ever chart (land.acre, table startitems). */
export function AdminStartItems() {
  const [rows, setRows] = useState<{ name: string; amount: number }[] | null | undefined>(undefined)
  const [buildings, setBuildings] = useState<{ name: string; display: string }[]>([])
  const [actions, setActions] = useState<string[] | null>(null)
  const [readError, setReadError] = useState<string | null>(null)
  const [draft, setDraft] = useState<{ name: string; amount: number; editing: boolean } | null>(null)
  const [status, setStatus] = useState<Status>({ state: 'idle' })

  const load = () => fetchStartItems().then((r) => { setRows(r); setReadError(null) }, (e) => setReadError(friendlyError(e)))
  useEffect(() => {
    load()
    contractActions().then(setActions)
    fetchBuildCfgNames().then(setBuildings, () => setBuildings([]))
  }, [])

  const deployed = actions === null ? null : actions.includes('setstartitem') && actions.includes('delstartitem')
  const choices = [...GROUND_ITEMS.map((n) => ({ name: n, display: n })), ...buildings]
  const label = (name: string) => choices.find((c) => c.name === name)?.display ?? name
  const settle = (message: string) => { setStatus({ state: 'done', message }); setTimeout(load, 1500); setTimeout(load, 4000) }

  const send = async (name: 'setstartitem' | 'delstartitem', data: Record<string, unknown>, done: string) => {
    // straight to the wallet: its own signing screen is where it is confirmed
    const who = signer(); if (!who) { setStatus({ state: 'error', message: 'Sign in with a wallet first.' }); return false }
    setStatus({ state: 'busy' })
    try {
      await transact([{ account: CONTRACT, name, authorization: [who], data: { wallet: who.actor, ...data } }])
      settle(done); return true
    } catch (e) { setStatus({ state: 'error', message: friendlyError(e) }); return false }
  }
  const save = async () => {
    if (!draft) return
    if (!Number.isInteger(draft.amount) || draft.amount < 1 || draft.amount > 65535) { setStatus({ state: 'error', message: 'amount: a whole number from 1 to 65535' }); return }
    if (await send('setstartitem', { building_name: draft.name, amount: draft.amount }, `${label(draft.name)}: ${draft.amount} saved.`)) setDraft(null)
  }

  const busy = status.state === 'busy'
  const free = choices.filter((c) => !rows?.some((r) => r.name === c.name))
  const startNew = () => { if (free.length) { setDraft({ name: free[0].name, amount: 1, editing: false }); setStatus({ state: 'idle' }) } }

  return (
    <section className="admin-section">
      <div className="admin-h">
        <h1>First island</h1>
        <button type="button" className="btn small" disabled={busy || !rows || !deployed || !free.length} onClick={startNew}>add something</button>
      </div>
      <p className="admin-lede">What a player gets with the first island they ever chart (land.acre, table startitems). Building, laying or planting takes from their inventory (a building one, soil, a path, a fence or a tree one a tile), and erasing gives it back.</p>
      {deployed === false && <p className="admin-note">The deployed contract has no starting inventory yet (setstartitem, delstartitem and the startitems table come with its update).</p>}
      {buildings.length === 0 && <p className="admin-note">buildcfg is empty: only soil, paths, fences and trees can be handed out until the buildings are in it.</p>}

      {readError && <p className="admin-error" role="alert">Could not read the starting inventory: {readError}</p>}
      {rows === undefined && !readError && <p className="hand">Reading the starting inventory…</p>}
      {rows && rows.length === 0 && <p className="hand">Nothing yet: a first island brings nothing.</p>}
      {rows && rows.length > 0 && (
        <ul className="gen-list">
          {rows.map((r) => (
            <li key={r.name} className={draft?.name === r.name ? 'is-open' : ''}>
              <span className="gen-no">{r.amount} ×</span>
              <span className="gen-sum"><b>{label(r.name)}</b>{label(r.name) !== r.name ? <> · <code>{r.name}</code></> : null}</span>
              <span className="gen-acts">
                <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft({ name: r.name, amount: r.amount, editing: true }); setStatus({ state: 'idle' }) }}>edit</button>
                <button type="button" className="build-link danger" disabled={busy || !deployed} onClick={() => send('delstartitem', { building_name: r.name }, `${label(r.name)} taken off the list.`)}>delete</button>
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
          <div className="admin-h"><h2>{draft.editing ? `Changing ${label(draft.name)}` : 'Something more for a first island'}</h2></div>
          <div className="gen-grid">
            <label>
              <span>what</span>
              {draft.editing ? <input type="text" value={label(draft.name)} disabled /> : (
                <select value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })}>
                  {free.map((c) => <option key={c.name} value={c.name}>{c.display}{c.display !== c.name ? ` (${c.name})` : ''}</option>)}
                </select>
              )}
              <small>soil, a path, a fence or a tree is one tile; a building is one building</small>
            </label>
            <label>
              <span>how many</span>
              <input type="number" min={1} max={65535} step={1} value={draft.amount} onChange={(e) => setDraft({ ...draft, amount: Number(e.target.value) })} />
              <small>given once, with the first island</small>
            </label>
          </div>
          <div className="gen-foot">
            <button type="submit" className="btn" disabled={busy || !deployed}>{busy ? WAITING : draft.editing ? 'save' : 'add'}</button>
            <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft(null); setStatus({ state: 'idle' }) }}>cancel</button>
          </div>
        </form>
      )}
    </section>
  )
}

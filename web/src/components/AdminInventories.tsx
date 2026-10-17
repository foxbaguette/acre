import { useEffect, useState } from 'react'

import { CONTRACT } from '@/chain/config'
import { contractActions, contractTables, readTable } from '@/chain/rpc'
import { fetchCropCfg, fetchSeeds } from '@/chain/farming'
import { friendlyError, signer, transact } from '@/wallet/session'

type Row = { wallet: string; items: { building_name: string; amount: number }[] }
type Status = { state: 'idle' } | { state: 'busy' } | { state: 'error'; message: string } | { state: 'done'; message: string }
const WAITING = 'Waiting for your wallet…'

/** Lands › Inventories: what every player holds (land.acre inventory), and clearing a player's row. */
export function AdminInventories() {
  const [rows, setRows] = useState<Row[] | null>(null)
  const [readError, setReadError] = useState<string | null>(null)
  const [actions, setActions] = useState<string[] | null>(null)
  const [status, setStatus] = useState<Status>({ state: 'idle' })
  // each player's seeds by crop name (land.acre seeds, scope = the player); null: the table is not deployed yet
  const [seeds, setSeeds] = useState<Record<string, Record<string, number>> | null>(null)

  const load = async () => {
    try {
      const t = await contractTables(); if (t && !t.includes('inventory')) { setRows([]); return }
      const list = (await readTable<Row>('inventory', CONTRACT)).sort((a, b) => a.wallet.localeCompare(b.wallet))
      setRows(list); setReadError(null)
      if (t && !t.includes('seeds')) { setSeeds(null); return }
      const crops = await fetchCropCfg().catch(() => []), name = (id: string) => crops.find((c) => c.id === id)?.name ?? `crop ${id}`
      const held = await Promise.all(list.map((r) => fetchSeeds(r.wallet).catch(() => null)))
      setSeeds(Object.fromEntries(list.map((r, k) => [r.wallet, Object.fromEntries(Object.entries(held[k] ?? {}).map(([id, n]) => [name(id), n]))])))
    } catch (e) { setReadError(friendlyError(e)) }
  }
  useEffect(() => { load(); contractActions().then(setActions) }, [])
  const can = (a: string) => !!actions?.includes(a)
  const busy = status.state === 'busy'

  const send = async (name: string, data: Record<string, unknown>, done: string) => {
    // straight to the wallet: its own signing screen is where it is confirmed
    const who = signer(); if (!who) { setStatus({ state: 'error', message: 'Sign in with a wallet first.' }); return }
    setStatus({ state: 'busy' })
    try {
      await transact([{ account: CONTRACT, name, authorization: [who], data: { wallet: who.actor, ...data } }])
      setStatus({ state: 'done', message: done }); setTimeout(load, 1500); setTimeout(load, 4000)
    } catch (e) { setStatus({ state: 'error', message: friendlyError(e) }) }
  }

  return (
    <section className="admin-section">
      <div className="admin-h">
        <h1>Inventories</h1>
        <button type="button" className="btn small danger" disabled={busy || !rows?.length || !can('clrinventory')} onClick={() => send('clrinventory', {}, 'Every inventory cleared.')}>clear all</button>
      </div>
      <p className="admin-lede">What every player holds (land.acre, table inventory) and their seeds (table seeds; Lands › Clear clears them). Clearing a player’s row takes everything they hold, and their next island counts as their first: it brings what Lands › First island lists.</p>
      {actions && !can('delinventory') && <p className="admin-note">The deployed contract cannot clear inventories yet (delinventory and clrinventory come with its update).</p>}
      {readError && <p className="admin-error" role="alert">Could not read the inventories: {readError}</p>}
      {rows === null && !readError && <p className="hand">Reading the inventories…</p>}
      {rows && rows.length === 0 && <p className="hand">No player has an inventory row.</p>}
      {rows && rows.length > 0 && (
        <ul className="gen-list">
          {rows.map((r) => (
            <li key={r.wallet}>
              <span className="gen-no">{r.wallet}</span>
              <span className="gen-sum">{r.items.length ? r.items.map((i) => `${i.amount} ${i.building_name}`).join(' · ') : <i>holds nothing</i>}
                {seeds && <small className="inv-seeds">seeds: {Object.keys(seeds[r.wallet] ?? {}).length ? Object.entries(seeds[r.wallet]).map(([c, n]) => `${n} ${c}`).join(' · ') : 'none'}</small>}</span>
              <span className="gen-acts">
                <button type="button" className="build-link danger" disabled={busy || !can('delinventory')} onClick={() => send('delinventory', { owner: r.wallet }, `${r.wallet}’s inventory cleared: their next island brings the starting items.`)}>clear</button>
              </span>
            </li>
          ))}
        </ul>
      )}
      {status.state === 'busy' && <p className="admin-note" role="status">{WAITING}</p>}
      {status.state === 'done' && <p className="admin-done" role="status">{status.message}</p>}
      {status.state === 'error' && <p className="admin-error" role="alert">{status.message}</p>}
    </section>
  )
}

import { useEffect, useMemo, useState } from 'react'

import { AdminClear } from '@/components/AdminClear'
import { fetchGenRows, fetchIsAuthorizer, GEN_DEFAULTS, GEN_FIELDS, genProblem, type GenRow } from '@/chain/admin'
import { CONTRACT } from '@/chain/config'
import { actionFields } from '@/chain/rpc'
import { AccountTag, Header } from '@/journal/Header'
import { friendlyError, signer, transact } from '@/wallet/session'

/** The admin panel: the game's settings, for land.acre's authorizers. For now: Lands › Genconfig. */
export function AdminPage({ account, wallet, onSignOut, onLeave }: { account: string; wallet: string | null; onSignOut: () => void; onLeave: () => void }) {
  const [authorized, setAuthorized] = useState<boolean | null>(null)
  const [section, setSection] = useState<'genconfig' | 'clear'>('genconfig')
  useEffect(() => { fetchIsAuthorizer(account).then(setAuthorized) }, [account])
  return (
    <div className="admin">
      <Header home="contents-1" right={<AccountTag account={account} wallet={wallet} onSignOut={onSignOut} />} />
      <div className="wrap admin-body">
        <nav className="admin-nav" aria-label="Admin">
          <button type="button" className="admin-back hand" onClick={onLeave}>← back to the journal</button>
          <h2>Lands</h2>
          <ul>
            {([['genconfig', 'Genconfig'], ['clear', 'Clearing']] as const).map(([k, label]) => (
              <li key={k}><button type="button" aria-current={section === k ? 'page' : undefined} onClick={() => setSection(k)}>{label}</button></li>
            ))}
          </ul>
        </nav>
        <main className="admin-main">
          {authorized === false && <p className="admin-note">This wallet is not one of land.acre’s authorizers: you can look, but the contract will refuse any change.</p>}
          {section === 'genconfig' ? <GenConfigs /> : <AdminClear />}
        </main>
      </div>
    </div>
  )
}

type Draft = { index: string; values: Record<string, number | boolean>; copiedFrom: string | null }
type Status = { state: 'idle' } | { state: 'busy'; what: string } | { state: 'error'; message: string } | { state: 'done'; message: string }

/** The generator configs: the list, and an editor to add one (empty or copied from another) or change one. */
function GenConfigs() {
  const [rows, setRows] = useState<GenRow[] | null>(null)
  const [readError, setReadError] = useState<string | null>(null)
  const [fields, setFields] = useState<{ indexed: boolean; canDelete: boolean } | null>(null)
  const [draft, setDraft] = useState<Draft | null>(null)
  const [status, setStatus] = useState<Status>({ state: 'idle' })

  const load = () => fetchGenRows().then((r) => { setRows(r); setReadError(null) }, (e) => setReadError(friendlyError(e)))
  useEffect(() => {
    load()
    // what the deployed contract takes: numbered configs and deleting one came with its update
    Promise.all([actionFields('setgenconfig'), actionFields('delgencfg')]).then(([set, del]) => setFields({ indexed: set.includes('index'), canDelete: del.includes('index') }))
  }, [])

  const nextIndex = useMemo(() => String(rows && rows.length ? Math.max(...rows.map((r) => Number(r.index))) + 1 : 0), [rows])
  const startNew = (from: GenRow | null) => {
    const values = from ? Object.fromEntries(GEN_FIELDS.map((f) => [f.name, from[f.name] as number | boolean])) : { ...GEN_DEFAULTS }
    setDraft({ index: nextIndex, values, copiedFrom: from ? from.index : null }); setStatus({ state: 'idle' })
  }
  const edit = (row: GenRow) => { setDraft({ index: row.index, values: Object.fromEntries(GEN_FIELDS.map((f) => [f.name, row[f.name] as number | boolean])), copiedFrom: null }); setStatus({ state: 'idle' }) }

  // after a change, read the table again once a node has the block
  const settle = (message: string) => { setStatus({ state: 'done', message }); setTimeout(load, 1500); setTimeout(load, 4000) }

  const save = async () => {
    if (!draft) return
    if (cannotSave) return
    const problem = genProblem(draft.values); if (problem) { setStatus({ state: 'error', message: problem }); return }
    const who = signer(); if (!who) { setStatus({ state: 'error', message: 'Sign in with a wallet first.' }); return }
    const data: Record<string, unknown> = { wallet: who.actor, ...draft.values }
    if (fields?.indexed) data.index = draft.index
    setStatus({ state: 'busy', what: 'Waiting for your wallet…' })
    try {
      await transact([{ account: CONTRACT, name: 'setgenconfig', authorization: [who], data }])
      setDraft(null); settle(`Config no. ${fields?.indexed ? draft.index : '0'} saved.`)
    } catch (e) { setStatus({ state: 'error', message: friendlyError(e) }) }
  }
  const remove = async (row: GenRow) => {
    if (!fields?.canDelete) return
    const who = signer(); if (!who) { setStatus({ state: 'error', message: 'Sign in with a wallet first.' }); return }
    setStatus({ state: 'busy', what: 'Waiting for your wallet…' })
    try {
      await transact([{ account: CONTRACT, name: 'delgencfg', authorization: [who], data: { wallet: who.actor, index: row.index } }])
      if (draft?.index === row.index) setDraft(null)
      settle(`Config no. ${row.index} deleted.`)
    } catch (e) { setStatus({ state: 'error', message: friendlyError(e) }) }
  }

  const exists = !!draft && !!rows?.some((r) => r.index === draft.index)
  // the deployed contract without numbered configs can only save no. 0
  const cannotSave = !!draft && fields?.indexed === false && draft.index !== '0'
  const busy = status.state === 'busy'
  const groups = [...new Set(GEN_FIELDS.map((f) => f.group))]

  return (
    <section className="admin-section">
      <div className="admin-h">
        <h1>Generator configs</h1>
        <button type="button" className="btn small" disabled={busy || rows === null} onClick={() => startNew(null)}>new config</button>
      </div>
      <p className="admin-lede">How new islands are charted (land.acre, table genconfig). Charting picks one of these; islands already charted never change.</p>
      {fields && !fields.indexed && <p className="admin-note">The deployed contract keeps a single config (no. 0): saving overwrites it. Numbered configs, and deleting one, come with the contract’s update (setgenconfig with an index, and delgencfg).</p>}

      {readError && <p className="admin-error" role="alert">Could not read the configs: {readError}</p>}
      {rows === null && !readError && <p className="hand">Reading the configs…</p>}
      {rows && rows.length === 0 && <p className="hand">No generator configs yet.</p>}
      {rows && rows.length > 0 && (
        <ul className="gen-list">
          {rows.map((r) => (
            <li key={r.index} className={draft?.index === r.index ? 'is-open' : ''}>
              <span className="gen-no">no. {r.index}</span>
              <span className="gen-sum">{r.width} × {r.height} · land {r.land_min}–{r.land_max}% · {r.ponds_min}–{r.ponds_max} ponds · hills {r.mountain_chance}% · forest {r.forests ? `${r.forest_min}–${r.forest_max}%` : 'none'}</span>
              <span className="gen-acts">
                <button type="button" className="build-link" disabled={busy} onClick={() => edit(r)}>edit</button>
                <button type="button" className="build-link" disabled={busy} onClick={() => startNew(r)}>copy</button>
                <button type="button" className="build-link danger" disabled={busy || !fields?.canDelete} title={fields?.canDelete ? undefined : 'needs the contract’s update (delgencfg)'} onClick={() => remove(r)}>delete</button>
              </span>
            </li>
          ))}
        </ul>
      )}

      {status.state === 'busy' && <p className="admin-note" role="status">{status.what}</p>}
      {status.state === 'done' && <p className="admin-done" role="status">{status.message}</p>}
      {status.state === 'error' && !draft && <p className="admin-error" role="alert">{status.message}</p>}

      {draft && (
        <form className="gen-edit" onSubmit={(e) => { e.preventDefault(); save() }}>
          <div className="admin-h">
            <h2>{exists ? `Changing config no. ${draft.index}` : draft.copiedFrom !== null ? `A new config, copied from no. ${draft.copiedFrom}` : 'A new config'}</h2>
            <label className="gen-index">
              <span>config no.</span>
              <input type="number" min={0} step={1} value={draft.index} onChange={(e) => setDraft({ ...draft, index: e.target.value.replace(/\D/g, '') || '0' })} />
            </label>
          </div>
          {exists && draft.copiedFrom !== null && <p className="admin-note">Config no. {draft.index} already exists: saving overwrites it.</p>}
          {cannotSave && <p className="admin-note">The deployed contract keeps only config no. 0, so no. {draft.index} cannot be saved yet: that needs the contract’s update (setgenconfig with an index). Set the number to 0 to overwrite config no. 0 with these settings instead.</p>}
          {groups.map((g) => (
            <fieldset key={g}>
              <legend>{g}</legend>
              <div className="gen-grid">
                {GEN_FIELDS.filter((f) => f.group === g).map((f) => (
                  <label key={f.name} className={f.kind === 'bool' ? 'gen-bool' : ''} title={f.hint}>
                    {f.kind === 'bool' ? (
                      <><input type="checkbox" checked={!!draft.values[f.name]} onChange={(e) => setDraft({ ...draft, values: { ...draft.values, [f.name]: e.target.checked } })} /><span>{f.label}</span></>
                    ) : (
                      <><span>{f.label}</span><input type="number" min={0} max={f.max} step={1} value={Number(draft.values[f.name])} onChange={(e) => setDraft({ ...draft, values: { ...draft.values, [f.name]: Number(e.target.value) } })} /></>
                    )}
                    <small>{f.hint}</small>
                  </label>
                ))}
              </div>
            </fieldset>
          ))}
          {status.state === 'error' && <p className="admin-error" role="alert">{status.message}</p>}
          <div className="gen-foot">
            <button type="submit" className="btn" disabled={busy || cannotSave}>{busy ? 'Waiting for your wallet…' : exists ? `save config no. ${draft.index}` : `add config no. ${draft.index}`}</button>
            <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft(null); setStatus({ state: 'idle' }) }}>cancel</button>
          </div>
        </form>
      )}
    </section>
  )
}

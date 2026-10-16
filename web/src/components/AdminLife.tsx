import { useCallback, useEffect, useMemo, useState } from 'react'

import { fetchSpeciesRows, SPECIES_DEFAULTS, SPECIES_FIELDS, speciesProblem, type SpeciesRow } from '@/chain/admin'
import { LIFE_CONTRACT } from '@/chain/config'
import { actionFields, contractActions, contractTables, readTable } from '@/chain/rpc'
import { BEASTS, speciesKey } from '@/engine/creatures'
import { friendlyError, signer, transact } from '@/wallet/session'

/** Where a species can live (life.acre species environments), with what each means on the island. */
const ENVIRONMENTS: [string, string][] = [['pond', 'fresh water'], ['sea', 'the ocean'], ['land', 'grass and the hills'], ['beach', 'sand']]

type Draft = { id: string; values: Record<string, number | string>; copiedFrom: string | null; environments: string[] }
type Status = { state: 'idle' } | { state: 'busy'; what: string } | { state: 'error'; message: string } | { state: 'done'; message: string }

/** The names a species can have so that the island has a picture for it. */
const PICTURES = BEASTS.map(([key, home]) => ({ name: key.split('__')[1].replace(/-polished$/, '').replace(/-/g, ' '), home }))

/** Seconds, said the way people count them. */
const span = (s: number) => (s >= 86400 && s % 3600 === 0 ? `${+(s / 86400).toFixed(2)} days` : s >= 3600 ? `${+(s / 3600).toFixed(2)} h` : s >= 60 ? `${+(s / 60).toFixed(1)} min` : `${s} s`)

/** Life › Species: the list, and an editor to add one (empty or copied from another) or change one. */
export function AdminSpecies() {
  const [rows, setRows] = useState<SpeciesRow[] | null>(null)
  const [readError, setReadError] = useState<string | null>(null)
  const [draft, setDraft] = useState<Draft | null>(null)
  const [status, setStatus] = useState<Status>({ state: 'idle' })

  // whether the deployed setspecies takes environments (it came with the contract's update)
  const [withEnv, setWithEnv] = useState<boolean | null>(null)
  useEffect(() => { actionFields('setspecies', LIFE_CONTRACT).then((f) => setWithEnv(f.includes('environments'))) }, [])
  const load = () => fetchSpeciesRows().then((r) => { setRows(r); setReadError(null) }, (e) => setReadError(friendlyError(e)))
  useEffect(() => { load() }, [])

  const nextId = useMemo(() => String(rows && rows.length ? Math.max(...rows.map((r) => Number(r.species_id))) + 1 : 0), [rows])
  const valuesOf = (r: SpeciesRow) => Object.fromEntries(SPECIES_FIELDS.map((f) => [f.name, r[f.name] as number | string]))
  const startNew = (from: SpeciesRow | null) => { setDraft({ id: nextId, values: from ? valuesOf(from) : { ...SPECIES_DEFAULTS }, copiedFrom: from ? from.species_id : null, environments: from ? [...from.environments] : [] }); setStatus({ state: 'idle' }) }
  const edit = (r: SpeciesRow) => { setDraft({ id: r.species_id, values: valuesOf(r), copiedFrom: null, environments: r.environments }); setStatus({ state: 'idle' }) }

  // after a change, read the table again once a node has the block
  const settle = (message: string) => { setStatus({ state: 'done', message }); setTimeout(load, 1500); setTimeout(load, 4000) }

  const save = async () => {
    if (!draft) return
    const problem = speciesProblem(draft.values); if (problem) { setStatus({ state: 'error', message: problem }); return }
    const who = signer(); if (!who) { setStatus({ state: 'error', message: 'Sign in with a wallet first.' }); return }
    setStatus({ state: 'busy', what: 'Waiting for your wallet…' })
    try {
      await transact([{ account: LIFE_CONTRACT, name: 'setspecies', authorization: [who], data: { wallet: who.actor, species_id: draft.id, ...draft.values, species_name: String(draft.values.species_name).trim(), ...(withEnv ? { environments: ENVIRONMENTS.map(([e]) => e).filter((e) => draft.environments.includes(e)) } : {}) } }])
      setDraft(null); settle(`Species no. ${draft.id} saved.`)
    } catch (e) { setStatus({ state: 'error', message: friendlyError(e) }) }
  }
  const remove = async (r: SpeciesRow) => {
    const who = signer(); if (!who) { setStatus({ state: 'error', message: 'Sign in with a wallet first.' }); return }
    setStatus({ state: 'busy', what: 'Waiting for your wallet…' })
    try {
      await transact([{ account: LIFE_CONTRACT, name: 'delspecies', authorization: [who], data: { wallet: who.actor, species_id: r.species_id } }])
      if (draft?.id === r.species_id) setDraft(null)
      settle(`Species no. ${r.species_id} deleted.`)
    } catch (e) { setStatus({ state: 'error', message: friendlyError(e) }) }
  }

  const exists = !!draft && !!rows?.some((r) => r.species_id === draft.id)
  const busy = status.state === 'busy'
  const groups = [...new Set(SPECIES_FIELDS.map((f) => f.group))]
  const picture = draft ? speciesKey(String(draft.values.species_name)) : null

  return (
    <section className="admin-section">
      <div className="admin-h">
        <h1>Species</h1>
        <button type="button" className="btn small" disabled={busy || rows === null} onClick={() => startNew(null)}>new species</button>
      </div>
      <p className="admin-lede">The kinds of creature there are (life.acre, table species). A creature is spawned as one of these; creatures already alive keep what they were born with.</p>

      {readError && <p className="admin-error" role="alert">Could not read the species: {readError}</p>}
      {rows === null && !readError && <p className="hand">Reading the species…</p>}
      {rows && rows.length === 0 && <p className="hand">No species yet.</p>}
      {rows && rows.length > 0 && (
        <ul className="gen-list">
          {rows.map((r) => (
            <li key={r.species_id} className={draft?.id === r.species_id ? 'is-open' : ''}>
              <span className="gen-no">no. {r.species_id}</span>
              <span className="gen-sum"><b>{r.species_name}</b>{r.environments.length ? ` (${r.environments.join(', ')})` : ''} · size {r.min_size}–{r.max_size} · mass {r.min_mass}–{r.max_mass} · speed {r.min_speed}–{r.max_speed} · eats {r.food_type || '—'} · breeds every {span(Number(r.breeding_cooldown))}{speciesKey(String(r.species_name)) ? '' : ' · no picture for this name'}</span>
              <span className="gen-acts">
                <button type="button" className="build-link" disabled={busy} onClick={() => edit(r)}>edit</button>
                <button type="button" className="build-link" disabled={busy} onClick={() => startNew(r)}>copy</button>
                <button type="button" className="build-link danger" disabled={busy} onClick={() => remove(r)}>delete</button>
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
            <h2>{exists && draft.copiedFrom === null ? `Changing species no. ${draft.id}` : draft.copiedFrom !== null ? `A new species, copied from no. ${draft.copiedFrom}` : 'A new species'}</h2>
            <label className="gen-index">
              <span>species no.</span>
              <input type="number" min={0} step={1} value={draft.id} onChange={(e) => setDraft({ ...draft, id: e.target.value.replace(/\D/g, '') || '0' })} />
            </label>
          </div>
          {exists && draft.copiedFrom !== null && <p className="admin-note">Species no. {draft.id} already exists: saving overwrites it.</p>}
          {groups.map((g) => (
            <fieldset key={g}>
              <legend>{g}</legend>
              <div className="gen-grid">
                {SPECIES_FIELDS.filter((f) => f.group === g).map((f) => (
                  <label key={f.name} title={f.hint}>
                    <span>{f.label}</span>
                    {f.kind === 'int' ? (
                      <input type="number" min={0} max={f.max} step={1} value={Number(draft.values[f.name])} onChange={(e) => setDraft({ ...draft, values: { ...draft.values, [f.name]: Number(e.target.value) } })} />
                    ) : (
                      <input type="text" list={f.name === 'species_name' ? 'species-pictures' : undefined} maxLength={f.kind === 'name' ? 12 : 64} value={String(draft.values[f.name])}
                        onChange={(e) => setDraft({ ...draft, values: { ...draft.values, [f.name]: f.kind === 'name' ? e.target.value.toLowerCase() : e.target.value } })} />
                    )}
                    <small>
                      {f.hint}
                      {f.name.endsWith('_cooldown') && ` (${span(Number(draft.values[f.name]))})`}
                      {f.name === 'species_name' && String(draft.values.species_name).trim() && (picture ? ` · it has a picture and ${{ air: 'flies', water: 'swims', land: 'walks' }[picture[1]]}` : ' · no picture on the island for this name yet')}
                    </small>
                  </label>
                ))}
              </div>
            </fieldset>
          ))}
          <datalist id="species-pictures">{PICTURES.map((p) => <option key={p.name} value={p.name}>{p.home}</option>)}</datalist>
          <fieldset>
            <legend>where it lives</legend>
            <div className="crop-chips">
              {ENVIRONMENTS.map(([e, what]) => (
                <label key={e} className="gen-bool" title={what}><input type="checkbox" disabled={withEnv === false} checked={draft.environments.includes(e)} onChange={(ev) => setDraft({ ...draft, environments: ev.target.checked ? [...draft.environments, e] : draft.environments.filter((x) => x !== e) })} /><span>{e}</span><small>{what}</small></label>
              ))}
            </div>
            <small>{withEnv === false ? 'the deployed setspecies cannot set this yet (it comes with the life contract’s update)' : draft.environments.length ? 'it keeps to these on the island (one that flies flies anywhere)' : 'none ticked: where its picture belongs'}</small>
          </fieldset>
          {status.state === 'error' && <p className="admin-error" role="alert">{status.message}</p>}
          <div className="gen-foot">
            <button type="submit" className="btn" disabled={busy}>{busy ? 'Waiting for your wallet…' : exists ? `save species no. ${draft.id}` : `add species no. ${draft.id}`}</button>
            <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft(null); setStatus({ state: 'idle' }) }}>cancel</button>
          </div>
        </form>
      )}
    </section>
  )
}

type Count = number | null
const CLEARS: { action: string; title: string; note: string; table: string; danger?: boolean }[] = [
  { action: 'clrspecies', title: 'Every species', note: 'the whole species table: nothing new can be spawned until species are added again; the creatures stay', table: 'species' },
  { action: 'clrcreatures', title: 'Every creature', note: 'the whole creatures table, on every island and of every owner', table: 'creatures', danger: true },
]

/** Life › Clearing: life.acre's clears, each with how many rows are left for it. */
export function AdminLifeClear() {
  const [actions, setActions] = useState<string[] | null>(null)
  const [counts, setCounts] = useState<Record<string, Count | undefined>>({})
  const [status, setStatus] = useState<{ action: string; text: string; error?: boolean } | null>(null)

  const recount = useCallback(async (only?: string) => {
    const known = await contractTables(LIFE_CONTRACT)
    for (const c of CLEARS) {
      if (only && c.action !== only) continue
      setCounts((o) => ({ ...o, [c.action]: undefined }))
      const n: Promise<Count> = known && !known.includes(c.table) ? Promise.resolve(null)
        : readTable<unknown>(c.table, LIFE_CONTRACT, () => true, { code: LIFE_CONTRACT }).then((r) => r.length, () => null)
      n.then((v) => setCounts((o) => ({ ...o, [c.action]: v })))
    }
  }, [])
  useEffect(() => { contractActions(LIFE_CONTRACT).then(setActions); recount() }, [recount])

  const run = async (action: string) => {
    // straight to the wallet: its own signing screen is where it is confirmed
    const who = signer(); if (!who) { setStatus({ action, text: 'Sign in with a wallet first.', error: true }); return }
    setStatus({ action, text: 'Waiting for your wallet…' })
    try {
      await transact([{ account: LIFE_CONTRACT, name: action, authorization: [who], data: { wallet: who.actor } }])
      setStatus({ action, text: 'Cleared.' })
      setTimeout(() => recount(action), 1500); setTimeout(() => recount(action), 4000)
    } catch (e) { setStatus({ action, text: friendlyError(e), error: true }) }
  }

  return (
    <section className="admin-section">
      <div className="admin-h"><h1>Clearing</h1></div>
      <p className="admin-lede">Every clear life.acre has, with what is left for it. Only life.acre’s authorizers may run them.</p>
      <ul className="clr-list">
        {CLEARS.map((c) => {
          const deployed = actions === null ? null : actions.includes(c.action), n = counts[c.action]
          const state = deployed === false ? 'not in the deployed contract' : n === undefined ? 'counting…' : n === null ? 'cannot be read' : n === 0 ? 'already clear' : `${n} row${n === 1 ? '' : 's'} to clear`
          const cls = deployed === false || n === null ? 'is-missing' : n === 0 ? 'is-clear' : n === undefined ? '' : 'is-full'
          return (
            <li key={c.action} className={cls}>
              <span className="clr-what"><b>{c.title}</b> <code>{c.action}</code><small>{c.note}</small></span>
              <span className="clr-state">{state}</span>
              <span className="clr-act">
                <button type="button" className={`btn small${c.danger ? ' danger' : ''}`} disabled={!deployed || !n || status?.text === 'Waiting for your wallet…'} onClick={() => run(c.action)}>clear</button>
                {status?.action === c.action && <small className={status.error ? 'clr-err' : 'clr-ok'} role="status">{status.text}</small>}
              </span>
            </li>
          )
        })}
      </ul>
    </section>
  )
}

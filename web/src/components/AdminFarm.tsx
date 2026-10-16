import { useEffect, useMemo, useState } from 'react'

import { CONTRACT } from '@/chain/config'
import { fetchCropCfg, fetchHarvestCfg, type CropCfg, type HarvestCfg } from '@/chain/farming'
import { fetchHomeClock } from '@/chain/home'
import { contractActions } from '@/chain/rpc'
import { CROPS } from '@/engine/crops'
import { friendlyError, signer, transact } from '@/wallet/session'

type Status = { state: 'idle' } | { state: 'busy' } | { state: 'error'; message: string } | { state: 'done'; message: string }
const WAITING = 'Waiting for your wallet…'
const span = (s: number) => (s >= 86400 && s % 3600 === 0 ? `${+(s / 86400).toFixed(2)} days` : s >= 3600 ? `${+(s / 3600).toFixed(2)} h` : s >= 60 ? `${+(s / 60).toFixed(1)} min` : `${s} s`)

/** Sends one land.acre action straight to the wallet (its signing screen is where it is confirmed). */
function useSend(setStatus: (s: Status) => void, after: () => void) {
  return async (name: string, data: Record<string, unknown>, done: string) => {
    const who = signer(); if (!who) { setStatus({ state: 'error', message: 'Sign in with a wallet first.' }); return false }
    setStatus({ state: 'busy' })
    try {
      await transact([{ account: CONTRACT, name, authorization: [who], data: { wallet: who.actor, ...data } }])
      setStatus({ state: 'done', message: done }); setTimeout(after, 1500); setTimeout(after, 4000); return true
    } catch (e) { setStatus({ state: 'error', message: friendlyError(e) }); return false }
  }
}

type Draft = { id: string; name: string; yield: number; growth: number; seasons: string[]; daytimes: string[]; weathers: string[]; copiedFrom: string | null }

/** Farming › Crops: what can be sown (land.acre cropcfg), with when it may be sown. */
export function AdminCrops() {
  const [rows, setRows] = useState<CropCfg[] | null>(null)
  const [readError, setReadError] = useState<string | null>(null)
  const [actions, setActions] = useState<string[] | null>(null)
  const [names, setNames] = useState<{ seasons: string[]; daytimes: string[]; weathers: string[] }>({ seasons: [], daytimes: [], weathers: [] })
  const [draft, setDraft] = useState<Draft | null>(null)
  const [status, setStatus] = useState<Status>({ state: 'idle' })

  const load = () => fetchCropCfg().then((r) => { setRows(r); setReadError(null) }, (e) => setReadError(friendlyError(e)))
  const send = useSend(setStatus, load)
  useEffect(() => {
    load(); contractActions().then(setActions)
    // the island clock's own names: what a crop's sowing times are picked from
    fetchHomeClock().then((c) => setNames({ seasons: c.seasons, daytimes: c.daytimes, weathers: [...new Set(Object.values(c.weatherNames).flat())].filter(Boolean) }), () => undefined)
  }, [])

  const deployed = actions === null ? null : actions.includes('setcropcfg')
  const nextId = useMemo(() => String(rows && rows.length ? Math.max(...rows.map((r) => Number(r.id))) + 1 : 1), [rows])
  const fromRow = (r: CropCfg, copy: boolean): Draft => ({ id: copy ? nextId : r.id, name: r.name, yield: r.yield, growth: r.growth, seasons: [...r.seasons], daytimes: [...r.daytimes], weathers: [...r.weathers], copiedFrom: copy ? r.id : null })
  const exists = !!draft && !!rows?.some((r) => r.id === draft.id)
  const busy = status.state === 'busy'

  const save = async () => {
    if (!draft) return
    if (!draft.name.trim()) { setStatus({ state: 'error', message: 'the crop needs a name' }); return }
    if (!Number.isInteger(draft.yield) || draft.yield < 0) { setStatus({ state: 'error', message: 'yield: a whole number of 0 or more' }); return }
    if (!Number.isInteger(draft.growth) || draft.growth < 1) { setStatus({ state: 'error', message: 'growth time: at least 1 second' }); return }
    const ok = await send('setcropcfg', { crop_id: draft.id, crop_name: draft.name.trim(), yield: draft.yield, growth_time_sec: draft.growth, seasons: draft.seasons, daytimes: draft.daytimes, weathers: draft.weathers }, `Crop no. ${draft.id} saved.`)
    if (ok) setDraft(null)
  }
  const chips = (key: 'seasons' | 'daytimes' | 'weathers', all: string[], word: string) => draft && (
    <fieldset>
      <legend>{word}</legend>
      <div className="crop-chips">
        {[...new Set([...all, ...draft[key]])].map((n) => (
          <label key={n} className="gen-bool"><input type="checkbox" checked={draft[key].includes(n)} onChange={(e) => setDraft({ ...draft, [key]: e.target.checked ? [...draft[key], n] : draft[key].filter((x) => x !== n) })} /><span>{n}</span></label>
        ))}
        {!all.length && <small>reading the island clock…</small>}
      </div>
      <small>{draft[key].length ? `only then` : 'none ticked: any'}</small>
    </fieldset>
  )

  return (
    <section className="admin-section">
      <div className="admin-h">
        <h1>Crops</h1>
        <span>
          <button type="button" className="btn small" disabled={busy || rows === null || !deployed} onClick={() => { setDraft({ id: nextId, name: '', yield: 1, growth: 600, seasons: [], daytimes: [], weathers: [], copiedFrom: null }); setStatus({ state: 'idle' }) }}>new crop</button>{' '}
          <button type="button" className="btn small danger" disabled={busy || !rows?.length || !deployed} onClick={() => send('clrcropcfg', {}, 'Every crop cleared.')}>clear all</button>
        </span>
      </div>
      <p className="admin-lede">What can be sown (land.acre, table cropcfg). The name picks the crop’s picture on the island; a crop may be sown only in the seasons, daytimes and weathers ticked (none ticked: any), as the island clock (home.acre) has them.</p>
      {deployed === false && <p className="admin-note">The deployed contract has no crops yet (setcropcfg, delcropcfg and clrcropcfg come with its update).</p>}
      {readError && <p className="admin-error" role="alert">Could not read the crops: {readError}</p>}
      {rows === null && !readError && <p className="hand">Reading the crops…</p>}
      {rows && rows.length === 0 && <p className="hand">No crops yet.</p>}
      {rows && rows.length > 0 && (
        <ul className="gen-list">
          {rows.map((r) => (
            <li key={r.id} className={draft?.id === r.id ? 'is-open' : ''}>
              <span className="gen-no">no. {r.id}</span>
              <span className="gen-sum"><b>{r.name}</b> · {r.yield} a tile · grows in {span(r.growth)}{r.seasons.length ? ` · ${r.seasons.join(', ')}` : ''}{r.daytimes.length ? ` · ${r.daytimes.join(', ')}` : ''}{r.weathers.length ? ` · ${r.weathers.join(', ')}` : ''}{(CROPS as readonly string[]).includes(r.name) ? '' : ' · no picture for this name'}</span>
              <span className="gen-acts">
                <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft(fromRow(r, false)); setStatus({ state: 'idle' }) }}>edit</button>
                <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft(fromRow(r, true)); setStatus({ state: 'idle' }) }}>copy</button>
                <button type="button" className="build-link danger" disabled={busy || !deployed} onClick={() => send('delcropcfg', { crop_id: r.id }, `Crop no. ${r.id} deleted.`)}>delete</button>
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
          <div className="admin-h">
            <h2>{exists && draft.copiedFrom === null ? `Changing crop no. ${draft.id}` : draft.copiedFrom !== null ? `A new crop, copied from no. ${draft.copiedFrom}` : 'A new crop'}</h2>
            <label className="gen-index"><span>crop no.</span><input type="number" min={0} max={65535} step={1} value={draft.id} onChange={(e) => setDraft({ ...draft, id: e.target.value.replace(/\D/g, '') || '0' })} /></label>
          </div>
          {exists && draft.copiedFrom !== null && <p className="admin-note">Crop no. {draft.id} already exists: saving overwrites it.</p>}
          <fieldset>
            <legend>the crop</legend>
            <div className="gen-grid">
              <label><span>name</span><input type="text" list="crop-pictures" maxLength={64} value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} />
                <small>{draft.name && !(CROPS as readonly string[]).includes(draft.name.trim()) ? 'no picture on the island for this name' : 'picks its picture on the island'}</small></label>
              <label><span>yield</span><input type="number" min={0} step={1} value={draft.yield} onChange={(e) => setDraft({ ...draft, yield: Number(e.target.value) })} /><small>what one tile brings in</small></label>
              <label><span>growth time</span><input type="number" min={1} step={1} value={draft.growth} onChange={(e) => setDraft({ ...draft, growth: Number(e.target.value) })} /><small>seconds from sown to fully grown ({span(draft.growth)})</small></label>
            </div>
          </fieldset>
          <datalist id="crop-pictures">{CROPS.map((c) => <option key={c} value={c} />)}</datalist>
          {chips('seasons', names.seasons, 'sown in these seasons')}
          {chips('daytimes', names.daytimes, 'at these times of day')}
          {chips('weathers', names.weathers, 'in this weather')}
          <div className="gen-foot">
            <button type="submit" className="btn" disabled={busy || !deployed}>{busy ? WAITING : exists ? `save crop no. ${draft.id}` : `add crop no. ${draft.id}`}</button>
            <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft(null); setStatus({ state: 'idle' }) }}>cancel</button>
          </div>
        </form>
      )}
    </section>
  )
}

const HARVEST_FIELDS: { key: keyof HarvestCfg; label: string; hint: string }[] = [
  { key: 'distance_sec', label: 'walking', hint: 'seconds a tile, walked in straight steps (a diagonal step counts 1.414)' },
  { key: 'harvest_sec_field', label: 'harvesting', hint: 'seconds for each tile of the field' },
  { key: 'offload_sec', label: 'offloading', hint: 'seconds at the silo' },
  { key: 'rest_sec', label: 'resting', hint: 'seconds at home before the next job' },
]

/** Farming › Harvest: how long a farmer's round takes (land.acre harvestcfg). */
export function AdminHarvest() {
  const [cfg, setCfg] = useState<HarvestCfg | null | undefined>(undefined)
  const [draft, setDraft] = useState<HarvestCfg>({ harvest_sec_field: 2, distance_sec: 1, offload_sec: 5, rest_sec: 10 })
  const [actions, setActions] = useState<string[] | null>(null)
  const [status, setStatus] = useState<Status>({ state: 'idle' })
  const load = () => fetchHarvestCfg().then((c) => { setCfg(c); if (c) setDraft(c) }, () => setCfg(null))
  const send = useSend(setStatus, load)
  useEffect(() => { load(); contractActions().then(setActions) }, [])
  const deployed = actions === null ? null : actions.includes('setharvcfg')
  const busy = status.state === 'busy'
  const save = () => {
    for (const f of HARVEST_FIELDS) if (!Number.isInteger(draft[f.key]) || draft[f.key] < 0) { setStatus({ state: 'error', message: `${f.label}: a whole number of 0 or more` }); return }
    send('setharvcfg', { ...draft }, 'Saved.')
  }
  return (
    <section className="admin-section">
      <div className="admin-h"><h1>Harvest</h1></div>
      <p className="admin-lede">How long a farmer’s round takes (land.acre, table harvestcfg): from their farmhouse to the field, harvesting it, to the silo nearest the field, offloading (from then on it can be claimed), home, and resting. Only farmhouses joined to the market send farmers, as many as their stage; the island shows them walking at the pace that fits these times.</p>
      {deployed === false && <p className="admin-note">The deployed contract has no harvest settings yet (setharvcfg comes with its update).</p>}
      {cfg === null && deployed && <p className="admin-note">Not set yet: no harvest can start until it is saved.</p>}
      <form className="gen-edit" onSubmit={(e) => { e.preventDefault(); save() }}>
        <div className="gen-grid">
          {HARVEST_FIELDS.map((f) => (
            <label key={f.key}><span>{f.label}</span><input type="number" min={0} step={1} value={draft[f.key]} onChange={(e) => setDraft({ ...draft, [f.key]: Number(e.target.value) })} /><small>{f.hint} · <code>{f.key}</code></small></label>
          ))}
        </div>
        {status.state === 'done' && <p className="admin-done" role="status">{status.message}</p>}
        {status.state === 'error' && <p className="admin-error" role="alert">{status.message}</p>}
        <div className="gen-foot"><button type="submit" className="btn" disabled={busy || !deployed}>{busy ? WAITING : 'save'}</button></div>
      </form>
    </section>
  )
}

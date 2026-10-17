import { useEffect, useMemo, useState } from 'react'

import { CONTRACT } from '@/chain/config'
import { fetchCropCfg, fetchHarvestCfg, type CropCfg, type HarvestCfg, START_SEEDS } from '@/chain/farming'
import { fetchHomeClock } from '@/chain/home'
import { contractActions, scopeNumber, actionFields } from '@/chain/rpc'
import { CROPS } from '@/engine/crops'
import { likedSoil } from '@/engine/cropSoil'
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

type Draft = { id: string; name: string; yield: number; growth: number; seasons: string[]; daytimes: string[]; weathers: string[]; nutrients: number; moisture: number; acidity: number; seedYield: number; labUnlock: boolean; copiedFrom: string | null }

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
  // seeds came with a later update of setcropcfg
  const [withSeeds, setWithSeeds] = useState(false)
  const [withUnlock, setWithUnlock] = useState(false)   // and the lab's unlocks after that
  useEffect(() => { actionFields('setcropcfg').then((fs) => { setWithSeeds(fs.includes('seed_yield')); setWithUnlock(fs.includes('lab_unlock')) }, () => undefined) }, [])
  const nextId = useMemo(() => String(rows && rows.length ? Math.max(...rows.map((r) => Number(r.id))) + 1 : 1), [rows])
  const fromRow = (r: CropCfg, copy: boolean): Draft => ({ id: copy ? nextId : r.id, name: r.name, yield: r.yield, growth: r.growth, seasons: [...r.seasons], daytimes: [...r.daytimes], weathers: [...r.weathers], nutrients: r.prefers?.nutrients ?? 50, moisture: r.prefers?.moisture ?? 50, acidity: r.prefers?.acidity ?? 65, seedYield: r.seedYield, labUnlock: r.labUnlock, copiedFrom: copy ? r.id : null })
  const exists = !!draft && !!rows?.some((r) => r.id === draft.id)
  const busy = status.state === 'busy'

  const save = async () => {
    if (!draft) return
    if (!draft.name.trim()) { setStatus({ state: 'error', message: 'the crop needs a name' }); return }
    if (!Number.isInteger(draft.yield) || draft.yield < 0) { setStatus({ state: 'error', message: 'yield: a whole number of 0 or more' }); return }
    if (!Number.isInteger(draft.growth) || draft.growth < 1) { setStatus({ state: 'error', message: 'growth time: at least 1 second' }); return }
    for (const [v, what, lo, hi] of [[draft.nutrients, 'nutrients', 0, 100], [draft.moisture, 'moisture', 0, 100], [draft.acidity, 'acidity (pH x 10)', 10, 140]] as const)
      if (!Number.isInteger(v) || v < lo || v > hi) { setStatus({ state: 'error', message: `${what}: a whole number from ${lo} to ${hi}` }); return }
    if (!Number.isInteger(draft.seedYield) || draft.seedYield < 0) { setStatus({ state: 'error', message: 'seeds a tile: a whole number of 0 or more' }); return }
    const ok = await send('setcropcfg', { crop_id: draft.id, crop_name: draft.name.trim(), yield: draft.yield, growth_time_sec: draft.growth, seasons: draft.seasons, daytimes: draft.daytimes, weathers: draft.weathers, pref_nutrients: draft.nutrients, pref_moisture: draft.moisture, pref_acidity: draft.acidity, ...(withSeeds ? { seed_yield: draft.seedYield } : {}), ...(withUnlock ? { lab_unlock: draft.labUnlock } : {}) }, `Crop no. ${draft.id} saved.`)
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
          {/* the crop open in the form is saved from up here (form="crop-form"), with no scrolling down for it */}
          {draft && <><button type="submit" form="crop-form" className="btn small" disabled={busy || !deployed}>{busy ? WAITING : exists ? `save crop no. ${draft.id}` : `add crop no. ${draft.id}`}</button>{' '}
            <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft(null); setStatus({ state: 'idle' }) }}>cancel</button>{' '}</>}
          <button type="button" className="btn small" disabled={busy || rows === null || !deployed} onClick={() => { setDraft({ id: nextId, name: '', yield: 100, growth: 600, seasons: [], daytimes: [], weathers: [], nutrients: 50, moisture: 50, acidity: 65, seedYield: 2, labUnlock: false, copiedFrom: null }); setStatus({ state: 'idle' }) }}>new crop</button>{' '}
          <button type="button" className="btn small danger" disabled={busy || !rows?.length || !deployed} onClick={() => send('clrcropcfg', {}, 'Every crop cleared.')}>clear all</button>
        </span>
      </div>
      <p className="admin-lede">What can be sown (land.acre, table cropcfg). The name picks the crop’s picture on the island; a crop may be sown only in the seasons, daytimes and weathers ticked (none ticked: any), as the island clock (home.acre) has them.</p>
      {deployed === false && <p className="admin-note">The deployed contract has no crops yet (setcropcfg, delcropcfg and clrcropcfg come with its update).</p>}
      {readError && <p className="admin-error" role="alert">Could not read the crops: {readError}</p>}
      {readError && /unpack/i.test(readError) && (
        <div className="admin-note">
          <p>The crops on the chain were saved in an older layout (before the soil the crops like best): the contract cannot read them, so it cannot clear them the usual way either. <b>rawclear</b> deletes them without reading them; then add the crops again.</p>
          <button type="button" className="btn small danger" disabled={busy || !actions?.includes('rawclear')} title={actions?.includes('rawclear') ? undefined : 'comes with the contract’s update (rawclear)'} onClick={() => send('rawclear', { table: 'cropcfg', scope: scopeNumber('land.acre') }, 'The old crops are cleared: add them again.')}>clear the old crops</button>
        </div>
      )}
      {rows === null && !readError && <p className="hand">Reading the crops…</p>}
      {rows && rows.length === 0 && <p className="hand">No crops yet.</p>}
      {rows && rows.length > 0 && (
        <ul className="gen-list">
          {rows.map((r) => (
            <li key={r.id} className={draft?.id === r.id ? 'is-open' : ''}>
              <span className="gen-no">no. {r.id}</span>
              <span className="gen-sum"><b>{r.name}</b> · {r.yield} a tile · grows in {span(r.growth)}{withSeeds ? ` · ${r.seedYield} seeds a tile` : ''}{r.labUnlock ? ' · unlocked in the lab' : ''}{r.prefers ? ` · likes nutrients ${r.prefers.nutrients}, moisture ${r.prefers.moisture}, pH ${(r.prefers.acidity / 10).toFixed(1)}` : ''}{r.seasons.length ? ` · ${r.seasons.join(', ')}` : ''}{r.daytimes.length ? ` · ${r.daytimes.join(', ')}` : ''}{r.weathers.length ? ` · ${r.weathers.join(', ')}` : ''}{(CROPS as readonly string[]).includes(r.name) ? '' : ' · no picture for this name'}</span>
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
        <form id="crop-form" className="gen-edit" onSubmit={(e) => { e.preventDefault(); save() }}>
          <div className="admin-h">
            <h2>{exists && draft.copiedFrom === null ? `Changing crop no. ${draft.id}` : draft.copiedFrom !== null ? `A new crop, copied from no. ${draft.copiedFrom}` : 'A new crop'}</h2>
            <label className="gen-index"><span>crop no.</span><input type="number" min={0} max={65535} step={1} value={draft.id} onChange={(e) => setDraft({ ...draft, id: e.target.value.replace(/\D/g, '') || '0' })} /></label>
          </div>
          {exists && draft.copiedFrom !== null && <p className="admin-note">Crop no. {draft.id} already exists: saving overwrites it.</p>}
          <fieldset>
            <legend>the crop</legend>
            {/* the crop is picked by its picture: the name is the picture's (and fills in the soil it likes best) */}
            <div className="crop-icons" role="radiogroup" aria-label="Which crop">
              {CROPS.map((c) => { const taken = rows?.find((r) => r.name === c && r.id !== draft.id)
                return (
                  <button key={c} type="button" role="radio" aria-checked={draft.name === c} className={`crop-icon${taken ? ' is-taken' : ''}`} title={taken ? `${c.replace(/-/g, ' ')}: already crop no. ${taken.id}` : c.replace(/-/g, ' ')}
                    onClick={() => { const liked = likedSoil(c); setDraft({ ...draft, name: c, ...(liked ?? {}) }) }}>
                    <img src={`art/crops/${c}/7-harvest-front.svg?v=1`} alt={c.replace(/-/g, ' ')} loading="lazy" />
                  </button>
                ) })}
            </div>
            <p className="crop-picked">{draft.name ? <><b>{draft.name.replace(/-/g, ' ')}</b>{!(CROPS as readonly string[]).includes(draft.name) && ' · no picture on the island for this name: pick one above'}</> : 'Pick a crop above.'}</p>
            <div className="gen-grid">
              <label><span>yield</span><input type="number" min={0} step={1} value={draft.yield} onChange={(e) => setDraft({ ...draft, yield: Number(e.target.value) })} /><small>what one tile brings in</small></label>
              <label><span>growth time</span><input type="number" min={1} step={1} value={draft.growth} onChange={(e) => setDraft({ ...draft, growth: Number(e.target.value) })} /><small>seconds from sown to fully grown ({span(draft.growth)})</small></label>
              <label><span>seeds a tile</span><input type="number" min={0} step={1} disabled={!withSeeds} value={draft.seedYield} onChange={(e) => setDraft({ ...draft, seedYield: Number(e.target.value) })} /><small>{withSeeds ? 'what one tile brings in when harvested for seeds (0: it cannot be); a tile sown takes one' : 'comes with land.acre’s seeds update'}</small></label>
              <label><span>unlocked</span><select disabled={!withUnlock} value={draft.labUnlock ? 'lab' : 'start'} onChange={(e) => setDraft({ ...draft, labUnlock: e.target.value === 'lab' })}><option value="start">from the start</option><option value="lab">in the research lab</option></select>
                <small>{!withUnlock ? 'comes with land.acre’s unlock update' : draft.labUnlock ? `only once a player unlocks it in the lab, which brings ${START_SEEDS} seeds of it: its price and time are set in Lab › Crops to unlock` : `every player may sow it: ${START_SEEDS} seeds of it come with a player’s first island`}</small></label>
            </div>
          </fieldset>
          <fieldset>
            <legend>the soil it likes best</legend>
            {likedSoil(draft.name) && <small className="crop-liked">Filled in for {draft.name}: change it as you like.</small>}
            <div className="gen-grid">
              <label><span>nutrients (%)</span><input type="number" min={0} max={100} step={1} value={draft.nutrients} onChange={(e) => setDraft({ ...draft, nutrients: Number(e.target.value) })} /><small>0-100% · each point an island is off: 2% less yield (none at 50 off: it cannot be sown there)</small></label>
              <label><span>moisture (%)</span><input type="number" min={0} max={100} step={1} value={draft.moisture} onChange={(e) => setDraft({ ...draft, moisture: Number(e.target.value) })} /><small>0-100% · each point off: it grows 5% longer</small></label>
              <label><span>acidity (pH)</span><input type="number" min={1} max={14} step={0.1} value={draft.acidity / 10} onChange={(e) => setDraft({ ...draft, acidity: Math.round(Number(e.target.value) * 10) })} /><small>pH 1.0-14.0 (kept as {draft.acidity}) · each 0.1 off: 1% less yield, 3% longer growth</small></label>
            </div>
          </fieldset>
          {chips('seasons', names.seasons, 'sown in these seasons')}
          {chips('daytimes', names.daytimes, 'at these times of day')}
          {chips('weathers', names.weathers, 'in this weather')}
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

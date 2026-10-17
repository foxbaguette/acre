import { useEffect, useState } from 'react'

import { fetchCropCfg, START_SEEDS, type CropCfg } from '@/chain/farming'
import { LIFE_CONTRACT } from '@/chain/config'
import { fenText, fetchLabConfig, FEN_DECIMALS, grown, LAB_CONTRACT, NO_LAB_CONFIG, UPGRADES, type CropRes, type LabConfig } from '@/chain/lab'
import { contractActions, contractTables, readTable } from '@/chain/rpc'
import { friendlyError, signer, transact } from '@/wallet/session'

type Status = { state: 'idle' } | { state: 'busy' } | { state: 'error'; message: string } | { state: 'done'; message: string }
const WAITING = 'Waiting for your wallet…'
const span = (s: number) => (s >= 86400 ? `${+(s / 86400).toFixed(2)} days` : s >= 3600 ? `${+(s / 3600).toFixed(2)} h` : s >= 60 ? `${+(s / 60).toFixed(1)} min` : `${s} s`)
const pct = (bp: number) => `${+(bp / 100).toFixed(2)}%`
const fenAsset = (fen: number) => `${fen.toFixed(FEN_DECIMALS)} FEN`

/** Sends one lab.acre action straight to the wallet; reloads after. */
function useLab() {
  const [cfg, setCfg] = useState<LabConfig | null>(null)
  const [actions, setActions] = useState<string[] | null>(null)
  const [status, setStatus] = useState<Status>({ state: 'idle' })
  const load = () => contractTables(LAB_CONTRACT).then((t) => (t && t.includes('upgradecfg') ? fetchLabConfig().then(setCfg) : setCfg(NO_LAB_CONFIG)), () => setCfg(NO_LAB_CONFIG))
  useEffect(() => { load(); contractActions(LAB_CONTRACT).then(setActions, () => setActions([])) }, [])
  const send = async (name: string, data: Record<string, unknown>, done: string) => {
    const who = signer(); if (!who) { setStatus({ state: 'error', message: 'Sign in with a wallet first.' }); return false }
    setStatus({ state: 'busy' })
    try { await transact([{ account: LAB_CONTRACT, name, authorization: [who], data: { wallet: who.actor, ...data } }]); setStatus({ state: 'done', message: done }); setTimeout(load, 1500); setTimeout(load, 4000); return true }
    catch (e) { setStatus({ state: 'error', message: friendlyError(e) }); return false }
  }
  return { cfg, deployed: actions === null ? null : actions.includes('setupgrade'), status, setStatus, send }
}
const StatusLine = ({ status }: { status: Status }) => (<>
  {status.state === 'busy' && <p className="admin-note" role="status">{WAITING}</p>}
  {status.state === 'done' && <p className="admin-done" role="status">{status.message}</p>}
  {status.state === 'error' && <p className="admin-error" role="alert">{status.message}</p>}
</>)
const Missing = ({ deployed }: { deployed: boolean | null }) => (deployed === false ? <p className="admin-note">The research lab’s contract (lab.acre) is not on the chain yet.</p> : null)
/** The first stages of a cost or time, to see how it grows. */
const curve = (start: number, bp: number, show: (v: number) => string) => [0, 1, 2, 4, 9].map((s) => `${s + 1}: ${show(grown(start, bp, s))}`).join(' · ')

type UpDraft = { key: string; name: string; effect: number; maxStages: number; startFen: number; costPct: number; startTime: number; timePct: number }

/** Lab › Upgrades: walking, harvesting, resting. */
export function AdminLabUpgrades() {
  const { cfg, deployed, status, setStatus, send } = useLab()
  const [draft, setDraft] = useState<UpDraft | null>(null)
  const busy = status.state === 'busy'
  const edit = (key: string) => { const c = cfg?.upgrades.find((u) => u.key === key), u = UPGRADES.find((x) => x.key === key)!
    setDraft(c ? { key, name: c.name, effect: c.effectBp / 100, maxStages: c.maxStages, startFen: c.startCost / 10 ** FEN_DECIMALS, costPct: c.costBp / 100, startTime: c.startTime, timePct: c.timeBp / 100 }
      : { key, name: u.word, effect: 5, maxStages: 20, startFen: 10, costPct: 25, startTime: 600, timePct: 20 }); setStatus({ state: 'idle' }) }
  const save = async () => {
    if (!draft) return
    if (!(draft.effect > 0) || !(draft.maxStages >= 1) || !(draft.startFen > 0) || draft.costPct < 0 || draft.startTime < 0 || draft.timePct < 0) { setStatus({ state: 'error', message: 'every number must be more than none (the increases may be none)' }); return }
    if (await send('setupgrade', { upgrade: draft.key, display_name: draft.name, effect_bp: Math.round(draft.effect * 100), max_stages: Math.round(draft.maxStages), start_cost: fenAsset(draft.startFen), cost_increase_bp: Math.round(draft.costPct * 100), start_time_sec: Math.round(draft.startTime), time_increase_bp: Math.round(draft.timePct * 100) }, `${draft.name} saved.`)) setDraft(null)
  }
  return (
    <section className="admin-section">
      <div className="admin-h"><h1>Upgrades</h1></div>
      <p className="admin-lede">What the research lab makes better about a player’s farmers, on all their islands (lab.acre, table upgradecfg). Each stage makes it that much better and costs FEN; the cost and the research time grow by their percent every stage.</p>
      <Missing deployed={deployed} />
      <ul className="gen-list">
        {UPGRADES.map((u) => { const c = cfg?.upgrades.find((x) => x.key === u.key)
          return (
            <li key={u.key} className={draft?.key === u.key ? 'is-open' : ''}>
              <span className="gen-no">{u.key}</span>
              <span className="gen-sum"><b>{c?.name || u.word}</b> · {u.hint}{c ? ` · +${pct(c.effectBp)} a stage, ${c.maxStages} stages (up to +${pct(c.effectBp * c.maxStages)}) · from ${fenText(c.startCost)}, +${pct(c.costBp)} a stage · from ${span(c.startTime)}, +${pct(c.timeBp)}` : ' · not set up: it cannot be researched'}</span>
              <span className="gen-acts">
                <button type="button" className="build-link" disabled={busy || !deployed} onClick={() => edit(u.key)}>{c ? 'edit' : 'set up'}</button>
                {c && <button type="button" className="build-link danger" disabled={busy || !deployed} onClick={() => send('delupgrade', { upgrade: u.key }, `${c.name} deleted.`)}>delete</button>}
              </span>
            </li>
          ) })}
      </ul>
      <StatusLine status={status} />
      {draft && (
        <form className="gen-edit" onSubmit={(e) => { e.preventDefault(); save() }}>
          <div className="admin-h"><h2>{draft.name || draft.key}</h2></div>
          <div className="gen-grid">
            <label><span>shown as</span><input type="text" maxLength={40} value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} /><small>its name for players</small></label>
            <label><span>better a stage (%)</span><input type="number" min={0.01} step={0.01} value={draft.effect} onChange={(e) => setDraft({ ...draft, effect: Number(e.target.value) })} /><small>{draft.key === 'rest' ? 'resting that much shorter' : `${draft.key === 'walk' ? 'walking' : 'harvesting'} that much faster`}</small></label>
            <label><span>stages</span><input type="number" min={1} step={1} value={draft.maxStages} onChange={(e) => setDraft({ ...draft, maxStages: Number(e.target.value) })} /><small>up to +{+(draft.effect * draft.maxStages).toFixed(2)}% in all</small></label>
            <label><span>first stage (FEN)</span><input type="number" min={0.0001} step={0.0001} value={draft.startFen} onChange={(e) => setDraft({ ...draft, startFen: Number(e.target.value) })} /></label>
            <label><span>cost more a stage (%)</span><input type="number" min={0} step={0.01} value={draft.costPct} onChange={(e) => setDraft({ ...draft, costPct: Number(e.target.value) })} /><small>{curve(Math.round(draft.startFen * 10 ** FEN_DECIMALS), Math.round(draft.costPct * 100), fenText)}</small></label>
            <label><span>first stage takes (s)</span><input type="number" min={0} step={1} value={draft.startTime} onChange={(e) => setDraft({ ...draft, startTime: Number(e.target.value) })} /><small>{span(draft.startTime)}</small></label>
            <label><span>longer a stage (%)</span><input type="number" min={0} step={0.01} value={draft.timePct} onChange={(e) => setDraft({ ...draft, timePct: Number(e.target.value) })} /><small>{curve(draft.startTime, Math.round(draft.timePct * 100), span)}</small></label>
          </div>
          <div className="gen-foot">
            <button type="submit" className="btn" disabled={busy || !deployed}>{busy ? WAITING : 'save'}</button>
            <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft(null); setStatus({ state: 'idle' }) }}>cancel</button>
          </div>
        </form>
      )}
    </section>
  )
}

type Track = CropRes['track']
type CropDraft = { cropId: string; track: Track; effect: number; maxStages: number; startCost: number; costPct: number; startTime: number; timePct: number; editing: boolean }
const TRACKS: { key: Track; word: string; hint: string }[] = [
  { key: 'yield', word: 'yield', hint: 'every stage +2% yield, up to 100 stages (300% in all)' },
  { key: 'growth', word: 'growth', hint: 'every stage grows that much faster, up to its stages' },
]

/** Lab › Crops: each crop's research, two tracks (yield, growth), paid with the crop. */
export function AdminLabCrops() {
  const { cfg, deployed, status, setStatus, send } = useLab()
  const [crops, setCrops] = useState<CropCfg[]>([])
  const [draft, setDraft] = useState<CropDraft | null>(null)
  useEffect(() => { fetchCropCfg().then(setCrops, () => setCrops([])) }, [])
  const busy = status.state === 'busy', nameOf = (id: string) => crops.find((c) => c.id === id)?.name ?? `crop no. ${id}`
  const has = (id: string, t: Track) => !!cfg?.crops.some((r) => r.cropId === id && r.track === t)
  // the crop and track pairs not set up yet
  const free = crops.flatMap((c) => TRACKS.filter((t) => !has(c.id, t.key)).map((t) => ({ cropId: c.id, track: t.key })))
  const fresh = (cropId: string, track: Track): CropDraft => ({ cropId, track, effect: track === 'growth' ? 3 : 2, maxStages: track === 'growth' ? 30 : 100, startCost: 20, costPct: 12, startTime: 900, timePct: 10, editing: false })
  const fromRow = (r: CropRes, copyTo?: { cropId: string; track: Track }): CropDraft => ({ cropId: copyTo?.cropId ?? r.cropId, track: copyTo?.track ?? r.track, effect: r.effectBp / 100, maxStages: r.maxStages, startCost: r.startCost, costPct: r.costBp / 100, startTime: r.startTime, timePct: r.timeBp / 100, editing: !copyTo })
  const save = async () => {
    if (!draft) return
    if (!(draft.startCost >= 1) || draft.costPct < 0 || draft.startTime < 0 || draft.timePct < 0) { setStatus({ state: 'error', message: 'the first stage costs at least 1; the rest may be none' }); return }
    if (draft.track === 'growth' && (!(draft.effect > 0) || !(draft.maxStages >= 1))) { setStatus({ state: 'error', message: 'growth: faster a stage and stages must be more than none' }); return }
    if (await send('setcropres', { crop_id: draft.cropId, track: draft.track, effect_bp: Math.round(draft.effect * 100), max_stages: Math.round(draft.maxStages), start_cost: Math.round(draft.startCost), cost_increase_bp: Math.round(draft.costPct * 100), start_time_sec: Math.round(draft.startTime), time_increase_bp: Math.round(draft.timePct * 100) }, `${nameOf(draft.cropId)}’s ${draft.track} saved.`)) setDraft(null)
  }
  const pickFree = (v: string) => { const [cropId, track] = v.split('|'); setDraft(draft && { ...fresh(cropId, track as Track), ...{ startCost: draft.startCost, costPct: draft.costPct, startTime: draft.startTime, timePct: draft.timePct } }) }
  const rows = [...(cfg?.crops ?? [])].sort((p, q) => Number(p.cropId) - Number(q.cropId) || p.track.localeCompare(q.track))
  return (
    <section className="admin-section">
      <div className="admin-h">
        <h1>Crop research</h1>
        <button type="button" className="btn small" disabled={busy || !deployed || !free.length} onClick={() => { setDraft(fresh(free[0].cropId, free[0].track)); setStatus({ state: 'idle' }) }}>add research</button>
      </div>
      <p className="admin-lede">Each crop’s research (lab.acre, table cropres), in two tracks, both paid with the crop itself out of an island’s storage: its <b>yield</b> (+2% a stage, up to 100 stages: 300% in all) and how fast it <b>grows</b> (as much faster a stage as set: growth time ÷ (1 + the total)). The cost and the research time grow by their percent every stage.</p>
      <Missing deployed={deployed} />
      {cfg && rows.length === 0 && <p className="hand">No crop can be researched yet.</p>}
      {rows.length > 0 && (
        <ul className="gen-list">
          {rows.map((r) => (
            <li key={r.cropId + r.track} className={draft?.editing && draft.cropId === r.cropId && draft.track === r.track ? 'is-open' : ''}>
              <span className="gen-no">{r.track}</span>
              <span className="gen-sum"><b>{nameOf(r.cropId).replace(/-/g, ' ')}</b> · {r.track === 'growth' ? `${pct(r.effectBp)} faster a stage, ${r.maxStages} stages (up to ${pct(r.effectBp * r.maxStages)})` : '+2% a stage, 100 stages'} · from {r.startCost}, +{pct(r.costBp)} a stage (last stage: {grown(r.startCost, r.costBp, r.maxStages - 1)}) · from {span(r.startTime)}, +{pct(r.timeBp)}</span>
              <span className="gen-acts">
                <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft(fromRow(r)); setStatus({ state: 'idle' }) }}>edit</button>
                <button type="button" className="build-link" disabled={busy || !free.length} onClick={() => { setDraft(fromRow(r, free[0])); setStatus({ state: 'idle' }) }}>copy</button>
                <button type="button" className="build-link danger" disabled={busy || !deployed} onClick={() => send('delcropres', { crop_id: r.cropId, track: r.track }, `${nameOf(r.cropId)}’s ${r.track} deleted.`)}>delete</button>
              </span>
            </li>
          ))}
        </ul>
      )}
      <StatusLine status={status} />
      {draft && (
        <form className="gen-edit" onSubmit={(e) => { e.preventDefault(); save() }}>
          <div className="admin-h"><h2>{draft.editing ? `${nameOf(draft.cropId).replace(/-/g, ' ')}’s ${draft.track}` : 'A crop’s research'}</h2></div>
          <div className="gen-grid">
            <label><span>crop and track</span>{draft.editing ? <input type="text" disabled value={`${nameOf(draft.cropId)} · ${draft.track}`} /> : (
              <select value={`${draft.cropId}|${draft.track}`} onChange={(e) => pickFree(e.target.value)}>{free.map((p) => <option key={p.cropId + p.track} value={`${p.cropId}|${p.track}`}>{nameOf(p.cropId)} · {p.track}</option>)}</select>)}
              <small>{TRACKS.find((t) => t.key === draft.track)!.hint}</small></label>
            {draft.track === 'growth' && (<>
              <label><span>faster a stage (%)</span><input type="number" min={0.01} step={0.01} value={draft.effect} onChange={(e) => setDraft({ ...draft, effect: Number(e.target.value) })} /><small>growth time ÷ (1 + the total): +100% halves it</small></label>
              <label><span>stages</span><input type="number" min={1} step={1} value={draft.maxStages} onChange={(e) => setDraft({ ...draft, maxStages: Number(e.target.value) })} /><small>up to {+(draft.effect * draft.maxStages).toFixed(2)}% faster: {Math.round(100 * 100 / (100 + draft.effect * draft.maxStages))}% of the time</small></label>
            </>)}
            <label><span>first stage costs</span><input type="number" min={1} step={1} value={draft.startCost} onChange={(e) => setDraft({ ...draft, startCost: Number(e.target.value) })} /><small>of the crop itself</small></label>
            <label><span>cost more a stage (%)</span><input type="number" min={0} step={0.01} value={draft.costPct} onChange={(e) => setDraft({ ...draft, costPct: Number(e.target.value) })} /><small>{curve(draft.startCost, Math.round(draft.costPct * 100), String)} · last: {grown(draft.startCost, Math.round(draft.costPct * 100), (draft.track === 'growth' ? draft.maxStages : 100) - 1)}</small></label>
            <label><span>first stage takes (s)</span><input type="number" min={0} step={1} value={draft.startTime} onChange={(e) => setDraft({ ...draft, startTime: Number(e.target.value) })} /><small>{span(draft.startTime)}</small></label>
            <label><span>longer a stage (%)</span><input type="number" min={0} step={0.01} value={draft.timePct} onChange={(e) => setDraft({ ...draft, timePct: Number(e.target.value) })} /><small>{curve(draft.startTime, Math.round(draft.timePct * 100), span)}</small></label>
          </div>
          <div className="gen-foot">
            <button type="submit" className="btn" disabled={busy || !deployed}>{busy ? WAITING : 'save'}</button>
            <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft(null); setStatus({ state: 'idle' }) }}>cancel</button>
          </div>
        </form>
      )}
    </section>
  )
}

/** Lab › Species: which species can be unlocked, for how much FEN, taking how long. */
export function AdminLabSpecies() {
  const { cfg, deployed, status, setStatus, send } = useLab()
  const [species, setSpecies] = useState<{ id: string; name: string }[]>([])
  const [draft, setDraft] = useState<{ id: string; fen: number; time: number; editing: boolean } | null>(null)
  useEffect(() => { readTable<{ species_id: number | string; species_name: string }>('species', LIFE_CONTRACT, () => true, { code: LIFE_CONTRACT }).then((r) => setSpecies(r.map((x) => ({ id: String(x.species_id), name: x.species_name }))), () => setSpecies([])) }, [])
  const busy = status.state === 'busy', nameOf = (id: string) => species.find((s) => s.id === id)?.name ?? `species no. ${id}`
  const free = species.filter((s) => !cfg?.species.some((x) => x.speciesId === s.id))
  const save = async () => {
    if (!draft) return
    if (!(draft.fen > 0) || draft.time < 0) { setStatus({ state: 'error', message: 'the price must be more than none' }); return }
    if (await send('setspecies', { species_id: draft.id, price: fenAsset(draft.fen), time_sec: Math.round(draft.time) }, `${nameOf(draft.id)} saved.`)) setDraft(null)
  }
  return (
    <section className="admin-section">
      <div className="admin-h">
        <h1>Species to unlock</h1>
        <button type="button" className="btn small" disabled={busy || !deployed || !free.length} onClick={() => { setDraft({ id: free[0].id, fen: 50, time: 3600, editing: false }); setStatus({ state: 'idle' }) }}>add a species</button>
      </div>
      <p className="admin-lede">The species a player can unlock in the research lab, each for FEN, its research taking a while (lab.acre, table speciescfg). The species themselves are in Life › Species.</p>
      <Missing deployed={deployed} />
      {cfg && cfg.species.length === 0 && <p className="hand">No species can be unlocked yet.</p>}
      {cfg && cfg.species.length > 0 && (
        <ul className="gen-list">
          {cfg.species.map((s) => (
            <li key={s.speciesId} className={draft?.id === s.speciesId ? 'is-open' : ''}>
              <span className="gen-no">no. {s.speciesId}</span>
              <span className="gen-sum"><b>{nameOf(s.speciesId)}</b> · {fenText(s.price)} · takes {span(s.time)}</span>
              <span className="gen-acts">
                <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft({ id: s.speciesId, fen: s.price / 10 ** FEN_DECIMALS, time: s.time, editing: true }); setStatus({ state: 'idle' }) }}>edit</button>
                <button type="button" className="build-link danger" disabled={busy || !deployed} onClick={() => send('delspecies', { species_id: s.speciesId }, `${nameOf(s.speciesId)} deleted.`)}>delete</button>
              </span>
            </li>
          ))}
        </ul>
      )}
      <StatusLine status={status} />
      {draft && (
        <form className="gen-edit" onSubmit={(e) => { e.preventDefault(); save() }}>
          <div className="admin-h"><h2>{draft.editing ? nameOf(draft.id) : 'A species to unlock'}</h2></div>
          <div className="gen-grid">
            <label><span>species</span>{draft.editing ? <input type="text" disabled value={nameOf(draft.id)} /> : (
              <select value={draft.id} onChange={(e) => setDraft({ ...draft, id: e.target.value })}>{free.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}</select>)}<small>from Life › Species</small></label>
            <label><span>price (FEN)</span><input type="number" min={0.0001} step={0.0001} value={draft.fen} onChange={(e) => setDraft({ ...draft, fen: Number(e.target.value) })} /></label>
            <label><span>takes (s)</span><input type="number" min={0} step={1} value={draft.time} onChange={(e) => setDraft({ ...draft, time: Number(e.target.value) })} /><small>{span(draft.time)}</small></label>
          </div>
          <div className="gen-foot">
            <button type="submit" className="btn" disabled={busy || !deployed}>{busy ? WAITING : 'save'}</button>
            <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft(null); setStatus({ state: 'idle' }) }}>cancel</button>
          </div>
        </form>
      )}
    </section>
  )
}

/** Lab › Crops to unlock: the crops land.acre keeps for the lab (Farming › Crops, unlocked in the research lab), each
 *  for FEN, its research taking a while. */
export function AdminLabCropUnlocks() {
  const { cfg, status, setStatus, send } = useLab()
  const [crops, setCrops] = useState<CropCfg[] | null>(null)
  const [can, setCan] = useState<boolean | null>(null)
  const [draft, setDraft] = useState<{ id: string; fen: number; time: number; editing: boolean } | null>(null)
  useEffect(() => { fetchCropCfg().then(setCrops, () => setCrops([])); contractActions(LAB_CONTRACT).then((a) => setCan(a.includes('setcropunl')), () => setCan(false)) }, [])
  const busy = status.state === 'busy', nameOf = (id: string) => crops?.find((c) => c.id === id)?.name.replace(/-/g, ' ') ?? `crop no. ${id}`
  const locked = (crops ?? []).filter((c) => c.labUnlock), priced = cfg?.cropUnlocks ?? []
  const unpriced = locked.filter((c) => !priced.some((p) => p.cropId === c.id))
  const save = async () => {
    if (!draft) return
    if (!(draft.fen > 0) || draft.time < 0) { setStatus({ state: 'error', message: 'the price must be more than none' }); return }
    if (await send('setcropunl', { crop_id: draft.id, price: fenAsset(draft.fen), time_sec: Math.round(draft.time) }, `${nameOf(draft.id)} saved.`)) setDraft(null)
  }
  return (
    <section className="admin-section">
      <div className="admin-h">
        <h1>Crops to unlock</h1>
        <button type="button" className="btn small" disabled={busy || !can || !unpriced.length} onClick={() => { setDraft({ id: unpriced[0].id, fen: 25, time: 1800, editing: false }); setStatus({ state: 'idle' }) }}>price a crop</button>
      </div>
      <p className="admin-lede">The crops set to be unlocked in the research lab (Farming › Crops, “unlocked: in the research lab”), each for FEN, its research taking a while (lab.acre, table cropunlock). Once unlocked, the player may sow it and gets its starting seeds.</p>
      {can === false && <p className="admin-note">The deployed lab.acre cannot unlock crops yet (setcropunl and delcropunl come with its update).</p>}
      {crops && !locked.length && <p className="hand">No crop is set to be unlocked in the lab: every crop is unlocked from the start.</p>}
      {unpriced.length > 0 && <p className="admin-note">Not priced yet, so no player can unlock {unpriced.length === 1 ? 'it' : 'them'}: {unpriced.map((c) => nameOf(c.id)).join(', ')}.</p>}
      {priced.length > 0 && (
        <ul className="gen-list">
          {priced.map((p) => { const crop = crops?.find((c) => c.id === p.cropId)
            return (
            <li key={p.cropId} className={draft?.id === p.cropId ? 'is-open' : ''}>
              <span className="gen-no">no. {p.cropId}</span>
              <span className="gen-sum"><b>{nameOf(p.cropId)}</b> · {fenText(p.price)} · takes {span(p.time)}{crop ? ` · brings ${START_SEEDS} seeds` : ''}{crop && !crop.labUnlock ? ' · unlocked from the start anyway (Farming › Crops)' : ''}{!crop && crops ? ' · no such crop any more' : ''}</span>
              <span className="gen-acts">
                <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft({ id: p.cropId, fen: p.price / 10 ** FEN_DECIMALS, time: p.time, editing: true }); setStatus({ state: 'idle' }) }}>edit</button>
                <button type="button" className="build-link danger" disabled={busy || !can} onClick={() => send('delcropunl', { crop_id: p.cropId }, `${nameOf(p.cropId)} deleted.`)}>delete</button>
              </span>
            </li>
          ) })}
        </ul>
      )}
      <StatusLine status={status} />
      {draft && (
        <form className="gen-edit" onSubmit={(e) => { e.preventDefault(); save() }}>
          <div className="admin-h"><h2>{draft.editing ? nameOf(draft.id) : 'A crop to unlock'}</h2></div>
          <div className="gen-grid">
            <label><span>crop</span>{draft.editing ? <input type="text" disabled value={nameOf(draft.id)} /> : (
              <select value={draft.id} onChange={(e) => setDraft({ ...draft, id: e.target.value })}>{unpriced.map((c) => <option key={c.id} value={c.id}>{nameOf(c.id)}</option>)}</select>)}<small>the crops set to be unlocked in the lab</small></label>
            <label><span>price (FEN)</span><input type="number" min={0.0001} step={0.0001} value={draft.fen} onChange={(e) => setDraft({ ...draft, fen: Number(e.target.value) })} /></label>
            <label><span>takes (s)</span><input type="number" min={0} step={1} value={draft.time} onChange={(e) => setDraft({ ...draft, time: Number(e.target.value) })} /><small>{span(draft.time)}</small></label>
          </div>
          <div className="gen-foot">
            <button type="submit" className="btn" disabled={busy || !can}>{busy ? WAITING : 'save'}</button>
            <button type="button" className="build-link" disabled={busy} onClick={() => { setDraft(null); setStatus({ state: 'idle' }) }}>cancel</button>
          </div>
        </form>
      )}
    </section>
  )
}

/** Lab › Clearing: every player's research (player data), one player's, and the configs. */
export function AdminLabClear() {
  const { cfg, deployed, status, send } = useLab()
  const [players, setPlayers] = useState<string[] | null>(null)
  const [one, setOne] = useState('')
  const load = () => contractTables(LAB_CONTRACT).then((t) => (t && t.includes('players') ? readTable<{ wallet: string }>('players', LAB_CONTRACT, () => true, { code: LAB_CONTRACT }).then((r) => setPlayers(r.map((x) => x.wallet))) : setPlayers([])), () => setPlayers([]))
  useEffect(() => { load() }, [])
  const busy = status.state === 'busy', configs = cfg ? cfg.upgrades.length + cfg.crops.length + cfg.species.length + cfg.cropUnlocks.length : null
  const run = async (name: string, data: Record<string, unknown>, done: string) => { if (await send(name, data, done)) { setTimeout(load, 1500); setTimeout(load, 4000) } }
  return (
    <section className="admin-section">
      <div className="admin-h"><h1>Clearing</h1></div>
      <p className="admin-lede">The research lab’s clears (lab.acre). Player data is what players researched; configs are the settings in the other Lab pages.</p>
      <Missing deployed={deployed} />
      <div className="clr-part">
        <h2 className="clr-part-h">Player data</h2>
        <ul className="clr-list">
          <li className={players?.length ? 'is-full' : 'is-clear'}>
            <span className="clr-what"><b>Every player’s research</b> <code>clrplayers</code><small>every player’s stages, unlocked species and crops, and research under way (the seeds an unlock brought stay)</small>{players && players.length > 0 && <small className="clr-on">{players.join(', ')}</small>}</span>
            <span className="clr-state">{players === null ? 'counting…' : players.length ? `${players.length} player${players.length === 1 ? '' : 's'}` : 'already clear'}</span>
            <span className="clr-act"><button type="button" className="btn small danger" disabled={busy || !deployed || !players?.length} onClick={() => run('clrplayers', {}, 'Every player’s research cleared.')}>clear</button></span>
          </li>
          <li>
            <span className="clr-what"><b>One player’s research</b> <code>clrplayer</code><small>just their stages, unlocked species and crops, and research under way</small></span>
            <span className="clr-state"><input type="text" placeholder="wallet" value={one} maxLength={12} onChange={(e) => setOne(e.target.value.trim().toLowerCase())} /></span>
            <span className="clr-act"><button type="button" className="btn small danger" disabled={busy || !deployed || !one} onClick={() => run('clrplayer', { player: one }, `${one}’s research cleared.`)}>clear</button></span>
          </li>
        </ul>
      </div>
      <div className="clr-part clr-configs">
        <h2 className="clr-part-h">Configs</h2>
        <ul className="clr-list">
          <li className={configs ? 'is-full' : 'is-clear'}>
            <span className="clr-what"><b>The lab’s settings</b> <code>clrconfigs</code><small>the upgrades, the crops’ research, the crops and species to unlock</small></span>
            <span className="clr-state">{configs === null ? 'counting…' : configs ? `${configs} row${configs === 1 ? '' : 's'}` : 'already clear'}</span>
            <span className="clr-act"><button type="button" className="btn small danger" disabled={busy || !deployed || !configs} onClick={() => run('clrconfigs', {}, 'The lab’s settings cleared.')}>clear</button></span>
          </li>
        </ul>
      </div>
      <StatusLine status={status} />
    </section>
  )
}

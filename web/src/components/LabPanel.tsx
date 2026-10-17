import { useEffect, useState } from 'react'

import { START_SEEDS, type CropCfg } from '@/chain/farming'
import { LIFE_CONTRACT } from '@/chain/config'
import { completeResearch, fenText, fetchLabConfig, fetchProgress, grown, hasLab, payFen, researchCrop, UPGRADES, type LabConfig, type Progress } from '@/chain/lab'
import { readTable } from '@/chain/rpc'
import { growthWorked, timeWords, yieldWorked } from '@/chain/effects'
import { friendlyError, signer, transact } from '@/wallet/session'

const cropWord = (c: string) => c.replace(/-/g, ' ')
const span = (s: number) => (s >= 86400 ? `${+(s / 86400).toFixed(1)} days` : s >= 3600 ? `${+(s / 3600).toFixed(1)} h` : s >= 60 ? `${Math.round(s / 60)} min` : `${s} s`)
const left = (ms: number) => { const s = Math.max(0, Math.ceil(ms / 1000)); return s >= 3600 ? `${Math.floor(s / 3600)} h ${Math.ceil((s % 3600) / 60)} min` : s >= 60 ? `${Math.floor(s / 60)} min ${s % 60} s` : `${s} s` }

/** The research lab's card: the research under way, the farmers' upgrades, each crop's yield, the species to unlock.
 *  Research belongs to the signed-in player; crop research is paid from this island's storage. */
export function LabPanel({ mapId, owner, crops, stored, soil, onChanged, onClose }: {
  mapId: string; owner: string | null; crops: CropCfg[] | null; stored: Record<string, number>; soil: { nutrients: number; moisture: number; acidity: number } | null; onChanged: () => void; onClose: () => void
}) {
  const who = signer(), player = who?.actor ?? owner
  const [on, setOn] = useState<boolean | null>(null)
  const [cfg, setCfg] = useState<LabConfig | null>(null)
  const [prog, setProg] = useState<Progress | null>(null)
  const [names, setNames] = useState<Record<string, string>>({})
  const [note, setNote] = useState<string | null>(null)
  const [now, setNow] = useState(Date.now())
  /** the lab's tab: the farmers' upgrades, the crops' research, or what can be unlocked (crops and species) */
  const [tab, setTab] = useState<'farmers' | 'crops' | 'unlocks'>(() => { try { const t = localStorage.getItem('ua-lab-tab'); return t === 'crops' || t === 'unlocks' ? t : 'farmers' } catch { return 'farmers' } })
  const pick = (t: typeof tab) => { setTab(t); try { localStorage.setItem('ua-lab-tab', t) } catch { /* only remembered here */ } }
  useEffect(() => { const t = window.setInterval(() => setNow(Date.now()), 1000); return () => window.clearInterval(t) }, [])

  const load = () => {
    if (!player) return
    fetchProgress(player).then(setProg, (e) => setNote(friendlyError(e)))
  }
  useEffect(() => {
    hasLab().then((yes) => {
      setOn(yes); if (!yes) return
      fetchLabConfig().then(setCfg, (e) => setNote(friendlyError(e)))
      load()
      readTable<{ species_id: number | string; species_name: string }>('species', LIFE_CONTRACT, () => true, { code: LIFE_CONTRACT })
        .then((rows) => setNames(Object.fromEntries(rows.map((r) => [String(r.species_id), r.species_name]))), () => undefined)
    })
  }, [player])   // eslint-disable-line react-hooks/exhaustive-deps

  const busy = note === 'Waiting for your wallet…', canAct = !!who && who.actor === owner
  const research = prog?.research ?? null, under = !!research && research.done > now
  const send = async (actions: ReturnType<typeof completeResearch>[] | ReturnType<typeof payFen>[] | ReturnType<typeof researchCrop>[], done: string) => {
    setNote('Waiting for your wallet…')
    try { await transact(actions); setNote(done); setTimeout(() => { load(); onChanged() }, 2500) } catch (e) { setNote(friendlyError(e)) }
  }
  const what = (r: NonNullable<Progress['research']>) => r.kind === 'upgrade' ? `${UPGRADES.find((u) => u.key === r.key)?.word ?? r.key}, stage ${r.stage}`
    : r.kind === 'crop' || r.kind === 'cropgrow' ? `${cropWord(crops?.find((c) => c.id === r.key)?.name ?? `crop no. ${r.key}`)}’s ${r.kind === 'crop' ? 'yield' : 'growth'}, stage ${r.stage}` : r.kind === 'cropunlock' ? `unlocking ${cropWord(crops?.find((c) => c.id === r.key)?.name ?? `crop no. ${r.key}`)}` : `the ${names[r.key] ?? `species no. ${r.key}`}`

  if (on === false) return (
    <div className="build-card lab-card" role="region" aria-label="The research lab">
      <div className="farm-h"><h2>The research lab</h2><button type="button" className="build-link" onClick={onClose}>done</button></div>
      <p className="build-hint hand">The research lab opens with its contract (lab.acre).</p>
    </div>
  )
  return (
    <div className="build-card lab-card" role="region" aria-label="The research lab">
      <div className="farm-h"><h2>The research lab</h2><button type="button" className="build-link" onClick={onClose}>done</button></div>
      {research ? (() => { const span = Math.max(1, research.done - research.started), pct = Math.min(100, Math.max(0, ((now - research.started) / span) * 100))
        const cropId = research.kind === 'crop' || research.kind === 'cropgrow' || research.kind === 'cropunlock' ? research.key : null, pic = cropId ? crops?.find((c) => c.id === cropId)?.name : null
        return (
          <div className={`lab-now${under ? '' : ' is-done'}`} role="status">
            <span className="lab-now-tag">{under ? 'researching now' : 'research done'}</span>
            <div className="lab-now-main">
              {pic && <img src={`art/crops/${pic}/7-harvest-front.svg?v=1`} alt="" />}
              <span><b>{what(research)}</b><small>{under ? `${left(research.done - now)} left · done ${new Date(research.done).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}` : 'Finish it to make it count.'}</small></span>
              {!under && <button type="button" className="build-confirm" disabled={!canAct || busy} onClick={() => send([completeResearch(who!)], 'Finished.')}>finish</button>}
            </div>
            <div className="lab-progress"><div className="lab-bar" aria-label={`${Math.floor(pct)}% done`}><i style={{ width: `${pct}%` }} /></div><small>{Math.floor(pct)}%</small></div>
            {under && <small className="lab-one">One research at a time: the next can start once this one is finished.</small>}
          </div>
        ) })() : <p className="lab-idle hand">No research under way: pick one below. One runs at a time.</p>}
      {note && <p className="build-hint hand" role="status">{note}</p>}

      <div className="lab-tabs" role="tablist" aria-label="Research">
        {([['farmers', 'Farmers'], ['crops', 'Crops'], ['unlocks', 'Unlocks']] as const).map(([k, w]) => (
          <button key={k} type="button" role="tab" aria-selected={tab === k} className="lab-tab" onClick={() => pick(k)}>{w}</button>
        ))}
      </div>

      {tab === 'farmers' && <ul className="lab-list">
        {UPGRADES.map((u) => { const c = cfg?.upgrades.find((x) => x.key === u.key); if (!c) return null
          const have = prog?.upgrades[u.key] ?? { stage: 0, totalBp: 0 }, full = have.stage >= c.maxStages
          const cost = grown(c.startCost, c.costBp, have.stage), time = grown(c.startTime, c.timeBp, have.stage)
          return (
            <li key={u.key}>
              <span><b>{c.name || u.word}</b><small>{u.hint} · stage {have.stage} of {c.maxStages}{have.totalBp ? ` · ${+(have.totalBp / 100).toFixed(2)}% better` : ''}{full ? '' : ` · next: +${+(c.effectBp / 100).toFixed(2)}%, ${span(time)}`}</small></span>
              {!full && <button type="button" className="build-link" disabled={!canAct || busy || under} onClick={() => send([payFen(who!, cost, `upgrade:${u.key}`)], `Researching ${u.word}.`)}>{fenText(cost)}</button>}
            </li>
          ) })}
        {cfg && !cfg.upgrades.length && <li className="lab-empty">No upgrades set up yet (Admin › Lab).</li>}
      </ul>}

      {tab === 'crops' && <ul className="lab-list">
        {[...new Set((cfg?.crops ?? []).map((r) => r.cropId))].map((id) => {
          const crop = crops?.find((c) => c.id === id), name = crop?.name ?? `crop no. ${id}`, here = stored[id] ?? 0, have = prog?.crops[id] ?? { yield: 0, growth: 0, growthBp: 0 }
          const grows = crop ? growthWorked(crop, soil, prog) : null, yields = crop ? yieldWorked(crop, soil, prog) : null
          return (
            <li key={id} className="lab-crop-row">
              <span className="lab-crop"><img src={`art/crops/${name}/7-harvest-front.svg?v=1`} alt="" loading="lazy" /><span><b>{cropWord(name)}</b>
                <small>on this island: {yields ? `${yields.value} a tile` : '…'} · grows in {grows ? timeWords(grows.value) : '…'} · this island holds {here}</small></span></span>
              {(['yield', 'growth'] as const).map((track) => { const r = cfg?.crops.find((x) => x.cropId === id && x.track === track); if (!r) return null
                const stage = track === 'yield' ? have.yield : have.growth, full = stage >= r.maxStages
                const cost = grown(r.startCost, r.costBp, stage), time = grown(r.startTime, r.timeBp, stage)
                const now = track === 'yield' ? `${100 + 2 * stage}% yield` : have.growthBp ? `${+(have.growthBp / 100).toFixed(2)}% faster` : 'its own pace'
                return (
                  <span key={track} className="lab-track">
                    <small><i>{track}</i> stage {stage} of {r.maxStages} · {now}{full ? '' : ` · next: +${+(r.effectBp / 100).toFixed(2)}%${track === 'growth' ? ' faster' : ''}, ${span(time)}`}</small>
                    {!full && <button type="button" className="build-link" disabled={!canAct || busy || under || here < cost} title={here < cost ? `this island holds ${here} of the ${cost} it needs` : undefined} onClick={() => send([researchCrop(who!, id, track, mapId)], `Researching ${cropWord(name)}’s ${track}.`)}>{cost} {cropWord(name)}</button>}
                  </span>
                ) })}
            </li>
          ) })}
        {cfg && !cfg.crops.length && <li className="lab-empty">No crop research set up yet (Admin › Lab).</li>}
      </ul>}

      {tab === 'unlocks' && (cfg?.cropUnlocks.length ?? 0) > 0 && (<>
      <h3>Crops to unlock</h3>
      <ul className="lab-list">
        {cfg!.cropUnlocks.map((u) => { const crop = crops?.find((c) => c.id === u.cropId); if (crop && !crop.labUnlock) return null
          const name = crop?.name ?? `crop no. ${u.cropId}`, have = prog?.cropsUnlocked.has(u.cropId), now = research?.kind === 'cropunlock' && research.key === u.cropId
          return (
            <li key={u.cropId} className="lab-crop-row">
              <span className="lab-crop"><img src={`art/crops/${name}/7-harvest-front.svg?v=1`} alt="" loading="lazy" /><span><b>{cropWord(name)}</b>
                <small>{have ? 'unlocked: it can be sown' : now ? 'being unlocked' : `takes ${span(u.time)} · then it can be sown, with ${START_SEEDS} seeds to start`}</small></span></span>
              {!have && !now && <button type="button" className="build-link" disabled={!canAct || busy || under} onClick={() => send([payFen(who!, u.price, `crop:${u.cropId}`)], `Unlocking ${cropWord(name)}.`)}>{fenText(u.price)}</button>}
            </li>
          ) })}
      </ul>
      </>)}

      {tab === 'unlocks' && <><h3>Species</h3>
      <ul className="lab-list">
        {(cfg?.species ?? []).map((s) => { const name = names[s.speciesId] ?? `species no. ${s.speciesId}`, have = prog?.species.has(s.speciesId)
          return (
            <li key={s.speciesId}>
              <span><b>{name}</b><small>{have ? 'unlocked' : `takes ${span(s.time)}`}</small></span>
              {!have && <button type="button" className="build-link" disabled={!canAct || busy || under} onClick={() => send([payFen(who!, s.price, `species:${s.speciesId}`)], `Researching the ${name}.`)}>{fenText(s.price)}</button>}
            </li>
          ) })}
        {cfg && !cfg.species.length && <li className="lab-empty">No species to unlock yet (Admin › Lab).</li>}
      </ul></>}
      {!canAct && <p className="rec-foot">Only the island’s owner, signed in, researches here.</p>}
    </div>
  )
}

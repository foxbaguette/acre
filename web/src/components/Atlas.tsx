import { useCallback, useEffect, useMemo, useRef, useState, type CSSProperties } from 'react'

import { fetchIsAuthorizer, fetchIsLifeAuthorizer } from '@/chain/admin'
import { CONTRACT, GEN_CONFIG } from '@/chain/config'
import { actionFields } from '@/chain/rpc'
import { fetchMapTiles, fetchPlayerMaps, mapStats, placeWords, type MapStats, type PlayerMap, fetchGenConfigs, type GenConfig } from '@/chain/maps'
import { friendlyError, signer, transact } from '@/wallet/session'
import { coastlinePath } from '@/lib/outline'
import { ArrowLeft, ArrowRight, Book, type Bookmark, type Spread } from '@/journal/Book'
import { AccountTag, Header } from '@/journal/Header'
import { withAdmin } from '@/lib/adminUrl'

const PER_PAGE = 11
/** How long the pointer (or keyboard focus) rests on an index line before its chart is loaded and drawn. */
const DWELL_MS = 500
const ROMAN = ['i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii', 'ix', 'x']
const ORD = ['first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh', 'eighth', 'ninth', 'tenth', 'eleventh', 'twelfth',
  'thirteenth', 'fourteenth', 'fifteenth', 'sixteenth', 'seventeenth', 'eighteenth', 'nineteenth', 'twentieth']

const islandName = (m: PlayerMap) => m.name || `Island ${m.id}`
/** A random 64-bit seed for createmap, as a decimal string. */
const rollSeed = () => {
  const [hi, lo] = crypto.getRandomValues(new Uint32Array(2))
  return ((BigInt(hi) << 32n) | BigInt(lo)).toString()
}
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))
type Charting = { phase: 'idle' } | { phase: 'signing' } | { phase: 'charting' } | { phase: 'error'; message: string }
const pageOf = (i: number) => 2 * i + 1
const pct = (v: number) => `${Math.round(v * 1000) / 10}%`

// ---------- a map's chart, loaded on demand and kept for the visit ----------

interface Chart {
  state: 'loading' | 'ready' | 'error'
  path?: string
  stats?: MapStats
}
const charts = new Map<string, Chart>()

function useChart(mapId: string | null): Chart | null {
  const [, redraw] = useState(0)
  useEffect(() => {
    if (!mapId || charts.get(mapId)?.state === 'ready' || charts.get(mapId)?.state === 'loading') return
    charts.set(mapId, { state: 'loading' })
    redraw((n) => n + 1)
    fetchMapTiles(mapId).then(
      (tiles) => charts.set(mapId, { state: 'ready', path: coastlinePath(tiles), stats: mapStats(tiles) }),
      () => charts.set(mapId, { state: 'error' })
    ).finally(() => redraw((n) => n + 1))
  }, [mapId])
  // another component may have finished loading this chart meanwhile
  useEffect(() => {
    if (!mapId || charts.get(mapId)?.state !== 'loading') return
    const t = setInterval(() => charts.get(mapId)?.state !== 'loading' && redraw((n) => n + 1), 200)
    return () => clearInterval(t)
  }, [mapId])
  return mapId ? charts.get(mapId) ?? null : null
}

/** A few honest words about an island, from its chart. */
function describe(s: MapStats): string {
  const size = s.land < 0.35 ? 'A small island' : s.land > 0.5 ? 'A broad island' : 'A fair-sized island'
  const parts = ['open meadows']
  parts.push(s.forest / Math.max(s.land, 0.01) > 0.15 ? 'thick woods' : 'scattered woods')
  if (s.mountain > 0.03) parts.push('a snowy mountain')
  else if (s.mountain > 0) parts.push('rocky hills')
  if (s.freshWater > 0.01) parts.push('a lake')
  else if (s.freshWater > 0) parts.push('a few ponds')
  parts.push('sandy shores')
  return `${size}: ${parts.slice(0, -1).join(', ')} and ${parts[parts.length - 1]}.`
}

// ---------- pieces ----------

const Compass = () => (
  <svg className="compass" viewBox="0 0 100 100" fill="none" stroke="currentColor" aria-hidden="true">
    <circle cx="50" cy="50" r="30" strokeWidth="1.5" />
    <circle cx="50" cy="50" r="24" strokeWidth=".8" strokeDasharray="2 3" />
    <path d="M50 8 56 50 50 92 44 50Z" fill="currentColor" fillOpacity=".25" strokeWidth="1.4" />
    <path d="M50 8 56 50H44Z" fill="currentColor" strokeWidth="1" />
    <path d="M8 50 50 45 92 50 50 55Z" strokeWidth="1.2" />
    <text x="50" y="6" fontFamily="IM Fell English SC, serif" fontSize="12" fill="currentColor" stroke="none" textAnchor="middle">N</text>
  </svg>
)

function IslandChart({ chart, name, className, idle }: { chart: Chart | null; name: string; className: string; idle?: string }) {
  return (
    <div className={className}>
      <svg viewBox="-2 -2 104 104" width="100%" height="100%" role="img" aria-label={chart?.path ? `Chart of ${name}, coastline only` : `Chart of ${name}, not drawn yet`}>
        <rect x="-2" y="-2" width="104" height="104" fill="rgba(37,70,127,.07)" />
        <g stroke="rgba(37,70,127,.18)" strokeWidth=".25">
          {[10, 20, 30, 40, 50, 60, 70, 80, 90].map((k) => (
            <path key={k} d={`M${k} -2V102M-2 ${k}H102`} />
          ))}
        </g>
        {chart?.path && (
          <g className="chart-ink">
            <path d={chart.path} fill="none" stroke="rgba(37,70,127,.35)" strokeWidth="3.2" strokeLinejoin="round" />
            <path d={chart.path} fill="#f6eed8" stroke="#2b2721" strokeWidth=".6" strokeLinejoin="round" fillRule="evenodd" />
          </g>
        )}
      </svg>
      {!chart?.path && (
        <div className="pv-empty">
          {chart?.state === 'loading' ? 'charting the coastline…' : chart?.state === 'error' ? 'this chart could not be read, try again in a moment' : idle}
        </div>
      )}
      <Compass />
      <span className="scale">
        one league<i />
      </span>
    </div>
  )
}

// ---------- the page ----------

export function Atlas({ account, wallet, onSignOut, onEnter }: {
  account: string
  wallet: string | null
  onSignOut: () => void
  onEnter: (mapId: string) => void
}) {
  const [maps, setMaps] = useState<PlayerMap[] | null>(null)
  const [authorizer, setAuthorizer] = useState(false)
  useEffect(() => { let live = true; Promise.all([fetchIsAuthorizer(account), fetchIsLifeAuthorizer(account)]).then(([land, life]) => live && setAuthorizer(land || life)); return () => { live = false } }, [account])
  const [error, setError] = useState<string | null>(null)
  const [attempt, setAttempt] = useState(0)
  const [current, setCurrent] = useState('contents-1')
  const [pointed, setPointed] = useState<number | null>(null) // index line under the pointer or focus
  const [sketched, setSketched] = useState<number | null>(null) // the line rested on long enough to load its chart
  const [seed, setSeed] = useState(rollSeed)
  const [charting, setCharting] = useState<Charting>({ phase: 'idle' })
  // the generator configs the contract has, and the one this island is charted with
  const [configs, setConfigs] = useState<GenConfig[] | null>(null)
  const [gen, setGen] = useState(GEN_CONFIG)
  useEffect(() => {
    let live = true
    fetchGenConfigs().then((list) => {
      if (!live) return
      setConfigs(list)
      if (list.length && !list.some((c) => c.index === GEN_CONFIG)) setGen(list[0].index)
    }, () => live && setConfigs([]))
    return () => { live = false }
  }, [])
  const dwell = useRef<ReturnType<typeof setTimeout>>()

  useEffect(() => {
    let live = true
    setMaps(null)
    setError(null)
    fetchPlayerMaps(account).then(
      (m) => {
        if (!live) return
        setMaps(m)
        const start = location.hash.slice(1)
        if (/^(contents-\d+|isle-\d+|new)$/.test(start)) setCurrent(start)
      },
      (e) => live && setError(e instanceof Error ? e.message : String(e))
    )
    return () => {
      live = false
    }
  }, [account, attempt])

  const turn = useCallback((id: string) => {
    setCurrent(id)
    history.replaceState(null, '', `${location.search}#${id}`)
  }, [])

  const point = (i: number) => {
    setPointed(i)
    clearTimeout(dwell.current)
    dwell.current = setTimeout(() => setSketched(i), DWELL_MS)
  }
  const leave = () => clearTimeout(dwell.current)
  useEffect(() => () => clearTimeout(dwell.current), [])

  const list = maps ?? []
  const pages = Math.max(1, Math.ceil((list.length + 1) / PER_PAGE))
  const isleIndex = current.startsWith('isle-') ? Number(current.slice(5)) : null
  const openMap = isleIndex != null ? list[isleIndex] : null
  const previewIndex = pointed ?? (list.length === 1 ? 0 : null)
  const previewMap = previewIndex != null ? list[previewIndex] : null
  const previewChart = useChart(sketched != null && sketched === previewIndex ? list[sketched]?.id ?? null : list.length === 1 ? list[0].id : null)
  const openChart = useChart(openMap?.id ?? null)

  const contentsPage = (p: number) => {
    const id = `contents-${p + 1}`
    const rows = list.slice(p * PER_PAGE, (p + 1) * PER_PAGE)
    const withNew = p === pages - 1
    const roomy = list.length <= 5
    const left = (
      <>
        <div className="leaf-body">
          <div className="entry-meta">
            <span>{account}&rsquo;s islands</span>
            <span>{pages > 1 ? `index, ${ROMAN[p * 2]}` : 'index'}</span>
          </div>
          <div className="contents-h">
            <h2>{p === 0 ? 'Contents' : <>Contents, <em>cont.</em></>}</h2>
            <p>{list.length === 0 ? 'no islands yet' : list.length === 1 ? 'one island, charted' : `${list.length} islands, charted`}</p>
          </div>
          <ol className={`index${roomy ? ' roomy' : ''}`} onMouseLeave={leave}>
            {rows.map((m, k) => {
              const i = p * PER_PAGE + k
              return (
                <li key={m.id}>
                  <a
                    className={`entry${previewIndex === i ? ' is-active' : ''}`}
                    href={`#isle-${i}`}
                    data-turn={`isle-${i}`}
                    onMouseEnter={() => point(i)}
                    onFocus={() => point(i)}
                    onBlur={leave}
                    aria-label={`${islandName(m)}, page ${pageOf(i)}`}
                  >
                    <span className="e-name">{islandName(m)}</span>
                    <span className="e-visit">{m.name ? `map no. ${m.id}` : 'not yet named'}</span>
                    <span className="e-lead" aria-hidden="true" />
                    <span className="e-page">{pageOf(i)}</span>
                  </a>
                </li>
              )
            })}
            {withNew && (
              <li>
                <a className="entry new" href="#new" data-turn="new" aria-describedby="new-hint">
                  <span className="e-name">chart a new island</span>
                  <span className="e-visit" />
                  <span className="e-lead" aria-hidden="true" />
                  <span className="e-page" aria-hidden="true">{pageOf(list.length)}</span>
                </a>
              </li>
            )}
          </ol>
          {withNew && (
            <p className="index-note" id="new-hint">
              <svg viewBox="0 0 34 30" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true">
                <path d="M3 4c2 10 9 18 26 20M22 18c3 2 5 4 7 6-3 1-6 2-8 4" />
              </svg>
              <span>
                {list.length === 0 ? 'Every line of this journal is still waiting.' : list.length === 1 ? 'One island so far. The rest of these lines are waiting.' : 'Plenty of lines left in this journal.'}
                <span className="create-hint">{list.length === 0 ? 'Turn to the blank page to chart your first one.' : 'Turn to the blank page to chart another one.'}</span>
              </span>
            </p>
          )}
        </div>
        <div className="folio">
          <span>{ROMAN[p * 2]}</span>
          {p > 0 && (
            <a className="turn-link" href={`#contents-${p}`} data-turn={`contents-${p}`}>
              <ArrowLeft /> contents, {ROMAN[(p - 1) * 2]}
            </a>
          )}
        </div>
      </>
    )
    const onPage = previewIndex != null && previewIndex >= p * PER_PAGE && previewIndex < (p + 1) * PER_PAGE
    const right = (
      <>
        <div className="leaf-body preview">
          {onPage && previewMap ? (
            <>
              <div className="entry-meta">
                <span>fig. {pageOf(previewIndex!)}</span>
                <span>map no. {previewMap.id}</span>
                {previewMap.at && <span title="its place on the world map">at {previewMap.at.x}, {previewMap.at.y}</span>}
              </div>
              <IslandChart chart={previewChart} name={islandName(previewMap)} className="pv-chart" idle="rest on its line a moment to sketch the chart" />
              <div className="pv-cap">
                <span>{islandName(previewMap)}, coastline</span>
                <span>not to scale</span>
              </div>
              <div className="pv-text">
                <h2>{islandName(previewMap)}</h2>
                {previewChart?.stats && <p className="hand">{describe(previewChart.stats)}</p>}
                <a className="link-hand" href={`#isle-${previewIndex}`} data-turn={`isle-${previewIndex}`}>
                  turn to page {pageOf(previewIndex!)} <ArrowRight />
                </a>
              </div>
            </>
          ) : (
            <div className="welcome">
              <p className="kicker">Welcome back</p>
              <h2>Choose a page</h2>
              <p className="lede">Rest on an island in the contents to sketch its chart here, or click it to turn to its page.</p>
              <div className="exlibris">
                <span>
                  from the journal of
                  <br />
                  {account}
                </span>
                <svg aria-hidden="true">
                  <use href="#stamp" />
                </svg>
              </div>
            </div>
          )}
        </div>
        <div className="folio">
          {p < pages - 1 ? (
            <a className="turn-link" href={`#contents-${p + 2}`} data-turn={`contents-${p + 2}`}>
              continued overleaf <ArrowRight />
            </a>
          ) : (
            <span />
          )}
          <span>{ROMAN[p * 2 + 1]}</span>
        </div>
      </>
    )
    return { id, left, right }
  }

  const islandSpread = (i: number): Spread => {
    const m = list[i], name = islandName(m), pg = pageOf(i), contents = `contents-${Math.floor(i / PER_PAGE) + 1}`
    const chart = i === isleIndex ? openChart : null
    const s = chart?.stats
    const rows: [string, number | undefined, string][] = [
      ['land', s?.land, 'var(--moss)'], ['forest', s?.forest, '#3d6a3a'], ['mountain', s?.mountain, 'var(--ink-soft)'],
      ['beach', s?.beach, '#b8892f'], ['fresh water', s?.freshWater, '#2f6f86']
    ]
    return {
      id: `isle-${i}`,
      left: (
        <>
          <div className="leaf-body">
            <div className="entry-meta">
              <span>Page {pg}</span>
              <span>map no. {m.id}</span>
              <span title={`its place on the world map: ${placeWords(m.at)}`}>{m.at ? `at ${m.at.x}, ${m.at.y}` : 'no place yet'}</span>
            </div>
            <span className="roman">{m.name ? `The ${ORD[i] ?? `${i + 1}th`} island` : 'not yet named'}</span>
            <div className="isle-h">
              <h2>{name}</h2>
            </div>
            <IslandChart chart={chart} name={name} className="chart-full" idle="charting the coastline…" />
            <div className="chart-cap">
              <span>fig. {pg} &mdash; the coastline, as charted</span>
              <span>not to scale</span>
            </div>
          </div>
          <div className="folio">
            <span>{pg}</span>
            <a className="turn-link" href={`#${contents}`} data-turn={contents}>
              <ArrowLeft /> back to contents
            </a>
          </div>
        </>
      ),
      right: (
        <>
          <div className="leaf-body">
            <div className="record">
              <h3>Field record</h3>
              <ul className="rec" aria-label="Share of the chart">
                {rows.map(([label, v, c]) => (
                  <li key={label}>
                    <b>{label}</b>
                    <span className="bar" aria-hidden="true">
                      <i style={{ '--v': v == null ? '0%' : `${Math.min(100, v * 100)}%`, '--c': c } as CSSProperties} />
                    </span>
                    <span>{v == null ? '…' : pct(v)}</span>
                  </li>
                ))}
              </ul>
              <p className="rec-foot">Shares of the whole chart, sea included.</p>
            </div>
            <p className="isle-notes hand">{s ? describe(s) : 'Reading the survey…'}</p>
            <div className="enter-row">
              <a
                className="enter"
                href={`?island=${m.id}`}
                onClick={(e) => {
                  e.preventDefault()
                  onEnter(m.id)
                }}
              >
                <span className="wax" aria-hidden="true">
                  <svg>
                    <use href="#stamp-mark" />
                  </svg>
                </span>
                <span className="enter-txt">
                  <b>Enter island</b>
                  <small>step ashore on {name}</small>
                </span>
              </a>
            </div>
          </div>
          <div className="folio">
            {i > 0 ? (
              <a className="turn-link" href={`#isle-${i - 1}`} data-turn={`isle-${i - 1}`}>
                <ArrowLeft /> {islandName(list[i - 1])}
              </a>
            ) : (
              <span />
            )}
            {i < list.length - 1 && (
              <a className="turn-link" href={`#isle-${i + 1}`} data-turn={`isle-${i + 1}`}>
                {islandName(list[i + 1])} <ArrowRight />
              </a>
            )}
            <span>{pg + 1}</span>
          </div>
        </>
      )
    }
  }

  const chartNew = async () => {
    const who = signer()
    if (!who) {
      setCharting({ phase: 'error', message: 'Sign in with a wallet to chart an island.' })
      return
    }
    setCharting({ phase: 'signing' })
    try {
      // the generator config goes along once the contract takes one (createmap with genconfig_id)
      const takesConfig = (await actionFields('createmap')).includes('genconfig_id')
      await transact([{ account: CONTRACT, name: 'createmap', authorization: [who], data: { wallet: who.actor, seed, ...(takesConfig ? { genconfig_id: gen } : {}) } }])
    } catch (err) {
      setCharting({ phase: 'error', message: friendlyError(err) })
      return
    }
    // The map row appears once a node has the block; then turn to the new island's page.
    setCharting({ phase: 'charting' })
    const known = new Set(list.map((m) => m.id))
    for (let k = 0; k < 12; k++) {
      await sleep(1500)
      const fresh = await fetchPlayerMaps(account).catch(() => null)
      const added = fresh?.find((m) => !known.has(m.id))
      if (fresh && added) {
        setMaps(fresh)
        setCharting({ phase: 'idle' })
        setSeed(rollSeed())
        turn(`isle-${fresh.indexOf(added)}`)
        return
      }
    }
    setCharting({ phase: 'error', message: 'The island was charted, but the journal has not caught up yet. Reload the page in a moment.' })
  }

  const newSpread = (): Spread => {
    const pg = pageOf(list.length), busy = charting.phase === 'signing' || charting.phase === 'charting'
    return {
      id: 'new',
      left: (
        <>
          <div className="leaf-body">
            <div className="entry-meta">
              <span>Page {pg}</span>
              <span>a blank page</span>
            </div>
            <span className="roman">the next island</span>
            <div className="isle-h">
              <h2>Chart a new island</h2>
            </div>
            <p className="lede">
              Every island grows from a seed the moment it is charted: its coastline, mountains, forests and lakes come out different every
              time, and the island belongs to your wallet.
            </p>
            <div className="seed-box">
              <span className="seed-lbl">seed</span>
              <span className="seed-no hand">{seed}</span>
              <button type="button" className="seed-roll" onClick={() => setSeed(rollSeed())} disabled={busy}>
                roll another
              </button>
            </div>
            {configs && configs.length > 0 && (
              <fieldset className="gen-cards" disabled={busy}>
                <legend className="seed-lbl">what kind of island</legend>
                {configs.map((c) => (
                  <label key={c.index} className={`gen-card${gen === c.index ? ' is-picked' : ''}`}>
                    <input type="radio" name="genconfig" value={c.index} checked={gen === c.index} onChange={() => setGen(c.index)} />
                    <b>no. {c.index}</b>
                    <span>{c.width} × {c.height} tiles · land {c.land_min}–{c.land_max}%</span>
                    <span>{c.ponds_min}–{c.ponds_max} ponds · lake {c.lake_chance}% · river {c.river_chance}%</span>
                    <span>hills {c.mountain_chance}% · {c.forests ? `forest ${c.forest_min}–${c.forest_max}%` : 'no forest'} · up to {c.islets_max} islets</span>
                  </label>
                ))}
              </fieldset>
            )}
            <p className="index-note">
              <svg viewBox="0 0 34 30" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true">
                <path d="M3 4c2 10 9 18 26 20M22 18c3 2 5 4 7 6-3 1-6 2-8 4" />
              </svg>
              <span>Charting asks your wallet to sign once.</span>
            </p>
          </div>
          <div className="folio">
            <span>{pg}</span>
            <a className="turn-link" href={`#contents-${pages}`} data-turn={`contents-${pages}`}>
              <ArrowLeft /> back to contents
            </a>
          </div>
        </>
      ),
      right: (
        <>
          <div className="leaf-body preview">
            <IslandChart chart={null} name="a new island" className="pv-chart" idle="your new island will be drawn here" />
            <div className="pv-cap">
              <span>fig. {pg} &mdash; still blank</span>
              <span>not to scale</span>
            </div>
            <div className="pv-text">
              <button type="button" className="btn" onClick={chartNew} disabled={busy} aria-busy={busy}>
                {charting.phase === 'signing' ? 'Waiting for your wallet…' : charting.phase === 'charting' ? 'Charting the island…' : 'Chart this island'}
              </button>
              {charting.phase === 'charting' && <p className="hand charting-note">The surveyors are at work. This page turns as soon as the island is on the chart.</p>}
              {charting.phase === 'error' && (
                <p className="charting-error" role="alert">
                  {charting.message}
                </p>
              )}
            </div>
          </div>
          <div className="folio">
            <span />
            <span>{pg + 1}</span>
          </div>
        </>
      )
    }
  }

  const spreads: Spread[] = useMemo(() => {
    const out: Spread[] = []
    for (let p = 0; p < pages; p++) out.push(contentsPage(p))
    for (let i = 0; i < list.length; i++) out.push(islandSpread(i))
    out.push(newSpread())
    return out
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [list, pages, previewIndex, previewChart, openChart, isleIndex, account, seed, charting, configs, gen])

  const bookmarks: Bookmark[] = [
    { id: 'contents-1', label: 'Contents', active: (c) => c.startsWith('contents-') },
    ...(list.length === 1 ? [{ id: 'isle-0', label: islandName(list[0]), className: 'isle-tab' }] : [])
  ]

  return (
    <div className="atlas">
      <Header home="contents-1" right={<div className="top-right">{authorizer && <a className="admin-link hand" href={withAdmin(true)}>admin</a>}<AccountTag account={account} wallet={wallet} onSignOut={onSignOut} /></div>} />
      <main>
        <div className="wrap">
          <h1 className="sr-only">Your islands</h1>
          {error ? (
            <div className="sheet atlas-msg">
              <h2>The journal could not be opened.</h2>
              <p className="lede">{error}</p>
              <button type="button" className="btn" onClick={() => setAttempt((a) => a + 1)}>
                Try again
              </button>
            </div>
          ) : !maps ? (
            <div className="sheet atlas-msg">
              <p className="hand">Opening your journal…</p>
            </div>
          ) : (
            <Book className="atlas-book" spreads={spreads} current={spreads.some((s) => s.id === current) ? current : 'contents-1'} onTurn={turn} bookmarks={bookmarks} />
          )}
        </div>
      </main>
    </div>
  )
}

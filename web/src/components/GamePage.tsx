import { useEffect, useRef, useState, type CSSProperties } from 'react'

import { fetchMapTiles, fetchPlayerMaps, mapStats, type MapStats } from '@/chain/maps'
import { startIsland, type IslandView } from '@/game/renderer'
import { AccountTag } from '@/journal/Header'

type Load = { state: 'reading' } | { state: 'drawing' } | { state: 'ready' } | { state: 'error'; message: string }

const HINT_KEY = 'ua-island-hint-seen'
const seenHint = () => {
  try {
    return localStorage.getItem(HINT_KEY) === '1'
  } catch {
    return false
  }
}

const pct = (v: number) => `${Math.round(v * 1000) / 10}%`

/**
 * The island itself, full screen. The journal only shows up in small pieces around the edges: the island's
 * name tag, who is signed in, zoom, the time of day, the weather and a field-notes card.
 */
export function GamePage({ mapId, account, wallet, onSignOut, onLeave }: {
  mapId: string
  account: string
  wallet: string | null
  onSignOut: () => void
  onLeave: () => void
}) {
  const [load, setLoad] = useState<Load>({ state: 'reading' })
  const [name, setName] = useState(`Island ${mapId}`)
  const [stats, setStats] = useState<MapStats | null>(null)
  const [notesOpen, setNotesOpen] = useState(false)
  const [hint, setHint] = useState(!seenHint())
  const started = useRef<IslandView | null>(null)

  useEffect(() => {
    let live = true
    fetchPlayerMaps(account).then((maps) => {
      const m = maps.find((x) => x.id === mapId)
      if (live && m?.name) setName(m.name)
    }, () => undefined)
    fetchMapTiles(mapId).then(
      (tiles) => {
        if (!live || started.current) return
        setStats(mapStats(tiles))
        setLoad({ state: 'drawing' })
        // let the "sketching" note paint before the first build starts
        setTimeout(() => {
          if (!live || started.current) return
          try {
            started.current = startIsland({ tiles, mapId })
            if (import.meta.env.DEV) (window as unknown as { __island: IslandView }).__island = started.current
            started.current.ready.then(() => live && setLoad({ state: 'ready' }))
          } catch (err) {
            setLoad({ state: 'error', message: err instanceof Error ? err.message : String(err) })
          }
        }, 60)
      },
      (err) => live && setLoad({ state: 'error', message: err instanceof Error ? err.message : String(err) })
    )
    return () => {
      live = false
    }
  }, [account, mapId])

  const closeHint = () => {
    setHint(false)
    try {
      localStorage.setItem(HINT_KEY, '1')
    } catch {
      /* the hint simply shows again next time */
    }
  }

  return (
    <div className="game">
      <h1 className="sr-only">{name}</h1>
      <div className="view" id="view" aria-label={`${name}, seen from above. Drag to look around, scroll or pinch to zoom.`} role="img">
        {/* the scene canvases form one group, so a weather grade is a single filter pass; the weather layer sits above */}
        <div className="scene">
          <canvas className="field" id="field" />
          <canvas className="fx" id="fx" aria-hidden="true" />
          <canvas className="fx" id="live" aria-hidden="true" />
        </div>
        <canvas className="fx" id="weather" aria-hidden="true" />
      </div>

      {/* switches the renderer reads; the game keeps them at these settings */}
      <div hidden aria-hidden="true">
        <input type="checkbox" id="animate" defaultChecked />
        <input type="checkbox" id="creatures" />
        <input type="checkbox" id="natural" defaultChecked />
        <input type="checkbox" id="letters" />
        <div id="legend" />
        <button type="button" id="copyMap" />
        <span id="copied" />
        <select id="chainMap" />
        <button type="button" id="chainRefresh" />
        <span id="chainStatus" />
        <button type="button" id="shuffle" />
      </div>

      {load.state !== 'ready' && (
        <div className="game-veil" role="status">
          <svg className="veil-stamp" aria-hidden="true">
            <use href="#stamp" />
          </svg>
          {load.state === 'error' ? (
            <>
              <p className="hand">This island could not be opened.</p>
              <p className="veil-small">{load.message}</p>
              <button type="button" className="btn small" onClick={onLeave}>
                Back to the journal
              </button>
            </>
          ) : (
            <p className="hand">{load.state === 'reading' ? 'Reading the chart…' : 'Sketching the island…'}</p>
          )}
        </div>
      )}

      {/* ---------- the island's name tag, top left ---------- */}
      <div className="hud hud-tl">
        <div className="isle-tag">
          <svg className="isle-tag-mark" aria-hidden="true">
            <use href="#stamp-mark" />
          </svg>
          <span>
            <small>map no. {mapId}</small>
            <b>{name}</b>
          </span>
        </div>
        <button type="button" className="back-link" onClick={onLeave}>
          <svg width="30" height="16" viewBox="0 0 34 18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true">
            <path d="M32 10C24 7 14 6 3 9M9 3C6.5 5 4.5 7 3 9c2.5 1.3 5 3 7 5" />
          </svg>
          back to the journal
        </button>
        <span className="hud-fps" id="fps" aria-live="off" />
      </div>

      {/* ---------- who is signed in, top right ---------- */}
      <div className="hud hud-tr">
        <AccountTag account={account} wallet={wallet} onSignOut={onSignOut} />
      </div>

      {/* ---------- zoom, right edge ---------- */}
      <div className="hud hud-r" role="group" aria-label="Zoom">
        <button type="button" className="knob" id="zin" aria-label="Zoom in">
          +
        </button>
        <button type="button" className="knob" id="zout" aria-label="Zoom out">
          &minus;
        </button>
        <button type="button" className="knob knob-fit" id="zfit" aria-label="Show the whole map">
          <svg viewBox="0 0 100 100" fill="none" stroke="currentColor" aria-hidden="true">
            <circle cx="50" cy="50" r="34" strokeWidth="5" />
            <path d="M50 10 58 50 50 90 42 50Z" fill="currentColor" fillOpacity=".25" strokeWidth="4" />
            <path d="M50 10 58 50H42Z" fill="currentColor" />
          </svg>
        </button>
      </div>

      {/* ---------- time of day and weather, bottom left ---------- */}
      <div className="hud hud-bl">
        <div className="hud-row" role="group" aria-label="Time of day">
          <span className="hud-label">daytime</span>
          <button type="button" className="wx-tag" data-daytime="morning" aria-pressed="false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
              <path d="M4 16h16M7 16a5 5 0 0 1 10 0M12 4v3M5.5 8.5l2 2M18.5 8.5l-2 2M2 20h20" />
            </svg>
            morning
          </button>
          <button type="button" className="wx-tag" data-daytime="day" aria-pressed="true">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
              <circle cx="12" cy="12" r="4" />
              <path d="M12 2.5v2.5M12 19v2.5M2.5 12H5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M5.3 18.7l1.8-1.8M16.9 7.1l1.8-1.8" />
            </svg>
            day
          </button>
          <button type="button" className="wx-tag" data-daytime="evening" aria-pressed="false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
              <path d="M4 16h16M8 16a4 4 0 0 1 8 0M2 20h20M12 7v3M6 10l1.5 1.5M18 10l-1.5 1.5" />
            </svg>
            evening
          </button>
          <button type="button" className="wx-tag" data-daytime="night" aria-pressed="false">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="M19 14.5A7.5 7.5 0 0 1 9.5 5a7.5 7.5 0 1 0 9.5 9.5z" />
              <path d="M17 3l.6 1.4L19 5l-1.4.6L17 7l-.6-1.4L15 5l1.4-.6z" />
            </svg>
            night
          </button>
        </div>
        <div className="hud-row" role="group" aria-label="Weather">
        <span className="hud-label">weather</span>
        <button type="button" className="wx-tag" data-weather="sun" aria-pressed="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
            <circle cx="12" cy="12" r="4" />
            <path d="M12 2.5v2.5M12 19v2.5M2.5 12H5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M5.3 18.7l1.8-1.8M16.9 7.1l1.8-1.8" />
          </svg>
          sunny
        </button>
        <button type="button" className="wx-tag" data-weather="cloudy" aria-pressed="false">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M7 18a4 4 0 0 1 .5-8 5.5 5.5 0 0 1 10.4 1.6A3.5 3.5 0 0 1 17.5 18z" />
            <path d="M3.5 13.5a3 3 0 0 1 2-5" />
          </svg>
          cloudy
        </button>
        <button type="button" className="wx-tag" data-weather="rain" aria-pressed="false">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
            <path d="M7 15a4 4 0 0 1 .5-8 5.5 5.5 0 0 1 10.4 1.6A3.5 3.5 0 0 1 17.5 15z" />
            <path d="M9 18l-1 3M13 18l-1 3M17 18l-1 3" />
          </svg>
          light rain
        </button>
        <button type="button" className="wx-tag" data-weather="storm" aria-pressed="false">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M7 14a4 4 0 0 1 .5-8 5.5 5.5 0 0 1 10.4 1.6A3.5 3.5 0 0 1 17.5 14z" />
            <path d="M12.5 14l-2.5 4h3l-2 4" />
          </svg>
          storm
        </button>
        </div>
      </div>

      {/* ---------- field notes, bottom right ---------- */}
      <div className="hud hud-br">
        <div className={`notes-card${notesOpen ? ' is-open' : ''}`}>
          <button type="button" className="notes-toggle" aria-expanded={notesOpen} aria-controls="field-notes" onClick={() => setNotesOpen((o) => !o)}>
            <span>Field notes</span>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
              <path d={notesOpen ? 'M6 15l6-6 6 6' : 'M6 9l6 6 6-6'} />
            </svg>
          </button>
          <div id="field-notes" hidden={!notesOpen}>
            {stats ? (
              <ul className="rec">
                {([
                  ['land', stats.land, 'var(--moss)'], ['forest', stats.forest, '#3d6a3a'], ['mountain', stats.mountain, 'var(--ink-soft)'],
                  ['beach', stats.beach, '#b8892f'], ['fresh water', stats.freshWater, '#2f6f86']
                ] as [string, number, string][]).map(([label, v, c]) => (
                  <li key={label}>
                    <b>{label}</b>
                    <span className="bar" aria-hidden="true">
                      <i style={{ '--v': `${Math.min(100, v * 100)}%`, '--c': c } as CSSProperties} />
                    </span>
                    <span>{pct(v)}</span>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="hand">Reading the survey…</p>
            )}
            <p className="rec-foot">Shares of the whole chart, sea included.</p>
          </div>
        </div>
      </div>

      {hint && load.state === 'ready' && (
        <div className="hud hud-hint">
          <p className="hint-note">
            <span className="pin" aria-hidden="true" />
            drag to look around &middot; scroll or pinch to zoom &middot; double-click to look closer
            <button type="button" className="hint-close" onClick={closeHint} aria-label="Dismiss the hint">
              &times;
            </button>
          </p>
        </div>
      )}
    </div>
  )
}

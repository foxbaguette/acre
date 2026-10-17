import { useEffect, useState } from 'react'

import { islandTime, type HomeClock } from '@/chain/home'

/** A small paper clock face with the island's time (home.acre's clock), and which day of the season it is. */
/** The island's clock; clicking it shows or hides the tools needed now and then (onToggle, open). */
export function IslandClock({ clock, season, open, onToggle }: { clock: HomeClock; season: string; open?: boolean; onToggle?: () => void }) {
  const [now, setNow] = useState(Date.now())
  useEffect(() => {
    // redraw exactly when the next island minute begins (a fixed interval beats against the island minute's length)
    const perMin = (clock.daytime * Math.max(1, clock.daytimes.length) * 1000) / (24 * 60)
    let id = 0
    const next = () => { const t = Date.now(); id = window.setTimeout(() => { setNow(Date.now()); next() }, perMin - ((t - clock.start) % perMin) + 4) }
    next()
    return () => clearTimeout(id)
  }, [clock])
  const { h, m, day, days } = islandTime(clock, now)
  const hourA = ((h % 12) + m / 60) * 30, minA = m * 6, hh = String(h).padStart(2, '0'), mm = String(m).padStart(2, '0')
  return (
    <button type="button" className={`isle-clock${open ? ' is-open' : ''}`} aria-expanded={onToggle ? !!open : undefined} onClick={onToggle}
      title={onToggle ? (open ? 'hide the weather and the bestiary' : 'show the weather and the bestiary') : undefined} aria-label={`Island time ${hh}:${mm}, day ${day} of ${season}${onToggle ? (open ? ': hide the weather and the bestiary' : ': show the weather and the bestiary') : ''}`}>
      <svg viewBox="0 0 40 40" aria-hidden="true">
        <circle cx="20" cy="20" r="18" className="face" />
        {Array.from({ length: 12 }, (_, k) => (
          <line key={k} x1="20" y1={k % 3 ? 4.5 : 3.5} x2="20" y2={k % 3 ? 6.5 : 8} transform={`rotate(${k * 30} 20 20)`} className="tick" />
        ))}
        <line x1="20" y1="20" x2="20" y2="10.5" transform={`rotate(${hourA} 20 20)`} className="hand hour" />
        <line x1="20" y1="20" x2="20" y2="6.5" transform={`rotate(${minA} 20 20)`} className="hand min" />
        <circle cx="20" cy="20" r="1.6" className="pin" />
      </svg>
      <span>
        <b>{hh}:{mm}</b>
        <small>day {day} of {days} · {season}</small>
      </span>
      {onToggle && <svg className="isle-clock-more" viewBox="0 0 24 24" aria-hidden="true"><path d="M7 10l5 5 5-5" /></svg>}
    </button>
  )
}

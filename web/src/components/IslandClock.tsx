import { useEffect, useState } from 'react'

import { islandTime, type HomeClock } from '@/chain/home'

/** A small paper clock face with the island's time (home.acre's clock), and which day of the season it is. */
export function IslandClock({ clock, season }: { clock: HomeClock; season: string }) {
  const [now, setNow] = useState(Date.now())
  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), 500)   // an island minute is under a second
    return () => clearInterval(id)
  }, [])
  const { h, m, day, days } = islandTime(clock, now)
  const hourA = ((h % 12) + m / 60) * 30, minA = m * 6, hh = String(h).padStart(2, '0'), mm = String(m).padStart(2, '0')
  return (
    <div className="isle-clock" role="timer" aria-label={`Island time ${hh}:${mm}, day ${day} of ${season}`}>
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
    </div>
  )
}

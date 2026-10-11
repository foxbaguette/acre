import { useEffect, useState, type CSSProperties } from 'react'

import type { Creature } from '@/chain/life'
import { recolouredArt } from '@/lib/recolour'

/** A stat against the species' standard (1000): the bar is full at double, the tick marks the standard. */
function Stat({ label, value }: { label: string; value: number }) {
  const pct = Math.round(value / 10)
  return (
    <li>
      <b>{label}</b>
      <span className="bar stat-bar" aria-hidden="true">
        <i style={{ '--v': `${Math.min(100, value / 20)}%`, '--c': 'var(--moss)' } as CSSProperties} />
      </span>
      <span>{pct}%</span>
    </li>
  )
}

/** Relative luminance (0 dark to 1 light) of a hex colour without '#'. */
function luminance(hex: string): number {
  const [r, g, b] = (hex.match(/../g) ?? ['00', '00', '00']).map((h) => {
    const v = parseInt(h, 16) / 255
    return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4
  })
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

/** How light the creature looks overall: its base colour counts most, its markings least. */
const creatureLightness = (colors: string[]) => [0.4, 0.2, 0.15, 0.1, 0.15].reduce((sum, w, i) => sum + w * luminance(colors[i] ?? '000000'), 0)

const day = (d: Date) => (isNaN(d.getTime()) ? 'unknown' : d.toLocaleDateString(undefined, { day: 'numeric', month: 'long', year: 'numeric' }))

function breeding(ready: Date): string {
  const ms = ready.getTime() - Date.now()
  if (isNaN(ms) || ms <= 0) return 'ready'
  const min = Math.ceil(ms / 60000)
  return min < 60 ? `in ${min} min` : min < 60 * 48 ? `in ${Math.round(min / 60)} h` : `in ${Math.round(min / 1440)} days`
}

/**
 * The notes card for the selected creature: it takes the field notes' place while a creature is selected.
 * Size, speed and mass are shown against the species' standard, 100% (the tick on each bar).
 */
export function CreatureCard({ creature, art, onClose }: { creature: Creature; art: string | null; onClose: () => void }) {
  const c = creature
  const [picture, setPicture] = useState<string | null>(null)
  useEffect(() => {
    let live = true
    setPicture(null)
    if (art) recolouredArt(`/art/topdown/${art}/side.svg`, c.colors).then((url) => live && setPicture(url), () => undefined)
    return () => {
      live = false
    }
  }, [art, c.colors])
  // a light creature would vanish on the paper backdrop, so it gets a dusky one; mid-tones get a faint shadow too
  const light = creatureLightness(c.colors)
  const backdrop = light > 0.42 ? ' dusk' : light > 0.25 ? ' lifted' : ''
  return (
    <section className="creature-card" aria-label={`${c.name}, specimen no. ${c.id}`}>
      <header>
        <span>
          <small>specimen no. {String(c.id)}</small>
          <b>{c.name}</b>
          {c.speciesName !== c.name && <em>{c.speciesName}</em>}
        </span>
        <button type="button" className="hint-close" onClick={onClose} aria-label="Close the creature notes">
          &times;
        </button>
      </header>
      {art && (
        <figure className={'portrait' + backdrop}>
          {picture ? <img src={picture} alt={`${c.name}, seen from the side, in its own colours`} /> : <span className="portrait-wait" aria-hidden="true" />}
        </figure>
      )}
      <ul className="swatches" aria-label="Its five colours">
        {c.colors.map((hex, i) => {
          const rgb = (hex.match(/../g) ?? []).map((h) => parseInt(h, 16)).join(', ')
          return (
            <li key={i} tabIndex={0} aria-label={`Colour ${i + 1}: #${hex.toUpperCase()}, RGB ${rgb}`}>
              <small>#{hex.toUpperCase()}</small>
              <i className={luminance(hex) > 0.7 ? 'pale' : undefined} style={{ background: `#${hex}` }} />
              <span className="rgb" aria-hidden="true">RGB {rgb}</span>
            </li>
          )
        })}
      </ul>
      <ul className="rec">
        <Stat label="size" value={c.size} />
        <Stat label="speed" value={c.speed} />
        <Stat label="mass" value={c.mass} />
      </ul>
      <dl className="facts">
        <dt>sex</dt>
        <dd>{c.sex === 0 ? 'female' : c.sex === 1 ? 'male' : String(c.sex)}</dd>
        <dt>hatched</dt>
        <dd>{day(c.born)}</dd>
        <dt>breeding</dt>
        <dd>{breeding(c.breedReady)}</dd>
      </dl>
    </section>
  )
}

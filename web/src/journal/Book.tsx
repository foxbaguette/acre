import { useCallback, useEffect, useLayoutEffect, useRef, type ReactNode } from 'react'

/** One page side: React content, or imported HTML (the landing chapters). */
export type PageContent = ReactNode | { html: string }

export interface Spread {
  id: string
  left: PageContent
  right: PageContent
}

export interface Bookmark {
  id: string
  label: ReactNode
  /** Which spreads light this bookmark up; defaults to its own id. */
  active?: (current: string) => boolean
  className?: string
}

const isHtml = (c: PageContent): c is { html: string } => typeof c === 'object' && c !== null && 'html' in (c as object)

function Leaf({ content }: { content: PageContent }) {
  return isHtml(content) ? <div className="leaf" dangerouslySetInnerHTML={{ __html: content.html }} /> : <div className="leaf">{content}</div>
}

/**
 * The open journal: two pages, bookmarks on the right page, and a page that turns over the spine when the
 * spread changes. Any element with data-turn="<spread id>" (inside or outside the book) turns to that spread.
 *
 * The turn: before React swaps the content, both visible pages are copied. Then, going forward, the old left
 * page stays on top as a still copy while a leaf (old right page in front, new left page behind) swings over
 * the spine; going back, the mirror image. Phones, reduced motion and hidden tabs just swap.
 */
export function Book({
  spreads,
  current,
  onTurn,
  bookmarks,
  hint,
  className = ''
}: {
  spreads: Spread[]
  current: string
  onTurn: (id: string) => void
  bookmarks: Bookmark[]
  hint?: ReactNode
  className?: string
}) {
  const book = useRef<HTMLDivElement>(null)
  const pending = useRef<{ from: string; l: Node; r: Node } | null>(null)
  const order = spreads.map((s) => s.id)
  const spread = spreads.find((s) => s.id === current) ?? spreads[0]

  const turn = useCallback(
    (id: string) => {
      if (id === current || !order.includes(id) || book.current?.querySelector('.turn')) return
      const el = book.current
      if (el) {
        const l = el.querySelector('.page-l > .leaf'), r = el.querySelector('.page-r > .leaf')
        if (l && r) pending.current = { from: current, l: l.cloneNode(true), r: r.cloneNode(true) }
      }
      onTurn(id)
    },
    [current, onTurn, order]
  )

  // data-turn links anywhere on the page
  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      const a = (e.target as Element).closest?.('[data-turn]') as HTMLElement | null
      if (!a) return
      e.preventDefault()
      turn(a.dataset.turn!)
    }
    document.addEventListener('click', onClick)
    return () => document.removeEventListener('click', onClick)
  }, [turn])

  useLayoutEffect(() => {
    const snap = pending.current
    pending.current = null
    const el = book.current
    if (!snap || !el || snap.from === current) return
    const still = matchMedia('(prefers-reduced-motion: reduce)').matches || matchMedia('(max-width: 980px)').matches || document.hidden
    if (still) {
      if (matchMedia('(max-width: 980px)').matches) el.scrollIntoView({ block: 'start', behavior: 'smooth' })
      return
    }
    const forward = order.indexOf(current) > order.indexOf(snap.from)
    const fresh = (side: 'l' | 'r') => el.querySelector(`.page-${side} > .leaf`)!.cloneNode(true)
    const face = (side: 'l' | 'r', leaf: Node, cls: string) => {
      const f = document.createElement('div')
      f.className = `${cls} page sheet page-${side}`
      f.setAttribute('aria-hidden', 'true')
      ;(leaf as Element).querySelectorAll?.('[id]').forEach((n) => n.removeAttribute('id'))
      f.appendChild(leaf)
      return f
    }
    // the half that has not turned yet keeps showing the old page
    const cover = face(forward ? 'l' : 'r', forward ? snap.l : snap.r, `turn-cover ${forward ? 'is-left' : 'is-right'}`)
    const leaf = document.createElement('div')
    leaf.className = `turn ${forward ? 'turn-fwd' : 'turn-back'}`
    leaf.appendChild(face(forward ? 'r' : 'l', forward ? snap.r : snap.l, 'face front'))
    leaf.appendChild(face(forward ? 'l' : 'r', fresh(forward ? 'l' : 'r'), 'face back'))
    el.append(cover, leaf)
    let done = false
    const land = () => {
      if (done) return
      done = true
      cover.remove()
      leaf.remove()
    }
    // The turn runs on its own: re-renders while it turns (charts loading, hover) must not cut it short.
    leaf.addEventListener('animationend', (e) => e.target === leaf && land())
    setTimeout(land, 1000)
  }, [current, order])

  return (
    <div className={`book ${className}`} ref={book}>
      <nav className="bookmarks" role="tablist" aria-label="Journal sections">
        {bookmarks.map((b) => {
          const on = b.active ? b.active(current) : b.id === current
          return (
            <a
              key={b.id}
              className={`bookmark ${b.className ?? ''}`}
              role="tab"
              href={`#${b.id}`}
              data-turn={b.id}
              aria-selected={on}
              onKeyDown={(e) => {
                const d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0
                if (!d) return
                e.preventDefault()
                const i = bookmarks.indexOf(b), next = bookmarks[(i + d + bookmarks.length) % bookmarks.length]
                turn(next.id)
                ;(e.currentTarget.parentElement?.children[bookmarks.indexOf(next)] as HTMLElement | undefined)?.focus()
              }}
            >
              {b.label}
            </a>
          )
        })}
      </nav>
      {hint && (
        <p className="bookmark-hint" aria-hidden="true">
          {hint}
        </p>
      )}
      <div className="page page-l sheet">
        <Leaf key={`${spread.id}-l`} content={spread.left} />
      </div>
      <div className="page page-r sheet">
        <Leaf key={`${spread.id}-r`} content={spread.right} />
      </div>
    </div>
  )
}

export const ArrowRight = () => (
  <svg width="34" height="18" viewBox="0 0 34 18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true">
    <path d="M2 10c8-3 18-4 29-1M25 3c2.5 2 4.5 4 6 6-2.5 1.3-5 3-7 5" />
  </svg>
)

export const ArrowLeft = () => (
  <svg width="34" height="18" viewBox="0 0 34 18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true">
    <path d="M32 10C24 7 14 6 3 9M9 3C6.5 5 4.5 7 3 9c2.5 1.3 5 3 7 5" />
  </svg>
)

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'

import { Book, ArrowRight, type Bookmark, type Spread } from '@/journal/Book'
import { Header, WalletIcon } from '@/journal/Header'
import { CHAPTERS } from '@/journal/landing'

const STAGE_WORDS: Record<string, string> = {
  '1-seeds-front': 'seeds', '2-sown': 'sown', '3-first-growth': 'first growth', '4-second-growth': 'second growth',
  '5-third-growth': 'third growth', '6-harvest': 'ready', '7-harvest-front': 'harvested', '8-dead': 'wilted'
}

const chapterFromHash = () => {
  const id = location.hash.slice(1)
  return CHAPTERS.some((c) => c.id === id) ? id : CHAPTERS[0].id
}

/** The landing page: the field journal, chapter by chapter, with Connect wallet on its pages. */
export function Landing({ onConnect, busy, error }: { onConnect: () => void; busy: string | null; error: string | null }) {
  const [current, setCurrent] = useState(chapterFromHash)
  const root = useRef<HTMLDivElement>(null)

  const spreads: Spread[] = useMemo(() => CHAPTERS.map((c) => ({ id: c.id, left: { html: c.left }, right: { html: c.right } })), [])
  const bookmarks: Bookmark[] = useMemo(() => CHAPTERS.map((c) => ({ id: c.id, label: c.label })), [])

  const turn = useCallback((id: string) => {
    setCurrent(id)
    history.replaceState(null, '', `#${id}`)
  }, [])

  // Buttons inside the imported pages: Connect wallet, and the crop picker on the crops chapter.
  useEffect(() => {
    const el = root.current
    if (!el) return
    const onClick = (e: MouseEvent) => {
      const target = e.target as Element
      if (target.closest('[data-action="connect"]')) {
        onConnect()
        return
      }
      const tab = target.closest('.tabs [role="tab"][data-crop]') as HTMLElement | null
      if (!tab) return
      const leaf = tab.closest('.leaf')!
      leaf.querySelectorAll('.tabs [role="tab"]').forEach((t) => t.setAttribute('aria-selected', String(t === tab)))
      const name = leaf.querySelector('#plate-name'), note = leaf.querySelector('#plate-note')
      if (name?.firstChild) name.firstChild.nodeValue = `${tab.dataset.name} `
      if (note) note.textContent = tab.dataset.note ?? ''
      leaf.querySelectorAll<HTMLImageElement>('#stage-list img').forEach((img) => {
        img.src = `/art/crops/${tab.dataset.crop}/${img.dataset.stage}.svg`
        img.alt = `${tab.dataset.name}: ${STAGE_WORDS[img.dataset.stage!]}`
      })
    }
    el.addEventListener('click', onClick)
    return () => el.removeEventListener('click', onClick)
  }, [onConnect])

  // While the wallet opens, every Connect button on the open pages waits.
  useEffect(() => {
    root.current?.querySelectorAll<HTMLButtonElement>('[data-action="connect"]').forEach((b) => {
      b.disabled = !!busy
      b.setAttribute('aria-busy', String(!!busy))
    })
  }, [busy, current])

  return (
    <div ref={root}>
      <Header
        home={CHAPTERS[0].id}
        right={
          <button className="btn small" type="button" data-action="connect" disabled={!!busy}>
            <WalletIcon /> {busy ?? 'Connect wallet'}
          </button>
        }
      />
      <main>
        <div className="wrap">
          {error && (
            <p className="journal-notice" role="alert">
              {error}
            </p>
          )}
          <Book
            className="landing-book"
            spreads={spreads}
            current={current}
            onTurn={turn}
            bookmarks={bookmarks}
            hint={
              <>
                pick a bookmark <ArrowRight />
              </>
            }
          />
        </div>
      </main>
      <footer>
        <div className="wrap">
          <a className="brand" href={`#${CHAPTERS[0].id}`} data-turn={CHAPTERS[0].id} aria-label="Unclaimed Acres, back to the first page">
            <svg className="brand-stamp" width="44" height="44" aria-hidden="true">
              <use href="#stamp-mark" />
            </svg>
            <span className="brand-name">Unclaimed Acres</span>
          </a>
          <p style={{ margin: 0 }}>An island farming &amp; creature game. In development; artwork shown is from the game.</p>
        </div>
      </footer>
    </div>
  )
}

import { useCallback, useEffect, useState } from 'react'

import { Atlas } from '@/components/Atlas'
import { GamePage } from '@/components/GamePage'
import { Landing } from '@/components/Landing'
import { JournalDefs } from '@/journal/Header'
import { hasStoredSession, login, logout, preloadWallet, restoreSession, walletName } from '@/wallet/session'

/** Dev only: ?as=account shows that wallet's islands without signing in. */
const spectate = import.meta.env.DEV ? new URLSearchParams(location.search).get('as') : null

const message = (err: unknown) => (err instanceof Error ? err.message : String(err))
const islandParam = () => new URLSearchParams(location.search).get('island')

/** This address with ?island set or removed, keeping anything else (like ?as=). */
function withIsland(id: string | null, hash = '') {
  const p = new URLSearchParams(location.search)
  if (id) p.set('island', id)
  else p.delete('island')
  const q = p.toString()
  return location.pathname + (q ? `?${q}` : '') + hash
}

export function App() {
  const [account, setAccount] = useState<string | null>(spectate)
  const [restoring, setRestoring] = useState(!spectate && hasStoredSession())
  const [busy, setBusy] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [island, setIsland] = useState<string | null>(islandParam)

  useEffect(() => {
    if (!restoring) return
    restoreSession()
      .then((actor) => actor && setAccount(actor))
      .finally(() => setRestoring(false))
  }, [restoring])

  // The island renderer owns the page while it runs, so leaving it (or going back) reloads into the journal.
  useEffect(() => {
    const onPop = () => {
      if (island && islandParam() !== island) location.reload()
    }
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [island])

  const connect = useCallback(async () => {
    setError(null)
    setBusy('Opening wallet…')
    try {
      const actor = await login()
      if (actor) {
        setAccount(actor)
        history.replaceState(null, '', withIsland(null))
      }
    } catch (err) {
      setError(`Sign-in failed: ${message(err)}`)
    } finally {
      setBusy(null)
    }
  }, [])

  const signOut = useCallback(async () => {
    if (spectate) {
      location.assign(location.pathname)
      return
    }
    try {
      await logout()
    } finally {
      if (island) location.assign(location.pathname)
      setAccount(null)
      history.replaceState(null, '', location.pathname)
    }
  }, [island])

  const enter = useCallback((mapId: string) => {
    history.pushState(null, '', withIsland(mapId))
    setIsland(mapId)
  }, [])

  const leave = useCallback(() => {
    location.assign(withIsland(null, '#contents-1'))
  }, [])

  let page
  if (restoring) {
    page = (
      <div className="splash" role="status">
        <svg aria-hidden="true">
          <use href="#stamp" />
        </svg>
        <p>Opening your journal…</p>
      </div>
    )
  } else if (!account) {
    page = (
      <div onPointerEnter={preloadWallet} onFocus={preloadWallet}>
        <Landing onConnect={connect} busy={busy} error={error} />
      </div>
    )
  } else if (island) {
    page = <GamePage mapId={island} account={account} wallet={walletName()} onSignOut={signOut} onLeave={leave} />
  } else {
    page = <Atlas account={account} wallet={walletName()} onSignOut={signOut} onEnter={enter} />
  }

  return (
    <>
      <JournalDefs />
      {page}
    </>
  )
}

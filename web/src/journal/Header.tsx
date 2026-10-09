import type { ReactNode } from 'react'

import { JOURNAL_DEFS } from './landing'

/** The SVG symbols every journal page uses: #stamp, #stamp-mark, #isle. */
export function JournalDefs() {
  return <div hidden dangerouslySetInnerHTML={{ __html: JOURNAL_DEFS }} />
}

/** Stamp logo on the left, `right` (a button or the account tag) on the right. */
export function Header({ home, right }: { home: string; right: ReactNode }) {
  return (
    <header className="top">
      <div className="wrap">
        <a className="brand" href={`#${home}`} data-turn={home} aria-label="Unclaimed Acres, back to the first page">
          <svg className="brand-stamp" width="64" height="64" aria-hidden="true">
            <use href="#stamp-mark" />
          </svg>
          <span className="brand-name">
            Unclaimed Acres<small>a field journal</small>
          </span>
        </a>
        {right}
      </div>
    </header>
  )
}

/** Who is signed in: a paper tag pinned to the page, with Sign out. */
export function AccountTag({ account, wallet, onSignOut }: { account: string; wallet: string | null; onSignOut: () => void }) {
  return (
    <div className="acct" title={wallet ? `Signed in with ${wallet}` : undefined}>
      <svg className="acct-mark" aria-hidden="true">
        <use href="#stamp-mark" />
      </svg>
      <span className="acct-who">
        <small>signed in as</small>
        <b>{account}</b>
      </span>
      <button type="button" className="acct-out" onClick={onSignOut}>
        Sign out
      </button>
    </div>
  )
}

export function WalletIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
      <rect x="3" y="6" width="18" height="13" rx="2" />
      <path d="M16 12.5h2M3 9h14a2 2 0 0 0 2-2V5" />
    </svg>
  )
}

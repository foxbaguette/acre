import type { AnyAction, Session, SessionKit } from '@wharfkit/session'

import { APP_NAME, CHAIN_ID, RPC_NODES } from '@/chain/config'

let kit: Promise<SessionKit> | null = null
let current: Session | undefined

/** Where WharfKit's BrowserLocalStorage (no key prefix) keeps the last session. */
const STORED_SESSION_KEY = 'wharf--session'

/** Set while the wallet picker is open; called when the player closes it. */
let onPickerClosed: (() => void) | null = null

/**
 * The wallet code is downloaded on first use, not at startup, so the landing page stays light.
 * WAX Cloud Wallet, Wombat and Anchor are offered.
 */
function getKit(): Promise<SessionKit> {
  kit ??= (async () => {
    const [{ SessionKit, ChainDefinition }, { default: WebRenderer }, anchor, cloudWallet, wombat] = await Promise.all([
      import('@wharfkit/session'),
      import('@wharfkit/web-renderer'),
      import('@wharfkit/wallet-plugin-anchor'),
      import('@wharfkit/wallet-plugin-cloudwallet'),
      import('@wharfkit/wallet-plugin-wombat')
    ])
    const ui = new WebRenderer()
    // Closing the wallet picker (×, Escape, backdrop) cancels its login promise silently, so
    // kit.login() would never settle and the button would wait forever. Hear the close here.
    const addCancelable = ui.addCancelablePromise
    ui.addCancelablePromise = (cancel: (reason?: string, silent?: boolean) => unknown) =>
      addCancelable((reason?: string, silent?: boolean) => {
        onPickerClosed?.()
        return cancel(reason, silent)
      })
    return new SessionKit({
      appName: APP_NAME,
      chains: [ChainDefinition.from({ id: CHAIN_ID, url: RPC_NODES[0] })],
      ui,
      walletPlugins: [new cloudWallet.WalletPluginCloudWallet(), new wombat.WalletPluginWombat(), new anchor.WalletPluginAnchor()]
    })
  })()
  // A failed download (offline, stale deploy) can be retried on the next call.
  kit.catch(() => {
    kit = null
  })
  return kit
}

/** Starts the wallet download early, e.g. when a visitor reaches for the sign-in button. */
export function preloadWallet() {
  void getKit().catch(() => undefined)
}

export function hasStoredSession(): boolean {
  try {
    return localStorage.getItem(STORED_SESSION_KEY) !== null
  } catch {
    return false
  }
}

function isUserCancel(err: unknown): boolean {
  const message = err instanceof Error ? err.message : String(err ?? '')
  return /cancel|closed|rejected by user|user rejected|denied/i.test(message)
}

/** The account of the last session in this browser, if the wallet still has it. */
export async function restoreSession(): Promise<string | undefined> {
  if (!hasStoredSession()) return undefined
  try {
    current = await (await getKit()).restore()
  } catch {
    current = undefined
  }
  return current ? String(current.actor) : undefined
}

/** Opens the wallet picker. Resolves to the account, or undefined if the player closes it. */
export async function login(): Promise<string | undefined> {
  const k = await getKit()
  const closed = new Promise<undefined>((resolve) => {
    onPickerClosed = () => resolve(undefined)
  })
  try {
    const result = await Promise.race([k.login(), closed])
    if (!result) return undefined
    current = result.session
    return String(current.actor)
  } catch (err) {
    if (isUserCancel(err)) return undefined
    throw err
  } finally {
    onPickerClosed = null
  }
}

export async function logout(): Promise<void> {
  const k = await getKit()
  await k.logout(current)
  current = undefined
}

/** Short wallet name for the signed-in session, e.g. "Wombat". */
export function walletName(): string | null {
  if (!current) return null
  return current.walletPlugin.metadata.name ?? current.walletPlugin.id
}

/** Signs and broadcasts actions with the signed-in wallet; resolves to the transaction id. */
export async function transact(actions: AnyAction[]): Promise<string> {
  if (!current) await restoreSession()
  if (!current) throw new Error('Sign in with a wallet first.')
  const result = await current.transact({ actions }, { broadcast: true, expireSeconds: 120 })
  return String(result.resolved?.transaction.id ?? '')
}

/** The signed-in account and permission, for action authorizations. */
export function signer(): { actor: string; permission: string } | null {
  return current ? { actor: String(current.actor), permission: String(current.permission) } : null
}

/** Turns a wallet or chain error into the sentence a player should see. */
export function friendlyError(err: unknown): string {
  const raw = err instanceof Error ? err.message : String(err ?? '')
  if (isUserCancel(err)) return 'The wallet request was closed.'
  const msg = raw.replace(/^.*assertion failure with message:\s*/i, '').replace(/\s*- 3\s*$/, '').trim()
  return msg ? msg.charAt(0).toUpperCase() + msg.slice(1) : 'The transaction failed.'
}

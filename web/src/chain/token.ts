import { TOKEN_CONTRACT, TOKEN_DECIMALS, TOKEN_SYMBOL } from './config'
import { readTable } from './rpc'

interface AccountRow { balance: string }

const zero = (0).toFixed(TOKEN_DECIMALS)

/** A wallet's Fenmark balance as the token contract keeps it ("1250.0000"), or zero while there is no contract, no
 *  balance row, or the read fails. */
export async function fetchFenBalance(account: string): Promise<string> {
  if (!TOKEN_CONTRACT) return zero
  try {
    const rows = await readTable<AccountRow>('accounts', account, () => true, { code: TOKEN_CONTRACT })
    const row = rows.find((r) => r.balance.endsWith(' ' + TOKEN_SYMBOL))
    return row ? row.balance.split(' ')[0] : zero
  } catch {
    return zero
  }
}

/** "1250.0000" with thousands marked: "1,250.0000". */
export const formatFen = (amount: string) => { const [whole, frac] = amount.split('.'); return whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',') + (frac ? '.' + frac : '') }

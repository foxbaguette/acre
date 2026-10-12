import { CONTRACT, RPC_NODES } from './config'

/** text/plain is CORS-safelisted, so table reads skip the preflight that some nodes refuse. */
const CONTENT_TYPE = 'text/plain;charset=UTF-8'

interface TableResponse<T> {
  rows: T[]
  more: boolean
  next_key?: string
}

/** Optional: another contract, or a secondary index with a key range (e.g. index 3, i64, map id to map id). */
export interface TableQuery {
  code?: string
  index?: number
  keyType?: string
  lower?: string
  upper?: string
}

let preferred = 0

/**
 * Every row of a contract table. Busy nodes sometimes answer with an empty or cut-off table instead
 * of an error, so `complete` decides whether an answer can be trusted; if not, the next node is asked.
 */
export async function readTable<T>(table: string, scope: string, complete: (rows: T[]) => boolean = () => true, query: TableQuery = {}): Promise<T[]> {
  let lastError: unknown = new Error('No WAX node answered')
  for (let n = 0; n < RPC_NODES.length; n++) {
    const index = (preferred + n) % RPC_NODES.length
    const node = RPC_NODES[index]
    try {
      const rows: T[] = []
      let lower = query.lower ?? ''
      for (let page = 0; page < 50; page++) {
        const response = await fetch(`${node}/v1/chain/get_table_rows`, {
          method: 'POST',
          headers: { 'Content-Type': CONTENT_TYPE },
          signal: AbortSignal.timeout(10_000),
          body: JSON.stringify({
            json: true, code: query.code ?? CONTRACT, scope, table, lower_bound: lower, limit: 1000,
            ...(query.index ? { index_position: query.index, key_type: query.keyType ?? 'i64' } : {}),
            ...(query.upper !== undefined ? { upper_bound: query.upper } : {})
          })
        })
        if (!response.ok) throw new Error(`${node} answered ${response.status}`)
        const json = (await response.json()) as TableResponse<T>
        if (!Array.isArray(json.rows)) throw new Error(`${node} sent no rows`)
        rows.push(...json.rows)
        if (!json.more || !json.next_key) break
        lower = json.next_key
      }
      if (complete(rows)) {
        preferred = index
        return rows
      }
      lastError = new Error('The WAX nodes sent an incomplete table. Please try again.')
    } catch (err) {
      lastError = err
    }
  }
  throw lastError
}

/** The fields an action of a contract takes, as its deployed ABI says (to keep working across a contract update). */
export async function actionFields(action: string, code = CONTRACT): Promise<string[]> {
  for (let n = 0; n < RPC_NODES.length; n++) {
    const node = RPC_NODES[(preferred + n) % RPC_NODES.length]
    try {
      const response = await fetch(`${node}/v1/chain/get_abi`, { method: 'POST', headers: { 'Content-Type': CONTENT_TYPE }, signal: AbortSignal.timeout(10_000), body: JSON.stringify({ account_name: code }) })
      if (!response.ok) continue
      const abi = (await response.json()).abi as { actions: { name: string; type: string }[]; structs: { name: string; fields: { name: string }[] }[] }
      const type = abi.actions.find((a) => a.name === action)?.type ?? action
      return abi.structs.find((s) => s.name === type)?.fields.map((f) => f.name) ?? []
    } catch { /* the next node */ }
  }
  return []
}

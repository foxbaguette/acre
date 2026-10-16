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

interface Abi { actions: { name: string; type: string }[]; structs: { name: string; fields: { name: string }[] }[]; tables: { name: string }[] }
const abis = new Map<string, Promise<Abi | null>>()
/** A contract's deployed ABI, read once a minute at most (null if no node answers). */
function deployedAbi(code: string): Promise<Abi | null> {
  let p = abis.get(code)
  if (!p) {
    p = (async () => {
      for (let n = 0; n < RPC_NODES.length; n++) {
        const node = RPC_NODES[(preferred + n) % RPC_NODES.length]
        try {
          const response = await fetch(`${node}/v1/chain/get_abi`, { method: 'POST', headers: { 'Content-Type': CONTENT_TYPE }, signal: AbortSignal.timeout(10_000), body: JSON.stringify({ account_name: code }) })
          if (response.ok) return (await response.json()).abi as Abi
        } catch { /* the next node */ }
      }
      return null
    })()
    abis.set(code, p); setTimeout(() => abis.delete(code), 60_000)
  }
  return p
}

/** The fields an action of a contract takes, as its deployed ABI says (to keep working across a contract update). */
export async function actionFields(action: string, code = CONTRACT): Promise<string[]> {
  const abi = await deployedAbi(code), act = abi?.actions.find((a) => a.name === action)
  return act ? abi!.structs.find((s) => s.name === act.type)?.fields.map((f) => f.name) ?? [] : []
}

/** A scope as get_table_by_scope names it (a WAX name) back to the number it stands for, e.g. "............a" is 6. */
export function scopeNumber(name: string): string {
  const chars = '.12345abcdefghijklmnopqrstuvwxyz'
  let v = 0n
  for (let i = 0; i < 13; i++) {
    const c = BigInt(Math.max(0, chars.indexOf(name[i] ?? '.')))
    v |= i < 12 ? (c & 0x1fn) << BigInt(64 - 5 * (i + 1)) : c & 0x0fn
  }
  return v.toString()
}

/** The scopes (as numbers) that hold rows of a table, with how many. (The empty scope, number 0, is not listed by the
 *  chain: ask for it on its own.) */
export async function tableScopes(table: string, code = CONTRACT): Promise<{ scope: string; count: number }[]> {
  for (let n = 0; n < RPC_NODES.length; n++) {
    const node = RPC_NODES[(preferred + n) % RPC_NODES.length]
    try {
      const out: { scope: string; count: number }[] = []
      let lower = ''
      for (let page = 0; page < 20; page++) {
        const response = await fetch(`${node}/v1/chain/get_table_by_scope`, { method: 'POST', headers: { 'Content-Type': CONTENT_TYPE }, signal: AbortSignal.timeout(10_000), body: JSON.stringify({ code, table, lower_bound: lower, limit: 1000 }) })
        if (!response.ok) throw new Error(`${node} answered ${response.status}`)
        const json = (await response.json()) as { rows: { scope: string; count: number }[]; more: string }
        out.push(...json.rows.map((r) => ({ scope: scopeNumber(r.scope), count: r.count })))
        if (!json.more) break
        lower = json.more
      }
      return out
    } catch { /* the next node */ }
  }
  return []
}

/** The tables a contract has, as its deployed ABI lists them (null if it cannot be read). */
export async function contractTables(code = CONTRACT): Promise<string[] | null> {
  return (await deployedAbi(code))?.tables.map((t) => t.name) ?? null
}

/** The actions a contract has, as its deployed ABI lists them. */
export async function contractActions(code = CONTRACT): Promise<string[]> {
  return (await deployedAbi(code))?.actions.map((a) => a.name) ?? []
}

// Reads every map of the land.acre contract from WAX and writes island-select/assets/islands.json:
// for each map its coastline as an SVG path (tile units 0-100) and its land, forest, mountain, beach and
// fresh-water shares. Same outline method as web/src/lib/outline.ts. Run: node tools/islands/outlines.mjs
import { writeFileSync, mkdirSync } from 'node:fs'

const NODES = ['https://wax.greymass.com', 'https://api.wax.alohaeos.com', 'https://wax.eosphere.io']
const SIZE = 100

async function table(table, scope) {
  for (const node of NODES) {
    try {
      const r = await fetch(`${node}/v1/chain/get_table_rows`, { method: 'POST', body: JSON.stringify({ json: true, code: 'land.acre', scope: String(scope), table, limit: 1000 }) })
      const j = await r.json()
      if (Array.isArray(j.rows) && j.rows.length) return j.rows
    } catch {}
  }
  throw new Error(`no node answered for ${table}/${scope}`)
}

function decode(rows) {
  const t = new Uint8Array(SIZE * SIZE)
  for (const row of rows) {
    const b = row.tiles.match(/../g).map((h) => parseInt(h, 16)), cx = row.id % 10, cy = Math.floor(row.id / 10)
    for (let k = 0; k < 100; k++) t[(cy * 10 + Math.floor(k / 10)) * SIZE + cx * 10 + (k % 10)] = b[k]
  }
  return t
}

function blur(src, W) {
  const out = new Float32Array(src.length), k = [1, 2, 1]
  for (let y = 0; y < W; y++) for (let x = 0; x < W; x++) {
    let s = 0, w = 0
    for (let j = -1; j <= 1; j++) for (let i = -1; i <= 1; i++) {
      const xx = x + i, yy = y + j
      if (xx < 0 || yy < 0 || xx >= W || yy >= W) continue
      const q = k[i + 1] * k[j + 1]; s += src[yy * W + xx] * q; w += q
    }
    out[y * W + x] = s / w
  }
  return out
}

function coastline(tiles) {
  const W = SIZE + 2
  let f = new Float32Array(W * W)
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) f[(y + 1) * W + x + 1] = (tiles[y * SIZE + x] & 7) === 0 ? 0 : 1
  f = blur(blur(f, W), W)
  const at = (x, y) => f[y * W + x], pts = new Map(), links = new Map()
  const link = (a, b) => { (links.get(a) ?? links.set(a, []).get(a)).push(b); (links.get(b) ?? links.set(b, []).get(b)).push(a) }
  const edge = (kind, x, y) => {
    const key = kind + x + ',' + y
    if (!pts.has(key)) {
      const [x2, y2] = kind === 'h' ? [x + 1, y] : [x, y + 1], a = at(x, y), t = (0.5 - a) / (at(x2, y2) - a)
      pts.set(key, [x + (x2 - x) * t - 0.5, y + (y2 - y) * t - 0.5])
    }
    return key
  }
  for (let y = 0; y < W - 1; y++) for (let x = 0; x < W - 1; x++) {
    const tl = at(x, y) >= 0.5, tr = at(x + 1, y) >= 0.5, br = at(x + 1, y + 1) >= 0.5, bl = at(x, y + 1) >= 0.5
    const i = (tl ? 8 : 0) | (tr ? 4 : 0) | (br ? 2 : 0) | (bl ? 1 : 0)
    if (i === 0 || i === 15) continue
    const T = () => edge('h', x, y), B = () => edge('h', x, y + 1), L = () => edge('v', x, y), R = () => edge('v', x + 1, y)
    const c = (at(x, y) + at(x + 1, y) + at(x + 1, y + 1) + at(x, y + 1)) / 4 >= 0.5
    switch (i) {
      case 1: case 14: link(L(), B()); break
      case 2: case 13: link(B(), R()); break
      case 3: case 12: link(L(), R()); break
      case 4: case 11: link(T(), R()); break
      case 6: case 9: link(T(), B()); break
      case 7: case 8: link(L(), T()); break
      case 5: if (c) { link(L(), T()); link(R(), B()) } else { link(T(), R()); link(L(), B()) } break
      case 10: if (c) { link(T(), R()); link(L(), B()) } else { link(L(), T()); link(R(), B()) } break
    }
  }
  const seen = new Set(), parts = [], r = (v) => Math.round(v * 10) / 10
  for (const start of links.keys()) {
    if (seen.has(start)) continue
    const loop = []; let prev = '', cur = start
    while (!seen.has(cur)) {
      seen.add(cur); loop.push(pts.get(cur))
      const next = links.get(cur).find((k) => k !== prev && !seen.has(k)) ?? ''
      prev = cur; if (!next) break; cur = next
    }
    if (loop.length < 3) continue
    const mid = (a, b) => [r((a[0] + b[0]) / 2), r((a[1] + b[1]) / 2)], n = loop.length, s = mid(loop[n - 1], loop[0])
    let d = `M${s[0]} ${s[1]}`
    for (let k = 0; k < n; k++) { const m = mid(loop[k], loop[(k + 1) % n]); d += `Q${r(loop[k][0])} ${r(loop[k][1])} ${m[0]} ${m[1]}` }
    parts.push(d + 'Z')
  }
  return parts.join('')
}

function stats(t) {
  let land = 0, forest = 0, mountain = 0, beach = 0, fresh = 0
  for (const b of t) { const g = b & 7; if (g) land++; if (b & 64) forest++; if (g === 4) mountain++; if (g === 2) beach++; if (g === 1) fresh++ }
  const p = (v) => Math.round((v / t.length) * 1000) / 10
  return { land: p(land), forest: p(forest), mountain: p(mountain), beach: p(beach), freshWater: p(fresh) }
}

const maps = await table('maps', 'land.acre')
const out = []
for (const m of maps) {
  const tiles = decode(await table('chunks', m.map_id))
  out.push({ id: m.map_id, owner: m.owner, name: m.map_name, coast: coastline(tiles), stats: stats(tiles) })
  console.log('map', m.map_id, out.at(-1).stats)
}
mkdirSync('island-select/assets', { recursive: true })
writeFileSync('island-select/assets/islands.json', JSON.stringify(out))
console.log('wrote', out.length, 'islands')

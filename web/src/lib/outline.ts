import { MAP_SIZE } from '@/chain/config'

/**
 * The coastline of a map as a smooth SVG path in tile units (0-100): every tile that is not sea counts
 * as land. The land mask is softened with a small blur, traced with marching squares at the halfway
 * value, and each loop is drawn with quadratic curves through the midpoints of its edges.
 */
export function coastlinePath(tiles: Uint8Array, size = MAP_SIZE): string {
  const W = size + 2 // one ring of sea around the map, so every coast is a closed loop
  let field: Float32Array = new Float32Array(W * W)
  for (let y = 0; y < size; y++)
    for (let x = 0; x < size; x++) field[(y + 1) * W + x + 1] = (tiles[y * size + x] & 7) === 0 ? 0 : 1
  for (let pass = 0; pass < 2; pass++) field = blur(field, W)

  const at = (x: number, y: number) => field[y * W + x]
  const points = new Map<string, [number, number]>()
  const links = new Map<string, string[]>()
  const link = (a: string, b: string) => {
    ;(links.get(a) ?? links.set(a, []).get(a)!).push(b)
    ;(links.get(b) ?? links.set(b, []).get(b)!).push(a)
  }
  // Edge keys: h = between (x, y) and (x + 1, y); v = between (x, y) and (x, y + 1).
  const edge = (kind: 'h' | 'v', x: number, y: number) => {
    const key = `${kind}${x},${y}`
    if (!points.has(key)) {
      const [x2, y2] = kind === 'h' ? [x + 1, y] : [x, y + 1]
      const a = at(x, y)
      const t = (0.5 - a) / (at(x2, y2) - a)
      // Grid point (gx, gy) is the centre of tile (gx - 1, gy - 1).
      points.set(key, [x + (x2 - x) * t - 0.5, y + (y2 - y) * t - 0.5])
    }
    return key
  }

  for (let y = 0; y < W - 1; y++)
    for (let x = 0; x < W - 1; x++) {
      const tl = at(x, y) >= 0.5, tr = at(x + 1, y) >= 0.5, br = at(x + 1, y + 1) >= 0.5, bl = at(x, y + 1) >= 0.5
      const index = (tl ? 8 : 0) | (tr ? 4 : 0) | (br ? 2 : 0) | (bl ? 1 : 0)
      if (index === 0 || index === 15) continue
      const top = () => edge('h', x, y), bottom = () => edge('h', x, y + 1)
      const left = () => edge('v', x, y), right = () => edge('v', x + 1, y)
      const centre = (at(x, y) + at(x + 1, y) + at(x + 1, y + 1) + at(x, y + 1)) / 4 >= 0.5
      switch (index) {
        case 1: case 14: link(left(), bottom()); break
        case 2: case 13: link(bottom(), right()); break
        case 3: case 12: link(left(), right()); break
        case 4: case 11: link(top(), right()); break
        case 6: case 9: link(top(), bottom()); break
        case 7: case 8: link(left(), top()); break
        case 5: // top right and bottom left are land
          if (centre) { link(left(), top()); link(right(), bottom()) } else { link(top(), right()); link(left(), bottom()) }
          break
        case 10: // top left and bottom right are land
          if (centre) { link(top(), right()); link(left(), bottom()) } else { link(left(), top()); link(right(), bottom()) }
          break
      }
    }

  const seen = new Set<string>()
  const parts: string[] = []
  for (const start of links.keys()) {
    if (seen.has(start)) continue
    const loop: [number, number][] = []
    let previous = ''
    let current = start
    while (!seen.has(current)) {
      seen.add(current)
      loop.push(points.get(current)!)
      const next = links.get(current)!.find((k) => k !== previous && !seen.has(k)) ?? ''
      previous = current
      if (!next) break
      current = next
    }
    if (loop.length >= 3) parts.push(smoothLoop(loop))
  }
  return parts.join(' ')
}

function blur(src: Float32Array, W: number): Float32Array {
  const out = new Float32Array(src.length)
  const k = [1, 2, 1]
  for (let y = 0; y < W; y++)
    for (let x = 0; x < W; x++) {
      let sum = 0, weight = 0
      for (let j = -1; j <= 1; j++)
        for (let i = -1; i <= 1; i++) {
          const xx = x + i, yy = y + j
          if (xx < 0 || yy < 0 || xx >= W || yy >= W) continue
          const w = k[i + 1] * k[j + 1]
          sum += src[yy * W + xx] * w
          weight += w
        }
      out[y * W + x] = sum / weight
    }
  return out
}

const r = (v: number) => Math.round(v * 100) / 100

function smoothLoop(p: [number, number][]): string {
  const mid = (a: [number, number], b: [number, number]) => [r((a[0] + b[0]) / 2), r((a[1] + b[1]) / 2)]
  const n = p.length
  const [sx, sy] = mid(p[n - 1], p[0])
  let d = `M${sx} ${sy}`
  for (let i = 0; i < n; i++) {
    const [mx, my] = mid(p[i], p[(i + 1) % n])
    d += `Q${r(p[i][0])} ${r(p[i][1])} ${mx} ${my}`
  }
  return d + 'Z'
}

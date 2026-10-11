// The mountains, in the style picked from the sheets (alpine snowfields, version C2: a spine with spurs, a long gentle
// foot). The GPU draws them (see terrain.ts, mountainH); here we only say, for every field pixel, where it lies on
// "its" mountain in the sheet's own units, how big that mountain is and how much of it to show.
//
// A mountain is a group of touching mountain cells. Every pixel belongs to the nearest one. The sheet draws a mountain
// of a fixed size centred on a point; the game lays it over the real mountain by scaling it to the mountain's size
// (radius of a circle of the same area, over 7.5 sheet units) and clipping it with the blurred outline of the cells.
import type { World } from './world'
import { T } from './world'

export interface Mountain {
  cells: number[]
  cx: number
  cy: number
  /** radius of a circle of the same area, tiles */
  radius: number
  /** how long against how wide */
  stretch: number
  /** the direction of its long side, radians */
  axis: number
  /** tallest level among its cells */
  top: number
}

export interface MountainFields {
  list: Mountain[]
  /** per field pixel, RGBA: x and y in sheet units from the mountain's centre, the sheet's scale (tiles per unit), how much shows (0..1) */
  f1: Float32Array
}

const smooth = (a: number, b: number, x: number) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t) }

/** `wide` and `narrow`: the cells' outline blurred a lot and a little (field resolution); big mountains use the wide one. */
export function buildMountains(world: World, S: number, wide: Float32Array, narrow: Float32Array): MountainFields {
  const { cols, rows, type, elev } = world, w = cols * S, h = rows * S, N = cols * rows
  const rock = (i: number) => type[i] === T.rock
  const label = new Int32Array(N).fill(-1), list: Mountain[] = []
  for (let i0 = 0; i0 < N; i0++) {
    if (!rock(i0) || label[i0] >= 0) continue
    const id = list.length, cells: number[] = [i0], st = [i0]; label[i0] = id
    while (st.length) {
      const i = st.pop()!, x = i % cols, y = (i / cols) | 0
      for (let j = -1; j <= 1; j++) for (let k = -1; k <= 1; k++) {
        const X = x + k, Y = y + j; if (X < 0 || Y < 0 || X >= cols || Y >= rows) continue
        const q = Y * cols + X; if (rock(q) && label[q] < 0) { label[q] = id; cells.push(q); st.push(q) }
      }
    }
    let cx = 0, cy = 0, top = 0
    for (const i of cells) { cx += (i % cols) + 0.5; cy += ((i / cols) | 0) + 0.5; top = Math.max(top, elev[i]) }
    cx /= cells.length; cy /= cells.length
    let sxx = 0, syy = 0, sxy = 0
    for (const i of cells) { const dx = (i % cols) + 0.5 - cx, dy = ((i / cols) | 0) + 0.5 - cy; sxx += dx * dx; syy += dy * dy; sxy += dx * dy }
    sxx /= cells.length; syy /= cells.length; sxy /= cells.length
    const tr = sxx + syy, det = sxx * syy - sxy * sxy, d = Math.sqrt(Math.max(0, tr * tr / 4 - det))
    const l1 = tr / 2 + d, l2 = Math.max(tr / 2 - d, 0.05)
    list.push({ cells, cx, cy, radius: Math.sqrt(cells.length / Math.PI), stretch: Math.sqrt(l1 / l2), axis: Math.atan2(l1 - sxx, sxy || 1e-6), top })
  }
  const f1 = new Float32Array(w * h * 4)
  if (!list.length) return { list, f1 }
  // every cell belongs to the nearest mountain
  const near = new Int32Array(N).fill(-1), q: number[] = []
  for (let i = 0; i < N; i++) if (label[i] >= 0) { near[i] = label[i]; q.push(i) }
  for (let qi = 0; qi < q.length; qi++) {
    const i = q[qi], x = i % cols, y = (i / cols) | 0
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const X = x + dx, Y = y + dy; if (X < 0 || Y < 0 || X >= cols || Y >= rows) continue; const j = Y * cols + X; if (near[j] < 0) { near[j] = near[i]; q.push(j) } }
  }
  // a mountain that is long and narrow is laid along its long side; a roundish one keeps the sheet's own direction
  const frame = list.map((m) => { const a = m.stretch > 1.5 ? m.axis : 0; return [Math.cos(a), Math.sin(a), m.radius / 7.5, smooth(2.5, 4.5, m.radius)] })
  for (let py = 0; py < h; py++) for (let px = 0; px < w; px++) {
    const k = py * w + px, x = (px + 0.5) / S, y = (py + 0.5) / S
    const id = near[Math.min(rows - 1, y | 0) * cols + Math.min(cols - 1, x | 0)]
    const m = list[id], [c, s, scale, big] = frame[id]
    const dx = x - m.cx, dy = y - m.cy
    f1[k * 4] = (dx * c + dy * s) / scale
    f1[k * 4 + 1] = (-dx * s + dy * c) / scale
    f1[k * 4 + 2] = scale
    f1[k * 4 + 3] = Math.min(1, Math.max(0, narrow[k] + (wide[k] - narrow[k]) * big))
  }
  return { list, f1 }
}

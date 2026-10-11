// Soft fields for the natural edges. Each starts from a set of cells read as samples at the cell centres and
// interpolated between them, so a staircase of cells becomes a slope instead of steps. The sample position is
// pushed around by a few octaves of smooth noise (the same push for every field, so beach, water and rock still
// meet), which turns the grid into wandering shores. Then a light blur and the island's fine edge noise; a ground type covers a pixel where its field is above a threshold. The GPU reads
// them with smooth (bicubic) sampling and draws every edge as a distance, so edges stay crisp at any zoom.
//
// They are packed four to a texture:
//   F0  rock, sand, soil, path
//   F1  water, open sea, land seen from the sea (wide, for the shallows), land (narrow, for the surf line)
//   F2  mountain levels 1-4
//   F3  mountain level 5
import { buildMountains, type Mountain } from './mountains'
import { blurGrid, seeded, T, type World } from './world'

/** Where each ground's edge sits on its field, the colour of the band along it and the band's width in tiles. */
export const EDGES = {
  rock: { inner: 0.53, edge: [0x5e, 0x58, 0x50], band: 0.06, blur: 0.3 },
  sand: { inner: 0.53, edge: [0xc2, 0xae, 0x86], band: 0.06, blur: 0.3 },
  soil: { inner: 0.535, edge: [0x3e, 0x2a, 0x1c], band: 0.07, blur: 0.2 },
  path: { inner: 0.5, edge: [0x58, 0x4e, 0x46], band: 0.06, blur: 0.2 },
  water: { inner: 0.56, edge: [0x1d, 0x56, 0x77], band: 0.08, blur: 0.6 },
}
export const LEVEL_TH = 0.56

export interface Fields {
  /** field pixels per tile */
  S: number
  w: number
  h: number
  /** four RGBA float images, w x h */
  tex: Float32Array[]
  /** the terrain's height image (see terrain.ts), w x h RGBA */
  height: Float32Array
  /** the mountains found on the island */
  mountains: Mountain[]
  /** Makes the soil and path fields again from the world as it is now (after building); updates tex[0] in place. */
  refreshGrounds: () => void
}

export function buildFields(world: World, S: number): Fields {
  const { cols, rows, type, ocean } = world, w = cols * S, h = rows * S
  const nf = noiseField(world, S), [wu, wv] = warpField(world, S)
  const cells = new Float32Array(cols * rows)
  // where each field pixel reads the cells: bilinear between cell centres (outside the map the nearest cell repeats);
  // the same for every field, so worked out once
  const at = new Int32Array(w * h), wx = new Float32Array(w * h), wy = new Float32Array(w * h)
  for (let k = 0; k < at.length; k++) {
    const u = Math.min(cols - 1, Math.max(0, wu[k])), v = Math.min(rows - 1, Math.max(0, wv[k]))
    const x0 = Math.min(cols - 2, u | 0), y0 = Math.min(rows - 2, v | 0)
    at[k] = y0 * cols + x0; wx[k] = u - x0; wy[k] = v - y0
  }
  const field = (pick: (i: number) => boolean | number, blur: number, amp: number) => {
    for (let i = 0; i < cells.length; i++) cells[i] = +pick(i)
    const f = new Float32Array(w * h)
    for (let k = 0; k < f.length; k++) {
      const i = at[k], fx = wx[k], fy = wy[k], a = cells[i], b = cells[i + 1], c = cells[i + cols], d = cells[i + cols + 1]
      f[k] = (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy
    }
    // the interpolation already softens by about 0.3 tiles; only blur what is asked beyond that, plus a touch to
    // round the kinks the interpolation leaves along cell centres
    if (blur > 0) blurGrid(f, w, h, 1, Math.max(0.12, Math.sqrt(Math.max(0, blur * blur - 0.08))) * S)
    for (let k = 0; k < f.length; k++) f[k] += nf[k] * amp
    return f
  }
  // soil, with straight edges where it meets a path: a soil tile next to a path reaches straight across to the path's
  // middle (the path is drawn over it), so the field runs right up to the path, with no strip of grass between
  const soilField = () => {
    const f = field(of(T.soil), EDGES.soil.blur, 0.035), add = new Float32Array(w * h)
    const rect = (x0: number, y0: number, x1: number, y1: number) => {
      for (let py = Math.max(0, Math.round(y0 * S)); py < Math.min(h, Math.round(y1 * S)); py++) add.fill(1, py * w + Math.max(0, Math.round(x0 * S)), py * w + Math.min(w, Math.round(x1 * S)))
    }
    const is = (x: number, y: number, t: number) => x >= 0 && y >= 0 && x < cols && y < rows && type[y * cols + x] === t
    for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
      if (!is(x, y, T.soil)) continue
      const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]].filter(([dx, dy]) => is(x + dx, y + dy, T.path))
      if (!dirs.length) continue
      rect(x, y, x + 1, y + 1)
      for (const [dx, dy] of dirs) rect(x + Math.min(0, dx) * 0.5 + Math.max(0, dx), y + Math.min(0, dy) * 0.5 + Math.max(0, dy), x + 1 + Math.max(0, dx) * 0.5 + Math.min(0, dx), y + 1 + Math.max(0, dy) * 0.5 + Math.min(0, dy))
    }
    blurGrid(add, w, h, 1, 0.1 * S)
    for (let k = 0; k < f.length; k++) f[k] = Math.max(f[k], add[k])
    return f
  }
  // paths are laid by hand: a footpath about half a tile wide along the middle of its tiles, straight, joining the
  // paths next to it (also corner to corner); where paths fill a whole block of tiles, they close up into a paved square
  const straight = (pick: (i: number) => boolean) => {
    const f = new Float32Array(w * h), HW = 0.22
    const rect = (x0: number, y0: number, x1: number, y1: number) => {
      for (let py = Math.max(0, Math.round(y0 * S)); py < Math.min(h, Math.round(y1 * S)); py++) f.fill(1, py * w + Math.max(0, Math.round(x0 * S)), py * w + Math.min(w, Math.round(x1 * S)))
    }
    const P = (x: number, y: number) => x >= 0 && y >= 0 && x < cols && y < rows && pick(y * cols + x)
    const segment = (ax: number, ay: number, bx: number, by: number) => {   // a strip of the path's width from a to b, in tiles
      const x0 = Math.max(0, Math.floor((Math.min(ax, bx) - HW) * S)), x1 = Math.min(w - 1, Math.ceil((Math.max(ax, bx) + HW) * S))
      const y0 = Math.max(0, Math.floor((Math.min(ay, by) - HW) * S)), y1 = Math.min(h - 1, Math.ceil((Math.max(ay, by) + HW) * S))
      const vx = bx - ax, vy = by - ay, vv = vx * vx + vy * vy
      for (let py = y0; py <= y1; py++) for (let px = x0; px <= x1; px++) {
        const qx = (px + 0.5) / S - ax, qy = (py + 0.5) / S - ay, u = Math.max(0, Math.min(1, (qx * vx + qy * vy) / vv))
        if (Math.hypot(qx - vx * u, qy - vy * u) <= HW) f[py * w + px] = 1
      }
    }
    for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
      if (!P(x, y)) continue
      rect(x + 0.5 - HW, y + 0.5 - HW, x + 0.5 + HW, y + 0.5 + HW)
      if (P(x + 1, y)) rect(x + 0.5, y + 0.5 - HW, x + 1.5, y + 0.5 + HW)
      if (P(x, y + 1)) rect(x + 0.5 - HW, y + 0.5, x + 0.5 + HW, y + 1.5)
      if (P(x + 1, y) && P(x, y + 1) && P(x + 1, y + 1)) rect(x + 0.5, y + 0.5, x + 1.5, y + 1.5)
      // corner to corner, where the two do not already join through a tile beside both
      for (const dx of [1, -1]) if (P(x + dx, y + 1) && !P(x + dx, y) && !P(x, y + 1)) segment(x + 0.5, y + 0.5, x + dx + 0.5, y + 1.5)
    }
    blurGrid(f, w, h, 1, 0.1 * S)
    return f
  }
  const empty = () => new Float32Array(w * h).fill(-1)
  const tex = [0, 1, 2, 3].map(() => new Float32Array(w * h * 4))
  const pack = (t: number, c: number, f: Float32Array) => { const out = tex[t]; for (let k = 0; k < f.length; k++) out[k * 4 + c] = f[k] }
  const of = (t: number) => (i: number) => type[i] === t
  // F0.r: ground marked mountain (not painted as a ground of its own any more: the mountains are relief)
  pack(0, 0, world.has[T.rock] ? field((i) => type[i] === T.rock, 2, 0.04) : empty())
  pack(0, 1, world.has[T.sand] ? field(of(T.sand), EDGES.sand.blur, 0.035) : empty())
  pack(0, 2, world.has[T.soil] ? soilField() : empty())
  pack(0, 3, world.has[T.path] ? straight(of(T.path)) : empty())
  // F1: the mountains (filled below); F2 and F3 are unused
  const anySea = ocean.some((v) => v)
  pack(2, 0, empty()); pack(3, 0, empty())
  // the terrain: distances to the sea and into ponds from the same warped outlines, mountain bulk, woods
  const height = new Float32Array(w * h * 4)
  const sd = (inside: Float32Array | null, th = 0.5) => {
    if (!inside) return null
    // at half resolution (the distances are smooth; the GPU adds the fine shore), then spread back out bilinearly
    const hw = w >> 1, hh = h >> 1, m = new Uint8Array(hw * hh)
    for (let y = 0; y < hh; y++) for (let x = 0; x < hw; x++) m[y * hw + x] = (inside[(2 * y) * w + 2 * x] + inside[(2 * y) * w + 2 * x + 1] + inside[(2 * y + 1) * w + 2 * x] + inside[(2 * y + 1) * w + 2 * x + 1]) > th * 4 ? 1 : 0
    const d = signedDistance(m, hw, hh, S / 2), out = new Float32Array(w * h)
    for (let y = 0; y < h; y++) {
      const v = Math.min(hh - 1, Math.max(0, (y + 0.5) / 2 - 0.5)), y0 = Math.min(hh - 2, v | 0), fy = v - y0
      for (let x = 0; x < w; x++) {
        const u = Math.min(hw - 1, Math.max(0, (x + 0.5) / 2 - 0.5)), x0 = Math.min(hw - 2, u | 0), fx = u - x0, i = y0 * hw + x0
        out[y * w + x] = (d[i] + (d[i + 1] - d[i]) * fx) * (1 - fy) + (d[i + hw] + (d[i + hw + 1] - d[i + hw]) * fx) * fy
      }
    }
    return out
  }
  const landF = anySea ? field((i) => !ocean[i], 0, 0) : null
  const pondF = world.has[T.water] ? field((i) => type[i] === T.water && !ocean[i], 0.75, 0) : null   // rounder: a wide blur, read at a lower level so small ponds stay
  const dSea = sd(landF), dPond = sd(pondF, 0.36)
  const woods = field((i) => world.forest[i], 1.1, 0)
  // the mountains: per pixel, where it lies on its mountain, the sheet's scale and how much shows (F1; see mountains.ts)
  const anyRock = world.has[T.rock]
  const mt = buildMountains(world, S, anyRock ? field((i) => type[i] === T.rock, 3.4, 0) : new Float32Array(w * h), anyRock ? field((i) => type[i] === T.rock, 1.2, 0) : new Float32Array(w * h))
  tex[1].set(mt.f1)
  for (let k = 0; k < w * h; k++) {
    height[k * 4] = dSea ? Math.max(-14, Math.min(14, dSea[k])) : 14
    height[k * 4 + 1] = 0                                        // (free)
    height[k * 4 + 2] = dPond ? Math.max(-14, Math.min(14, dPond[k])) : -14
    height[k * 4 + 3] = Math.max(0, Math.min(1, woods[k]))
  }
  const refreshGrounds = () => {
    pack(0, 2, world.has[T.soil] ? soilField() : empty())
    pack(0, 3, world.has[T.path] ? straight(of(T.path)) : empty())
  }
  return { S, w, h, tex, height, mountains: mt.list, refreshGrounds }
}

/** Signed distance to the edge of a mask, in tiles: + inside, - outside (exact Euclidean, two passes per side). */
function signedDistance(m: Uint8Array, w: number, h: number, S: number): Float32Array {
  const inF = edt(m, w, h, 0), outF = edt(m, w, h, 1), out = new Float32Array(w * h)
  for (let k = 0; k < out.length; k++) out[k] = m[k] ? (Math.sqrt(inF[k]) - 0.5) / S : -(Math.sqrt(outF[k]) - 0.5) / S
  return out
}
/** Squared distance from every pixel to the nearest pixel whose mask equals `target` (Felzenszwalb & Huttenlocher). */
function edt(m: Uint8Array, w: number, h: number, target: number): Float32Array {
  const INF = 1e20, d = new Float32Array(w * h), n = Math.max(w, h)
  for (let k = 0; k < d.length; k++) d[k] = m[k] === target ? 0 : INF
  const f = new Float64Array(n), g = new Float64Array(n), v = new Int32Array(n), z = new Float64Array(n + 1)
  const pass = (len: number) => {
    let k = 0; v[0] = 0; z[0] = -INF; z[1] = INF
    for (let q = 1; q < len; q++) {
      let s2 = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k])
      while (s2 <= z[k]) { k--; s2 = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]) }
      k++; v[k] = q; z[k] = s2; z[k + 1] = INF
    }
    k = 0
    for (let q = 0; q < len; q++) { while (z[k + 1] < q) k++; g[q] = (q - v[k]) * (q - v[k]) + f[v[k]] }
  }
  for (let x = 0; x < w; x++) { for (let y = 0; y < h; y++) f[y] = d[y * w + x]; pass(h); for (let y = 0; y < h; y++) d[y * w + x] = g[y] }
  for (let y = 0; y < h; y++) { for (let x = 0; x < w; x++) f[x] = d[y * w + x]; pass(w); for (let x = 0; x < w; x++) d[y * w + x] = g[x] }
  return d
}

/** Where each field pixel reads the cells, in cell-centre units: its own position pushed by three octaves of smooth
 *  noise (about 4, 1.7 and 0.75 tiles across), so straight runs of cells bend into natural shores. */
function warpField(world: World, S: number): [Float32Array, Float32Array] {
  const { cols, rows, noise } = world, w = cols * S, h = rows * S
  const R = seeded(Math.floor((noise[0] + 1) * 1e6) + Math.floor((noise[1] + 1) * 1e3) + 9173)
  const octaves = [[4, 0.6], [1.7, 0.26], [0.75, 0.09]].map(([cell, amp]) => {
    const gw = Math.ceil(cols / cell) + 3, gh = Math.ceil(rows / cell) + 3
    return { cell, amp, gw, gx: Float32Array.from({ length: gw * gh }, () => R() * 2 - 1), gy: Float32Array.from({ length: gw * gh }, () => R() * 2 - 1) }
  })
  const wu = new Float32Array(w * h), wv = new Float32Array(w * h)
  const ease = (t: number) => t * t * (3 - 2 * t)
  for (const o of octaves) {                                   // one octave at a time, without closures: this runs per field pixel
    const { cell, amp, gw, gx, gy } = o
    for (let py = 0; py < h; py++) {
      const v = (py + 0.5) / S / cell + 1, j0 = v | 0, fy = ease(v - j0), row = py * w
      for (let px = 0; px < w; px++) {
        const u = (px + 0.5) / S / cell + 1, i0 = u | 0, fx = ease(u - i0), i = j0 * gw + i0, k = row + px
        const w00 = (1 - fx) * (1 - fy), w10 = fx * (1 - fy), w01 = (1 - fx) * fy, w11 = fx * fy
        wu[k] += (gx[i] * w00 + gx[i + 1] * w10 + gx[i + gw] * w01 + gx[i + gw + 1] * w11) * amp
        wv[k] += (gy[i] * w00 + gy[i + 1] * w10 + gy[i + gw] * w01 + gy[i + gw + 1] * w11) * amp
      }
    }
  }
  for (let py = 0; py < h; py++) for (let px = 0; px < w; px++) { const k = py * w + px; wu[k] += (px + 0.5) / S - 0.5; wv[k] += (py + 0.5) / S - 0.5 }
  return [wu, wv]
}

/** The edge wobble at field resolution: the island's half-tile noise grid, smoothly interpolated. */
function noiseField(world: World, S: number): Float32Array {
  const { cols, rows, noise, nw, nh } = world, w = cols * S, h = rows * S, out = new Float32Array(w * h)
  for (let py = 0; py < h; py++) {
    const v = ((py + 0.5) / S) * 2 + 0.5, j0 = Math.floor(v), fy = v - j0, ja = Math.min(nh - 1, Math.max(0, j0)), jb = Math.min(nh - 1, Math.max(0, j0 + 1))
    for (let px = 0; px < w; px++) {
      const u = ((px + 0.5) / S) * 2 + 0.5, i0 = Math.floor(u), fx = u - i0, ia = Math.min(nw - 1, Math.max(0, i0)), ib = Math.min(nw - 1, Math.max(0, i0 + 1))
      const a = noise[ja * nw + ia], b = noise[ja * nw + ib], c = noise[jb * nw + ia], d = noise[jb * nw + ib]
      out[py * w + px] = (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
    }
  }
  return out
}

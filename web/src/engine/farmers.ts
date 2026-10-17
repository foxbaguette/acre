// The farmers: each one is a job in land.acre's worker queue (table workqueue), and the chain says when each part of
// the round begins: out of the farmhouse at start, at the field at atField, done harvesting at harvested, at the silo at
// atSilo, offloaded at offloaded, home at home (resting inside until rested). A farmer walks the island's real way
// (round fences and buildings, swimming only where land would be far longer; paths are quicker), but at whatever pace makes each walk take exactly as
// long as the chain counted, so what is seen is what the chain has.
import { dims, entrance, type Builds } from './build'

export interface Farmer {
  id: number; look: number
  x: number; y: number; head: number
  state: 'walk' | 'harvest' | 'drop'
  /** in the water: swimming across a short stretch */
  swim: boolean
  /** what it carries (null: nothing) */
  crop: string | null
}

/** One job of the worker queue, as the page reads it: times in ms, tiles and buildings as map indexes (y * 100 + x). */
export interface Job {
  id: string; farmhouse: number; worker: number; silo: number; crop: string; tiles: number[]; amount: number; claimed: boolean
  /** harvested for seeds: amount is seeds, for the owner (not the island's storage) */
  seeds?: boolean
  start: number; atField: number; harvested: number; atSilo: number; offloaded: number; home: number; rested: number
}

/** The grid the farmers walk: which tiles they may step on, and how dear each step is. */
export interface Ground { cols: number; rows: number; walk: (i: number) => boolean; water: (i: number) => boolean; cost: (i: number) => number }

/** A job's round as points to walk through: out to the field, through its tiles, on to the silo, home. */
interface Round { out: number[]; field: number[]; toSilo: number[]; home: number[] }

export class Farmers {
  list: Farmer[] = []
  /** the tiles of jobs still being harvested (their crop not cut yet) */
  claimed = new Set<number>()
  private jobs: Job[] = []
  private rounds = new Map<string, Round>()
  /** tile: when its crop was cut (ms) */
  private cutTiles = new Map<number, number>()
  constructor(private ground: () => Ground, private builds: () => Builds) {}

  setJobs(jobs: Job[]) { this.jobs = jobs; this.rounds.clear() }
  /** The ground or the buildings changed: the ways are found again. */
  rethink() { this.rounds.clear() }
  /** Whether the crop sown on a tile at that time is cut already: a farmer has been over it since (it is bare soil
   *  from then on, claimed or not; a crop sown there afterwards is a new one). */
  cut(i: number, sown = 0) { const at = this.cutTiles.get(i); return at !== undefined && sown <= at }
  /** The tiles cut so far, with when. */
  cutList() { return this.cutTiles }

  private door(at: number) {
    const b = this.builds()[at], g = this.ground(); if (!b?.s) return at
    const e = entrance(b.s, at, g.cols, g.rows, b.o ?? 0); return e >= 0 ? e : at
  }
  /** The tiles beside a silo a farmer can stand on to put the sack in. */
  private siloSpots(at: number) {
    const b = this.builds()[at], g = this.ground(), out = new Set<number>(); if (!b?.s) return new Set([at])
    const [w, h] = dims(b.s, b.o), x0 = at % g.cols, y0 = (at - x0) / g.cols
    for (let y = y0 - 1; y <= y0 + h; y++) for (let x = x0 - 1; x <= x0 + w; x++) { if (x < 0 || y < 0 || x >= g.cols || y >= g.rows) continue; const i = y * g.cols + x; if (g.walk(i)) out.add(i) }
    return out.size ? out : new Set([at])
  }

  /** The cheapest way from a tile to the nearest of some goal tiles (8-neighbour, no cutting corners); a straight
   *  line when there is none. */
  private route(from: number, goals: Set<number>): number[] {
    if (goals.has(from)) return [from]
    const g = this.ground(), N = g.cols * g.rows, dist = new Float64Array(N).fill(Infinity), prev = new Int32Array(N).fill(-1)
    const heap: [number, number][] = []
    const push = (d: number, i: number) => { heap.push([d, i]); let k = heap.length - 1; while (k > 0) { const p = (k - 1) >> 1; if (heap[p][0] <= heap[k][0]) break; [heap[p], heap[k]] = [heap[k], heap[p]]; k = p } }
    const pop = () => { const top = heap[0], last = heap.pop()!; if (heap.length) { heap[0] = last; let k = 0; for (;;) { const l = 2 * k + 1, r = l + 1; let m = k; if (l < heap.length && heap[l][0] < heap[m][0]) m = l; if (r < heap.length && heap[r][0] < heap[m][0]) m = r; if (m === k) break; [heap[m], heap[k]] = [heap[k], heap[m]]; k = m } } return top }
    dist[from] = 0; push(0, from)
    while (heap.length) {
      const [d, i] = pop(); if (d > dist[i]) continue
      if (goals.has(i)) { const out: number[] = []; for (let k = i; k >= 0; k = prev[k]) out.push(k); return out.reverse() }
      const x = i % g.cols, y = (i - x) / g.cols
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        if (!dx && !dy) continue; const X = x + dx, Y = y + dy; if (X < 0 || Y < 0 || X >= g.cols || Y >= g.rows) continue
        const j = Y * g.cols + X; if (!g.walk(j) && !goals.has(j)) continue
        if (dx && dy && (!g.walk(y * g.cols + X) || !g.walk(Y * g.cols + x))) continue
        const nd = d + (dx && dy ? 1.414 : 1) * g.cost(j); if (nd < dist[j]) { dist[j] = nd; prev[j] = i; push(nd, j) }
      }
    }
    let best = -1, bd = Infinity; const fx = from % g.cols, fy = (from - fx) / g.cols   // no way round: straight to the nearest goal
    for (const k of goals) { const d = Math.hypot(k % g.cols - fx, (k - (k % g.cols)) / g.cols - fy); if (d < bd) { bd = d; best = k } }
    return best < 0 ? [from] : [from, best]
  }

  private roundOf(j: Job): Round {
    let r = this.rounds.get(j.id); if (r) return r
    const g = this.ground(), door = this.door(j.farmhouse), tiles = new Set(j.tiles)
    const out = this.route(door, tiles)
    // through the field, always on to the nearest tile not yet harvested
    const field: number[] = [out[out.length - 1]], left = new Set(j.tiles); left.delete(field[0])
    while (left.size) { const a = field[field.length - 1], ax = a % g.cols, ay = (a - ax) / g.cols; let best = -1, bd = Infinity
      for (const k of left) { const d = Math.hypot(k % g.cols - ax, (k - (k % g.cols)) / g.cols - ay); if (d < bd) { bd = d; best = k } }
      field.push(best); left.delete(best) }
    const toSilo = this.route(field[field.length - 1], this.siloSpots(j.silo))
    const home = this.route(toSilo[toSilo.length - 1], new Set([door]))
    r = { out, field, toSilo, home }; this.rounds.set(j.id, r); return r
  }

  /** Where along a walk of tiles a farmer is, a fraction of the way along it: position and heading. */
  private along(tiles: number[], f: number): [number, number, number] {
    const g = this.ground(), pts = tiles.map((i) => [i % g.cols + 0.5, (i - (i % g.cols)) / g.cols + 0.5])
    if (pts.length === 1) return [pts[0][0], pts[0][1], Math.PI / 2]
    const seg = pts.slice(1).map((p, k) => Math.hypot(p[0] - pts[k][0], p[1] - pts[k][1])), total = seg.reduce((a, b) => a + b, 0) || 1
    let d = Math.max(0, Math.min(1, f)) * total
    for (let k = 0; k < seg.length; k++) {
      if (d <= seg[k] || k === seg.length - 1) { const a = pts[k], b = pts[k + 1], u = seg[k] ? Math.min(1, d / seg[k]) : 1; return [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, Math.atan2(b[1] - a[1], b[0] - a[0])] }
      d -= seg[k]
    }
    const p = pts[pts.length - 1]; return [p[0], p[1], Math.PI / 2]
  }

  /** Where every farmer is now, from the jobs' times. */
  step(now = Date.now()) {
    const list: Farmer[] = []
    this.claimed.clear(); this.cutTiles.clear()
    for (const j of this.jobs) {
      const look = (j.farmhouse + j.worker) % 4, id = Number(j.id) || 0
      const frac = (a: number, b: number) => (b > a ? (now - a) / (b - a) : 1)
      // the crops this farmer has cut already: one tile after another through the harvest
      const r = this.roundOf(j), n = r.field.length
      const done = now >= j.harvested ? n : now >= j.atField ? Math.floor(frac(j.atField, j.harvested) * n) : 0
      r.field.forEach((i, k) => (k < done ? this.cutTiles.set(i, j.atField + ((k + 1) / n) * (j.harvested - j.atField)) : this.claimed.add(i)))
      if (now < j.start || now >= j.home) continue                                   // waiting for its turn, or home again
      let p: [number, number, number], state: Farmer['state'] = 'walk', crop: string | null = null
      if (now < j.atField) p = this.along(r.out, frac(j.start, j.atField))
      else if (now < j.harvested) { p = this.along(r.field, frac(j.atField, j.harvested)); state = 'harvest'; crop = done > 0 ? j.crop : null }
      else if (now < j.atSilo) { p = this.along(r.toSilo, frac(j.harvested, j.atSilo)); crop = j.crop }
      else if (now < j.offloaded) { p = this.along(r.toSilo, 1); state = 'drop'; crop = j.crop }
      else p = this.along(r.home, frac(j.offloaded, j.home))
      const g = this.ground(), at = Math.floor(p[1]) * g.cols + Math.floor(p[0])
      list.push({ id, look, x: p[0], y: p[1], head: p[2], state, crop, swim: state === 'walk' && g.water(at) })
    }
    this.list = list
  }
  /** Whether anything about the farmers changes with time from now on. */
  busy(now = Date.now()) { return this.jobs.some((j) => now < j.home) }
}

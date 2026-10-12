// The farmers: when crops are marked for harvest, each farmhouse sends out as many farmers as its stage (stage n, n
// farmers). A farmer takes the nearest open job, walks there (round fences, buildings and water; paths are quicker),
// harvests the tile, carries the sack to the nearest silo, then takes the next job; with none left, walks home and goes in.
import { BUILDINGS, dims, entrance, footprint, type Builds } from './build'

export interface Farmer {
  id: number; home: number; look: number
  x: number; y: number; head: number
  state: 'out' | 'toCrop' | 'harvest' | 'toSilo' | 'drop' | 'home'
  path: number[]; t: number; job: number; crop: string | null
}

/** The grid the farmers walk: which tiles they may step on, and how dear each step is. */
export interface Ground { cols: number; rows: number; walk: (i: number) => boolean; cost: (i: number) => number }

const HARVEST_S = 2.2, DROP_S = 0.7, SPEED = 1.5

export class Farmers {
  list: Farmer[] = []
  private next = 1
  /** tiles being harvested (claimed by a farmer) */
  claimed = new Set<number>()
  constructor(private ground: () => Ground, private builds: () => Builds,
    /** the harvest is in: the crop leaves its tile and goes into the store */
    private harvested: (tile: number, crop: string) => void) {}

  /** The tiles marked for harvest and not yet taken by a farmer. */
  private open() { const b = this.builds(), out: number[] = []; for (const k in b) if (b[k].h && b[k].c && !this.claimed.has(Number(k))) out.push(Number(k)); return out }
  private houses() { const b = this.builds(), out: { at: number; lv: number; door: number }[] = []
    for (const k in b) if (b[k].s === 'farmhouse') { const g = this.ground(), at = Number(k); out.push({ at, lv: b[k].lv ?? 1, door: entrance('farmhouse', at, g.cols, g.rows, b[k].o ?? 0) }) }
    return out }
  /** The tiles beside each silo a farmer can stand on to put the sack in. */
  private siloSpots() { const b = this.builds(), g = this.ground(), out = new Set<number>()
    for (const k in b) if (b[k].s === 'silo') { const at = Number(k), [w, h] = dims('silo', b[k].o), x0 = at % g.cols, y0 = (at - x0) / g.cols
      for (let y = y0 - 1; y <= y0 + h; y++) for (let x = x0 - 1; x <= x0 + w; x++) { if (x < 0 || y < 0 || x >= g.cols || y >= g.rows) continue; const i = y * g.cols + x; if (g.walk(i)) out.add(i) } }
    return out }
  hasSilo() { return this.siloSpots().size > 0 }

  /** The cheapest way from a tile to the nearest of some goal tiles (8-neighbour, no cutting corners), or null. */
  private route(from: number, goals: Set<number>): number[] | null {
    if (goals.has(from)) return [from]
    const g = this.ground(), N = g.cols * g.rows, dist = new Float64Array(N).fill(Infinity), prev = new Int32Array(N).fill(-1)   // (dist not Float32: its rounding made settled tiles look stale)
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
    return null
  }
  private go(f: Farmer, goals: Set<number>) { const g = this.ground(), from = Math.floor(f.y) * g.cols + Math.floor(f.x), p = this.route(from, goals); f.path = p ? p.slice(1) : []; return !!p }
  /** The farmer takes the nearest open job; false if none can be reached. */
  private takeJob(f: Farmer) {
    const jobs = this.open(); if (!jobs.length || !this.hasSilo()) return false
    if (!this.go(f, new Set(jobs))) return false
    const g = this.ground(), end = f.path.length ? f.path[f.path.length - 1] : Math.floor(f.y) * g.cols + Math.floor(f.x)
    f.job = end; f.crop = this.builds()[end]?.c ?? null; this.claimed.add(end); f.state = 'toCrop'; return true
  }

  step(dt: number) {
    const g = this.ground(), b = this.builds()
    // send farmers out while there are open jobs (each house up to its stage), one every second
    if (this.open().length && this.hasSilo()) for (const h of this.houses()) {
      if (h.door < 0) continue
      const out = this.list.filter((f) => f.home === h.at).length
      if (out >= h.lv) continue
      const last = this.list.filter((f) => f.home === h.at).reduce((m, f) => Math.max(m, f.id), 0)
      if (this.list.some((f) => f.id === last && f.state === 'out' && f.t < 1)) continue
      const x = h.door % g.cols + 0.5, y = (h.door - h.door % g.cols) / g.cols + 0.5
      const f: Farmer = { id: this.next++, home: h.at, look: (h.at + out) % 4, x, y: y - 0.3, head: Math.PI / 2, state: 'out', path: [], t: 0, job: -1, crop: null }
      this.list.push(f)
    }
    for (const f of [...this.list]) {
      if (!(f.home in b) || b[f.home].s !== 'farmhouse') { this.release(f); this.list.splice(this.list.indexOf(f), 1); continue }   // its house is gone
      f.t += dt
      if (f.state === 'out') { if (f.t > .6 && !this.takeJob(f)) { this.goHome(f) } continue }
      if (f.state === 'harvest') { if (f.t >= HARVEST_S) { const c = this.builds()[f.job]?.c; if (c) { this.harvested(f.job, c); f.crop = c } this.claimed.delete(f.job); f.job = -1
          if (!this.go(f, this.siloSpots())) { this.goHome(f); continue } f.state = 'toSilo'; f.t = 0 } continue }
      if (f.state === 'drop') { if (f.t >= DROP_S) { f.crop = null; f.t = 0; if (!this.takeJob(f)) this.goHome(f) } continue }
      // walking: along the path, tile centre to tile centre
      if (f.path.length) {
        const i = f.path[0], tx = i % g.cols + 0.5, ty = (i - i % g.cols) / g.cols + 0.5, dx = tx - f.x, dy = ty - f.y, d = Math.hypot(dx, dy)
        const sp = SPEED * (g.cost(Math.floor(f.y) * g.cols + Math.floor(f.x)) < 1 ? 1.25 : 1) * dt
        f.head = Math.atan2(dy, dx)
        if (d <= sp) { f.x = tx; f.y = ty; f.path.shift() } else { f.x += dx / d * sp; f.y += dy / d * sp }
        continue
      }
      // arrived
      if (f.state === 'toCrop') { if (this.builds()[f.job]?.c) { f.state = 'harvest'; f.t = 0 } else { this.claimed.delete(f.job); f.job = -1; if (!this.takeJob(f)) this.goHome(f) } }
      else if (f.state === 'toSilo') { f.state = 'drop'; f.t = 0 }
      else if (f.state === 'home') this.list.splice(this.list.indexOf(f), 1)   // in through the door
    }
  }
  private release(f: Farmer) { if (f.job >= 0) this.claimed.delete(f.job) }
  private goHome(f: Farmer) {
    this.release(f); f.job = -1; f.state = 'home'; f.t = 0
    const h = this.houses().find((q) => q.at === f.home); if (!h || h.door < 0) { f.path = []; return }
    if (!this.go(f, new Set([h.door]))) f.path = []
  }
  /** A building of this kind covers tile i. */
  static covered(b: Builds, i: number) { return b[i]?.u !== undefined }
  static footprintOf(b: Builds, at: number, cols: number) { const s = b[at]?.s; return s ? footprint(s, at, cols, b[at].o) : [] }
  static spec = BUILDINGS
}

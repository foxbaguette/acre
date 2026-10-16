// The creatures from the chain: where each lives (open grass, fresh water or the sky), how it wanders, how it keeps
// out of others' way, and which one the player picked. Ported from the old renderer; each creature starts at a spot
// seeded by its id, so it is found in the same place on every visit.
import type { Lifeform } from '@/engine/types'
import { seeded, T, type World } from './world'

/** [art folder, home, size in tiles]. Sprites face up; they are turned towards where they go. */
export const BEASTS: [string, 'air' | 'water' | 'land', number][] = [
  ['flyers__pegasus', 'air', 1.8], ['flyers__aether-jelly', 'air', 1.2], ['flyers__glass-dragonfly', 'air', 0.8], ['flyers__simurgh', 'air', 2],
  ['flyers__sky-squid', 'air', 1.4], ['flyers__crest-wyrm', 'air', 2], ['creatures__phoenix', 'air', 1.8], ['creatures__dragon', 'air', 2.4],
  ['creatures__lancer-hornet', 'air', 0.7], ['animals__owl', 'air', 0.9], ['animals__raven', 'air', 0.8], ['bugs__lantern-firefly', 'air', 0.5],
  ['dinos__aurora-pterosaur', 'air', 2], ['bone__crypt-bat', 'air', 0.9],
  ['creatures__sea-serpent', 'water', 2], ['deepsea__crystal-crab-polished', 'water', 1], ['deepsea__ember-octopus', 'water', 1.2],
  ['deepsea__leaf-dragon', 'water', 1], ['yokai__shachihoko', 'water', 1.3], ['europe__kraken', 'water', 2], ['europe__jormungandr', 'water', 2.2],
  ['europe__nessie', 'water', 2], ['mythsea__cadborosaurus', 'water', 2], ['turtles__crystal-turtle', 'water', 1.3], ['hell__skull-crab', 'water', 1],
  ['creatures__fire-salamander', 'land', 0.9], ['creatures__crystal-spider', 'land', 0.9], ['creatures__kitsune', 'land', 1.1], ['creatures__gem-scarab', 'land', 0.6],
  ['animals__redpanda', 'land', 0.9], ['animals__fox', 'land', 1], ['animals__deer', 'land', 1.4], ['felines__moon-cat', 'land', 0.9],
  ['felines__moss-ocelot', 'land', 1], ['beasts__frost-mammoth', 'land', 2.1], ['beasts__blossom-stag', 'land', 1.5], ['beasts__bone-howler', 'land', 1.3],
  ['beasts__lantern-giraffe', 'land', 1.9], ['dinos__gem-parasaurolophus', 'land', 1.9], ['dinos__thunder-diplodocus', 'land', 2.6], ['yokai__baku', 'land', 1.4],
  ['yokai__kirin', 'land', 1.6], ['orochi__gold-orochi', 'land', 1.9], ['europe__fenrir', 'land', 1.6], ['europe__black-shuck', 'land', 1.3],
  ['hell__nightmare', 'land', 1.6], ['hell__torment-ram', 'land', 1.3], ['hell__hellspinner', 'land', 1.2], ['carnivores__snow-leopard', 'land', 1.2],
  ['hoofed__camel', 'land', 1.6], ['hoofed__mountain-goat', 'land', 1.2], ['story__wind-hare', 'land', 0.7], ['rats__black-rat', 'land', 0.5],
]
export const spriteUrl = (k: string) => `art/topdown/${k}/top.svg?v=1`
export const speciesKey = (name: string) => {
  const slug = String(name || '').trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
  return BEASTS.find((b) => b[0].split('__')[1] === slug || b[0].split('__')[1] === slug + '-polished') ?? null
}

interface Area { ok: (x: number, y: number, r: number) => boolean }
export interface Creature {
  id: number | string; sprite: string; home: 'air' | 'water' | 'land'; size: number; r: number
  x: number; y: number; area: Area; tx: number; ty: number; head: number; wait: number; phase: number; speed: number; moving: boolean
  blocked?: number; since?: number; ax?: number; ay?: number
  /** the fenced area it lives in (land creatures) */
  pen?: number
}

const RECOLOURED = new Map<string, Promise<string>>()
/** The sprite with the creature's own five colours as its defaults, as a data URL. */
export function recolouredUrl(key: string, colors: string[]) {
  const id = key + '|' + colors.join(',')
  let p = RECOLOURED.get(id)
  if (!p) {
    p = fetch(spriteUrl(key)).then((r) => r.text()).then((t) => {
      colors.forEach((c, i) => { if (/^[0-9a-f]{6}$/i.test(c || '')) t = t.replace(new RegExp('(--c' + (i + 1) + ',\\s*)#[0-9A-Fa-f]{3,8}'), '$1#' + c) })
      return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(t)
    })
    RECOLOURED.set(id, p)
  }
  return p
}

export class Herd {
  list: Creature[] = []
  selected: Creature | null = null
  /** the creature the player is carrying: it stays where the pointer puts it */
  held: Creature | null = null
  private from: [number, number] = [0, 0]
  /** Picks a creature up. */
  grab(c: Creature) { this.held = c; this.from = [c.x, c.y]; c.moving = false; c.wait = 0 }
  /** Whether a creature may be set down here: its own kind of ground (land: grass, off fences and buildings; any enclosure). */
  canDrop(c: Creature, x: number, y: number) { return c.area.ok(x, y, c.r) && (c.home !== 'land' || !this.fence[this.cell(x, y)]) }
  /** Sets the carried creature down where it is, or back where it was picked up if it cannot be there. */
  drop() {
    const c = this.held; if (!c) return
    this.held = null
    if (!this.canDrop(c, c.x, c.y)) { c.x = this.from[0]; c.y = this.from[1] }
    c.tx = c.x; c.ty = c.y; c.wait = 1 + Math.random() * 2; c.blocked = 0; c.since = 0
    if (c.home === 'land') this.settle(c)                         // it now lives in the enclosure it was set down in
  }
  private ask = 0
  private world: World
  /** fence tiles, and which fenced-off area every tile belongs to (tiles split by fences; a gap joins two areas) */
  private fence: Uint8Array
  private pen: Int32Array
  constructor(world: World) { this.world = world; this.fence = new Uint8Array(world.cols * world.rows); this.pen = new Int32Array(world.cols * world.rows) }

  /** The fences changed: works out the fenced areas again; every land creature stays in the one it stands in. */
  setFences(fence: Uint8Array) {
    const w = this.world, N = w.cols * w.rows
    this.fence = fence; this.pen = new Int32Array(N).fill(-1)
    let n = 0
    for (let i0 = 0; i0 < N; i0++) {
      if (fence[i0] || this.pen[i0] >= 0) continue
      const st = [i0]; this.pen[i0] = n
      while (st.length) {
        const i = st.pop()!, x = i % w.cols, y = (i - x) / w.cols
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const X = x + dx, Y = y + dy; if (X < 0 || Y < 0 || X >= w.cols || Y >= w.rows) continue; const j = Y * w.cols + X; if (!fence[j] && this.pen[j] < 0) { this.pen[j] = n; st.push(j) } }
      }
      n++
    }
    for (const c of this.list) if (c.home === 'land') this.settle(c)
  }
  private cell(x: number, y: number) { const w = this.world; return Math.max(0, Math.min(w.rows - 1, Math.floor(y))) * w.cols + Math.max(0, Math.min(w.cols - 1, Math.floor(x))) }
  /** A creature caught on a fence steps off it to the nearest side; then it belongs to the area it is in. */
  private settle(c: Creature) {
    if (this.fence[this.cell(c.x, c.y)]) {
      const fx = Math.floor(c.x), fy = Math.floor(c.y)
      out: for (let r = 1; r <= 5; r++) for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {   // the nearest free tile, ring by ring (a building can be wide)
        if (Math.max(Math.abs(dx), Math.abs(dy)) !== r) continue
        const x = fx + dx + 0.5, y = fy + dy + 0.5; if (!this.fence[this.cell(x, y)] && c.area.ok(x, y, c.r)) { c.x = x; c.y = y; break out }
      }
    }
    c.pen = this.pen[this.cell(c.x, c.y)]; c.tx = c.x; c.ty = c.y
    // too close to a fence to move at all: step to the nearest spot in its area where it fits
    if (!this.okFor(c, c.x, c.y)) {
      let best: [number, number] | null = null, bd = Infinity
      for (let dy = -2; dy <= 2; dy += 0.25) for (let dx = -2; dx <= 2; dx += 0.25) {
        const d = dx * dx + dy * dy; if (d < bd && this.okFor(c, c.x + dx, c.y + dy)) { bd = d; best = [c.x + dx, c.y + dy] }
      }
      if (best) { c.x = c.tx = best[0]; c.y = c.ty = best[1] }
    }
  }
  /** Whether a creature may stand here: its own kind of ground, and for land creatures off the fences and in its own area. */
  private okFor(c: Creature, x: number, y: number) {
    if (!c.area.ok(x, y, c.r)) return false
    if (c.home !== 'land') return true
    const inPen = (a: number, b: number) => { const i = this.cell(a, b); return !this.fence[i] && this.pen[i] === c.pen }
    return this.ringOk(x, y, c.r * 0.8, inPen)
  }

  private typeAt(x: number, y: number) {
    const w = this.world; if (x < 0 || y < 0 || x >= w.cols || y >= w.rows) return 'edge'
    const i = Math.floor(y) * w.cols + Math.floor(x); return w.ocean[i] ? 'sea' : w.type[i]
  }
  private ringOk(x: number, y: number, r: number, ok: (x: number, y: number) => boolean) { for (let a = 0; a < 6.28; a += 0.785) if (!ok(x + Math.cos(a) * r, y + Math.sin(a) * r)) return false; return ok(x, y) }

  /** Places the creatures; resolves to the pictures to register (name -> url) and how many were placed. */
  async set(list: Lifeform[], register: (name: string, url: string) => void): Promise<number> {
    const ask = ++this.ask, w = this.world
    const woods = (x: number, y: number) => w.forest[Math.floor(y) * w.cols + Math.floor(x)]   // trees would hide them
    const grassOk = (x: number, y: number) => { const t = this.typeAt(x, y); return (t === T.grass || t === T.sand) && !woods(x, y) && !this.fence[this.cell(x, y)] }   // grass and the beaches
    const areas: Record<string, Area> = {
      land: { ok: (x, y, r) => x > 1 + r && y > 1 + r && x < w.cols - 1 - r && y < w.rows - 1 - r && this.ringOk(x, y, r, grassOk) },
      water: { ok: (x, y, r) => this.ringOk(x, y, r * 1.1, (a, b) => this.typeAt(a, b) === T.water) },
      air: { ok: (x, y) => x > 1 && y > 1 && x < w.cols - 1 && y < w.rows - 1 },
    }
    // a species' own environments, where life.acre lists them: pond (fresh water), sea, land (grass and the grassy
    // hills, out of the woods), beach (sand); off the fences, like any creature on the ground
    const tileOk = (envs: Set<string>) => (a: number, b: number) => {
      const t = this.typeAt(a, b)
      if (t === 'sea') return envs.has('sea')
      if (t === T.water) return envs.has('pond')
      if (this.fence[this.cell(a, b)]) return false
      if (t === T.sand) return envs.has('beach')
      return (t === T.grass || t === T.rock) && envs.has('land') && !woods(a, b)
    }
    const areaFor = (envs: Set<string>): Area => { const ok = tileOk(envs), dry = envs.has('land') || envs.has('beach')
      return { ok: (x, y, r) => x > 1 + r && y > 1 + r && x < w.cols - 1 - r && y < w.rows - 1 - r && this.ringOk(x, y, dry ? r : r * 1.1, ok) } }
    const made: Creature[] = []
    for (const f of list || []) {
      const b = speciesKey(f.species); if (!b) { console.warn('No sprite for species', f.species); continue }
      const scale = Math.max(0.2, (Number(f.size) || 1000) / 1000), quick = Math.max(0.1, (Number(f.speed) || 1000) / 1000)
      const size = b[2] * scale * 0.5   // half the art's listed size: they read better beside the trees and buildings
      // where it lives: its species' environments (a flyer flies wherever), else where its picture belongs
      const envs = new Set((f.environments ?? []).filter((e) => ['pond', 'sea', 'land', 'beach'].includes(e)))
      const own = envs.size > 0 && b[1] !== 'air', home: Creature['home'] = own ? (envs.has('land') || envs.has('beach') ? 'land' : 'water') : b[1]
      const r = size * 0.36, area = own ? areaFor(envs) : areas[b[1]], rnd = seeded(Number(f.id) * 7919 + 101)
      let x = w.cols / 2, y = w.rows / 2
      for (let k = 0; k < 6000; k++) { const tx = 2 + rnd() * (w.cols - 4), ty = 2 + rnd() * (w.rows - 4); if (area.ok(tx, ty, r)) { x = tx; y = ty; break } }
      const sprite = 'cre:' + b[0] + '|' + (f.colors || []).join(',')
      register(sprite, await recolouredUrl(b[0], f.colors || []))
      made.push({ id: f.id, sprite, home, size, r, x, y, area, tx: x, ty: y, head: rnd() * 6.28, wait: b[1] === 'air' ? 0 : rnd() * 3, phase: rnd() * 6.28, speed: (b[1] === 'air' ? 1.3 : 0.5) * quick, moving: false })
      if (ask !== this.ask) return 0                             // a newer list took over
    }
    this.list = made
    for (const c of made) if (c.home === 'land') this.settle(c)
    if (this.selected && !this.list.includes(this.selected)) this.selected = null
    return made.length
  }

  /** The creature under (wx, wy) in world tiles, given the view's pixels per tile (generous for small ones). */
  at(wx: number, wy: number, z: number): Creature | null {
    let best: Creature | null = null, bd = Infinity
    for (const c of this.list) {
      const lift = c.home === 'air' ? 0.9 * 0.15 : 0, d = Math.hypot(wx - c.x, wy - (c.y - lift)) * z, reach = Math.max(18, c.size * z * 0.55)
      if (d < reach && d < bd) { bd = d; best = c }
    }
    return best
  }

  step(dt: number) {
    const grid = new Map<number, Creature[]>(), key = (x: number, y: number) => Math.floor(x / 3) * 4096 + Math.floor(y / 3)   // buckets of 3x3 tiles
    for (const c of this.list) { const k = key(c.x, c.y); let b = grid.get(k); if (!b) grid.set(k, b = []); b.push(c) }
    const near = (c: Creature) => { const out: Creature[] = [], bx = Math.floor(c.x / 3), by = Math.floor(c.y / 3); for (let i = -1; i <= 1; i++) for (let j = -1; j <= 1; j++) { const b = grid.get((bx + i) * 4096 + by + j); if (b) out.push(...b) } return out }
    for (const c of this.list) {
      if (c === this.held) continue
      if (c.home === 'air') { this.fly(c, dt); continue }
      if (c.wait > 0) { c.wait -= dt; c.moving = false; if (c.wait <= 0) this.pickTarget(c); continue }
      const dx = c.tx - c.x, dy = c.ty - c.y, d = Math.hypot(dx, dy)
      if (d < 0.05) { c.wait = 1.5 + Math.random() * 5; c.moving = false; continue }
      let want = Math.atan2(dy, dx)
      const ahead = near(c).find((o) => {                       // someone in the way?
        if (o === c || o.home !== c.home) return false
        const ox = o.x - c.x, oy = o.y - c.y, od = Math.hypot(ox, oy)
        return od < c.r + o.r + 0.6 && (ox * Math.cos(want) + oy * Math.sin(want)) / (od || 1) > 0.3
      })
      if (ahead) {
        const side = ((ahead.x - c.x) * Math.sin(want) - (ahead.y - c.y) * Math.cos(want)) > 0 ? 1 : -1
        want += side * 1.1                                       // step around them on the free side
        c.blocked = (c.blocked || 0) + dt
        if (c.blocked > 1.5) { c.blocked = 0; this.pickTarget(c, Math.atan2(c.y - ahead.y, c.x - ahead.x)); continue }   // still stuck: go elsewhere
      } else c.blocked = Math.max(0, (c.blocked || 0) - dt * 0.5)
      c.since = (c.since || 0) + dt                             // watchdog: barely moved for 2 s means pause, then find another goal
      if (Math.hypot(c.x - (c.ax ?? c.x), c.y - (c.ay ?? c.y)) > 0.15) { c.ax = c.x; c.ay = c.y; c.since = 0 }
      else if (c.since > 2) { c.since = 0; c.ax = c.x; c.ay = c.y; c.wait = 0.6 + Math.random(); c.moving = false; continue }
      const turn = ((want - c.head + 9.42478) % 6.28318) - 3.14159   // turn smoothly before and while walking
      c.head += Math.max(-dt * 3, Math.min(dt * 3, turn))
      const facing = Math.max(0, Math.cos(turn)), step = Math.min(d, c.speed * dt * facing * Math.min(1, d * 1.5 + 0.3))
      const nx = c.x + Math.cos(c.head) * step, ny = c.y + Math.sin(c.head) * step
      if (this.okFor(c, nx, ny)) { c.x = nx; c.y = ny }
      else { const sx = c.x + dx / d * step, sy = c.y + dy / d * step     // the side-step hit a wall: try straight on, else rethink
        if (step > 0 && this.okFor(c, sx, sy)) { c.x = sx; c.y = sy } else this.pickTarget(c) }
      c.moving = step > 0.001
    }
    for (const a of this.list) for (const b of near(a)) {         // keep a little personal space (each pair once)
      if (a === this.held || b === this.held) continue
      if (b === a || a.home !== b.home || (a.x < b.x || (a.x === b.x && a.y <= b.y))) continue
      const dx = b.x - a.x, dy = b.y - a.y, d = Math.hypot(dx, dy) || 0.01, min = a.r + b.r
      if (d < min) { const push = (min - d) * 0.5 * Math.min(1, dt * 4), ux = dx / d, uy = dy / d
        if (this.okFor(a, a.x - ux * push, a.y - uy * push)) { a.x -= ux * push; a.y -= uy * push }
        if (this.okFor(b, b.x + ux * push, b.y + uy * push)) { b.x += ux * push; b.y += uy * push } }
    }
  }

  private fly(c: Creature, dt: number) {                        // flyers glide on without ever stopping, curving gently towards a new goal
    c.wait = 0; c.moving = true
    let dx = c.tx - c.x, dy = c.ty - c.y
    if (Math.hypot(dx, dy) < 1.5) { this.pickTarget(c, c.head); dx = c.tx - c.x; dy = c.ty - c.y }
    const turn = ((Math.atan2(dy, dx) - c.head + 9.42478) % 6.28318) - 3.14159
    c.head += Math.max(-dt * 1.2, Math.min(dt * 1.2, turn))
    const step = c.speed * dt * (0.65 + 0.35 * (Math.cos(turn) + 1) / 2)
    const nx = c.x + Math.cos(c.head) * step, ny = c.y + Math.sin(c.head) * step
    if (c.area.ok(nx, ny, c.r)) { c.x = nx; c.y = ny }
    else { this.pickTarget(c, Math.atan2(this.world.rows / 2 - c.y, this.world.cols / 2 - c.x)); if (c.area.ok(nx, c.y, c.r)) c.x = nx; else if (c.area.ok(c.x, ny, c.r)) c.y = ny }
  }

  private pickTarget(c: Creature, away?: number) {               // away: a preferred direction, e.g. away from a creature in the way
    const reach = c.home === 'air' ? 8 : 3
    for (let k = 0; k < 20; k++) {
      const a = away !== undefined && k < 12 ? away + (Math.random() - 0.5) * 1.6 : Math.random() * 6.28, d = 0.5 + Math.random() * reach, tx = c.x + Math.cos(a) * d, ty = c.y + Math.sin(a) * d
      let ok = true; for (let s = 1; s <= 6 && ok; s++) ok = this.okFor(c, c.x + (tx - c.x) * s / 6, c.y + (ty - c.y) * s / 6)
      if (ok) { c.tx = tx; c.ty = ty; return }
    }
    c.tx = c.x; c.ty = c.y; c.wait = 1
  }
}

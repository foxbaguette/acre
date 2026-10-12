// The island on the GPU (WebGL2): the game page's only renderer (its interface is in types.ts).
//
//   world.ts      the island as data, seeded from the map id
//   fields.ts     soft edge fields for every ground, the shore and the mountain levels
//   ground.ts     the ground baked into cached chunks per detail level (decor baked in)
//   atlas.ts      sprite pictures rasterised on demand into texture-array pages
//   sprites.ts    one instanced batch for everything standing or moving
//   creatures.ts  the chain's creatures: placement, wandering, selection
import type { Daytime, IslandView, Lifeform, Weather } from '@/engine/types'
import { Atlas } from './atlas'
import { applyBuilds, BUILDINGS, buildingTiles, cropStage, dims, entrance, erasable, erase, eraseKindAt, footprint, placeBuilding, turn, type Building, type EraseKind, MIN_ENCLOSURE, pristineOf, ring, rules, type Builds, type BuildTool } from './build'
import { CHIMNEYS, FOUNTAINS, LIGHTS, LIT, PAD, RENDERED, SHPAD } from './buildingArt'
import { CROPS } from './crops'
import { Farmers } from './farmers'
import { BEASTS, Herd, speciesKey } from './creatures'
import { buildFields } from './fields'
import { Ground } from './ground'
import { cloudShapes, DAYS, Sky, WX } from './sky'
import { FIELD, FIELD_REACH, FLAG, SHAPE, Sprites } from './sprites'
import { buildWorld, COLS, ROWS, seeded, T, type World } from './world'

export interface EngineOptions { tiles: Uint8Array; mapId: string | number; weather?: Weather; daytime?: Daytime; view?: HTMLElement; /** the player's builds, laid over the map */ builds?: Builds }

/** Small machines get fewer pixels and a smaller cache from the start. */
const LOW = !!(((navigator as { deviceMemory?: number }).deviceMemory ?? 8) <= 4 || (navigator.hardwareConcurrency || 8) <= 2)


// a butterfly from above, as the old renderer painted it: shadow below, two wings a side, a body (s = one unit, 192 px canvas)
const FLY_COLOURS = [['#FFFFFF', '#F3E9C8'], ['#F6D04D', '#E8A93A'], ['#F2A7C3', '#E07AA3'], ['#A9D4F5', '#6FAEE0']]
const FLY_STAGES = 8
/** Crops with painted field tiles (tools/painted-crops.mjs): they fill their tile so a planted patch reads as one field. */
const PAINTED_CROPS = new Set<string>(CROPS)
const cropSeed = (c: string) => { let h = 7; for (const ch of c) h = (h * 31 + ch.charCodeAt(0)) % 997; return h % 4 }
function paintFly(g: CanvasRenderingContext2D, px: number, flap: number, c: string[]) {
  const k = px / 192, x = 96 * k, y = 48 * k, s = 32 * k
  g.fillStyle = 'rgba(30,50,20,.18)'; g.beginPath(); g.ellipse(x + s * 1.2, y + s * 2.2, s * flap, s * 0.5, 0, 0, 6.2832); g.fill()
  for (const side of [-1, 1]) {
    g.fillStyle = c[0]; g.beginPath(); g.moveTo(x, y); g.lineTo(x + side * s * 1.3 * flap, y - s * 1.1); g.lineTo(x + side * s * 1.1 * flap, y + s * 0.2); g.closePath(); g.fill()
    g.fillStyle = c[1]; g.beginPath(); g.moveTo(x, y); g.lineTo(x + side * s * 0.9 * flap, y + s * 0.2); g.lineTo(x + side * s * 0.6 * flap, y + s * 0.9); g.closePath(); g.fill()
  }
  g.fillStyle = '#3A2A1E'; g.fillRect(x - s * 0.12, y - s * 0.6, s * 0.24, s * 1.3)
}
const SHADE: [number, number, number] = [20 / 255, 40 / 255, 15 / 255]

export function startEngine(opts: EngineOptions): IslandView {
  const view = opts.view ?? document.getElementById('view')!
  const canvas = document.createElement('canvas')
  canvas.className = 'gl-scene'
  canvas.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:block'
  view.prepend(canvas)
  const gl = canvas.getContext('webgl2', { antialias: false, alpha: false, depth: false, stencil: false, powerPreference: 'high-performance' })
  if (!gl) throw new Error('This browser does not offer WebGL2.')
  gl.getExtension('EXT_color_buffer_float'); gl.getExtension('EXT_texture_filter_anisotropic'); gl.getExtension('OES_texture_float_linear')

  const t0 = performance.now()
  const world: World = buildWorld(opts.tiles, Number(opts.mapId))
  const t1 = performance.now()
  const fields = buildFields(world, LOW ? 6 : 8)
  // the player's builds, over the island as the chain made it; saved ones the map no longer allows are left out
  const pristine = pristineOf(world)
  const mountainAt = (i: number) => fields.tex[1][(Math.min(fields.h - 1, Math.round(((i / COLS | 0) + 0.5) * fields.S)) * fields.w + Math.min(fields.w - 1, Math.round(((i % COLS) + 0.5) * fields.S))) * 4 + 3]
  // builds is the plan: what stands, with what the player marked and has not confirmed yet; done is what stands. The
  // plan is judged on planWorld, the island as the plan would leave it; the island on screen shows what stands.
  let builds: Builds = {}
  const planWorld: World = { ...world, type: world.type.slice(), tile: world.tile.slice(), forest: world.forest.slice(), has: world.has.slice(), trees: world.trees.slice(), decor: world.decor.slice() }
  const can = rules(planWorld, () => builds, mountainAt)
  for (const k in opts.builds ?? {}) if (can.open(Number(k))) builds[Number(k)] = { ...opts.builds![Number(k)] }
  for (const k in builds) { const b = builds[k], top = b.u !== undefined ? opts.builds?.[b.u] : undefined   // a building of a kind that is gone (the windmill) goes too
    if (b.u !== undefined && (!top?.s || !(top.s in BUILDINGS))) { delete b.u; delete b.s; delete b.lv; delete b.o; delete b.l; if (!Object.keys(b).length) delete builds[k] } }
  let done: Builds = JSON.parse(JSON.stringify(builds))
  let fence = applyBuilds(world, pristine, done), planFence = applyBuilds(planWorld, pristine, builds)
  if (Object.values(done).some((b) => b.g)) { setDoors(); fields.refreshGrounds() }
  // ---------- the harvest: crops marked for it, the farmers who bring it in, the store in the silos ----------
  const STORE_KEY = 'ua-store-' + opts.mapId
  let store: Record<string, number> = {}
  try { store = JSON.parse(localStorage.getItem(STORE_KEY) ?? '{}') } catch { store = {} }
  let onStore: ((s: Record<string, number>) => void) | null = null
  const both = (fn: (b: Builds) => void) => { fn(done); fn(builds) }      // the harvest is not a plan: it changes what stands and the plan alike
  const farmers = new Farmers(() => {
    const blocked = walls()
    return { cols: COLS, rows: ROWS,
      walk: (i) => !world.ocean[i] && world.type[i] !== T.water && !blocked[i],
      cost: (i) => (world.type[i] === T.path ? 0.6 : done[i]?.c ? 1.15 : 1) }
  }, () => done, (tile, crop) => {
    both((b) => { const c = b[tile]; if (c) { delete c.c; delete c.t; delete c.h } })
    store[crop] = (store[crop] ?? 0) + 1
    try { localStorage.setItem(STORE_KEY, JSON.stringify(store)) } catch { /* only for this visit */ }
    onStore?.({ ...store }); relay(null)
  })
  const ripe = (i: number) => !!done[i]?.c && cropStage(done[i].t ?? 0, Date.now()) === '6-harvest'
  /** The ripe tiles of the same crop joined to this one (the field it belongs to). */
  const fieldOf = (i: number) => { const c = done[i]?.c, out = new Set<number>([i]), st = [i]
    while (st.length) { const k = st.pop()!, x = k % COLS, y = (k - x) / COLS
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const X = x + dx, Y = y + dy; if (X < 0 || Y < 0 || X >= COLS || Y >= ROWS) continue; const j = Y * COLS + X; if (!out.has(j) && done[j]?.c === c && ripe(j)) { out.add(j); st.push(j) } } }
    return [...out] }
  // ripe ripeList: joined ripe tiles of one crop, worked out every half second (crops ripen as time goes by)
  interface Field { key: string; crop: string; tiles: number[]; open: number; marked: number; x: number; y: number }
  let ripeList: Field[] = [], fieldsAt = 0, hoverField: Field | null = null
  function ripeFields(): Field[] {
    const now = Date.now(); if (now - fieldsAt < 500) return ripeList; fieldsAt = now
    const seenT = new Set<number>(), out: Field[] = []
    for (const k in done) { const i0 = Number(k); if (seenT.has(i0) || !ripe(i0)) continue
      const c = done[i0].c!, tiles: number[] = [], st = [i0]; seenT.add(i0)
      while (st.length) { const i = st.pop()!; tiles.push(i); const x = i % COLS, y = (i - x) / COLS
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const X = x + dx, Y = y + dy; if (X < 0 || Y < 0 || X >= COLS || Y >= ROWS) continue; const j = Y * COLS + X; if (!seenT.has(j) && done[j]?.c === c && ripe(j)) { seenT.add(j); st.push(j) } } }
      const open = tiles.filter((i) => !done[i].h).length, xs = tiles.map((i) => i % COLS), ys = tiles.map((i) => (i - (i % COLS)) / COLS)
      out.push({ key: c + ':' + Math.min(...tiles), crop: c, tiles, open, marked: tiles.length - open, x: xs.reduce((a, b) => a + b, 0) / xs.length + 0.5, y: ys.reduce((a, b) => a + b, 0) / ys.length + 0.5 })   // the field's middle
    }
    return (ripeList = out)
  }
  const tokenLayer = document.createElement('div'); tokenLayer.className = 'field-tokens'; view.append(tokenLayer)
  const tokens = new Map<string, HTMLButtonElement>()
  const SICKLE = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M5 19l5-5"/><path d="M10 14c1-6 6-9 10-8-3 1-6 4-6 8"/></svg>'
  function placeTokens() {
    const list = ripeFields(), live = new Set<string>(), z = CAM.z
    for (const f of list) {
      if (!f.open && !f.marked) continue
      live.add(f.key); let el = tokens.get(f.key)
      if (!el) { el = document.createElement('button'); el.type = 'button'; el.className = 'field-token'; el.innerHTML = '<span class="tok">' + SICKLE + '</span><span class="n"></span><span class="note"></span><span class="stem"></span>'
        const key = f.key
        el.addEventListener('pointerdown', (e) => e.stopPropagation())
        el.addEventListener('click', (e) => { e.stopPropagation(); const fl = ripeList.find((q) => q.key === key); if (fl && fl.open) { harvestTiles(fl.tiles); fieldsAt = 0 } })
        el.addEventListener('pointerenter', () => { hoverField = ripeList.find((q) => q.key === key) ?? null; kick() })
        el.addEventListener('pointerleave', () => { hoverField = null; kick() })
        tokenLayer.append(el); tokens.set(f.key, el) }
      const working = !f.open
      el.classList.toggle('working', working); el.classList.toggle('far', z < 16)
      el.querySelector('.n')!.textContent = String(working ? f.marked : f.open)
      el.querySelector('.note')!.textContent = working ? 'being harvested' : `harvest the ${f.crop.replace(/-/g, ' ')} · ${f.open} tile${f.open === 1 ? '' : 's'}`
      el.setAttribute('aria-label', working ? `${f.crop} being harvested` : `Harvest the ${f.crop}, ${f.open} tiles`)
      el.style.transform = `translate(${(f.x - CAM.x) * z}px, ${(f.y - CAM.y) * z}px)`
    }
    for (const [k, el] of tokens) if (!live.has(k)) { el.remove(); tokens.delete(k); if (hoverField?.key === k) hoverField = null }
  }
  // the enclosures land.acre keeps: a small paper tag in the middle of each, with its number and size. Its tiles are
  // found from its first tile over what stands now (not reached past a fence); one that is not closed here is not shown.
  const penLayer = document.createElement('div'); penLayer.className = 'pen-tags'; view.append(penLayer)
  let pens: { id: string; tiles: number; at: number; el: HTMLDivElement; x: number; y: number }[] = []
  function penMiddle(at: number): [number, number] | null {
    if (done[at]?.f) return null
    const seenP = new Set([at]), st = [at]; let sx = 0, sy = 0, n = 0
    while (st.length) { const j = st.pop()!, x = j % COLS, y = (j - x) / COLS; sx += x; sy += y; n++
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const X = x + dx, Y = y + dy; if (X < 0 || Y < 0 || X >= COLS || Y >= ROWS) return null   // it reaches the edge: open
        const k = Y * COLS + X; if (!seenP.has(k) && !done[k]?.f) { seenP.add(k); st.push(k) } } }
    return [sx / n + 0.5, sy / n + 0.5]
  }
  const setEnclosures = (list: { id: string; tiles: number; at: number }[]) => {
    for (const p of pens) p.el.remove()
    pens = []
    for (const e of list) { const m = penMiddle(e.at); if (!m) continue
      const el = document.createElement('div'); el.className = 'pen-tag'
      el.innerHTML = '<b></b><small></small>'; el.querySelector('b')!.textContent = 'enclosure no. ' + e.id; el.querySelector('small')!.textContent = e.tiles + ' tile' + (e.tiles === 1 ? '' : 's')
      penLayer.append(el); pens.push({ ...e, el, x: m[0], y: m[1] }) }
    kick()
  }
  function placePens() { const z = CAM.z
    penLayer.classList.toggle('far', z < 10)
    for (const p of pens) p.el.style.transform = `translate(${(p.x - CAM.x) * z}px, ${(p.y - CAM.y) * z}px)` }
  const harvestTiles = (tiles: number[]) => { both((b) => { for (const i of tiles) if (b[i]?.c && ripe(i)) b[i].h = 1 }); relay(null) }
  const harvest = (tile: number, whole: boolean) => { const tiles = whole ? fieldOf(tile) : [tile]
    both((b) => { for (const i of tiles) if (b[i]?.c) b[i].h = 1 }); relay(null) }
  const unharvest = (tile: number, whole: boolean) => { const tiles = whole ? fieldOf(tile) : [tile]
    both((b) => { for (const i of tiles) if (b[i] && !farmers.claimed.has(i)) delete b[i].h }); relay(null) }
  const t2 = performance.now()
  const ground = new Ground(gl, world, fields, LOW ? 256 : 512, LOW)
  { const q = new URLSearchParams(location.search).get('ground'); if (q) q.split(',').forEach((v, k) => { if (k < 4) ground.look[k] = Number(v) || 0 }) }   // ?ground=path,soil,rock: try a look
  const atlas = new Atlas(gl, LOW ? 4 : 8)
  const sprites = new Sprites(gl)
  const herd = new Herd(world)
  const walls = () => { const b = buildingTiles(done, fence.length); for (let i = 0; i < b.length; i++) b[i] |= fence[i]; return b }   // what creatures cannot cross
  herd.setFences(walls())
  const sky = new Sky(gl)
  const CLOUD = cloudShapes()
  const stats = { worldMs: t1 - t0, fieldsMs: t2 - t1, fps: 0, frames: 0, at: 0, frameMs: 0, sprites: 0 }
  const state = { weather: (opts.weather ?? 'sun') as Weather, daytime: (opts.daytime ?? 'day') as Daytime, motion: !matchMedia('(prefers-reduced-motion: reduce)').matches }

  // ---------- the sea floor: coral reefs in the shallows, now and then a shipwreck further out. Not every island has
  // them; whether it does, how many and where all follow from the map id, so they can always be worked out again. ----------
  const seabed: { name: string; x: number; y: number; w: number; h: number; rot: number; tint?: [number, number, number] }[] = []
  {
    const R = seeded(Number(opts.mapId) * 104729 + 7), dist = new Int16Array(COLS * ROWS).fill(-1), q: number[] = []
    for (let i = 0; i < COLS * ROWS; i++) if (!world.ocean[i]) { dist[i] = 0; q.push(i) }
    for (let h = 0; h < q.length; h++) { const i = q[h], x = i % COLS, y = (i - x) / COLS
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const X = x + dx, Y = y + dy; if (X < 0 || Y < 0 || X >= COLS || Y >= ROWS) continue; const j = Y * COLS + X; if (dist[j] < 0) { dist[j] = dist[i] + 1; q.push(j) } } }
    const band = (lo: number, hi: number) => { const out: number[] = []; for (let i = 0; i < COLS * ROWS; i++) if (dist[i] >= lo && dist[i] <= hi) out.push(i); return out }
    const place = (cands: number[], name: string, w: number, h: number, apart: number) => {
      for (let k = 0; k < 40 && cands.length; k++) {
        const i = cands[Math.floor(R() * cands.length)], x = i % COLS + 0.5, y = Math.floor(i / COLS) + 0.5
        if (seabed.some((s) => Math.hypot(s.x - x, s.y - y) < apart)) continue
        seabed.push({ name, x, y, w, h, rot: (R() - 0.5) * 1.2 }); return
      }
    }
    // the corals' own colours, very muted (each multiplies the plate's grey-green)
    const CORAL: [number, number, number][] = [[1.7, 0.86, 0.82], [1.6, 1.18, 0.7], [1.2, 0.86, 1.4], [1.65, 1.02, 0.76], [0.92, 1.15, 0.95], [1.4, 0.95, 1.1]]
    const shallows = band(5, 9), open = band(7, 13), WRECKS = ['sloop', 'brig', 'longship']
    const wr = R(); if (wr < 0.4) { const n = wr < 0.08 ? 2 : 1; for (let k = 0; k < n; k++) place(open, 'sea-wreck-' + WRECKS[Math.floor(R() * WRECKS.length)], 6.2, 4.48, 16) }
    // table-coral reefs: not a fixed picture but a patch of any size, small or wide, grown plate by plate over the sea
    // floor: plates crowd toward its middle, thin out at its edge, and never reach onto land
    if (R() < 0.7) for (let n = 1 + Math.floor(R() * 3), k = 0; k < n; k++) {
      const i = shallows[Math.floor(R() * shallows.length)]; if (i === undefined) break
      const cx = i % COLS + 0.5, cy = Math.floor(i / COLS) + 0.5
      if (seabed.some((s) => Math.hypot(s.x - cx, s.y - cy) < 10)) continue
      const rx = 1.2 + Math.pow(R(), 1.6) * 6.5, ry = rx * (0.55 + R() * 0.45), turn = R() * Math.PI, lobes = [0, 1, 2].map(() => [R() * 6.28, 0.12 + R() * 0.22, 2 + Math.floor(R() * 3)])
      const reach = (x: number, y: number) => { const u = x - cx, v = y - cy, a = Math.cos(turn) * u + Math.sin(turn) * v, b = -Math.sin(turn) * u + Math.cos(turn) * v, ang = Math.atan2(b / ry, a / rx)
        return Math.hypot(a / rx, b / ry) / (1 + lobes.reduce((t, [p, m, f]) => t + Math.sin(ang * f + p) * m, 0)) }   // < 1: inside the patch
      const plates = Math.round(rx * ry * 5.5)
      for (let tries = 0, made = 0; made < plates && tries < plates * 8; tries++) {
        const x = cx + (R() * 2 - 1) * rx * 1.4, y = cy + (R() * 2 - 1) * rx * 1.4, d = reach(x, y), j = Math.floor(y) * COLS + Math.floor(x)
        if (d > 1 || R() < d * d * 0.75 || !world.ocean[j] || dist[j] < 3) continue   // well clear of the surf
        const r = (0.22 + R() * 0.38) * (1.15 - d * 0.5)
        seabed.push({ name: 'sea-plate-' + (1 + Math.floor(R() * 5)), x, y, w: r * 2.67, h: r * 2.67, rot: R() * 6.28, tint: CORAL[Math.floor(R() * CORAL.length)] }); made++
      }
    }
    seabed.sort((a, b) => a.y - b.y)                             // plates further down lie over those above
    for (const name of new Set(seabed.map((s) => s.name))) atlas.add(name, 'art/tiles/' + name + '.png?v=1')
  }
  // ---------- whales: a very few, out where the sea is deep, wandering slowly; now and then one blows ----------
  const deep: number[] = []
  {
    const dist = new Int16Array(COLS * ROWS).fill(-1), q: number[] = []
    for (let i = 0; i < COLS * ROWS; i++) if (!world.ocean[i]) { dist[i] = 0; q.push(i) }
    for (let h = 0; h < q.length; h++) { const i = q[h], x = i % COLS, y = (i - x) / COLS
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const X = x + dx, Y = y + dy; if (X < 0 || Y < 0 || X >= COLS || Y >= ROWS) continue; const j = Y * COLS + X; if (dist[j] < 0) { dist[j] = dist[i] + 1; q.push(j) } } }
    for (let i = 0; i < COLS * ROWS; i++) if (dist[i] >= 6) deep.push(i)
  }
  const deepSet = new Uint8Array(COLS * ROWS); for (const i of deep) deepSet[i] = 1
  const deepAt = (x: number, y: number) => { const X = Math.floor(x), Y = Math.floor(y); return X >= 0 && Y >= 0 && X < COLS && Y < ROWS && deepSet[Y * COLS + X] === 1 }
  const pickDeep = () => { const i = deep[Math.floor(Math.random() * deep.length)]; return [i % COLS + 0.5, Math.floor(i / COLS) + 0.5] }
  const whales = deep.length < 60 ? [] : [...Array(Math.min(3, 1 + Math.floor(deep.length / 600)))].map(() => { const [x, y] = pickDeep(), [tx, ty] = pickDeep(); return { x, y, tx, ty, head: Math.random() * 6.28, blow: 8 + Math.random() * 20, phase: Math.random() * 6.28 } })
  // a place to swim to that can be reached in a straight line through deep water
  const clearTo = (x: number, y: number, tx: number, ty: number) => { const n = Math.ceil(Math.hypot(tx - x, ty - y) * 2); for (let k = 1; k <= n; k++) if (!deepAt(x + (tx - x) * k / n, y + (ty - y) * k / n)) return false; return true }
  const retarget = (w: { x: number; y: number; tx: number; ty: number }) => { for (let k = 0; k < 40; k++) { const [tx, ty] = pickDeep(); if (Math.hypot(tx - w.x, ty - w.y) > 6 && clearTo(w.x, w.y, tx, ty)) { w.tx = tx; w.ty = ty; return } } }
  whales.forEach(retarget)
  const stepWhales = (dt: number) => {
    for (const w of whales) {
      if (Math.hypot(w.tx - w.x, w.ty - w.y) < 2) retarget(w)
      // steer for the target, but away from shallows ahead: feel 3 tiles ahead to each side
      let turn = Math.atan2(w.ty - w.y, w.tx - w.x) - w.head; turn = Math.atan2(Math.sin(turn), Math.cos(turn))
      const ahead = (a: number, d: number) => deepAt(w.x + Math.cos(w.head + a) * d, w.y + Math.sin(w.head + a) * d)
      if (!ahead(0, 3)) turn = ahead(0.7, 3) || !ahead(-0.7, 3) ? 1 : -1
      w.head += Math.max(-0.35 * dt, Math.min(0.35 * dt, turn))
      const nx = w.x + Math.cos(w.head) * 0.45 * dt, ny = w.y + Math.sin(w.head) * 0.45 * dt
      if (deepAt(nx, ny)) { w.x = nx; w.y = ny } else { w.head += 0.6 * dt; retarget(w) }   // blocked: turn on the spot until the way is open
      w.blow -= dt; if (w.blow < -3) w.blow = 15 + Math.random() * 30
    }
  }
  // the pictures: trees, decor, butterflies (creatures are added when they arrive)
  atlas.add('whale', 'art/tiles/whale.svg?v=1')
  for (const n of ['farmer-1', 'farmer-2', 'farmer-3', 'farmer-4', 'farmer-sack']) atlas.add(n, `art/tiles/${n}.svg?v=1`)
  for (let m = 0; m < 16; m++) { const n = `fence-${m.toString(2).padStart(4, '0')}`; atlas.add(n, `art/tiles/${n}.svg?v=2`) }
  // a meadow patch: one of four versions, turned, mirrored and sized by where it lies, so no two neighbours look alike
  const spot = (d: { x: number; y: number }, k: number) => { const h = Math.sin(d.x * 12.9898 + d.y * 78.233 + k * 37.719) * 43758.5453; return h - Math.floor(h) }
  const decorArt = (d: { name: string; x: number; y: number }) => (d.name.startsWith('decor-meadow') ? `${d.name}-${1 + Math.floor(spot(d, 1) * 4)}` : d.name)
  for (const d of new Set(world.decor.map(decorArt))) atlas.add(d, `art/tiles/${d}.svg?v=2`)
  FLY_COLOURS.forEach((c, ci) => { for (let i = 0; i < FLY_STAGES; i++) atlas.add(`fly-${ci}-${i}`, (g, px) => paintFly(g, px, 0.25 + 0.75 * (i + 0.5) / FLY_STAGES, c)) })

  // decor is baked into the ground: meadow carpets after the grass, the rest after the other grounds
  const decorIn = (region: [number, number, number]) => { const [x0, y0, n] = region; return world.decor.filter((d) => d.x > x0 - 2 && d.x < x0 + n + 2 && d.y > y0 - 2 && d.y < y0 + n + 2) }
  ground.canBake = (region, L) => { let ok = true; for (const d of decorIn(region)) if (!atlas.ready(decorArt(d), d.sc * L)) ok = false; return ok }
  ground.decor = (stage, region, L, S) => {
    sprites.begin()
    for (const d of decorIn(region)) {
      if (d.under !== (stage === 0) || (d.name === 'decor-lily') !== (stage === 2)) continue
      const r = atlas.get(decorArt(d), d.sc * L); if (!r) continue
      if (d.name.startsWith('decor-meadow')) { const s = d.sc * (0.85 + spot(d, 2) * 0.4); sprites.picture(r, d.x + 0.5, d.y + 0.5, [-s / 2, -s / 2, s / 2, s / 2], { rot: spot(d, 3) * 6.2832, sx: spot(d, 4) < 0.5 ? -1 : 1 }) }
      else sprites.picture(r, d.x + 0.5, d.y + 0.5, [-d.sc / 2, -d.sc / 2, d.sc / 2, d.sc / 2])
    }
    gl.viewport(0, 0, S, S)
    sprites.draw(atlas.tex, ground.height, ground.fieldSize, [world.cols, world.rows], { x: region[0], y: region[1], z: L }, S, S, { flip: false })
  }

  // ---------- camera: z = CSS pixels per tile, x/y = the world tile at the view's top-left ----------
  const CAM = { z: 0, x: 0, y: 0 }
  const dpr = () => Math.min(window.devicePixelRatio || 1, LOW ? 1 : 1.5)
  const zMin = () => Math.min(view.clientWidth / COLS, view.clientHeight / ROWS)
  const zMax = 260
  const clampCam = () => {
    const vw = view.clientWidth / CAM.z, vh = view.clientHeight / CAM.z
    CAM.x = vw >= COLS ? (COLS - vw) / 2 : Math.min(Math.max(CAM.x, 0), COLS - vw)
    CAM.y = vh >= ROWS ? (ROWS - vh) / 2 : Math.min(Math.max(CAM.y, 0), ROWS - vh)
  }
  const zoomNow = (f: number, px: number, py: number) => {
    const z = Math.min(zMax, Math.max(zMin(), CAM.z * f)); if (z === CAM.z) return
    const wx = CAM.x + px / CAM.z, wy = CAM.y + py / CAM.z
    CAM.z = z; CAM.x = wx - px / z; CAM.y = wy - py / z; clampCam(); kick()
  }
  const ZOOM = { target: 0, px: 0, py: 0, active: false }
  const zoomTo = (z: number, px: number, py: number) => { ZOOM.target = Math.min(zMax, Math.max(zMin(), z)); ZOOM.px = px; ZOOM.py = py; ZOOM.active = true; kick() }
  const zoomAt = (f: number, px: number, py: number) => zoomTo((ZOOM.active ? ZOOM.target : CAM.z) * f, px, py)
  const fit = () => { CAM.z = zMin(); CAM.x = 0; CAM.y = 0; clampCam(); kick() }
  const frameIsland = () => {                                   // frame the land, with a little sea around it
    let x0 = COLS, y0 = ROWS, x1 = 0, y1 = 0
    for (let i = 0; i < COLS * ROWS; i++) { if (world.ocean[i]) continue; const x = i % COLS, y = (i - x) / COLS; x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y) }
    if (x1 < x0) return fit()
    const W = view.clientWidth, H = view.clientHeight
    CAM.z = Math.max(zMin(), Math.min(W / (x1 - x0 + 14), H / (y1 - y0 + 14))); CAM.x = (x0 + x1 + 1) / 2 - W / CAM.z / 2; CAM.y = (y0 + y1 + 1) / 2 - H / CAM.z / 2; clampCam(); kick()
  }

  // ---------- the scene, one batch of sprites a frame ----------
  /** Fills the sprite batch for this frame; returns where its parts begin: [land, flyers, clouds, light, glows, end]. */
  function buildScene(t: number, dt: number, cam: { x: number; y: number; z: number }, W: number, H: number): number[] {
    const z = cam.z, x0 = cam.x - 3, y0 = cam.y - 3, x1 = cam.x + W / z + 3, y1 = cam.y + H / z + 3
    const seen = (x: number, y: number, m = 0) => x > x0 - m && y > y0 - m && x < x1 + m && y < y1 + m
    const still = !state.motion
    sprites.begin()
    const halo = (c: { x: number; y: number; size: number }, y: number) => { const rx = c.size * 0.62; sprites.shape(SHAPE.halo, c.x, y, rx * 1.25, rx * 0.82 * 1.25, [still ? 1 : 0, Math.max(1.5 / (rx * z), 0.045), 0, 1]) }
    const body = (c: typeof herd.list[number], y: number, flags: number) => {
      const r = atlas.get(c.sprite, c.size * z); if (!r) return
      const breathe = still ? 1 : 1 + 0.015 * Math.sin(t * 2 + c.phase), bob = still || !c.moving ? 0 : Math.abs(Math.sin(t * 8 + c.phase))
      const f = falling(c)
      sprites.picture(r, c.x, y - f.h, [-c.size / 2, -c.size / 2, c.size / 2, c.size / 2], { rot: c.head + Math.PI / 2, sx: breathe * (1 - bob * 0.03) * f.sx, sy: breathe * (1 + bob * 0.05) * f.sy, flags })
    }
    // a creature just set down: it drops from where it was held, lands with a squash and a little bounce, and dust puffs
    // up round it. h: how high it still is (tiles), sx, sy: its squash
    const falling = (c: typeof herd.list[number]) => {
      const t0 = drops.get(c); if (t0 === undefined) return { h: 0, sx: 1, sy: 1 }
      const a = t - t0, H = liftOf(c), T1 = Math.sqrt(2 * H / 9), T2 = 0.18   // 9 tiles/s² to the ground, then one small hop
      if (a > T1 + T2 + 0.25) { drops.delete(c); return { h: 0, sx: 1, sy: 1 } }
      if (a < T1) return { h: H - 4.5 * a * a, sx: 0.96, sy: 1.06 }      // falling: stretched a touch
      const b = a - T1, land = Math.exp(-b * 14)
      const h = b < T2 ? 0.07 * Math.sin(Math.PI * b / T2) : 0
      return { h, sx: 1 + 0.22 * land, sy: 1 - 0.2 * land }
    }
    for (const [c, t0] of drops) { const a = t - Math.sqrt(2 * liftOf(c) / 9) - t0
      if (a > 0 && a < 0.5) for (let k = 0; k < 6; k++) { const s = Math.max(c.size, 0.7), ang = k / 6 * 6.283 + c.phase, d = s * (0.3 + a * 1.2), rr = s * (0.1 + a * 0.3)
        sprites.shape(SHAPE.puff, c.x + Math.cos(ang) * d, c.y + c.size * 0.15 + Math.sin(ang) * d * 0.55, rr, rr * 0.75, [0.82, 0.76, 0.62, (1 - a / 0.5) * 0.45]) } }
    if (drops.size) kick()
    // whales below the surface; when one blows: it rises, and a spout of spray
    for (const w of whales) if (seen(w.x, w.y, 4)) {
      const r = atlas.get('whale', 3.6 * z); if (!r) continue
      const up = w.blow < 0 ? Math.sin(Math.min(1, -w.blow / 3) * Math.PI) : 0, sway = still ? 0 : Math.sin(t * 0.8 + w.phase) * 0.05
      sprites.picture(r, w.x, w.y, [-1, -1.8, 1, 1.8], { rot: w.head + Math.PI / 2 + sway, color: [1, 1, 1, 0.55 + 0.4 * up], flags: FLAG.water })
    }
    // the sea floor, under everything that swims
    for (const s of seabed) if (seen(s.x, s.y, 4)) { const r = atlas.get(s.name, s.w * z); if (r) sprites.picture(r, s.x, s.y, [-s.w / 2, -s.h / 2, s.w / 2, s.h / 2], { rot: s.rot, flags: FLAG.water | FLAG.seabed, color: s.tint ? [...s.tint, 0.97] : [1, 1, 1, 1] }) }   // (alpha .97 marks a reef for the shader)
    // under the water's surface: swimmers, tinted and clipped by the water, with a ripple spreading round each
    for (const c of herd.list) if (c.home === 'water' && c !== herd.held && seen(c.x, c.y)) {
      if (c === herd.selected) halo(c, c.y)
      body(c, c.y, FLAG.water)
      if (!still) { const k = (t * 0.6 + c.phase) % 1; sprites.shape(SHAPE.ripple, c.x, c.y, c.size * (0.35 + k * 0.3) / 0.92, c.size * (0.25 + k * 0.2) / 0.92, [225 / 255, 245 / 255, 1, (1 - k) * 0.6], FLAG.water) }
    }
    const landAt = sprites.n
    // standing on the ground, back to front: trees and land creatures
    const items: [number, number, number, number][] = []        // [depth, kind 0 tree / 1 creature / 2 post / 3 crop / 4 rail / 5 building, index, 0 standing / 1 planned / 2 to be erased]
    const homes: [string, number, number, Building, number][] = []   // the buildings in view: art, top-left x, y, kind, turn
    // a turned point of a building's own drawing, on the map
    const at = (kind: Building, o: number, bx: number, by: number, x: number, y: number) => { const [u, v] = turn(kind, o, x, y); return [bx + u, by + v] }
    // shadows by the time of day: the sun's place (the buildings' shadow pictures were rendered under the same three suns),
    // as how far a shadow reaches along the ground per unit of height, and how dark it is; at night, midday's, faint
    const SUN = ({ morning: ['morning', -1.33, 0.33, 0.85], day: ['day', 0.4, 0.3, 1], evening: ['evening', 1.33, 0.33, 0.85], night: ['day', 0.4, 0.3, 0.3] } as Record<string, [string, number, number, number]>)[state.daytime] ?? ['day', 0.4, 0.3, 1]
    const [sunName, sunX, sunZ, aS] = SUN, sunA = Math.atan2(sunZ, sunX), sunL = Math.hypot(sunX, sunZ) / 0.5
    const PLAN = 1, GONE = 2, holo = (st: number) => (st === PLAN ? -1 : st === GONE ? -2 : 1)   // a negative alpha draws a hologram (sprites.ts)
    const tk = (t: { name: string; x: number; y: number }) => t.name + ',' + t.x.toFixed(2) + ',' + t.y.toFixed(2)
    const planTrees = new Set(planWorld.trees.map(tk)), doneTrees = new Set(world.trees.map(tk))
    const trees = [...world.trees, ...planWorld.trees.filter((t) => !doneTrees.has(tk(t)))]
    trees.forEach((tr, i) => { if (seen(tr.x, tr.y, 2)) items.push([tr.y + 0.5, 0, i, i < world.trees.length ? (planTrees.has(tk(tr)) ? 0 : GONE) : PLAN]) })
    const now = Date.now()
    const putBuilding = (i: number, b: { s?: Building; o?: number }, st: number, d = 0) => { const x = i % COLS, y = (i - x) / COLS, [w, h] = dims(b.s!, b.o); if (seen(x + w / 2, y + h / 2, Math.max(w, h))) items.push([y + h - 0.05 + d, 5, i, st]) }
    for (const k in done) { const b = done[k]; if (!b.s) continue; const p = builds[k], same = p?.s === b.s && (p.o ?? 0) === (b.o ?? 0)
      putBuilding(Number(k), b, same ? 0 : GONE); if (same && (p.lv ?? 1) !== (b.lv ?? 1)) putBuilding(Number(k), p, PLAN, 0.001) }
    for (const k in builds) { const p = builds[k]; if (!p.s) continue; const d = done[k]; if (d?.s === p.s && (d.o ?? 0) === (p.o ?? 0)) continue; putBuilding(Number(k), p, PLAN) }
    for (const k in done) { const b = done[k]; if (!b.c) continue; const i = Number(k), x = i % COLS, y = (i - x) / COLS; if (seen(x, y, 1)) items.push([y - 0.4, 3, i, builds[k]?.c === b.c ? 0 : GONE]) }
    for (const k in builds) { const p = builds[k]; if (!p.c || done[k]?.c === p.c) continue; const i = Number(k), x = i % COLS, y = (i - x) / COLS; if (seen(x, y, 1)) items.push([y - 0.39, 3, i, PLAN]) }
    const anyFence = new Uint8Array(fence.length), postState = (i: number) => (fence[i] && planFence[i] ? 0 : fence[i] ? GONE : PLAN)
    for (let i = 0; i < fence.length; i++) anyFence[i] = fence[i] | planFence[i]
    for (let i = 0; i < anyFence.length; i++) if (anyFence[i]) {
      const x = i % COLS, y = (i - x) / COLS; if (!seen(x, y, 1)) continue
      const a = anchor(i), st = postState(i); items.push([a[1] + 0.12, 2, i, st])
      for (let k = 0; k < 4; k++) { const j = linked(anyFence, i, k); if (j < 0) continue
        const sj = postState(j), rs = st === 0 && sj === 0 ? 0 : st === PLAN || sj === PLAN ? PLAN : GONE
        items.push([(a[1] + anchor(j)[1]) / 2 + 0.1, 4, i * 4 + k, rs]) }
    }
    herd.list.forEach((c, i) => { if (c.home === 'land' && c !== herd.held && seen(c.x, c.y)) items.push([c.y, 1, i, 0]) })
    farmers.list.forEach((f, i) => { if (seen(f.x, f.y)) items.push([f.y, 6, i, 0]) })
    if (hoverField) for (const i of hoverField.tiles) { const x = i % COLS, y = (i - x) / COLS; sprites.shape(SHAPE.tile, x + 0.5, y + 0.5, 0.5, 0.5, [1, 0.9, 0.55, 0.5]) }
    for (const k in done) { if (!done[k].h) continue; const i = Number(k), x = i % COLS, y = (i - x) / COLS; if (!seen(x, y)) continue
      const pulse = farmers.claimed.has(i) ? 0.75 + 0.25 * Math.sin(t * 6) : 0.55
      sprites.shape(SHAPE.tile, x + 0.5, y + 0.5, 0.5, 0.5, [1, 0.86, 0.42, pulse]) }
    items.sort((a, b) => a[0] - b[0])
    // planned and cleared ground: a blue tile where soil or a path is to go, red where it is to be taken up or plants cleared
    for (const k of new Set([...Object.keys(done), ...Object.keys(builds)])) { const i = Number(k), dg = done[i]?.g, pg = builds[i]?.g; if (dg === pg) continue
      const x = i % COLS, y = (i - x) / COLS; if (!seen(x, y)) continue
      sprites.shape(SHAPE.tile, x + 0.5, y + 0.5, 0.5, 0.5, pg ? [0.35, 0.78, 1, 0.8] : [1, 0.34, 0.3, 0.8]) }
    { const kept = new Set(planWorld.decor), marked = new Set<number>()
      for (const d of world.decor) if (!kept.has(d)) { const x = Math.floor(d.x + 0.5), y = Math.floor(d.y + 0.5), i = y * COLS + x, p = builds[i]; if (marked.has(i) || !seen(x, y) || (p && (p.g || p.f || p.c || p.p || p.u !== undefined))) continue;   // only plants cleared on purpose, not those a build covers marked.add(i)
        sprites.shape(SHAPE.tile, x + 0.5, y + 0.5, 0.42, 0.42, [1, 0.34, 0.3, 0.7]) } }
    for (const [, kind, i, st] of items) if (kind === 5 && st !== PLAN) { const b = done[i], [w, h] = dims(b.s!, b.o), x = i % COLS, y = (i - x) / COLS, sq = 0.62
      if (b.s === 'torch') sprites.shape(SHAPE.softShadow, x + 0.6, y + 0.64, 0.13, 0.06, [...SHADE, 0.4])
      else if (!RENDERED.has(b.s!)) sprites.shape(SHAPE.softShadow, x + w / 2 + 0.3, y + h / 2 + 0.4, w * sq, h * sq, [...SHADE, 0.42]) }
    for (const [, kind, i, st] of items) if (kind === 0 && st !== PLAN) { const tr = trees[i], rr = tr.sc * 0.55
      // cast by the sun the way the buildings' are: the crown's shadow thrown out to the lower right by the tree's height,
      // stretched a little along the light, and a small dark patch at the foot of the trunk
      const hgt = tr.sc * 1.25, ox = hgt * sunX, oy = hgt * sunZ, kS = sunL
      sprites.shape(SHAPE.softShadow, tr.x + 0.5 + ox, tr.y + 0.5 + oy, rr * (1.25 + (kS - 1) * 0.5), rr * 1.0, [...SHADE, 0.36 * aS], 0, sunA)   // soft: a crown lets light through
      sprites.shape(SHAPE.softShadow, tr.x + 0.5 + ox * .9, tr.y + 0.5 + oy * .9, rr * (.85 + (kS - 1) * 0.35), rr * .68, [...SHADE, 0.22 * aS], 0, sunA)
      sprites.shape(SHAPE.softShadow, tr.x + 0.5 + rr * 0.15, tr.y + 0.5 + rr * 0.2, rr * 0.55, rr * 0.45, [...SHADE, 0.3]) }
    for (const [, kind, i, st] of items) {
      if (kind === 0) {
        const tr = trees[i], conifer = Number(tr.name.slice(-2)) >= 4, rr = tr.sc * (conifer ? 0.46 : 0.56)
        sprites.tree(tr.x + 0.5, tr.y + 0.5 - tr.lift, rr, (tr.phase / 6.2832 * 7.3) % 1, conifer ? 1 : 0, (tr.phase * 3.7) % 1, still ? 0 : tr.sw * 0.4, tr.phase, holo(st))
      } else if (kind === 3) {
        const set = st === PLAN ? builds : done, b = set[i], name = cropArt(b.c!, st === PLAN ? '6-harvest' : cropStage(b.t ?? 0, now)), r = atlas.get(name, z); if (!r) continue
        const x = i % COLS, y = (i - x) / COLS
        if (PAINTED_CROPS.has(b.c!) && st !== PLAN) {   // (a planned crop shows as its plain tile: the soil it needs is only planned too)                          // a field tile: ragged where the field ends, interlocking with another crop
          let fl = FLAG.graded | FLAG.field | cropSeed(b.c!) * FIELD.seed, k = 0
          for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) { if (!dx && !dy) continue
            const nb = set[i + dy * COLS + dx]
            if (nb?.c === b.c || nb?.g !== 'soil') fl |= FIELD.near << k
            if (nb?.c === b.c) fl |= FIELD.same << k
            k++ }
          if (!still) fl |= FIELD.wind
          sprites.picture(r, x + 0.5, y + 0.5, [-FIELD_REACH, -FIELD_REACH, FIELD_REACH, FIELD_REACH], { flags: fl, color: [1, 1, 1, holo(st)] })
        } else sprites.picture(r, x + 0.5, y + 0.5, [-0.5, -0.5, 0.5, 0.5], { sway: still ? 0 : 0.12, phase: i * 0.37, flags: FLAG.graded, color: [1, 1, 1, holo(st)] })
      } else if (kind === 2) {                                  // a post, standing on its anchor
        const r = atlas.get('fence-0000', z); if (!r) continue
        const [ax, ay] = anchor(i)
        sprites.picture(r, ax, ay, [-0.5, -0.5, 0.5, 0.5], { flags: FLAG.graded, color: [1, 1, 1, holo(st)] })
      } else if (kind === 5) {                                  // a building, standing on its footprint
        const b = (st === PLAN ? builds : done)[i], spec = BUILDINGS[b.s!], base = spec.art(b.lv ?? 1)
        const x = i % COLS, y = (i - x) / COLS, o = b.o ?? 0, [w, h] = dims(b.s!, o)
        if (RENDERED.has(b.s!)) {                                // a rendered picture for each facing, with its shadow, reaching PAD tiles past the footprint
          const name = buildingArt(`${base}-o${o}`), pw = w + PAD[0] + PAD[2], ph = h + PAD[1] + PAD[3], r = atlas.get(name, Math.max(pw, ph) * z); if (!r) continue
          const rect: [number, number, number, number] = [-PAD[0], -PAD[1], w + PAD[2], h + PAD[3]]
          if (st !== PLAN) { const sw = w + SHPAD[0] + SHPAD[2], sh = h + SHPAD[1] + SHPAD[3], sr = atlas.get(buildingArt(`${base}-o${o}-shadow-${sunName}`), Math.max(sw, sh) * z)   // its shadow, where the hour's sun throws it
            if (sr) sprites.picture(sr, x, y, [-SHPAD[0], -SHPAD[1], w + SHPAD[2], h + SHPAD[3]], { color: [1, 1, 1, aS] }) }
          sprites.picture(r, x, y, rect, { flags: FLAG.graded, color: [1, 1, 1, holo(st)] })
        } else {
          const name = buildingArt(base), r = atlas.get(name, Math.max(spec.w, spec.h) * z); if (!r) continue
          sprites.picture(r, x + w / 2, y + h / 2, [-spec.w / 2, -spec.h / 2, spec.w / 2, spec.h / 2], { rot: o * Math.PI / 2, flags: FLAG.graded, color: [1, 1, 1, holo(st)] })
        }
        if (st === PLAN) continue
        homes.push([base, x, y, b.s!, o])
        if (b.s === 'torch') {                                   // its flame, alive (a soft glow round it after dark comes with the lights)
          const fl = still ? 0 : 1
          sprites.shape(SHAPE.flame, x + 0.5, y + 0.17, 0.1, 0.17, [(x * 0.37 + y * 0.61) % 1, fl, 0, 1])
        }
      } else if (kind === 4) {                                  // a rail from one post to the next: the rail part of the straight fence art, stretched and turned
        const r = atlas.get('fence-0101', z); if (!r) continue
        const a = i >> 2, b = linked(anyFence, a, i & 3), [x0, y0] = anchor(a), [x1, y1] = anchor(b)
        const len = Math.hypot(x1 - x0, y1 - y0), u = r.u0 + (r.u1 - r.u0) * 0.43
        sprites.picture({ ...r, u1: u }, (x0 + x1) / 2, (y0 + y1) / 2, [-len / 2, -0.5, len / 2, 0.5], { rot: Math.atan2(y1 - y0, x1 - x0), flags: FLAG.graded, color: [1, 1, 1, holo(st)] })
      } else if (kind === 6) {                                  // a farmer: walking, bent over the harvest, carrying the sack
        const f = farmers.list[i], r = atlas.get('farmer-' + (f.look + 1), 0.9 * z); if (!r) continue
        const walking = f.path.length > 0, work = f.state === 'harvest', bob = still ? 0 : walking ? Math.abs(Math.sin(t * 9 + f.id)) : work ? Math.abs(Math.sin(t * 7 + f.id)) : 0
        sprites.shape(SHAPE.shadow, f.x + 0.07, f.y + 0.1, 0.28, 0.21, [...SHADE, 0.3])
        if (f.crop) { const sk = atlas.get('farmer-sack', 0.4 * z); if (sk) sprites.picture(sk, f.x - Math.cos(f.head) * 0.12, f.y - Math.sin(f.head) * 0.12 - 0.04, [-0.24, -0.24, 0.24, 0.24], { rot: f.head + Math.PI / 2, flags: FLAG.graded }) }
        const sw = still ? 0 : walking ? Math.sin(t * 9 + f.id) * 0.12 : work ? Math.sin(t * 7 + f.id) * 0.25 : 0
        sprites.picture(r, f.x, f.y - bob * 0.05, [-0.44, -0.44, 0.44, 0.44], { rot: f.head + Math.PI / 2 + sw, sx: 1 + bob * 0.04, sy: 1 - bob * 0.03, flags: FLAG.graded })
        if (work && !still) for (let k = 0; k < 3; k++) { const a = (t * 1.6 + k / 3 + f.id * 0.37) % 1   // chaff flying up as the crop is cut
          sprites.shape(SHAPE.dot, f.x + Math.cos(f.head) * 0.25 + Math.sin(k * 2.1 + t) * 0.15, f.y + Math.sin(f.head) * 0.25 - a * 0.35, 0.025, 0.025, [0.86, 0.76, 0.42, 1 - a]) }
      } else {
        const c = herd.list[i]
        if (c === herd.selected) halo(c, c.y)
        sprites.shape(SHAPE.shadow, c.x + c.size * 0.06, c.y + c.size * 0.09, c.size * 0.34, c.size * 0.26, [...SHADE, 0.3])
        body(c, c.y, FLAG.graded)
      }
    }
    for (const w of whales) if (w.blow < 0 && !still && seen(w.x, w.y, 4)) {
      const k = -w.blow / 3, hx = w.x + Math.cos(w.head) * 1.1, hy = w.y + Math.sin(w.head) * 1.1
      for (let j = 0; j < 6; j++) { const a = (k * 1.6 + j / 6) % 1, rr = 0.15 + a * 0.5
        sprites.shape(SHAPE.puff, hx + Math.sin(j * 2.1) * a * 0.3, hy - a * 1.4, rr, rr, [0.95, 0.97, 1, (1 - a) * 0.55 * Math.sin(Math.min(1, k) * Math.PI)]) }
    }
    // fountains: water welling from the spout, falling in arcs all round into the basin, rings spreading on the water
    for (const [name, bx, by, , bo] of homes) for (const [fx, fy, fr, fh] of FOUNTAINS[`${name}-o${bo}`] ?? []) {
      const cx = bx + fx, cy = by + fy, ty = cy - fh
      if (!seen(cx, cy, 2)) continue
      for (let k = 0; k < 3; k++) { const a = still ? (k + 0.5) / 3 : (t * 0.45 + k / 3) % 1
        sprites.shape(SHAPE.ripple, cx, cy, fr * (0.25 + a * 0.68), fr * (0.25 + a * 0.68) * 0.92, [0.86, 0.95, 1, (1 - a) * 0.5]) }
      for (let j = 0; j < 8; j++) { const dir = j / 8 * Math.PI * 2 + 0.2
        for (let k = 0; k < 5; k++) { const a = still ? (k + 0.5) / 5 : (t * 1.1 + k / 5 + j * 0.13) % 1
          const r = 0.06 + a * fr * 0.62   // out over the spout's bowl, falling ever faster into the basin
          sprites.shape(SHAPE.dot, cx + Math.cos(dir) * r, ty + (cy - ty) * a * a + Math.sin(dir) * r * 0.92, 0.022, 0.026, [0.86, 0.94, 1, 0.75 * (1 - a * 0.6)]) } }
      const bob = still ? 0 : Math.sin(t * 5) * 0.012
      sprites.shape(SHAPE.dot, cx, ty - 0.06 + bob, 0.035, 0.05, [0.92, 0.97, 1, 0.8])   // the water welling up from the top
    }
    // chimney smoke: soft puffs rising, swelling and thinning as the wind takes them east
    const wind = WX[state.weather].gust
    for (const [name, bx, by, bk, bo] of homes) for (const [cx, cy] of (RENDERED.has(bk) ? CHIMNEYS[`${name}-o${bo}`] : CHIMNEYS[name]) ?? []) {
      const [sx, sy] = RENDERED.has(bk) ? [bx + cx, by + cy] : at(bk, bo, bx, by, cx, cy), seed = sx * 1.7 + sy * 3.1
      for (let k = 0; k < 7; k++) {
        const a = still ? (k + 0.5) / 7 : (t * 0.16 + k / 7 + seed) % 1, rise = a * 1.3
        const px = sx + a * a * (0.9 + 0.5 * wind) + Math.sin(a * 5 + seed + k) * 0.08, py = sy - rise
        const rr = 0.1 + a * 0.38, alpha = Math.min(1, a * 6) * (1 - a) * 0.5
        sprites.shape(SHAPE.puff, px, py, rr, rr, [0.88, 0.87, 0.84, alpha])
      }
    }
    // the tiles a build would cover: gold where it can go, red where it cannot, pale where something will be erased
    for (const [i, k] of preview()) { const x = i % COLS, y = (i - x) / COLS; if (seen(x, y)) sprites.shape(SHAPE.tile, x + 0.5, y + 0.5, 0.5, 0.5, k === 0 ? [0.98, 0.82, 0.4, 0.9] : k === 1 ? [0.9, 0.32, 0.25, 0.5] : k === 3 ? [0.92, 0.95, 1, 0.75] : [1, 0.94, 0.86, 0.95]) }
    // the shadows of flyers, far below
    for (const c of herd.list) if (c.home === 'air' && c !== herd.held && seen(c.x, c.y, 2)) {
      const bob = still ? 0 : Math.sin(t * 1.3 + c.phase), rx = c.size * 0.34 * (1 - 0.05 * bob)
      sprites.shape(SHAPE.softShadow, c.x + 0.75 + 0.04 * bob, c.y + 1.05 + 0.05 * bob, rx, rx * 0.72, [...SHADE, 0.2 - 0.02 * bob])
    }
    // butterflies: fewer in bad weather, none at night, too small to see from far out
    if (!still && z >= 14) {
      const n = world.flies.length * WX[state.weather].flies * DAYS[state.daytime].flies
      for (let fi = 0; fi < n; fi++) {
        const f = world.flies[fi]
        const wx = f.cx + Math.sin(t * f.sp + f.a) * 2.2 + Math.sin(t * f.sp * 2.3 + f.b) * 0.8, wy = f.cy + Math.cos(t * f.sp * 1.3 + f.b) * 1.6 + Math.sin(t * f.sp * 3.1 + f.a) * 0.5
        if (!seen(wx, wy)) continue
        const stage = Math.min(FLY_STAGES - 1, Math.floor(Math.abs(Math.sin(t * 11 + f.a)) * FLY_STAGES)), r = atlas.get(`fly-${f.ci}-${stage}`, 0.45 * z); if (!r) continue
        sprites.picture(r, wx, wy, [-0.225, -0.1125, 0.225, 0.3375], { flags: FLAG.graded })
      }
    }
    // flyers above everything
    const flyAt = sprites.n
    { const c = herd.held                                        // the carried creature, held up off the ground
      if (c) { const ok = herd.canDrop(c, c.x, c.y), m = still ? 0 : 1, q = t + c.phase
        // a little panicked: it wriggles side to side, kicks (a quick squash and stretch), bobs in the air, and now and then
        // twists hard the other way, as if trying to get loose
        const twist = Math.sin(q * 2.3) > 0.82 ? Math.sin(q * 9) * 0.35 : 0
        const sway = m * (Math.sin(q * 21) * 0.17 + Math.sin(q * 34) * 0.06 + twist)
        const kick = m * Math.sin(q * 27), sx = 1 + 0.07 * kick, sy = 1 - 0.07 * kick
        const lift = liftOf(c) + m * (0.06 * Math.abs(Math.sin(q * 13)) + 0.02 * Math.sin(q * 41))
        const jx = m * Math.sin(q * 17) * 0.04
        sprites.shape(SHAPE.softShadow, c.x + 0.1, c.y + 0.15, c.size * (0.4 - lift * 0.12), c.size * (0.3 - lift * 0.09), [...SHADE, 0.38 - lift * 0.25])
        if (!ok) sprites.shape(SHAPE.tile, Math.floor(c.x) + 0.5, Math.floor(c.y) + 0.5, 0.5, 0.5, [0.9, 0.32, 0.25, 0.5])
        const r = atlas.get(c.sprite, c.size * 1.15 * z)
        if (r) sprites.picture(r, c.x + jx, c.y - lift, [-c.size * 0.575, -c.size * 0.575, c.size * 0.575, c.size * 0.575], { rot: c.head + Math.PI / 2 + sway, sx, sy, flags: FLAG.graded, color: ok ? [1, 1, 1, 1] : [1, 0.75, 0.72, 1] })
        // sweat drops flicking off now and then
        if (m) for (let k = 0; k < 3; k++) { const a = ((q * 1.7 + k / 3) % 1), side = k % 2 ? 1 : -1
          if (a < 0.55) { const d = c.size * (0.42 + a * 0.5); sprites.shape(SHAPE.dot, c.x + side * d * 0.8, c.y - lift - c.size * 0.3 - a * 0.25 + a * a * 0.6, 0.035, 0.05, [0.82, 0.92, 1, (1 - a / 0.55) * 0.9]) } } } }
    for (const c of herd.list) if (c.home === 'air' && c !== herd.held && seen(c.x, c.y, 2)) {
      const lift = 0.9 + (still ? 0 : 0.08 * Math.sin(t * 1.3 + c.phase))
      if (c === herd.selected) halo(c, c.y)
      body(c, c.y - lift * 0.15, FLAG.graded)
    }
    // Cloud shadows drift slowly across the whole world; when the sky turns cloudy, more grow in over a couple of seconds
    const blobs: [number, number, number, number, number, number, number][] = []   // x, y, rx, ry, soft, alpha, tilt
    const target = WX[state.weather].more; sky.grow = still ? target : sky.grow + Math.sign(target - sky.grow) * Math.min(Math.abs(target - sky.grow), dt / 2)
    const M = Math.max(10, (view.clientWidth / zMin() - COLS) / 2 + 6)   // clouds appear and vanish beyond the widest view, then drift in
    const tt = still ? 0 : t
    for (let k = 0; k < 7 + (sky.grow > 0.01 ? 28 : 0); k++) {
      const more = k >= 7, p = more ? CLOUD.puffs[k - 7] : null, grow = p ? Math.min(1, Math.max(0, sky.grow * 1.5 - p.delay)) : 1; if (grow <= 0) continue
      const w = p ? p.w * (0.55 + 0.45 * grow) : [8, 14, 22, 10, 30, 12, 80][k], giant = k === 6, span = COLS + 30 + 2 * M + (giant ? 200 : 0)
      const cx0 = p ? ((tt * p.sp + p.x * span) % span) - 15 - M : ((tt * (giant ? 0.2 : 0.3) + (giant ? 60 : k * span / 6)) % span) - 15 - M
      const cy0 = p ? p.y * (ROWS + 16) - 8 + Math.sin(tt * 0.05 + p.phase) * 0.8 : ((k * 7.3) % ROWS) + Math.sin(tt * 0.05 + k) * 0.8
      const wx = cx0 + 15 - w / 2, wy = cy0 - w * 0.35, tall = p ? p.tall : 0.7, shape = p ? p.shape : CLOUD.clouds[k % 6]
      if (wx + w < x0 - 8 || wx - 6 > x1 || wy + w * tall < y0 - 8 || wy - 7 > y1) continue
      for (const [bx, by, rx, ry, tilt] of shape.blobs) {
        const soft = 2 * shape.blur / rx
        blobs.push([wx + bx * w, wy + by * w * tall, rx * w * (1 + soft), ry * w * tall * (1 + soft), soft, p ? grow * grow : 1, tilt])
      }
    }
    const cloudAt = sprites.n
    for (const [bx, by, rx, ry, soft, a, tilt] of blobs) sprites.shape(SHAPE.cloud, bx, by, rx, ry, [0, soft, 0, a], 0, tilt)
    // fireflies after dark: little swarms on the banks, each light circling slowly; their light, then their glow
    const lightAt = sprites.n, glows: [number, number, number][] = []
    const nf = z < 8 ? 0 : Math.round(world.swarms.length * DAYS[state.daytime].fireflies * WX[state.weather].flies)
    const far = Math.min(1, Math.max(0.12, (z - 8) / 40))           // seen from afar, only faint specks
    for (let i = 0; i < nf; i++) {
      const sw = world.swarms[i], cx = sw.cx + Math.sin(tt * sw.sp + sw.a) * 0.4, cy = sw.cy + Math.cos(tt * sw.sp * 0.8 + sw.a) * 0.3
      if (!seen(cx, cy, 2)) continue
      const breath = (still ? 1 : 0.9 + 0.1 * Math.sin(t * 0.5 + sw.a)) * far
      for (const fl of sw.flies) {
        const ang = fl.a0 + tt * fl.w, fx = cx + Math.cos(ang) * fl.r, fy = cy + Math.sin(ang) * fl.r * 0.6 + (still ? 0 : Math.sin(t * 1.3 + fl.b) * fl.bob)
        const glow = (still ? 0.85 : 0.72 + 0.22 * Math.sin(t * 0.6 + fl.b)) * far
        sprites.shape(SHAPE.light, fx, fy, 0.7, 0.7, [0.35 * glow * breath, 0.85 * glow * breath, 0, 0])
        glows.push([fx, fy, glow])
      }
    }
    const dark = state.daytime === 'night' ? 1 : state.daytime === 'evening' ? 0.6 : 0
    // each window, door, lantern and torch throws its own light: a pool that fades softly, a window's only forward
    if (dark) for (const [name, bx, by, bk, bo] of homes) for (const [lx, ly, reach, fwd, bright = 1] of LIGHTS[name] ?? []) {
      const [px, py] = at(bk, bo, bx, by, lx, ly)
      const flick = still || fwd ? 1 : 0.92 + 0.08 * Math.sin(t * 7.3 + bx * 3) * Math.sin(t * 4.1 + by)
      sprites.shape(SHAPE.light, px, py, reach, reach, [0.55 * dark * flick * bright, 0.9 * dark * flick * Math.min(1, bright * 1.3), fwd, 0], 0, bo * Math.PI / 2) }
    const glowAt = sprites.n
    if (dark) for (const [name, bx, by, bk, bo] of homes) if (LIT.has(name)) {
      const sp = BUILDINGS[bk], [w, h] = dims(bk, bo)
      if (RENDERED.has(bk)) { const pw = w + PAD[0] + PAD[2], ph = h + PAD[1] + PAD[3], lr = atlas.get(buildingArt(`${name}-o${bo}-lights`), Math.max(pw, ph) * z); if (!lr) continue
        sprites.picture(lr, bx, by, [-PAD[0], -PAD[1], w + PAD[2], h + PAD[3]], { color: [1, 1, 1, dark] }); continue }
      const r = atlas.get(buildingArt(name + '-lights'), Math.max(sp.w, sp.h) * z); if (!r) continue
      const flick = still ? 1 : 0.94 + 0.06 * Math.sin(t * 3.1 + bx) * Math.sin(t * 1.7 + by)
      sprites.picture(r, bx + w / 2, by + h / 2, [-sp.w / 2, -sp.h / 2, sp.w / 2, sp.h / 2], { rot: bo * Math.PI / 2, color: [1, 1, 1, dark * flick] })
    }
    for (const [fx, fy, glow] of glows) {
      sprites.shape(SHAPE.glow, fx, fy, 0.13, 0.13, [1, 222 / 255, 150 / 255, glow * 0.85])
      const core = Math.max(1 / z, 0.022); sprites.shape(SHAPE.dot, fx, fy, core, core, [1, 240 / 255, 200 / 255, glow])
    }
    return [landAt, flyAt, cloudAt, lightAt, glowAt, sprites.n]
  }

  // ---------- the frame ----------
  let raf = 0, last = 0, size = [0, 0]
  const kick = () => { if (!raf) raf = requestAnimationFrame(frame) }
  const resize = () => {
    const d = dpr(), w = Math.round(view.clientWidth * d), h = Math.round(view.clientHeight * d)
    if (w !== size[0] || h !== size[1]) { canvas.width = w; canvas.height = h; size = [w, h] }
  }
  function frame(now: number) {
    raf = 0
    if (!ground.tiles) { kick(); return }
    const dt = Math.min(50, now - (last || now)); last = now
    if (ZOOM.active) {
      const ratio = ZOOM.target / CAM.z
      if (Math.abs(Math.log(ratio)) < 0.003) { ZOOM.active = false; zoomNow(ratio, ZOOM.px, ZOOM.py) } else zoomNow(ratio ** (1 - Math.exp(-dt / 80)), ZOOM.px, ZOOM.py)
    }
    if (state.motion) { herd.step(dt / 1000); stepWhales(dt / 1000) }
    farmers.step(dt / 1000); if (farmers.list.length || farmers.claimed.size) kick()   // the harvest goes on even when motion is reduced
    placeTokens()
    placePens()
    resize()
    const d = dpr(), cam = { x: CAM.x, y: CAM.y, z: CAM.z * d }, W = size[0], H = size[1], t = now / 1000
    const f0 = performance.now()
    atlas.frame++
    atlas.work(LOW ? 2 : 3)
    // bake what the view lacks: a couple of chunks a frame, nearest the middle first
    const need = ground.missing(cam, W, H)
    for (let k = 0, made = 0; k < need.length && made < (ZOOM.active ? 1 : 3); k++) if (ground.bakeChunk(need[k][0], need[k][1], need[k][2])) made++
    sky.size(W, H)
    const parts = buildScene(t, dt / 1000, cam, W, H), [landAt, flyAt, cloudAt, lightAt, glowAt, end] = parts
    const fieldArgs = [atlas.tex, ground.height, ground.fieldSize, [world.cols, world.rows]] as const
    const sp = (from: number, to: number, o: Record<string, unknown> = {}) => sprites.draw(fieldArgs[0], fieldArgs[1], fieldArgs[2], [fieldArgs[3][0], fieldArgs[3][1]], cam, W, H, { time: t, gust: WX[state.weather].gust, from, to, soil: ground.f[0], ...o })
    // the cloud shadows and the fireflies' light, each in its own small target
    gl!.bindFramebuffer(gl!.FRAMEBUFFER, sky.light!.fb); gl!.viewport(0, 0, sky.light!.w, sky.light!.h); gl!.clearColor(0, 0, 0, 1); gl!.clear(gl!.COLOR_BUFFER_BIT)
    sp(lightAt, glowAt, { blend: 'light' })
    // the scene: ground, swimmers, the water's life, what stands on the ground, cloud shadows, flyers
    gl!.bindFramebuffer(gl!.FRAMEBUFFER, sky.scene!.fb); gl!.viewport(0, 0, W, H)
    const pending = ground.draw(cam, W, H)
    sp(0, landAt)
    const still = !state.motion
    sky.water(ground.height, ground.fieldSize, [world.cols, world.rows], cam, W, H, t, state.weather === 'storm' ? 2 : state.weather === 'rain' ? 1 : 0, cam.z > 6 ? (still ? 2 : 1) : 0, !still && cam.z > 14, ground.level(cam.z))
    sp(landAt, flyAt)
    // the weather: whole cloud systems as on the planet map; their shadows at every zoom, the clouds themselves from far out
    const farZ = cam.z / d, far = 1 - Math.min(1, Math.max(0, (farZ - 11) / 22)), cover = ({ sun: -0.1, cloudy: 0.03, rain: 0.08, storm: 0.14 } as Record<string, number>)[state.weather] ?? 0, wet = state.weather === 'rain' || state.weather === 'storm' ? 1 : 0
    sky.farClouds(cam, W, H, still ? 0 : t, far, cover, wet, 0)
    sp(flyAt, cloudAt)
    sky.farClouds(cam, W, H, still ? 0 : t, far, cover, wet, 1)
    // graded onto the canvas, then what glows and falls on top
    sky.final(state.weather, state.daytime, W, H, true)
    sp(glowAt, end)
    if (!still) sky.rain(state.weather, W, H, d, t, dt / 1000)
    stats.sprites = sprites.n
    stats.frameMs = performance.now() - f0
    stats.frames++
    if (now - stats.at > 1000) { stats.fps = Math.round(stats.frames * 1000 / (now - stats.at)); stats.frames = 0; stats.at = now; const el = document.getElementById('fps'); if (el) el.textContent = `${stats.fps} fps · gl` }
    if (state.motion || pending || need.length || ZOOM.active) kick()
  }
  document.addEventListener('visibilitychange', () => { if (!document.hidden) kick() })

  // ---------- input: drag to pan, wheel / pinch / double-click to zoom, click or tap a creature to select it ----------
  const ptrs = new Map<number, [number, number]>(); let pinch = 0
  let press: { x: number; y: number; id: number } | null = null
  const toWorld = (cx: number, cy: number) => { const r = view.getBoundingClientRect(); return [CAM.x + (cx - r.left) / CAM.z, CAM.y + (cy - r.top) / CAM.z] }
  const cellAt = (cx: number, cy: number): [number, number] => { const [wx, wy] = toWorld(cx, cy); return [Math.max(0, Math.min(COLS - 1, Math.floor(wx))), Math.max(0, Math.min(ROWS - 1, Math.floor(wy)))] }
  view.addEventListener('pointerdown', (e) => {
    view.setPointerCapture(e.pointerId); ptrs.set(e.pointerId, [e.clientX, e.clientY]); view.classList.add('drag')
    press = ptrs.size === 1 ? { x: e.clientX, y: e.clientY, id: e.pointerId } : null
    // with a build tool picked, a drag with the main button (or one finger) marks tiles instead of panning
    if (tool && ptrs.size === 1 && e.button === 0) { const [x, y] = cellAt(e.clientX, e.clientY); mark = [x, y, x, y]; stroke = (tool === 'fence' || tool === 'path') && !e.shiftKey ? [y * COLS + x] : null; eraseKind = tool === 'erase' ? eraseKindAt(planWorld, builds, y * COLS + x) : null; harvestOff = tool === 'harvest' && !!done[y * COLS + x]?.h; unmark = unmarks(y * COLS + x); kick() }
    else { mark = null; stroke = null }
    if (!tool && ptrs.size === 1 && e.button === 0) { const [wx, wy] = toWorld(e.clientX, e.clientY), c = herd.at(wx, wy, CAM.z); carry = c ? { c, dx: c.x - wx, dy: c.y - wy } : null } else carry = null
  })
  view.addEventListener('pointermove', (e) => {
    const p = ptrs.get(e.pointerId); if (!p) return
    ptrs.set(e.pointerId, [e.clientX, e.clientY])
    if (carry && ptrs.size === 1) {                             // carrying a creature: it follows the pointer, the map stays put
      if (!herd.held && press && Math.hypot(e.clientX - press.x, e.clientY - press.y) >= 6) { herd.grab(carry.c); view.style.cursor = 'grabbing' }
      if (herd.held) { const [wx, wy] = toWorld(e.clientX, e.clientY); carry.c.x = wx; carry.c.y = wy + liftOf(carry.c); kick(); return }   // held by its middle, right under the pointer; it stands on the ground a little below
    }
    if (mark && ptrs.size === 1) { const [x, y] = cellAt(e.clientX, e.clientY); if (x !== mark[2] || y !== mark[3]) { if (stroke) stroke.push(...line8(mark[2], mark[3], x, y)); mark[2] = x; mark[3] = y; kick() } return }
    if (ptrs.size === 2) {
      mark = null
      const [a, b] = [...ptrs.values()], dd = Math.hypot(a[0] - b[0], a[1] - b[1]), r = view.getBoundingClientRect()
      if (pinch) zoomNow(dd / pinch, (a[0] + b[0]) / 2 - r.left, (a[1] + b[1]) / 2 - r.top); pinch = dd; return
    }
    CAM.x -= (e.clientX - p[0]) / CAM.z; CAM.y -= (e.clientY - p[1]) / CAM.z; clampCam(); kick()
  })
  const up = (e: PointerEvent) => {
    if (herd.held) { const c = herd.held; herd.drop(); if (c.home !== 'air') drops.set(c, performance.now() / 1000); carry = null; press = null; ptrs.delete(e.pointerId); pinch = 0; if (!ptrs.size) view.classList.remove('drag'); view.style.cursor = ''; kick(); return }
    carry = null
    if (mark) { if (e.type === 'pointerup') build(); mark = null; stroke = null; kick() }
    else if (e.type === 'pointerup' && press && press.id === e.pointerId && Math.hypot(e.clientX - press.x, e.clientY - press.y) < 6) {   // a click, not a drag
      const [wx, wy] = toWorld(e.clientX, e.clientY), c = herd.at(wx, wy, CAM.z)
      select(c ? c.id : null)                                   // a click on empty ground lets the selected creature go
    }
    press = null; ptrs.delete(e.pointerId); pinch = 0; if (!ptrs.size) view.classList.remove('drag')
  }
  view.addEventListener('pointerup', up); view.addEventListener('pointercancel', up)
  let carry: { c: typeof herd.list[number]; dx: number; dy: number } | null = null
  /** How high a carried creature is held above the ground it would land on (tiles): smaller ones not as high. */
  const liftOf = (c: { size: number }) => 0.12 + c.size * 0.3
  const drops = new Map<typeof herd.list[number], number>()     // creatures just set down, and when (s)
  let hoverCur = '', hoverRaf = 0, hoverAt: [number, number] = [0, 0]
  view.addEventListener('pointermove', (e) => {
    if (ptrs.size) return; hoverAt = [e.clientX, e.clientY]
    if (!hoverRaf) hoverRaf = requestAnimationFrame(() => {
      hoverRaf = 0
      if (tool) { const c = cellAt(hoverAt[0], hoverAt[1]); if (!hover || c[0] !== hover[0] || c[1] !== hover[1]) { hover = c; kick() } return }
      const [wx, wy] = toWorld(hoverAt[0], hoverAt[1]), want = herd.at(wx, wy, CAM.z) ? 'grab' : ''; if (want !== hoverCur) { hoverCur = want; view.style.cursor = want }
    })
  })
  view.addEventListener('wheel', (e) => { e.preventDefault(); const r = view.getBoundingClientRect(); zoomAt(Math.exp(-e.deltaY * 0.0015), e.clientX - r.left, e.clientY - r.top) }, { passive: false })
  view.addEventListener('dblclick', (e) => { e.preventDefault(); const r = view.getBoundingClientRect(); zoomTo(CAM.z * (e.shiftKey ? 0.5 : 2), e.clientX - r.left, e.clientY - r.top) })
  document.getElementById('zin')?.addEventListener('click', () => zoomAt(1.4, view.clientWidth / 2, view.clientHeight / 2))
  document.getElementById('zout')?.addEventListener('click', () => zoomAt(1 / 1.4, view.clientWidth / 2, view.clientHeight / 2))
  document.getElementById('zfit')?.addEventListener('click', fit)
  document.addEventListener('keydown', (e) => { if ((e.key === 'r' || e.key === 'R') && tool && tool in BUILDINGS && !(e.target instanceof HTMLInputElement)) { rotateBuild(); return } if (e.key === 'Escape') { if (mark) { mark = null; kick() } else if (herd.selected) select(null) } })
  view.addEventListener('pointerleave', () => { if (hover) { hover = null; kick() } })
  view.addEventListener('contextmenu', (e) => { if (tool) e.preventDefault() })   // right-drag moves the map while building

  // ---------- fences: where each post stands ----------
  /** The fence tile a fence on tile i joins in direction k (0 east, 1 south, 2 south-east, 3 south-west), or -1.
   *  Corner to corner only where no tile beside both carries a fence (else the two already join through it). */
  function linked(f: Uint8Array, i: number, k: number): number {
    const x = i % COLS, y = (i - x) / COLS, on = (a: number, b: number) => a >= 0 && b >= 0 && a < COLS && b < ROWS && f[b * COLS + a] === 1
    if (k === 0) return on(x + 1, y) ? i + 1 : -1
    if (k === 1) return on(x, y + 1) ? i + COLS : -1
    const dx = k === 2 ? 1 : -1
    return on(x + dx, y + 1) && !on(x + dx, y) && !on(x, y + 1) ? i + COLS + dx : -1
  }
  // On a tile at the water's edge the post moves out onto the shore: along the slope of the distance to the water, to
  // where the grass ends and the beach begins, so a fence built on the last tiles runs along the coast, not in steps.
  const SHORE = 0.45
  const waterDist = (x: number, y: number) => {               // tiles from the nearest sea or pond (+ on land), from the height field
    const fx = Math.max(0, Math.min(fields.w - 1, Math.round(x * fields.S))), fy = Math.max(0, Math.min(fields.h - 1, Math.round(y * fields.S)))
    const k = (fy * fields.w + fx) * 4; return Math.min(fields.height[k], -fields.height[k + 2])
  }
  const anchors = new Map<number, [number, number]>()
  function anchor(i: number): [number, number] {
    let a = anchors.get(i); if (a) return a
    const x = (i % COLS) + 0.5, y = ((i / COLS) | 0) + 0.5, d = waterDist(x, y)
    a = [x, y]
    if (d < 1.4) {
      const e = 0.25, gx = (waterDist(x + e, y) - waterDist(x - e, y)) / (2 * e), gy = (waterDist(x, y + e) - waterDist(x, y - e)) / (2 * e), g = Math.hypot(gx, gy)
      if (g > 0.2) { const m = Math.max(-0.6, Math.min(0.6, (d - SHORE) / g)); a = [x - gx / g * m, y - gy / g * m] }
    }
    anchors.set(i, a); return a
  }

  // ---------- building ----------
  let tool: BuildTool | null = null, rot = 0, mark: [number, number, number, number] | null = null, hover: [number, number] | null = null
  /** the tiles a fence or path being drawn passes, in order; null while dragging a rectangle */
  let stroke: number[] | null = null
  /** what an erase that is being dragged is after: set by the tile it started on */
  let eraseKind: EraseKind | null = null
  // starting on something already marked takes the mark back: with the eraser, what is marked to go; with a build
  // tool, what is planned to go up. The tiles go back to what stands.
  let unmark = false, harvestOff = false
  const same = (a: unknown, b: unknown) => JSON.stringify(a ?? {}) === JSON.stringify(b ?? {})
  const planned = (i: number) => { const p = builds[i], d = done[i] ?? {}; return !!p && !!((p.g && p.g !== d.g) || (p.f && !d.f) || (p.c && p.c !== d.c) || (p.p && !d.p) || (p.u !== undefined && p.u !== d.u) || (p.s && p.lv !== d.lv)) }
  const doomed = (i: number) => { const p = builds[i] ?? {}, d = done[i] ?? {}; return !!((d.g && p.g !== d.g) || (d.f && !p.f) || (d.c && p.c !== d.c) || (d.p && !p.p) || (d.u !== undefined && p.u !== d.u) || (p.x && !d.x)) }
  const unmarks = (i: number) => !!tool && tool !== 'upgrade' && tool !== 'harvest' && (tool === 'erase' ? doomed(i) : planned(i))
  /** The tiles taking a mark back here changes: a building's whole footprint, planned or standing. */
  function unmarkTiles(cells: Iterable<number>) {
    const out = new Set<number>(), test = tool === 'erase' ? doomed : planned
    for (const i of cells) { if (!test(i)) continue; out.add(i)
      const pu = builds[i]?.u, du = done[i]?.u
      if (pu !== undefined && builds[pu]?.s) { for (const j of footprint(builds[pu].s!, pu, COLS, builds[pu].o)) out.add(j); for (const j of builds[pu].l ?? []) if (planned(j)) out.add(j) }
      if (du !== undefined && done[du]?.s) for (const j of footprint(done[du].s!, du, COLS, done[du].o)) out.add(j) }
    return out
  }
  const revert = (i: number) => { if (done[i]) builds[i] = JSON.parse(JSON.stringify(done[i])); else delete builds[i] }
  /** The tiles from one to the next as a straight line, diagonal steps allowed (fences and paths join corner to corner). */
  function line8(x0: number, y0: number, x1: number, y1: number): number[] {
    const out: number[] = [], n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0))
    for (let k = 1; k <= n; k++) out.push(Math.round(y0 + (y1 - y0) * k / n) * COLS + Math.round(x0 + (x1 - x0) * k / n))
    return out
  }
  let crop: string = CROPS.includes('wheat' as never) ? 'wheat' : CROPS[0]
  let onBuild: ((b: Builds, undoable: boolean, pending: number, kind: 'build' | 'erase' | 'both') => void) | null = null
  const history: string[] = []                                  // the builds before each change, for undo
  const added = new Set<string>()
  const buildingArt = (n: string) => { if (!added.has(n)) { added.add(n); atlas.add(n, /-o\d/.test(n) ? `art/tiles/${n}.png?v=12` : `art/tiles/${n}.svg?v=5`) } return n }
  const cropArt = (c: string, stage: string) => { const n = `crop-${c}-${stage}`; if (!added.has(n)) { added.add(n); atlas.add(n, PAINTED_CROPS.has(c) ? `art/tiles/${n}.svg?v=9` : `art/crops/${c}/${stage}.svg?v=1`) } return n }
  const box = (m: [number, number, number, number]): [number, number, number, number] => [Math.min(m[0], m[2]), Math.min(m[1], m[3]), Math.max(m[0], m[2]), Math.max(m[1], m[3])]
  const inBox = ([x0, y0, x1, y1]: [number, number, number, number]) => { const out: number[] = []; for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) out.push(y * COLS + x); return out }
  /** The tiles the build being marked would cover: 0 it goes there, 1 it cannot, 2 something there will be erased. */
  function preview(): [number, number][] {
    if (!tool) return []
    const m = mark ?? (hover ? [hover[0], hover[1], hover[0], hover[1]] as [number, number, number, number] : null); if (!m) return []
    const b = box(m), out: [number, number][] = []
    if (tool === 'harvest') { const off = mark ? harvestOff : !!done[m[1] * COLS + m[0]]?.h; for (const i of inBox(b)) if (ripe(i) && !!done[i].h === off) out.push([i, off ? 3 : 0]); return out }
    if (mark ? unmark : hover && unmarks(hover[1] * COLS + hover[0])) { for (const i of unmarkTiles(stroke ? new Set(stroke) : inBox(b))) out.push([i, 3]); return out }
    if (stroke) { const ok = tool === 'fence' ? can.fence : can.path; for (const i of new Set(stroke)) out.push([i, ok(i) ? 0 : 1]); return out }
    if (tool === 'fence') {
      const small = b[2] - b[0] + 1 < MIN_ENCLOSURE || b[3] - b[1] + 1 < MIN_ENCLOSURE
      for (const i of ring(b, COLS)) out.push([i, !small && can.fence(i) ? 0 : 1])
      return out
    }
    if (tool in BUILDINGS) {                                     // its footprint, and the path its door will be joined to
      const k = tool as Building, at = placeAt(k, m[2], m[3]), fp = footprint(k, at, COLS, rot), link = linkPath(k, at, rot), ok = fp.every(can.building) && link !== null
      const cells = fp.map((i) => [i, ok ? 0 : 1] as [number, number])
      if (link) for (const i of link) cells.push([i, ok ? 0 : 1])
      else { const e = entrance(k, at, COLS, ROWS, rot); if (e >= 0) cells.push([e, 1]) }
      return cells
    }
    if (tool === 'upgrade') { const at = builds[m[3] * COLS + m[2]]?.u; if (at === undefined) return []; const b = builds[at]; return footprint(b.s!, at, COLS, b.o).map((i) => [i, (b.lv ?? 1) < BUILDINGS[b.s!].stages ? 0 : 1] as [number, number]) }
    if (tool === 'erase') {
      const k = mark ? eraseKind : eraseKindAt(planWorld, builds, m[0] + m[1] * COLS), seen = new Set<number>()
      for (const i of inBox(b)) if (erasable(planWorld, builds, i, k)) {
        const u = builds[i]?.u
        for (const j of u !== undefined && (k === null || k === 'building') ? footprint(builds[u].s!, u, COLS, builds[u].o) : [i]) if (!seen.has(j)) { seen.add(j); out.push([j, 2]) }   // a building goes whole: show all of it
      }
      return out
    }
    const ok = tool === 'soil' ? can.soil : tool === 'path' ? can.path : tool === 'tree' ? can.tree : can.crop
    for (const i of inBox(b)) out.push([i, ok(i) ? 0 : 1])
    return out
  }
  /** Lays the builds over the island again; where the ground changed, it is re-drawn over that box. */
  /** Where a path ends at a building's door, it runs on right up to the door. */
  function setDoors() {
    fields.doors.length = 0
    for (const k in done) { const b = done[k]; if (!b.s || BUILDINGS[b.s].door === undefined) continue
      const at = Number(k), o = b.o ?? 0, e = entrance(b.s, at, COLS, ROWS, o); if (e < 0 || world.type[e] !== T.path) continue
      const [dx, dy] = turn(b.s, o, BUILDINGS[b.s].door! + 0.5, BUILDINGS[b.s].doorY!), ex = e % COLS, ey = (e - ex) / COLS
      fields.doors.push([ex + 0.5, ey + 0.5, at % COLS + dx, (at - at % COLS) / COLS + dy]) }
  }
  /** How many tiles the plan changes. */
  const pending = () => { let n = 0; for (const k of new Set([...Object.keys(done), ...Object.keys(builds)])) if (JSON.stringify(done[Number(k)] ?? {}) !== JSON.stringify(builds[Number(k)] ?? {})) n++; return n }
  /** What the plan does: puts things up, takes things down, or both. */
  const planKind = (): 'build' | 'erase' | 'both' => { let up = false, down = false
    for (const k of new Set([...Object.keys(done), ...Object.keys(builds)])) { const i = Number(k); if (planned(i)) up = true; if (doomed(i)) down = true }
    return up && down ? 'both' : down ? 'erase' : 'build' }
  /** The plan changed: judge it anew and show it (the island itself waits for the plan to be confirmed). */
  function refreshPlan() {
    planFence = applyBuilds(planWorld, pristine, builds); can.changed()
    kick(); onBuild?.(JSON.parse(JSON.stringify(done)), history.length > 0, pending(), planKind())
  }
  /** What stands changed: lay it over the island again; where the ground changed, it is re-drawn over that box. */
  function relay(groundBox: [number, number, number, number] | null) {
    fence = applyBuilds(world, pristine, done); herd.setFences(walls()); setDoors()
    if (groundBox) { fields.refreshGrounds(); ground.rebuild(fields, groundBox) }
    refreshPlan()
  }
  /** The box round every tile whose ground differs between two sets of builds, or null. */
  function groundDiff(a: Builds, b: Builds): [number, number, number, number] | null {
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
    for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) {
      const i = Number(k), x = i % COLS, y = (i - x) / COLS
      if (a[i]?.s !== b[i]?.s || a[i]?.o !== b[i]?.o) { x0 = Math.min(x0, x - 2); y0 = Math.min(y0, y - 2); x1 = Math.max(x1, x + 6); y1 = Math.max(y1, y + 6) }   // a building came or went: the path to its door with it
      if (a[i]?.g === b[i]?.g) continue
      x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y)
    }
    return x1 < x0 ? null : [x0, y0, x1, y1]
  }
  /** The top-left tile of a building of this kind centred on the tile under the pointer, kept on the map. */
  function placeAt(kind: Building, cx: number, cy: number) {
    const [w, h] = dims(kind, rot), x0 = Math.max(0, Math.min(COLS - w, cx - Math.floor(w / 2))), y0 = Math.max(0, Math.min(ROWS - h, cy - Math.floor(h / 2)))
    return y0 * COLS + x0
  }
  /** The path tiles that would join a building's door to the paths: none if a path already starts at its door, up to
   *  two new ones if a path is that close and the ground takes them; null if it cannot be joined. A building without a
   *  door needs none. */
  function linkPath(kind: Building, at: number, o: number): number[] | null {
    if (BUILDINGS[kind].door === undefined) return []
    const e = entrance(kind, at, COLS, ROWS, o); if (e < 0) return null
    if (planWorld.type[e] === T.path) return []
    const fp = new Set(footprint(kind, at, COLS, o)), ex = e % COLS, ey = (e - ex) / COLS
    let best: number[] | null = null, bestScore = Infinity
    for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) {
      const x = ex + dx, y = ey + dy; if (x < 0 || y < 0 || x >= COLS || y >= ROWS || planWorld.type[y * COLS + x] !== T.path) continue
      const line = [e, ...line8(ex, ey, x, y)].filter((i) => planWorld.type[i] !== T.path)
      if (line.length > 2 || line.some((i) => fp.has(i) || !can.path(i))) continue
      const score = line.length * 10 + Math.hypot(dx, dy)           // the fewest new tiles, then the straightest way
      if (score < bestScore) { bestScore = score; best = line }
    }
    return best
  }
  function build() {
    if (!tool || !mark) return
    if (tool === 'harvest') {                                    // not a plan: the farmers go at once (a drag starting on a mark takes marks back)
      const cells = inBox(box(mark)).filter((i) => ripe(i) && !!done[i].h === harvestOff)
      if (harvestOff) both((b) => { for (const i of cells) if (b[i] && !farmers.claimed.has(i)) delete b[i].h }); else both((b) => { for (const i of cells) b[i].h = 1 })
      fieldsAt = 0; relay(null); return
    }
    const b = box(mark), before = JSON.stringify(builds)
    let changed = false
    if (unmark) {                                                // taking marks back
      for (const i of unmarkTiles(stroke ? new Set(stroke) : inBox(b))) if (!same(builds[i], done[i])) { revert(i); changed = true }
    } else if (tool in BUILDINGS) {                                      // a building goes where the pointer was let go
      const k = tool as Building, at = placeAt(k, mark[2], mark[3]), link = linkPath(k, at, rot)
      if (!footprint(k, at, COLS, rot).every(can.building) || link === null) return
      placeBuilding(planWorld, builds, k, at, rot); changed = true
      for (const i of link) builds[i] = { ...builds[i], g: 'path' }
      if (link.length) builds[at] = { ...builds[at], l: link }   // remembered, so taking the building back takes its path too
    } else if (tool === 'upgrade') {
      const at = builds[mark[3] * COLS + mark[2]]?.u; if (at === undefined) return
      const top = builds[at]; if ((top.lv ?? 1) >= BUILDINGS[top.s!].stages) return
      top.lv = (top.lv ?? 1) + 1; changed = true
    } else
    if (stroke) {                                                // a drawn fence or path: every tile it passed that can take it
      for (const i of new Set(stroke)) {
        if (tool === 'fence' && can.fence(i) && !builds[i]?.f) { builds[i] = { ...builds[i], f: 1 }; changed = true }
        if (tool === 'path' && can.path(i)) { builds[i] = { ...builds[i], g: 'path' }; changed = true }
      }
    } else if (tool === 'fence') {
      const ringCells = ring(b, COLS)
      if (b[2] - b[0] + 1 < MIN_ENCLOSURE || b[3] - b[1] + 1 < MIN_ENCLOSURE || !ringCells.every(can.fence)) return
      for (const i of ringCells) if (!builds[i]?.f) { builds[i] = { ...builds[i], f: 1 }; changed = true }
    } else if (tool === 'erase') {
      for (const i of inBox(b)) if (erasable(planWorld, builds, i, eraseKind)) { erase(planWorld, builds, i, eraseKind); changed = true }
    } else if (tool === 'tree') {                                // a tree on each open grass tile: mostly broadleaf, now and then a conifer
      for (const i of inBox(b)) if (can.tree(i)) { const p = Math.random() < 0.7 ? 1 + Math.floor(Math.random() * 3) : 4 + Math.floor(Math.random() * 3); builds[i] = { ...builds[i], p }; delete builds[i].x; changed = true }
    } else if (tool === 'crop') {
      const t = Date.now()
      for (const i of inBox(b)) if (can.crop(i)) { builds[i] = { ...builds[i], c: crop, t }; changed = true }
    } else {
      const ok = tool === 'soil' ? can.soil : can.path
      const g = tool === 'soil' ? 'soil' : 'path'
      for (const i of inBox(b)) if (ok(i)) { builds[i] = { ...builds[i], g }; changed = true }
    }
    if (!changed) return
    history.push(before); if (history.length > 100) history.shift()
    refreshPlan()
  }
  /** Builds the plan: what was marked now stands, what was marked for erasing goes. Crops start growing now. */
  const confirmBuild = () => {
    if (!pending()) return
    const t = Date.now(); for (const k in builds) { const b = builds[k]; if (b.c && done[k]?.c !== b.c) b.t = t }
    const old = done; done = JSON.parse(JSON.stringify(builds)); history.length = 0
    relay(groundDiff(old, done))
  }
  /** Drops the plan: the holograms go, nothing changes. */
  const discardBuild = () => { builds = JSON.parse(JSON.stringify(done)); history.length = 0; refreshPlan() }
  /** Turns the building about to be placed a quarter turn clockwise. */
  const rotateBuild = () => { rot = (rot + 1) % 4; kick() }
  const setBuildTool = (t: BuildTool | null, c?: string) => { tool = t; if (c && (CROPS as readonly string[]).includes(c)) crop = c; mark = null; stroke = null; hover = null; view.style.cursor = t ? 'crosshair' : ''; kick() }
  const undoBuild = () => {
    const prev = history.pop(); if (prev === undefined) return false
    builds = JSON.parse(prev)
    refreshPlan(); return true
  }
  let rt = 0
  window.addEventListener('resize', () => { clearTimeout(rt); rt = window.setTimeout(() => { if (CAM.z < zMin()) CAM.z = zMin(); clampCam(); kick() }, 150) })

  // ---------- selection ----------
  let onSelect: ((id: number | string | null) => void) | null = null
  function select(id: number | string | null) {
    const c = id === null || id === undefined ? null : herd.list.find((q) => String(q.id) === String(id)) ?? null
    if (c === herd.selected) return
    herd.selected = c; kick()
    onSelect?.(c ? c.id : null)
  }

  const ready = ground.ready.then(() => { frameIsland(); return new Promise<void>((r) => { const chk = () => (ground.missing({ x: CAM.x, y: CAM.y, z: CAM.z * dpr() }, size[0], size[1]).length ? requestAnimationFrame(chk) : r()); requestAnimationFrame(chk) }) })

  // the page's weather and time-of-day buttons
  const setWeather = (k: Weather) => { if (!WX[k]) return; state.weather = k; sky.nextFlash = performance.now() / 1000 + 3; document.querySelectorAll<HTMLElement>('[data-weather]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.weather === k))); kick() }
  const setDaytime = (k: Daytime) => { if (!DAYS[k]) return; state.daytime = k; document.querySelectorAll<HTMLElement>('[data-daytime]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.daytime === k))); kick() }
  document.querySelectorAll<HTMLElement>('[data-weather]').forEach((b) => b.addEventListener('click', () => setWeather(b.dataset.weather as Weather)))
  document.querySelectorAll<HTMLElement>('[data-daytime]').forEach((b) => b.addEventListener('click', () => setDaytime(b.dataset.daytime as Daytime)))
  if (opts.weather) setWeather(opts.weather); if (opts.daytime) setDaytime(opts.daytime)

  return {
    setWeather,
    setDaytime,
    setLifeforms: async (list: Lifeform[]) => { const n = await herd.set(list, (name, url) => atlas.add(name, url)); kick(); return n },
    setEnclosures,
    selectCreature: select,
    showCreature: (id: number | string) => {
      const c = herd.list.find((q) => String(q.id) === String(id)); if (!c) return
      CAM.z = Math.max(CAM.z, Math.min(zMax, 60)); CAM.x = c.x - view.clientWidth / CAM.z / 2; CAM.y = c.y - view.clientHeight / CAM.z / 2; clampCam(); select(c.id); kick()
    },
    spriteFor: (species: string) => { const b = speciesKey(species); return b ? b[0] : null },
    onSelect: (fn) => { onSelect = fn },
    fit,
    zoomAt,
    redraw: kick,
    ready,
    setBuildTool,
    plan: () => JSON.parse(JSON.stringify(builds)) as Builds,
    confirmBuild,
    discardBuild,
    rotateBuild,
    undoBuild,
    onBuild: (fn) => { onBuild = fn },
    harvest,
    unharvest,
    onStore: (fn) => { onStore = fn; fn({ ...store }) },
    debug: { farmers, seabed, sky, whales, CAM, stats, ground, world, fields, atlas, sprites, herd, state, BEASTS, setBuilds: (b: Builds) => { const old = done; done = b; builds = JSON.parse(JSON.stringify(b)); history.length = 0; relay(groundDiff(old, done)) } },
  }
}

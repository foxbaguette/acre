// The island on the GPU (WebGL2): the game page's only renderer (its interface is in types.ts).
//
//   world.ts      the island as data, seeded from the map id
//   fields.ts     soft edge fields for every ground, the shore and the mountain levels
//   ground.ts     the ground baked into cached chunks per detail level (decor baked in)
//   atlas.ts      sprite pictures rasterised on demand into texture-array pages
//   sprites.ts    one instanced batch for everything standing or moving
//   creatures.ts  the chain's creatures: placement, wandering, selection
import type { Daytime, Inventory, IslandView, Lifeform, PenLoss, Weather, Season } from '@/engine/types'
import { Atlas } from './atlas'
import { applyBuilds, WILD, BUILDINGS, buildingTiles, cropStage, dims, entrance, erasable, erase, eraseKindAt, footprint, GROW_MS, insideOk, needsPath, placeBuilding, turn, type Building, type EraseKind, MIN_ENCLOSURE, pristineOf, ring, rules, type Builds, type BuildTool, type CellBuild } from './build'
import { CHIMNEYS, FOUNTAINS, LIGHTS, LIT, PAD, RENDERED, SHPAD } from './buildingArt'
import { CROPS } from './crops'
import { Farmers, type Job } from './farmers'
import { BEASTS, Herd, speciesKey } from './creatures'
import { buildFields } from './fields'
import { Ground } from './ground'
import { cloudShapes, DAYS, Sky, WX, blendMood, wxMood } from './sky'
import { FIELD, FIELD_REACH, FLAG, SHAPE, Sprites } from './sprites'
import { buildWorld, COLS, ROWS, seeded, T, type World } from './world'

export interface EngineOptions { tiles: Uint8Array; mapId: string | number; weather?: Weather; daytime?: Daytime; season?: Season; view?: HTMLElement; /** the player's builds, laid over the map */ builds?: Builds }

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
  // the island's own trees are constructs (tree kind WILD), laid onto the land as its woods; the land keeps none of its own
  const land = Uint8Array.from(opts.tiles, (b) => b & 0x3f)
  for (const k in opts.builds ?? {}) if (opts.builds![Number(k)].p === WILD) land[Number(k)] |= 64
  const world: World = buildWorld(land, Number(opts.mapId))
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
  // ---------- the harvest: what grows (land.acre plants), the farmers' jobs (its worker queue) ----------
  // A harvest is not a plan: it goes to the chain at once (onHarvest), and the farmers then walk as its jobs say.
  const both = (fn: (b: Builds) => void) => { fn(done); fn(builds) }      // it changes what stands and the plan alike
  let onHarvest: ((tiles: number[]) => void) | null = null
  /** how long each crop takes to grow, ms (cropcfg); a crop not in it grows at the old pace */
  let growth: Record<string, number> = {}
  const stageOf = (b: CellBuild, now: number) => cropStage(b.t ?? 0, now, growth[b.c ?? ''] ?? GROW_MS)
  const farmers = new Farmers(() => {
    const blocked = walls()
    return { cols: COLS, rows: ROWS,
      walk: (i) => !blocked[i],                                   // water too: a farmer swims, but only where land would be far longer
      water: (i) => !!world.ocean[i] || world.type[i] === T.water,
      cost: (i) => (world.ocean[i] || world.type[i] === T.water ? 6 : world.type[i] === T.path ? 0.6 : done[i]?.c ? 1.15 : 1) }
  }, () => done)
  const ripe = (i: number) => !!done[i]?.c && stageOf(done[i], Date.now()) === '6-harvest'
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
  // pointing at a crop still growing: how long until it is fully grown (gone once it is)
  const cropTip = document.createElement('div'); cropTip.className = 'crop-tip'; cropTip.hidden = true; cropTip.innerHTML = '<b></b><small></small>'; view.append(cropTip)
  let tipTile = -1
  const grownAt = (b: CellBuild) => (b.t ?? 0) + (growth[b.c ?? ''] ?? GROW_MS)
  const inWords = (ms: number) => { const s = Math.max(1, Math.ceil(ms / 1000)); return s >= 3600 ? `${Math.floor(s / 3600)} h ${Math.ceil((s % 3600) / 60)} min` : s >= 60 ? `${Math.floor(s / 60)} min ${s % 60} s` : `${s} s` }
  function placeCropTip() {
    const b = tipTile >= 0 ? done[tipTile] : undefined, left = b?.c ? grownAt(b) - Date.now() : 0
    if (!b?.c || left <= 0 || farmers.cut(tipTile, b.t ?? 0)) { if (!cropTip.hidden) cropTip.hidden = true; return }
    const x = tipTile % COLS, y = (tipTile - x) / COLS, z = CAM.z
    cropTip.querySelector('b')!.textContent = b.c.replace(/-/g, ' ')
    cropTip.querySelector('small')!.textContent = 'fully grown in ' + inWords(left)
    cropTip.style.transform = `translate(${(x + 0.5 - CAM.x) * z}px, ${(y - CAM.y) * z}px)`
    cropTip.hidden = false; kick()   // (the countdown goes on while it shows)
  }
  const penLayer = document.createElement('div'); penLayer.className = 'pen-tags'; view.append(penLayer)
  let pens: { id: string; tiles: number; at: number; el: HTMLDivElement; x: number; y: number }[] = []
  /** The middle of an enclosure: over what stands now, inside its fence (null if it is open here); a pond's, over its water. */
  function penMiddle(at: number, water = false): [number, number] | null {
    const pondAt = (k: number) => world.type[k] === T.water && !world.ocean[k]
    if (water ? !pondAt(at) : done[at]?.f) return null
    const seenP = new Set([at]), st = [at]; let sx = 0, sy = 0, n = 0
    while (st.length) { const j = st.pop()!, x = j % COLS, y = (j - x) / COLS; sx += x; sy += y; n++
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const X = x + dx, Y = y + dy; if (X < 0 || Y < 0 || X >= COLS || Y >= ROWS) { if (water) continue; return null }   // it reaches the edge: open
        const k = Y * COLS + X; if (!seenP.has(k) && (water ? pondAt(k) : !done[k]?.f)) { seenP.add(k); st.push(k) } } }
    return [sx / n + 0.5, sy / n + 0.5]
  }
  const setEnclosures = (list: { id: string; tiles: number; at: number; water?: boolean }[]) => {
    for (const p of pens) p.el.remove()
    pens = []
    for (const e of list) { const m = penMiddle(e.at, e.water); if (!m) continue
      const el = document.createElement('div'); el.className = 'pen-tag' + (e.water ? ' pond' : '')
      el.innerHTML = '<i class="pen-seal"></i><b></b><small></small>'; el.querySelector('i')!.textContent = e.id; el.querySelector('b')!.textContent = (e.water ? 'pond no. ' : 'enclosure no. ') + e.id; el.querySelector('small')!.textContent = e.tiles + ' tile' + (e.tiles === 1 ? '' : 's')
      penLayer.append(el); pens.push({ ...e, el, x: m[0], y: m[1] }) }
    kick()
  }
  function placePens() { const z = CAM.z
    penLayer.classList.toggle('far', z < 10); penLayer.classList.toggle('near', z >= 30)   // close up the whole tags show; further out only their seals
    for (const p of pens) p.el.style.transform = `translate(${(p.x - CAM.x) * z}px, ${(p.y - CAM.y) * z}px)` }
  /** Fully grown tiles not yet being harvested go to the chain: a farmer is sent for them. */
  const harvestTiles = (tiles: number[]) => { const ok = tiles.filter((i) => ripe(i) && !done[i].h); if (ok.length) onHarvest?.(ok) }
  void fieldOf
  /** The farmers' jobs from the chain: their tiles are being harvested (until claimed), and the farmers walk them. */
  const setJobs = (jobs: Job[]) => {
    both((b) => { for (const k in b) if (b[k].h) delete b[k].h })
    for (const j of jobs) if (!j.claimed) both((b) => { for (const i of j.tiles) if (b[i]?.c) b[i].h = 1 })
    farmers.setJobs(jobs); fieldsAt = 0; kick()
  }
  /** What grows, from the chain (crop name and when sown, ms): it replaces the crops that stand; the plan's own
   *  unconfirmed sowing stays. */
  const setPlants = (plants: Record<number, { c: string; t: number }>) => {
    const keys = new Set([...Object.keys(done), ...Object.keys(builds), ...Object.keys(plants)].map(Number))
    const unplanned = new Set([...keys].filter((i) => JSON.stringify(builds[i] ?? {}) === JSON.stringify(done[i] ?? {})))
    for (const i of keys) {
      const b = { ...(done[i] ?? {}) }; delete b.c; delete b.t; delete b.h
      if (plants[i]) { b.c = plants[i].c; b.t = plants[i].t }
      if (Object.keys(b).length) done[i] = b; else delete done[i]
      if (unplanned.has(i)) { if (done[i]) builds[i] = { ...done[i] }; else delete builds[i] }
    }
    fieldsAt = 0; relay(null)
  }
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
  // the season: the one it is now (northern months) unless told
  const SEASONS: Season[] = ['spring', 'summer', 'autumn', 'winter'], month = new Date().getMonth()
  const state = { weather: (opts.weather ?? 'sun') as Weather, daytime: (opts.daytime ?? 'day') as Daytime, season: (opts.season ?? SEASONS[Math.floor(((month + 10) % 12) / 3)]) as Season, motion: !matchMedia('(prefers-reduced-motion: reduce)').matches }
  const winter = () => state.season === 'winter'
  // changes blend in: a new daytime or weather over a few seconds (p: 0 the old, 1 the new); a new season crossfades from
  // the picture before it, held until the new season's ground is drawn
  const FADE_S = 2.5
  const fade = { day: { from: state.daytime, p: 1 }, wx: { from: state.weather, wasWinter: false, p: 1 }, season: { p: 1, hold: false, t0: 0, cam: { x: 0, y: 0, z: 0 } } }
  const ease = (p: number) => p * p * (3 - 2 * p)
  const lerp = (a: number, b: number, k: number) => a + (b - a) * k
  let drawn = false   // (nothing fades before the first picture)

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
  // ice floes for winter: a few on the open sea, each bobbing where it lies, clear of the shore
  const seaAt = (x: number, y: number) => { const X = Math.floor(x), Y = Math.floor(y); return X < 0 || Y < 0 || X >= COLS || Y >= ROWS || world.ocean[Y * COLS + X] === 1 }   // beyond the map it is all sea
  const fl0 = (r: number) => r + 0.6   // room to bob without touching land
  const floeFits = (x: number, y: number, r: number) => seaAt(x, y) && [0, 1, 2, 3, 4, 5].every((k) => seaAt(x + Math.cos(k * 1.047) * (r + 0.4), y + Math.sin(k * 1.047) * (r + 0.4)))
  const floes: { x: number; y: number; r: number; rot: number; seed: number }[] = []
  { const M = 40   // the sea round the map, as far as the view can show it, gets floes too
    let sea = 0; for (let i = 0; i < COLS * ROWS; i++) if (world.ocean[i]) sea++
    sea += (COLS + 2 * M) * (ROWS + 2 * M) - COLS * ROWS
    const R = seeded(Number(opts.mapId) * 31 + 977), n = Math.min(420, Math.round(sea / 45))
    for (let k = 0, tries = 0; k < n && tries < n * 30; tries++) { const r = 0.3 + R() * R() * 1.1, x = -M + R() * (COLS + 2 * M), y = -M + R() * (ROWS + 2 * M)
      if (floeFits(x, y, fl0(r))) { floes.push({ x, y, r, rot: R() * 6.28, seed: R() }); k++ } } }
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

  // decor by season: in spring more flowers and flower carpets come up on open grass (the same every time, from the
  // tile); in winter flowers, carpets and lilies are gone under the snow and ice
  const springDecor: typeof world.decor = []
  { const has = new Set(world.decor.map((d) => Math.round(d.y) * COLS + Math.round(d.x)))
    const meadowKinds = ['meadow-yellow', 'meadow-white', 'meadow-purple', 'meadow-clover']
    for (let i = 0; i < COLS * ROWS; i++) { if (world.type[i] !== T.grass || world.forest[i] || has.has(i)) continue
      const x = i % COLS, y = (i - x) / COLS, h = spot({ x, y }, 9)
      if (h < 0.1) springDecor.push({ x: x + (spot({ x, y }, 10) - 0.5) * 0.5, y: y + (spot({ x, y }, 11) - 0.5) * 0.5, name: 'decor-flowers-' + (h < 0.05 ? 1 : 2), sc: 0.45 + spot({ x, y }, 12) * 0.3, under: false })
      else if (h < 0.22) springDecor.push({ x, y, name: 'decor-' + meadowKinds[Math.floor(spot({ x, y }, 13) * meadowKinds.length)], sc: 1.05 + spot({ x, y }, 14) * 0.15, under: true }) } }
  for (const d of new Set(springDecor.map(decorArt))) atlas.add(d, `art/tiles/${d}.svg?v=2`)
  const UNDER_SNOW = /^decor-(flowers|meadow|lily)/
  const springOk = (d: { x: number; y: number }) => { const i = Math.round(d.y) * COLS + Math.round(d.x), b = done[i]; return world.type[i] === T.grass && !world.forest[i] && !(b && (b.g || b.f || b.c || b.p || b.x || b.u !== undefined)) }
  const decorNow = () => state.season === 'winter' ? world.decor.filter((d) => !UNDER_SNOW.test(d.name)) : state.season === 'spring' ? [...world.decor, ...springDecor.filter(springOk)] : world.decor
  // decor is baked into the ground: meadow carpets after the grass, the rest after the other grounds
  const decorIn = (region: [number, number, number]) => { const [x0, y0, n] = region; return decorNow().filter((d) => d.x > x0 - 2 && d.x < x0 + n + 2 && d.y > y0 - 2 && d.y < y0 + n + 2) }
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
    // winter: ice floes drifting on the sea
    // (each bobs and turns a little where it lies: they do not drift)
    if (winter()) for (const fl of floes) { if (!seen(fl.x, fl.y, 2)) continue; const ph = fl.seed * 40, m = still ? 0 : 1
      sprites.shape(SHAPE.ice, fl.x + Math.sin(t * 0.21 + ph) * 0.07 * m, fl.y + Math.sin(t * 0.17 + ph * 1.3) * 0.05 * m, fl.r, fl.r, [fl.seed, 0, 0, 1], 0, fl.rot + Math.sin(t * 0.13 + ph) * 0.06 * m) }
    const landAt = sprites.n
    // standing on the ground, back to front: trees and land creatures
    const items: [number, number, number, number][] = []        // [depth, kind 0 tree / 1 creature / 2 post / 3 crop / 4 rail / 5 building, index, 0 standing / 1 planned / 2 to be erased]
    const homes: [string, number, number, Building, number][] = []   // the buildings in view: art, top-left x, y, kind, turn
    // a turned point of a building's own drawing, on the map
    const at = (kind: Building, o: number, bx: number, by: number, x: number, y: number) => { const [u, v] = turn(kind, o, x, y); return [bx + u, by + v] }
    // shadows by the time of day: the sun's place (the buildings' shadow pictures were rendered under the same three suns),
    // as how far a shadow reaches along the ground per unit of height, and how dark it is; at night, midday's, faint
    const SUNS = { morning: ['morning', -1.33, 0.33, 0.85], day: ['day', 0.4, 0.3, 1], evening: ['evening', 1.33, 0.33, 0.85], night: ['day', 0.4, 0.3, 0.3] } as Record<string, [string, number, number, number]>
    // (while the daytime changes, the sun moves across and the one shadow picture fades into the next)
    const dk = ease(fade.day.p), s0 = SUNS[fade.day.from] ?? SUNS.day, s1 = SUNS[state.daytime] ?? SUNS.day
    const sunName = s1[0], sunX = lerp(s0[1], s1[1], dk), sunZ = lerp(s0[2], s1[2], dk), aS = lerp(s0[3], s1[3], dk)
    const shadowPics: [string, number][] = s0[0] === s1[0] || dk >= 1 ? [[sunName, aS]] : [[s0[0], s0[3] * (1 - dk)], [sunName, s1[3] * dk]]
    const sunA = Math.atan2(sunZ, sunX), sunL = Math.hypot(sunX, sunZ) / 0.5
    const PLAN = 1, GONE = 2, holo = (st: number) => (st === PLAN ? -1 : st === GONE ? -2 : 1)   // a negative alpha draws a hologram (sprites.ts)
    const tk = (t: { name: string; x: number; y: number }) => t.name + ',' + t.x.toFixed(2) + ',' + t.y.toFixed(2)
    const planTrees = new Set(planWorld.trees.map(tk)), doneTrees = new Set(world.trees.map(tk))
    const trees = [...world.trees, ...planWorld.trees.filter((t) => !doneTrees.has(tk(t)))]
    trees.forEach((tr, i) => { if (seen(tr.x, tr.y, 2)) items.push([tr.y + 0.5, 0, i, i < world.trees.length ? (planTrees.has(tk(tr)) ? 0 : GONE) : PLAN]) })
    const putBuilding = (i: number, b: { s?: Building; o?: number }, st: number, d = 0) => { const x = i % COLS, y = (i - x) / COLS, [w, h] = dims(b.s!, b.o); if (seen(x + w / 2, y + h / 2, Math.max(w, h))) items.push([y + h - 0.05 + d, 5, i, st]) }
    for (const k in done) { const b = done[k]; if (!b.s) continue; const p = builds[k], same = p?.s === b.s && (p.o ?? 0) === (b.o ?? 0)
      putBuilding(Number(k), b, same ? 0 : GONE); if (same && (p.lv ?? 1) !== (b.lv ?? 1)) putBuilding(Number(k), p, PLAN, 0.001) }
    for (const k in builds) { const p = builds[k]; if (!p.s) continue; const d = done[k]; if (d?.s === p.s && (d.o ?? 0) === (p.o ?? 0)) continue; putBuilding(Number(k), p, PLAN) }
    for (const k in done) { const b = done[k]; if (!b.c) continue; const i = Number(k), x = i % COLS, y = (i - x) / COLS; if (farmers.cut(i, b.t ?? 0)) continue; if (seen(x, y, 1)) items.push([y - 0.4, 3, i, builds[k]?.c === b.c ? 0 : GONE]) }
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
    for (const k in done) { if (!done[k].h) continue; const i = Number(k), x = i % COLS, y = (i - x) / COLS; if (!seen(x, y) || farmers.cut(i, done[k].t ?? 0)) continue
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
    for (const [, kind, i, st] of items) if (kind === 0 && st !== PLAN) { const tr = trees[i], bare = winter() && Number(tr.name.slice(-2)) < 4, rr = tr.sc * (bare ? 0.4 : 0.55), aB = bare ? 0.45 : 1
      // cast by the sun the way the buildings' are: the crown's shadow thrown out to the lower right by the tree's height,
      // stretched a little along the light, and a small dark patch at the foot of the trunk
      const hgt = tr.sc * 1.25, ox = hgt * sunX, oy = hgt * sunZ, kS = sunL
      sprites.shape(SHAPE.softShadow, tr.x + 0.5 + ox, tr.y + 0.5 + oy, rr * (1.25 + (kS - 1) * 0.5), rr * 1.0, [...SHADE, 0.36 * aS * aB], 0, sunA)   // soft: a crown lets light through (a bare one more)
      sprites.shape(SHAPE.softShadow, tr.x + 0.5 + ox * .9, tr.y + 0.5 + oy * .9, rr * (.85 + (kS - 1) * 0.35), rr * .68, [...SHADE, 0.22 * aS * aB], 0, sunA)
      sprites.shape(SHAPE.softShadow, tr.x + 0.5 + rr * 0.15, tr.y + 0.5 + rr * 0.2, rr * 0.55, rr * 0.45, [...SHADE, 0.3]) }
    for (const [, kind, i, st] of items) {
      if (kind === 0) {
        const tr = trees[i], conifer = Number(tr.name.slice(-2)) >= 4, rr = tr.sc * (conifer ? 0.46 : 0.56)
        sprites.tree(tr.x + 0.5, tr.y + 0.5 - tr.lift, rr, (tr.phase / 6.2832 * 7.3) % 1, conifer ? 1 : 0, (tr.phase * 3.7) % 1, still ? 0 : tr.sw * 0.4, tr.phase, holo(st))
      } else if (kind === 3) {
        const set = st === PLAN ? builds : done, b = set[i], name = cropArt(b.c!, st === PLAN ? '6-harvest' : stageOf(b, Date.now())), r = atlas.get(name, z); if (!r) continue
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
          if (st !== PLAN) for (const [sn, sa] of shadowPics) { const sw = w + SHPAD[0] + SHPAD[2], sh = h + SHPAD[1] + SHPAD[3], sr = atlas.get(buildingArt(`${base}-o${o}-shadow-${sn}`), Math.max(sw, sh) * z)   // its shadow, where the hour's sun throws it
            if (sr) sprites.picture(sr, x, y, [-SHPAD[0], -SHPAD[1], w + SHPAD[2], h + SHPAD[3]], { color: [1, 1, 1, sa] }) }
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
        if (f.swim) {                                                // swimming: low in the water, rings spreading round, the sack held up out of sight
          for (let k = 0; k < 2; k++) { const a = still ? 0.5 : (t * 0.8 + k / 2 + f.id * 0.31) % 1
            sprites.shape(SHAPE.shadow, f.x, f.y + 0.04, 0.22 + a * 0.3, 0.16 + a * 0.22, [0.88, 0.95, 1, 0.42 * (1 - a)]) }
          sprites.picture(r, f.x, f.y + (still ? 0 : Math.sin(t * 4 + f.id) * 0.02), [-0.44, -0.44, 0.44, 0.44], { rot: f.head + Math.PI / 2 + (still ? 0 : Math.sin(t * 5 + f.id) * 0.18), sx: 0.82, sy: 0.82, flags: FLAG.graded, color: [0.82, 0.9, 1, 0.9] })
          continue }
        const walking = f.state === 'walk', work = f.state === 'harvest', bob = still ? 0 : walking ? Math.abs(Math.sin(t * 9 + f.id)) : work ? Math.abs(Math.sin(t * 7 + f.id)) : 0
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
      const n = world.flies.length * WX[state.weather].flies * DAYS[state.daytime].flies * (winter() ? 0 : 1)
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
    const nf = z < 8 || winter() ? 0 : Math.round(world.swarms.length * DAYS[state.daytime].fireflies * WX[state.weather].flies)
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
    const darkOf = (k: string) => (k === 'night' ? 1 : k === 'evening' ? 0.6 : 0), dark = lerp(darkOf(fade.day.from), darkOf(state.daytime), dk)
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
    for (const fd of [fade.day, fade.wx]) if (fd.p < 1) fd.p = Math.min(1, fd.p + dt / 1000 / FADE_S)
    if (ZOOM.active) {
      const ratio = ZOOM.target / CAM.z
      if (Math.abs(Math.log(ratio)) < 0.003) { ZOOM.active = false; zoomNow(ratio, ZOOM.px, ZOOM.py) } else zoomNow(ratio ** (1 - Math.exp(-dt / 80)), ZOOM.px, ZOOM.py)
    }
    if (state.motion) { herd.step(dt / 1000); stepWhales(dt / 1000) }
    farmers.step(); if (farmers.busy()) kick()   // the harvest goes on even when motion is reduced
    // a crop the farmers have cut is gone: the tile is bare soil, to sow again at once (the chain agrees, claimed or not)
    { let gone = false
      for (const [i] of farmers.cutList()) { const b = done[i]; if (!b?.c || !farmers.cut(i, b.t ?? 0)) continue
        const plan = builds[i], same = plan?.c === b.c && plan?.t === b.t
        delete b.c; delete b.t; delete b.h; if (!Object.keys(b).length) delete done[i]
        if (same && plan) { delete plan.c; delete plan.t; delete plan.h; if (!Object.keys(plan).length) delete builds[i] }
        gone = true }
      if (gone) { fieldsAt = 0; relay(null) } }
    placeTokens()
    placePens()
    placeCropTip()
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
    // the weather, blended while one turns into the next
    const wk = ease(fade.wx.p), wFrom = fade.wx.from, wTo = state.weather
    const COVER = { sun: -0.1, cloudy: 0.03, rain: 0.08, storm: 0.14 } as Record<string, number>, wetOf = (k: string) => (k === 'rain' || k === 'storm' ? 1 : 0)
    const ringsOf = (k: string, wint: boolean) => (wint ? 0 : k === 'storm' ? 2 : k === 'rain' ? 1 : 0)
    const gust = lerp(WX[wFrom].gust, WX[wTo].gust, wk)
    const sp = (from: number, to: number, o: Record<string, unknown> = {}) => sprites.draw(fieldArgs[0], fieldArgs[1], fieldArgs[2], [fieldArgs[3][0], fieldArgs[3][1]], cam, W, H, { time: t, gust, from, to, soil: ground.f[0], ...o })
    // the cloud shadows and the fireflies' light, each in its own small target
    gl!.bindFramebuffer(gl!.FRAMEBUFFER, sky.light!.fb); gl!.viewport(0, 0, sky.light!.w, sky.light!.h); gl!.clearColor(0, 0, 0, 1); gl!.clear(gl!.COLOR_BUFFER_BIT)
    sp(lightAt, glowAt, { blend: 'light' })
    // the scene: ground, swimmers, the water's life, what stands on the ground, cloud shadows, flyers
    gl!.bindFramebuffer(gl!.FRAMEBUFFER, sky.scene!.fb); gl!.viewport(0, 0, W, H)
    const pending = ground.draw(cam, W, H)
    const still = !state.motion
    const farZ = cam.z / d, far = 1 - Math.min(1, Math.max(0, (farZ - 11) / 22)), cover = lerp(COVER[wFrom] ?? 0, COVER[wTo] ?? 0, wk), wet = lerp(wetOf(wFrom), wetOf(wTo), wk)
    sp(0, landAt, { cloud: [far, cover, still ? 0 : t, 0] })
    sky.water(ground.height, ground.fieldSize, [world.cols, world.rows], cam, W, H, t, lerp(ringsOf(wFrom, fade.wx.wasWinter), ringsOf(wTo, winter()), wk), cam.z > 6 ? (still ? 2 : 1) : 0, !still && cam.z > 14, ground.level(cam.z))
    sp(landAt, flyAt)
    // the weather: whole cloud systems as on the planet map; their shadows at every zoom, the clouds themselves from far out
    sky.farClouds(cam, W, H, still ? 0 : t, far, cover, wet, 0)
    sp(flyAt, cloudAt)
    sky.farClouds(cam, W, H, still ? 0 : t, far, cover, wet, 1)
    // a new season: the picture from before, held until the new ground is drawn (or the view moves), then fading out
    if (fade.season.p < 1) { const fs = fade.season, moved = CAM.x !== fs.cam.x || CAM.y !== fs.cam.y || CAM.z !== fs.cam.z
      if (fs.hold && (!need.length || moved || performance.now() - fs.t0 > 2500)) fs.hold = false
      if (!fs.hold) fs.p = Math.min(1, fs.p + dt / 1000 / (moved ? 0.35 : 1.2))
      sky.drawSnap(1 - ease(fs.p)) }
    // graded onto the canvas, then what glows and falls on top
    sky.final(blendMood(DAYS[fade.day.from], DAYS[state.daytime], ease(fade.day.p)), blendMood(wxMood(wFrom, fade.wx.wasWinter), wxMood(wTo, winter()), wk), W, H, true)
    sp(glowAt, end)
    if (!still) { if (wk < 1 && wFrom !== wTo) sky.rain(wFrom, W, H, d, t, dt / 1000, fade.wx.wasWinter, 1 - wk); sky.rain(wTo, W, H, d, t, dt / 1000, winter(), wFrom === wTo ? 1 : wk) }
    drawn = true
    stats.sprites = sprites.n
    stats.frameMs = performance.now() - f0
    stats.frames++
    if (now - stats.at > 1000) { stats.fps = Math.round(stats.frames * 1000 / (now - stats.at)); stats.frames = 0; stats.at = now; const el = document.getElementById('fps'); if (el) el.textContent = `${stats.fps} fps · gl` }
    if (state.motion || pending || need.length || ZOOM.active || fade.day.p < 1 || fade.wx.p < 1 || fade.season.p < 1) kick()
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
    if (tool && ptrs.size === 1 && e.button === 0) { const [x, y] = cellAt(e.clientX, e.clientY); mark = [x, y, x, y]; stroke = (tool === 'fence' || tool === 'path') && !e.shiftKey ? [y * COLS + x] : null; eraseKind = tool === 'erase' ? eraseKindAt(planWorld, builds, y * COLS + x) : null; unmark = unmarks(y * COLS + x); kick() }
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
      { const [cx, cy] = cellAt(hoverAt[0], hoverAt[1]), i = cy * COLS + cx, t = !tool || tool === 'crop' || tool === 'harvest' ? (done[i]?.c ? i : -1) : -1; if (t !== tipTile) { tipTile = t; kick() } }
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
  view.addEventListener('pointerleave', () => { tipTile = -1; if (hover) { hover = null; kick() } kick() })
  view.addEventListener('contextmenu', (e) => e.preventDefault())   // no browser menu on the island (right-drag moves the map while building)

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
  let unmark = false
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
  let onBuild: ((b: Builds, undoable: boolean, pending: number, kind: 'build' | 'erase' | 'both', fenced: PenLoss, left: Inventory | null) => void) | null = null

  // ---------- the inventory: what the island's owner holds (land.acre, table inventory); null: not read, no limit ----------
  // Each tile of soil, path, fence or planted tree takes one, a building one; erasing gives it back. The island's own
  // trees are nobody's. As land.acre counts it: by what stands (done) against the plan (builds).
  let inv: Inventory | null = null, itemNames: Partial<Record<Building, string>> = {}
  const itemOf = (b?: CellBuild): string | null => {
    if (!b) return null
    if (b.g) return b.g
    if (b.f) return 'fence'
    if (b.p) return b.p === WILD ? null : 'tree'
    if (b.s) return itemNames[b.s] ?? b.s
    return null
  }
  /** What is left of each thing once the plan is built. */
  const left = (): Inventory | null => {
    if (!inv) return null
    const out: Inventory = { ...inv }
    for (const k of new Set([...Object.keys(done), ...Object.keys(builds)])) {
      const i = Number(k), a = itemOf(done[i]), b = itemOf(builds[i]); if (a === b) continue
      if (a) out[a] = (out[a] ?? 0) + 1
      if (b) out[b] = (out[b] ?? 0) - 1
    }
    return out
  }
  /** A budget to mark tiles against: afford(i, next) takes what tile i would become from it (and gives back what was
   *  there), or says it is not there. Without an inventory everything is affordable. */
  const budget = () => {
    const b = left()
    return (i: number, next: CellBuild) => {
      if (!b) return true
      const was = itemOf(builds[i]), now = itemOf(next); if (was === now) return true
      if (now && (b[now] ?? 0) <= 0) return false
      if (now) b[now] = (b[now] ?? 0) - 1
      if (was) b[was] = (b[was] ?? 0) + 1
      return true
    }
  }
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
    if (tool === 'harvest') { for (const i of inBox(b)) if (ripe(i) && !done[i].h) out.push([i, 0]); return out }
    if (mark ? unmark : hover && unmarks(hover[1] * COLS + hover[0])) { for (const i of unmarkTiles(stroke ? new Set(stroke) : inBox(b))) out.push([i, 3]); return out }
    const afford = budget()
    if (stroke) { const ok = tool === 'fence' ? can.fence : can.path, put = (i: number): CellBuild => (tool === 'fence' ? { ...builds[i], f: 1 } : { ...builds[i], g: 'path' })
      for (const i of new Set(stroke)) out.push([i, ok(i) && (tool === 'fence' && builds[i]?.f ? true : afford(i, put(i))) ? 0 : 1]); return out }
    if (tool === 'fence') {
      const small = b[2] - b[0] + 1 < MIN_ENCLOSURE || b[3] - b[1] + 1 < MIN_ENCLOSURE, cells = ring(b, COLS)
      const enough = cells.every((i) => builds[i]?.f || afford(i, { ...builds[i], f: 1 }))
      for (const i of cells) out.push([i, !small && enough && can.fence(i) ? 0 : 1])
      return out
    }
    if (tool in BUILDINGS) {                                     // its footprint, and the path its door will be joined to
      const k = tool as Building, at = placeAt(k, m[2], m[3]), fp = footprint(k, at, COLS, rot), link = linkPath(k, at, rot), ok = fp.every(can.building) && link !== null && (insideOk.has(k) || !can.inPen(at)) && afford(at, { s: k }) && (link ?? []).every((i) => afford(i, { ...builds[i], g: 'path' }))
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
    const put = (i: number): CellBuild => (tool === 'soil' ? { ...builds[i], g: 'soil' } : tool === 'path' ? { ...builds[i], g: 'path' } : tool === 'tree' ? { ...builds[i], p: 1 } : builds[i] ?? {})
    for (const i of inBox(b)) out.push([i, ok(i) && afford(i, put(i)) ? 0 : 1])
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
  /** A fence closed an enclosure: the soil inside it goes (with its crops), and so does every building not made to stand
   *  in one, as land.acre does it. */
  function clearPens() {
    can.changed()
    for (const k of Object.keys(builds)) { const i = Number(k), b = builds[i]; if (!b || !can.inPen(i)) continue
      if (b.s && !insideOk.has(b.s)) erase(planWorld, builds, i, 'building')
      if (builds[i]?.g === 'soil') erase(planWorld, builds, i, 'soil') }
  }
  /** What the plan's enclosures take away: soil and buildings that stand now, inside a fence of the plan. */
  function penLoss(): PenLoss {
    const out: PenLoss = { soil: 0, buildings: [] }
    for (const k in done) { const i = Number(k), b = done[i]; if (!can.inPen(i)) continue
      if (b.g === 'soil' && builds[i]?.g !== 'soil') out.soil++
      if (b.s && !builds[i]?.s && !insideOk.has(b.s)) out.buildings.push(b.s) }
    return out
  }
  /** The plan changed: judge it anew and show it (the island itself waits for the plan to be confirmed). */
  function refreshPlan() {
    planFence = applyBuilds(planWorld, pristine, builds); can.changed()
    kick(); onBuild?.(JSON.parse(JSON.stringify(done)), history.length > 0, pending(), planKind(), penLoss(), left())
  }
  /** What stands changed: lay it over the island again; where the ground changed, it is re-drawn over that box. */
  function relay(groundBox: [number, number, number, number] | null) {
    fence = applyBuilds(world, pristine, done); herd.setFences(walls()); setDoors(); farmers.rethink()
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
   *  door needs none, and neither does the main building (the market): it is joined if a path is close, else stands alone. */
  function linkPath(kind: Building, at: number, o: number): number[] | null {
    // one without a path rule may stand alone (joined if a path is close); one with it needs a path touching it, as
    // land.acre checks: at its door if it has one, else anywhere along a side
    const needs = needsPath(kind)
    if (BUILDINGS[kind].door === undefined) {
      if (!needs) return []
      const [w, h] = dims(kind, o), x0 = at % COLS, y0 = (at - x0) / COLS, side: number[] = []
      for (let x = x0; x < x0 + w; x++) side.push((y0 - 1) * COLS + x, (y0 + h) * COLS + x)
      for (let y = y0; y < y0 + h; y++) side.push(y * COLS + x0 - 1, y * COLS + x0 + w)
      return side.some((i) => i >= 0 && i < COLS * ROWS && planWorld.type[i] === T.path) ? [] : null
    }
    const alone = needs ? null : []
    const e = entrance(kind, at, COLS, ROWS, o); if (e < 0) return alone
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
    return best ?? alone
  }
  function build() {
    if (!tool || !mark) return
    if (tool === 'harvest') {                                    // not a plan: a farmer is sent at once (the chain decides who)
      harvestTiles(inBox(box(mark))); return
    }
    const b = box(mark), before = JSON.stringify(builds), afford = budget()
    let changed = false
    if (unmark) {                                                // taking marks back
      for (const i of unmarkTiles(stroke ? new Set(stroke) : inBox(b))) if (!same(builds[i], done[i])) { revert(i); changed = true }
    } else if (tool in BUILDINGS) {                                      // a building goes where the pointer was let go
      const k = tool as Building, at = placeAt(k, mark[2], mark[3]), link = linkPath(k, at, rot)
      if (!footprint(k, at, COLS, rot).every(can.building) || link === null || (!insideOk.has(k) && can.inPen(at))) return
      if (!afford(at, { s: k }) || !link.every((i) => afford(i, { ...builds[i], g: 'path' }))) return   // not enough left
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
        if (tool === 'fence' && can.fence(i) && !builds[i]?.f && afford(i, { ...builds[i], f: 1 })) { builds[i] = { ...builds[i], f: 1 }; changed = true }
        if (tool === 'path' && can.path(i) && afford(i, { ...builds[i], g: 'path' })) { builds[i] = { ...builds[i], g: 'path' }; changed = true }
      }
    } else if (tool === 'fence') {
      const ringCells = ring(b, COLS)
      if (b[2] - b[0] + 1 < MIN_ENCLOSURE || b[3] - b[1] + 1 < MIN_ENCLOSURE || !ringCells.every(can.fence)) return
      if (!ringCells.every((i) => builds[i]?.f || afford(i, { ...builds[i], f: 1 }))) return   // the whole ring, or none of it
      for (const i of ringCells) if (!builds[i]?.f) { builds[i] = { ...builds[i], f: 1 }; changed = true }
    } else if (tool === 'erase') {
      for (const i of inBox(b)) if (erasable(planWorld, builds, i, eraseKind)) { erase(planWorld, builds, i, eraseKind); changed = true }
    } else if (tool === 'tree') {                                // a tree on each open grass tile: mostly broadleaf, now and then a conifer
      for (const i of inBox(b)) if (can.tree(i) && afford(i, { ...builds[i], p: 1 })) { const p = Math.random() < 0.7 ? 1 + Math.floor(Math.random() * 3) : 4 + Math.floor(Math.random() * 3); builds[i] = { ...builds[i], p }; delete builds[i].x; changed = true }
    } else if (tool === 'crop') {
      const t = Date.now()
      for (const i of inBox(b)) if (can.crop(i)) { builds[i] = { ...builds[i], c: crop, t }; changed = true }
    } else {
      const ok = tool === 'soil' ? can.soil : can.path
      const g = tool === 'soil' ? 'soil' : 'path'
      for (const i of inBox(b)) if (ok(i) && afford(i, { ...builds[i], g })) { builds[i] = { ...builds[i], g }; changed = true }
    }
    if (!changed) return
    // one construct a tile: where something is built now, the island's own tree there makes way
    for (const k in builds) { const q = builds[k]; if (q.p === WILD && (q.g || q.f || q.u !== undefined)) delete q.p }
    if (tool === 'fence') clearPens()
    history.push(before); if (history.length > 100) history.shift()
    refreshPlan()
  }
  /** Builds the plan: what was marked now stands, what was marked for erasing goes. Crops start growing now. */
  const confirmBuild = () => {
    if (!pending()) return
    const t = Date.now(); for (const k in builds) { const b = builds[k]; if (b.c && done[k]?.c !== b.c) b.t = t }
    inv = left()
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
  let onConditions: ((c: { season: Season; daytime: Daytime; weather: Weather }) => void) | null = null
  const told = () => onConditions?.({ season: state.season, daytime: state.daytime, weather: state.weather })
  const setWeather = (k: Weather) => { if (!WX[k]) return; if (drawn && k !== state.weather) fade.wx = { from: state.weather, wasWinter: winter(), p: 0 }; else fade.wx.wasWinter = winter(); state.weather = k; told(); sky.nextFlash = performance.now() / 1000 + 3; document.querySelectorAll<HTMLElement>('[data-weather]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.weather === k))); kick() }
  const setDaytime = (k: Daytime) => { if (!DAYS[k]) return; if (drawn && k !== state.daytime) fade.day = { from: state.daytime, p: 0 }; state.daytime = k; told(); document.querySelectorAll<HTMLElement>('[data-daytime]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.daytime === k))); kick() }
  const setSeason = (k: Season) => { const n = SEASONS.indexOf(k); if (n < 0) return
    if (drawn && k !== state.season && sky.snapshot()) fade.season = { p: 0, hold: true, t0: performance.now(), cam: { ...CAM } }
    if (fade.wx.p >= 1) fade.wx.wasWinter = k === 'winter'
    state.season = k; sprites.season = n; told()
    if (ground.look[3] !== n) { ground.look[3] = n; ground.restyle() }
    document.querySelectorAll<HTMLElement>('[data-season]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.season === k))); kick() }
  setSeason(state.season)
  // the season, daytime and weather buttons, wherever the page puts them (and whenever it draws them)
  document.addEventListener('click', (e) => { const b = (e.target as Element | null)?.closest?.('[data-season], [data-daytime], [data-weather]') as HTMLElement | null; if (!b) return
    if (b.dataset.season) setSeason(b.dataset.season as Season); else if (b.dataset.daytime) setDaytime(b.dataset.daytime as Daytime); else if (b.dataset.weather) setWeather(b.dataset.weather as Weather) })
  if (opts.weather) setWeather(opts.weather); if (opts.daytime) setDaytime(opts.daytime)

  return {
    setWeather,
    setDaytime,
    setSeason,
    onConditions: (fn) => { onConditions = fn; told() },
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
    setInventory: (held, names) => { inv = held; itemNames = names; refreshPlan() },
    onHarvest: (fn) => { onHarvest = fn },
    setJobs,
    setPlants,
    setGrowth: (g) => { growth = g; fieldsAt = 0; kick() },
    debug: { farmers, seabed, sky, whales, floes, CAM, stats, ground, world, fields, atlas, sprites, herd, state, BEASTS, setBuilds: (b: Builds) => { const old = done; done = b; builds = JSON.parse(JSON.stringify(b)); history.length = 0; relay(groundDiff(old, done)) } },
  }
}

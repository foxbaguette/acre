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
import { applyBuilds, BUILDINGS, buildingTiles, cropStage, erasable, erase, eraseKindAt, footprint, placeBuilding, type Building, type EraseKind, MIN_ENCLOSURE, pristineOf, ring, rules, type Builds, type BuildTool } from './build'
import { CROPS } from './crops'
import { BEASTS, Herd, speciesKey } from './creatures'
import { buildFields } from './fields'
import { Ground } from './ground'
import { cloudShapes, DAYS, Sky, WX } from './sky'
import { FLAG, SHAPE, Sprites } from './sprites'
import { buildWorld, COLS, ROWS, TREES, type World } from './world'

export interface EngineOptions { tiles: Uint8Array; mapId: string | number; weather?: Weather; daytime?: Daytime; view?: HTMLElement; /** the player's builds, laid over the map */ builds?: Builds }

/** Small machines get fewer pixels and a smaller cache from the start. */
const LOW = !!(((navigator as { deviceMemory?: number }).deviceMemory ?? 8) <= 4 || (navigator.hardwareConcurrency || 8) <= 2)


// a butterfly from above, as the old renderer painted it: shadow below, two wings a side, a body (s = one unit, 192 px canvas)
const FLY_COLOURS = [['#FFFFFF', '#F3E9C8'], ['#F6D04D', '#E8A93A'], ['#F2A7C3', '#E07AA3'], ['#A9D4F5', '#6FAEE0']]
const FLY_STAGES = 8
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
  // no trees where a mountain stands: inside its outline (and a little around it)
  { const { S, w, tex } = fields, at = (x: number, y: number) => (Math.min(fields.h - 1, Math.max(0, Math.round((y + 0.5) * S))) * w + Math.min(w - 1, Math.max(0, Math.round((x + 0.5) * S)))) * 4
    const ok = (x: number, y: number) => tex[1][at(x, y) + 3] < 0.4                  // F1.a: how much mountain shows here
    world.trees = world.trees.filter((tr) => [[0, 0], [0.5, 0], [-0.5, 0], [0, 0.5], [0, -0.5]].every(([dx, dy]) => ok(tr.x + dx, tr.y + dy))) }
  // the player's builds, over the island as the chain made it; saved ones the map no longer allows are left out
  const pristine = pristineOf(world)
  const mountainAt = (i: number) => fields.tex[1][(Math.min(fields.h - 1, Math.round(((i / COLS | 0) + 0.5) * fields.S)) * fields.w + Math.min(fields.w - 1, Math.round(((i % COLS) + 0.5) * fields.S))) * 4 + 3]
  let builds: Builds = {}
  const can = rules(world, () => builds, mountainAt)
  for (const k in opts.builds ?? {}) if (can.open(Number(k))) builds[Number(k)] = { ...opts.builds![Number(k)] }
  let fence = applyBuilds(world, pristine, builds)
  if (Object.values(builds).some((b) => b.g)) fields.refreshGrounds()
  const t2 = performance.now()
  const ground = new Ground(gl, world, fields, LOW ? 256 : 512, LOW)
  { const q = new URLSearchParams(location.search).get('ground'); if (q) q.split(',').forEach((v, k) => { if (k < 4) ground.look[k] = Number(v) || 0 }) }   // ?ground=path,soil,rock: try a look
  const atlas = new Atlas(gl, LOW ? 4 : 8)
  const sprites = new Sprites(gl)
  const herd = new Herd(world)
  const walls = () => { const b = buildingTiles(builds, fence.length); for (let i = 0; i < b.length; i++) b[i] |= fence[i]; return b }   // what creatures cannot cross
  herd.setFences(walls())
  const sky = new Sky(gl)
  const CLOUD = cloudShapes()
  const stats = { worldMs: t1 - t0, fieldsMs: t2 - t1, fps: 0, frames: 0, at: 0, frameMs: 0, sprites: 0 }
  const state = { weather: (opts.weather ?? 'sun') as Weather, daytime: (opts.daytime ?? 'day') as Daytime, motion: !matchMedia('(prefers-reduced-motion: reduce)').matches }

  // the pictures: trees, decor, butterflies (creatures are added when they arrive)
  for (const n of TREES) atlas.add(n, `/art/tiles/${n}.svg?v=1`)
  for (let m = 0; m < 16; m++) { const n = `fence-${m.toString(2).padStart(4, '0')}`; atlas.add(n, `/art/tiles/${n}.svg?v=1`) }
  for (const d of new Set(world.decor.map((q) => q.name))) atlas.add(d, `/art/tiles/${d}.svg?v=1`)
  FLY_COLOURS.forEach((c, ci) => { for (let i = 0; i < FLY_STAGES; i++) atlas.add(`fly-${ci}-${i}`, (g, px) => paintFly(g, px, 0.25 + 0.75 * (i + 0.5) / FLY_STAGES, c)) })

  // decor is baked into the ground: meadow carpets after the grass, the rest after the other grounds
  const decorIn = (region: [number, number, number]) => { const [x0, y0, n] = region; return world.decor.filter((d) => d.x > x0 - 2 && d.x < x0 + n + 2 && d.y > y0 - 2 && d.y < y0 + n + 2) }
  ground.canBake = (region, L) => { let ok = true; for (const d of decorIn(region)) if (!atlas.ready(d.name, d.sc * L)) ok = false; return ok }
  ground.decor = (stage, region, L, S) => {
    sprites.begin()
    for (const d of decorIn(region)) {
      if (d.under !== (stage === 0) || (d.name === 'decor-lily') !== (stage === 2)) continue
      const r = atlas.get(d.name, d.sc * L); if (!r) continue
      sprites.picture(r, d.x + 0.5, d.y + 0.5, [-d.sc / 2, -d.sc / 2, d.sc / 2, d.sc / 2])
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
      sprites.picture(r, c.x, y, [-c.size / 2, -c.size / 2, c.size / 2, c.size / 2], { rot: c.head + Math.PI / 2, sx: breathe * (1 - bob * 0.03), sy: breathe * (1 + bob * 0.05), flags })
    }
    // under the water's surface: swimmers, tinted and clipped by the water, with a ripple spreading round each
    for (const c of herd.list) if (c.home === 'water' && seen(c.x, c.y)) {
      if (c === herd.selected) halo(c, c.y)
      body(c, c.y, FLAG.water)
      if (!still) { const k = (t * 0.6 + c.phase) % 1; sprites.shape(SHAPE.ripple, c.x, c.y, c.size * (0.35 + k * 0.3) / 0.92, c.size * (0.25 + k * 0.2) / 0.92, [225 / 255, 245 / 255, 1, (1 - k) * 0.6], FLAG.water) }
    }
    const landAt = sprites.n
    // standing on the ground, back to front: trees and land creatures
    const items: [number, number, number][] = []                // [depth, kind 0 tree / 1 creature / 2 fence, index]
    world.trees.forEach((tr, i) => { if (seen(tr.x, tr.y, 2)) items.push([tr.y + 0.5, 0, i]) })
    const now = Date.now()
    for (const k in builds) { const b = builds[k]; if (!b.s) continue; const i = Number(k), x = i % COLS, y = (i - x) / COLS, { w, h } = BUILDINGS[b.s]; if (seen(x + w / 2, y + h / 2, Math.max(w, h))) items.push([y + h - 0.05, 5, i]) }
    for (const k in builds) { const b = builds[k]; if (!b.c) continue; const i = Number(k), x = i % COLS, y = (i - x) / COLS; if (seen(x, y, 1)) items.push([y - 0.4, 3, i]) }
    for (let i = 0; i < fence.length; i++) if (fence[i]) {
      const x = i % COLS, y = (i - x) / COLS; if (!seen(x, y, 1)) continue
      const a = anchor(i); items.push([a[1] + 0.12, 2, i])
      for (let k = 0; k < 4; k++) { const j = linked(fence, i, k); if (j >= 0) items.push([(a[1] + anchor(j)[1]) / 2 + 0.1, 4, i * 4 + k]) }
    }
    herd.list.forEach((c, i) => { if (c.home === 'land' && seen(c.x, c.y)) items.push([c.y, 1, i]) })
    items.sort((a, b) => a[0] - b[0])
    for (const [, kind, i] of items) {
      if (kind === 0) {
        const tr = world.trees[i], r = atlas.get(tr.name, tr.sc * z); if (!r) continue
        sprites.picture(r, tr.x + 0.5, tr.y + 0.5 - tr.lift, [-tr.sc / 2, 0.5 - tr.sc, tr.sc / 2, 0.5], { sway: still ? 0 : tr.sw, phase: tr.phase, flags: FLAG.graded })
      } else if (kind === 3) {
        const b = builds[i], name = cropArt(b.c!, cropStage(b.t ?? 0, now)), r = atlas.get(name, z); if (!r) continue
        const x = i % COLS, y = (i - x) / COLS
        sprites.picture(r, x + 0.5, y + 0.5, [-0.5, -0.5, 0.5, 0.5], { sway: still ? 0 : 0.12, phase: i * 0.37, flags: FLAG.graded })
      } else if (kind === 2) {                                  // a post, standing on its anchor
        const r = atlas.get('fence-0000', z); if (!r) continue
        const [ax, ay] = anchor(i)
        sprites.picture(r, ax, ay, [-0.5, -0.5, 0.5, 0.5], { flags: FLAG.graded })
      } else if (kind === 5) {                                  // a building, standing on its footprint
        const b = builds[i], spec = BUILDINGS[b.s!], name = buildingArt(spec.art(b.lv ?? 1)), r = atlas.get(name, Math.max(spec.w, spec.h) * z); if (!r) continue
        const x = i % COLS, y = (i - x) / COLS
        sprites.picture(r, x + spec.w / 2, y + spec.h, [-spec.w / 2, -spec.h, spec.w / 2, 0], { flags: FLAG.graded })
      } else if (kind === 4) {                                  // a rail from one post to the next: the rail part of the straight fence art, stretched and turned
        const r = atlas.get('fence-0101', z); if (!r) continue
        const a = i >> 2, b = linked(fence, a, i & 3), [x0, y0] = anchor(a), [x1, y1] = anchor(b)
        const len = Math.hypot(x1 - x0, y1 - y0), u = r.u0 + (r.u1 - r.u0) * 0.43
        sprites.picture({ ...r, u1: u }, (x0 + x1) / 2, (y0 + y1) / 2, [-len / 2, -0.5, len / 2, 0.5], { rot: Math.atan2(y1 - y0, x1 - x0), flags: FLAG.graded })
      } else {
        const c = herd.list[i]
        if (c === herd.selected) halo(c, c.y)
        sprites.shape(SHAPE.shadow, c.x + c.size * 0.06, c.y + c.size * 0.09, c.size * 0.34, c.size * 0.26, [...SHADE, 0.3])
        body(c, c.y, FLAG.graded)
      }
    }
    // the tiles a build would cover: gold where it can go, red where it cannot, pale where something will be erased
    for (const [i, k] of preview()) { const x = i % COLS, y = (i - x) / COLS; if (seen(x, y)) sprites.shape(SHAPE.tile, x + 0.5, y + 0.5, 0.5, 0.5, k === 0 ? [0.98, 0.82, 0.4, 0.9] : k === 1 ? [0.9, 0.32, 0.25, 0.5] : [1, 0.94, 0.86, 0.95]) }
    // the shadows of flyers, far below
    for (const c of herd.list) if (c.home === 'air' && seen(c.x, c.y, 2)) {
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
    for (const c of herd.list) if (c.home === 'air' && seen(c.x, c.y, 2)) {
      const lift = 0.9 + (still ? 0 : 0.08 * Math.sin(t * 1.3 + c.phase))
      if (c === herd.selected) halo(c, c.y)
      body(c, c.y - lift * 0.15, FLAG.graded)
    }
    // Cloud shadows drift slowly across the whole world; when the sky turns cloudy, more grow in over a couple of seconds
    const cloudAt = sprites.n
    const target = WX[state.weather].more; sky.grow = still ? target : sky.grow + Math.sign(target - sky.grow) * Math.min(Math.abs(target - sky.grow), dt / 2)
    const M = Math.max(10, (view.clientWidth / zMin() - COLS) / 2 + 6)   // clouds appear and vanish beyond the widest view, then drift in
    const tt = still ? 0 : t
    for (let k = 0; k < 7 + (sky.grow > 0.01 ? 28 : 0); k++) {
      const more = k >= 7, p = more ? CLOUD.puffs[k - 7] : null, grow = p ? Math.min(1, Math.max(0, sky.grow * 1.5 - p.delay)) : 1; if (grow <= 0) continue
      const w = p ? p.w * (0.55 + 0.45 * grow) : [8, 14, 22, 10, 30, 12, 80][k], giant = k === 6, span = COLS + 30 + 2 * M + (giant ? 200 : 0)
      const cx0 = p ? ((tt * p.sp + p.x * span) % span) - 15 - M : ((tt * (giant ? 0.2 : 0.3) + (giant ? 60 : k * span / 6)) % span) - 15 - M
      const cy0 = p ? p.y * (ROWS + 16) - 8 + Math.sin(tt * 0.05 + p.phase) * 0.8 : ((k * 7.3) % ROWS) + Math.sin(tt * 0.05 + k) * 0.8
      const wx = cx0 + 15 - w / 2, wy = cy0 - w * 0.35, tall = p ? p.tall : 0.7, shape = p ? p.shape : CLOUD.clouds[k % 6]
      if (wx + w < x0 || wx > x1 || wy + w * tall < y0 || wy > y1) continue
      for (const [bx, by, rx, ry, tilt] of shape.blobs) {
        const soft = 2 * shape.blur / rx
        sprites.shape(SHAPE.cloud, wx + bx * w, wy + by * w * tall, rx * w * (1 + soft), ry * w * tall * (1 + soft), [0, soft, 0, p ? grow * grow : 1], 0, tilt)
      }
    }
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
    const glowAt = sprites.n
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
    if (state.motion) herd.step(dt / 1000)
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
    const sp = (from: number, to: number, o: Record<string, unknown> = {}) => sprites.draw(fieldArgs[0], fieldArgs[1], fieldArgs[2], [fieldArgs[3][0], fieldArgs[3][1]], cam, W, H, { time: t, gust: WX[state.weather].gust, from, to, ...o })
    // the cloud shadows and the fireflies' light, each in its own small target
    gl!.bindFramebuffer(gl!.FRAMEBUFFER, sky.clouds!.fb); gl!.viewport(0, 0, sky.clouds!.w, sky.clouds!.h); gl!.clearColor(0, 0, 0, 0); gl!.clear(gl!.COLOR_BUFFER_BIT)
    sp(cloudAt, lightAt, { blend: 'max' })
    gl!.bindFramebuffer(gl!.FRAMEBUFFER, sky.light!.fb); gl!.viewport(0, 0, sky.light!.w, sky.light!.h); gl!.clearColor(0, 0, 0, 1); gl!.clear(gl!.COLOR_BUFFER_BIT)
    sp(lightAt, glowAt, { blend: 'light' })
    // the scene: ground, swimmers, the water's life, what stands on the ground, cloud shadows, flyers
    gl!.bindFramebuffer(gl!.FRAMEBUFFER, sky.scene!.fb); gl!.viewport(0, 0, W, H)
    const pending = ground.draw(cam, W, H)
    sp(0, landAt)
    const still = !state.motion
    sky.water(ground.height, ground.fieldSize, [world.cols, world.rows], cam, W, H, t, state.weather === 'storm' ? 2 : state.weather === 'rain' ? 1 : 0, cam.z > 6 ? (still ? 2 : 1) : 0, !still && cam.z > 14, ground.level(cam.z))
    sp(landAt, flyAt)
    sky.cloudShadows(Math.min(1, WX[state.weather].clouds * 1.3))
    sp(flyAt, cloudAt)
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
    if (tool && ptrs.size === 1 && e.button === 0) { const [x, y] = cellAt(e.clientX, e.clientY); mark = [x, y, x, y]; stroke = (tool === 'fence' || tool === 'path') && !e.shiftKey ? [y * COLS + x] : null; eraseKind = tool === 'erase' ? eraseKindAt(world, builds, y * COLS + x) : null; kick() }
    else { mark = null; stroke = null }
  })
  view.addEventListener('pointermove', (e) => {
    const p = ptrs.get(e.pointerId); if (!p) return
    ptrs.set(e.pointerId, [e.clientX, e.clientY])
    if (mark && ptrs.size === 1) { const [x, y] = cellAt(e.clientX, e.clientY); if (x !== mark[2] || y !== mark[3]) { if (stroke) stroke.push(...line8(mark[2], mark[3], x, y)); mark[2] = x; mark[3] = y; kick() } return }
    if (ptrs.size === 2) {
      mark = null
      const [a, b] = [...ptrs.values()], dd = Math.hypot(a[0] - b[0], a[1] - b[1]), r = view.getBoundingClientRect()
      if (pinch) zoomNow(dd / pinch, (a[0] + b[0]) / 2 - r.left, (a[1] + b[1]) / 2 - r.top); pinch = dd; return
    }
    CAM.x -= (e.clientX - p[0]) / CAM.z; CAM.y -= (e.clientY - p[1]) / CAM.z; clampCam(); kick()
  })
  const up = (e: PointerEvent) => {
    if (mark) { if (e.type === 'pointerup') build(); mark = null; stroke = null; kick() }
    else if (e.type === 'pointerup' && press && press.id === e.pointerId && Math.hypot(e.clientX - press.x, e.clientY - press.y) < 6) {   // a click, not a drag
      const [wx, wy] = toWorld(e.clientX, e.clientY), c = herd.at(wx, wy, CAM.z)
      if (c) select(c.id)                                       // clicking the map does not let go: only the card's close button or Esc
    }
    press = null; ptrs.delete(e.pointerId); pinch = 0; if (!ptrs.size) view.classList.remove('drag')
  }
  view.addEventListener('pointerup', up); view.addEventListener('pointercancel', up)
  let hoverCur = '', hoverRaf = 0, hoverAt: [number, number] = [0, 0]
  view.addEventListener('pointermove', (e) => {
    if (ptrs.size) return; hoverAt = [e.clientX, e.clientY]
    if (!hoverRaf) hoverRaf = requestAnimationFrame(() => {
      hoverRaf = 0
      if (tool) { const c = cellAt(hoverAt[0], hoverAt[1]); if (!hover || c[0] !== hover[0] || c[1] !== hover[1]) { hover = c; kick() } return }
      const [wx, wy] = toWorld(hoverAt[0], hoverAt[1]), want = herd.at(wx, wy, CAM.z) ? 'pointer' : ''; if (want !== hoverCur) { hoverCur = want; view.style.cursor = want }
    })
  })
  view.addEventListener('wheel', (e) => { e.preventDefault(); const r = view.getBoundingClientRect(); zoomAt(Math.exp(-e.deltaY * 0.0015), e.clientX - r.left, e.clientY - r.top) }, { passive: false })
  view.addEventListener('dblclick', (e) => { e.preventDefault(); const r = view.getBoundingClientRect(); zoomTo(CAM.z * (e.shiftKey ? 0.5 : 2), e.clientX - r.left, e.clientY - r.top) })
  document.getElementById('zin')?.addEventListener('click', () => zoomAt(1.4, view.clientWidth / 2, view.clientHeight / 2))
  document.getElementById('zout')?.addEventListener('click', () => zoomAt(1 / 1.4, view.clientWidth / 2, view.clientHeight / 2))
  document.getElementById('zfit')?.addEventListener('click', fit)
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') { if (mark) { mark = null; kick() } else if (herd.selected) select(null) } })
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
  let tool: BuildTool | null = null, mark: [number, number, number, number] | null = null, hover: [number, number] | null = null
  /** the tiles a fence or path being drawn passes, in order; null while dragging a rectangle */
  let stroke: number[] | null = null
  /** what an erase that is being dragged is after: set by the tile it started on */
  let eraseKind: EraseKind | null = null
  /** The tiles from one to the next as a straight line, diagonal steps allowed (fences and paths join corner to corner). */
  function line8(x0: number, y0: number, x1: number, y1: number): number[] {
    const out: number[] = [], n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0))
    for (let k = 1; k <= n; k++) out.push(Math.round(y0 + (y1 - y0) * k / n) * COLS + Math.round(x0 + (x1 - x0) * k / n))
    return out
  }
  let crop: string = CROPS.includes('wheat' as never) ? 'wheat' : CROPS[0]
  let onBuild: ((b: Builds, undoable: boolean) => void) | null = null
  const history: string[] = []                                  // the builds before each change, for undo
  const added = new Set<string>()
  const buildingArt = (n: string) => { if (!added.has(n)) { added.add(n); atlas.add(n, `/art/tiles/${n}.svg?v=2`) } return n }
  const cropArt = (c: string, stage: string) => { const n = `crop-${c}-${stage}`; if (!added.has(n)) { added.add(n); atlas.add(n, `/art/crops/${c}/${stage}.svg?v=1`) } return n }
  const box = (m: [number, number, number, number]): [number, number, number, number] => [Math.min(m[0], m[2]), Math.min(m[1], m[3]), Math.max(m[0], m[2]), Math.max(m[1], m[3])]
  const inBox = ([x0, y0, x1, y1]: [number, number, number, number]) => { const out: number[] = []; for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) out.push(y * COLS + x); return out }
  /** The tiles the build being marked would cover: 0 it goes there, 1 it cannot, 2 something there will be erased. */
  function preview(): [number, number][] {
    if (!tool) return []
    const m = mark ?? (hover ? [hover[0], hover[1], hover[0], hover[1]] as [number, number, number, number] : null); if (!m) return []
    const b = box(m), out: [number, number][] = []
    if (stroke) { const ok = tool === 'fence' ? can.fence : can.path; for (const i of new Set(stroke)) out.push([i, ok(i) ? 0 : 1]); return out }
    if (tool === 'fence') {
      const small = b[2] - b[0] + 1 < MIN_ENCLOSURE || b[3] - b[1] + 1 < MIN_ENCLOSURE
      for (const i of ring(b, COLS)) out.push([i, !small && can.fence(i) ? 0 : 1])
      return out
    }
    if (tool in BUILDINGS) { const at = placeAt(tool as Building, m[2], m[3]); return footprint(tool as Building, at, COLS).map((i) => [i, can.building(i) ? 0 : 1] as [number, number]) }
    if (tool === 'upgrade') { const at = builds[m[3] * COLS + m[2]]?.u; if (at === undefined) return []; const b = builds[at]; return footprint(b.s!, at, COLS).map((i) => [i, (b.lv ?? 1) < BUILDINGS[b.s!].stages ? 0 : 1] as [number, number]) }
    if (tool === 'erase') { const k = mark ? eraseKind : eraseKindAt(world, builds, m[0] + m[1] * COLS); for (const i of inBox(b)) if (erasable(world, builds, i, k)) out.push([i, 2]); return out }
    const ok = tool === 'soil' ? can.soil : tool === 'path' ? can.path : can.crop
    for (const i of inBox(b)) out.push([i, ok(i) ? 0 : 1])
    return out
  }
  /** Lays the builds over the island again; where the ground changed, it is re-drawn over that box. */
  function relay(groundBox: [number, number, number, number] | null) {
    fence = applyBuilds(world, pristine, builds); herd.setFences(walls())
    if (groundBox) { fields.refreshGrounds(); ground.rebuild(fields, groundBox) }
    kick(); onBuild?.(JSON.parse(JSON.stringify(builds)), history.length > 0)
  }
  /** The box round every tile whose ground differs between two sets of builds, or null. */
  function groundDiff(a: Builds, b: Builds): [number, number, number, number] | null {
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
    for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) {
      const i = Number(k); if (a[i]?.g === b[i]?.g) continue
      const x = i % COLS, y = (i - x) / COLS; x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y)
    }
    return x1 < x0 ? null : [x0, y0, x1, y1]
  }
  /** The top-left tile of a building of this kind centred on the tile under the pointer, kept on the map. */
  function placeAt(kind: Building, cx: number, cy: number) {
    const { w, h } = BUILDINGS[kind], x0 = Math.max(0, Math.min(COLS - w, cx - Math.floor(w / 2))), y0 = Math.max(0, Math.min(ROWS - h, cy - Math.floor(h / 2)))
    return y0 * COLS + x0
  }
  function build() {
    if (!tool || !mark) return
    const b = box(mark), before = JSON.stringify(builds), old: Builds = JSON.parse(before)
    let changed = false
    if (tool in BUILDINGS) {                                      // a building goes where the pointer was let go
      const at = placeAt(tool as Building, mark[2], mark[3])
      if (!footprint(tool as Building, at, COLS).every(can.building)) return
      placeBuilding(world, builds, tool as Building, at); changed = true
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
      for (const i of inBox(b)) if (erasable(world, builds, i, eraseKind)) { erase(world, builds, i, eraseKind); changed = true }
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
    relay(groundDiff(old, builds))
  }
  const setBuildTool = (t: BuildTool | null, c?: string) => { tool = t; if (c && (CROPS as readonly string[]).includes(c)) crop = c; mark = null; stroke = null; hover = null; view.style.cursor = t ? 'crosshair' : ''; kick() }
  const undoBuild = () => {
    const prev = history.pop(); if (prev === undefined) return false
    const old = builds; builds = JSON.parse(prev)
    relay(groundDiff(old, builds)); return true
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
    selectCreature: select,
    spriteFor: (species: string) => { const b = speciesKey(species); return b ? b[0] : null },
    onSelect: (fn) => { onSelect = fn },
    fit,
    zoomAt,
    redraw: kick,
    ready,
    setBuildTool,
    undoBuild,
    onBuild: (fn) => { onBuild = fn },
    debug: { CAM, stats, ground, world, fields, atlas, sprites, herd, state, BEASTS },
  }
}

import { useEffect, useRef, useState } from 'react'

import { acidWord, fetchAllMaps, fetchMapTiles, placeWords, spiralPlace, type PlayerMap } from '@/chain/maps'
import { drift, openSea } from '@/chain/world'
import { Header } from '@/journal/Header'

// The world map: every island at its place (land.acre maps x, y: a spiral out from 0, 0 that leaves open sea), seen from
// high above: an animated ocean, the islands' own land with shallow water and surf round their coasts, clouds when far
// out. One square of the world is one island (100 × 100 tiles), each a little off its square (drift), so no grid shows.
// Islands are read only once they are in view, and kept. Their tags are the enclosures' seals.

const TILES = 100, SEA_REACH = 32   // tiles of shallow water counted out from a coast
// an island's pictures reach this many tiles past its square on every side, so its shallows and surf fade out by
// distance wherever its land lies (also right at the edge of its square), never cut off by the square
const PAD = 24, SIDE = TILES + 2 * PAD, REACH = PAD / TILES
/** The islands' seals (number, name, owner): hidden for now; a click on an island still opens its card. */
const SHOW_SEALS = false
interface Isle { map: PlayerMap; x: number; y: number; ox: number; oy: number; placed: boolean; tex: WebGLTexture[] | null; asked: boolean; tag: HTMLDivElement | null }

// the land's colours (bits 0-2: fresh water, beach, grass, hills, field, road), as seen from high above; the hills are
// gentle grassy ones now, as on the islands: a green a little deeper than the grass, rising only a little
const GROUND: Record<number, [number, number, number]> = { 1: [62, 118, 132], 2: [222, 204, 158], 3: [118, 150, 80], 4: [112, 146, 76], 5: [124, 96, 66], 6: [176, 160, 122] }

const NOISE = `
float h2(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f);
  return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float s = 0., a = .5; for (int k = 0; k < 5; k++) { s += a * vn(p); p = p * 2.03 + 17.1; a *= .5; } return s; }`
const VERT = `#version 300 es
in vec2 aPos; uniform vec4 uRect; uniform vec2 uCam; uniform float uZoom; uniform vec2 uRes; out vec2 vUv; out vec2 vWorld;
void main() { vUv = aPos; vWorld = uRect.xy + aPos * uRect.zw; vec2 s = (vWorld - uCam) * uZoom / (uRes * .5); gl_Position = vec4(s.x, -s.y, 0, 1); }`
// the ocean, everywhere: swell and ripples moving, glints of sun, deeper and lighter reaches
const OCEAN = `#version 300 es
precision highp float; in vec2 vWorld; uniform float uTime, uZoom; out vec4 o; ${NOISE}
vec3 sea(vec2 w, float t, float detail) {
  float big = fbm(w * .35 + vec2(t * .004, -t * .003));
  float swell = fbm(w * 3. + vec2(t * .05, t * .03)), rip = fbm(w * 9. - vec2(t * .09, t * .06));
  float waves = mix(.5, swell * .65 + rip * .35, detail);
  vec3 c = mix(vec3(.04, .17, .27), vec3(.07, .30, .42), big);
  c = mix(c, c * 1.18 + vec3(.0, .03, .03), waves - .2);
  float glint = pow(max(0., fbm(w * 14. + vec2(t * .25, -t * .2)) - .62) * 2.6, 3.) * detail;
  return c + vec3(.85, .9, .9) * glint * .55;
}
void main() { float detail = clamp((uZoom - 6.) / 60., 0., 1.); o = vec4(sea(vWorld, uTime, detail), 1); }`
// an island: its land shaded by its hills, lakes that shimmer; round it shallow turquoise water and surf. Its coast is
// where the signed distance to it (land +, sea -, in tiles) crosses nothing, so it curves smoothly between the tiles
const ISLAND = `#version 300 es
precision highp float; in vec2 vUv; in vec2 vWorld; uniform sampler2D uCol, uInfo; uniform float uTime, uZoom; uniform int uMode; out vec4 o; ${NOISE}
void main() {
  vec4 info = texture(uInfo, vUv); float t = uTime;
  float sd = (info.r - .502) * 255. / 16.;                                         // tiles inside (+) or out at sea (-)
  float close = clamp(uZoom / 300., 0., 1.), px = 100. / max(uZoom, 1.);          // tiles a screen pixel covers
  float edge = (fbm(vWorld * 180.) - .5) * 1.1 * close;                           // a coast a little ragged, close up
  float land = smoothstep(-.5 - px, .5 + px, sd + edge), dist = info.b;
  // the water round it: shallow and light near the shore, fading into the ocean; surf rolling in
  float shallow = 1. - smoothstep(0., .3, dist), near = 1. - smoothstep(0., .14, dist);
  float wv = fbm(vWorld * 3. + vec2(t * .05, t * .03)) * .65 + fbm(vWorld * 9. - vec2(t * .09, t * .06)) * .35;
  vec3 sh = mix(vec3(.07, .32, .43), vec3(.30, .72, .70), near * near) * (.92 + .16 * wv);
  float roll = .5 + .5 * sin(t * 1.4 - dist * 120. + fbm(vWorld * 18.) * 7.);
  float foam = (1. - smoothstep(0., .06, dist)) * smoothstep(.55, 1., roll) * .7 + (1. - smoothstep(0., .02, dist)) * .5;
  foam *= clamp(uZoom / 50., 0., 1.);
  vec4 water = vec4(mix(sh, vec3(.96, .98, .97), foam), clamp(shallow * shallow * .8 + foam * .5, 0., 1.));
  // the land: its colour (softened), lit from the north-west by its hills, a little grain close up
  vec2 st = vec2(1.5 / ${SIDE}.);
  float hl = texture(uInfo, vUv - vec2(st.x, 0)).g, hr = texture(uInfo, vUv + vec2(st.x, 0)).g, hu = texture(uInfo, vUv - vec2(0, st.y)).g, hd = texture(uInfo, vUv + vec2(0, st.y)).g;
  float lit = clamp(1. + (hl - hr) * 1.8 + (hu - hd) * 1.8, .78, 1.22);
  vec3 c = texture(uCol, vUv).rgb * lit;
  c *= .94 + .12 * mix(.5, fbm(vWorld * 90.), close);
  float lake = smoothstep(.35, .65, info.a);
  c = mix(c, mix(vec3(.17, .40, .48), vec3(.30, .60, .66), wv), lake);             // a lake
  if (uMode == 0) { o = vec4(water.rgb, water.a * (1. - land)); if (o.a <= .002) discard; }
  else { o = vec4(c, land); if (land <= .002) discard; }
}`
// the clouds of a sunny day, seen from high above: fields of fair-weather cloud where a slow, large cover lets them be,
// shaped by warped noise (so they bunch and stretch like real ones), soft at the edges and wispy at their fringes; thin
// and see-through, drifting slowly with faint shadows on the sea, and thinning out close up so the island stays clear
const CLOUDS = `#version 300 es
precision highp float; in vec2 vWorld; uniform float uTime, uZoom; out vec4 o; ${NOISE}
float thick(vec2 w, float t) {
  vec2 drift = vec2(t * .008, t * .003);
  float cover = smoothstep(.38, .72, fbm(w * .22 + 7.3 + drift * .3));                  // where there are clouds at all
  vec2 q = vec2(fbm(w * 1.1 + drift), fbm(w * 1.1 + vec2(5.2, 1.3) + drift));
  float n = fbm(w * 1.6 + q * 1.7 + drift * 1.4);                                     // the clouds' shapes, warped
  float wisp = fbm(w * 7. - drift * 2.);                                              // fine wisps at their fringes
  return smoothstep(.5, .86, n * .85 + wisp * .22) * cover;
}
void main() {
  float fade = 1. - smoothstep(220., 640., uZoom); if (fade <= 0.) discard;
  vec2 w = vWorld / 1.8;
  float d = thick(w, uTime), s = thick(w - vec2(.05, .04), uTime);
  float lit = thick(w + vec2(.018, .026), uTime);                                     // lit from above: thinner tops brighter
  vec3 cloud = mix(vec3(.84, .87, .90), vec3(1.), clamp(1. - (d - lit) * 3.5, 0., 1.));
  float ca = d * .48 * fade, sa = s * .09 * fade * (1. - d);
  o = vec4((cloud * ca + vec3(.02, .05, .08) * sa) / max(ca + sa, 1e-4), ca + sa);
}`

/** The exact distance (tiles) from every cell to the nearest cell of a set (Felzenszwalb's two passes). */
function distanceTo(set: Uint8Array, w: number, h: number): Float32Array {
  const INF = 1e9, g = new Float32Array(w * h), out = new Float32Array(w * h), n = Math.max(w, h)
  const f = new Float32Array(n), d = new Float32Array(n), v = new Int32Array(n), z = new Float32Array(n + 1)
  const pass = (len: number) => {   // the squared distance along one line, from f into d
    let k = 0; v[0] = 0; z[0] = -INF; z[1] = INF
    for (let q = 1; q < len; q++) {
      let s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k])
      while (s <= z[k]) { k--; s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]) }
      k++; v[k] = q; z[k] = s; z[k + 1] = INF
    }
    k = 0; for (let q = 0; q < len; q++) { while (z[k + 1] < q) k++; d[q] = (q - v[k]) * (q - v[k]) + f[v[k]] }
  }
  for (let x = 0; x < w; x++) { for (let y = 0; y < h; y++) f[y] = set[y * w + x] ? 0 : INF; pass(h); for (let y = 0; y < h; y++) g[y * w + x] = d[y] }
  for (let y = 0; y < h; y++) { for (let x = 0; x < w; x++) f[x] = g[y * w + x]; pass(w); for (let x = 0; x < w; x++) out[y * w + x] = Math.sqrt(d[x]) }
  return out
}

/** Softens a picture of numbers (3 × 3, the given passes), where keep says which cells take part. */
function soften(a: Float32Array, w: number, h: number, passes: number, keep?: Uint8Array) {
  const b = new Float32Array(a.length)
  for (let p = 0; p < passes; p++) {
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { let s = 0, n = 0
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) { const X = x + dx, Y = y + dy; if (X < 0 || Y < 0 || X >= w || Y >= h) continue; const j = Y * w + X; if (keep && !keep[j]) continue; s += a[j]; n++ }
      b[y * w + x] = n ? s / n : a[y * w + x] }
    a.set(b)
  }
}

/** An island's land as two small textures, reaching PAD tiles past its square: its colours (softened), and what the
 *  shader needs: the signed distance to its coast, its hills' height (softened), how far the sea is from the coast, its
 *  lakes. */
function islandTextures(gl: WebGL2RenderingContext, tiles: Uint8Array): WebGLTexture[] {
  const N = SIDE * SIDE, land = new Uint8Array(N), sea = new Uint8Array(N).fill(1), lake = new Float32Array(N), height = new Float32Array(N)
  const rgb = [new Float32Array(N).fill(GROUND[3][0]), new Float32Array(N).fill(GROUND[3][1]), new Float32Array(N).fill(GROUND[3][2])]
  for (let ty = 0; ty < TILES; ty++) for (let tx = 0; tx < TILES; tx++) {
    const b = tiles[ty * TILES + tx], g = b & 7, i = (ty + PAD) * SIDE + tx + PAD; if (!g) continue
    sea[i] = 0; land[i] = 1
    const c = GROUND[g] ?? GROUND[3]; rgb[0][i] = c[0]; rgb[1][i] = c[1]; rgb[2][i] = c[2]
    height[i] = g === 4 ? 0.1 + Math.min(5, (b >> 3) & 7) * 0.035 : 0.08
    if (g === 1) lake[i] = 1
  }
  const toLand = distanceTo(land, SIDE, SIDE), toSea = distanceTo(sea, SIDE, SIDE)
  for (const ch of rgb) soften(ch, SIDE, SIDE, 2, land)
  soften(height, SIDE, SIDE, 3); soften(lake, SIDE, SIDE, 1)
  const col = new Uint8Array(N * 4), info = new Uint8Array(N * 4)
  for (let i = 0; i < N; i++) {
    col[i * 4] = rgb[0][i]; col[i * 4 + 1] = rgb[1][i]; col[i * 4 + 2] = rgb[2][i]; col[i * 4 + 3] = 255
    const sd = land[i] ? toSea[i] - 0.5 : 0.5 - toLand[i]                                   // + inside, - at sea (tiles)
    info[i * 4] = Math.max(0, Math.min(255, Math.round(128 + sd * 16)))
    info[i * 4 + 1] = Math.round(Math.min(1, height[i]) * 255)
    info[i * 4 + 2] = land[i] ? 0 : Math.min(255, Math.round(((toLand[i] - 0.5) / SEA_REACH) * 255))
    info[i * 4 + 3] = Math.round(lake[i] * 255)
  }
  return [col, info].map((data) => {
    const t = gl.createTexture()!; gl.bindTexture(gl.TEXTURE_2D, t)
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, SIDE, SIDE, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    return t
  })
}

function program(gl: WebGL2RenderingContext, frag: string) {
  const make = (type: number, src: string) => { const sh = gl.createShader(type)!; gl.shaderSource(sh, src); gl.compileShader(sh); if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(sh) ?? 'shader'); return sh }
  const p = gl.createProgram()!; gl.attachShader(p, make(gl.VERTEX_SHADER, VERT)); gl.attachShader(p, make(gl.FRAGMENT_SHADER, frag)); gl.bindAttribLocation(p, 0, 'aPos'); gl.linkProgram(p)
  if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(p) ?? 'link')
  const u = (n: string) => gl.getUniformLocation(p, n)
  return { p, rect: u('uRect'), cam: u('uCam'), zoom: u('uZoom'), res: u('uRes'), time: u('uTime'), col: u('uCol'), info: u('uInfo'), mode: u('uMode') }
}

/** The world map page (?world): the world from above with every island, to pan, zoom and open. */
export function WorldMap({ account, onLeave, onOpen }: { account: string | null; onLeave: () => void; onOpen: (mapId: string) => void }) {
  const box = useRef<HTMLDivElement>(null), canvas = useRef<HTMLCanvasElement>(null), tagLayer = useRef<HTMLDivElement>(null)
  const isles = useRef<Isle[]>([])
  // the view: the world point (in islands) in the middle of the screen, and pixels per island
  const cam = useRef({ x: 0.5, y: 0.5, z: 180 })
  const [count, setCount] = useState<number | null>(null)
  const [unplaced, setUnplaced] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const [picked, setPicked] = useState<Isle | null>(null)
  const [here, setHere] = useState({ x: 0, y: 0 })
  const pick = useRef<(q: Isle | null) => void>(() => undefined); pick.current = setPicked

  // every map at its place; one from before places were kept goes where the spiral would have put it, in map order
  useEffect(() => {
    let live = true
    fetchAllMaps().then((found) => {
      if (!live) return
      // dev only, ?demo=40: the first island again at the next 40 places, to see a busy world
      const demo = import.meta.env.DEV ? Number(new URLSearchParams(location.search).get('demo')) || 0 : 0
      const maps = demo && found.length ? [...found, ...Array.from({ length: demo }, (_, k) => ({ ...found[0], name: `demo ${k + 1}`, owner: 'demo', at: null }))] : found
      const taken = new Set(maps.filter((m) => m.at).map((m) => `${m.at!.x},${m.at!.y}`)), list: Isle[] = []
      let n = 0, loose = 0
      const put = (m: PlayerMap, x: number, y: number, placed: boolean) => { const d = drift(x, y); list.push({ map: m, x, y, ox: x + d.dx, oy: y + d.dy, placed, tex: null, asked: false, tag: null }) }
      for (const m of maps) {
        if (m.at) { put(m, m.at.x, m.at.y, true); continue }
        let p = spiralPlace(n); while (taken.has(`${p.x},${p.y}`) || openSea(p.x, p.y)) p = spiralPlace(++n)
        taken.add(`${p.x},${p.y}`); n++; loose++; put(m, p.x, p.y, false)
      }
      isles.current = list; setCount(list.length); setUnplaced(loose)
      const mine = list.find((q) => account && q.map.owner === account)   // start over the player's first island
      if (mine) cam.current = { ...cam.current, x: mine.ox + 0.5, y: mine.oy + 0.5 }
    }, (e) => setError(e instanceof Error ? e.message : String(e)))
    return () => { live = false }
  }, [account])

  // the drawing: the ocean, the islands in view, the clouds; and the islands' seals over it
  useEffect(() => {
    const cv = canvas.current!, el = box.current!, layer = tagLayer.current!
    const gl = cv.getContext('webgl2', { antialias: true, premultipliedAlpha: false })
    if (!gl) { setError('this browser does not offer WebGL2'); return }
    let ocean: ReturnType<typeof program>, island: ReturnType<typeof program>, clouds: ReturnType<typeof program>
    try { ocean = program(gl, OCEAN); island = program(gl, ISLAND); clouds = program(gl, CLOUDS) } catch (e) { setError(String(e)); return }
    const quad = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, quad); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([0, 0, 1, 0, 0, 1, 1, 1]), gl.STATIC_DRAW)
    gl.enableVertexAttribArray(0); gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
    gl.enable(gl.BLEND); gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches, t0 = performance.now()
    let raf = 0, lastHere = ''
    const frame = () => {
      raf = requestAnimationFrame(frame)
      if (document.hidden) return
      const dpr = Math.min(2, window.devicePixelRatio || 1), W = el.clientWidth, H = el.clientHeight
      if (cv.width !== Math.round(W * dpr) || cv.height !== Math.round(H * dpr)) { cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr) }
      gl.viewport(0, 0, cv.width, cv.height)
      const { x: cx, y: cy, z } = cam.current, t = still ? 0 : (performance.now() - t0) / 1000
      const hw = W / 2 / z, hh = H / 2 / z
      const use = (pr: typeof ocean, rect: number[]) => { gl.useProgram(pr.p); gl.uniform4f(pr.rect, rect[0], rect[1], rect[2], rect[3]); gl.uniform2f(pr.cam, cx, cy); gl.uniform1f(pr.zoom, z); gl.uniform2f(pr.res, W, H); gl.uniform1f(pr.time, t) }
      const screen = [cx - hw, cy - hh, hw * 2, hh * 2]
      use(ocean, screen); gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
      // the islands in view (read the ones not read yet, a few at a time)
      let reading = isles.current.filter((q) => q.asked && !q.tex).length
      const shown = isles.current.filter((q) => q.ox + 1 + REACH > cx - hw && q.ox - REACH < cx + hw && q.oy + 1 + REACH > cy - hh && q.oy - REACH < cy + hh)
      for (const mode of [0, 1]) for (const q of shown) {
        if (!q.tex) continue
        use(island, [q.ox - REACH, q.oy - REACH, 1 + 2 * REACH, 1 + 2 * REACH]); gl.uniform1i(island.col, 0); gl.uniform1i(island.info, 1); gl.uniform1i(island.mode, mode)
        gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, q.tex[0]); gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D, q.tex[1])
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
      }
      for (const q of isles.current) {
        const inView = q.ox + 1 > cx - hw && q.ox < cx + hw && q.oy + 1 > cy - hh && q.oy < cy + hh
        if (inView && !q.tex && !q.asked && reading < 4) { q.asked = true; reading++; fetchMapTiles(q.map.id).then((tl) => { q.tex = islandTextures(gl, tl) }, () => { q.asked = false }) }
        // its seal: shown while islands are big enough to tell apart, the whole tag close up (or pointed at)
        const showTag = SHOW_SEALS && inView && z >= 22
        if (showTag && !q.tag) {
          const tag = document.createElement('div'); tag.className = 'isle-seal' + (account && q.map.owner === account ? ' mine' : '')
          tag.innerHTML = '<i></i><b></b><small></small>'
          tag.querySelector('i')!.textContent = q.map.id; tag.querySelector('b')!.textContent = q.map.name || `map no. ${q.map.id}`
          tag.querySelector('small')!.textContent = `${q.map.owner} · at ${q.x}, ${q.y}`
          tag.querySelector('i')!.addEventListener('click', (e) => { e.stopPropagation(); pick.current(q) })
          layer.append(tag); q.tag = tag
        }
        if (!showTag && q.tag) { q.tag.remove(); q.tag = null }
        if (q.tag) q.tag.style.transform = `translate(${W / 2 + (q.ox + 0.5 - cx) * z}px, ${H / 2 + (q.oy + 0.5 - cy) * z}px)`
      }
      layer.classList.toggle('near', z >= 420)
      use(clouds, screen); gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
      const h = `${Math.floor(cx)},${Math.floor(cy)}`; if (h !== lastHere) { lastHere = h; setHere({ x: Math.floor(cx), y: Math.floor(cy) }) }
    }
    raf = requestAnimationFrame(frame)
    return () => { cancelAnimationFrame(raf); for (const q of isles.current) { q.tag?.remove(); q.tag = null; q.tex = null; q.asked = false } }
  }, [account])

  // pan with a drag, zoom with the wheel or two fingers; a click (no drag) picks the island under it
  useEffect(() => {
    const el = box.current; if (!el) return
    const ptrs = new Map<number, [number, number]>(); let moved = 0, pinch = 0
    const zoomAt = (f: number, px: number, py: number) => {
      const c = cam.current, r = el.getBoundingClientRect(), W = r.width, H = r.height
      const wx = c.x + (px - r.left - W / 2) / c.z, wy = c.y + (py - r.top - H / 2) / c.z, z = Math.max(4, Math.min(1600, c.z * f))
      cam.current = { x: wx - (px - r.left - W / 2) / z, y: wy - (py - r.top - H / 2) / z, z }
    }
    const down = (e: PointerEvent) => { if ((e.target as Element).closest('.isle-seal i, .world-card, .world-mine, .world-zoom')) return; el.setPointerCapture(e.pointerId); ptrs.set(e.pointerId, [e.clientX, e.clientY]); moved = 0; if (ptrs.size === 2) { const [a, b] = [...ptrs.values()]; pinch = Math.hypot(a[0] - b[0], a[1] - b[1]) } }
    const move = (e: PointerEvent) => {
      const p = ptrs.get(e.pointerId); if (!p) return
      if (ptrs.size === 1) { const dx = e.clientX - p[0], dy = e.clientY - p[1]; moved += Math.abs(dx) + Math.abs(dy); cam.current = { ...cam.current, x: cam.current.x - dx / cam.current.z, y: cam.current.y - dy / cam.current.z } }
      ptrs.set(e.pointerId, [e.clientX, e.clientY])
      if (ptrs.size === 2) { const [a, b] = [...ptrs.values()], d = Math.hypot(a[0] - b[0], a[1] - b[1]); if (pinch) zoomAt(d / pinch, (a[0] + b[0]) / 2, (a[1] + b[1]) / 2); pinch = d; moved = 99 }
    }
    const up = (e: PointerEvent) => {
      if (!ptrs.has(e.pointerId)) return
      if (ptrs.size === 1 && moved < 6) {   // a click: the island under it (its square, as it lies)
        const c = cam.current, r = el.getBoundingClientRect(), wx = c.x + (e.clientX - r.left - r.width / 2) / c.z, wy = c.y + (e.clientY - r.top - r.height / 2) / c.z
        setPicked(isles.current.find((q) => wx >= q.ox && wx < q.ox + 1 && wy >= q.oy && wy < q.oy + 1) ?? null)
      }
      ptrs.delete(e.pointerId); if (ptrs.size < 2) pinch = 0
    }
    const wheel = (e: WheelEvent) => { e.preventDefault(); zoomAt(Math.exp(-e.deltaY * 0.0015), e.clientX, e.clientY) }
    el.addEventListener('pointerdown', down); el.addEventListener('pointermove', move); el.addEventListener('pointerup', up); el.addEventListener('pointercancel', up)
    el.addEventListener('wheel', wheel, { passive: false })
    return () => { el.removeEventListener('pointerdown', down); el.removeEventListener('pointermove', move); el.removeEventListener('pointerup', up); el.removeEventListener('pointercancel', up); el.removeEventListener('wheel', wheel) }
  }, [])

  const zoomBy = (f: number) => { const c = cam.current; cam.current = { ...c, z: Math.max(4, Math.min(1600, c.z * f)) } }
  const goTo = (x: number, y: number, z = cam.current.z) => { cam.current = { x: x + 0.5, y: y + 0.5, z } }

  return (
    <div className="world">
      <Header home="contents-1" right={<button type="button" className="admin-back hand" onClick={onLeave}>← back to the journal</button>} />
      <div className="world-view" ref={box} role="application" aria-label="The world map: drag to look around, scroll or pinch to zoom, click an island">
        <canvas ref={canvas} className="world-canvas" />
        <div className="isle-seals" ref={tagLayer} />
        <div className="world-tag">
          <b>The world</b>
          <small>{error ? `could not draw the world: ${error}` : count === null ? 'reading the maps…' : `${count} island${count === 1 ? '' : 's'} charted · at ${here.x}, ${here.y}`}</small>
          {unplaced > 0 && <small className="world-note">{unplaced} charted before islands had places: shown where the spiral puts them</small>}
        </div>
        <div className="world-zoom" role="group" aria-label="Zoom">
          <button type="button" className="zoom-btn" aria-label="Zoom in" onClick={() => zoomBy(1.6)}>+</button>
          <button type="button" className="zoom-btn" aria-label="Zoom out" onClick={() => zoomBy(1 / 1.6)}>−</button>
          <button type="button" className="zoom-btn world-home" title="the middle of the world" aria-label="To the middle of the world" onClick={() => goTo(0, 0)}>◎</button>
        </div>
        {picked && (
          <div className="world-card" role="dialog" aria-label={picked.map.name || `map no. ${picked.map.id}`}>
            <button type="button" className="build-link world-close" onClick={() => setPicked(null)} aria-label="Close">×</button>
            <small>map no. {picked.map.id}{picked.map.owner === account ? ' · yours' : ''}</small>
            <h2>{picked.map.name || 'not yet named'}</h2>
            <p>{picked.map.owner}</p>
            <p className="world-place">at {picked.x}, {picked.y} · {picked.placed ? placeWords({ x: picked.x, y: picked.y }) : 'no place on chain yet'}</p>
            {picked.map.soil && <p className="world-place">soil: nutrients {picked.map.soil.nutrients}% · moisture {picked.map.soil.moisture}% · pH {(picked.map.soil.acidity / 10).toFixed(1)}, {acidWord(picked.map.soil.acidity)}</p>}
            <button type="button" className="build-confirm" onClick={() => onOpen(picked.map.id)}>open the island</button>
          </div>
        )}
      </div>
    </div>
  )
}

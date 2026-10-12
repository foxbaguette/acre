// The island's buildings as 3D models, for rendering their pictures (building-export.html) and the showcase
// (building-render.html). Each model stands on the ground (y = 0) round its footprint's centre, its entrance to the
// south (+z). One unit is one tile.
import * as THREE from 'three'

export const TILT = 18 * Math.PI / 180            // the game's camera: tipped this far from straight down, toward the north
export const FOOT = { farmhouse: [3, 4], lab: [4, 4], bakery: [2, 2], silo: [2, 2], kitchen: [3, 2], nest: [2, 2] }

let S = 7
const rnd = () => (S = S * 16807 % 2147483647) / 2147483647
export const reseed = (n) => { S = n * 7919 % 2147483647 || 7 }
const TAU = Math.PI * 2
const hex = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16))
export const mix = (a, b, t) => { const A = hex(a), B = hex(b); return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * Math.max(0, Math.min(1, t))).toString(16).padStart(2, '0')).join('') }
export function canvasTex(w, h, draw, rep = [1, 1]) {
  const c = document.createElement('canvas'); c.width = w; c.height = h; const g = c.getContext('2d'); draw(g, w, h)
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; t.repeat.set(...rep); return t
}
export const speck = (g, w, h, n, cols, s = [1, 3]) => { for (let k = 0; k < n; k++) { g.fillStyle = cols[Math.floor(rnd() * cols.length)]; g.fillRect(rnd() * w, rnd() * h, s[0] + rnd() * (s[1] - s[0]), s[0] + rnd() * (s[1] - s[0])) } }

// ---------- materials (each texture one unit square; roof courses run up and down the canvas, along the ridge) ----------
export const T = {
  clay: () => canvasTex(256, 256, (g, w, h) => { g.fillStyle = '#7e4a38'; g.fillRect(0, 0, w, h)
    for (let c = 0; c < 4; c++) for (let y = (c % 2) * 18; y < h + 40; y += 36) { g.fillStyle = mix('#8e5a44', rnd() < .5 ? '#5e3428' : '#a87458', rnd() * .5); g.fillRect(c * 64 + 2, y - 36, 60, 34); g.fillStyle = 'rgba(255,230,200,.18)'; g.fillRect(c * 64 + 2, y - 36, 6, 34); g.fillStyle = 'rgba(0,0,0,.35)'; g.fillRect(c * 64 + 56, y - 36, 6, 34) }
    speck(g, w, h, 900, ['rgba(40,30,20,.15)', 'rgba(90,100,60,.18)', 'rgba(230,210,180,.1)']) }),
  shingle: () => canvasTex(256, 256, (g, w, h) => { g.fillStyle = '#4e4238'; g.fillRect(0, 0, w, h)
    for (let c = 0; c < 5; c++) for (let y = -rnd() * 30; y < h; ) { const l = 22 + rnd() * 26; g.fillStyle = mix('#5e5044', rnd() < .5 ? '#2e2620' : '#8a7a64', rnd() * .5); g.fillRect(c * 51 + 1, y, 49, l - 2); g.fillStyle = 'rgba(0,0,0,.4)'; g.fillRect(c * 51 + 45, y, 5, l - 2); y += l }
    speck(g, w, h, 1200, ['rgba(20,16,12,.2)', 'rgba(110,120,80,.2)', 'rgba(200,190,160,.08)']) }),
  slate: () => canvasTex(256, 256, (g, w, h) => { g.fillStyle = '#4a5058'; g.fillRect(0, 0, w, h)
    for (let c = 0; c < 5; c++) for (let y = (c % 2) * 24; y < h + 48; y += 48) { g.fillStyle = mix('#58606a', rnd() < .5 ? '#2e343a' : '#7a828a', rnd() * .4); g.fillRect(c * 51 + 1, y - 48, 49, 46); g.fillStyle = 'rgba(0,0,0,.4)'; g.fillRect(c * 51 + 44, y - 48, 6, 46) }
    speck(g, w, h, 900, ['rgba(20,20,20,.2)', 'rgba(200,200,190,.1)']) }),
  plaster: () => canvasTex(256, 256, (g, w, h) => { g.fillStyle = '#c4b89c'; g.fillRect(0, 0, w, h); speck(g, w, h, 3000, ['rgba(120,100,70,.12)', 'rgba(255,250,230,.12)'], [1, 4])
    for (let k = 0; k < 8; k++) { g.fillStyle = 'rgba(110,90,60,.08)'; g.beginPath(); g.ellipse(rnd() * w, rnd() * h, 20 + rnd() * 40, 10 + rnd() * 30, 0, 0, TAU); g.fill() } }),
  stone: () => canvasTex(256, 256, (g, w, h) => { g.fillStyle = '#5a554c'; g.fillRect(0, 0, w, h)
    for (let y = 0, r = 0; y < h; y += 32, r++) for (let x = -(r % 2) * 24; x < w; ) { const sw = 34 + rnd() * 26; g.fillStyle = mix('#8a8274', rnd() < .5 ? '#5e584e' : '#aea490', rnd() * .6); g.beginPath(); g.roundRect(x + 2, y + 2, sw - 4, 28, 6); g.fill(); x += sw }
    speck(g, w, h, 1500, ['rgba(0,0,0,.12)', 'rgba(255,250,230,.08)']) }),
  planks: () => canvasTex(256, 256, (g, w, h) => { for (let x = 0; x < w; x += 32) { g.fillStyle = mix('#6e5440', rnd() < .5 ? '#4a3828' : '#8e7054', rnd() * .5); g.fillRect(x, 0, 31, h); g.fillStyle = 'rgba(0,0,0,.4)'; g.fillRect(x + 30, 0, 2, h) }
    for (let k = 0; k < 200; k++) { g.fillStyle = 'rgba(30,20,10,.15)'; g.fillRect(rnd() * w, rnd() * h, 1, 10 + rnd() * 30) } }),
  metal: () => canvasTex(256, 256, (g, w, h) => { g.fillStyle = '#8e9290'; g.fillRect(0, 0, w, h)
    for (let x = 0; x < w; x += 32) { g.fillStyle = mix('#9a9e9a', '#6e7270', rnd() * .4); g.fillRect(x, 0, 30, h); g.fillStyle = 'rgba(255,255,255,.25)'; g.fillRect(x, 0, 2, h); g.fillStyle = 'rgba(0,0,0,.3)'; g.fillRect(x + 29, 0, 2, h) }
    for (let y = 30; y < h; y += 64) for (let x = 6; x < w; x += 16) { g.fillStyle = 'rgba(40,40,40,.5)'; g.fillRect(x, y, 3, 3) }
    for (let k = 0; k < 14; k++) { g.fillStyle = 'rgba(130,80,40,.18)'; g.fillRect(rnd() * w, rnd() * h, 4 + rnd() * 6, 30 + rnd() * 80) } }),
  straw: () => canvasTex(256, 256, (g, w, h) => { g.fillStyle = '#a88e4e'; g.fillRect(0, 0, w, h); for (let k = 0; k < 2500; k++) { const x = rnd() * w, y = rnd() * h, a = rnd() * TAU; g.strokeStyle = mix('#6e5a2a', '#e2cc86', rnd()); g.lineWidth = 1.2; g.beginPath(); g.moveTo(x, y); g.lineTo(x + Math.cos(a) * 14, y + Math.sin(a) * 14); g.stroke() } }),
  flag: () => canvasTex(256, 256, (g, w, h) => { g.fillStyle = '#6a645a'; g.fillRect(0, 0, w, h); for (let y = 0; y < h; y += 52) for (let x = -rnd() * 30; x < w; ) { const sw = 50 + rnd() * 40; g.fillStyle = mix('#9a9284', '#bab2a0', rnd()); g.beginPath(); g.roundRect(x + 3, y + 3, sw - 6, 46, 8); g.fill(); x += sw } speck(g, w, h, 1500, ['rgba(0,0,0,.1)', 'rgba(80,100,50,.2)']) }),
  clayDome: () => canvasTex(256, 256, (g, w, h) => { g.fillStyle = '#a8785a'; g.fillRect(0, 0, w, h); speck(g, w, h, 3000, ['rgba(80,50,30,.18)', 'rgba(240,210,170,.15)', 'rgba(30,20,10,.12)'], [2, 6]) }),
  logs: () => canvasTex(256, 256, (g, w, h) => { for (let y = 0; y < h; y += 32) { const gr = g.createLinearGradient(0, y, 0, y + 32); gr.addColorStop(0, '#9a7448'); gr.addColorStop(.5, '#7a5634'); gr.addColorStop(1, '#3e2a1a'); g.fillStyle = gr; g.fillRect(0, y, w, 32) }
    for (let k = 0; k < 300; k++) { g.fillStyle = 'rgba(40,26,14,.25)'; g.fillRect(rnd() * w, rnd() * h, 10 + rnd() * 30, 1) } }),
  thatch: () => canvasTex(256, 256, (g, w, h) => { g.fillStyle = '#9a8048'; g.fillRect(0, 0, w, h)
    for (let c = 0; c < 4; c++) { for (let k = 0; k < 700; k++) { const x = c * 64 + rnd() * 64, y = rnd() * h; g.strokeStyle = mix('#5e4a24', '#d8c27e', rnd()); g.lineWidth = 1.3; g.beginPath(); g.moveTo(x, y); g.lineTo(x + 12 + rnd() * 10, y + (rnd() - .5) * 3); g.stroke() }
      g.fillStyle = 'rgba(30,20,8,.35)'; g.fillRect(c * 64 + 58, 0, 6, h) } }),
  boards: () => canvasTex(256, 256, (g, w, h) => { g.fillStyle = '#5e4a34'; g.fillRect(0, 0, w, h)   // long rough boards, running down the slope, with battens over the joins
    for (let y = 0; y < h; y += 42) { const gr = g.createLinearGradient(0, y, 0, y + 42); gr.addColorStop(0, mix('#8a6e4c', '#6e5438', rnd())); gr.addColorStop(1, '#4e3a28'); g.fillStyle = gr; g.fillRect(0, y, w, 40)
      for (let k = 0; k < 18; k++) { g.fillStyle = 'rgba(30,20,10,.2)'; g.fillRect(rnd() * w, y + rnd() * 40, 20 + rnd() * 60, 1) } g.fillStyle = 'rgba(0,0,0,.45)'; g.fillRect(0, y + 38, w, 4) }
    speck(g, w, h, 600, ['rgba(90,110,60,.25)', 'rgba(20,14,8,.2)'], [2, 6]) }),
  hedge: () => canvasTex(128, 128, (g, w, h) => { g.fillStyle = '#3e5a2a'; g.fillRect(0, 0, w, h); speck(g, w, h, 1500, ['rgba(20,36,14,.4)', 'rgba(110,140,70,.35)'], [2, 5]) }),
  bark: () => canvasTex(128, 128, (g, w, h) => { g.fillStyle = '#4e3e2e'; g.fillRect(0, 0, w, h); for (let k = 0; k < 300; k++) { g.fillStyle = rnd() < .5 ? 'rgba(20,14,8,.3)' : 'rgba(140,110,80,.2)'; g.fillRect(rnd() * w, rnd() * h, 2, 8 + rnd() * 16) } }),
}
const rep = (t, x, y) => { t.repeat.set(x, y); return t }
export const M = (map, o = {}) => new THREE.MeshStandardMaterial({ map, roughness: .92, metalness: 0, ...o })
export const flat = (color, o = {}) => new THREE.MeshStandardMaterial({ color, roughness: .9, ...o })

// ---------- parts ----------
export const add = (parent, mesh, x = 0, y = 0, z = 0) => { mesh.position.set(x, y, z); mesh.castShadow = true; mesh.receiveShadow = true; parent.add(mesh); return mesh }
export const box = (w, h, d, mat) => new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat)
function gableRoof(parent, w, d, y, rise, mat, ov = .22) {
  const half = w / 2 + ov, L = Math.hypot(half, rise), a = Math.atan2(rise, half), dd = d + ov * 2
  for (const s of [-1, 1]) { const grp = new THREE.Group(); grp.position.set(s * half / 2, y + rise / 2 - .06, 0); grp.rotation.z = -s * a
    const m = mat(); rep(m.map, L, dd); add(grp, new THREE.Mesh(new THREE.BoxGeometry(L, .08, dd), m)); parent.add(grp) }
  add(parent, new THREE.Mesh(new THREE.CylinderGeometry(.07, .07, dd, 8), flat('#3e3428')), 0, y + rise + .01, 0).rotation.x = Math.PI / 2
}
function gableEnds(parent, w, d, y, rise, mat) {
  const sh = new THREE.Shape(); sh.moveTo(-w / 2, 0); sh.lineTo(w / 2, 0); sh.lineTo(0, rise * .96); sh.closePath()
  for (const z of [-d / 2, d / 2]) { const m = add(parent, new THREE.Mesh(new THREE.ShapeGeometry(sh), mat), 0, y, z); m.material.side = THREE.DoubleSide }
}
// a window or door on a face looking along +z (local); a window's pane glows after dark
function opening(ctx, parent, x, y, z, w, h, door = false) {
  add(parent, box(w + .08, h + .08, .05, flat('#4a3a2a')), x, y, z + .02)
  const pane = add(parent, box(w, h, .06, new THREE.MeshStandardMaterial({ color: door ? '#5a3e26' : '#232c34', roughness: door ? .9 : .3 })), x, y, z + .035)
  if (!door) ctx.glow.push(pane)
}
const chimneyAt = (ctx, parent, x, z, base, top) => { add(parent, box(.42, top - base, .42, M(rep(T.stone(), .5, 1)))).position.set(x, (base + top) / 2, z); const mark = new THREE.Object3D(); mark.position.set(x, top + .05, z); parent.add(mark); ctx.smoke.push(mark); add(parent, box(.5, .08, .5, flat('#5a544c')), x, top, z) }

// ---------- the buildings ----------
// ---------- the farmhouse growing inside its plot (3 x 4 tiles: x -1.5..1.5, z -2..2; its front wall always at z 1.7) ----------
// A house: stone plinth, plastered walls of one or more floors (beams between them), a clay-tiled gable roof with its ridge
// north to south, windows on every floor, the door on the ground floor, chimneys, dormers.
const FLOOR0 = 1.05, FLOOR = .9
function houseBody(ctx, h, o) {
  const g2 = new THREE.Group(); g2.position.set(o.x ?? 0, 0, o.z); h.add(g2)
  const { w, d } = o, F = o.floors ?? 1, wh = FLOOR0 + (F - 1) * FLOOR, rise = o.rise ?? w * .38
  add(g2, box(w + .1, .3, d + .1, M(rep(T.stone(), w, .3))), 0, .15, 0)
  const wallT = T[o.wall ?? 'plaster'], roofT = T[o.roof ?? 'clay']
  add(g2, box(w, wh - .3, d, M(rep(wallT(), w, wh))), 0, .3 + (wh - .3) / 2, 0)
  for (let f = 1; f < F; f++) add(g2, box(w + .04, .06, d + .04, flat('#5a4634')), 0, FLOOR0 + (f - 1) * FLOOR, 0)
  if (o.hip) { const hr = add(g2, new THREE.Mesh(new THREE.ConeGeometry(Math.SQRT1_2 * 1.06, rise, 4, 1), M(rep(roofT(), 3, 2))), 0, wh + rise / 2, 0); hr.rotation.y = Math.PI / 4; hr.scale.set(w + .28, 1, d + .28) }
  else if (o.ridgeX) { const rg = new THREE.Group(); rg.rotation.y = Math.PI / 2; g2.add(rg); gableEnds(rg, d, w, wh, o.rise ?? d * .38, M(rep(wallT(), d, 1))); gableRoof(rg, d, w, wh, o.rise ?? d * .38, () => M(roofT()), .14) }
  else { gableEnds(g2, w, d, wh, rise, M(rep(wallT(), w, 1))); gableRoof(g2, w, d, wh, rise, () => M(roofT()), o.roof === 'thatch' ? .24 : .14) }
  const yAt = (f) => (f === 0 ? .78 : FLOOR0 + (f - 1) * FLOOR + .45)
  const n = Math.max(1, Math.round(w / .72)), xs = [...Array(n)].map((_, k) => -w / 2 + (k + .5) * w / n)
  if (o.front !== false) for (let f = 0; f < F; f++) for (const x of xs) { if (o.door && f === 0 && Math.abs(x) < .3) continue; opening(ctx, g2, x, yAt(f), d / 2, .3, .32) }
  if (o.door) opening(ctx, g2, 0, .5, d / 2, .42, .82, true)
  for (const sd of [-1, 1]) { const side = new THREE.Group(); side.position.set(sd * w / 2, 0, 0); side.rotation.y = sd * Math.PI / 2; g2.add(side)
    const m = Math.max(1, Math.round(d / 1.1)); for (let f = 0; f < F; f++) for (let k = 0; k < m; k++) opening(ctx, side, -d / 2 + (k + .5) * d / m, yAt(f), 0, .28, .3) }
  for (const [cx, cz] of o.chimneys ?? []) chimneyAt(ctx, g2, cx * w / 2, cz * d / 2, wh, wh + rise + .3)
  if (o.porch) { for (const x of [-.55, .55]) add(g2, box(.07, .85, .07, flat('#5a4634')), x, .42, d / 2 + .32); const pr = add(g2, box(1.35, .06, .5, M(rep(roofT(), 1.3, .5))), 0, .9, d / 2 + .2); pr.rotation.x = .3 }
  if (o.cupola) { const cy = wh + (o.ridgeX ? (o.rise ?? d * .38) : rise); add(g2, box(.42, .42, .42, M(rep(T.planks(), .4, .4))), 0, cy - .05, 0); add(g2, new THREE.Mesh(new THREE.ConeGeometry(.36, .4, 4), M(rep(T.slate(), .5, .5))), 0, cy + .36, 0).rotation.y = Math.PI / 4; add(g2, box(.02, .4, .02, flat('#2e2a26')), 0, cy + .7, 0); add(g2, box(.28, .03, .02, flat('#2e2a26')), .06, cy + .8, 0) }
  if (o.dormers) for (const sd of [-1, 1]) for (const z of o.dormers) { const dg = new THREE.Group(); const rr = o.ridgeX ? (o.rise ?? d * .38) : rise
    if (o.ridgeX) { dg.position.set(z * w / 2, wh + rr * .42, sd * d * .24); dg.rotation.y = sd > 0 ? 0 : Math.PI } else { dg.position.set(sd * w * .24, wh + rise * .42, z * d / 2); dg.rotation.y = sd * Math.PI / 2 } g2.add(dg)
    add(dg, box(.46, .4, .42, M(rep(wallT(), .5, .4))), 0, 0, 0); add(dg, new THREE.Mesh(new THREE.ConeGeometry(.38, .28, 4), M(rep(roofT(), .4, .4))), 0, .34, 0).rotation.y = Math.PI / 4; opening(ctx, dg, 0, 0, .21, .22, .22) }
  return wh
}
// a lean-to shed against a wall: plank walls, one sloping roof
function shed(h, x, z, w, d, ht = .8) {
  const g2 = new THREE.Group(); g2.position.set(x, 0, z); h.add(g2)
  add(g2, box(w, ht, d, M(rep(T.planks(), w, ht))), 0, ht / 2, 0)
  const rf = add(g2, box(w + .14, .06, d + .2, M(rep(T.shingle(), w, d))), 0, ht + .08, 0); rf.rotation.x = -.28
}
// a square stair tower: stone below, plaster above, windows each floor, a pyramid roof (and at the top stage a spire)
function tower(ctx, h, x, z, s, floors, spire) {
  const g2 = new THREE.Group(); g2.position.set(x, 0, z); h.add(g2)
  const ht = FLOOR0 + (floors - 1) * FLOOR
  add(g2, box(s + .08, .45, s + .08, M(rep(T.stone(), s, .45))), 0, .225, 0)
  add(g2, box(s, ht - .45, s, M(rep(T.plaster(), s, ht))), 0, .45 + (ht - .45) / 2, 0)
  for (let f = 0; f < floors; f++) for (const [px, pz, ry] of [[0, s / 2, 0], [s / 2, 0, Math.PI / 2]]) { const o = new THREE.Group(); o.position.set(px, 0, pz); o.rotation.y = ry; g2.add(o); opening(ctx, o, 0, f === 0 ? .8 : FLOOR0 + (f - 1) * FLOOR + .45, 0, .24, .3) }
  add(g2, new THREE.Mesh(new THREE.ConeGeometry(s * .78, spire ? 1.3 : .8, 4), M(rep(T.slate(), s, 1))), 0, ht + (spire ? .65 : .4), 0).rotation.y = Math.PI / 4
  if (spire) { add(g2, box(.03, .5, .03, flat('#2e2a26', { metalness: .5 })), 0, ht + 1.5, 0); add(g2, box(.3, .04, .02, flat('#2e2a26', { metalness: .5 })), .08, ht + 1.62, 0) }
}
function well(h, x, z) { add(h, new THREE.Mesh(new THREE.CylinderGeometry(.22, .24, .3, 14), M(rep(T.stone(), 1, .3))), x, .15, z); add(h, new THREE.Mesh(new THREE.CylinderGeometry(.16, .16, .02, 14), flat('#2a4a54', { roughness: .2 })), x, .3, z)
  for (const dx of [-.2, .2]) add(h, box(.04, .55, .04, flat('#4e3a28')), x + dx, .45, z); const rf = add(h, new THREE.Mesh(new THREE.ConeGeometry(.3, .25, 4), M(rep(T.shingle(), .4, .4))), x, .82, z); rf.rotation.y = Math.PI / 4 }
function beds(h, x, z, w, d, n = 3) { add(h, box(w, .06, d, flat('#4e3a26')), x, .03, z); for (let k = 0; k < n; k++) for (let j = 0; j < 6; j++) add(h, new THREE.Mesh(new THREE.SphereGeometry(.07, 6, 5), flat(mix('#4e7a30', '#8eaa4e', (k * 7 + j) % 5 / 5))), x - w / 2 + (j + .5) * w / 6, .08, z - d / 2 + (k + .5) * d / n) }
function rail(h, pts) { const post = flat('#6a5644'), rl = flat('#7e6a54'); for (let i = 1; i < pts.length; i++) { const [a, b] = [pts[i - 1], pts[i]], len = Math.hypot(b[0] - a[0], b[1] - a[1]), n = Math.max(1, Math.round(len / .5))
  for (let k = 0; k <= n; k++) add(h, box(.05, .32, .05, post), a[0] + (b[0] - a[0]) * k / n, .16, a[1] + (b[1] - a[1]) * k / n)
  const r2 = add(h, box(len, .03, .03, rl), (a[0] + b[0]) / 2, .26, (a[1] + b[1]) / 2); r2.rotation.y = -Math.atan2(b[1] - a[1], b[0] - a[0]) } }
function hedgeRow(h, x, z, w, d) { add(h, box(w, .32, d, M(rep(T.hedge(), w * 2, .6))), x, .16, z) }
function glasshouse(ctx, h, x, z, w, d) { const glass = new THREE.MeshStandardMaterial({ color: '#b8d4d0', roughness: .1, metalness: .2, transparent: true, opacity: .55 })
  add(h, box(w, .5, d, glass), x, .25, z); const rf = new THREE.Group(); rf.position.set(x, .5, z); h.add(rf)
  for (const sd of [-1, 1]) { const p = add(rf, box(w / 2 + .05, .02, d, glass), sd * w / 4, .14, 0); p.rotation.z = -sd * .55 }
  for (let k = 0; k <= 4; k++) add(h, box(.025, .82, .025, flat('#e8e4dc')), x - w / 2 + k * w / 4, .41, z + d / 2)
  for (let k = 0; k < 4; k++) add(h, new THREE.Mesh(new THREE.SphereGeometry(.09, 6, 5), flat('#5e8a3a')), x - w / 3 + k * w / 4.5, .12, z) }
function cart(h, x, z, a = 0) { const g2 = new THREE.Group(); g2.position.set(x, 0, z); g2.rotation.y = a; h.add(g2); add(g2, box(.5, .12, .32, M(rep(T.planks(), .5, .3))), 0, .28, 0); for (const sd of [-1, 1]) add(g2, new THREE.Mesh(new THREE.CylinderGeometry(.16, .16, .04, 14), flat('#4a3828')), 0, .17, sd * .19).rotation.x = Math.PI / 2; add(g2, box(.4, .03, .03, flat('#4a3828')), .42, .22, 0) }
const FZ = 1.7
const FARM_GROWTH = {
  // D: a homestead. Each stage a new kind of house, a new material: a log hut under thatch, a plank cabin under shingles with
  // a garden, a plastered cottage under clay tiles with a well, a two-floor farmhouse with a porch, a stone manor under slate
  homestead: [
    (c, h) => { houseBody(c, h, { z: FZ - .8, w: 1.4, d: 1.6, wall: 'logs', roof: 'boards', door: true, rise: .7 }); add(h, new THREE.Mesh(new THREE.CylinderGeometry(.08, .1, .5, 8), M(T.bark())), .9, .25, -.6) },
    (c, h) => houseBody(c, h, { z: FZ - 1.0, w: 1.8, d: 2.0, wall: 'planks', roof: 'shingle', door: true, chimneys: [[.4, -.3]] }),
    (c, h) => { houseBody(c, h, { z: FZ - 1.3, w: 2.2, d: 2.6, wall: 'plaster', roof: 'clay', door: true, chimneys: [[.45, -.35]] }); well(h, -1.2, 1.5) },
    (c, h) => { houseBody(c, h, { z: FZ - 1.6, w: 2.4, d: 3.2, floors: 2, wall: 'plaster', roof: 'clay', door: true, porch: true, chimneys: [[.45, -.4], [-.45, .4]] }) },
    // a stately stone farmhouse under slate: a main block across the plot, a two-floor front wing whose gable faces the path
    // and holds the door (a T from above), two tall chimneys, dormers, a bell turret on the ridge, lanterns by the door
    (c, h) => { houseBody(c, h, { z: -.55, w: 2.7, d: 2.3, floors: 2, wall: 'stone', roof: 'slate', ridgeX: true, rise: .95, front: true, chimneys: [[-.82, 0], [.82, 0]], dormers: [-.55, .55], cupola: true })
      houseBody(c, h, { z: FZ - .55, w: 1.3, d: 1.1, floors: 2, wall: 'stone', roof: 'slate', rise: .62, door: true })
      for (const x of [-.42, .42]) { add(h, box(.04, .5, .04, flat('#2e2c2a')), x, .9, FZ + .06); c.glow.push(add(h, box(.1, .13, .1, new THREE.MeshStandardMaterial({ color: '#e8c878' })), x, 1.2, FZ + .08)) } },
  ],
  // E: a farmstead round a yard. One small house; a shed beside it; the house grows and a cart stands in the yard; a barn
  // closes one side (an L); at the end a U of buildings round the yard, a gate between them
  courtyard: [
    (c, h) => houseBody(c, h, { x: -.65, z: FZ - .9, w: 1.4, d: 1.8, door: true, chimneys: [[.4, -.3]] }),
    (c, h) => { houseBody(c, h, { x: -.65, z: FZ - .9, w: 1.4, d: 1.8, door: true, chimneys: [[.4, -.3]] }); shed(h, .85, .9, .9, 1.4, .75) },
    (c, h) => { houseBody(c, h, { x: -.55, z: FZ - 1.4, w: 1.7, d: 2.8, door: true, chimneys: [[.4, -.3]] }); shed(h, .95, .9, .9, 1.4, .75); cart(h, .9, -.4, .5) },
    (c, h) => { houseBody(c, h, { x: -.55, z: FZ - 1.4, w: 1.7, d: 2.8, floors: 2, door: true, chimneys: [[.4, -.3]] }); houseBody(c, h, { x: .4, z: -1.45, w: 2.1, d: 1.0, wall: 'planks', roof: 'shingle', front: false }); cart(h, .9, .3, .5) },
    (c, h) => { houseBody(c, h, { x: -.55, z: FZ - 1.4, w: 1.7, d: 2.8, floors: 2, door: true, chimneys: [[.4, -.3]], dormers: [.1] }); houseBody(c, h, { x: .4, z: -1.45, w: 2.1, d: 1.0, wall: 'planks', roof: 'shingle', front: false }); houseBody(c, h, { x: 1.0, z: .6, w: .9, d: 2.0, wall: 'planks', roof: 'shingle', front: false }); cart(h, .55, -.4, .2) },
  ],
  // F: a garden house. The cottage gains a flower garden, then a glasshouse, then a second floor, then a stone terrace and a
  // pergola, a garden that fills the plot
  garden: [
    (c, h) => houseBody(c, h, { z: FZ - 1.0, w: 1.8, d: 2.0, door: true, chimneys: [[.4, -.3]] }),
    (c, h) => { houseBody(c, h, { z: FZ - 1.0, w: 1.8, d: 2.0, door: true, chimneys: [[.4, -.3]] }); beds(h, 0, -1.45, 2.4, .9, 3); hedgeRow(h, 0, -1.95, 2.8, .14) },
    (c, h) => { houseBody(c, h, { z: FZ - 1.0, w: 1.8, d: 2.0, door: true, chimneys: [[.4, -.3]] }); glasshouse(c, h, 0, -1.4, 2.2, .9); hedgeRow(h, 0, -1.95, 2.8, .14) },
    (c, h) => { houseBody(c, h, { z: FZ - 1.0, w: 1.8, d: 2.0, floors: 2, door: true, chimneys: [[.4, -.3]] }); glasshouse(c, h, 0, -1.4, 2.2, .9); hedgeRow(h, 0, -1.95, 2.8, .14); hedgeRow(h, -1.35, .3, .14, 2.4); hedgeRow(h, 1.35, .3, .14, 2.4) },
    (c, h) => { houseBody(c, h, { z: FZ - 1.0, w: 1.8, d: 2.0, floors: 2, door: true, chimneys: [[.4, -.3]], dormers: [0] }); glasshouse(c, h, 0, -1.4, 2.2, .9); hedgeRow(h, 0, -1.95, 2.8, .14); hedgeRow(h, -1.35, .3, .14, 2.4); hedgeRow(h, 1.35, .3, .14, 2.4)
      for (const x of [-1.15, 1.15]) for (const z of [-.6, .4]) add(h, new THREE.Mesh(new THREE.SphereGeometry(.18, 10, 8), flat('#9a5a7a')), x, .3, z) },
  ],
  // A: up. It fills its plot by the second stage, then gains floors: two, dormers, three
  up: [
    (c, h) => houseBody(c, h, { z: FZ - 1.2, w: 1.8, d: 2.4, door: true, chimneys: [[.4, -.3]] }),
    (c, h) => houseBody(c, h, { z: FZ - 1.65, w: 2.5, d: 3.3, door: true, chimneys: [[.45, -.4]] }),
    (c, h) => houseBody(c, h, { z: FZ - 1.65, w: 2.5, d: 3.3, floors: 2, door: true, chimneys: [[.45, -.4]] }),
    (c, h) => houseBody(c, h, { z: FZ - 1.65, w: 2.5, d: 3.3, floors: 2, door: true, chimneys: [[.45, -.4], [-.45, .35]], dormers: [-.45, .4] }),
    (c, h) => houseBody(c, h, { z: FZ - 1.65, w: 2.5, d: 3.3, floors: 3, door: true, chimneys: [[.45, -.4], [-.45, .35]], dormers: [-.45, .4] }),
  ],
  // B: out, then up. A cottage that gains a shed, a rear wing (an L inside the plot), then a second floor on both parts
  spread: [
    (c, h) => houseBody(c, h, { z: FZ - 1.2, w: 1.8, d: 2.4, door: true, chimneys: [[.4, -.3]] }),
    (c, h) => { houseBody(c, h, { z: FZ - 1.2, w: 1.8, d: 2.4, door: true, chimneys: [[.4, -.3]] }); shed(h, .2, -1.3, 1.3, .9) },
    (c, h) => { houseBody(c, h, { z: FZ - 1.1, w: 2.6, d: 2.2, door: true, chimneys: [[.45, -.2]] }); houseBody(c, h, { x: -.55, z: -1.15, w: 1.5, d: 1.5, front: false }) },
    (c, h) => { houseBody(c, h, { z: FZ - 1.1, w: 2.6, d: 2.2, floors: 2, door: true, chimneys: [[.45, -.2]] }); houseBody(c, h, { x: -.55, z: -1.15, w: 1.5, d: 1.5, front: false }); shed(h, .85, -1.45, .9, .8, .7) },
    (c, h) => { houseBody(c, h, { z: FZ - 1.1, w: 2.6, d: 2.2, floors: 2, door: true, chimneys: [[.45, -.2], [-.5, .1]], dormers: [0] }); houseBody(c, h, { x: -.55, z: -1.15, w: 1.5, d: 1.5, floors: 2, front: false }); shed(h, .85, -1.45, .9, .8, .7) },
  ],
  // C: a tower. The house gains a floor, then a stair tower in its back corner that rises with each stage, a spire at the top
  tower: [
    (c, h) => houseBody(c, h, { z: FZ - 1.2, w: 1.8, d: 2.4, door: true, chimneys: [[.4, -.3]] }),
    (c, h) => houseBody(c, h, { z: FZ - 1.5, w: 2.2, d: 3.0, door: true, chimneys: [[.45, -.4]] }),
    (c, h) => houseBody(c, h, { z: FZ - 1.5, w: 2.2, d: 3.0, floors: 2, door: true, chimneys: [[.45, -.4]] }),
    (c, h) => { houseBody(c, h, { x: -.25, z: FZ - 1.5, w: 2.2, d: 3.0, floors: 2, door: true, chimneys: [[-.45, -.4]] }); tower(c, h, .95, -1.1, .9, 3, false) },
    (c, h) => { houseBody(c, h, { x: -.25, z: FZ - 1.5, w: 2.2, d: 3.0, floors: 2, door: true, chimneys: [[-.45, -.4]], dormers: [.35] }); tower(c, h, .95, -1.1, .9, 4, true) },
  ],
}
function farmhouse(ctx, g, stage, variant = 'homestead') {   // the game's farmhouse grows as the homestead
  if (variant && FARM_GROWTH[variant]) { FARM_GROWTH[variant][stage - 1](ctx, g); ctx.lights.push([0, FZ + .05, 1.5, 1], [-.75, FZ + .05, 1.1, 1], [.75, FZ + .05, 1.1, 1]); return }
  farmhouseOld(ctx, g, stage)
}
function farmhouseOld(ctx, g, stage) {
  const P = [{ w: 1.9, d: 2.6, wh: 1.15, rise: .85 }, { w: 2.2, d: 3.0, wh: 1.25, rise: .92 }, { w: 2.5, d: 3.4, wh: 1.35, rise: 1 }, { w: 2.5, d: 3.4, wh: 1.35, rise: 1 }, { w: 2.5, d: 3.4, wh: 1.35, rise: 1 }][stage - 1]
  const h = new THREE.Group(); h.position.z = 1.7 - P.d / 2; g.add(h)          // the front wall always on the same line, where the path meets it
  const { w, d, wh, rise } = P
  add(h, box(w + .1, .35, d + .1, M(rep(T.stone(), w, .35))), 0, .175, 0)
  add(h, box(w, wh - .35, d, M(rep(T.plaster(), w, 1))), 0, .35 + (wh - .35) / 2, 0)
  gableEnds(h, w, d, wh, rise, M(rep(T.plaster(), w, 1)))
  gableRoof(h, w, d, wh, rise, () => M(T.clay()))
  chimneyAt(ctx, h, w * .25, -d * .18, wh, wh + rise + .25)
  opening(ctx, h, 0, .55, d / 2, .44, .9, true)
  if (stage >= 2) { opening(ctx, h, -w * .32, .85, d / 2, .36, .36); opening(ctx, h, w * .32, .85, d / 2, .36, .36) } else opening(ctx, h, -w * .3, .85, d / 2, .34, .34)
  if (stage >= 3) opening(ctx, h, 0, wh + .4, d / 2, .28, .28)
  for (const s of [-1, 1]) { const side = new THREE.Group(); side.position.set(s * w / 2, 0, 0); side.rotation.y = s * Math.PI / 2; h.add(side); for (const z of stage >= 3 ? [-.9, .3] : [-.4]) opening(ctx, side, z * s, .85, 0, .34, .34) }
  if (stage >= 4) {                                              // dormers on both slopes, a porch roof over the door
    for (const s of [-1, 1]) for (const z of [-.8, .6]) { const dg = new THREE.Group(); dg.position.set(s * w * .26, wh + rise * .45, z); dg.rotation.y = s * Math.PI / 2; h.add(dg)
      add(dg, box(.5, .42, .45, M(rep(T.plaster(), .5, .4))), 0, 0, 0); add(dg, new THREE.Mesh(new THREE.ConeGeometry(.42, .3, 4), M(rep(T.clay(), .4, .4))), 0, .36, 0).rotation.y = Math.PI / 4; opening(ctx, dg, 0, 0, .23, .24, .24) }
    for (const x of [-.4, .4]) add(h, box(.06, .9, .06, flat('#5a4634')), x, .45, d / 2 + .5)
    const pr = add(h, box(1.05, .06, .65, M(rep(T.clay(), 1, .6))), 0, .95, d / 2 + .28); pr.rotation.x = .25
  }
  if (stage >= 5) {                                              // a lean-to wing on the west side, a second chimney, a lantern by the door
    const wg = new THREE.Group(); wg.position.set(-(w / 2 + .45), 0, .2); h.add(wg)
    add(wg, box(.9, .95, 1.7, M(rep(T.plaster(), .9, 1))), 0, .475, 0)
    const lr = add(wg, box(1.1, .07, 1.9, M(rep(T.clay(), 1.1, 1.9))), -.05, 1.08, 0); lr.rotation.z = .32
    const s2 = new THREE.Group(); s2.position.set(-.45, 0, 0); s2.rotation.y = -Math.PI / 2; wg.add(s2); opening(ctx, s2, 0, .55, 0, .34, .34)
    chimneyAt(ctx, h, -w * .25, d * .2, wh, wh + rise + .1)
    add(h, box(.05, .5, .05, flat('#2e2c2a')), .5, .95, d / 2 + .05); const lamp = add(h, box(.12, .14, .12, new THREE.MeshStandardMaterial({ color: '#e8c878' })), .5, 1.25, d / 2 + .08); ctx.glow.push(lamp)
  }
  const fz = 1.7
  ctx.lights.push([0, fz + .05, 1.5, 1], [-w * .32, fz + .05, 1.1, 1], [w * .32, fz + .05, 1.1, 1])
  if (stage >= 5) ctx.lights.push([.5, fz + .15, 1.8, 0, .6])
}
// the observatory (the research lab, 4x4): a round white tower, a ring of windows, a green copper dome with its slit open
// to the south and the telescope looking out of it; the door half a tile east of the middle (the path comes to the third tile)
function lab(ctx, g) {
  add(g, new THREE.Mesh(new THREE.CylinderGeometry(1.6, 1.7, .35, 40), M(rep(T.stone(), 10, .35))), 0, .175, 0)
  add(g, new THREE.Mesh(new THREE.CylinderGeometry(1.5, 1.55, 1.45, 40), M(rep(T.plaster(), 9, 1.45))), 0, .35 + .725, 0)
  add(g, new THREE.Mesh(new THREE.TorusGeometry(1.52, .05, 8, 48), flat('#8e867a')), 0, 1.8, 0).rotation.x = Math.PI / 2
  // the dome: copper gone green, an opening from its top down to its rim, facing south; dark inside, lit after dark
  const dome = new THREE.Group(); dome.position.y = 1.82; g.add(dome)
  const gap = .42, copper = flat('#5e8274', { metalness: .45, roughness: .5 })
  const shell = add(dome, new THREE.Mesh(new THREE.SphereGeometry(1.45, 40, 16, Math.PI / 2 + gap / 2, Math.PI * 2 - gap, 0, Math.PI / 2), copper)); shell.material.side = THREE.DoubleSide
  for (let k = 1; k < 12; k++) { const a = Math.PI / 2 + gap / 2 + k * (Math.PI * 2 - gap) / 12; const rib = add(dome, new THREE.Mesh(new THREE.TorusGeometry(1.46, .025, 6, 24, Math.PI / 2), flat('#45625a', { metalness: .5 }))); rib.rotation.set(0, -a + Math.PI / 2, 0); rib.rotateX(0); rib.rotation.order = 'YXZ'; rib.rotation.x = 0; rib.rotation.z = 0; rib.rotation.y = -a; rib.rotateOnAxis(new THREE.Vector3(1, 0, 0), 0) }
  const inside = add(dome, new THREE.Mesh(new THREE.SphereGeometry(1.4, 32, 12, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshStandardMaterial({ color: '#1a1814', side: THREE.BackSide }))); ctx.glow.push(inside)
  for (const s of [-1, 1]) { const shutter = add(dome, box(.06, .06, 1.45, flat('#3e544c', { metalness: .5 }))); shutter.position.set(s * .32, 1.0, .9); shutter.rotation.x = -.62 }
  // the telescope: a brass tube on its mount, looking out of the slit
  const tube = new THREE.Group(); tube.position.set(0, .55, .1); tube.rotation.x = -.75; dome.add(tube)
  add(tube, new THREE.Mesh(new THREE.CylinderGeometry(.13, .16, 1.9, 16), flat('#b08a4e', { metalness: .7, roughness: .35 })), 0, 0, .55).rotation.x = Math.PI / 2
  add(tube, new THREE.Mesh(new THREE.CylinderGeometry(.17, .17, .12, 16), flat('#2a2622', { metalness: .5 })), 0, 0, 1.5).rotation.x = Math.PI / 2
  add(dome, new THREE.Mesh(new THREE.SphereGeometry(.12, 12, 8), flat('#d8d2c4', { metalness: .3 })), 0, 1.47, 0)
  // a ring of tall windows, the door with steps
  const da = Math.acos(.5 / 1.52)
  for (const [a, door] of [[da, true], [da - .7, false], [da + .7, false], [da + 1.9, false], [da - 1.9, false], [da + 3.1, false]]) { const o = new THREE.Group(); o.position.set(Math.cos(a) * 1.53, 0, Math.sin(a) * 1.53); o.rotation.y = Math.PI / 2 - a; g.add(o); opening(ctx, o, 0, door ? .62 : 1.12, 0, door ? .48 : .26, door ? .9 : .5, door) }
  add(g, box(.7, .1, .35, flat('#9a9284')), .5, .05, Math.sin(da) * 1.6 + .2)
  ctx.lights.push([.5, Math.sin(da) * 1.6 + .15, 1.4, 1], [0, 1.2, 2.2, 1, .55])
}
// the bakery (2x2): a half-timbered bakehouse under dark wooden shingles, its ridge running east to west, and a big round
// clay bread oven built onto its east side with a chimney of its own; flour sacks and a bread board by the door (half a
// tile east of the middle: the path comes to the second tile)
function bakery(ctx, g) {
  const w = 1.4, d = 1.25, wh = 1.05, rise = .62, fz = .8
  const h = new THREE.Group(); h.position.set(-.18, 0, fz - d / 2); g.add(h)
  add(h, box(w + .06, .25, d + .06, M(rep(T.stone(), w, .25))), 0, .125, 0)
  add(h, box(w, wh - .25, d, M(rep(T.plaster(), w, .8))), 0, .25 + (wh - .25) / 2, 0)
  // the timber frame on the front: posts, a rail, braces
  const beam = flat('#3e2e22'), front = d / 2 + .012
  for (const x of [-w / 2 + .04, -.2, .3, w / 2 - .04]) add(h, box(.07, wh - .25, .02, beam), x, .25 + (wh - .25) / 2, front)
  add(h, box(w, .07, .02, beam), 0, .72, front); add(h, box(w, .07, .02, beam), 0, wh - .03, front)
  for (const [x, a] of [[-.45, .7], [.55, -.7]]) add(h, box(.06, .55, .02, beam), x, .5, front).rotation.z = a
  // the roof, its ridge east to west
  const roof = new THREE.Group(); roof.rotation.y = Math.PI / 2; h.add(roof)
  gableEnds(roof, d, w, wh, rise, M(rep(T.plaster(), d, .6)))
  gableRoof(roof, d, w, wh, rise, () => M(T.shingle()), .16)
  opening(ctx, h, .55, .5, d / 2, .36, .82, true)
  opening(ctx, h, -.3, .52, d / 2, .4, .32)
  // the oven: a clay dome on a stone plinth against the east wall, its mouth to the south, a stone chimney rising from it
  const ov = new THREE.Group(); ov.position.set(w / 2 + .32 - .18, 0, fz - d / 2 - .05); g.add(ov)
  add(ov, new THREE.Mesh(new THREE.CylinderGeometry(.5, .55, .3, 24), M(rep(T.stone(), 3, .3))), 0, .15, 0)
  add(ov, new THREE.Mesh(new THREE.SphereGeometry(.48, 24, 12, 0, Math.PI * 2, 0, Math.PI / 2), M(T.clayDome())), 0, .3, 0).scale.set(1, .85, 1)
  ctx.glow.push(add(ov, box(.2, .16, .05, new THREE.MeshStandardMaterial({ color: '#2a160e' })), 0, .42, .46))
  add(ov, box(.22, .9, .22, M(rep(T.stone(), .3, .9))), .1, .7, -.28); add(ov, box(.27, .05, .27, flat('#7a7268')), .1, 1.16, -.28)
  ctx.smoke.push(new THREE.Vector3(w / 2 + .32 - .18 + .1, 1.22, fz - d / 2 - .05 - .28))
  // flour sacks by the door, a bread board on trestles, firewood for the oven
  for (const [x, z] of [[.15, .98], [.3, 1.03]]) add(g, new THREE.Mesh(new THREE.SphereGeometry(.12, 10, 8), flat('#dcd2bc')), x, .09, z).scale.set(1.1, .8, 1)
  add(g, box(.34, .05, .2, flat('#8a6440')), -.6, .36, .98); for (const x of [-.7, -.6, -.5]) add(g, new THREE.Mesh(new THREE.SphereGeometry(.045, 10, 8), flat('#b8823e')), x, .41, .98).scale.set(1.5, .8, 1)
  for (const [x, z] of [[-.74, .92], [-.46, .92], [-.74, 1.04], [-.46, 1.04]]) add(g, box(.03, .36, .03, flat('#4e3a28')), x, .18, z)
  for (let k = 0; k < 6; k++) add(g, new THREE.Mesh(new THREE.CylinderGeometry(.05, .05, .4, 8), M(T.bark())), .75 + (k % 3) * .1, .06 + Math.floor(k / 3) * .09, .55).rotation.x = Math.PI / 2
  ctx.lights.push([.37, fz + .1, 1.4, 1], [-.48, fz + .1, 1.2, 1], [.66, .55, 1.6, 0, .7])
}
function silo(ctx, g) {
  add(g, new THREE.Mesh(new THREE.CylinderGeometry(.82, .82, 3.2, 32), M(rep(T.metal(), 5.5, 3.2), { metalness: .35, roughness: .55 })), 0, 1.6, 0)
  add(g, new THREE.Mesh(new THREE.SphereGeometry(.84, 32, 12, 0, TAU, 0, Math.PI / 2), M(rep(T.metal(), 5.5, 1), { metalness: .4, roughness: .5 })), 0, 3.2, 0).scale.y = .45
  for (const y of [.9, 1.8, 2.7]) add(g, new THREE.Mesh(new THREE.TorusGeometry(.83, .03, 6, 40), flat('#4e5250', { metalness: .6 })), 0, y, 0).rotation.x = Math.PI / 2
  for (const dx of [-.1, .1]) add(g, box(.03, 3.3, .03, flat('#3e3e3c', { metalness: .6 })), dx, 1.65, .85)
  for (let y = .4; y < 3.3; y += .25) add(g, box(.2, .02, .02, flat('#3e3e3c', { metalness: .6 })), 0, y, .85)
  add(g, new THREE.Mesh(new THREE.CylinderGeometry(.12, .16, .2, 12), flat('#5e625e', { metalness: .5 })), 0, 3.63, 0)
}
function kitchen(ctx, g) {
  add(g, box(3, .08, 2, M(rep(T.flag(), 3, 2))), 0, .04, 0)
  add(g, box(1.2, .35, 1.0, M(rep(T.stone(), 1.2, .35))), -.8, .26, -.35)
  add(g, new THREE.Mesh(new THREE.SphereGeometry(.55, 24, 12, 0, TAU, 0, Math.PI / 2), M(T.clayDome())), -.8, .43, -.35).scale.set(1, .8, .9)
  add(g, new THREE.Mesh(new THREE.CylinderGeometry(.07, .09, .5, 10), flat('#5a4636')), -.8, .95, -.6); ctx.smoke.push(new THREE.Vector3(-.8, 1.22, -.6))
  ctx.glow.push(add(g, box(.24, .18, .05, new THREE.MeshStandardMaterial({ color: '#2a160e' })), -.8, .55, .12))
  for (let k = 0; k < 9; k++) { const a = k / 9 * TAU; add(g, new THREE.Mesh(new THREE.DodecahedronGeometry(.08), flat('#7a746a')), .55 + Math.cos(a) * .28, .1, -.35 + Math.sin(a) * .22) }
  ctx.glow.push(add(g, new THREE.Mesh(new THREE.CylinderGeometry(.18, .18, .03, 14), new THREE.MeshStandardMaterial({ color: '#4a2412' })), .55, .1, -.35)); ctx.smoke.push(new THREE.Vector3(.55, .7, -.35))
  add(g, new THREE.Mesh(new THREE.SphereGeometry(.17, 14, 10), flat('#2a2a2a', { metalness: .5, roughness: .4 })), .55, .42, -.35)
  for (const a of [0, 2.1, 4.2]) add(g, box(.025, .8, .025, flat('#2a2a2a')), .55 + Math.cos(a) * .2, .45, -.35 + Math.sin(a) * .2).rotation.set(Math.sin(a) * .3, 0, -Math.cos(a) * .3)
  add(g, box(1.6, .06, .55, M(rep(T.planks(), 1.6, .55))), .2, .48, .5); for (const [x, z] of [[-.5, .3], [.9, .3], [-.5, .7], [.9, .7]]) add(g, box(.06, .45, .06, flat('#4e3a28')), x, .23, z)
  for (const z of [.12, .88]) add(g, box(1.5, .05, .18, flat('#6a5038')), .2, .3, z)
  for (let k = 0; k < 4; k++) add(g, new THREE.Mesh(new THREE.CylinderGeometry(.07, .05, .04, 12), flat('#b8a888')), -.3 + k * .35, .53, .5)
  for (let k = 0; k < 8; k++) add(g, new THREE.Mesh(new THREE.CylinderGeometry(.07, .07, .5, 8), M(T.bark())), -1.35, .08 + Math.floor(k / 4) * .14, .2 + (k % 4) * .15).rotation.x = Math.PI / 2
  add(g, new THREE.Mesh(new THREE.CylinderGeometry(.17, .17, .42, 14), M(rep(T.planks(), 2, 1))), 1.3, .21, -.6)
  ctx.lights.push([-.8, .2, 2.2, 0, .8], [.55, -.35, 2.2, 0, .75])
}
function nest(ctx, g) {
  add(g, new THREE.Mesh(new THREE.CylinderGeometry(.9, .95, .06, 30), M(rep(T.straw(), 2, 2))), 0, .03, 0)
  add(g, new THREE.Mesh(new THREE.TorusGeometry(.55, .26, 14, 32), M(rep(T.straw(), 4, 1))), 0, .2, 0).rotation.x = Math.PI / 2
  add(g, box(.5, .28, .32, M(T.straw())), .62, .14, .62).rotation.y = .4
}
const BUILD = { farmhouse, lab, bakery, silo, kitchen, nest }

/** A building's model: its group, the meshes that glow after dark, chimney tops (model space), where its lights fall
 *  on the ground ([x, z, reach, forward-only, brightness] from its centre). */
export function build(kind, stage = 1, variant) {
  reseed(kind.length * 31 + stage)
  const ctx = { group: new THREE.Group(), glow: [], smoke: [], lights: [] }
  BUILD[kind](ctx, ctx.group, stage, variant)
  return ctx
}

// Every crop painted as a field, like tools/painted-crops.mjs (which keeps its four hand-made ones: tomatoes, wheat,
// zucchini, Buddha's hand). Each crop belongs to a family that shares a way of growing (grain, rosette, vine, bush,
// orchard, tall, palm, spiky, cactus, mushroom) and brings its own colours and fruit. Plants stand on the soil's two
// furrow ridges (a quarter and three quarters down the tile); every tile repeats without a seam.
//   tiles/crop-<crop>-<stage>.svg for 2-sown .. 6-harvest, and web/public/mountain-ideas/crops.html (the sheet)
// Run from the Cute Fox folder: node tools/painted-crops-all.mjs, then web/scripts/import-art.mjs
import { mkdirSync, writeFileSync } from 'node:fs'

const f = (n) => +n.toFixed(1)
let seed = 1
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647 }
const mix = (a, b, t) => { const p = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)), A = p(a), B = p(b); return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * Math.max(0, Math.min(1, t))).toString(16).padStart(2, '0')).join('') }
const LA = -2.3, toward = (a) => .5 + .5 * Math.cos(a - LA), TAU = Math.PI * 2
const STAGES = ['2-sown', '3-first-growth', '4-second-growth', '5-third-growth', '6-harvest']
const ROWS = [25, 75]
const SOFT = `<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.2"/></filter><filter id="glow" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="2.5"/></filter>`
const svg = (label, body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" role="img" aria-label="${label}"><defs>${SOFT}</defs>${body}</svg>\n`
const field = (body) => `<g id="c">${body}</g>` + [[-100, 0], [100, 0], [0, -100], [0, 100], [-100, -100], [100, -100], [-100, 100], [100, 100]].map(([x, y]) => `<use href="#c" x="${x}" y="${y}"/>`).join('')

// ---------- brushes ----------
const leaf = (x, y, a, l, w, dark, light) => { const tx = x + Math.cos(a) * l, ty = y + Math.sin(a) * l, nx = -Math.sin(a) * w, ny = Math.cos(a) * w
  return `<path d="M${f(x)} ${f(y)}Q${f((x + tx) / 2 + nx)} ${f((y + ty) / 2 + ny)} ${f(tx)} ${f(ty)}Q${f((x + tx) / 2 - nx)} ${f((y + ty) / 2 - ny)} ${f(x)} ${f(y)}Z" fill="${mix(dark, light, toward(a) * .85 + (rnd() - .5) * .2)}"/>` }
const sprout = (x, y, s, L = ['#4E7A30', '#A8CC6A']) => [-2.2, -.9].map((a) => leaf(x, y, a + (rnd() - .5) * .4, 5 * s, 2 * s, L[0], L[1])).join('') + `<circle cx="${f(x)}" cy="${f(y)}" r="${f(s)}" fill="${mix(L[0], '#000000', .25)}"/>`
const holes = (xs) => ROWS.map((y) => xs.map((x) => `<ellipse cx="${f(x + (rnd() - .5) * 3)}" cy="${f(y + 1)}" rx="3.2" ry="2" fill="#3A2614" opacity=".55"/><ellipse cx="${f(x - .5)}" cy="${f(y)}" rx="1.4" ry="1" fill="#E8D8A8" opacity=".8"/>`).join('')).join('')
const band = (half, op = .5, col = '#1E3214') => ROWS.map((y) => `<rect x="0" y="${f(y - half * .8)}" width="100" height="${f(half * 1.6)}" fill="${col}" opacity="${op}" filter="url(#soft)"/>`).join('')
const shade = (x, y, rx, ry, o = .32) => `<ellipse cx="${f(x + rx * .25)}" cy="${f(y + ry * .35)}" rx="${f(rx)}" ry="${f(ry * .8)}" fill="#1A1408" opacity="${o}" filter="url(#soft)"/>`
const hi = (x, y, r, o = .55) => `<circle cx="${f(x - r * .35)}" cy="${f(y - r * .35)}" r="${f(r * .35)}" fill="#FFFFFF" opacity="${o}"/>`
const ball = (x, y, r, c) => `<circle cx="${f(x + r * .25)}" cy="${f(y + r * .35)}" r="${f(r)}" fill="#1A1408" opacity=".3"/><circle cx="${f(x)}" cy="${f(y)}" r="${f(r)}" fill="${c}"/><circle cx="${f(x + r * .2)}" cy="${f(y + r * .2)}" r="${f(r * .75)}" fill="${mix(c, '#000000', .18)}" opacity=".35"/>` + hi(x, y, r)
const oval = (x, y, l, w, a, c) => `<ellipse cx="${f(x + 1)}" cy="${f(y + 1.4)}" rx="${f(l)}" ry="${f(w)}" transform="rotate(${f(a * 57.3)} ${f(x + 1)} ${f(y + 1.4)})" fill="#1A1408" opacity=".3"/><ellipse cx="${f(x)}" cy="${f(y)}" rx="${f(l)}" ry="${f(w)}" transform="rotate(${f(a * 57.3)} ${f(x)} ${f(y)})" fill="${c}"/><ellipse cx="${f(x - w * .3)}" cy="${f(y - w * .4)}" rx="${f(l * .5)}" ry="${f(w * .3)}" transform="rotate(${f(a * 57.3)} ${f(x - w * .3)} ${f(y - w * .4)})" fill="#FFFFFF" opacity=".35"/>`
const blossom = (x, y, r, col) => { let o = ''; for (let j = 0; j < 5; j++) { const b = j / 5 * TAU + rnd(), cx = x + Math.cos(b) * r * .55, cy = y + Math.sin(b) * r * .55; o += `<ellipse cx="${f(cx)}" cy="${f(cy)}" rx="${f(r * .55)}" ry="${f(r * .38)}" transform="rotate(${f(b * 57.3)} ${f(cx)} ${f(cy)})" fill="${mix(col, '#6A4A20', (1 - toward(b)) * .3)}"/>` } return o + `<circle cx="${f(x)}" cy="${f(y)}" r="${f(r * .28)}" fill="#E8A030"/>` }
// a fruit of a given kind
function fruit(kind, x, y, s, c, a = rnd() * TAU) {
  switch (kind) {
    case 'long': return oval(x, y, 4.5 * s, 1.6 * s, a, c) + `<circle cx="${f(x - Math.cos(a) * 4.5 * s)}" cy="${f(y - Math.sin(a) * 4.5 * s)}" r="${f(1 * s)}" fill="#3E6A2A"/>`
    case 'pod': return oval(x, y, 4 * s, 1.1 * s, a, c)
    case 'cluster': { let o = ''; for (let k = 0; k < 7; k++) { const b = k * 2.4, d = k ? 1.8 * s : 0; o += ball(x + Math.cos(b) * d, y + Math.sin(b) * d * 1.2 + k * .25 * s, 1.3 * s, c) } return o }
    case 'spiky': { let o = ''; for (let k = 0; k < 10; k++) { const b = k / 10 * TAU; o += `<path d="M${f(x + Math.cos(b) * 2.6 * s)} ${f(y + Math.sin(b) * 2.6 * s)}l${f(Math.cos(b) * 1.6 * s)} ${f(Math.sin(b) * 1.6 * s)}" stroke="${mix(c, '#3A2A10', .3)}" stroke-width="${f(.8 * s)}" stroke-linecap="round"/>` } return o + ball(x, y, 2.8 * s, c) }
    case 'hairy': { let o = ''; for (let k = 0; k < 14; k++) { const b = k / 14 * TAU; o += `<path d="M${f(x + Math.cos(b) * 2 * s)} ${f(y + Math.sin(b) * 2 * s)}l${f(Math.cos(b + .4) * 1.5 * s)} ${f(Math.sin(b + .4) * 1.5 * s)}" stroke="${mix(c, '#F0E070', .3)}" stroke-width="${f(.5 * s)}" stroke-linecap="round"/>` } return o + ball(x, y, 2.1 * s, c) }
    case 'striped': return ball(x, y, 4 * s, c) + [-.5, 0, .5].map((d) => `<path d="M${f(x + d * 4 * s)} ${f(y - 3.8 * s)}Q${f(x + d * 6 * s)} ${f(y)} ${f(x + d * 4 * s)} ${f(y + 3.8 * s)}" stroke="${mix(c, '#0E2A10', .55)}" stroke-width="${f(.9 * s)}" fill="none"/>`).join('')
    case 'ribbed': return ball(x, y, 4 * s, c) + [-.55, 0, .55].map((d) => `<path d="M${f(x + d * 4 * s)} ${f(y - 3.6 * s)}Q${f(x + d * 5.5 * s)} ${f(y)} ${f(x + d * 4 * s)} ${f(y + 3.6 * s)}" stroke="${mix(c, '#5A2A08', .35)}" stroke-width="${f(.7 * s)}" fill="none"/>`).join('') + `<rect x="${f(x - .6 * s)}" y="${f(y - 5 * s)}" width="${f(1.2 * s)}" height="${f(2 * s)}" fill="#4E5A28"/>`
    case 'egg': return oval(x, y, 2.6 * s, 2 * s, -1.2, c)
    case 'pouch': return ball(x, y, 2.6 * s, c) + `<path d="M${f(x - 1 * s)} ${f(y - 2.4 * s)}l${f(1 * s)} ${f(-1.6 * s)}l${f(1 * s)} ${f(1.6 * s)}" fill="${mix(c, '#7A9A5A', .5)}"/>`
    case 'star': { let o = ''; for (let k = 0; k < 6; k++) { const b = k / 6 * TAU + a; o += leaf(x, y, b, 3.2 * s, 1 * s, mix(c, '#405070', .3), c) } return `<circle cx="${f(x)}" cy="${f(y)}" r="${f(5 * s)}" fill="${c}" opacity=".35" filter="url(#glow)"/>` + o + `<circle cx="${f(x)}" cy="${f(y)}" r="${f(.9 * s)}" fill="#FFF8E0"/>` }
    case 'flower': return blossom(x, y, 3 * s, c)
    default: return ball(x, y, 1.6 * s, c)
  }
}
// a crop's fruit drawn in its colours, cycling through them
const fruitOf = (s, k, x, y, sc = 1) => fruit(s.shape, x, y, (s.size ?? 1) * sc, s.fruit[k % s.fruit.length])

// ---------- families ----------
// grain: shoots that close into a standing field, then turn their ripe colour
function grain(st, s) {
  const P = []
  if (st === 0) return holes([12.5, 37.5, 62.5, 87.5])
  if (st === 1) return ROWS.map((y) => [12.5, 37.5, 62.5, 87.5].map((x) => sprout(x, y, .8)).join('')).join('')
  const ripe = [0, 0, 0, .25, 1][st], tall = [0, 0, 8, 12, 14][st]
  const dk = mix('#3E6024', s.stalk[0], ripe), lt = mix('#9CC064', s.stalk[1], ripe)
  if (st === 4) P.push(`<rect width="100" height="100" fill="${s.ground}"/>`)
  else if (st === 3) P.push(band(13, .7, '#4E6A2C'))
  const n = [0, 0, 60, 110, 380][st]
  for (let k = 0; k < n; k++) {
    const x = rnd() * 100, y = st === 4 ? rnd() * 106 - 3 : ROWS[k % 2] + (rnd() - .5) * [0, 0, 10, 18][st], t = -Math.PI / 2 - .35 + (rnd() - .5) * .5 + (s.droop && st === 4 ? .9 : 0), l = tall * (.7 + rnd() * .5)
    const tx = x + Math.cos(t) * l, ty = y + Math.sin(t) * l
    P.push(`<path d="M${f(x)} ${f(y)}L${f(tx)} ${f(ty)}" stroke="${mix(dk, lt, rnd() * .6 + .2)}" stroke-width="1.3" stroke-linecap="round"/>`)
    if (st >= 3) P.push(`<ellipse cx="${f(tx)}" cy="${f(ty)}" rx="${s.head ?? 1.6}" ry="${f((s.head ?? 1.6) * 2.2)}" transform="rotate(${f(t * 57.3 + 90)} ${f(tx)} ${f(ty)})" fill="${mix(mix('#7EA048', s.ear, ripe), '#FFF2B8', rnd() * .4 * ripe + .05)}"/>`)
  }
  return P.join('')
}
// rosette: leafy heads, herbs and root crops, three a row
function rosette(st, s) {
  const xs = s.dense ? [12.5, 37.5, 62.5, 87.5] : [16.7, 50, 83.3], P = []
  if (st === 0) return holes(xs)
  if (st === 1) return ROWS.map((y) => xs.map((x) => sprout(x, y, .9, s.leaf)).join('')).join('')
  const R = (s.dense ? [0, 0, 6, 9, 11] : [0, 0, 8, 12, 15])[st] * (s.scale ?? 1)
  P.push(band(R * .9, .45))
  for (const y of ROWS) for (const x0 of xs) {
    const x = x0 + (rnd() - .5) * 2.5, yy = y + (rnd() - .5) * 2
    P.push(shade(x, yy, R, R * .85))
    const nl = s.narrow ? 14 : 9
    for (let k = 0; k < nl; k++) { const a = k / nl * TAU + rnd() * .5; P.push(leaf(x, yy, a, R * (.8 + rnd() * .3), R * (s.narrow ? .1 : .32), s.leaf[0], s.leaf[1])) }
    if (s.head && st >= 3) { const r = R * (st === 4 ? .62 : .4); P.push(`<circle cx="${f(x)}" cy="${f(yy)}" r="${f(r)}" fill="${s.head[0]}"/>`); for (let k = 0; k < 6; k++) { const a = k / 6 * TAU + rnd(); P.push(leaf(x, yy, a, r * .95, r * .45, s.head[0], s.head[1])) } P.push(hi(x, yy, r * .7, .25)) }
    else for (let k = 0; k < 5; k++) { const a = rnd() * TAU; P.push(leaf(x, yy, a, R * .5, R * .2, s.leaf[0], mix(s.leaf[1], '#FFFFFF', .15))) }
    if (s.root && st === 4) P.push(`<ellipse cx="${f(x + R * .15)}" cy="${f(yy + R * .3)}" rx="${f(R * .32)}" ry="${f(R * .22)}" fill="${s.root}"/>`, hi(x + R * .15, yy + R * .3, R * .2, .4))
    if (s.fruit && st === 4) for (let k = 0; k < 3; k++) { const a = rnd() * TAU, d = R * (.3 + rnd() * .4); P.push(fruitOf(s, k, x + Math.cos(a) * d, yy + Math.sin(a) * d, .8)) }
    if (s.bloom && st === 3) for (let k = 0; k < 3; k++) { const a = rnd() * TAU, d = R * .5; P.push(blossom(x + Math.cos(a) * d, yy + Math.sin(a) * d, 2, s.bloom)) }
  }
  return P.join('')
}
// a broad leaf with three rounded lobes and pale veins
const bigLeaf = (x, y, a, l, dark, light) => {
  const c = mix(dark, light, toward(a) * .8 + (rnd() - .5) * .2); let o = ''
  for (const [da, k, rr] of [[0, .62, .42], [-.55, .48, .32], [.55, .48, .32]]) { const b = a + da, cx = x + Math.cos(b) * l * k, cy = y + Math.sin(b) * l * k
    o += `<ellipse cx="${f(cx + 1.6)}" cy="${f(cy + 2)}" rx="${f(l * rr)}" ry="${f(l * rr * .86)}" fill="#142410" opacity=".35"/><ellipse cx="${f(cx)}" cy="${f(cy)}" rx="${f(l * rr)}" ry="${f(l * rr * .86)}" fill="${c}"/>` }
  for (const da of [0, -.5, .5]) o += `<path d="M${f(x)} ${f(y)}L${f(x + Math.cos(a + da) * l * .8)} ${f(y + Math.sin(a + da) * l * .8)}" stroke="${mix(c, '#E8F0C8', .45)}" stroke-width=".8" opacity=".8"/>`
  return o
}
// vine: rows of broad leaves that widen, blossoms, then fruit lying among them
function vine(st, s) {
  const P = []
  if (st === 0) return holes([25, 75])
  if (st === 1) return ROWS.map((y) => [25, 75].map((x) => sprout(x, y, 1.2, s.leaf)).join('')).join('')
  const half = [0, 0, 11, 17, 21][st], L = [0, 0, 11, 15, 17][st]
  P.push(band(half, .55))
  for (const y of ROWS) for (let x = -6; x < 106; x += 9 + rnd() * 5) P.push(bigLeaf(x, y + (rnd() - .5) * half * 1.2, rnd() * TAU, L * (.75 + rnd() * .35), s.leaf[0], s.leaf[1]))
  if (st === 4) for (let k = 0; k < 4; k++) P.push(fruitOf(s, k, 12 + k * 24 + (rnd() - .5) * 6, ROWS[k % 2] + (rnd() - .5) * 12))
  if (st >= 3) for (let k = 0; k < (st === 3 ? 6 : 2); k++) P.push(blossom(8 + k * (st === 3 ? 17 : 40) + rnd() * 8, ROWS[k % 2] + (rnd() - .5) * half, 5, s.bloom ?? '#F4A830'))
  return P.join('')
}
// bush: two bushy plants a row, flowering, then hung with fruit
function bush(st, s) {
  const xs = s.low ? [16.7, 50, 83.3] : [25, 75], P = []
  if (st === 0) return holes(xs)
  if (st === 1) return ROWS.map((y) => xs.map((x) => sprout(x, y, 1, s.leaf)).join('')).join('')
  const R = (s.low ? [0, 0, 9, 13, 15] : [0, 0, 14, 21, 25])[st]
  for (const y of ROWS) for (const x0 of xs) {
    const x = x0 + (rnd() - .5) * 3
    P.push(shade(x, y, R * .95, R * .75, .35))
    for (let k = 0; k < 9 + st * 3; k++) { const a = rnd() * TAU, d = rnd() * R * .35; P.push(leaf(x + Math.cos(a) * d, y + Math.sin(a) * d, a, R * (.55 + rnd() * .35), R * .22, s.leaf[0], s.leaf[1])) }
    for (let k = 0; k < 6; k++) { const a = rnd() * TAU, d = rnd() * R * .5; P.push(leaf(x + Math.cos(a) * d, y + Math.sin(a) * d, a, R * .4, R * .15, s.leaf[0], mix(s.leaf[1], '#FFFFFF', .2))) }
    if (st === 3) for (let k = 0; k < 4; k++) { const a = rnd() * TAU, d = R * (.2 + rnd() * .5); P.push(blossom(x + Math.cos(a) * d, y + Math.sin(a) * d, 2.4, s.bloom ?? '#FAF6EC')) }
    if (st === 4) for (let k = 0; k < (s.many ?? 6); k++) { const a = rnd() * TAU, d = R * (.2 + rnd() * .5); P.push(fruitOf(s, k, x + Math.cos(a) * d, y + Math.sin(a) * d)) }
  }
  return P.join('')
}
// orchard: rows of glossy shrubs that thicken into hedges, blossom, then fruit
function orchard(st, s) {
  const P = []
  if (st === 0) return holes([12.5, 37.5, 62.5, 87.5])
  if (st === 1) return ROWS.map((y) => [12.5, 37.5, 62.5, 87.5].map((x) => sprout(x, y, .9, s.leaf)).join('')).join('')
  const half = [0, 0, 10, 16, 20][st], ll = [0, 0, 5, 6, 7][st]
  P.push(band(half, .6, '#14260F'))
  for (const y of ROWS) for (let k = 0; k < [0, 0, 70, 120, 210][st]; k++) P.push(leaf(rnd() * 112 - 6, y + (rnd() - .5) * half * 1.7, rnd() * TAU, ll * (.8 + rnd() * .5), ll * .38, s.leaf[0], s.leaf[1]))
  for (let k = 0; k < 30; k++) P.push(`<ellipse cx="${f(rnd() * 100)}" cy="${f(ROWS[k % 2] + (rnd() - .5) * half * 1.4)}" rx="1.5" ry=".8" fill="#E8F4D0" opacity=".5"/>`)
  if (st === 3) for (let k = 0; k < 16; k++) P.push(blossom(rnd() * 100, ROWS[k % 2] + (rnd() - .5) * half * 1.3, 2.4, s.bloom ?? '#FAF6EC'))
  if (st === 4) for (let k = 0; k < (s.many ?? 10); k++) P.push(fruitOf(s, k, 4 + k * (92 / (s.many ?? 10)) + (rnd() - .5) * 4, ROWS[k % 2] + (rnd() - .5) * 24))
  return P.join('')
}
// tall: corn and cane, long strap leaves in rows, tassels and cobs or banded stalks
function tall(st, s) {
  const P = []
  if (st === 0) return holes([16.7, 50, 83.3])
  if (st === 1) return ROWS.map((y) => [16.7, 50, 83.3].map((x) => sprout(x, y, 1, s.leaf)).join('')).join('')
  const half = [0, 0, 9, 15, 19][st], l = [0, 0, 9, 14, 17][st]
  P.push(band(half, .55))
  for (const y of ROWS) for (const x0 of [16.7, 50, 83.3]) {
    const x = x0 + (rnd() - .5) * 3
    for (let k = 0; k < 8; k++) { const a = k / 8 * TAU + rnd() * .4; P.push(leaf(x, y, a, l * (.8 + rnd() * .4), 1.6, s.leaf[0], s.leaf[1])) }
    if (s.stalk) P.push(`<circle cx="${f(x)}" cy="${f(y)}" r="2.6" fill="${s.stalk}"/>`, hi(x, y, 2.6, .3))
    if (st >= 3 && s.tassel) for (let k = 0; k < 5; k++) { const a = k / 5 * TAU; P.push(`<path d="M${f(x)} ${f(y)}l${f(Math.cos(a) * 3.5)} ${f(Math.sin(a) * 3.5)}" stroke="${s.tassel}" stroke-width="1.1" stroke-linecap="round"/>`) }
    if (st === 4 && s.fruit) for (let k = 0; k < 2; k++) P.push(fruitOf(s, k, x + (k ? 5 : -5), y + (k ? 3 : -2)))
  }
  return P.join('')
}
// sunflower: rows of leafy plants, buds, then big yellow faces
function sunflower(st, s) {
  const xs = [25, 75], P = []
  if (st === 0) return holes(xs)
  if (st === 1) return ROWS.map((y) => xs.map((x) => sprout(x, y, 1.2)).join('')).join('')
  const R = [0, 0, 12, 17, 20][st]
  for (const y of ROWS) for (const x0 of xs) {
    const x = x0 + (rnd() - .5) * 3
    P.push(shade(x, y, R, R * .8))
    for (let k = 0; k < 8; k++) { const a = k / 8 * TAU + rnd() * .4; P.push(leaf(x, y, a, R * (.85 + rnd() * .2), R * .3, '#2E5020', '#8EB45A')) }
    if (st === 3) P.push(ball(x, y, 4, '#6E8A3A'))
    if (st === 4) { let o = ''; for (let k = 0; k < 16; k++) { const a = k / 16 * TAU; o += leaf(x, y, a, 11, 2.6, '#D89A20', '#FFE070') } P.push(o, `<circle cx="${f(x)}" cy="${f(y)}" r="6" fill="#5A3A1A"/>`, `<circle cx="${f(x - 1.5)}" cy="${f(y - 1.5)}" r="2.5" fill="#8A6030" opacity=".7"/>`) }
  }
  return P.join('')
}
// palm: one big plant a tile, long fronds radiating, then a hanging bunch
function palm(st, s) {
  const spots = [[28, 25], [72, 75]], P = []
  if (st === 0) return holes([28, 72])
  if (st === 1) return spots.map(([x, y]) => sprout(x, y, 1.3, s.leaf)).join('')
  const R = [0, 0, 16, 23, 27][st]
  for (const [x, y] of spots) {
    P.push(shade(x, y, R, R * .85, .35))
    const n = s.round ? 6 : 7
    for (let k = 0; k < n; k++) { const a = k / n * TAU + rnd() * .3
      if (s.round) { const cx = x + Math.cos(a) * R * .5, cy = y + Math.sin(a) * R * .5; P.push(`<ellipse cx="${f(cx)}" cy="${f(cy)}" rx="${f(R * .42)}" ry="${f(R * .32)}" transform="rotate(${f(a * 57.3)} ${f(cx)} ${f(cy)})" fill="${mix(s.leaf[0], s.leaf[1], toward(a) * .8)}"/>`)
        for (let j = -1; j <= 1; j++) P.push(`<path d="M${f(cx + Math.cos(a + 1.57) * j * R * .12)} ${f(cy + Math.sin(a + 1.57) * j * R * .12)}l${f(Math.cos(a) * R * .3)} ${f(Math.sin(a) * R * .3)}" stroke="#1A3014" stroke-width="1.2"/>`) }
      else { P.push(leaf(x, y, a, R, R * .2, s.leaf[0], s.leaf[1])); P.push(`<path d="M${f(x)} ${f(y)}L${f(x + Math.cos(a) * R * .95)} ${f(y + Math.sin(a) * R * .95)}" stroke="${mix(s.leaf[1], '#FFFFFF', .3)}" stroke-width=".8" opacity=".7"/>`) } }
    if (st === 4) P.push(fruitOf(s, 0, x + 3, y + 2, 1.2))
  }
  return P.join('')
}
// spiky: pineapple rosettes of stiff narrow leaves, then a fruit in each
function spiky(st, s) {
  const xs = [16.7, 50, 83.3], P = []
  if (st === 0) return holes(xs)
  if (st === 1) return ROWS.map((y) => xs.map((x) => sprout(x, y, .9, s.leaf)).join('')).join('')
  const R = [0, 0, 9, 13, 15][st]
  for (const y of ROWS) for (const x of xs) {
    P.push(shade(x, y, R, R * .85))
    for (let k = 0; k < 16; k++) { const a = k / 16 * TAU + rnd() * .2; P.push(leaf(x, y, a, R * (.75 + rnd() * .3), 1.2, s.leaf[0], s.leaf[1])) }
    if (st === 4) P.push(fruitOf(s, 0, x, y))
    if (st === 3) P.push(`<circle cx="${f(x)}" cy="${f(y)}" r="2.4" fill="#C86090"/>`)
  }
  return P.join('')
}
// cactus: ribbed stems sprawling from each plant, then bright fruit at their tips
function cactus(st, s) {
  const xs = [25, 75], P = []
  if (st === 0) return holes(xs)
  if (st === 1) return ROWS.map((y) => xs.map((x) => `<ellipse cx="${x}" cy="${y}" rx="3" ry="2" fill="#5E8A4A"/>`).join('')).join('')
  const l = [0, 0, 11, 17, 20][st]
  for (const y of ROWS) for (const x of xs) {
    P.push(shade(x, y, l * .9, l * .7))
    for (let k = 0; k < 5; k++) { const a = k / 5 * TAU + rnd() * .5, tx = x + Math.cos(a) * l, ty = y + Math.sin(a) * l
      P.push(`<path d="M${f(x)} ${f(y)}L${f(tx)} ${f(ty)}" stroke="${mix('#3E6A3A', '#8EBA70', toward(a))}" stroke-width="5" stroke-linecap="round"/>`, `<path d="M${f(x)} ${f(y)}L${f(tx)} ${f(ty)}" stroke="#2A4A28" stroke-width="1" stroke-dasharray="2 2"/>`)
      if (st === 4 && k % 2 === 0) P.push(fruitOf(s, k, tx, ty))
      if (st === 3 && k % 2 === 0) P.push(blossom(tx, ty, 3, '#FAF0E0')) }
  }
  return P.join('')
}
// mushroom: a mulch of straw along the rows, pins, then caps of many sizes
function mushroom(st, s) {
  const P = []
  for (const y of ROWS) for (let k = 0; k < 40; k++) { const x = rnd() * 100, yy = y + (rnd() - .5) * 18, t = rnd() * Math.PI
    P.push(`<path d="M${f(x)} ${f(yy)}l${f(Math.cos(t) * 4)} ${f(Math.sin(t) * 4)}" stroke="${mix('#8A6A3A', '#D8BC80', rnd())}" stroke-width="1.2" stroke-linecap="round" opacity=".85"/>`) }
  if (st === 0) return P.join('')
  const n = [0, 10, 14, 18, 22][st], r = [0, .9, 2, 3, 4][st]
  for (let k = 0; k < n; k++) { const x = rnd() * 100, y = ROWS[k % 2] + (rnd() - .5) * 16, rr = r * (.6 + rnd() * .6), c = s.fruit[k % s.fruit.length]
    if (s.glow) P.push(`<circle cx="${f(x)}" cy="${f(y)}" r="${f(rr * 2.2)}" fill="${c}" opacity=".35" filter="url(#glow)"/>`)
    P.push(`<ellipse cx="${f(x + rr * .3)}" cy="${f(y + rr * .4)}" rx="${f(rr)}" ry="${f(rr * .85)}" fill="#1A1408" opacity=".35"/>`, `<circle cx="${f(x)}" cy="${f(y)}" r="${f(rr)}" fill="${c}"/>`, `<circle cx="${f(x + rr * .15)}" cy="${f(y + rr * .15)}" r="${f(rr * .7)}" fill="${mix(c, '#000000', .15)}" opacity=".4"/>`, hi(x, y, rr, .6))
    if (s.shape === 'funnel') P.push(`<circle cx="${f(x)}" cy="${f(y)}" r="${f(rr * .4)}" fill="${mix(c, '#7A4A10', .35)}"/>`) }
  return P.join('')
}

// ---------- the crops: family, leaves, fruit ----------
const G = ['#2E5020', '#8EB45A'], DG = ['#1E3A1A', '#7AA458'], BG = ['#2E4A3A', '#9AB8A0']
const C = {
  oats: { fam: grain, stalk: ['#9A8A50', '#E8DCA8'], ear: '#E0D4A0', ground: '#A8986A', head: 1.3, droop: true },
  rye: { fam: grain, stalk: ['#7A6E48', '#C8BC8A'], ear: '#B4A878', ground: '#8E8058' },
  'red-wheat': { fam: grain, stalk: ['#8A4A20', '#E09A60'], ear: '#C8703A', ground: '#94502A' },
  rice: { fam: grain, stalk: ['#7A8A3A', '#D8D890'], ear: '#D8C878', ground: '#7E8A44', droop: true, head: 1.2 },
  lettuce: { fam: rosette, leaf: ['#5E9A3A', '#C8E890'], head: ['#7AB848', '#D8F0A0'] },
  cabbage: { fam: rosette, leaf: ['#4E7A6A', '#A8CCB8'], head: ['#8AB8A0', '#D8ECDC'], scale: 1.15 },
  'red-cabbage': { fam: rosette, leaf: ['#4A3A6A', '#9A88C0'], head: ['#6A4A8A', '#B8A0D8'], scale: 1.15 },
  broccoli: { fam: rosette, leaf: ['#2E5A3A', '#88B094'], head: ['#2E6A30', '#6EA050'] },
  basil: { fam: rosette, leaf: ['#2E6A2A', '#8ECC6A'], dense: true, bloom: '#F0F0F0' },
  mint: { fam: rosette, leaf: ['#3A7A4A', '#9ADCA0'], dense: true, bloom: '#D8B8E8' },
  thyme: { fam: rosette, leaf: ['#4A6A4A', '#A8B8A0'], dense: true, narrow: true, bloom: '#E8C0E0', fruit: ['#D8A8D8'], shape: 'dot', size: .6 },
  'spring-onions': { fam: rosette, leaf: ['#3A6A3A', '#A8D888'], narrow: true, root: '#F0F0E8' },
  garlic: { fam: rosette, leaf: ['#5A7A5A', '#B8D0A8'], narrow: true, root: '#F4ECE0' },
  carrots: { fam: rosette, leaf: ['#3A6A2A', '#9ACC6A'], narrow: true, root: '#E8782A' },
  beetroot: { fam: rosette, leaf: ['#3A5A2A', '#9AB86A'], root: '#8A2040' },
  radish: { fam: rosette, leaf: ['#3A6A2A', '#A0CC70'], root: '#E04A6A' },
  potatoes: { fam: rosette, leaf: ['#3A5E2A', '#90B460'], bloom: '#F0E8F8', root: '#C8A060' },
  peanuts: { fam: rosette, leaf: ['#3A6A2A', '#9AC870'], dense: true, bloom: '#F0C030', root: '#D8B078' },
  cucumber: { fam: vine, leaf: G, fruit: ['#3E6A2A'], shape: 'long', size: 1, bloom: '#F0D040' },
  pumpkin: { fam: vine, leaf: G, fruit: ['#E8822A'], shape: 'ribbed', size: 1.4 },
  watermelon: { fam: vine, leaf: G, fruit: ['#4E8A3A'], shape: 'striped', size: 1.5, bloom: '#F0D040' },
  kiwano: { fam: vine, leaf: G, fruit: ['#F09A30'], shape: 'spiky', size: 1.3, bloom: '#F0D040' },
  'bell-pepper': { fam: bush, leaf: G, fruit: ['#D8342A', '#F0C030', '#E8782A'], shape: 'ribbed', size: .7 },
  eggplant: { fam: bush, leaf: G, fruit: ['#4A2A5A'], shape: 'long', size: .9, bloom: '#B8A0E0', many: 4 },
  'carolina-reaper': { fam: bush, leaf: G, fruit: ['#C8201A'], shape: 'pod', size: .8, many: 9 },
  'ember-pepper': { fam: bush, leaf: G, fruit: ['#F05A1A', '#F0A020'], shape: 'pod', size: .8, many: 9 },
  beans: { fam: bush, leaf: G, fruit: ['#5E9A3A'], shape: 'pod', size: 1.1, many: 8, bloom: '#F0F0F0' },
  peas: { fam: bush, leaf: ['#3E7A4A', '#A8D8A0'], fruit: ['#7AB850'], shape: 'pod', size: 1, many: 8, bloom: '#F0E8F8' },
  strawberries: { fam: bush, low: true, leaf: G, fruit: ['#D8282A'], shape: 'egg', size: .8, many: 4 },
  pineberry: { fam: bush, low: true, leaf: G, fruit: ['#F4ECE0'], shape: 'egg', size: .8, many: 4 },
  raspberries: { fam: bush, leaf: G, fruit: ['#C82A5A'], shape: 'cluster', size: .7, many: 7 },
  blueberries: { fam: bush, leaf: ['#2E4A3A', '#8AA88A'], fruit: ['#3A4A8A', '#5A6AA8'], shape: 'dot', size: .9, many: 14 },
  'egg-plant': { fam: bush, leaf: G, fruit: ['#F8F2E4', '#F0E0C0'], shape: 'egg', size: 1, many: 5 },
  'milk-pouch': { fam: bush, leaf: ['#4E7A5A', '#B8D8B8'], fruit: ['#FAF8F0'], shape: 'pouch', size: 1, many: 5 },
  moonbloom: { fam: bush, low: true, leaf: ['#3A5A6A', '#A8C8D0'], fruit: ['#D8E8FF', '#B8D0FF'], shape: 'star', size: .9, many: 3, bloom: '#E0E8FF' },
  lemon: { fam: orchard, leaf: DG, fruit: ['#F0D040'], shape: 'egg', size: 1.2 },
  lime: { fam: orchard, leaf: DG, fruit: ['#7AB838'], shape: 'round', size: 1.4 },
  orange: { fam: orchard, leaf: DG, fruit: ['#F08A20'], shape: 'round', size: 1.8 },
  mandarin: { fam: orchard, leaf: DG, fruit: ['#F07A1A'], shape: 'round', size: 1.5, many: 12 },
  'finger-lime': { fam: orchard, leaf: DG, fruit: ['#3A5A2A', '#6A4A3A'], shape: 'long', size: .7, many: 12 },
  coffee: { fam: orchard, leaf: DG, fruit: ['#C8201A', '#8A1A1A'], shape: 'cluster', size: .55, many: 12 },
  olive: { fam: orchard, leaf: ['#4A5A4A', '#A8B8A0'], fruit: ['#3A2A3A', '#6A7A3A'], shape: 'egg', size: .5, many: 16 },
  cacao: { fam: orchard, leaf: DG, fruit: ['#C8782A', '#A85A1A'], shape: 'ribbed', size: .7, many: 7 },
  'custard-apple': { fam: orchard, leaf: DG, fruit: ['#8AB868'], shape: 'round', size: 2.2, many: 8 },
  durian: { fam: orchard, leaf: DG, fruit: ['#A8A040'], shape: 'spiky', size: 1.2, many: 6 },
  jabuticaba: { fam: orchard, leaf: DG, fruit: ['#2A1A2A'], shape: 'cluster', size: .55, many: 12 },
  mangosteen: { fam: orchard, leaf: DG, fruit: ['#5A1A3A'], shape: 'round', size: 1.8, many: 9 },
  rambutan: { fam: orchard, leaf: DG, fruit: ['#D82A2A'], shape: 'hairy', size: .9, many: 12 },
  salak: { fam: orchard, leaf: ['#3A4A2A', '#8A9A6A'], fruit: ['#7A3A2A'], shape: 'egg', size: 1, many: 9 },
  'pink-guava': { fam: orchard, leaf: DG, fruit: ['#C8D888', '#F0A8B0'], shape: 'round', size: 1.7, many: 9 },
  kiwi: { fam: orchard, leaf: G, fruit: ['#8A6A3A'], shape: 'egg', size: 1, many: 12 },
  grapes: { fam: orchard, leaf: G, fruit: ['#5A2A6A', '#7A3A8A'], shape: 'cluster', size: .8, many: 8 },
  corn: { fam: tall, leaf: ['#3A6A2A', '#A8CC6A'], tassel: '#E8D080', fruit: ['#F0C840'], shape: 'long', size: .8 },
  'sugar-cane': { fam: tall, leaf: ['#3A6A3A', '#A8C890'], stalk: '#8A5A7A' },
  sunflower: { fam: sunflower },
  banana: { fam: palm, leaf: ['#3A7A3A', '#A8D880'], fruit: ['#F0D040'], shape: 'cluster', size: 1.1 },
  'blue-java': { fam: palm, leaf: ['#3A6A5A', '#A0C8B8'], fruit: ['#A8C0D8'], shape: 'cluster', size: 1.1 },
  monstera: { fam: palm, round: true, leaf: ['#1E4A2A', '#6AA060'], fruit: ['#C8D8A0'], shape: 'long', size: 1.3 },
  pineapple: { fam: spiky, leaf: ['#4A6A5A', '#A8C0A8'], fruit: ['#E0A030'], shape: 'ribbed', size: 1 },
  'dragon-fruit': { fam: cactus, fruit: ['#E83A8A'], shape: 'egg', size: 1.1 },
  champignon: { fam: mushroom, fruit: ['#F0E8DC', '#E4D8C8'] },
  chanterelle: { fam: mushroom, fruit: ['#F0A030', '#E8B848'], shape: 'funnel' },
  glowcap: { fam: mushroom, fruit: ['#6A8AF0', '#A070F0'], glow: true },
}

mkdirSync('web/public/mountain-ideas', { recursive: true })
const hash = (c) => { let h = 7; for (const ch of c) h = (h * 31 + ch.charCodeAt(0)) % 9973; return h }
for (const [crop, spec] of Object.entries(C)) STAGES.forEach((st, i) => {
  seed = hash(crop) * 13 + i + 1
  writeFileSync(`tiles/crop-${crop}-${st}.svg`, svg(`${crop}, ${st.slice(2).replace(/-/g, ' ')}`, field(spec.fam(i, spec))))
})
// the sheet: every crop with a field of each stage
const ALL = [...Object.keys(C), 'tomatoes', 'wheat', 'zucchini', 'buddhas-hand'].sort()
const names = ['sown', 'first growth', 'second growth', 'third growth', 'ripe']
writeFileSync('web/public/mountain-ideas/crops.html', `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Crop Fields</title>
<style>body{margin:0;background:#efe6d2;color:#2f2a22;font:14px/1.4 Georgia,serif}header{padding:24px 24px 6px;max-width:1300px;margin:0 auto}h1{margin:0 0 4px;font-size:26px}header p{margin:0;color:#7a6f5c}
main{max-width:1300px;margin:0 auto;padding:12px 24px 40px;display:grid;grid-template-columns:150px repeat(5,1fr);gap:8px 10px;align-items:center}
.h{font-size:12px;color:#7a6f5c;text-transform:uppercase;letter-spacing:.06em}.n{font-size:16px}
.f{aspect-ratio:1;border-radius:8px;background:repeating-linear-gradient(180deg,#7a5232 0 12.5%,#5e3e24 12.5% 25%);padding:10%;box-sizing:border-box}
.f div{width:100%;height:100%;border-radius:14px;background-size:33.333% 33.333%;background-repeat:repeat}</style></head><body>
<header><h1>Every crop as a field</h1><p>Each crop at its five stages, as a bed of three by three tiles on soil. ${ALL.length} crops.</p></header><main>
<div></div>${names.map((n) => `<div class="h">${n}</div>`).join('')}
${ALL.map((c) => `<div class="n">${c.replace(/-/g, ' ')}</div>` + STAGES.map((st) => `<div class="f"><div style="background-image:url(../art/tiles/crop-${c}-${st}.svg)"></div></div>`).join('')).join('\n')}
</main></body></html>`)
console.log(Object.keys(C).length + ' crops painted, sheet written')

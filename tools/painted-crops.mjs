// Crops painted for the game's fields, one tile each, so neighbouring tiles join into a field as in the reference:
// plants stand in the soil's two furrow ridges (a quarter and three quarters down the tile) and repeat across it.
// No outlines, light from the upper left. Tomatoes, wheat, zucchini and Buddha's hand so far.
//   tiles/crop-<crop>-<stage>.svg for the growing stages 2-sown .. 6-harvest
// Run from the Cute Fox folder: node tools/painted-crops.mjs, then web/scripts/import-art.mjs
import { writeFileSync } from 'node:fs'

const f = (n) => +n.toFixed(1)
let seed = 1
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647 }
const mix = (a, b, t) => { const p = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)), A = p(a), B = p(b); return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * Math.max(0, Math.min(1, t))).toString(16).padStart(2, '0')).join('') }
const LA = -2.3, toward = (a) => .5 + .5 * Math.cos(a - LA)
const STAGES = ['2-sown', '3-first-growth', '4-second-growth', '5-third-growth', '6-harvest']
const ROWS = [25, 75]
const SOFT = `<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.2"/></filter>`
const svg = (label, defs, body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" role="img" aria-label="${label}"><defs>${SOFT}${defs}</defs>${body}</svg>\n`
// a field tile that repeats without a seam: its content drawn again one tile to every side
const field = (body) => `<g id="c">${body}</g>` + [[-100, 0], [100, 0], [0, -100], [0, 100], [-100, -100], [100, -100], [-100, 100], [100, 100]].map(([x, y]) => `<use href="#c" x="${x}" y="${y}"/>`).join('')
// a leaf: a pointed oval turned toward a, lit by which way it faces
const leaf = (x, y, a, l, w, dark, light) => { const tx = x + Math.cos(a) * l, ty = y + Math.sin(a) * l, nx = -Math.sin(a) * w, ny = Math.cos(a) * w
  return `<path d="M${f(x)} ${f(y)}Q${f((x + tx) / 2 + nx)} ${f((y + ty) / 2 + ny)} ${f(tx)} ${f(ty)}Q${f((x + tx) / 2 - nx)} ${f((y + ty) / 2 - ny)} ${f(x)} ${f(y)}Z" fill="${mix(dark, light, toward(a) * .85 + (rnd() - .5) * .2)}"/>` }
const sprout = (x, y, s) => [-2.2, -.9].map((a) => leaf(x, y, a + (rnd() - .5) * .4, 5 * s, 2 * s, '#4E7A30', '#A8CC6A')).join('') + `<circle cx="${f(x)}" cy="${f(y)}" r="${f(1 * s)}" fill="#3E5A24"/>`
const holes = (xs) => ROWS.map((y) => xs.map((x) => `<ellipse cx="${f(x + (rnd() - .5) * 3)}" cy="${f(y + 1)}" rx="3.2" ry="2" fill="#3A2614" opacity=".55"/><ellipse cx="${f(x - .5)}" cy="${f(y)}" rx="1.4" ry="1" fill="#E8D8A8" opacity=".8"/>`).join('')).join('')

// ---------- tomatoes: two bushy plants a row, flowering, then hung with fruit ----------
function tomato(stage) {
  seed = 31 + stage
  const xs = [25, 75], P = []
  if (stage === 0) return holes(xs)
  if (stage === 1) return ROWS.map((y) => xs.map((x) => sprout(x, y, 1)).join('')).join('')
  const R = [0, 0, 14, 21, 25][stage]
  for (const y of ROWS) for (const x0 of xs) {
    const x = x0 + (rnd() - .5) * 3
    P.push(`<ellipse cx="${f(x + R * .25)}" cy="${f(y + R * .35)}" rx="${f(R * .95)}" ry="${f(R * .75)}" fill="#1A1408" opacity=".35" filter="url(#soft)"/>`)
    for (let k = 0; k < 9 + stage * 3; k++) { const a = rnd() * Math.PI * 2, d = rnd() * R * .35; P.push(leaf(x + Math.cos(a) * d, y + Math.sin(a) * d, a, R * (.55 + rnd() * .35), R * .22, '#2E4A1E', '#8EB45A')) }
    for (let k = 0; k < 6; k++) { const a = rnd() * Math.PI * 2, d = rnd() * R * .5; P.push(leaf(x + Math.cos(a) * d, y + Math.sin(a) * d, a, R * .4, R * .15, '#3E5E26', '#B4D07A')) }
    if (stage >= 3) for (let k = 0; k < (stage === 3 ? 4 : 7); k++) {
      const a = rnd() * Math.PI * 2, d = R * (.2 + rnd() * .5), fx = x + Math.cos(a) * d, fy = y + Math.sin(a) * d, r = stage === 3 ? 2 : 2.8 + rnd() * .8
      const c = stage === 3 ? (k % 2 ? '#F0D060' : '#8EB04A') : (k % 3 === 2 ? '#E87838' : '#D8342A')
      P.push(`<circle cx="${f(fx + .6)}" cy="${f(fy + .8)}" r="${f(r)}" fill="#1A1408" opacity=".3"/><circle cx="${f(fx)}" cy="${f(fy)}" r="${f(r)}" fill="${c}"/><circle cx="${f(fx - r * .35)}" cy="${f(fy - r * .35)}" r="${f(r * .35)}" fill="#FFFFFF" opacity=".55"/>`)
    }
  }
  return P.join('')
}

// ---------- wheat: rows of shoots that close into a standing field, green then gold ----------
function wheat(stage) {
  seed = 51 + stage
  const P = []
  if (stage === 0) return holes([12.5, 37.5, 62.5, 87.5])
  if (stage === 1) return ROWS.map((y) => [12.5, 37.5, 62.5, 87.5].map((x) => sprout(x, y, .8)).join('')).join('')
  const ripe = [0, 0, 0, .25, 1][stage], tall = [0, 0, 8, 12, 14][stage]
  const stalkDark = mix('#3E6024', '#9A7428', ripe), stalkLight = mix('#9CC064', '#F2D888', ripe)
  if (stage === 4) P.push(`<rect width="100" height="100" fill="#94702E"/>`)                     // ripe: the field closes over the soil
  else if (stage === 3) P.push(...ROWS.map((y) => `<rect x="0" y="${y - 14}" width="100" height="26" fill="#4E6A2C" opacity=".75" filter="url(#soft)"/>`))
  // stalks: a dense band along each row (the whole tile once ripe), leaning a little in the wind, lit tips
  const n = [0, 0, 60, 110, 380][stage]
  for (let k = 0; k < n; k++) {
    const x = rnd() * 100, y = stage === 4 ? rnd() * 106 - 3 : ROWS[k % 2] + (rnd() - .5) * [0, 0, 10, 18][stage], t = -Math.PI / 2 - .35 + (rnd() - .5) * .5, l = tall * (.7 + rnd() * .5)
    const tx = x + Math.cos(t) * l, ty = y + Math.sin(t) * l
    P.push(`<path d="M${f(x)} ${f(y)}L${f(tx)} ${f(ty)}" stroke="${mix(stalkDark, stalkLight, rnd() * .6 + .2)}" stroke-width="${stage === 4 ? 1.3 : 1.5}" stroke-linecap="round"/>`)
    if (stage >= 3) { const c = mix(mix('#7EA048', '#E8C060', ripe), '#FFF2B8', rnd() * .45 * ripe + .1)
      P.push(`<ellipse cx="${f(tx)}" cy="${f(ty)}" rx="1.6" ry="3.6" transform="rotate(${f(t * 57.3 + 90)} ${f(tx)} ${f(ty)})" fill="${c}"/>`) }
  }
  // light and shade over the whole patch, so it reads as a soft mass
  // (no light across the tile: it would repeat tile by tile and show the seams)
  return P.join('')
}
// ---------- zucchini: a field of broad lobed leaves in rows, big orange blossoms, then striped fruit ----------
// a broad leaf: three rounded lobes toward a, pale veins
const bigLeaf = (x, y, a, l, dark, light) => {
  const c = mix(dark, light, toward(a) * .8 + (rnd() - .5) * .2), o = []
  for (const [da, k, rr] of [[0, .62, .42], [-.55, .48, .32], [.55, .48, .32]]) { const b = a + da, cx = x + Math.cos(b) * l * k, cy = y + Math.sin(b) * l * k
    o.push(`<ellipse cx="${f(cx + 1.6)}" cy="${f(cy + 2)}" rx="${f(l * rr)}" ry="${f(l * rr * .86)}" fill="#142410" opacity=".35"/>`, `<ellipse cx="${f(cx)}" cy="${f(cy)}" rx="${f(l * rr)}" ry="${f(l * rr * .86)}" fill="${c}"/>`) }
  o.push(`<ellipse cx="${f(x + Math.cos(a) * l * .5 - 1)}" cy="${f(y + Math.sin(a) * l * .5 - 1)}" rx="${f(l * .22)}" ry="${f(l * .14)}" fill="#FFFFFF" opacity=".12"/>`)
  for (const da of [0, -.5, .5]) o.push(`<path d="M${f(x)} ${f(y)}L${f(x + Math.cos(a + da) * l * .8)} ${f(y + Math.sin(a + da) * l * .8)}" stroke="${mix(c, '#E8F0C8', .45)}" stroke-width=".8" opacity=".8"/>`)
  return o.join('')
}
const blossom = (x, y, r, col) => { const o = []; for (let j = 0; j < 5; j++) { const b = j / 5 * Math.PI * 2 + rnd(); o.push(`<ellipse cx="${f(x + Math.cos(b) * r * .55)}" cy="${f(y + Math.sin(b) * r * .55)}" rx="${f(r * .55)}" ry="${f(r * .38)}" transform="rotate(${f(b * 57.3)} ${f(x + Math.cos(b) * r * .55)} ${f(y + Math.sin(b) * r * .55)})" fill="${mix(col, '#8A4A10', (1 - toward(b)) * .35)}"/>`) }
  return o.join('') + `<circle cx="${f(x)}" cy="${f(y)}" r="${f(r * .28)}" fill="#C86A10"/>` }
function zucchini(stage) {
  seed = 71 + stage
  const P = []
  if (stage === 0) return holes([25, 75])
  if (stage === 1) return ROWS.map((yy) => [25, 75].map((xx) => sprout(xx, yy, 1.2)).join('')).join('')
  // a field in rows: each row a band of overlapping broad leaves that widens until, ripe, the rows close over the soil
  const half = [0, 0, 11, 17, 21][stage], L = [0, 0, 11, 15, 17][stage]                  // ripe, the rows almost touch: a dark line of shade between them
  for (const y of ROWS) P.push(`<rect x="0" y="${y - half * .8}" width="100" height="${f(half * 1.6)}" fill="#1E3214" opacity=".55" filter="url(#soft)"/>`)
  for (const y of ROWS) for (let x = -6; x < 106; x += 9 + rnd() * 5) {
    const yy = y + (rnd() - .5) * half * 1.2, ang = rnd() * Math.PI * 2
    P.push(bigLeaf(x, yy, ang, L * (.75 + rnd() * .35), '#2A4A1C', '#8EB45A'))
  }
  if (stage === 4) for (let k = 0; k < 4; k++) {                       // ripe fruit lying among the leaves
    const ang = rnd() * Math.PI, x0 = 12 + k * 24 + (rnd() - .5) * 6, y0 = ROWS[k % 2] + (rnd() - .5) * 18, l = 15, x1 = x0 + Math.cos(ang) * l, y1 = y0 + Math.sin(ang) * l * .5
    P.push(`<path d="M${f(x0 + 1.5)} ${f(y0 + 2.5)}L${f(x1 + 1.5)} ${f(y1 + 2.5)}" stroke="#101C0A" stroke-width="9" stroke-linecap="round" opacity=".45"/>`, `<path d="M${f(x0)} ${f(y0)}L${f(x1)} ${f(y1)}" stroke="#2E5420" stroke-width="8" stroke-linecap="round"/>`, `<path d="M${f(x0)} ${f(y0)}L${f(x1)} ${f(y1)}" stroke="#4E7E34" stroke-width="5" stroke-linecap="round" stroke-dasharray="3.5 2.5"/>`, `<path d="M${f(x0 - .8)} ${f(y0 - 2)}L${f(x1 - .8)} ${f(y1 - 2)}" stroke="#B0D08A" stroke-width="1.5" stroke-linecap="round" opacity=".7"/>`, `<circle cx="${f(x1)}" cy="${f(y1)}" r="2.4" fill="#F0B030"/>`)
  }
  if (stage >= 3) for (let k = 0; k < (stage === 3 ? 6 : 3); k++) P.push(blossom(8 + k * (stage === 3 ? 17 : 33) + rnd() * 8, ROWS[k % 2] + (rnd() - .5) * half, 5.5, '#F4A830'))
  return P.join('')
}

// ---------- Buddha's hand: rows of glossy citrus shrubs, white blossom, then yellow fingered fruit ----------
const handFruit = (x, y, a, s) => { const o = [`<ellipse cx="${f(x + 1)}" cy="${f(y + 1.5)}" rx="${f(5 * s)}" ry="${f(4 * s)}" fill="#1A1408" opacity=".3"/>`]
  for (let j = -3; j <= 3; j++) { const b = a + j * .26, l = (8 - Math.abs(j)) * s, fx = x + Math.cos(b) * l * .55, fy = y + Math.sin(b) * l * .55
    o.push(`<ellipse cx="${f(fx)}" cy="${f(fy)}" rx="${f(l * .55)}" ry="${f(1.5 * s)}" transform="rotate(${f(b * 57.3)} ${f(fx)} ${f(fy)})" fill="${mix('#C88A18', '#FFE070', toward(b) * .7 + .2)}"/>`) }
  return o.join('') + `<circle cx="${f(x)}" cy="${f(y)}" r="${f(3.4 * s)}" fill="#E8B030"/><circle cx="${f(x - s)}" cy="${f(y - s)}" r="${f(1.4 * s)}" fill="#FFF4B0" opacity=".7"/>` }
function buddha(stage) {
  seed = 91 + stage
  const P = []
  if (stage === 0) return holes([12.5, 37.5, 62.5, 87.5])
  if (stage === 1) return ROWS.map((y) => [12.5, 37.5, 62.5, 87.5].map((x) => sprout(x, y, .9)).join('')).join('')
  // a citrus orchard in rows: glossy dark shrubs along each row that grow into hedges and, ripe, close into one canopy
  const half = [0, 0, 10, 16, 20][stage], ll = [0, 0, 5, 6, 7][stage]
  for (const y of ROWS) P.push(`<rect x="0" y="${y - half * .8}" width="100" height="${f(half * 1.6)}" fill="#14260F" opacity=".6" filter="url(#soft)"/>`)
  for (const y of ROWS) for (let k = 0; k < [0, 0, 70, 120, 210][stage]; k++) {
    const x = rnd() * 112 - 6, yy = y + (rnd() - .5) * half * 1.7, ang = rnd() * Math.PI * 2
    P.push(leaf(x, yy, ang, ll * (.8 + rnd() * .5), ll * .38, '#1E3A1A', '#7AA458'))
  }
  for (let k = 0; k < 30; k++) { const x = rnd() * 100, y = ROWS[k % 2] + (rnd() - .5) * half * 1.4
    P.push(`<ellipse cx="${f(x)}" cy="${f(y)}" rx="1.5" ry=".8" fill="#E8F4D0" opacity=".55"/>`) }   // glossy glints
  if (stage === 3) for (let k = 0; k < 16; k++) P.push(blossom(rnd() * 100, ROWS[k % 2] + (rnd() - .5) * half * 1.3, 2.4, '#FAF6EC'))
  if (stage === 4) for (let k = 0; k < 8; k++) P.push(handFruit(rnd() * 100, ROWS[k % 2] + (rnd() - .5) * 26, rnd() * Math.PI * 2, .9 + rnd() * .4))
  return P.join('')
}

const RIPE = `<linearGradient id="ripe" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFF4C8" stop-opacity=".18"/><stop offset="1" stop-color="#3A2A08" stop-opacity=".18"/></linearGradient>`

STAGES.forEach((st, i) => {
  writeFileSync(`tiles/crop-tomatoes-${st}.svg`, svg(`Tomatoes, ${st.slice(2).replace('-', ' ')}`, '', field(tomato(i))))
  writeFileSync(`tiles/crop-wheat-${st}.svg`, svg(`Wheat, ${st.slice(2).replace('-', ' ')}`, RIPE, field(wheat(i))))
  writeFileSync(`tiles/crop-zucchini-${st}.svg`, svg(`Zucchini, ${st.slice(2).replace('-', ' ')}`, '', field(zucchini(i))))
  writeFileSync(`tiles/crop-buddhas-hand-${st}.svg`, svg(`Buddha's hand, ${st.slice(2).replace('-', ' ')}`, '', field(buddha(i))))
})
console.log('tomatoes, wheat, zucchini and buddhas-hand painted')

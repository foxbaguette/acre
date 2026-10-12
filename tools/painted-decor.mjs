// The small things on the island, painted to match the trees and buildings: bushes, stones, a stump, flowers, meadow
// carpets, lilies, reeds, driftwood, and the fence (a post, and the rails the game stretches between posts).
// No outlines: rounded forms in soft gradients, lit from the upper left, with soft shadows to the lower right.
// Overwrites tiles/decor-*.svg and tiles/fence-0000.svg / fence-0101.svg (the two the game draws).
// Run from the Cute Fox folder: node tools/painted-decor.mjs, then web/scripts/import-art.mjs
import { writeFileSync } from 'node:fs'

const f = (n) => +n.toFixed(1)
let seed = 1
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647 }
const mix = (a, b, t) => { const p = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)), A = p(a), B = p(b); return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * Math.max(0, Math.min(1, t))).toString(16).padStart(2, '0')).join('') }
const LA = -2.3, toward = (a) => .5 + .5 * Math.cos(a - LA)                // how much a direction faces the light

// a smooth, slightly irregular round shape
const blob = (cx, cy, rx, ry = rx, wob = .12, n = 9) => {
  const pts = [...Array(n)].map((_, k) => { const a = k / n * Math.PI * 2, r = 1 + (rnd() - .5) * 2 * wob; return [cx + Math.cos(a) * rx * r, cy + Math.sin(a) * ry * r] })
  const mid = (a, b) => [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]
  let d = `M${f(mid(pts[n - 1], pts[0])[0])} ${f(mid(pts[n - 1], pts[0])[1])}`
  for (let k = 0; k < n; k++) { const m = mid(pts[k], pts[(k + 1) % n]); d += `Q${f(pts[k][0])} ${f(pts[k][1])} ${f(m[0])} ${f(m[1])}` }
  return d + 'Z'
}
let gid = 0
// a radial gradient lit from the upper left: light, the colour itself, shade
const dome = (defs, light, base, dark) => { const id = 'g' + ++gid; defs.push(`<radialGradient id="${id}" cx=".5" cy=".5" r=".62" fx=".3" fy=".26"><stop offset="0" stop-color="${light}"/><stop offset=".45" stop-color="${base}"/><stop offset="1" stop-color="${dark}"/></radialGradient>`); return `url(#${id})` }
const SOFT = `<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.4"/></filter>`
const shadow = (cx, cy, rx, ry, o = .32) => `<ellipse cx="${f(cx + rx * .22)}" cy="${f(cy + ry * .3)}" rx="${f(rx)}" ry="${f(ry * .85)}" fill="#0B0E07" opacity="${o}" filter="url(#soft)"/>`
const file = (name, label, build) => { gid = 0; const defs = [SOFT], body = build(defs); writeFileSync(`tiles/${name}.svg`, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" role="img" aria-label="${label}"><defs>${defs.join('')}</defs>${body}</svg>\n`) }

// leaves: little lit and shaded dabs over a rounded form
const leaves = (cx, cy, r, n, dark, light, size = 2.6) => [...Array(n)].map(() => {
  const a = rnd() * Math.PI * 2, d = Math.sqrt(rnd()) * r * .92, x = cx + Math.cos(a) * d, y = cy + Math.sin(a) * d
  const lit = toward(Math.atan2(y - cy, x - cx)) * (d / r) + (1 - d / r) * .55
  return `<ellipse cx="${f(x)}" cy="${f(y)}" rx="${f(size * (.7 + rnd() * .6))}" ry="${f(size * .6)}" transform="rotate(${f(rnd() * 180)} ${f(x)} ${f(y)})" fill="${mix(dark, light, lit + (rnd() - .5) * .3)}" opacity=".9"/>`
}).join('')

function bush(defs, blossom) {
  const P = [], cx = 50, cy = 52
  const lumps = [[0, 0, 15], [-11, -5, 11], [10, -7, 11], [-8, 9, 10], [11, 7, 10]].map(([dx, dy, r]) => [cx + dx + (rnd() - .5) * 3, cy + dy + (rnd() - .5) * 3, r * (.9 + rnd() * .2)])
  P.push(shadow(cx + 3, cy + 3, 25, 20, .34))
  P.push(`<path d="${blob(cx, cy, 24, 21, .1)}" fill="#2C4220"/>`)
  for (const [x, y, r] of lumps.sort((a, b) => b[2] - a[2]).reverse()) P.push(`<path d="${blob(x, y, r, r, .14)}" fill="${dome(defs, '#A8BE6A', '#5E7E38', '#2C4220')}"/>`)
  P.push(leaves(cx, cy, 22, 70, '#3A5428', '#B4C878'))
  if (blossom) for (let k = 0; k < 9; k++) { const a = rnd() * Math.PI * 2, d = Math.sqrt(rnd()) * 18, x = cx + Math.cos(a) * d, y = cy + Math.sin(a) * d, c = rnd() > .4 ? '#EDB4CA' : '#F2E2A0'
    P.push(`<circle cx="${f(x)}" cy="${f(y)}" r="2.2" fill="${c}"/><circle cx="${f(x - .6)}" cy="${f(y - .6)}" r=".9" fill="#FFFFFF" opacity=".7"/>`) }
  return P.join('')
}
function stone(defs, two) {
  const P = []
  const one = (cx, cy, rx, ry) => {
    P.push(shadow(cx + 2, cy + 2, rx * 1.1, ry * 1.05, .36))
    P.push(`<path d="${blob(cx, cy, rx, ry, .1, 8)}" fill="${dome(defs, '#DAD6CC', '#A39E94', '#5E5A54')}"/>`)
    P.push(`<path d="M${f(cx - rx * .2)} ${f(cy - ry * .5)}q${f(rx * .15)} ${f(ry * .35)} ${f(rx * .05)} ${f(ry * .7)}" stroke="#5E5A54" stroke-width="1" fill="none" opacity=".45"/>`)
    P.push(`<ellipse cx="${f(cx + rx * .35)}" cy="${f(cy + ry * .45)}" rx="${f(rx * .4)}" ry="${f(ry * .25)}" fill="#6E8A3A" opacity=".55" filter="url(#soft)"/>`)
  }
  if (two) { one(42, 48, 13, 11); one(60, 60, 8, 7) } else one(50, 54, 13, 10)
  return P.join('')
}
function stump(defs) {
  const P = [], cx = 50, cy = 50, r = 12, h = 6
  P.push(shadow(cx + 3, cy + 5, 17, 13, .34))
  for (const [a, l] of [[.6, 12], [2.3, 10], [3.9, 11], [5.3, 9]]) P.push(`<path d="M${f(cx + Math.cos(a) * r * .7)} ${f(cy + h + Math.sin(a) * r * .55)}q${f(Math.cos(a) * l * .6)} ${f(Math.sin(a) * l * .3 + 2)} ${f(Math.cos(a) * l)} ${f(Math.sin(a) * l * .6 + 2)}" stroke="#5A4028" stroke-width="3.2" stroke-linecap="round" fill="none"/>`)   // roots
  P.push(`<path d="M${cx - r} ${cy}L${cx - r} ${cy + h}A${r} ${r * .8} 0 0 0 ${cx + r} ${cy + h}L${cx + r} ${cy}Z" fill="${dome(defs, '#9A7652', '#6E5034', '#3E2C1C')}"/>`)            // the bark below the cut
  P.push(`<ellipse cx="${cx}" cy="${cy}" rx="${r}" ry="${r * .8}" fill="#C9A47A"/>`)
  for (let k = 1; k < 5; k++) P.push(`<ellipse cx="${cx + .5}" cy="${cy + .3}" rx="${f(r * k / 5)}" ry="${f(r * .8 * k / 5)}" fill="none" stroke="#9A7650" stroke-width=".8" opacity=".7"/>`)
  P.push(`<ellipse cx="${cx - 4}" cy="${cy - 3}" rx="5" ry="3" fill="#FFF0D0" opacity=".25"/>`, `<ellipse cx="${cx + 7}" cy="${cy + 6}" rx="5" ry="3" fill="#6E8A3A" opacity=".7"/>`)
  return P.join('')
}
function flowers(defs, cols) {
  const P = [], cx = 50, cy = 52
  P.push(shadow(cx + 2, cy + 2, 16, 13, .22))
  for (let k = 0; k < 14; k++) { const a = rnd() * Math.PI * 2, d = 4 + rnd() * 10, x = cx + Math.cos(a) * d, y = cy + Math.sin(a) * d
    P.push(`<ellipse cx="${f(x)}" cy="${f(y)}" rx="6" ry="2.6" transform="rotate(${f(a * 57.3)} ${f(x)} ${f(y)})" fill="${mix('#3A5428', '#8EAE5E', toward(a) * .8 + rnd() * .2)}"/>`) }
  for (let k = 0; k < 7; k++) { const a = rnd() * Math.PI * 2, d = Math.sqrt(rnd()) * 12, x = cx + Math.cos(a) * d, y = cy + Math.sin(a) * d, c = cols[k % cols.length]
    for (let j = 0; j < 5; j++) { const b = j / 5 * Math.PI * 2 + k; P.push(`<circle cx="${f(x + Math.cos(b) * 2.3)}" cy="${f(y + Math.sin(b) * 2.3)}" r="1.9" fill="${mix(c, '#3A3020', toward(b) < .3 ? .15 : 0)}"/>`) }
    P.push(`<circle cx="${f(x)}" cy="${f(y)}" r="1.4" fill="#E8B048"/>`) }
  return P.join('')
}
// a carpet of meadow flowers or grass, thinning out toward its edge
function meadow(defs, kind) {
  const P = [], C = 50, R = 46
  const at = () => { const a = rnd() * Math.PI * 2, d = R * Math.pow(rnd(), .7); return [C + Math.cos(a) * d, C + Math.sin(a) * d, d / R] }
  for (let k = 0; k < 26; k++) { const [x, y] = at(), t = rnd() * Math.PI   // grass tufts beneath
    for (let j = -1; j <= 1; j++) P.push(`<path d="M${f(x)} ${f(y)}l${f(Math.cos(t + j * .5) * 4)} ${f(-3 - rnd() * 2)}" stroke="${mix('#4E6E2E', '#9AB660', rnd())}" stroke-width="1.1" stroke-linecap="round"/>`) }
  if (kind === 'tall') {
    for (let k = 0; k < 34; k++) { const [x, y] = at(); for (let j = 0; j < 5; j++) { const t = -Math.PI / 2 + (j - 2) * .32 + (rnd() - .5) * .2, l = 6 + rnd() * 5
      P.push(`<path d="M${f(x)} ${f(y)}q${f(Math.cos(t) * l * .5)} ${f(Math.sin(t) * l * .5)} ${f(Math.cos(t) * l + 1.5)} ${f(Math.sin(t) * l)}" stroke="${mix('#3E5A24', '#C8D088', j / 4 * .6 + rnd() * .4)}" stroke-width="1.2" stroke-linecap="round" fill="none"/>`) } }
    return P.join('')
  }
  if (kind === 'clover') for (let k = 0; k < 30; k++) { const [x, y] = at(); for (let j = 0; j < 3; j++) { const b = j * 2.1 + k; P.push(`<circle cx="${f(x + Math.cos(b) * 1.6)}" cy="${f(y + Math.sin(b) * 1.6)}" r="1.7" fill="${mix('#4E7A30', '#9CC064', toward(b))}"/>`) } }
  const cols = { yellow: ['#F0D060', '#E8B848', '#FFF0A0'], white: ['#FAF6EC', '#EEE8DA', '#F6F0C8'], purple: ['#B88ED0', '#D8A8E0', '#9E7AC0'], clover: ['#F4F0F0', '#E8B0C8'] }[kind]
  for (let k = 0; k < 40; k++) { const [x, y, d] = at(), c = cols[k % cols.length], r = 1.3 + rnd() * .9
    P.push(`<circle cx="${f(x + .6)}" cy="${f(y + .8)}" r="${f(r)}" fill="#1E2A10" opacity=".25"/><circle cx="${f(x)}" cy="${f(y)}" r="${f(r)}" fill="${c}" opacity="${f(1 - d * .3)}"/><circle cx="${f(x - r * .3)}" cy="${f(y - r * .3)}" r="${f(r * .4)}" fill="#FFFFFF" opacity=".5"/>`) }
  return P.join('')
}
function lily(defs) {
  const P = []
  for (const [x, y, r] of [[44, 46, 13], [62, 58, 9], [40, 64, 7]]) { const a = rnd() * Math.PI * 2
    P.push(`<path d="M${x} ${y}L${f(x + Math.cos(a - .25) * r)} ${f(y + Math.sin(a - .25) * r)}A${r} ${r} 0 1 1 ${f(x + Math.cos(a + .25) * r)} ${f(y + Math.sin(a + .25) * r)}Z" fill="${dome(defs, '#B8D088', '#6E9A48', '#3E6228')}"/>`) }
  for (let j = 0; j < 8; j++) { const b = j / 8 * Math.PI * 2; P.push(`<ellipse cx="${f(46 + Math.cos(b) * 3.4)}" cy="${f(44 + Math.sin(b) * 3.4)}" rx="3.4" ry="1.8" transform="rotate(${f(b * 57.3)} ${f(46 + Math.cos(b) * 3.4)} ${f(44 + Math.sin(b) * 3.4)})" fill="${mix('#F4C4D4', '#C87894', 1 - toward(b))}"/>`) }
  P.push(`<circle cx="46" cy="44" r="1.8" fill="#F0D060"/>`)
  return P.join('')
}
function reeds(defs, heads) {
  const P = [], cx = 50, cy = 56
  P.push(shadow(cx + 2, cy, 12, 8, .2))
  for (let k = 0; k < 16; k++) { const t = -Math.PI / 2 + (rnd() - .5) * 1.5, l = 14 + rnd() * 12, x = cx + (rnd() - .5) * 10
    P.push(`<path d="M${f(x)} ${cy}q${f(Math.cos(t) * l * .4)} ${f(Math.sin(t) * l * .5)} ${f(Math.cos(t) * l)} ${f(Math.sin(t) * l)}" stroke="${mix('#3E5A28', '#A8C070', rnd())}" stroke-width="1.6" stroke-linecap="round" fill="none"/>`)
    if (heads && k % 4 === 0) P.push(`<ellipse cx="${f(x + Math.cos(t) * l * .8)}" cy="${f(cy + Math.sin(t) * l * .8)}" rx="1.8" ry="4" transform="rotate(${f(t * 57.3 + 90)} ${f(x + Math.cos(t) * l * .8)} ${f(cy + Math.sin(t) * l * .8)})" fill="#6E4A2A"/>`) }
  return P.join('')
}
function driftwood(defs) {
  const P = [`<path d="M28 58Q50 50 72 46" stroke="#0B0E07" stroke-width="8" stroke-linecap="round" opacity=".25" filter="url(#soft)" fill="none" transform="translate(3 4)"/>`]
  P.push(`<path d="M28 58Q50 50 72 46" stroke="#9A8C74" stroke-width="7" stroke-linecap="round" fill="none"/>`, `<path d="M28 56.5Q50 48.5 72 44.5" stroke="#D8D0C0" stroke-width="2.5" stroke-linecap="round" fill="none" opacity=".8"/>`, `<path d="M50 51q6 -6 12 -12" stroke="#A89A80" stroke-width="3.5" stroke-linecap="round" fill="none"/>`)
  return P.join('')
}

seed = 3; file('decor-bush-1', 'Decoration bush-1', (d) => bush(d, false))
seed = 9; file('decor-bush-2', 'Decoration bush-2', (d) => bush(d, true))
seed = 5; file('decor-stone-1', 'Decoration stone-1', (d) => stone(d, false))
seed = 8; file('decor-stone-2', 'Decoration stone-2', (d) => stone(d, true))
seed = 4; file('decor-stump', 'Decoration stump', stump)
seed = 6; file('decor-flowers-1', 'Decoration flowers-1', (d) => flowers(d, ['#E8A050', '#F0D060', '#E8A050']))
seed = 7; file('decor-flowers-2', 'Decoration flowers-2', (d) => flowers(d, ['#EDB4CA', '#FAF6EC', '#E890B0']))
// four versions of each meadow kind, so neighbouring patches differ (the game picks one per spot, and turns it)
for (const k of ['yellow', 'white', 'purple', 'tall', 'clover']) for (let v = 1; v <= 4; v++) { seed = 20 + k.length * 7 + v * 131; file(`decor-meadow-${k}-${v}`, 'Decoration meadow-' + k, (d) => meadow(d, k)) }
seed = 11; file('decor-lily', 'Decoration lily', lily)
seed = 12; file('decor-reeds-1', 'Decoration reeds-1', (d) => reeds(d, true))
seed = 13; file('decor-reeds-2', 'Decoration reeds-2', (d) => reeds(d, false))
seed = 14; file('decor-driftwood', 'Decoration driftwood', driftwood)

// the fence: weathered grey-brown wood, rounded by its light. The post keeps the old one's place on the tile; the rails
// fill the left 43% of fence-0101, which the game stretches from post to post.
const wood = (defs, id, vertical) => { defs.push(`<linearGradient id="${id}" x1="0" y1="0" x2="${vertical ? 1 : 0}" y2="${vertical ? 0 : 1}"><stop offset="0" stop-color="#B8A88A"/><stop offset=".4" stop-color="#8E7C62"/><stop offset="1" stop-color="#5A4C3A"/></linearGradient>`); return `url(#${id})` }
const post = (defs) => `<ellipse cx="62" cy="67" rx="9" ry="4" fill="#0B0E07" opacity=".3" filter="url(#soft)"/><rect x="43.5" y="40" width="13" height="25" rx="2" fill="${wood(defs, 'pw', true)}"/><path d="M47 44v18M52 42v20" stroke="#5A4C3A" stroke-width=".7" opacity=".5"/><ellipse cx="50" cy="40" rx="6.5" ry="4" fill="#C2B496"/><ellipse cx="50" cy="40" rx="3.6" ry="2.2" fill="none" stroke="#9A8A6E" stroke-width=".7"/>`
const rails = (defs) => { const g = wood(defs, 'rw', false); return [44, 54].map((y) => `<rect x="0" y="${y + 9}" width="43" height="5" fill="#0B0E07" opacity=".22" filter="url(#soft)"/><rect x="0" y="${y}" width="43" height="6" fill="${g}"/><path d="M0 ${y + 2.4}H43" stroke="#6A5A44" stroke-width=".6" opacity=".5"/>`).join('') }
gid = 0
{ const defs = [SOFT]; const b = post(defs); writeFileSync('tiles/fence-0000.svg', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" role="img" aria-label="Fence tile, connected"><defs>${defs.join('')}</defs>${b}</svg>\n`) }
{ const defs = [SOFT]; const b = rails(defs) + `<g transform="translate(57 0)">${rails([])}</g>`.replace(/url\(#rw\)/g, 'url(#rw)') + post(defs); writeFileSync('tiles/fence-0101.svg', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" role="img" aria-label="Fence tile, connected east west"><defs>${defs.join('')}</defs>${b}</svg>\n`) }
console.log('decor and fence painted')

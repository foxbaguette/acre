// Draws the buildings into tiles/: flat low-poly facets in the style of the trees and bushes (no outlines, light from
// the upper left, a soft shadow to the lower right, seen from above and a little from the front). 100 units a tile.
//   building-farmhouse-1..5  3 x 4 tiles: the farmhouse at each stage (1 to 5 farmers), from a thatched cottage to a
//                            big tiled house with dormers, a porch and a garden
//   building-lab.svg         4 x 4 tiles: a research lab with an observatory dome and a greenhouse wing
//   building-nest.svg        2 x 2 tiles: a straw nest for hatching eggs
// Run from the Cute Fox folder: node tools/buildings.mjs
import { writeFileSync } from 'node:fs'

const f1 = (n) => +n.toFixed(1)
const pts = (p) => p.map(([x, y]) => `${f1(x)} ${f1(y)}`).join(' ')
const poly = (cls, p) => `<path class="${cls}" d="M${pts(p).replace(/ (?=-?\d+(\.\d+)? -?\d)/g, (m, i, o, s) => m)}"/>`
const path = (cls, list) => `<path class="${cls}" d="${list.map((p) => 'M' + p.map(([x, y]) => `${f1(x)} ${f1(y)}`).join('L') + 'z').join('')}"/>`
const rect = (x0, y0, x1, y1) => [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]
const oval = (cx, cy, rx, ry, n, rot = 0, wob = 0, seed = 1) => {
  let s = seed; const rnd = () => { s = (s * 16807) % 2147483647; return s / 2147483647 }
  return Array.from({ length: n }, (_, k) => { const a = rot + (k / n) * Math.PI * 2, w = 1 + (rnd() - .5) * wob; return [cx + Math.cos(a) * rx * w, cy + Math.sin(a) * ry * w] })
}
const svg = (w, h, label, style, body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" role="img" aria-label="${label}"><style>${style}</style>${body.join('')}</svg>\n`

// ---------- the nest: 200 x 200 ----------
{
  const S = [], cx = 98, cy = 104
  S.push(path('h', [oval(cx + 10, cy + 12, 84, 70, 14, .2, .08, 3)]))
  // the outer ring of straw: facets round the rim, lit on the upper left
  const n = 18, ring = oval(cx, cy, 82, 70, n, 0, .1, 7), inner = oval(cx + 2, cy + 3, 52, 42, n, 0, .08, 11)
  for (let k = 0; k < n; k++) {
    const a = ring[k], b = ring[(k + 1) % n], c = inner[(k + 1) % n], d = inner[k]
    const ang = (k + .5) / n * Math.PI * 2, lit = Math.cos(ang - Math.PI * 1.25)   // facing the light from the upper left
    S.push(path(lit > .35 ? 'a' : lit > -.35 ? 'b' : 'c', [[a, b, c, d]]))
  }
  // straws lying across the rim
  let s = 5; const rnd = () => { s = (s * 16807) % 2147483647; return s / 2147483647 }
  for (let k = 0; k < 34; k++) {
    const ang = rnd() * Math.PI * 2, r = .72 + rnd() * .34, x = cx + Math.cos(ang) * 82 * r, y = cy + Math.sin(ang) * 70 * r
    const t = ang + Math.PI / 2 + (rnd() - .5) * 1.4, len = 14 + rnd() * 16, wd = 1.6 + rnd() * 1.2
    const dx = Math.cos(t) * len / 2, dy = Math.sin(t) * len / 2, nx = -Math.sin(t) * wd / 2, ny = Math.cos(t) * wd / 2
    const lit = Math.cos(ang - Math.PI * 1.25)
    S.push(path(lit > 0 ? 'e' : rnd() > .5 ? 'b' : 'a', [[[x - dx + nx, y - dy + ny], [x + dx + nx, y + dy + ny], [x + dx - nx, y + dy - ny], [x - dx - nx, y - dy - ny]]]))
  }
  // the hollow: deeper straw, darkest where the rim shades it
  S.push(path('i', [inner]), path('j', [oval(cx + 8, cy + 9, 40, 30, 12, .3, .1, 13)]))
  for (let k = 0; k < 12; k++) {
    const ang = rnd() * Math.PI * 2, r = rnd() * .7, x = cx + 2 + Math.cos(ang) * 46 * r, y = cy + 3 + Math.sin(ang) * 36 * r, t = rnd() * Math.PI
    const dx = Math.cos(t) * 9, dy = Math.sin(t) * 9, nx = -Math.sin(t) * 1.1, ny = Math.cos(t) * 1.1
    S.push(path('b', [[[x - dx + nx, y - dy + ny], [x + dx + nx, y + dy + ny], [x + dx - nx, y + dy - ny], [x - dx - nx, y - dy - ny]]]))
  }
  // three eggs, lit on the upper left, with a few speckles
  for (const [ex, ey, rot, kind] of [[82, 96, -.5, 0], [114, 102, .3, 1], [96, 122, .1, 0]]) {
    const o = oval(ex, ey, 15, 20, 14, rot), lit = oval(ex - 4, ey - 5, 9, 12, 10, rot)
    S.push(path('h', [oval(ex + 5, ey + 6, 15, 18, 12, rot)]))
    S.push(path(kind ? 'q2' : 'p2', [o]), path(kind ? 'q' : 'p', [lit]))
    S.push(path('m', [oval(ex + 5, ey - 2, 1.8, 1.6, 5), oval(ex - 2, ey + 8, 1.5, 1.3, 5), oval(ex + 7, ey + 9, 1.2, 1.1, 5), oval(ex - 6, ey - 9, 1.2, 1, 5)]))
  }
  // two stones by the nest
  S.push(path('h', [oval(30, 170, 12, 7, 8)]), path('o2', [oval(26, 164, 11, 8, 8, .2, .2, 17)]), path('o', [oval(23, 161, 6, 4, 7)]))
  S.push(path('h', [oval(178, 58, 9, 6, 8)]), path('o2', [oval(175, 53, 9, 7, 8, .5, .2, 19)]), path('o', [oval(172, 51, 5, 3.5, 7)]))
  writeFileSync('tiles/building-nest.svg', svg(200, 200, 'Straw hatching nest, two by two tiles',
    '.h{fill:#0B0E07;fill-opacity:.28}.a{fill:#E2C26A}.b{fill:#C9A24B}.c{fill:#A07E35}.e{fill:#F0D88E}.i{fill:#8C6B2C}.j{fill:#6F5222}' +
    '.p{fill:#FBF6EA}.p2{fill:#E3D6BC}.q{fill:#E6F0F2}.q2{fill:#B9CED6}.m{fill:#9A7A55}.o{fill:#B5AEA3}.o2{fill:#8B847A}', S))
}
console.log("farmhouse stages, lab and nest written")

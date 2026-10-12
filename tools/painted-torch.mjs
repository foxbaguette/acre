// The torch (1x1), painted: a wooden post with an iron basket; the game draws its flame live. The other buildings are
// rendered from 3D models: tools/render-buildings.mjs.
//   tiles/building-torch.svg, tiles/building-torch-lights.svg
// Run from the Cute Fox folder: node tools/painted-torch.mjs, then web/scripts/import-art.mjs
import { writeFileSync } from 'node:fs'

const f = (n) => +n.toFixed(1)
let seed = 1
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647 }
const mix = (a, b, t) => { const p = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)), A = p(a), B = p(b); return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * Math.max(0, Math.min(1, t))).toString(16).padStart(2, '0')).join('') }
const pd = (pts) => 'M' + pts.map(([x, y]) => `${f(x)} ${f(y)}`).join('L') + 'Z'
const poly = (pts, fill, extra = '') => `<path d="${pd(pts)}" fill="${fill}"${extra}/>`
const T = .32                                      // the farmhouse's tilt
const LA = -2.3                                    // the light comes from the upper left (angle in the picture)
const shadeAt = (a) => .5 + .5 * Math.cos(a - LA)  // 1 facing the light, 0 away from it

// merge into buildingArt.ts: where each building's lights fall on the ground (LIGHTS) and which have a -lights picture
const mergeLights = (lights) => { const AF = 'web/src/engine/buildingArt.ts', art = readFileSync(AF, 'utf8'), m = art.match(/LIGHTS: Record<string, number\[\]\[\]> = (\{.*\})/)
  writeFileSync(AF, art.replace(m[1], JSON.stringify({ ...JSON.parse(m[1]), ...lights })).replace(/LIT = new Set\((\[.*\])\)/, (_, l) => 'LIT = new Set(' + JSON.stringify([...new Set([...JSON.parse(l), ...Object.keys(lights)])]) + ')')) }
const DEFS = `<defs><filter id="soft" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="7"/></filter><filter id="glow" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="8"/></filter><filter id="paint" x="-5%" y="-5%" width="110%" height="110%"><feTurbulence type="fractalNoise" baseFrequency=".55" numOctaves="3" seed="7" result="n"/><feComposite in="SourceGraphic" in2="n" operator="arithmetic" k1=".45" k2=".8" k3="0" k4="0" result="t"/><feComposite in="t" in2="SourceGraphic" operator="in"/></filter><radialGradient id="lit"><stop offset="0" stop-color="#FFF1B8"/><stop offset="1" stop-color="#FFB64E"/></radialGradient><linearGradient id="litv" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF1B8"/><stop offset="1" stop-color="#FFB64E"/></linearGradient></defs>`
const svg = (w, h, label, body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" role="img" aria-label="${label}">${DEFS}${body}</svg>\n`

// ---------- the torch (1x1): a wooden post with an iron basket, a flame in it ----------
function torch() {
  const P = [], LI = [], x = 50, y = 62, top = 34
  P.push(`<ellipse cx="${x + 10}" cy="${y + 6}" rx="12" ry="5" fill="#0B0E07" opacity=".35" filter="url(#soft)"/>`)
  P.push(`<rect x="${x - 3.5}" y="${top + 4}" width="7" height="${y - top - 4}" rx="2" fill="#6E5034"/>`, `<rect x="${x - 3.5}" y="${top + 4}" width="2.5" height="${y - top - 4}" rx="1" fill="#9A7650"/>`)
  P.push(`<ellipse cx="${x}" cy="${y}" rx="5" ry="2" fill="#4E3824"/>`)
  P.push(`<path d="M${x - 9} ${top - 2}L${x + 9} ${top - 2}L${x + 6} ${top + 7}L${x - 6} ${top + 7}Z" fill="#3A3632"/>`, `<ellipse cx="${x}" cy="${top - 2}" rx="9" ry="3.6" fill="#2A2420"/>`, `<path d="M${x - 7} ${top}L${x - 5} ${top + 6}M${x} ${top + 1}V${top + 7}M${x + 7} ${top}L${x + 5} ${top + 6}" stroke="#5A544C" stroke-width="1.2"/>`)
  P.push(`<ellipse cx="${x}" cy="${top - 2}" rx="6.5" ry="2.4" fill="#C8501A"/>`, `<ellipse cx="${x - 1}" cy="${top - 2.4}" rx="3" ry="1.2" fill="#FFB040"/>`)   // embers; the flame itself is drawn live by the game
  LI.push(`<circle cx="${x}" cy="${top - 6}" r="16" fill="#FFB040" opacity=".55" filter="url(#glow)"/>`)
  return { body: `<g filter="url(#paint)">${P.join('')}</g>`, lights: LI.join(''), ground: [[.5, .56, 4.2, 0, .55]] }
}
const TO = torch()
writeFileSync('tiles/building-torch.svg', svg(100, 100, 'Torch', TO.body))
writeFileSync('tiles/building-torch-lights.svg', svg(100, 100, 'Torch: its flame', TO.lights))
console.log('torch written')

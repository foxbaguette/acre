// A whale seen from above, painted like the rest of the island (no outlines, light from the upper left): a slate-blue
// humpback with long pale flippers, knobbly head, and flukes. Head up (north), as the game's swimmers are drawn.
//   tiles/whale.svg
// Run from the Cute Fox folder: node tools/painted-whale.mjs, then web/scripts/import-art.mjs
import { writeFileSync } from 'node:fs'

const f = (n) => +n.toFixed(1)
let seed = 5
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647 }
// the body's half width along its length (y from the snout at 14 to the tail stock at 150)
const half = (y) => { const t = (y - 14) / 136; return 26 * Math.pow(Math.sin(Math.min(1, t * 1.15) * Math.PI * .5 + .05), .8) * (1 - Math.pow(Math.max(0, t - .35) / .65, 1.6) * .86) }
const side = (s) => [...Array(35)].map((_, k) => { const y = 14 + k * 4; return [50 + s * half(y), y] })
const R = side(1), L = side(-1).reverse()
const body = 'M' + [...R, ...L].map(([x, y]) => `${f(x)} ${f(y)}`).join('L') + 'Z'
const P = []
P.push(`<defs><linearGradient id="b" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#6E8498"/><stop offset=".45" stop-color="#465C70"/><stop offset="1" stop-color="#2A3A4A"/></linearGradient>
<linearGradient id="fl" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#C8D4DC"/><stop offset="1" stop-color="#7E909E"/></linearGradient>
<filter id="soft" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="1.6"/></filter><clipPath id="c"><path d="${body}"/></clipPath></defs>`)
// flippers: long, pale underneath showing at the edges, knobbly leading edge
for (const s of [-1, 1]) {
  const x0 = 50 + s * 20, y0 = 52
  P.push(`<path d="M${x0} ${y0}Q${50 + s * 52} ${y0 + 6} ${50 + s * 62} ${y0 + 34}Q${50 + s * 50} ${y0 + 24} ${50 + s * 18} ${y0 + 16}Z" fill="${s < 0 ? 'url(#fl)' : '#7E909E'}"/>`)
  for (let k = 1; k < 5; k++) P.push(`<circle cx="${f(50 + s * (22 + k * 9))}" cy="${f(y0 + 2 + k * 5)}" r="1.6" fill="#E4ECF0" opacity=".7"/>`)
}
// flukes
P.push(`<path d="M50 146Q36 160 8 166Q30 176 46 168L50 160L54 168Q70 176 92 166Q64 160 50 146Z" fill="url(#b)"/>`, `<path d="M8 166Q30 176 46 168L50 160L54 168Q70 176 92 166" fill="none" stroke="#1E2A36" stroke-width="1.2" opacity=".5"/>`)
P.push(`<path d="${body}" fill="url(#b)"/>`)
// mottling, a lighter back ridge, knobs on the head, the blowholes; shade on the right flank
P.push(`<g clip-path="url(#c)">`)
for (let k = 0; k < 40; k++) { const y = 20 + rnd() * 125, x = 50 + (rnd() - .5) * 2 * half(y) * .9; P.push(`<ellipse cx="${f(x)}" cy="${f(y)}" rx="${f(1 + rnd() * 2.5)}" ry="${f(1 + rnd() * 1.5)}" fill="${rnd() > .5 ? '#8EA2B4' : '#2A3846'}" opacity=".35"/>`) }
P.push(`<path d="M50 20L50 140" stroke="#9AB0C2" stroke-width="5" opacity=".35" filter="url(#soft)"/>`)
for (let k = 0; k < 14; k++) { const y = 18 + rnd() * 26, x = 50 + (rnd() - .5) * 2 * half(y) * .7; P.push(`<circle cx="${f(x)}" cy="${f(y)}" r="${f(1.2 + rnd())}" fill="#A8BACA" opacity=".8"/>`) }
P.push(`<path d="M76 0V180H48Q74 100 76 0Z" fill="#101A24" opacity=".22" filter="url(#soft)"/>`, `</g>`)
P.push(`<ellipse cx="48.6" cy="38" rx="1.4" ry="2.4" fill="#1A2632"/><ellipse cx="51.4" cy="38" rx="1.4" ry="2.4" fill="#1A2632"/>`)
writeFileSync('tiles/whale.svg', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 180" role="img" aria-label="A whale, seen from above">${P.join('')}</svg>\n`)
console.log('whale painted')

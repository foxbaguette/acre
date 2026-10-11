// The farmhouse: a cozy thatched farm cottage, seen from above and a little from the south, in five stages that grow
// within the same 3 x 4 tile plot (300 x 400 units, 100 a tile). Soft light from the upper left, gentle gradients,
// layered straw, contact shadows. For every stage two pictures:
//   tiles/building-farmhouse-N.svg          the cottage
//   tiles/building-farmhouse-N-lights.svg   only its lit windows and their glow, laid on at dusk and at night
// and the research lab, a round workshop (4 x 4): tiles/building-lab.svg and building-lab-lights.svg
// and web/src/engine/buildingArt.ts: where each stage's chimneys stand (the game lets smoke rise from them).
// Run from the Cute Fox folder: node tools/cottage.mjs
import { writeFileSync } from 'node:fs'

const f = (n) => +n.toFixed(1)
const P = (pts) => 'M' + pts.map(([x, y]) => `${f(x)} ${f(y)}`).join('L') + 'Z'
let seed = 1
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647 }
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${f(x)}" y="${f(y)}" width="${f(w)}" height="${f(h)}" fill="${fill}" ${extra}/>`

function cottage(stage) {
  seed = 11 + stage * 7
  const defs = [], body = [], lights = []
  // ---------------- the plot ----------------
  const half = [0, 92, 112, 124, 124, 126][stage]                       // half the house's width
  const WL = 150 - half, WR = 150 + half, L = WL - 18, R = WR + 18
  const RT = stage === 1 ? 66 : 30, RY = RT + 58, EY = 282, WB = 362     // roof top, ridge, eave; wall bottom
  const hip = (R - L) * 0.34                                          // big hipped ends: a rounder, softer roof
  const ridgeL = [L + hip, RY], ridgeR = [R - hip, RY]
  const NW = [L + 22, RT], NE = [R - 22, RT], SW = [L, EY], SE = [R, EY]

  defs.push(`<filter id="blur8" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="8"/></filter>`,
    `<filter id="blur4" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="4"/></filter>`,
    `<filter id="blur2" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="2"/></filter>`,
    `<filter id="glow" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="9"/></filter>`,
    `<linearGradient id="plaster" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F6EAD0"/><stop offset="1" stop-color="#E6D3AE"/></linearGradient>`,
    `<linearGradient id="plasterSh" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#5A4128" stop-opacity=".16"/></linearGradient>`,
    `<linearGradient id="tS" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E9C979"/><stop offset=".55" stop-color="#D6AF5E"/><stop offset="1" stop-color="#B98F45"/></linearGradient>`,
    `<linearGradient id="tN" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#F0D58E"/><stop offset="1" stop-color="#DDBB6C"/></linearGradient>`,
    `<linearGradient id="tW" x1="1" y1="0" x2="0" y2="0"><stop offset="0" stop-color="#EDD088"/><stop offset="1" stop-color="#E2BF6E"/></linearGradient>`,
    `<linearGradient id="tE" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#C79E50"/><stop offset="1" stop-color="#A47D3A"/></linearGradient>`,
    `<linearGradient id="eave" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#A9823D"/><stop offset="1" stop-color="#7C5C2A"/></linearGradient>`,
    `<linearGradient id="ridge" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F6E2A6"/><stop offset="1" stop-color="#D9B868"/></linearGradient>`,
    `<linearGradient id="glass" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#6C8E9C"/><stop offset="1" stop-color="#2E4653"/></linearGradient>`,
    `<linearGradient id="door" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#9A6538"/><stop offset="1" stop-color="#6E4524"/></linearGradient>`,
    `<linearGradient id="stone" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#C9C1B3"/><stop offset="1" stop-color="#8F877B"/></linearGradient>`,
    `<linearGradient id="lit" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF1B8"/><stop offset="1" stop-color="#FFB64E"/></linearGradient>`,
    `<radialGradient id="bush" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="#8DB866"/><stop offset=".6" stop-color="#5E8C45"/><stop offset="1" stop-color="#3F6631"/></radialGradient>`,
    `<radialGradient id="lav" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="#B69AD8"/><stop offset=".7" stop-color="#8A6CB6"/><stop offset="1" stop-color="#5E4A86"/></radialGradient>`,
    `<clipPath id="roof"><path d="${roofOutline()}"/></clipPath>`)

  function roofOutline() {                                              // the roof seen from above: soft, rounded corners
    const k = 26
    return `M${NW[0] + k} ${RT} L${NE[0] - k} ${RT} Q${NE[0] + 6} ${RT} ${NE[0] + 18} ${RT + 22} L${R - 2} ${EY - 30} Q${R + 2} ${EY} ${R - 24} ${EY + 4} ` +
      `L${L + 24} ${EY + 4} Q${L - 2} ${EY} ${L + 2} ${EY - 30} L${NW[0] - 18} ${RT + 22} Q${NW[0] - 6} ${RT} ${NW[0] + k} ${RT} Z`
  }

  // ---------------- the ground: shadow, path, garden ----------------
  body.push(`<path d="${roofOutline()}" fill="#0B0E07" opacity=".38" filter="url(#blur8)" transform="translate(16 18)"/>`)
  body.push(`<rect x="${WL + 10}" y="${WB - 6}" width="${WR - WL}" height="20" fill="#0B0E07" opacity=".3" filter="url(#blur4)"/>`)
  // stepping stones from the door
  const doorX = stage === 1 ? 168 : 150
  for (let k = 0; k < 3; k++) { const y = WB + 10 + k * 11, x = doorX + (k % 2 ? 4 : -3)
    body.push(`<ellipse cx="${x + 2}" cy="${y + 3}" rx="10" ry="5" fill="#0B0E07" opacity=".22"/>`, `<ellipse cx="${x}" cy="${y}" rx="10" ry="5.5" fill="url(#stone)"/>`) }
  // shrubs and flowers either side of the path
  const shrub = (x, y, r, kind = 'bush') => {
    body.push(`<ellipse cx="${x + r * .35}" cy="${y + r * .45}" rx="${r}" ry="${r * .75}" fill="#0B0E07" opacity=".28" filter="url(#blur2)"/>`)
    body.push(`<circle cx="${x}" cy="${y}" r="${r}" fill="url(#${kind})"/>`)
    if (kind === 'bush') for (let k = 0; k < 5; k++) { const a = rnd() * 6.28, d = rnd() * r * .6; body.push(`<circle cx="${f(x + Math.cos(a) * d)}" cy="${f(y + Math.sin(a) * d)}" r="2.2" fill="${['#F4A6B8', '#FFF4E0', '#F7D36B'][k % 3]}"/>`) }
  }
  shrub(WL + 8, WB + 18, 13, stage >= 3 ? 'lav' : 'bush')
  shrub(WR - 10, WB + 20, 12)
  if (stage >= 2) shrub(WL + 34, WB + 26, 9, 'bush')
  if (stage >= 3) shrub(WR - 36, WB + 27, 9, 'lav')

  // ---------------- the front wall ----------------
  const WT = EY - 14
  body.push(rect(WL, WT, WR - WL, WB - WT, 'url(#plaster)'), rect(150, WT, WR - 150, WB - WT, 'url(#plasterSh)'))
  // stone plinth and corner stones
  body.push(rect(WL - 2, WB - 12, WR - WL + 4, 13, '#A29A8D'))
  for (let x = WL; x < WR; x += 16 + rnd() * 6) body.push(`<rect x="${f(x)}" y="${WB - 11}" width="${f(12 + rnd() * 6)}" height="5" rx="2" fill="${rnd() > .5 ? '#BDB5A8' : '#8E8679'}"/>`, `<rect x="${f(x + 6)}" y="${WB - 5}" width="${f(12 + rnd() * 6)}" height="4.5" rx="2" fill="${rnd() > .5 ? '#B3AB9E' : '#857D70'}"/>`)
  for (const [x0, sh] of [[WL - 2, '#C8C0B2'], [WR - 12, '#9D9589']]) for (let y = WT + 6; y < WB - 14; y += 13) body.push(`<rect x="${x0 + ((y / 13) % 2 ? 0 : 3)}" y="${y}" width="11" height="11" rx="2" fill="${sh}"/>`)
  // windows: small panes in white frames, shutters, sills
  const win = (cx, cy, w = 30, h = 28) => {
    body.push(`<rect x="${cx - w / 2 - 9}" y="${cy - h / 2}" width="8" height="${h}" rx="1.5" fill="#7E9C6E"/>`, `<rect x="${cx + w / 2 + 1}" y="${cy - h / 2}" width="8" height="${h}" rx="1.5" fill="#6A8A5C"/>`)
    body.push(`<rect x="${cx - w / 2 - 2}" y="${cy - h / 2 - 2}" width="${w + 4}" height="${h + 4}" rx="2" fill="#F7F1E3"/>`, `<rect x="${cx - w / 2}" y="${cy - h / 2}" width="${w}" height="${h}" fill="url(#glass)"/>`)
    body.push(`<path d="${P([[cx - w / 2 + 3, cy + h / 2 - 3], [cx - w / 2 + 3, cy - h / 2 + 10], [cx - w / 2 + 12, cy - h / 2 + 3], [cx - w / 2 + 16, cy - h / 2 + 3]])}" fill="#FFFFFF" opacity=".22"/>`)
    body.push(rect(cx - 1.2, cy - h / 2, 2.4, h, '#F7F1E3'), rect(cx - w / 2, cy - 1.2, w, 2.4, '#F7F1E3'), rect(cx - w / 2 - 4, cy + h / 2 + 2, w + 8, 4, '#D9CDB4'))
    lights.push(`<ellipse cx="${cx}" cy="${cy + 4}" rx="${w * .95}" ry="${h * .9}" fill="#FFC861" opacity=".55" filter="url(#glow)"/>`,
      `<rect x="${cx - w / 2}" y="${cy - h / 2}" width="${w}" height="${h}" fill="url(#lit)"/>`, rect(cx - 1.2, cy - h / 2, 2.4, h, '#E5B568'), rect(cx - w / 2, cy - 1.2, w, 2.4, '#E5B568'))
    if (stage >= 2) {                                                   // a window box of flowers
      body.push(`<rect x="${cx - w / 2 - 3}" y="${cy + h / 2 + 5}" width="${w + 6}" height="7" rx="1.5" fill="#8A5A33"/>`)
      for (let k = 0; k < 7; k++) { const x = cx - w / 2 + 1 + k * (w / 6); body.push(`<circle cx="${f(x)}" cy="${cy + h / 2 + 5}" r="3.6" fill="#5E8C45"/>`, `<circle cx="${f(x + 1)}" cy="${cy + h / 2 + 3}" r="2.4" fill="${['#F28CA3', '#FFF2D8', '#F2C14E', '#C99AE0'][k % 4]}"/>`) }
    }
  }
  const wy = WT + 38
  const wins = stage === 1 ? [WL + 46] : stage === 2 ? [WL + 50, WR - 50] : [WL + 46, WR - 46]
  for (const x of wins) win(x, wy)
  // the door: arched, planked, under its own little canopy from stage 4
  const door = (x) => {
    const w = 32, h = 50, top = WB - 12 - h
    body.push(`<path d="M${x - w / 2 - 4} ${WB - 12}L${x - w / 2 - 4} ${top + 12}Q${x - w / 2 - 4} ${top - 6} ${x} ${top - 6}Q${x + w / 2 + 4} ${top - 6} ${x + w / 2 + 4} ${top + 12}L${x + w / 2 + 4} ${WB - 12}Z" fill="#B7AC98"/>`)
    body.push(`<path d="M${x - w / 2} ${WB - 12}L${x - w / 2} ${top + 12}Q${x - w / 2} ${top - 2} ${x} ${top - 2}Q${x + w / 2} ${top - 2} ${x + w / 2} ${top + 12}L${x + w / 2} ${WB - 12}Z" fill="url(#door)"/>`)
    for (let k = 1; k < 4; k++) body.push(rect(x - w / 2 + k * w / 4 - .6, top + 2, 1.2, h - 2, '#5A381D', 'opacity=".55"'))
    body.push(rect(x - w / 2, top + 16, w, 3, '#3E2A1A', 'opacity=".5"'), rect(x - w / 2, WB - 26, w, 3, '#3E2A1A', 'opacity=".5"'), `<circle cx="${x + 9}" cy="${top + 30}" r="2.2" fill="#E8C25A"/>`)
    body.push(`<path d="M${x - 8} ${top + 8}Q${x} ${top + 1} ${x + 8} ${top + 8}Z" fill="url(#glass)"/>`)
    lights.push(`<path d="M${x - 8} ${top + 8}Q${x} ${top + 1} ${x + 8} ${top + 8}Z" fill="url(#lit)"/>`)
    body.push(`<rect x="${x - w / 2 - 6}" y="${WB - 2}" width="${w + 12}" height="8" rx="2" fill="url(#stone)"/>`)
    if (stage >= 2) {                                                   // a lantern by the door
      body.push(rect(x + w / 2 + 8, top + 14, 3, 6, '#3E3229'), `<rect x="${x + w / 2 + 5}" y="${top + 19}" width="9" height="12" rx="1.5" fill="#3E3229"/>`, rect(x + w / 2 + 6.5, top + 21, 6, 8, '#E9D9A8'))
      lights.push(`<circle cx="${x + w / 2 + 9.5}" cy="${top + 25}" r="16" fill="#FFC861" opacity=".7" filter="url(#glow)"/>`, rect(x + w / 2 + 6.5, top + 21, 6, 8, '#FFE9A8'))
    }
    if (stage >= 4) {                                                   // a small thatched canopy over the door
      body.push(`<path d="M${x - w / 2 - 14} ${top + 4}Q${x} ${top - 26} ${x + w / 2 + 14} ${top + 4}L${x + w / 2 + 10} ${top + 10}Q${x} ${top - 14} ${x - w / 2 - 10} ${top + 10}Z" fill="url(#eave)"/>`)
      body.push(`<path d="M${x - w / 2 - 14} ${top + 4}Q${x} ${top - 26} ${x + w / 2 + 14} ${top + 4}Q${x} ${top - 18} ${x - w / 2 - 14} ${top + 4}Z" fill="url(#tS)"/>`)
    }
  }
  door(doorX)
  // under the eaves: a soft band of shade on the wall
  body.push(rect(WL, WT - 4, WR - WL, 20, '#3B2A16', 'opacity=".45" filter="url(#blur4)"'))
  // climbing roses on the corners from stage 3
  if (stage >= 3) for (const x of [WL + 4, WR - 4]) for (let k = 0; k < 9; k++) {
    const y = WB - 16 - k * 9 - rnd() * 4, xx = x + (rnd() - .5) * 10
    body.push(`<circle cx="${f(xx)}" cy="${f(y)}" r="${f(4 + rnd() * 2.5)}" fill="${rnd() > .4 ? '#5E8C45' : '#4A7538'}"/>`)
    if (rnd() > .45) body.push(`<circle cx="${f(xx + 1)}" cy="${f(y - 1)}" r="2.3" fill="${rnd() > .5 ? '#E87C93' : '#F7B3C2'}"/>`)
  }
  // firewood by the wall (stages 1-2), a water butt (from 3)
  if (stage <= 2) { const x = WR + 2, y = WB - 4
    body.push(`<ellipse cx="${x + 18}" cy="${y + 6}" rx="22" ry="7" fill="#0B0E07" opacity=".3" filter="url(#blur2)"/>`)
    for (let r = 0; r < 3; r++) for (let c = 0; c < 4 - r; c++) { const cx = x - 10 + c * 10 + r * 5, cy = y - r * 9; body.push(`<circle cx="${cx}" cy="${cy}" r="5.2" fill="#8A5A33"/>`, `<circle cx="${cx}" cy="${cy}" r="3.3" fill="#C99A63"/>`, `<circle cx="${cx}" cy="${cy}" r="1.2" fill="#8A5A33"/>`) } }
  if (stage >= 3) { const x = WL - 10, y = WB - 8
    body.push(`<ellipse cx="${x + 6}" cy="${y + 8}" rx="13" ry="6" fill="#0B0E07" opacity=".3" filter="url(#blur2)"/>`, `<rect x="${x - 11}" y="${y - 24}" width="22" height="30" rx="4" fill="#7A5232"/>`, rect(x - 11, y - 16, 22, 2.5, '#3E3229'), rect(x - 11, y - 4, 22, 2.5, '#3E3229'), `<ellipse cx="${x}" cy="${y - 24}" rx="11" ry="4" fill="#4A6E7E"/>`) }

  // ---------------- the thatched roof ----------------
  const R2 = []
  R2.push(`<path d="${P([NW, NE, ridgeR, ridgeL])}" fill="url(#tN)"/>`, `<path d="${P([ridgeL, ridgeR, SE, [R, EY + 8], [L, EY + 8], SW])}" fill="url(#tS)"/>`)
  R2.push(`<path d="${P([[L - 30, RT], NW, ridgeL, SW, [L - 30, EY + 8]])}" fill="url(#tW)"/>`, `<path d="${P([NE, [R + 30, RT], [R + 30, EY + 8], SE, ridgeR])}" fill="url(#tE)"/>`)
  // the straw: short strokes laid down the slope in courses, lighter on top of each course and darker under it
  const strokes = (x0, x1, y0, y1, dirx, diry, n, col, op, w) => { let d = ''
    for (let k = 0; k < n; k++) { const x = x0 + rnd() * (x1 - x0), y = y0 + rnd() * (y1 - y0), len = 7 + rnd() * 9; d += `M${f(x)} ${f(y)}l${f(dirx * len)} ${f(diry * len)}` }
    return `<path d="${d}" stroke="${col}" stroke-opacity="${op}" stroke-width="${w}" stroke-linecap="round" fill="none"/>` }
  R2.push(strokes(L, R, RY + 4, EY, 0.06, 1, 420, '#7E5B26', .18, 1.2), strokes(L, R, RY + 4, EY, 0.04, 1, 320, '#FFF0B8', .26, 1))
  R2.push(strokes(L, R, RT, RY, 0, -1, 120, '#8A6830', .16, 1.1), strokes(L, R, RT, RY, 0, -1, 100, '#FFF4C8', .3, 1))
  R2.push(strokes(L - 30, ridgeL[0], RT, EY, -1, .3, 130, '#8A6830', .16, 1.1), strokes(ridgeR[0], R + 30, RT, EY, 1, .3, 130, '#6E4E1F', .2, 1.1))
  // the courses: soft darker bands across the south slope
  for (let y = RY + 26; y < EY - 4; y += 30) R2.push(`<path d="M${L - 10} ${y + 4}Q150 ${y - 6} ${R + 10} ${y + 4}" stroke="#7A5726" stroke-opacity=".28" stroke-width="5" fill="none" filter="url(#blur2)"/>`)
  // eyebrow dormers from stage 4: the thatch swells over a little window
  const dormers = stage >= 5 ? [WL + 60, 150, WR - 60] : stage >= 4 ? [WL + 64, WR - 64] : []
  const dy = (RY + EY) / 2 - 6
  for (const x of dormers) {
    R2.push(`<ellipse cx="${x + 6}" cy="${dy + 18}" rx="30" ry="9" fill="#5A3E17" opacity=".45" filter="url(#blur4)"/>`)
    R2.push(`<path d="M${x - 30} ${dy + 18}Q${x} ${dy - 22} ${x + 30} ${dy + 18}Z" fill="url(#tN)"/>`, strokes(x - 26, x + 26, dy - 8, dy + 14, 0.05, 1, 60, '#FFF0B8', .4, 1))
    R2.push(`<path d="M${x - 14} ${dy + 18}Q${x} ${dy + 2} ${x + 14} ${dy + 18}Z" fill="url(#glass)"/>`, `<path d="M${x - 30} ${dy + 18}Q${x} ${dy - 22} ${x + 30} ${dy + 18}Q${x} ${dy - 10} ${x - 30} ${dy + 18}Z" fill="url(#eave)" opacity=".6"/>`)
    lights.push(`<ellipse cx="${x}" cy="${dy + 14}" rx="22" ry="12" fill="#FFC861" opacity=".5" filter="url(#glow)"/>`, `<path d="M${x - 14} ${dy + 18}Q${x} ${dy + 2} ${x + 14} ${dy + 18}Z" fill="url(#lit)"/>`)
  }
  // a soft rounded body: the edges fall away into shade, the upper left catches the sun
  R2.push(`<path d="${roofOutline()}" fill="none" stroke="#5A3E17" stroke-opacity=".55" stroke-width="34" filter="url(#blur8)"/>`)
  R2.push(`<ellipse cx="${L + (R - L) * .3}" cy="${RT + 40}" rx="${(R - L) * .32}" ry="46" fill="#FFF6D0" opacity=".35" filter="url(#blur8)"/>`)
  body.push(`<g clip-path="url(#roof)">${R2.join('')}</g>`)
  // the eave: the thatch's thick, rounded lower edge, cut in soft scallops
  let sc = `M${L + 22} ${EY - 4}`
  for (let x = L + 22; x < R - 22; x += 14) sc += `Q${x + 7} ${EY + 14} ${Math.min(R - 22, x + 14)} ${EY + 2}`
  sc += `L${R - 22} ${EY - 8}L${L + 22} ${EY - 8}Z`
  body.push(`<path d="${sc}" fill="url(#eave)"/>`)
  // the ridge: a decorated straw ridge with points and criss-cross liggers
  const rx0 = ridgeL[0] - 8, rx1 = ridgeR[0] + 8
  let rp = `M${rx0} ${RY - 7}L${rx1} ${RY - 7}L${rx1} ${RY + 3}`
  for (let x = rx1; x > rx0; x -= 16) rp += `L${x - 8} ${RY + 12}L${Math.max(rx0, x - 16)} ${RY + 3}`
  body.push(`<path d="${rp}Z" fill="url(#ridge)"/>`, `<path d="${rp}Z" fill="#6E4E1F" opacity=".15" transform="translate(0 3)"/>`)
  let lg = ''; for (let x = rx0 + 4; x < rx1 - 8; x += 12) lg += `M${x} ${RY - 5}L${x + 10} ${RY + 1}M${x + 10} ${RY - 5}L${x} ${RY + 1}`
  body.push(`<path d="${lg}" stroke="#9C7A3A" stroke-width="1.2" stroke-opacity=".7" fill="none"/>`)

  // ---------------- chimneys ----------------
  const chimneys = stage === 1 ? [[WR - 44, RY]] : stage >= 5 ? [[WL + 40, RY], [WR - 46, RY]] : [[WR - 46, RY]]
  const smoke = []
  for (const [cx, base] of chimneys) {
    const top = base - 46
    body.push(`<path d="${P([[cx + 10, base + 8], [cx + 44, base + 26], [cx + 52, base + 14], [cx + 18, base - 4]])}" fill="#4A3412" opacity=".35" filter="url(#blur4)"/>`)   // its shadow on the thatch
    body.push(`<rect x="${cx - 14}" y="${top}" width="28" height="${base - top + 8}" fill="#9C9488"/>`, `<rect x="${cx}" y="${top}" width="14" height="${base - top + 8}" fill="#7E766A"/>`)
    for (let y = top + 4; y < base + 4; y += 8) for (let x = cx - 14 + ((y / 8) % 2 ? 0 : 6); x < cx + 14; x += 12) body.push(`<rect x="${f(x)}" y="${f(y)}" width="${f(Math.min(10, cx + 14 - x))}" height="6" rx="1.5" fill="${x < cx ? '#B6AEA1' : '#8E8679'}"/>`)
    body.push(`<rect x="${cx - 17}" y="${top - 6}" width="34" height="8" rx="2" fill="#C2BAAD"/>`, `<rect x="${cx}" y="${top - 6}" width="17" height="8" rx="2" fill="#A39B8E"/>`, `<ellipse cx="${cx}" cy="${top - 4}" rx="9" ry="3" fill="#2A2420"/>`)
    smoke.push([cx / 100, (top - 6) / 100])
  }

  const svg = (parts, label) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400" role="img" aria-label="${label}"><defs>${defs.join('')}</defs>${parts.join('')}</svg>\n`
  writeFileSync(`tiles/building-farmhouse-${stage}.svg`, svg(body, `Farm cottage, stage ${stage} of 5`))
  writeFileSync(`tiles/building-farmhouse-${stage}-lights.svg`, svg(lights, `Farm cottage, stage ${stage}: lit windows`))
  return smoke
}

// ---------------- the research lab: a round workshop, 4 x 4 tiles (400 x 400) ----------------
// A round stone workshop under a conical slate roof with a glass lantern on top and a stovepipe; windows all round the
// front, a door under a little hood, a workbench, crates and a cart wheel outside.
function lab() {
  seed = 97
  const defs = [], body = [], lights = []
  const CX = 200, CY = 218, RR = 150, RY = 86, AY = 136, WR0 = 130, WB = 366   // roof base centre, radii, the apex's height on screen; wall radius; wall foot
  defs.push(`<filter id="blur8" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="8"/></filter>`,
    `<filter id="blur4" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="4"/></filter>`,
    `<filter id="blur2" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="2"/></filter>`,
    `<filter id="glow" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="9"/></filter>`,
    `<linearGradient id="wall" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#D8CFBF"/><stop offset=".45" stop-color="#C7BDAB"/><stop offset="1" stop-color="#8F8676"/></linearGradient>`,
    `<radialGradient id="slate" cx=".38" cy=".34" r=".72"><stop offset="0" stop-color="#9DB3C4"/><stop offset=".55" stop-color="#6F879B"/><stop offset="1" stop-color="#46586A"/></radialGradient>`,
    `<linearGradient id="glass" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#6C8E9C"/><stop offset="1" stop-color="#2E4653"/></linearGradient>`,
    `<linearGradient id="lit" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF1B8"/><stop offset="1" stop-color="#FFB64E"/></linearGradient>`,
    `<linearGradient id="door" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#4F7383"/><stop offset="1" stop-color="#34505E"/></linearGradient>`,
    `<linearGradient id="stone" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#C9C1B3"/><stop offset="1" stop-color="#8F877B"/></linearGradient>`,
    `<linearGradient id="wood" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#A9764A"/><stop offset="1" stop-color="#7A5232"/></linearGradient>`,
    `<radialGradient id="copper" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="#E6B27A"/><stop offset=".6" stop-color="#B9773F"/><stop offset="1" stop-color="#7E4A24"/></radialGradient>`,
    `<radialGradient id="bush" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="#8DB866"/><stop offset=".6" stop-color="#5E8C45"/><stop offset="1" stop-color="#3F6631"/></radialGradient>`,
    `<clipPath id="wallc"><rect x="${CX - WR0}" y="${CY}" width="${WR0 * 2}" height="${WB - CY + 4}"/></clipPath>`)
  // shadow on the ground
  body.push(`<ellipse cx="${CX + 22}" cy="${CY + 50}" rx="${RR}" ry="${RR * .9}" fill="#0B0E07" opacity=".38" filter="url(#blur8)"/>`)
  // the round wall: its front half shows below the roof's edge, in courses of stone
  body.push(`<path d="M${CX - WR0} ${CY}L${CX - WR0} ${WB - 36}A${WR0} 36 0 0 0 ${CX + WR0} ${WB - 36}L${CX + WR0} ${CY}Z" fill="url(#wall)"/>`)
  const st = []
  for (let y = CY + 70; y < WB; y += 12) for (let a = -1; a < 1; a += .12 + rnd() * .05) {
    const x = CX + Math.sin(a * Math.PI / 2) * WR0, yy = y + (1 - Math.cos(a * Math.PI / 2)) * -40 + 40 * (1 - Math.cos(a * Math.PI / 2)) * 0, w = 14 * Math.cos(a * Math.PI / 2) + 4
    st.push(`<rect x="${f(x - w / 2)}" y="${f(y - 36 * (1 - Math.cos(a * Math.PI / 2)))}" width="${f(w)}" height="9" rx="2.5" fill="${a < .2 ? (rnd() > .5 ? '#DCD4C5' : '#CBC2B2') : (rnd() > .5 ? '#A39A8A' : '#948B7C')}" opacity=".8"/>`)
  }
  body.push(`<g clip-path="url(#wallc)">${st.join('')}</g>`)
  body.push(`<path d="M${CX - WR0} ${WB - 36}A${WR0} 36 0 0 0 ${CX + WR0} ${WB - 36}L${CX + WR0} ${WB - 26}A${WR0} 36 0 0 1 ${CX - WR0} ${WB - 26}Z" fill="#7E766A"/>`)   // the footing
  // windows round the front: each squeezed by the curve of the wall
  for (const a of [-.62, -.3, .3, .62]) {
    const x = CX + Math.sin(a * Math.PI / 2) * WR0, sq = Math.cos(a * Math.PI / 2), w = 26 * sq, top = CY + RY + 4 - 30 * (1 - sq)
    body.push(`<path d="M${f(x - w / 2 - 3)} ${f(top + 40)}L${f(x - w / 2 - 3)} ${f(top + 10)}Q${f(x)} ${f(top - 8)} ${f(x + w / 2 + 3)} ${f(top + 10)}L${f(x + w / 2 + 3)} ${f(top + 40)}Z" fill="#F4EFE4"/>`)
    body.push(`<path d="M${f(x - w / 2)} ${f(top + 37)}L${f(x - w / 2)} ${f(top + 11)}Q${f(x)} ${f(top - 4)} ${f(x + w / 2)} ${f(top + 11)}L${f(x + w / 2)} ${f(top + 37)}Z" fill="url(#glass)"/>`, rect(x - 1, top + 2, 2, 35, '#F4EFE4'), rect(x - w / 2, top + 22, w, 2, '#F4EFE4'))
    lights.push(`<ellipse cx="${f(x)}" cy="${f(top + 24)}" rx="${f(w)}" ry="30" fill="#FFC861" opacity=".55" filter="url(#glow)"/>`, `<path d="M${f(x - w / 2)} ${f(top + 37)}L${f(x - w / 2)} ${f(top + 11)}Q${f(x)} ${f(top - 4)} ${f(x + w / 2)} ${f(top + 11)}L${f(x + w / 2)} ${f(top + 37)}Z" fill="url(#lit)"/>`)
  }
  // the door under a little copper hood, a round window in it, a lamp beside it, a step
  const DX = CX, DT = WB - 80
  body.push(`<path d="M${DX - 22} ${WB - 22}L${DX - 22} ${DT + 16}Q${DX} ${DT - 6} ${DX + 22} ${DT + 16}L${DX + 22} ${WB - 22}Z" fill="#B7AC98"/>`, `<path d="M${DX - 18} ${WB - 22}L${DX - 18} ${DT + 18}Q${DX} ${DT} ${DX + 18} ${DT + 18}L${DX + 18} ${WB - 22}Z" fill="url(#door)"/>`)
  body.push(`<circle cx="${DX}" cy="${DT + 28}" r="7" fill="#F4EFE4"/>`, `<circle cx="${DX}" cy="${DT + 28}" r="5" fill="url(#glass)"/>`, `<circle cx="${DX + 11}" cy="${DT + 50}" r="2.2" fill="#E8C25A"/>`)
  lights.push(`<circle cx="${DX}" cy="${DT + 28}" r="5" fill="url(#lit)"/>`)
  body.push(`<path d="M${DX - 30} ${DT + 8}Q${DX} ${DT - 26} ${DX + 30} ${DT + 8}L${DX + 26} ${DT + 13}Q${DX} ${DT - 16} ${DX - 26} ${DT + 13}Z" fill="url(#copper)"/>`)
  body.push(`<rect x="${DX - 28}" y="${WB - 22}" width="56" height="10" rx="3" fill="url(#stone)"/>`)
  body.push(rect(DX + 30, DT + 16, 3, 7, '#3E3229'), `<rect x="${DX + 27}" y="${DT + 22}" width="9" height="12" rx="1.5" fill="#3E3229"/>`, rect(DX + 28.5, DT + 24, 6, 8, '#E9D9A8'))
  lights.push(`<circle cx="${DX + 31.5}" cy="${DT + 28}" r="18" fill="#FFC861" opacity=".7" filter="url(#glow)"/>`, rect(DX + 28.5, DT + 24, 6, 8, '#FFE9A8'))
  // shade under the eaves
  body.push(`<path d="M${CX - WR0} ${CY}A${WR0} ${RY - 4} 0 0 0 ${CX + WR0} ${CY}L${CX + WR0} ${CY + 22}A${WR0} ${RY - 4} 0 0 1 ${CX - WR0} ${CY + 22}Z" fill="#2B2F35" opacity=".45" filter="url(#blur4)"/>`)
  // the conical roof: slate in rings, lit on the upper left, with a scalloped edge
  body.push(`<ellipse cx="${CX}" cy="${CY + 6}" rx="${RR + 2}" ry="${RY + 2}" fill="#3A4856"/>`)
  body.push(`<ellipse cx="${CX}" cy="${CY}" rx="${RR}" ry="${RY}" fill="url(#slate)"/>`)
  for (let k = 1; k <= 7; k++) {                                       // rings of slates, each edge a row of little scallops
    const t = k * .118, r = RR * (1 - t), ry = RY * (1 - t), cy = CY + (AY - CY) * t; let d = ''
    const n = Math.max(10, Math.round(r / 7))
    for (let j = 0; j < n; j++) { const a0 = j / n * Math.PI * 2, a1 = (j + 1) / n * Math.PI * 2, am = (a0 + a1) / 2
      d += `M${f(CX + Math.cos(a0) * r)} ${f(cy + Math.sin(a0) * ry)}Q${f(CX + Math.cos(am) * (r + 5))} ${f(cy + Math.sin(am) * (ry + 5))} ${f(CX + Math.cos(a1) * r)} ${f(cy + Math.sin(a1) * ry)}` }
    body.push(`<path d="${d}" stroke="#2F3D4A" stroke-opacity=".38" stroke-width="2" fill="none"/>`, `<path d="${d}" stroke="#D8E4EC" stroke-opacity=".22" stroke-width="1.2" fill="none" transform="translate(-1 -1.5)"/>`)
  }
  // the ridge lines of the cone, lit and shaded
  for (let j = 0; j < 12; j++) { const a = j / 12 * Math.PI * 2, lit = Math.cos(a - Math.PI * 1.25) > .2
    body.push(`<path d="M${CX} ${AY}L${f(CX + Math.cos(a) * RR)} ${f(CY + Math.sin(a) * RY)}" stroke="${lit ? '#E4EEF4' : '#2F3D4A'}" stroke-opacity="${lit ? .3 : .3}" stroke-width="2.5"/>`) }
  // the cone in light: brighter toward the peak and the sun, darker down its far and front slopes
  body.push(`<ellipse cx="${CX + 40}" cy="${CY + 30}" rx="${RR * .9}" ry="${RY * .8}" fill="#1C2630" opacity=".28" filter="url(#blur8)"/>`, `<ellipse cx="${CX - 44}" cy="${AY + 44}" rx="58" ry="28" fill="#F0F6FA" opacity=".22" filter="url(#blur8)"/>`)
  // the glass lantern on top, with a copper cap
  body.push(`<ellipse cx="${CX + 10}" cy="${AY + 12}" rx="40" ry="30" fill="#1C2630" opacity=".4" filter="url(#blur4)"/>`)
  body.push(`<ellipse cx="${CX}" cy="${AY + 4}" rx="36" ry="28" fill="#F4EFE4"/>`, `<ellipse cx="${CX}" cy="${AY + 2}" rx="31" ry="24" fill="url(#glass)"/>`)
  for (let j = 0; j < 8; j++) { const a = j / 8 * Math.PI * 2; body.push(`<path d="M${CX} ${AY + 2}L${f(CX + Math.cos(a) * 31)} ${f(AY + 2 + Math.sin(a) * 24)}" stroke="#F4EFE4" stroke-width="2"/>`) }
  lights.push(`<ellipse cx="${CX}" cy="${AY + 2}" rx="46" ry="38" fill="#FFC861" opacity=".6" filter="url(#glow)"/>`, `<ellipse cx="${CX}" cy="${AY + 2}" rx="31" ry="24" fill="url(#lit)"/>`)
  body.push(`<ellipse cx="${CX}" cy="${AY - 4}" rx="18" ry="14" fill="url(#copper)"/>`, `<circle cx="${CX - 5}" cy="${AY - 9}" r="4" fill="#F6D2A2" opacity=".7"/>`, `<circle cx="${CX}" cy="${AY - 18}" r="4" fill="url(#copper)"/>`)
  // the stovepipe, a little tilted cap, on the shaded side
  const SX = CX + 74, SY = CY - 64
  body.push(`<path d="M${SX + 6} ${SY + 40}L${SX + 34} ${SY + 52}L${SX + 38} ${SY + 44}L${SX + 10} ${SY + 32}Z" fill="#1C2630" opacity=".4" filter="url(#blur2)"/>`)
  body.push(`<rect x="${SX - 7}" y="${SY}" width="14" height="40" fill="#4A4643"/>`, `<rect x="${SX}" y="${SY}" width="7" height="40" fill="#34312F"/>`, rect(SX - 9, SY + 14, 18, 4, '#6A6560'))
  body.push(`<path d="M${SX - 13} ${SY + 2}L${SX} ${SY - 10}L${SX + 13} ${SY + 2}Z" fill="#5A5551"/>`)
  // around it: a workbench with tools, crates, a cart wheel, shrubs
  body.push(`<ellipse cx="${62}" cy="${372}" rx="44" ry="10" fill="#0B0E07" opacity=".3" filter="url(#blur2)"/>`, `<rect x="22" y="346" width="76" height="12" rx="2" fill="url(#wood)"/>`, rect(26, 358, 6, 16, '#6E4A2A'), rect(88, 358, 6, 16, '#6E4A2A'))
  body.push(`<circle cx="40" cy="349" r="5" fill="#B9773F"/>`, `<rect x="54" y="344" width="18" height="5" rx="1" fill="#9AA3A8"/>`, `<rect x="78" y="340" width="10" height="9" rx="1.5" fill="#6C8E9C"/>`)
  for (const [x, y, s] of [[318, 352, 26], [344, 362, 20], [330, 330, 18]]) body.push(`<rect x="${x + 4}" y="${y + 4}" width="${s}" height="${s * .8}" fill="#0B0E07" opacity=".3" filter="url(#blur2)"/>`, `<rect x="${x}" y="${y}" width="${s}" height="${s * .8}" rx="2" fill="url(#wood)"/>`, rect(x, y + s * .35, s, 2.5, '#6E4A2A'), rect(x + s * .45, y, 2.5, s * .8, '#6E4A2A'))
  body.push(`<circle cx="374" cy="306" r="17" fill="none" stroke="#7A5232" stroke-width="5"/>`, `<circle cx="374" cy="306" r="4" fill="#5E3F26"/>`)
  for (let j = 0; j < 8; j++) { const a = j / 8 * Math.PI * 2; body.push(`<path d="M374 306L${f(374 + Math.cos(a) * 15)} ${f(306 + Math.sin(a) * 15)}" stroke="#8A5A33" stroke-width="2.5"/>`) }
  for (const [x, y, r] of [[30, 300, 14], [52, 318, 10], [378, 380, 12]]) body.push(`<circle cx="${x + 5}" cy="${y + 6}" r="${r}" fill="#0B0E07" opacity=".28" filter="url(#blur2)"/>`, `<circle cx="${x}" cy="${y}" r="${r}" fill="url(#bush)"/>`)
  const svg = (parts, label) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" role="img" aria-label="${label}"><defs>${defs.join('')}</defs>${parts.join('')}</svg>\n`
  writeFileSync('tiles/building-lab.svg', svg(body, 'Research lab: a round workshop'))
  writeFileSync('tiles/building-lab-lights.svg', svg(lights, 'Research lab: lit windows'))
  return [[SX / 100, (SY - 6) / 100]]
}

const chimneys = {}
for (let s = 1; s <= 5; s++) chimneys[`building-farmhouse-${s}`] = cottage(s)
chimneys['building-lab'] = lab()
writeFileSync('web/src/engine/buildingArt.ts', `// Written by tools/cottage.mjs. Where smoke rises from each building's chimneys, in tiles from its top-left corner.
export const CHIMNEYS: Record<string, [number, number][]> = ${JSON.stringify(chimneys)}
/** The buildings that light their windows after dark (a "<name>-lights" picture). */
export const LIT = new Set(${JSON.stringify(Object.keys(chimneys))})
`)
console.log('cottage stages written', JSON.stringify(chimneys))

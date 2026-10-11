// The mossy old farmhouse, seen from high above: drawn from its real geometry (ground plan + heights) projected with a
// small tilt. The main ridge runs east-west, so the front slope fills most of the plot, the back slope shows as a
// narrower, lighter band, and the front wall shows only as a strip under the eaves. A small front gable over the door
// carries the round window. Shingle courses run across the slopes; each course laps over the one below it.
// Writes three tilts to compare:
//   web/public/mountain-ideas/farmhouses/top-N.svg and web/public/mountain-ideas/farmhouses-top.html
// Run from the Cute Fox folder: node tools/farmhouse-topdown.mjs
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'

const f = (n) => +n.toFixed(1)
let seed = 1
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647 }
const INK = '#2E241C'
const mix = (a, b, t) => { const p = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)), A = p(a), B = p(b); return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * Math.max(0, Math.min(1, t))).toString(16).padStart(2, '0')).join('') }
const dark = (c, t = .45) => mix(c, '#000000', t)
const pd = (pts) => 'M' + pts.map(([x, y]) => `${f(x)} ${f(y)}`).join('L') + 'Z'
const poly = (pts, fill, stroke = INK, sw = 2) => `<path d="${pd(pts)}" fill="${fill}"${stroke ? ` stroke="${stroke}" stroke-width="${sw}" stroke-linejoin="round"` : ''}/>`

export function farmhouse({ tilt = .32, stage = 3 } = {}) {
  seed = 41 + stage
  const P = [], LI = [], t = tilt
  // the plan (x across, y down the plot) and heights
  // it grows with each stage: a small cottage, then wider and deeper, then more on and around it
  const S = stage, X0 = [60, 40, 26, 26, 26][S - 1], X1 = 300 - X0, WH = 70, RH = [76, 84, 90, 90, 90][S - 1], OV = 12   // walls x0..x1, eaves overhang
  const YS = 340, YN = 14 + OV + WH * t + [44, 20, 0, 0, 0][S - 1], YR = YN + (YS - YN) * .46        // south wall, north wall, ridge line
  const pr = (x, y, z) => [x, y - z * t]                                  // ground position and height -> picture
  const XL = X0 - OV, XE = X1 + OV, ZR = WH + RH
  // a point on a main slope: u = 0 at the eave, 1 at the ridge
  const south = (x, u) => pr(x, YS + OV + (YR - YS - OV) * u, WH + RH * u)
  const north = (x, u) => pr(x, YN - OV + (YR - YN + OV) * u, WH + RH * u)
  const zSouth = (y) => WH + RH * (YS + OV - y) / (YS + OV - YR)
  // moss grows in a few clumps, more on the back slope and along the eaves
  const blobs = [...Array(S === 1 ? 12 : 9)].map(() => ({ x: XL + rnd() * (XE - XL), u: rnd(), r: 40 + rnd() * 50, back: rnd() < .45 }))
  const mossAt = (x, u, back) => Math.min(1, (back ? .35 : .12) + (1 - u) * .25 + blobs.filter((b) => b.back === back).reduce((m, b) => Math.max(m, 1 - Math.hypot(x - b.x, (u - b.u) * 160) / b.r), 0))

  // shadow on the ground, to the lower right
  P.push(`<path d="${pd([pr(XL + 24, YN + 6, 0), pr(Math.min(298, XE + 30), YN + 6, 0), pr(Math.min(298, XE + 30), YS + 24, 0), pr(XL + 24, YS + 24, 0)])}" fill="#0B0E07" opacity=".36" filter="url(#soft)"/>`)

  // the front wall: cobbles, the door, two windows (the eaves hide its top)
  const wallPts = [pr(X0, YS, 0), pr(X1, YS, 0), pr(X1, YS, WH), pr(X0, YS, WH)]
  P.push(poly(wallPts, '#A0937E'))
  const wTop = YS - WH * t, rowH = Math.max(5, 9 * t / .35)
  for (let y = YS - rowH, row = 0; y > wTop - rowH; y -= rowH, row++) for (let x = X0 - (row % 2 ? 7 : 0); x < X1;) {
    const w = 11 + rnd() * 11, c = mix('#B0A28E', rnd() > .5 ? '#3A362F' : '#E8E2D4', rnd() * .25), x0 = Math.max(X0, x), x1 = Math.min(X1, x + w), y0 = Math.max(wTop, y)
    if (x1 > x0 + 2) P.push(`<rect x="${f(x0 + 1)}" y="${f(y0 + .7)}" width="${f(x1 - x0 - 2)}" height="${f(Math.max(1, y + rowH - y0 - 1.4))}" rx="2.5" fill="${c}" stroke="${dark(c, .5)}" stroke-width=".9"/>`)
    x += w
  }
  P.push(poly(wallPts, 'none'))
  const XD = 150, wins = [X0 + 38, X1 - 38]
  for (const cx of wins) {
    const w = [pr(cx - 13, YS, WH * .38), pr(cx + 13, YS, WH * .38), pr(cx + 13, YS, WH * .78), pr(cx - 13, YS, WH * .78)]
    P.push(poly(w.map(([x, y], k) => [x + (k === 0 || k === 3 ? -3 : 3), y + (k < 2 ? 2 : -1)]), '#5E3F26', INK, 1.5), poly(w, '#2F3E46', null))
    LI.push(`<ellipse cx="${cx}" cy="${YS + 10}" rx="30" ry="14" fill="#FFC861" opacity=".4" filter="url(#glow)"/>`, `<ellipse cx="${cx}" cy="${f((w[0][1] + w[2][1]) / 2)}" rx="22" ry="12" fill="#FFC861" opacity=".7" filter="url(#glow)"/>`, poly(w, 'url(#lit)', null))
  }

  // one main slope as shingle courses. Courses are drawn eave first, so each one laps over the one below.
  const slope = (pt, back) => {
    const out = [], N = 11
    out.push(poly([pt(XL, 0), pt(XE, 0), pt(XE, 1), pt(XL, 1)], back ? '#7E8A5C' : '#66724A'))
    for (let c = 0; c < N; c++) {
      const u0 = c === 0 ? -.015 : (c - .3) / N, u1 = (c + 1) / N, len = back ? 24 : 26
      for (let x = XL - (c % 2 ? len / 2 : rnd() * 6); x < XE; ) {
        const w = len * (.75 + rnd() * .5), xa = Math.max(XL, x), xb = Math.min(XE, x + w - 1.2); x += w
        if (xb - xa < 3) continue
        const m = mossAt((xa + xb) / 2, (u0 + u1) / 2, back) + (rnd() - .5) * .35
        const slate = mix(back ? '#98A086' : '#8E8B80', back ? '#B2B49C' : '#6A685F', c / N * .6)
        const moss = back ? '#9DB462' : '#6F8A3C'
        const col = mix(mix(slate, moss, m > .55 ? .85 : m * .7), rnd() > .5 ? '#20201A' : '#F4EEDC', rnd() * .14)
        const q = [pt(xa, u0), pt(xb, u0), pt(xb, u1), pt(xa, u1)]
        out.push(poly(q, col, dark(col, .45), 1))
        if (!back) out.push(poly([pt(xa, u0), pt(xb, u0), pt(xb, u0 + .22 / N), pt(xa, u0 + .22 / N)], dark(col, .32), null))   // the butt edge, facing us
        else out.push(poly([pt(xa, u1 - .18 / N), pt(xb, u1 - .18 / N), pt(xb, u1), pt(xa, u1)], mix(col, '#FFFFFF', .18), null))
        if (m > .6 && rnd() > .45) {                                                              // a cushion of moss
          const [mx, my] = pt((xa + xb) / 2 + (rnd() - .5) * 6, (u0 + u1) / 2), r = 5 + rnd() * 7
          out.push(`<ellipse cx="${f(mx)}" cy="${f(my)}" rx="${f(r)}" ry="${f(r * .6)}" fill="${back ? '#A8C266' : '#7C9A42'}"/>`, `<ellipse cx="${f(mx - r * .3)}" cy="${f(my - r * .2)}" rx="${f(r * .45)}" ry="${f(r * .25)}" fill="${back ? '#C8DA86' : '#9AB858'}"/>`)
        }
      }
    }
    // the front slope darkens toward its eave
    if (!back) out.push(`<path d="${pd([pt(XL, 0), pt(XE, 0), pt(XE, .35), pt(XL, .35)])}" fill="#1A1A10" opacity=".14"/>`)
    out.push(poly([pt(XL, 0), pt(XE, 0), pt(XE, 1), pt(XL, 1)], 'none', INK, 2.2))
    return out
  }
  P.push(...slope(north, true), ...slope(south, false))
  // fascia boards along the front eave and up both roof ends
  const eY = south(0, 0)[1]
  P.push(poly([[XL - 2, eY], [XE + 2, eY], [XE + 2, eY + 6], [XL - 2, eY + 6]], '#6E4A2A', INK, 1.6))
  for (const x of [XL - 3, XE + 3]) P.push(poly([[x - 3, north(0, 0)[1]], [x + 3, north(0, 0)[1]], [x + 3, eY + 6], [x - 3, eY + 6]], '#6E4A2A', INK, 1.4))

  // the front gable over the door: its plank face with the round window, and its own two little slopes
  const GW = [40, 50, 58, 58, 58][S - 1], GO = 8, YF = YS + 24, ZG = WH + RH * .42, YG = YS + OV - (YS + OV - YR) * .42   // half width, overhang, its front wall, ridge height, where it meets the roof
  const gab = [pr(XD - GW, YF, WH), pr(XD, YF, ZG), pr(XD + GW, YF, WH)]
  const wing = [pr(XD - GW, YF, 0), pr(XD + GW, YF, 0), pr(XD + GW, YF, WH), pr(XD - GW, YF, WH)]
  P.push(`<path d="${pd([pr(XD + GW, YS, 0), pr(XD + GW + 26, YS, 0), pr(XD + GW + 26, YF + 14, 0), pr(XD + GW, YF + 14, 0)])}" fill="#0B0E07" opacity=".3" filter="url(#soft)"/>`, poly(wing, '#9A8C76'))
  for (let y = YF - rowH, row = 0; y > YF - WH * t - rowH; y -= rowH, row++) for (let x = XD - GW - (row % 2 ? 7 : 0); x < XD + GW;) {
    const w = 11 + rnd() * 11, c = mix('#B0A28E', rnd() > .5 ? '#3A362F' : '#E8E2D4', rnd() * .25), x0 = Math.max(XD - GW, x), x1 = Math.min(XD + GW, x + w), y0 = Math.max(YF - WH * t, y)
    if (x1 > x0 + 2) P.push(`<rect x="${f(x0 + 1)}" y="${f(y0 + .7)}" width="${f(x1 - x0 - 2)}" height="${f(Math.max(1, y + rowH - y0 - 1.4))}" rx="2.5" fill="${c}" stroke="${dark(c, .5)}" stroke-width=".9"/>`)
    x += w
  }
  P.push(poly(wing, 'none'))
  const wdoor = [pr(XD - 14, YF, 0), pr(XD + 14, YF, 0), pr(XD + 14, YF, WH * .8), pr(XD - 14, YF, WH * .8)]
  P.push(poly(wdoor, '#6E4A2A', INK, 1.8), `<path d="M${XD} ${f(wdoor[2][1])}L${XD} ${YF}" stroke="${INK}" stroke-width="1.1" opacity=".6"/>`, poly([[XD - 21, YF], [XD + 21, YF], [XD + 21, YF + 6], [XD - 21, YF + 6]], '#A8A196', INK, 1.3))
  LI.push(`<ellipse cx="${XD}" cy="${YF + 14}" rx="40" ry="14" fill="#FFC861" opacity=".35" filter="url(#glow)"/>`)
  P.push(poly([...gab, pr(XD + GW, YF, WH - 4), pr(XD - GW, YF, WH - 4)], '#5A3C24'))
  const gTop = pr(XD, YF, ZG)[1], gBot = pr(0, YF, WH)[1]
  for (let x = XD - GW; x < XD + GW; x += 10) {
    const h = 1 - Math.abs(x + 5 - XD) / GW, top = gBot - (gBot - gTop) * Math.max(0, h), c = mix('#5A3C24', rnd() > .5 ? '#1E120A' : '#B8946A', rnd() * .18)
    P.push(`<rect x="${f(x)}" y="${f(top)}" width="10" height="${f(gBot - top)}" fill="${c}" stroke="${dark(c, .5)}" stroke-width=".9"/>`)
  }
  P.push(poly(gab, 'none'))
  const gwY = gBot - (gBot - gTop) * .4, gr = 11, sq = Math.min(1, t * 2.4)
  const cross = `<path d="M${XD - gr} ${f(gwY)}h${gr * 2}M${XD} ${f(gwY - gr * sq)}v${f(gr * sq * 2)}" stroke="#3E2816" stroke-width="2"/>`
  P.push(`<ellipse cx="${XD}" cy="${f(gwY)}" rx="${gr + 3}" ry="${f((gr + 3) * sq)}" fill="#3E2816" stroke="${INK}" stroke-width="1.6"/>`, `<ellipse cx="${XD}" cy="${f(gwY)}" rx="${gr}" ry="${f(gr * sq)}" fill="#2F3E46"/>`, cross)
  LI.push(`<ellipse cx="${XD}" cy="${f(gwY)}" rx="${gr + 12}" ry="${f((gr + 12) * sq)}" fill="#FFC861" opacity=".55" filter="url(#glow)"/>`, `<ellipse cx="${XD}" cy="${f(gwY)}" rx="${gr}" ry="${f(gr * sq)}" fill="url(#lit)"/>`, cross)
  for (const s of [-1, 1]) {                                     // each little slope: eave corner, ridge front, where its ridge meets the roof
    const quad = [pr(XD + s * (GW + GO), YF + GO, WH), pr(XD, YF + GO, ZG), pr(XD, YG, ZG), pr(XD + s * (GW + GO), YS + OV, WH)]
    P.push(poly(quad, s < 0 ? '#8E9A66' : '#5E6A40'))
    for (let k = 1; k < 6; k++) {                                // shingle courses parallel to its eave
      const a = k / 6, [A, B, C, D] = quad, p0 = [A[0] + (B[0] - A[0]) * a, A[1] + (B[1] - A[1]) * a], p1 = [D[0] + (C[0] - D[0]) * a, D[1] + (C[1] - D[1]) * a]
      P.push(`<path d="M${f(p0[0])} ${f(p0[1])}L${f(p1[0])} ${f(p1[1])}" stroke="${s < 0 ? '#5E6A40' : '#3A4426'}" stroke-width="1.6"/>`)
    }
    if (rnd() > .3) { const [mx, my] = pr(XD + s * GW * .45, YS + 4, ZG - 18); P.push(`<ellipse cx="${f(mx)}" cy="${f(my)}" rx="9" ry="6" fill="${s < 0 ? '#9AB858' : '#6F8A3C'}"/>`) }
    P.push(poly(quad, 'none', INK, 2))
  }
  P.push(poly([pr(XD - 4, YF + GO + 2, ZG), pr(XD + 4, YF + GO + 2, ZG), pr(XD + 4, YG, ZG), pr(XD - 4, YG, ZG)], '#6E5A3A', INK, 1.4))
  P.push(poly([pr(XD - GW - GO - 2, YF + GO, WH - 2), pr(XD, YF + GO, ZG + 2), pr(XD + GW + GO + 2, YF + GO, WH - 2), pr(XD + GW + GO + 2, YF + GO, WH - 9), pr(XD, YF + GO, ZG - 5), pr(XD - GW - GO - 2, YF + GO, WH - 9)], '#6E4A2A', INK, 1.5))  // barge boards

  // the ridge cap
  P.push(poly([pr(XL - 3, YR - 6, ZR), pr(XE + 3, YR - 6, ZR), pr(XE + 3, YR + 6, ZR), pr(XL - 3, YR + 6, ZR)], '#6E6658', INK, 2), poly([pr(XL, YR - 4, ZR), pr(XE, YR - 4, ZR), pr(XE, YR - 1, ZR), pr(XL, YR - 1, ZR)], '#A49A86', null))
  for (let x = XL + 20; x < XE; x += 22) P.push(`<path d="M${x} ${f(pr(0, YR - 6, ZR)[1])}v12" stroke="${INK}" stroke-width="1" opacity=".5"/>`)

  // windows set into the front slope (stage 4 on): a wooden frame, glass that lights up after dark
  for (const [wx, wu] of S >= 5 ? [[XL + 62, .5], [XE - 60, .3]] : S >= 4 ? [[XL + 62, .5]] : []) {
    const q = [south(wx - 13, wu), south(wx + 13, wu), south(wx + 13, wu + .17), south(wx - 13, wu + .17)]
    const g = [south(wx - 9, wu + .03), south(wx + 9, wu + .03), south(wx + 9, wu + .14), south(wx - 9, wu + .14)]
    const bar = `<path d="M${wx} ${f(g[0][1])}V${f(g[2][1])}" stroke="#6E4A2A" stroke-width="2"/>`
    P.push(poly(q, '#6E4A2A', INK, 1.6), poly(g, '#3A5260', null), bar)
    LI.push(`<ellipse cx="${wx}" cy="${f((g[0][1] + g[2][1]) / 2)}" rx="22" ry="16" fill="#FFC861" opacity=".55" filter="url(#glow)"/>`, poly(g, 'url(#lit)', null), bar)
  }
  // things around the front: a woodpile, a barrel, a bush, flower pots, a lantern
  const pile = (x, y) => { const o = [poly([[x - 18, y + 8], [x + 18, y + 8], [x + 18, y - 6], [x - 18, y - 6]], '#7A5434', INK, 1.4)]; for (let k = 0; k < 6; k++) { const lx = x - 12 + (k % 3) * 12, ly = y - 1 - Math.floor(k / 3) * 6; o.push(`<circle cx="${lx}" cy="${ly}" r="5" fill="#C99A62" stroke="${INK}" stroke-width="1.2"/><circle cx="${lx}" cy="${ly}" r="2" fill="#8E6438"/>`) } return o.join('') }
  const barrel = (x, y) => `<ellipse cx="${x + 4}" cy="${y + 6}" rx="16" ry="8" fill="#0B0E07" opacity=".3"/><ellipse cx="${x}" cy="${y}" rx="14" ry="11" fill="#8A5E36" stroke="${INK}" stroke-width="1.6"/><ellipse cx="${x}" cy="${y}" rx="10" ry="8" fill="#6E4A2A" stroke="#3E3229" stroke-width="2"/><ellipse cx="${x - 3}" cy="${y - 2}" rx="5" ry="3" fill="#9FB8C4" opacity=".7"/>`
  const bush = (x, y, r) => `<ellipse cx="${x + 4}" cy="${y + 5}" rx="${r + 2}" ry="${r * .7}" fill="#0B0E07" opacity=".3"/><circle cx="${x}" cy="${y}" r="${r}" fill="#4E7A30" stroke="${INK}" stroke-width="1.5"/><circle cx="${x - r * .3}" cy="${y - r * .3}" r="${r * .55}" fill="#6E9A40"/><circle cx="${x + r * .25}" cy="${y - r * .1}" r="2.5" fill="#F2D06A"/><circle cx="${x - r * .45}" cy="${y + r * .2}" r="2.5" fill="#F29A9A"/>`
  const pot = (x, y, c) => `<circle cx="${x}" cy="${y}" r="7" fill="#B8643E" stroke="${INK}" stroke-width="1.3"/><circle cx="${x}" cy="${y - 1}" r="5" fill="#5E8A34"/><circle cx="${x - 1.5}" cy="${y - 2}" r="2.2" fill="${c}"/>`
  if (S === 1) P.push(pile(X1 + 4, 372))
  if (S >= 2) P.push(barrel(X1 - 16, 368))
  if (S >= 3) P.push(bush(X0 + 18, 368, 13))
  if (S >= 4) P.push(pot(XD - GW - 10, YF - 2, '#F2D06A'), pot(XD + GW + 10, YF - 2, '#E87A8A'))
  if (S >= 5) { P.push(`<path d="M${X0 + 50} 384v-26" stroke="#3E3229" stroke-width="3"/><rect x="${X0 + 44}" y="350" width="12" height="12" rx="2" fill="#6A6458" stroke="${INK}" stroke-width="1.4"/><rect x="${X0 + 47}" y="353" width="6" height="6" fill="#E8C878"/>`)
    LI.push(`<ellipse cx="${X0 + 50}" cy="370" rx="30" ry="18" fill="#FFC861" opacity=".5" filter="url(#glow)"/><rect x="${X0 + 47}" y="353" width="6" height="6" fill="#FFF1B8"/>`) }
  // the chimneys: stone stacks through the front slope near the ridge; their front face and cap seen from above
  const smokes = []
  for (const CX of S >= 5 ? [X1 - 58, X0 + 44] : [X1 - 58]) {
  const CY = YR + 26, CZ = ZR + 26, cw = 14
  const cb = zSouth(CY + cw)
  P.push(`<path d="${pd([pr(CX - cw, CY + cw, cb), pr(CX + cw, CY + cw, cb), pr(CX + cw + 34, CY + cw + 26, cb - 20), pr(CX - cw + 34, CY + cw + 26, cb - 20)])}" fill="#0B0E07" opacity=".28"/>`)
  const face = [pr(CX - cw, CY + cw, cb), pr(CX + cw, CY + cw, cb), pr(CX + cw, CY + cw, CZ), pr(CX - cw, CY + cw, CZ)]
  P.push(poly(face, '#8E867A'))
  for (let z = cb + 7, r = 0; z < CZ; z += 7, r++) { const y = f(pr(0, CY + cw, z)[1]), v = f(-7 * t)
    P.push(`<path d="M${CX - cw} ${y}h${cw * 2}${r % 2 ? `M${CX} ${y}v${v}` : `M${CX - 7} ${y}v${v}M${CX + 7} ${y}v${v}`}" stroke="#5E584E" stroke-width="1"/>`) }
  P.push(poly(face, 'none', INK, 1.8))
  P.push(poly([pr(CX - cw - 3, CY - cw - 3, CZ), pr(CX + cw + 3, CY - cw - 3, CZ), pr(CX + cw + 3, CY + cw + 3, CZ), pr(CX - cw - 3, CY + cw + 3, CZ)], '#B5AEA3'))
  P.push(poly([pr(CX - 8, CY - 8, CZ), pr(CX + 8, CY - 8, CZ), pr(CX + 8, CY + 8, CZ), pr(CX - 8, CY + 8, CZ)], '#1C1814', null))
  const sm = pr(CX, CY, CZ); smokes.push([+(sm[0] / 100).toFixed(2), +(sm[1] / 100).toFixed(2)])
  }
  // the weathervane on the ridge, toward the west end (stage 3 on)
  const [vx, vy] = pr(XL + 60, YR, ZR)
  if (S >= 3) P.push(`<path d="M${f(vx)} ${f(vy)}l0 ${f(-46 * t)}" stroke="#3E3229" stroke-width="2.5"/>`, `<path d="M${f(vx - 13)} ${f(vy - 40 * t)}l26 0l5 -4l-5 8l-26 0z" fill="#3E3229"/>`, `<circle cx="${f(vx)}" cy="${f(vy - 46 * t)}" r="2.5" fill="#3E3229"/>`)
  return { body: P.join(''), lights: LI.join(''), smoke: smokes }
}

const DEFS = `<defs><filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="6"/></filter><filter id="glow" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="8"/></filter><linearGradient id="lit" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF1B8"/><stop offset="1" stop-color="#FFB64E"/></linearGradient></defs>`
if (process.argv[1] && process.argv[1].endsWith('farmhouse-topdown.mjs')) {
  mkdirSync('web/public/mountain-ideas/farmhouses', { recursive: true })
  const chim = {}
  for (let st = 1; st <= 5; st++) { const h = farmhouse({ stage: st }); chim['building-farmhouse-' + st] = h.smoke
    writeFileSync(`tiles/building-farmhouse-${st}.svg`, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400" role="img" aria-label="Farmhouse, stage ${st} of 5">${DEFS}${h.body}</svg>\n`)
    writeFileSync(`tiles/building-farmhouse-${st}-lights.svg`, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400" role="img" aria-label="Farmhouse, stage ${st}: lit windows">${DEFS}${h.lights}</svg>\n`)
    writeFileSync(`web/public/mountain-ideas/farmhouses/stage-${st}-night.svg`, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400">${DEFS}${h.body}<rect width="300" height="400" fill="#0B1838" opacity=".58"/>${h.lights}</svg>\n`) }
  // keep the other buildings' chimneys in buildingArt.ts, replace the farmhouse's
  const AF = 'web/src/engine/buildingArt.ts', art = readFileSync(AF, 'utf8'), m = art.match(/CHIMNEYS: Record<string, \[number, number\]\[\]> = (\{.*\})/)
  const all = { ...JSON.parse(m[1]), ...chim }
  writeFileSync(AF, art.replace(m[1], JSON.stringify(all)).replace(/LIT = new Set\((\[.*\])\)/, (_, l) => 'LIT = new Set(' + JSON.stringify([...new Set([...JSON.parse(l), ...Object.keys(chim)])]) + ')'))
  const TILTS = [['A  Nearly straight down', .2], ['B  High', .32], ['C  A little lower', .45]]
  TILTS.forEach(([, tl], k) => { const h = farmhouse({ tilt: tl })
    writeFileSync(`web/public/mountain-ideas/farmhouses/top-${k + 1}.svg`, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400">${DEFS}${h.body}</svg>\n`)
    writeFileSync(`web/public/mountain-ideas/farmhouses/top-${k + 1}-night.svg`, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400">${DEFS}${h.body}<rect width="300" height="400" fill="#0B1838" opacity=".58"/>${h.lights}</svg>\n`) })
  writeFileSync('web/public/mountain-ideas/farmhouses-top.html', `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Farmhouse From Above</title>
<style>body{margin:0;background:#efe6d2;color:#2f2a22;font:15px/1.45 Georgia,serif}header{padding:28px 24px 8px;max-width:1300px;margin:0 auto}h1{margin:0 0 4px;font-size:26px}header p{margin:0;color:#7a6f5c}
main{display:grid;grid-template-columns:repeat(auto-fill,minmax(360px,1fr));gap:18px;padding:18px 24px 40px;max-width:1300px;margin:0 auto}figure{margin:0;background:#fbf7ee;border:1px solid #d9ccb2;border-radius:10px;overflow:hidden}
.yard{display:flex;justify-content:center;gap:14px;padding:18px;background:radial-gradient(circle at 30% 20%,#8fb35a,#6f9440)}.yard img{width:150px;height:200px}.night{background:#1d2a33}
figcaption{padding:10px 14px 12px}figcaption b{font-size:16px}figcaption div{color:#7a6f5c;font-size:14px}</style></head><body>
<header><h1>The mossy farmhouse, from above</h1><p>The same house drawn from its real shape at three camera heights: by day, and at night with its windows lit.</p></header><main>
${[1, 2, 3, 4, 5].map((st) => `<figure><div class="yard"><img src="../art/tiles/building-farmhouse-${st}.svg" alt=""><img class="night" src="farmhouses/stage-${st}-night.svg" alt=""></div><figcaption><b>Stage ${st}</b><div>${st} farmer${st > 1 ? 's live' : ' lives'} here.</div></figcaption></figure>`).join('')}
${TILTS.map(([n, tl], k) => `<figure><div class="yard"><img src="farmhouses/top-${k + 1}.svg" alt=""><img class="night" src="farmhouses/top-${k + 1}-night.svg" alt=""></div><figcaption><b>${n}</b><div>Tilt ${tl}: the front wall shows as ${tl < .25 ? 'a thin strip' : tl < .4 ? 'a narrow band' : 'a band you can read'}.</div></figcaption></figure>`).join('')}
</main></body></html>`)
  console.log('three tilts written')
}

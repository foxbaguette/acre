// Ten farmhouse ideas in the cozy hand-crafted top-down style (after the user's reference: chunky shingles with a lit
// top edge, plank gables, stone blocks, thin dark outlines). Each is a 3 x 4 tile plot (300 x 400 units).
// Writes web/public/mountain-ideas/farmhouses/fh-N.svg and the sheet web/public/mountain-ideas/farmhouses.html.
// Run from the Cute Fox folder: node tools/farmhouse-ideas.mjs
import { mkdirSync, writeFileSync } from 'node:fs'

const f = (n) => +n.toFixed(1)
let seed = 1
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647 }
const INK = '#2E241C'
const poly = (pts, fill, stroke = INK, sw = 2) => `<path d="M${pts.map(([x, y]) => `${f(x)} ${f(y)}`).join('L')}Z" fill="${fill}"${stroke ? ` stroke="${stroke}" stroke-width="${sw}" stroke-linejoin="round"` : ''}/>`
const box = (x, y, w, h, fill, stroke = INK, sw = 2, r = 0) => `<rect x="${f(x)}" y="${f(y)}" width="${f(w)}" height="${f(h)}"${r ? ` rx="${r}"` : ''} fill="${fill}"${stroke ? ` stroke="${stroke}" stroke-width="${sw}"` : ''}/>`
const mix = (a, b, t) => { const p = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)), A = p(a), B = p(b); return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * t).toString(16).padStart(2, '0')).join('') }
const dark = (c, t = .45) => mix(c, '#000000', t)
let clipN = 0
const clip = (clips, d) => { const id = 'c' + (++clipN); clips.push(`<clipPath id="${id}"><path d="${d}"/></clipPath>`); return id }
const pd = (pts) => 'M' + pts.map(([x, y]) => `${f(x)} ${f(y)}`).join('L') + 'Z'

// ---- materials: each fills a clipped area with its texture ----
const ROOFS = {
  slate: { base: '#A39C92', shade: '#6E685F', w: 26, h: 17, r: 3, moss: .08 },
  blue: { base: '#7E93A6', shade: '#55667A', w: 24, h: 16, r: 3, moss: .04 },
  clay: { base: '#C9693F', shade: '#8E4127', w: 20, h: 16, r: 8, moss: .03 },
  shake: { base: '#A0703F', shade: '#6E4A26', w: 18, h: 22, r: 2, moss: .06 },
  moss: { base: '#8F9A6A', shade: '#5E6A42', w: 26, h: 17, r: 4, moss: .3 },
  thatch: { base: '#D9B866', shade: '#A9853A', w: 34, h: 20, r: 10, moss: .05 },
}
function roofTex(id, x0, y0, x1, y1, kind, lit) {
  const m = ROOFS[kind], out = [], base = lit ? m.base : m.shade
  for (let row = 0, y = y0 - 4; y < y1 + m.h; row++, y += m.h - (kind === 'thatch' ? 7 : 4)) for (let x = x0 - (row % 2 ? m.w / 2 : 0); x < x1 + m.w; x += m.w - 1) {
    const c = mix(base, rnd() > .5 ? '#2A2622' : '#F2EAD6', rnd() * .2), ww = m.w - 1 - rnd() * 3
    if (kind === 'thatch') {                                            // straw bundles: rounded at the bottom, streaked
      out.push(`<path d="M${f(x)} ${f(y)}L${f(x + ww)} ${f(y)}L${f(x + ww)} ${f(y + m.h - 8)}Q${f(x + ww / 2)} ${f(y + m.h + 4)} ${f(x)} ${f(y + m.h - 8)}Z" fill="${c}" stroke="${dark(c, .4)}" stroke-width="1.3"/>`)
      for (let s = 0; s < 4; s++) out.push(`<path d="M${f(x + 5 + s * ww / 4.5)} ${f(y + 3)}l0 ${f(m.h - 8)}" stroke="${dark(c, .25)}" stroke-width="1.2" opacity=".6"/>`)
    } else if (kind === 'clay') {                                       // round-ended clay tiles
      out.push(`<path d="M${f(x)} ${f(y)}L${f(x + ww)} ${f(y)}L${f(x + ww)} ${f(y + m.h - 6)}Q${f(x + ww / 2)} ${f(y + m.h + 3)} ${f(x)} ${f(y + m.h - 6)}Z" fill="${c}" stroke="${dark(c)}" stroke-width="1.3"/>`)
      out.push(`<rect x="${f(x + 3)}" y="${f(y + 2)}" width="3" height="${m.h - 8}" rx="1.5" fill="#FFFFFF" opacity=".25"/>`)
    } else {
      out.push(`<rect x="${f(x)}" y="${f(y)}" width="${f(ww)}" height="${m.h}" rx="${m.r}" fill="${c}" stroke="${dark(c)}" stroke-width="1.3"/>`)
      out.push(`<rect x="${f(x + 2.5)}" y="${f(y + 1.5)}" width="${f(ww - 5)}" height="2.5" rx="1.2" fill="#FFFFFF" opacity="${kind === 'shake' ? .14 : .22}"/>`)
      if (kind === 'shake') out.push(`<path d="M${f(x + ww * .4)} ${f(y + 4)}l0 ${m.h - 6}" stroke="${dark(c, .3)}" stroke-width="1"/>`)
    }
    if (rnd() < m.moss) out.push(`<ellipse cx="${f(x + ww / 2)}" cy="${f(y + m.h * .6)}" rx="${f(ww * .35)}" ry="4" fill="#7E9A4C" opacity=".7"/>`)
  }
  return `<g clip-path="url(#${id})">${out.join('')}</g>`
}
function wallTex(id, x0, y0, x1, y1, kind) {
  const out = []
  if (kind === 'stone' || kind === 'cobble') {
    const bh = kind === 'cobble' ? 11 : 13
    for (let row = 0, y = y0; y < y1; row++, y += bh) for (let x = x0 - (row % 2 ? 9 : 0); x < x1;) {
      const w = (kind === 'cobble' ? 12 : 16) + rnd() * 12, c = mix(kind === 'cobble' ? '#B0A28E' : '#A8A196', rnd() > .5 ? '#3A362F' : '#E8E2D4', rnd() * .25)
      out.push(`<rect x="${f(x + 1)}" y="${f(y + 1)}" width="${f(w - 2)}" height="${bh - 2}" rx="${kind === 'cobble' ? 4.5 : 2.5}" fill="${c}" stroke="${dark(c, .5)}" stroke-width="1.2"/>`, `<rect x="${f(x + 3)}" y="${f(y + 2.5)}" width="${f(w - 7)}" height="2" rx="1" fill="#FFFFFF" opacity=".2"/>`)
      x += w
    }
  } else if (kind === 'plank' || kind === 'darkplank') {
    for (let x = x0; x < x1; x += 13) { const c = mix(kind === 'plank' ? '#B07E46' : '#7A5434', rnd() > .5 ? '#3A2414' : '#E8C89A', rnd() * .16)
      out.push(`<rect x="${f(x)}" y="${f(y0)}" width="13" height="${f(y1 - y0)}" fill="${c}" stroke="${dark(c, .5)}" stroke-width="1.2"/>`, `<rect x="${f(x + 2)}" y="${f(y0)}" width="2" height="${f(y1 - y0)}" fill="#FFFFFF" opacity=".12"/>`) }
  } else if (kind === 'log') {
    for (let y = y0; y < y1; y += 12) { const c = mix('#9A6B3F', rnd() > .5 ? '#3A2414' : '#E8C89A', rnd() * .15)
      out.push(`<rect x="${f(x0 - 4)}" y="${f(y)}" width="${f(x1 - x0 + 8)}" height="12" rx="6" fill="${c}" stroke="${dark(c, .5)}" stroke-width="1.3"/>`, `<rect x="${f(x0)}" y="${f(y + 2)}" width="${f(x1 - x0)}" height="2.5" rx="1.2" fill="#FFFFFF" opacity=".16"/>`) }
  } else if (kind === 'plaster' || kind === 'white') {                 // plaster between timber
    out.push(`<rect x="${x0}" y="${y0}" width="${x1 - x0}" height="${y1 - y0}" fill="${kind === 'white' ? '#F2EEE4' : '#EAD9B6'}"/>`)
    for (let k = 0; k < 14; k++) out.push(`<ellipse cx="${f(x0 + rnd() * (x1 - x0))}" cy="${f(y0 + rnd() * (y1 - y0))}" rx="${f(4 + rnd() * 8)}" ry="${f(2 + rnd() * 3)}" fill="#000000" opacity=".04"/>`)
    for (let x = x0; x <= x1; x += (x1 - x0) / 4) out.push(`<rect x="${f(x - 3)}" y="${y0}" width="6" height="${y1 - y0}" fill="#6B4A30" stroke="${INK}" stroke-width="1"/>`)
    out.push(`<rect x="${x0}" y="${f((y0 + y1) / 2 - 3)}" width="${x1 - x0}" height="6" fill="#6B4A30" stroke="${INK}" stroke-width="1"/>`)
  }
  return `<g clip-path="url(#${id})">${out.join('')}</g>`
}
// ---- small things ----
const pot = (x, y) => [`<ellipse cx="${x + 4}" cy="${y + 12}" rx="13" ry="5" fill="#0B0E07" opacity=".3"/>`, poly([[x - 10, y - 6], [x + 10, y - 6], [x + 7, y + 10], [x - 7, y + 10]], '#B5653A'), box(x - 12, y - 9, 24, 5, '#C9784A', INK, 1.6, 1.5),
  ...[[-6, -14], [0, -18], [6, -14], [-2, -11], [4, -10]].map(([dx, dy], k) => `<circle cx="${x + dx}" cy="${y + dy}" r="5.5" fill="${k % 2 ? '#5E8C45' : '#7DAA55'}" stroke="${INK}" stroke-width="1.2"/>`),
  ...[[-5, -16], [3, -19], [6, -12]].map(([dx, dy]) => `<circle cx="${x + dx}" cy="${y + dy}" r="2.4" fill="#F4E27A"/>`)]
const bush = (x, y, r, flowers) => [`<ellipse cx="${x + r * .3}" cy="${y + r * .5}" rx="${r}" ry="${r * .6}" fill="#0B0E07" opacity=".3"/>`,
  ...[[0, 0, 1], [-.5, .2, .7], [.5, .25, .7], [0, -.4, .7]].map(([dx, dy, s], k) => `<circle cx="${f(x + dx * r)}" cy="${f(y + dy * r)}" r="${f(r * s * .75)}" fill="${['#6E9E4E', '#5E8C45', '#7DAA55', '#86B85C'][k]}" stroke="${INK}" stroke-width="1.3"/>`),
  ...(flowers ? Array.from({ length: 5 }, (_, k) => `<circle cx="${f(x + (rnd() - .5) * r * 1.3)}" cy="${f(y + (rnd() - .6) * r)}" r="2.6" fill="${flowers}"/>`) : [])]
const barrel = (x, y) => [`<ellipse cx="${x + 4}" cy="${y + 14}" rx="13" ry="5" fill="#0B0E07" opacity=".3"/>`, box(x - 11, y - 12, 22, 26, '#8A5A33', INK, 1.8, 4), box(x - 11, y - 6, 22, 3, '#3E3229', null), box(x - 11, y + 6, 22, 3, '#3E3229', null), `<ellipse cx="${x}" cy="${y - 12}" rx="11" ry="4" fill="#A9773F" stroke="${INK}" stroke-width="1.6"/>`]
const window_ = (cx, y, w = 22, h = 18, frame = '#7A5230', shutters = null) => [
  ...(shutters ? [box(cx - w / 2 - 13, y - 2, 9, h + 8, shutters, INK, 1.4, 1), box(cx + w / 2 + 4, y - 2, 9, h + 8, mix(shutters, '#000000', .15), INK, 1.4, 1)] : []),
  box(cx - w / 2 - 4, y - 4, w + 8, h + 8, frame, INK, 2, 2), box(cx - w / 2, y, w, h, '#2F3E46', null), box(cx - 1, y, 2, h, frame, null), box(cx - w / 2, y + h / 2 - 1, w, 2, frame, null),
  `<path d="M${cx - w / 2 + 3} ${y + 5}L${cx - 2} ${y + 3}" stroke="#FFFFFF" stroke-opacity=".35" stroke-width="2"/>`, box(cx - w / 2 - 6, y + h + 4, w + 12, 5, '#8E867A', INK, 1.4, 1.5)]
const door = (clips, cx, top, bottom, w = 36, arch = true, color = '#8A5A33') => {
  const d = arch ? `M${cx - w / 2} ${bottom}L${cx - w / 2} ${top + 12}Q${cx} ${top - 6} ${cx + w / 2} ${top + 12}L${cx + w / 2} ${bottom}Z` : pd([[cx - w / 2, top], [cx + w / 2, top], [cx + w / 2, bottom], [cx - w / 2, bottom]])
  const id = clip(clips, d), out = [`<path d="${d}" fill="${color}"/>`, `<g clip-path="url(#${id})">`]
  for (let x = cx - w / 2; x < cx + w / 2; x += 9) out.push(`<rect x="${f(x)}" y="${top - 10}" width="9" height="${bottom - top + 10}" fill="${mix(color, rnd() > .5 ? '#000000' : '#FFFFFF', rnd() * .12)}" stroke="${dark(color, .5)}" stroke-width="1"/>`)
  out.push('</g>', box(cx - w / 2, top + 16, w, 3.5, '#3E3229', null), box(cx - w / 2, bottom - 14, w, 3.5, '#3E3229', null), `<path d="${d}" fill="none" stroke="${INK}" stroke-width="2"/>`, `<circle cx="${cx + w / 2 - 9}" cy="${(top + bottom) / 2 + 4}" r="3" fill="none" stroke="#C9A24B" stroke-width="2"/>`)
  return out
}
const chimney = (clips, cx, cy, kind = 'stone') => {
  const id = clip(clips, pd([[cx - 15, cy], [cx + 15, cy], [cx + 15, cy + 50], [cx - 15, cy + 50]]))
  return [`<path d="M${cx + 12} ${cy + 44}L${cx + 50} ${cy + 62}L${cx + 50} ${cy + 44}L${cx + 16} ${cy + 28}Z" fill="#0B0E07" opacity=".3"/>`,
    box(cx - 15, cy, 30, 50, kind === 'brick' ? '#A1503A' : '#8E867A'), kind === 'brick' ? brickTex(id, cx - 15, cy, cx + 15, cy + 50) : wallTex(id, cx - 15, cy, cx + 15, cy + 50, 'stone'),
    `<rect x="${cx}" y="${cy}" width="15" height="50" fill="#1C1A20" opacity=".2"/>`, box(cx - 15, cy, 30, 50, 'none'), box(cx - 19, cy - 8, 38, 10, kind === 'brick' ? '#B9644A' : '#B5AEA3', INK, 2, 2), `<ellipse cx="${cx}" cy="${cy - 4}" rx="9" ry="3" fill="#1C1814"/>`,
    ...[0, 1, 2].map((k) => `<circle cx="${cx + 6 + k * 9}" cy="${cy - 18 - k * 14}" r="${7 + k * 3}" fill="#E8E6E2" opacity="${.75 - k * .2}"/>`)]   // a wisp of smoke
}
function brickTex(id, x0, y0, x1, y1) { const out = []
  for (let row = 0, y = y0; y < y1; row++, y += 7) for (let x = x0 - (row % 2 ? 6 : 0); x < x1; x += 12) { const c = mix('#A1503A', rnd() > .5 ? '#000000' : '#F2C2A0', rnd() * .18); out.push(`<rect x="${f(x)}" y="${f(y)}" width="11" height="6" fill="${c}" stroke="${dark(c, .4)}" stroke-width=".8"/>`) }
  return `<g clip-path="url(#${id})">${out.join('')}</g>` }

// ---- a house with its gable to the front (ridge north-south), like the reference ----
function frontGable(o) {
  const P = [], clips = [], WL = 150 - o.half, WR = 150 + o.half, L = WL - 14, R = WR + 14, TOP = 30, RE = 200, EAVE = 292, GB = o.gableTo ?? 316, WB = 370
  P.push(`<path d="M${L + 24} ${TOP + 26}L${R + 18} ${TOP + 26}L${R + 18} ${WB + 12}L${L + 30} ${WB + 12}Z" fill="#0B0E07" opacity=".35" filter="url(#soft)"/>`)
  if (o.lean) {                                                         // a lean-to shed on the east side
    const sx0 = WR - 6, sx1 = 292, sy = 214
    const s1 = clip(clips, pd([[sx0, sy], [sx1, sy + 16], [sx1, 292], [sx0, 292]]))
    P.push(box(sx0, 292, sx1 - sx0, WB - 292, '#7A5434'), wallTex(clip(clips, pd([[sx0, 292], [sx1, 292], [sx1, WB], [sx0, WB]])), sx0, 292, sx1, WB, 'darkplank'), box(sx0, 292, sx1 - sx0, WB - 292, 'none'))
    P.push(poly([[sx0, sy], [sx1, sy + 16], [sx1, 292], [sx0, 292]], ROOFS[o.roof].shade), roofTex(s1, sx0, sy, sx1, 292, o.roof, false), poly([[sx0, sy], [sx1, sy + 16], [sx1, 292], [sx0, 292]], 'none', INK, 2.2))
    P.push(box(sx0 + 10, 304, 26, 50, '#4A3A2A', INK, 2), `<path d="M${sx0 + 12} 306L${sx0 + 34} 352M${sx0 + 34} 306L${sx0 + 12} 352" stroke="#7A5434" stroke-width="3"/>`)
  }
  const gable = [[WL, EAVE - 2], [150, RE + 6], [WR, EAVE - 2], [WR, GB], [WL, GB]]
  P.push(poly(gable, '#A9773F'), wallTex(clip(clips, pd(gable)), WL, RE, WR, GB, o.gable ?? 'plank'), poly(gable, 'none'))
  P.push(box(WL - 2, GB - 4, WR - WL + 4, 8, '#7A5230', INK, 2, 2))
  P.push(box(WL, GB + 4, WR - WL, WB - GB - 4, '#9C958A'), wallTex(clip(clips, pd([[WL, GB + 4], [WR, GB + 4], [WR, WB], [WL, WB]])), WL, GB + 4, WR, WB, o.wall), `<rect x="${WR - 26}" y="${GB + 4}" width="26" height="${WB - GB - 4}" fill="#1C1A20" opacity=".18"/>`, box(WL, GB + 4, WR - WL, WB - GB - 4, 'none'))
  const gy = (RE + GB) / 2 + 14
  if (o.roundWin !== false) P.push(`<circle cx="150" cy="${gy}" r="18" fill="#7A5230" stroke="${INK}" stroke-width="2"/>`, `<circle cx="150" cy="${gy}" r="13" fill="#2F3E46"/>`, box(148.5, gy - 13, 3, 26, '#7A5230', null), box(137, gy - 1.5, 26, 3, '#7A5230', null))
  else P.push(...window_(150, gy - 10, 24, 20, '#7A5230', o.shutters))
  for (const x of o.windows ?? [WL + 38, WR - 38]) P.push(...window_(x, GB + 18, 22, 18, o.frame ?? '#7A5230', o.shutters))
  P.push(...door(clips, o.doorX ?? 150, GB + 6, WB, 36, o.arch !== false, o.doorColor ?? '#8A5A33'), box((o.doorX ?? 150) - 26, WB, 52, 8, '#A8A196', INK, 1.6, 2))
  if (o.porch) { const dx = o.doorX ?? 150
    P.push(box(dx - 34, GB - 2, 4, WB - GB + 2, '#7A5230', INK, 1.4), box(dx + 30, GB - 2, 4, WB - GB + 2, '#7A5230', INK, 1.4), poly([[dx - 44, GB + 4], [dx + 44, GB + 4], [dx + 38, GB - 14], [dx - 38, GB - 14]], ROOFS[o.roof].base), poly([[dx, GB + 4], [dx + 44, GB + 4], [dx + 38, GB - 14], [dx, GB - 14]], ROOFS[o.roof].shade)) }
  const rl = [[L, TOP + 10], [150, TOP], [150, RE], [L, EAVE]], rr = [[150, TOP], [R, TOP + 10], [R, EAVE], [150, RE]]
  P.push(poly(rl, ROOFS[o.roof].base), roofTex(clip(clips, pd(rl)), L, TOP, 150, EAVE, o.roof, true), poly(rr, ROOFS[o.roof].shade), roofTex(clip(clips, pd(rr)), 150, TOP, R, EAVE, o.roof, false))
  P.push(poly(rl, 'none', INK, 2.4), poly(rr, 'none', INK, 2.4), box(144, TOP - 4, 12, RE - TOP + 6, o.ridge ?? '#7A5230', INK, 2, 3))
  P.push(poly([[L - 6, EAVE - 2], [150, RE - 6], [R + 6, EAVE - 2], [R + 6, EAVE + 8], [150, RE + 6], [L - 6, EAVE + 8]], o.barge ?? '#8A5A33', INK, 2.2))
  if (o.dormer) for (const [x, sun] of o.dormer) { const y = 100
    P.push(poly([[x, y + 20], [x + 22, y + 2], [x + 44, y + 20], [x + 44, y + 46], [x, y + 46]], sun ? '#B07E46' : '#8E6236'), box(x + 10, y + 24, 24, 18, '#2F3E46', INK, 2, 2), box(x + 21, y + 24, 2, 18, '#7A5230', null))
    P.push(poly([[x - 6, y + 22], [x + 22, y - 4], [x + 50, y + 22], [x + 46, y + 26], [x + 22, y + 4], [x - 2, y + 26]], sun ? ROOFS[o.roof].base : ROOFS[o.roof].shade)) }
  P.push(...chimney(clips, o.chimX ?? WR - 44, TOP + 34, o.chim))
  if (o.vane) P.push(box(148.5, TOP - 30, 3, 26, '#3E3229', null), poly([[136, TOP - 28], [162, TOP - 28], [168, TOP - 32], [162, TOP - 24], [136, TOP - 24]], '#3E3229', null))
  for (const e of o.extras ?? []) P.push(...e)
  return { P, clips }
}
// ---- a house with its long side to the front (ridge east-west): the whole south slope shows ----
function sideGable(o) {
  const P = [], clips = [], WL = 18, WR = 282, L = 6, R = 294, TOP = 36, RY = 110, EAVE = 262, WB = 368
  P.push(`<path d="M${L + 24} ${TOP + 26}L${R + 14} ${TOP + 26}L${R + 14} ${WB + 12}L${L + 30} ${WB + 12}Z" fill="#0B0E07" opacity=".35" filter="url(#soft)"/>`)
  P.push(box(WL, EAVE - 8, WR - WL, WB - EAVE + 8, '#9C958A'), wallTex(clip(clips, pd([[WL, EAVE - 8], [WR, EAVE - 8], [WR, WB], [WL, WB]])), WL, EAVE - 8, WR, WB, o.wall), `<rect x="${WR - 40}" y="${EAVE - 8}" width="40" height="${WB - EAVE + 8}" fill="#1C1A20" opacity=".16"/>`, box(WL, EAVE - 8, WR - WL, WB - EAVE + 8, 'none'))
  P.push(box(WL, EAVE - 8, WR - WL, 16, '#2B2620', null, 0), )
  for (const x of o.windows ?? [66, 234]) P.push(...window_(x, EAVE + 26, 26, 22, o.frame ?? '#7A5230', o.shutters))
  P.push(...door(clips, o.doorX ?? 150, EAVE + 22, WB, 38, o.arch !== false, o.doorColor ?? '#8A5A33'), box((o.doorX ?? 150) - 27, WB, 54, 8, '#A8A196', INK, 1.6, 2))
  if (o.porch) { const dx = o.doorX ?? 150
    P.push(box(dx - 40, EAVE + 6, 5, WB - EAVE - 6, '#7A5230', INK, 1.4), box(dx + 35, EAVE + 6, 5, WB - EAVE - 6, '#7A5230', INK, 1.4), poly([[dx - 50, EAVE + 14], [dx + 50, EAVE + 14], [dx + 44, EAVE - 6], [dx - 44, EAVE - 6]], ROOFS[o.roof].base)) }
  const north = [[L + 10, TOP], [R - 10, TOP], [R - 4, RY], [L + 4, RY]], south = [[L + 4, RY], [R - 4, RY], [R, EAVE], [L, EAVE]]
  P.push(poly(north, ROOFS[o.roof].base), roofTex(clip(clips, pd(north)), L, TOP, R, RY, o.roof, true), poly(south, mix(ROOFS[o.roof].base, ROOFS[o.roof].shade, .35)), roofTex(clip(clips, pd(south)), L, RY, R, EAVE, o.roof, true))
  P.push(`<path d="${pd(south)}" fill="#1C1A20" opacity=".1"/>`, poly(north, 'none', INK, 2.4), poly(south, 'none', INK, 2.4), box(L, RY - 6, R - L, 12, o.ridge ?? '#7A5230', INK, 2, 3))
  if (o.dormer) for (const x of o.dormer) { const y = RY + 46
    P.push(poly([[x, y + 20], [x + 24, y], [x + 48, y + 20], [x + 48, y + 52], [x, y + 52]], '#B07E46'), box(x + 11, y + 26, 26, 20, '#2F3E46', INK, 2, 2), box(x + 23, y + 26, 2, 20, '#7A5230', null))
    P.push(poly([[x - 6, y + 22], [x + 24, y - 6], [x + 54, y + 22], [x + 50, y + 26], [x + 24, y + 2], [x - 2, y + 26]], ROOFS[o.roof].base)) }
  P.push(...chimney(clips, o.chimX ?? 230, TOP + 10, o.chim))
  for (const e of o.extras ?? []) P.push(...e)
  return { P, clips }
}

const IDEAS = [
  ['Slate & stone', 'Your reference: grey slate, a plank gable with a round window, a stone ground floor.', () => frontGable({ half: 112, roof: 'slate', wall: 'stone', extras: [pot(96, 360), bush(262, 360, 16, '#F4E27A')] })],
  ['Red clay cottage', 'Warm clay tiles over white timber-framed plaster, green shutters.', () => frontGable({ half: 112, roof: 'clay', wall: 'white', gable: 'white', shutters: '#6E9455', roundWin: false, extras: [bush(40, 362, 15, '#F28CA3'), bush(262, 362, 15, '#FFFFFF')] })],
  ['Thatched cottage', 'A thick straw roof in bundles, plaster walls, a red door.', () => frontGable({ half: 110, roof: 'thatch', wall: 'plaster', gable: 'plaster', doorColor: '#A84A3A', ridge: '#C9A24B', barge: '#B08A3E', extras: [pot(96, 360), pot(204, 360)] })],
  ['Log farmhouse', 'A homestead of round logs under wooden shakes, a lean-to shed on the side.', () => frontGable({ half: 96, roof: 'shake', wall: 'log', gable: 'log', lean: true, doorX: 136, windows: [94], chimX: 100, extras: [barrel(30, 356)] })],
  ['Long farmhouse', 'The long side faces you: a deep slate roof, two windows and a porch.', () => sideGable({ roof: 'slate', wall: 'stone', porch: true, extras: [pot(30, 360), bush(272, 360, 15, '#C99AE0')] })],
  ['Blue slate & brick', 'Cool blue slate, a brick chimney, cream plaster and timber.', () => frontGable({ half: 116, roof: 'blue', wall: 'plaster', gable: 'darkplank', chim: 'brick', shutters: '#4E6B7A', extras: [bush(38, 362, 15, '#F4E27A')] })],
  ['Mossy old farmhouse', 'An old stone house: the roof greened with moss, cobbles, a weathervane.', () => frontGable({ half: 114, roof: 'moss', wall: 'cobble', gable: 'darkplank', vane: true, extras: [barrel(262, 356), bush(36, 362, 14)] })],
  ['Farmhouse with dormers', 'A big front-gabled house with dormer windows on both slopes and a porch.', () => frontGable({ half: 124, roof: 'slate', wall: 'stone', porch: true, dormer: [[44, true], [212, false]], extras: [pot(84, 362), pot(216, 362)] })],
  ['Shingled barn house', 'Long side to the front, wooden shakes, a barn-red door and dormers.', () => sideGable({ roof: 'shake', wall: 'darkplank', doorColor: '#A84A3A', dormer: [56, 196], chim: 'brick', extras: [barrel(30, 356), barrel(272, 356)] })],
  ['Little clay farmstead', 'A smaller clay-roofed house with a porch, flowers and a cart wheel.', () => frontGable({ half: 92, roof: 'clay', wall: 'stone', gable: 'plank', porch: true, windows: [96, 204], extras: [bush(30, 362, 14, '#F28CA3'), bush(270, 362, 14, '#F4E27A'), [`<circle cx="270" cy="300" r="18" fill="none" stroke="#7A5232" stroke-width="5"/>`, `<circle cx="270" cy="300" r="4" fill="#5E3F26"/>`]] })],
]

mkdirSync('web/public/mountain-ideas/farmhouses', { recursive: true })
const DEFS = `<defs><filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="6"/></filter></defs>`
IDEAS.forEach(([name, , make], k) => {
  seed = 101 + k * 17; clipN = 0
  const { P, clips } = make()
  writeFileSync(`web/public/mountain-ideas/farmhouses/fh-${k + 1}.svg`, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400" role="img" aria-label="${name.replace(/&/g, "and")}">${DEFS}<defs>${clips.join('')}</defs>${P.join('')}</svg>\n`)
})
writeFileSync('web/public/mountain-ideas/farmhouses.html', `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Farmhouse Ideas</title>
<style>
  :root { --bg: #efe6d2; --ink: #2f2a22; --muted: #7a6f5c; --card: #fbf7ee; --line: #d9ccb2; }
  * { box-sizing: border-box; } body { margin: 0; background: var(--bg); color: var(--ink); font: 15px/1.45 Georgia, serif; }
  header { padding: 28px 24px 8px; max-width: 1500px; margin: 0 auto; } h1 { margin: 0 0 4px; font-size: 26px; } header p { margin: 0; color: var(--muted); }
  main { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 18px; padding: 18px 24px 40px; max-width: 1500px; margin: 0 auto; }
  figure { margin: 0; background: var(--card); border: 1px solid var(--line); border-radius: 10px; overflow: hidden; }
  .yard { display: grid; place-items: center; padding: 18px; background: radial-gradient(circle at 30% 20%, #8fb35a, #6f9440); }
  .yard img { width: 180px; height: 240px; display: block; }
  .small { display: flex; justify-content: center; gap: 10px; padding: 8px; background: #6f9440; border-top: 1px solid rgba(0,0,0,.1); }
  .small img { width: 66px; height: 88px; }
  figcaption { padding: 10px 14px 12px; } figcaption b { font-size: 16px; } figcaption b span { color: #a0522d; margin-right: 6px; }
  figcaption div { color: var(--muted); font-size: 14px; margin-top: 2px; }
  @media (max-width: 480px) { main { padding: 12px 16px 32px; } header { padding: 20px 16px 4px; } }
</style></head><body>
<header><h1>Ten farmhouse ideas</h1><p>In the cozy hand-crafted top-down style of your reference, each on its 3 × 4 tile plot. Large, and below at about the size it shows in the game.</p></header>
<main>
${IDEAS.map(([name, note], k) => `<figure><div class="yard"><img src="farmhouses/fh-${k + 1}.svg" alt="${name}"></div><div class="small"><img src="farmhouses/fh-${k + 1}.svg" alt=""></div><figcaption><b><span>${k + 1}</span>${name}</b><div>${note}</div></figcaption></figure>`).join('\n')}
</main></body></html>
`)
console.log('ten farmhouse ideas written')

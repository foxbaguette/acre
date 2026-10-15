// The Fenmark (FEN) icon: a silver medal, a wreath of reeds round FEN. Two cuts of it: crisp (48 px and up) and firm
// (32 px and below: the reeds, bulrushes, line and lettering a little heavier). Pure strings, used by the design sheet
// (fenmark-crisp.html) and by tools/fenmark-icons.mjs, which writes the files with FEN as outlines.

const BRIGHT = { a: '#fbfcfb', b: '#c6c9c3', c: '#7e827c', rim: '#8e918b', dark: '#444740', light: '#ffffff' }
let uid = 0
const grad = (id, m) => `<radialGradient id="${id}" cx=".38" cy=".32" r=".8"><stop offset="0" stop-color="${m.a}"/><stop offset=".6" stop-color="${m.b}"/><stop offset="1" stop-color="${m.c}"/></radialGradient>`
const emboss = (m, g, op = 1, dy = 1.4) => `<g transform="translate(0 ${dy})" fill="${m.light}" stroke="${m.light}" opacity=".55">${g}</g><g fill="${m.dark}" stroke="${m.dark}" opacity="${op}">${g}</g>`
const r2 = (v) => Math.round(v * 100) / 100
const blade = (x, base, h, bend, w = 2) => `<path d="M${r2(x - w)} ${base} C${r2(x - w * .5)} ${r2(base - h * .5)} ${r2(x + bend * .5)} ${r2(base - h * .8)} ${r2(x + bend)} ${r2(base - h)} C${r2(x + bend * .4)} ${r2(base - h * .75)} ${r2(x + w)} ${r2(base - h * .5)} ${r2(x + w)} ${base}Z"/>`

// FEN as text by default; with an outline maker set, as a path drawn once and used twice
let fenOutline = null
/** fn(size, baseline) gives the path data of FEN centred on x 100, or null for live text */
export function setFenOutline(fn) { fenOutline = fn }

function face(m, o = {}) {
  const r = o.r ?? 82, k = r / 82, n = o.n ?? 7, step = 120 / (n - 1), fs = o.fen ?? 40, bw = o.bw ?? 2, cat = o.cat ?? 1, dy = o.dy ?? 1.4
  let g = ''
  for (const sd of [-1, 1]) for (let j = 0; j < n; j++) {
    const a = (100 + j * step) * Math.PI / 180, x = 100 + Math.cos(a) * 64 * k, y = 100 + Math.sin(a) * 64 * k, rot = Math.atan2(Math.cos(a), -Math.sin(a)) * 180 / Math.PI + 90
    const X = sd < 0 ? x : 200 - x, R = sd < 0 ? rot : -rot
    g += `<g transform="translate(${r2(X)} ${r2(y)}) rotate(${r2(R)}) scale(${k.toFixed(4)})">${blade(0, 0, 24, sd * -3, bw)}${j % 2 ? `<ellipse cx="0" cy="-26" rx="${r2(2.6 * cat)}" ry="${r2(6 * cat)}"/>` : ''}</g>`
  }
  const base = 100 + fs * .35, stroke = (fill) => (o.fw ? ` stroke="${fill}" stroke-width="${o.fw}" stroke-linejoin="round"` : '')
  const t = (fill, d, op) => (fenOutline
    ? `<use href="#fen" fill="${fill}" opacity="${op}"${stroke(fill)}${d ? ` transform="translate(0 ${d})"` : ''}/>`
    : `<text x="100" y="${base}" text-anchor="middle" font-family="IM Fell English SC, serif" font-size="${fs}" letter-spacing="2" fill="${fill}" opacity="${op}"${stroke(fill)}${d ? ` transform="translate(0 ${d})"` : ''}>FEN</text>`)
  const defs = fenOutline ? `<defs><path id="fen" d="${fenOutline(fs, base)}"/></defs>` : ''
  return defs + emboss(m, g, .9, dy) + t(m.light, dy, .55) + t(m.dark, 0, 1)
}
const disc = (r, fill) => `<circle cx="100" cy="100" r="${r}" fill="${fill}"/>`
const ring = (r, m, w, op) => `<circle cx="100" cy="100" r="${r}" fill="none" stroke="${m.dark}" stroke-width="${w}" opacity="${op}"/>`
const cleanRim = (m, id, outline, ow, faceR) => `<defs>${grad(id, m)}<linearGradient id="e${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#d6d9d3"/><stop offset="1" stop-color="#777a74"/></linearGradient></defs>` + disc(97, outline) + disc(r2(97 - ow), `url(#e${id})`) + disc(faceR, `url(#${id})`)

/** The crisp medal: a bevelled rim and a dark outline, one strong engraved line, a bright face. */
export const crisp = () => { const m = BRIGHT, id = 'fm' + (++uid); return cleanRim(m, id, '#55584f', 2.2, 89) + ring(84.5, m, 2.8, .8) + face(m, { r: 78, bw: 2.3, fw: .4 }) }
/** Its firm cut for 32 px and below: a darker outline, a heavier line, broader blades, bigger bulrushes, a heavier FEN. */
export const firm = () => { const m = BRIGHT, id = 'fm' + (++uid); return cleanRim(m, id, '#4e514b', 3, 89) + ring(84.5, m, 3.6, .85) + face(m, { r: 78, bw: 3.1, cat: 1.3, fen: 42, fw: .9, dy: 2 }) }
/** The cut for a size: firm at 32 px and below. */
export const forSize = (px) => (px <= 32 ? firm() : crisp())
/** A whole SVG file. */
export const file = (body, px = 200) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="${px}" height="${px}">${body}</svg>\n`

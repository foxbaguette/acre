// Writes the Fenmark (FEN) icon files from web/public/mountain-ideas/fenmark-icon.js, with FEN as outlines so they need
// no font:  web/public/art/token/fenmark.svg (the crisp medal, 48 px and up) and fenmark-small.svg (its firm cut, 32 px
// and below). Run from the Cute Fox folder: node tools/fenmark-icons.mjs
// Needs opentype.js (not a project dependency): install it once next to this file with
//   npm install --prefix tools opentype.js@1.3.4
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { pathToFileURL } from 'node:url'

const require = createRequire(import.meta.url)
let opentype
try { opentype = require('opentype.js') } catch { console.error('opentype.js is missing: npm install --prefix tools opentype.js@1.3.4'); process.exit(1) }

const icon = await import(pathToFileURL('web/public/mountain-ideas/fenmark-icon.js').href)
const buf = readFileSync('web/node_modules/@fontsource/im-fell-english-sc/files/im-fell-english-sc-latin-400-normal.woff')
const font = opentype.parse(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength))
icon.setFenOutline((size, base) => {
  const ls = 2 / size, w = font.getAdvanceWidth('FEN', size, { letterSpacing: ls })
  return font.getPath('FEN', 100 - w / 2 + 1, base, size, { letterSpacing: ls }).toPathData(1)
})
mkdirSync('web/public/art/token', { recursive: true })
const files = { 'fenmark.svg': icon.file(icon.crisp(), 256), 'fenmark-small.svg': icon.file(icon.firm(), 32) }
for (const [name, svg] of Object.entries(files)) { writeFileSync(`web/public/art/token/${name}`, svg); console.log(`web/public/art/token/${name}`, svg.length, 'bytes') }

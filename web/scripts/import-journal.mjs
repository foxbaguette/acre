// Imports the approved landing page (landing-ideas/02-field-journal.html) into the site:
//   src/journal/journal.css      its styles
//   src/journal/landing.ts       the SVG symbols and each chapter's left and right page as HTML
//   public/art/...               every image the chapters use (creatures, crops, island renders)
// Run from web/: node scripts/import-journal.mjs  (re-run after changing the landing page)
import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'

const ROOT = '..'
const src = readFileSync(join(ROOT, 'landing-ideas/02-field-journal.html'), 'utf8')
const between = (a, b, from = 0) => {
  const i = src.indexOf(a, from), j = src.indexOf(b, i + a.length)
  if (i < 0 || j < 0) throw new Error('marker not found: ' + a)
  return src.slice(i + a.length, j)
}

// art paths: ../topdown/x -> /art/topdown/x, ../crops/x -> /art/crops/x, assets/x -> /art/x
const art = new Set()
const fix = (html) => html
  .replace(/(src|href)="\.\.\/(topdown|crops)\/([^"]+)"/g, (_, a, d, p) => { art.add(`${d}/${p}`); return `${a}="/art/${d}/${p}"` })
  .replace(/src="assets\/([^"]+)"/g, (_, p) => { art.add(`landing-ideas/assets/${p}`); return `src="/art/${p}"` })
  .replace(/'\.\.\/crops\/'/g, "'/art/crops/'")
  .replace(/<button class="btn" type="button">/g, '<button class="btn" type="button" data-action="connect">')

// ---------- styles ----------
const css = between('<style>', '</style>')
mkdirSync('src/journal', { recursive: true })
writeFileSync('src/journal/journal.css', '/* Imported from landing-ideas/02-field-journal.html by scripts/import-journal.mjs. Do not edit here. */\n' + css)

// ---------- symbols ----------
const defs = '<svg width="0" height="0"' + between('<body>\n<svg width="0" height="0"', '</svg>\n\n<header') + '</svg>'

// ---------- chapters ----------
function leaves(block) {
  return block.split('\n        <div class="leaf" data-ch="').slice(1).map((piece) => {
    const id = piece.slice(0, piece.indexOf('"'))
    const inner = piece.slice(piece.indexOf('>\n') + 2, piece.lastIndexOf('\n        </div>'))
    return { id, html: fix(inner) }
  })
}
const left = leaves(between('<div class="page page-l sheet" id="page-l">', '\n      </div>\n      <div class="page page-r sheet"'))
const right = leaves(between('<div class="page page-r sheet" id="page-r">', '\n      </div>\n    </div>\n  </div>\n</main>'))
const labels = [...src.matchAll(/<a class="bookmark" id="tab-([a-z]+)" role="tab" href="#[a-z]+" data-turn="[a-z]+" aria-selected="(?:true|false)">([^<]+)<\/a>/g)]
  .map((m) => ({ id: m[1], label: m[2] }))
if (!labels.length || labels.length !== left.length || left.length !== right.length) throw new Error(`chapters: ${labels.length} tabs, ${left.length} left, ${right.length} right`)
const chapters = labels.map((l, i) => ({ id: l.id, label: l.label, left: left[i].html, right: right[i].html }))

// the crop picker swaps in every stage of each crop on its tabs
for (const m of src.matchAll(/data-crop="([a-z-]+)"/g))
  for (const st of ['1-seeds-front', '2-sown', '3-first-growth', '4-second-growth', '5-third-growth', '6-harvest', '7-harvest-front', '8-dead']) art.add(`crops/${m[1]}/${st}.svg`)

writeFileSync('src/journal/landing.ts', `// Imported from landing-ideas/02-field-journal.html by scripts/import-journal.mjs. Do not edit here.
export const JOURNAL_DEFS = ${JSON.stringify(defs)}

export interface Chapter { id: string; label: string; left: string; right: string }

export const CHAPTERS: Chapter[] = ${JSON.stringify(chapters, null, 2)}
`)

// ---------- art ----------
for (const p of art) {
  const from = join(ROOT, p)
  const to = join('public/art', p.replace(/^landing-ideas\/assets\//, ''))
  mkdirSync(dirname(to), { recursive: true })
  copyFileSync(from, to)
}
console.log(`${chapters.length} chapters, ${art.size} images, ${css.length} chars of css`)

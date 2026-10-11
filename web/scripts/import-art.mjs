// Copies the art the game draws with into public/art:
//   public/art/tiles/...     ground tiles, trees, decor, fences
//   public/art/crops/...     every finished crop (one with a done.txt): its growth stages and its harvest
//                            (and src/engine/crops.ts, the list of them)
//   public/art/topdown/...   every favourite creature's pictures: top view (map sprite), side view (its card) and eggs
// Run from web/: node scripts/import-art.mjs  (re-run after changing the art)
import { cpSync, existsSync, readFileSync, readdirSync, mkdirSync, writeFileSync } from 'node:fs'

cpSync('../tiles', 'public/art/tiles', { recursive: true })
// every favourite creature's pictures: top view (map sprite), side view (its card) and eggs
const favourites = readFileSync('../topdown/favorites.txt', 'utf8').split(String.fromCharCode(10)).map((s) => s.trim()).filter(Boolean)
for (const k of favourites) {
  const dir = k.replace('/', '__')
  mkdirSync(`public/art/topdown/${dir}`, { recursive: true })
  for (const f of ['top.svg', 'side.svg', 'egg-front.svg', 'egg-top.svg']) {
    try { cpSync(`../topdown/${dir}/${f}`, `public/art/topdown/${dir}/${f}`) } catch { /* not drawn yet */ }
  }
}
const crops = readdirSync('../crops', { withFileTypes: true }).filter((d) => d.isDirectory() && existsSync(`../crops/${d.name}/done.txt`)).map((d) => d.name).sort()
for (const c of crops) {
  mkdirSync(`public/art/crops/${c}`, { recursive: true })
  for (const f of readdirSync(`../crops/${c}`)) if (f.endsWith('.svg')) cpSync(`../crops/${c}/${f}`, `public/art/crops/${c}/${f}`)
}
writeFileSync('src/engine/crops.ts', `// Written by scripts/import-art.mjs: every finished crop in ../crops. Do not edit here.
export const CROPS = ${JSON.stringify(crops)} as const
`)
console.log('tiles, crops (' + crops.length + ') and creature art copied')

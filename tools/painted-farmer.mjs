// A farmer seen from above, painted like the rest of the island (no outlines, light from the upper left): a wide straw
// hat over the shoulders, arms at the sides, facing up (north) as the game's walkers are drawn; and the sack of harvest
// a farmer carries on the back. Four shirts.
//   tiles/farmer-1..4.svg, tiles/farmer-sack.svg
// Run from the Cute Fox folder: node tools/painted-farmer.mjs, then web/scripts/import-art.mjs
import { writeFileSync } from 'node:fs'

const SHIRTS = [['#7a8a9a', '#4e5c6a'], ['#9a6a4a', '#6a4430'], ['#7e8a5a', '#525e38'], ['#a89a7a', '#6e624a']]
const svg = (label, body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" role="img" aria-label="${label}"><defs>
<radialGradient id="hat" cx=".38" cy=".34" r=".7"><stop offset="0" stop-color="#f0dca0"/><stop offset=".6" stop-color="#c8a860"/><stop offset="1" stop-color="#8a6c34"/></radialGradient>
<radialGradient id="crown" cx=".4" cy=".36" r=".7"><stop offset="0" stop-color="#e8d090"/><stop offset="1" stop-color="#9a7a40"/></radialGradient>
<filter id="soft" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="2.5"/></filter></defs>${body}</svg>\n`
SHIRTS.forEach(([shirt, dark], k) => {
  const body = `<ellipse cx="56" cy="58" rx="24" ry="16" fill="#0B0E07" opacity=".35" filter="url(#soft)"/>
<ellipse cx="50" cy="52" rx="22" ry="12" fill="${dark}"/><ellipse cx="48" cy="50" rx="20" ry="10" fill="${shirt}"/>
<ellipse cx="27" cy="54" rx="5.5" ry="8" fill="${dark}"/><ellipse cx="73" cy="54" rx="5.5" ry="8" fill="${dark}"/>
<circle cx="27" cy="60" r="3.6" fill="#c89a78"/><circle cx="73" cy="60" r="3.6" fill="#b8886a"/>
<circle cx="50" cy="48" r="20" fill="url(#hat)"/><circle cx="50" cy="48" r="20" fill="none" stroke="#6e5428" stroke-width="1" opacity=".5"/>
<circle cx="50" cy="46" r="11" fill="url(#crown)"/><circle cx="50" cy="46" r="11.5" fill="none" stroke="${k % 2 ? '#7a3a2a' : '#3e4a5a'}" stroke-width="2.4"/>
${[...Array(14)].map((_, j) => { const a = j / 14 * Math.PI * 2; return `<path d="M${(50 + Math.cos(a) * 12).toFixed(1)} ${(46 + Math.sin(a) * 12).toFixed(1)}L${(50 + Math.cos(a) * 19).toFixed(1)} ${(48 + Math.sin(a) * 19).toFixed(1)}" stroke="#8a6c34" stroke-width=".7" opacity=".45"/>` }).join('')}`
  writeFileSync(`tiles/farmer-${k + 1}.svg`, svg('A farmer, seen from above', body))
})
writeFileSync('tiles/farmer-sack.svg', svg('A sack of harvest', `<ellipse cx="54" cy="56" rx="22" ry="18" fill="#0B0E07" opacity=".3" filter="url(#soft)"/>
<ellipse cx="50" cy="52" rx="21" ry="17" fill="#a8946a"/><ellipse cx="46" cy="48" rx="13" ry="9" fill="#cbb88c"/>
<path d="M40 36q10 -6 20 0" stroke="#6e5a38" stroke-width="3" fill="none" stroke-linecap="round"/><path d="M36 58q14 6 28 0" stroke="#7e6a46" stroke-width="1.5" fill="none" opacity=".6"/>`))
console.log('farmers painted')

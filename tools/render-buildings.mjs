// Renders the buildings' pictures from their 3D models (web/public/mountain-ideas/buildings3d.js) through the dev server
// and the debugging browser (Edge with --remote-debugging-port=9333), and writes:
//   tiles/building-<kind>[-<stage>]-o<facing>.png, ...-lights.png
//   web/src/engine/buildingArt.ts (chimneys, lights, which glow, the pictures' padding), keeping the torch's entries
// Run from the Cute Fox folder with the dev server on :5192: node tools/render-buildings.mjs, then web/scripts/import-art.mjs
import { readFileSync, writeFileSync } from 'node:fs'

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
const list = await (await fetch('http://127.0.0.1:9333/json')).json(), page = list.find((t) => t.type === 'page')
const ws = new WebSocket(page.webSocketDebuggerUrl); await new Promise((r) => (ws.onopen = r))
let id = 0; const pending = new Map(); ws.onmessage = (e) => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id) } }
const send = (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })) })
await send('Page.navigate', { url: 'http://localhost:5192/mountain-ideas/building-export.html#quiet' }); await sleep(4000)
const res = await send('Runtime.evaluate', { expression: 'window.exportAll()', awaitPromise: true, returnByValue: true })
if (res.result?.exceptionDetails) throw new Error(JSON.stringify(res.result.exceptionDetails).slice(0, 600))
const { files, meta } = res.result.result.value
for (const [name, url] of Object.entries(files)) writeFileSync(`tiles/${name}.png`, Buffer.from(url.split(',')[1], 'base64'))
// buildingArt.ts: the torch keeps what it had
const AF = 'web/src/engine/buildingArt.ts', old = readFileSync(AF, 'utf8')
const oldLights = JSON.parse(old.match(/LIGHTS: Record<string, number\[\]\[\]> = (\{.*\})/)[1])
writeFileSync(AF, `// Written by tools/render-buildings.mjs (the torch's entries by tools/painted-buildings.mjs). Rendered building pictures
// cover their footprint and PAD tiles round it (left, top, right, bottom); one picture per facing, named <art>-o<facing>.
export const PAD: [number, number, number, number] = ${JSON.stringify(meta.pad)}
/** The shadow pictures (<art>-o<facing>-shadow-<morning|day|evening>) reach this far round the footprint. */
export const SHPAD: [number, number, number, number] = ${JSON.stringify(meta.shpad)}
/** Where smoke rises from each picture's chimneys, in tiles from the (turned) footprint's top-left. */
export const CHIMNEYS: Record<string, [number, number][]> = ${JSON.stringify(meta.chimneys)}
/** Where water plays in each picture's fountains: [x, y of the basin's middle (tiles from the turned footprint's top-left),
 *  the basin's radius, how far above that the spout shows]. */
export const FOUNTAINS: Record<string, number[][]> = ${JSON.stringify(meta.fountains)}
/** The buildings that light their windows after dark (a "<picture>-lights" layer). */
export const LIT = new Set(${JSON.stringify([...meta.lit, 'building-torch'])})
/** Where each building's lights fall on the ground: [x, y (tiles from its top-left, entrance south), reach (tiles), 1 if
 *  it shines only forward or 0 all round, and how bright (1 if left out)]. Turned with the building. */
export const LIGHTS: Record<string, number[][]> = ${JSON.stringify({ ...meta.lights, 'building-torch': oldLights['building-torch'] })}
/** The kinds drawn from rendered pictures (the rest are single drawings, turned whole). */
export const RENDERED = new Set(['farmhouse', 'lab', 'bakery', 'silo', 'kitchen', 'nest', 'market'])
`)
console.log(Object.keys(files).length + ' pictures rendered')
ws.close()

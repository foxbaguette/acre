// Sprites on the GPU: every picture is rasterised once per size bucket (32 to 512 pixels square) into a slot of a
// texture-array page, a few milliseconds a frame so a zoom never stalls. Pages belong to one bucket each; when they
// are full, the slot used least recently is reused. A sprite that is not ready at the size asked for borrows the
// nearest size that is, so nothing vanishes for a frame on a zoom.
import { texParams, type GL } from './gl'
import { loadImage } from './ground'

export const BUCKETS = [32, 64, 128, 256, 512]
const PAGE = 2048

export interface Region { u0: number; v0: number; u1: number; v1: number; layer: number }
type Source = string | ((g: CanvasRenderingContext2D, px: number) => void)

interface Slot { page: number; i: number; key: string; used: number }

export class Atlas {
  gl: GL
  tex: WebGLTexture
  private pages: number[] = []                 // bucket of each page
  private slots = new Map<string, Slot>()       // key url@bucket -> slot
  private free = new Map<number, number[]>()    // page -> free slot indices
  private sources = new Map<string, Source>()
  private images = new Map<string, Promise<HTMLImageElement | null> | HTMLImageElement | null>()
  private todo: { key: string; name: string; px: number }[] = []
  private queued = new Set<string>()
  private canvas = document.createElement('canvas')
  private maxPages: number
  frame = 0
  /** a sprite became ready since the last check */
  fresh = false

  constructor(gl: GL, maxPages: number) {
    this.gl = gl; this.maxPages = maxPages
    this.tex = gl.createTexture()!
    gl.bindTexture(gl.TEXTURE_2D_ARRAY, this.tex)
    gl.texStorage3D(gl.TEXTURE_2D_ARRAY, 1, gl.RGBA8, PAGE, PAGE, maxPages)
    texParams(gl, gl.TEXTURE_2D_ARRAY, gl.LINEAR, gl.LINEAR)
  }

  /** Registers a picture: an image url, or a function that paints it into a px-square canvas. */
  add(name: string, src: Source) { if (!this.sources.has(name)) this.sources.set(name, src) }

  static bucket(px: number) { return BUCKETS.find((b) => b >= px) ?? BUCKETS[BUCKETS.length - 1] }

  /** The region of this picture at about px pixels, or a nearby size while that one is still being made. */
  get(name: string, px: number): Region | null {
    const b = Atlas.bucket(px), s = this.slots.get(name + '@' + b)
    if (s) { s.used = this.frame; return this.region(s, b) }
    this.request(name, b)
    const order = BUCKETS.slice().sort((p, q) => Math.abs(Math.log2(p / b)) - Math.abs(Math.log2(q / b)))
    for (const o of order) { const t = this.slots.get(name + '@' + o); if (t) { t.used = this.frame; return this.region(t, o) } }
    return null
  }

  /** Is this picture ready at exactly this size? (Asking also queues it.) */
  ready(name: string, px: number) { const b = Atlas.bucket(px); if (this.slots.has(name + '@' + b)) return true; this.request(name, b); return false }

  private region(s: Slot, b: number): Region {
    const per = PAGE / b, x = (s.i % per) * b, y = Math.floor(s.i / per) * b, pad = 1
    return { u0: (x + pad) / PAGE, v0: (y + pad) / PAGE, u1: (x + b - pad) / PAGE, v1: (y + b - pad) / PAGE, layer: s.page }
  }

  private request(name: string, b: number) {
    const key = name + '@' + b; if (this.queued.has(key) || !this.sources.has(name)) return
    this.queued.add(key); this.todo.push({ key, name, px: b })
    const src = this.sources.get(name)!
    if (typeof src === 'string' && !this.images.has(src)) { const p = loadImage(src); this.images.set(src, p); p.then((im) => this.images.set(src, im)) }
  }

  /** Rasterises waiting pictures for up to `budget` milliseconds. */
  work(budget = 3) {
    const t0 = performance.now(), gl = this.gl
    for (let k = 0; k < this.todo.length && performance.now() - t0 < budget;) {
      const job = this.todo[k], src = this.sources.get(job.name)!
      let im: HTMLImageElement | null = null
      if (typeof src === 'string') { const v = this.images.get(src); if (v instanceof Promise) { k++; continue } im = v ?? null }
      this.todo.splice(k, 1)
      const slot = this.alloc(job.px); if (!slot) { this.queued.delete(job.key); continue }   // no room this frame: asked again when next needed
      const b = job.px, c = this.canvas; if (c.width !== b) { c.width = c.height = b }
      const g = c.getContext('2d')!; g.clearRect(0, 0, b, b)
      if (typeof src === 'string') { if (im) g.drawImage(im, 1, 1, b - 2, b - 2) } else { g.save(); g.translate(1, 1); g.scale((b - 2) / b, (b - 2) / b); src(g, b); g.restore() }
      const per = PAGE / b
      gl.bindTexture(gl.TEXTURE_2D_ARRAY, this.tex)
      gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, true)
      gl.texSubImage3D(gl.TEXTURE_2D_ARRAY, 0, (slot.i % per) * b, Math.floor(slot.i / per) * b, slot.page, b, b, 1, gl.RGBA, gl.UNSIGNED_BYTE, c)
      gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false)
      slot.key = job.key; slot.used = this.frame; this.slots.set(job.key, slot); this.queued.delete(job.key)
      this.fresh = true
    }
    return this.todo.length
  }

  private alloc(b: number): Slot | null {
    for (const [page, list] of this.free) if (this.pages[page] === b && list.length) return { page, i: list.pop()!, key: '', used: 0 }
    if (this.pages.length < this.maxPages) {
      const page = this.pages.length, n = (PAGE / b) ** 2; this.pages.push(b)
      this.free.set(page, Array.from({ length: n - 1 }, (_, i) => n - 1 - i))
      return { page, i: 0, key: '', used: 0 }
    }
    let worst: Slot | null = null                // full: reuse the slot of this size that was used least recently
    for (const s of this.slots.values()) if (this.pages[s.page] === b && s.used < this.frame - 2 && (!worst || s.used < worst.used)) worst = s
    if (worst) { this.slots.delete(worst.key); return { page: worst.page, i: worst.i, key: '', used: 0 } }
    // no page of this size at all, or all of it in use: take over the page whose sprites were used least recently
    const last = new Map<number, number>(); for (const s of this.slots.values()) last.set(s.page, Math.max(last.get(s.page) ?? -1, s.used))
    let page = -1, oldest = this.frame - 2
    for (let p = 0; p < this.pages.length; p++) { const u = last.get(p) ?? -1; if (u < oldest) { oldest = u; page = p } }
    if (page < 0) return null
    for (const [k, s] of this.slots) if (s.page === page) this.slots.delete(k)
    const n = (PAGE / b) ** 2; this.pages[page] = b
    this.free.set(page, Array.from({ length: n - 1 }, (_, i) => n - 1 - i))
    return { page, i: 0, key: '', used: 0 }
  }
}

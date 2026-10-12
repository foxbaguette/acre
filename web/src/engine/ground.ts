// The ground: every tile's art in one GPU texture array, the island's cells and fields as textures, and a bake shader
// that paints a block of tiles ("chunk") at one detail level into a texture. Chunks are kept in a cache and only laid
// on screen each frame, so panning and animation never repaint the ground.
import { EDGES, LEVEL_TH, type Fields } from './fields'
import { byteTexture, floatTexture, freeTarget, GLSL_BICUBIC, program, quad, target, texParams, type GL, type Program, type Target } from './gl'
import { GLSL_LOOK } from './look'
import { GLSL_NOISE, GLSL_TERRAIN } from './terrain'
import { GROUND_TILES, LIFT, T, tileIndex, type World } from './world'

/** Detail levels, in pixels per tile, and how many tiles a chunk holds at each (chunks are about 1024 pixels). */
export const LEVELS = [16, 32, 64, 128, 256, 512]
export const chunkTiles = (L: number) => Math.max(2, Math.min(64, 1024 / L))

const RIM_BAND = 0.12

const BAKE_VS = `#version 300 es
in vec2 aPos; out vec2 vUV;
void main() { vUV = aPos; gl_Position = vec4(aPos * 2. - 1., 0., 1.); }`

const BAKE_FS = `#version 300 es
precision highp float; precision highp int; precision highp usampler2D; precision highp sampler2DArray;
uniform sampler2DArray uTiles;
uniform usampler2D uC0, uC1;
uniform sampler2D uF0, uF1, uF2, uF3, uTint;
uniform vec2 uFieldSize, uMap;
uniform vec4 uRegion;
uniform float uPx;
uniform int uPass, uLevels;
uniform bvec4 uHas;          // rock, sand, soil, path present
uniform bool uHasWater, uShallows;
uniform vec4 uLook;
in vec2 vUV; out vec4 o;
const float LIFT = ${LIFT};
const float SOIL = ${tileIndex.get('soil')}.;
${GLSL_BICUBIC}
${GLSL_NOISE}
${GLSL_LOOK}
vec4 F(sampler2D t, vec2 p) { return bicubic(t, p / uMap, uFieldSize); }
uvec4 cell0(vec2 p) { return texelFetch(uC0, clamp(ivec2(floor(p)), ivec2(0), ivec2(uMap) - 1), 0); }
uvec4 cell1(vec2 p) { return texelFetch(uC1, clamp(ivec2(floor(p)), ivec2(0), ivec2(uMap) - 1), 0); }
vec4 over(vec4 d, vec4 s) { return s + d * (1. - s.a); }
vec4 col(vec3 c, float a) { return vec4(c * a, a); }
vec4 tileAt(float layer, vec2 p, vec2 gx, vec2 gy) { vec4 t = textureGrad(uTiles, vec3(fract(p), layer), gx, gy); return t; }
// coverage of an edge from a field value and its screen gradient: d is the distance to the edge, in pixels
float dist(float f, float th) { vec2 g = vec2(dFdx(f), dFdy(f)); return (f - th) / max(length(g), 1e-4); }

void main() {
  vec2 p = uRegion.xy + vUV * uRegion.zw;
  vec2 gx = dFdx(p), gy = dFdy(p);
  uvec4 c = cell0(p);
  int type = int(c.b & 7u);
  if (uPass == 0) {                                   // grass everywhere, as on the planet map, with the island's lush and dry patches over it
    vec4 tint = texture(uTint, p / uMap) * (uLook.w > 2.5 ? .08 : .5);   // (under snow the lush and dry patches barely show)
    o = vec4(over(vec4(grassCol(p, uPx), 1.), tint).rgb, 0.);  // alpha 0: the mountain pass marks its cover there
    return;
  }
  if (uPass == 1) {                                   // sand, soil and path laid over the grass, each with a soft edge and no outline
    vec4 f0 = F(uF0, p);
    float soft = max(1., .07 * uPx);                  // about a fifteenth of a tile, never less than a pixel
    vec4 acc = vec4(0.);
    if (uHas.y) acc = over(acc, col(sandCol(p, uPx), clamp(dist(f0.g, ${EDGES.sand.inner}) / soft + .5, 0., 1.)));
    if (uHas.z) acc = over(acc, col(soilCol(p, uPx), clamp(dist(f0.b, ${EDGES.soil.inner}) / soft + .5, 0., 1.)));
    if (uHas.w) {                                     // a worn path: a ragged edge where the grass creeps in, lighter where feet go
      vec2 wp = p + (vec2(gnoise(p * 2.1 + 7.), gnoise(p * 2.1 + 19.)) - .5) * .16 + (vec2(vnoise(p * 9.), vnoise(p * 9. + 4.)) - .5) * .07;
      float fp = F(uF0, wp).a;
      // as in the reference: a dusty track, palest down the middle where feet go, a darker worn lip along its edge,
      // and the trampled grass just beside it a little darker; the border itself crisp
      float d = dist(fp, ${EDGES.path.inner}), tile = uPx;
      vec3 pc = pathCol(p, uPx) * mix(.9, 1.08, smoothstep(.55, .9, f0.a));
      pc = mix(pc, pc * vec3(.72, .66, .58), (1. - smoothstep(0., .07 * tile, d)) * .8);
      acc = over(acc, col(vec3(.16, .15, .06), .3 * (1. - smoothstep(0., .1 * tile, -d)) * step(d, 0.)));
      acc = over(acc, col(pc, clamp(d / max(1., .025 * tile) + .5, 0., 1.)));
    }
    o = acc;
    return;
  }
  // uPass 2: mountain levels, each a plateau lifted by its height above a cliff that hangs down to the ground
  // Each level's fields and edge distances first, in loops of fixed length: on Direct3D (ANGLE) a screen derivative
  // taken inside a loop that can end early comes back as zero.
  float dts[5], dws[5];
  for (int i = 0; i < 5; i++) {
    float up = float(i + 1) * LIFT;
    vec4 a = i < 4 ? F(uF2, p + vec2(0., up)) : F(uF3, p + vec2(0., up));
    float top = i == 0 ? a.r : i == 1 ? a.g : i == 2 ? a.b : i == 3 ? a.a : a.r, wall = top;
    for (int s = 1; s <= 4; s++) {
      vec4 b = i < 4 ? F(uF2, p + vec2(0., up - float(s) * LIFT * .25)) : F(uF3, p + vec2(0., up - float(s) * LIFT * .25));
      wall = max(wall, i == 0 ? b.r : i == 1 ? b.g : i == 2 ? b.b : i == 3 ? b.a : b.r);
    }
    dts[i] = dist(top, ${LEVEL_TH}); dws[i] = dist(wall, ${LEVEL_TH});
  }
  vec4 acc = vec4(0.);
  for (int L = 1; L <= 5; L++) {
    if (L > uLevels) break;
    float up = float(L) * LIFT, dt = dts[L - 1], dw = dws[L - 1];
    vec2 q = p + vec2(0., up);
    vec3 rock = tileAt(float(cell1(q).r), q, gx, gy).rgb;
    float cw = clamp(dw + .5, 0., 1.);
    if (cw > 0.) {                                    // the cliff face: shaded rock with vertical streaks
      vec3 face = mix(rock, vec3(40., 33., 26.) / 255., .55);
      float u = fract(p.x * 2.) * 23.;
      float st = u >= 1. && u < 3. ? .35 : u >= 7. && u < 8. ? .22 : u >= 12. && u < 15. ? .3 : u >= 18. && u < 19. ? .18 : 0.;
      face = mix(face, vec3(30., 24., 18.) / 255., st);
      acc = over(acc, col(face, cw));
    }
    float rim = clamp(${RIM_BAND} * uPx * .5 - abs(dt) + .5, 0., 1.);
    acc = over(acc, col(L == 5 ? vec3(242., 245., 248.) / 255. : vec3(194., 187., 176.) / 255., rim));
    float ct = clamp(dt + .5, 0., 1.);
    if (ct > 0.) {                                    // the plateau, snow on the summit
      vec4 shade = L == 5 ? vec4(236., 241., 246., .82 * 255.) : L == 4 ? vec4(225., 230., 236., .3 * 255.) : vec4(255., 250., 240., .04 * float(L) * 255.);
      acc = over(acc, col(mix(rock, shade.rgb / 255., shade.a / 255.), ct));
    }
  }
  o = acc;
}`

// The relief: reads the ground painted so far (rgb; alpha = where the mountains cover it) and lays the terrain over it:
// light and shade from the height map, shadows cast toward the south-east, a beach and wet sand along the sea, muddy
// pond banks, and the water itself, its colour from its depth (the bed showing through teal shallows, navy deeper).
const RELIEF_FS = `#version 300 es
precision highp float; precision highp sampler2DArray;
uniform sampler2D uRaw, uH, uF0, uF1;   // F1: the mountains (see terrain.ts)
uniform vec4 uLook;
uniform sampler2DArray uTiles;
uniform vec2 uHSize, uMap;
uniform vec4 uRegion;
uniform float uPx;
in vec2 vUV; out vec4 o;
const float SAND = ${tileIndex.get('sand-01')}.;
const float ROCK = ${tileIndex.get('rock-01')}.;
#define EXACT_HEIGHT
#define MOUNTAIN_DETAIL
${GLSL_TERRAIN}
${GLSL_LOOK}
vec3 rgb(float r, float g, float b) { return vec3(r, g, b) / 255.; }
void main() {
  vec2 p = uRegion.xy + vUV * uRegion.zw;
  vec4 raw = texelFetch(uRaw, ivec2(gl_FragCoord.xy), 0);
  vec3 col = raw.rgb;
  vec4 t = terrain(p, uPx);
  vec4 hv = hfield(p);                                                       // r: sea distance, a: woods
  float H = t.z;
  // seen from afar the fine rock detail is too small to show; the light then follows the ridges more than the broad
  // dome, so the mountain keeps its shape instead of reading as one smooth shaded blob
  float far = 1. - smoothstep(18., 70., uPx);
  float HL = H - far * .65 * mountainHD(p).x / HS;
  vec2 grad = vec2(dFdx(HL), dFdy(HL)) * uPx;
  vec2 gx = dFdx(p), gy = dFdy(p);
  vec3 N = normalize(vec3(-grad * HS, 1.));
  float li = dot(N, LIT) / LIT.z;
  float slope = length(grad) * HS;
  vec4 mm = mountainAt(p);                                                   // sheet x, y, scale, how much shows
  float scale = mm.z, Rm = scale * 7.5, K = scale * clamp(1.4 - (Rm - 4.3) / 4.6 * .4, 1., 1.4);
  vec2 qs = SC + mm.xy;                                                      // the sheet's own coordinates, for its noise
  float hm = mountainH(p);                                                   // the mountain's height, tiles
  float mtn = smoothstep(0., .25, hm);                                      // how much of a mountain this is
  vec4 f0 = texture(uF0, p / uMap);
  // as on the sheet: creases darker, crests a touch brighter, shade where the slopes close in around a spot, and
  // snow settling in the hollows. Read from the mountain's own height (tiles) around the point.
  float cav = 0., ao = 1.;
  if (mtn > 0.) {
    float e = .15;
    cav = (mountainH(p + vec2(e, 0.)) + mountainH(p - vec2(e, 0.)) + mountainH(p + vec2(0., e)) + mountainH(p - vec2(0., e)) - 4. * hm) / (e * e);
    float occ = 0.;
    for (int i = 0; i < 8; i++) { float a = float(i) * .785; occ += max(0., mountainH(p + vec2(cos(a), sin(a)) * .9) - hm); }
    ao = clamp(1. - occ * .09, .55, 1.);
  }
  // light: gentle on the lowland; on the mountains the sunlit faces glow warm and the far sides fall into cool shade,
  // as on the sheet, relative to what flat ground gets
  // shadows: walk toward the sun over the coarse height and see whether anything rises above the ray
  float s = 1., tanA = LIT.z / length(LIT.xy) / HS, h0 = max(hcoarse(p), H);
  float jit = th12(gl_FragCoord.xy);                                         // a per-pixel offset hides the steps of the walk
  float hb = 0.;                                                               // the tallest thing on the way: only real heights cast shadows
  for (int i = 1; i <= 16; i++) { float d = (float(i) - jit) * .3, hs = hcoarse(p + LD * d); hb = max(hb, hs); s = min(s, 1. - smoothstep(0., .06, hs - (h0 + d * tanA))); }
  s = mix(1., s, smoothstep(.16, .34, hb));
  s = mix(s, 1., far * .45);                                                 // so the cast shadow must not swallow the mountain
  float wet = wetness(t);
  // land: a beach along the sea (not where rock meets it), a darker wet strip at the waterline, mud by ponds
  vec3 sand = sandCol(p, uPx);
  float bw = .2 + .14 * gnoise(p * 1.6 + 3.);
  float beach = max(1. - smoothstep(bw * .6, bw, t.x), smoothstep(.15, .4, f0.g) * (1. - smoothstep(.8, 1.6, t.x)));   // the sand reaches the water
  beach *= 1. - mtn;
  vec3 land = mix(col, sand, beach);
  // mountains, as on the planet map: bare rock where it is steep or high, snow above the snow line (thinner on the
  // steepest faces); version 1 lets the grass climb higher under a smaller cap
  float slopeN = slope, hr = hm / (4.6 * K), n = gnoise(qs * 1.6), green = uLook.z > .5 ? 1. : 0.;
  vec3 rockC = mix(rgb(98., 90., 80.), rgb(150., 140., 124.), n) * (.92 + .16 * vnoise(p * 6.) * detailAt(uPx));
  float rockA = clamp(smoothstep(.35 + .25 * green, .9 + .2 * green, slopeN) + smoothstep(.45 + .15 * green, .75 + .1 * green, hr), 0., 1.) * smoothstep(.02, .15, hm);
  land = mix(land, rockC, rockA * 0.);                                       // (hills are grass: no rock)
  float line = mix(.8, .9, green);
  // (and no snow)
  land *= mix(1., ao, mtn * .3);                                            // only a breath of shade where the hill folds
  float wetS = 1. - smoothstep(0., .1 + .04 * gnoise(p * 4.), t.x);
  land = mix(land, land * vec3(.74, .76, .78), wetS * (1. - mtn));
  float mud = smoothstep(-.12, 0., t.y);
  land = mix(land, land * vec3(.7, .68, .6), mud * .7);
  land *= 1. - .1 * hv.a * (1. - mtn);                                      // the shade of the woods
  // the planet map's light: warm where the sun falls, cool in the shade, shadows cast across the land
  // far out, the mountain's own faces carry its shape: their light and shade a little stronger
  float liM = mix(li, 1. + (li - 1.) * 2.2, mtn);                           // a hill shows by its light: the sunny side brighter, the far side in shade
  float lit = clamp(liM, 0., 2.) * (.3 + .7 * s);
  land *= mix(vec3(.38, .42, .5), vec3(1.12, 1.07, .98), smoothstep(0., 1.5, lit));
  land = cozy(land);
  if (uLook.w > 2.5) land *= vec3(.95, .99, 1.07);                          // winter: a colder light
  if (wet <= 0.) { o = vec4(land, 1.); return; }
  // water: the bed (whatever is painted beneath, lit) seen through it; red fades first, so shallows turn teal
  float depth = t.w;
  bool pond = t.y > 0. && t.x >= 0.;
  vec3 bed = pond ? mix(sand, rgb(84., 72., 52.), .6) : sand;                   // sand on the sea floor, mud in ponds
  bed *= .8 + .2 * clamp(li, 0., 1.5);
  bed = mix(bed, rgb(66., 76., 58.), smoothstep(.55, .72, gnoise(p * .9 + 11.)) * .5 * smoothstep(.03, .15, depth));
  bed *= mix(vec3(.75, .8, .9), vec3(1.), s);
  vec3 trans = exp(-depth * (pond ? vec3(16., 9., 8.) : vec3(20., 8., 5.5)));
  vec3 deep = pond ? mix(rgb(38., 82., 80.), rgb(24., 56., 60.), smoothstep(.05, .2, depth))
                   : mix(rgb(32., 72., 92.), rgb(18., 44., 66.), smoothstep(.15, .75, depth)) * (.94 + .12 * gnoise(p * .07 + 3.));
  vec3 water = bed * trans + deep * (1. - trans);
  water = cozy(mix(water, water * vec3(.78, 1.04, 1.12), .55) * 1.18);   // clearer, more turquoise, as on the planet map
  o = vec4(mix(land, water, clamp(wet * uPx + .5, 0., 1.)), 1.);   // a soft edge one pixel wide at any zoom
}`

const DRAW_VS = `#version 300 es
in vec2 aPos;
uniform vec4 uRect, uSrc;          // world rect to cover (tiles); the world rect the texture holds
uniform vec3 uCam;                 // camera x, y (tiles) and device pixels per tile
uniform vec2 uView;
out vec2 vUV;
void main() {
  vec2 w = uRect.xy + aPos * uRect.zw;
  vUV = (w - uSrc.xy) / uSrc.zw;
  vec2 s = (w - uCam.xy) * uCam.z / uView * 2. - 1.;
  gl_Position = vec4(s.x, -s.y, 0., 1.);
}`
const DRAW_FS = `#version 300 es
precision highp float;
uniform sampler2D uTex; uniform float uAlpha;
in vec2 vUV; out vec4 o;
void main() { o = texture(uTex, vUV) * uAlpha; }`

// the open sea beyond the map's edge: one sea tile repeated
const SEA_FS = `#version 300 es
precision highp float; precision highp sampler2DArray;
uniform sampler2D uH; uniform vec2 uHSize, uMap; uniform vec3 uCam; uniform vec2 uView;
out vec4 o;
${GLSL_TERRAIN}
void main() {
  vec2 px = vec2(gl_FragCoord.x, uView.y - gl_FragCoord.y);
  vec2 p = uCam.xy + px / uCam.z;
  // the deep end of the sea's colours, graded exactly as the sea inside the map is, so the two meet without a seam
  vec3 w = vec3(18., 44., 66.) / 255. * (.94 + .12 * gnoise(p * .07 + 3.));
  w = mix(w, w * vec3(.78, 1.04, 1.12), .55) * 1.18;
  float l = dot(w, vec3(.299, .587, .114));
  w = mix(vec3(l), w, 1.1) * vec3(1.04, 1.02, .9) * 1.1;
  w += vec3(.55, .62, .82) * .06 * (1. - smoothstep(0., .55, l));
  w = (w - .45) * .96 + .45;
  o = vec4(w / (1. + max(w - .9, 0.) * 1.6), 1.);
}`
const FULL_VS = `#version 300 es
in vec2 aPos; void main() { gl_Position = vec4(aPos * 2. - 1., 0., 1.); }`

interface Chunk { t: Target; L: number; cx: number; cy: number; born: number; stale?: boolean }

export class Ground {
  gl: GL
  world: World
  ready: Promise<void>
  tiles!: WebGLTexture
  private c0: WebGLTexture
  private c1: WebGLTexture
  f: WebGLTexture[]
  private tint: WebGLTexture
  /** the terrain's height map (see terrain.ts) */
  height: WebGLTexture
  fieldSize: [number, number]
  private reliefP: Program
  private raw: Target | null = null
  private bake: Program
  private drawP: Program
  private seaP: Program
  private vao: WebGLVertexArrayObject
  private chunks = new Map<string, Chunk>()
  private px = 0
  /** pixels of chunks kept */
  budget: number
  maxLevel: number
  stats = { baked: 0, bakeMs: 0 }
  /** which path, soil and rock look to draw (see look.ts) */
  look: [number, number, number, number] = [0, 0, 1, 1]   // worn earth paths, furrowed soil, greener mountains (the painted look), the season (0 spring ... 3 winter)
  /** Paints decor into a chunk while it is being baked: stage 0 after the grass (meadow carpets), 1 after the other
   *  grounds, 2 on top of the finished relief (lilies, which float on the water). */
  decor: ((stage: 0 | 1 | 2, region: [number, number, number], L: number, S: number) => void) | null = null
  /** Whether everything a chunk needs is ready (decor pictures at this size); asked before baking it. */
  canBake: ((region: [number, number, number], L: number) => boolean) | null = null
  private levelsIn: Uint8Array        // per cell: the highest mountain level that can reach it (cliffs hang down, plateaus rise)

  constructor(gl: GL, world: World, fields: Fields, tileSize: number, low: boolean) {
    this.gl = gl; this.world = world
    this.budget = low ? 16e6 : 64e6
    this.maxLevel = low ? 256 : 512
    const { cols, rows } = world, N = cols * rows
    const d1 = new Uint8Array(N * 4)
    for (let i = 0; i < N; i++) d1.set([world.fillRock[i], world.fillSand[i], world.fillPath[i], world.fillWater[i]], i * 4)
    this.levelsIn = new Uint8Array(N)
    for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
      let m = 0
      for (let j = y - 2; j <= y + 6; j++) for (let k = x - 2; k <= x + 2; k++) if (j >= 0 && k >= 0 && j < rows && k < cols && world.type[j * cols + k] === T.rock) m = Math.max(m, world.elev[j * cols + k])
      this.levelsIn[y * cols + x] = m
    }
    this.c0 = byteTexture(gl, cols, rows, this.cells0())
    this.c1 = byteTexture(gl, cols, rows, d1)
    this.f = fields.tex.map((t) => floatTexture(gl, fields.w, fields.h, t))
    this.fieldSize = [fields.w, fields.h]
    this.height = floatTexture(gl, fields.w, fields.h, fields.height)
    this.reliefP = program(gl, BAKE_VS, RELIEF_FS)
    this.tint = floatTexture(gl, cols, rows, world.tint)
    this.bake = program(gl, BAKE_VS, BAKE_FS)
    this.drawP = program(gl, DRAW_VS, DRAW_FS)
    this.seaP = program(gl, FULL_VS, SEA_FS)
    this.vao = quad(gl)
    this.ready = this.loadTiles(tileSize)
  }

  /** Per cell: own tile, the tile below its edges, ground type and sea, mountain level and woods. */
  private cells0() {
    const w = this.world, N = w.cols * w.rows, d0 = new Uint8Array(N * 4)
    for (let i = 0; i < N; i++) d0.set([w.tile[i], w.under[i], w.type[i] | (w.ocean[i] << 3), w.elev[i] | (w.forest[i] << 3)], i * 4)
    return d0
  }

  /** After building: takes the world's cells and the fields' grounds again, and re-draws the chunks over this box
   *  (in cells; the old pictures stay on screen until the new ones are ready). */
  rebuild(fields: Fields, box: [number, number, number, number]) {
    const gl = this.gl, { cols, rows } = this.world
    gl.deleteTexture(this.c0); this.c0 = byteTexture(gl, cols, rows, this.cells0())
    gl.deleteTexture(this.f[0]); this.f[0] = floatTexture(gl, fields.w, fields.h, fields.tex[0])
    const [x0, y0, x1, y1] = [box[0] - 2, box[1] - 2, box[2] + 3, box[3] + 3]   // edges are soft: a little round the box too
    for (const c of this.chunks.values()) { const ch = chunkTiles(c.L), cx = c.cx * ch, cy = c.cy * ch; if (cx < x1 && cy < y1 && cx + ch > x0 && cy + ch > y0) c.stale = true }
  }

  /** The look changed (a new season): every chunk is drawn again (the old pictures stay on screen until then). */
  restyle() { for (const c of this.chunks.values()) c.stale = true }

  /** Rasterises every ground tile into the texture array, with mip levels. */
  private async loadTiles(size: number) {
    const gl = this.gl, tex = gl.createTexture()!
    gl.bindTexture(gl.TEXTURE_2D_ARRAY, tex)
    gl.texStorage3D(gl.TEXTURE_2D_ARRAY, Math.log2(size) + 1, gl.RGBA8, size, size, GROUND_TILES.length)
    const cv = document.createElement('canvas'); cv.width = cv.height = size
    const g = cv.getContext('2d')!
    const images = await Promise.all(GROUND_TILES.map((n) => loadImage(`art/tiles/${n}.svg?v=1`)))
    images.forEach((im, i) => {
      g.clearRect(0, 0, size, size)
      if (im) g.drawImage(im, 0, 0, size, size)
      gl.bindTexture(gl.TEXTURE_2D_ARRAY, tex)
      gl.texSubImage3D(gl.TEXTURE_2D_ARRAY, 0, 0, 0, i, size, size, 1, gl.RGBA, gl.UNSIGNED_BYTE, cv)
    })
    gl.generateMipmap(gl.TEXTURE_2D_ARRAY)
    texParams(gl, gl.TEXTURE_2D_ARRAY, gl.LINEAR_MIPMAP_LINEAR, gl.LINEAR, gl.REPEAT)
    gl.texParameterf(gl.TEXTURE_2D_ARRAY, 0x84fe /* TEXTURE_MAX_ANISOTROPY_EXT */, 4)
    this.tiles = tex
  }

  /** The highest mountain level any cell of this box can show. */
  private levelsAt(x0: number, y0: number, w: number, h: number) {
    const { cols, rows } = this.world; let m = 0
    for (let y = Math.max(0, Math.floor(y0)); y < Math.min(rows, Math.ceil(y0 + h)); y++) for (let x = Math.max(0, Math.floor(x0)); x < Math.min(cols, Math.ceil(x0 + w)); x++) m = Math.max(m, this.levelsIn[y * cols + x])
    return m
  }

  /** Paints the chunk (cx, cy) at level L into a new texture. */
  bakeChunk(L: number, cx: number, cy: number): Chunk | null {
    const gl = this.gl, ch = chunkTiles(L), S = ch * L, t0 = performance.now()
    if (this.canBake && !this.canBake([cx * ch, cy * ch, ch], L)) return null
    const t = target(gl, S, S, true)
    if (!this.raw || this.raw.w !== S) { if (this.raw) freeTarget(gl, this.raw); this.raw = target(gl, S, S) }
    const raw = this.raw                                // the ground before the relief, painted here first
    const P = this.bake, w = this.world
    gl.bindFramebuffer(gl.FRAMEBUFFER, raw.fb); gl.viewport(0, 0, S, S)
    gl.useProgram(P.p); gl.bindVertexArray(this.vao)
    const unit = (i: number, target: number, tex: WebGLTexture, name: string) => { gl.activeTexture(gl.TEXTURE0 + i); gl.bindTexture(target, tex); gl.uniform1i(P.u[name], i) }
    unit(0, gl.TEXTURE_2D_ARRAY, this.tiles, 'uTiles'); unit(1, gl.TEXTURE_2D, this.c0, 'uC0'); unit(2, gl.TEXTURE_2D, this.c1, 'uC1')
    unit(3, gl.TEXTURE_2D, this.f[0], 'uF0'); unit(4, gl.TEXTURE_2D, this.f[1], 'uF1'); unit(5, gl.TEXTURE_2D, this.f[2], 'uF2'); unit(6, gl.TEXTURE_2D, this.f[3], 'uF3')
    unit(7, gl.TEXTURE_2D, this.tint, 'uTint')
    gl.uniform2f(P.u.uFieldSize, this.fieldSize[0], this.fieldSize[1]); gl.uniform2f(P.u.uMap, w.cols, w.rows)
    gl.uniform4f(P.u.uRegion, cx * ch, cy * ch, ch, ch); gl.uniform1f(P.u.uPx, L); gl.uniform4f(P.u.uLook, ...this.look)
    gl.uniform4i(P.u.uHas, 0, +w.has[T.sand], +w.has[T.soil], +w.has[T.path])
    gl.uniform1i(P.u.uHasWater, 0); gl.uniform1i(P.u.uShallows, 0)             // the water comes from the relief pass
    const levels = this.levelsAt(cx * ch - 1, cy * ch - 1, ch + 2, ch + 2)
    gl.uniform1i(P.u.uLevels, levels)
    const between = (stage: 0 | 1) => {               // decor is drawn by another program; the bake's state is set again after it
      if (!this.decor) return
      gl.colorMask(true, true, true, false)
      this.decor(stage, [cx * ch, cy * ch, ch], L, S)
      gl.colorMask(true, true, true, true)
      gl.bindFramebuffer(gl.FRAMEBUFFER, raw.fb); gl.viewport(0, 0, S, S); gl.useProgram(P.p); gl.bindVertexArray(this.vao)
      gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D_ARRAY, this.tiles); gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D, this.c0)
      gl.enable(gl.BLEND); gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
    }
    gl.disable(gl.BLEND)
    gl.uniform1i(P.u.uPass, 0); gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    between(0)
    gl.enable(gl.BLEND); gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
    gl.colorMask(true, true, true, false)               // alpha is kept for the mountains' cover
    gl.uniform1i(P.u.uPass, 1); gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    gl.colorMask(true, true, true, true)
    between(1)
    // (the stepped plateaus of pass 2 are gone: mountains are part of the relief now)
    gl.disable(gl.BLEND)
    // the relief, from the scratch picture into the chunk; then what floats on the water
    const R = this.reliefP
    gl.bindFramebuffer(gl.FRAMEBUFFER, t.fb); gl.viewport(0, 0, S, S); gl.useProgram(R.p); gl.bindVertexArray(this.vao)
    const runit = (i: number, tg: number, tex: WebGLTexture, name: string) => { gl.activeTexture(gl.TEXTURE0 + i); gl.bindTexture(tg, tex); gl.uniform1i(R.u[name], i) }
    runit(0, gl.TEXTURE_2D_ARRAY, this.tiles, 'uTiles'); runit(1, gl.TEXTURE_2D, raw.tex, 'uRaw'); runit(2, gl.TEXTURE_2D, this.height, 'uH'); runit(3, gl.TEXTURE_2D, this.f[0], 'uF0'); runit(4, gl.TEXTURE_2D, this.f[1], 'uF1')
    gl.uniform2f(R.u.uHSize, this.fieldSize[0], this.fieldSize[1]); gl.uniform2f(R.u.uMap, w.cols, w.rows)
    gl.uniform4f(R.u.uRegion, cx * ch, cy * ch, ch, ch); gl.uniform1f(R.u.uPx, L); gl.uniform4f(R.u.uLook, ...this.look)
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    if (this.decor) { this.decor(2, [cx * ch, cy * ch, ch], L, S); gl.bindFramebuffer(gl.FRAMEBUFFER, t.fb) }
    gl.bindTexture(gl.TEXTURE_2D, t.tex); gl.generateMipmap(gl.TEXTURE_2D)
    gl.bindFramebuffer(gl.FRAMEBUFFER, null)
    const c: Chunk = { t, L, cx, cy, born: performance.now() }
    const key = `${L},${cx},${cy}`, was = this.chunks.get(key)
    if (was) { this.chunks.delete(key); this.px -= was.t.w * was.t.h; freeTarget(gl, was.t) }   // a stale picture, now redrawn
    this.chunks.set(key, c); this.px += S * S
    for (const [k, old] of this.chunks) { if (this.px <= this.budget) break; if (old === c) continue; this.chunks.delete(k); this.px -= old.t.w * old.t.h; freeTarget(gl, old.t) }
    this.stats.baked++; this.stats.bakeMs = performance.now() - t0
    return c
  }

  private get(L: number, cx: number, cy: number) {
    const k = `${L},${cx},${cy}`, c = this.chunks.get(k)
    if (c) { this.chunks.delete(k); this.chunks.set(k, c) }            // most recently used goes last
    return c
  }

  level(zDev: number) { return LEVELS.find((L) => L >= zDev * 0.92 && L <= this.maxLevel) ?? Math.min(this.maxLevel, LEVELS[LEVELS.length - 1]) }

  /** The chunks a view still lacks at its level, nearest the middle first. */
  missing(cam: { x: number; y: number; z: number }, W: number, H: number) {
    const L = this.level(cam.z), ch = chunkTiles(L), { cols, rows } = this.world, out: [number, number, number, number][] = []
    const x0 = Math.max(0, Math.floor(cam.x / ch)), y0 = Math.max(0, Math.floor(cam.y / ch))
    const x1 = Math.min(Math.ceil(cols / ch) - 1, Math.floor((cam.x + W / cam.z) / ch)), y1 = Math.min(Math.ceil(rows / ch) - 1, Math.floor((cam.y + H / cam.z) / ch))
    const mx = cam.x + W / cam.z / 2, my = cam.y + H / cam.z / 2
    for (let cy = y0; cy <= y1; cy++) for (let cx = x0; cx <= x1; cx++) if (!this.chunks.get(`${L},${cx},${cy}`) || this.chunks.get(`${L},${cx},${cy}`)!.stale) out.push([L, cx, cy, Math.hypot((cx + 0.5) * ch - mx, (cy + 0.5) * ch - my)])
    return out.sort((a, b) => a[3] - b[3])
  }

  /** Lays the ground on screen: the sea beyond the map, then each chunk (or a stand-in from another level). */
  draw(cam: { x: number; y: number; z: number }, W: number, H: number) {
    const gl = this.gl, { cols, rows } = this.world
    gl.bindVertexArray(this.vao)
    gl.useProgram(this.seaP.p)
    gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, this.height); gl.uniform1i(this.seaP.u.uH, 0)
    gl.uniform2f(this.seaP.u.uHSize, this.fieldSize[0], this.fieldSize[1]); gl.uniform2f(this.seaP.u.uMap, cols, rows)
    gl.uniform3f(this.seaP.u.uCam, cam.x, cam.y, cam.z); gl.uniform2f(this.seaP.u.uView, W, H)
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    const P = this.drawP; gl.useProgram(P.p)
    gl.uniform3f(P.u.uCam, cam.x, cam.y, cam.z); gl.uniform2f(P.u.uView, W, H); gl.uniform1i(P.u.uTex, 0); gl.uniform1f(P.u.uAlpha, 1)
    const L = this.level(cam.z), ch = chunkTiles(L)
    const x0 = Math.max(0, Math.floor(cam.x / ch)), y0 = Math.max(0, Math.floor(cam.y / ch))
    const x1 = Math.min(Math.ceil(cols / ch) - 1, Math.floor((cam.x + W / cam.z) / ch)), y1 = Math.min(Math.ceil(rows / ch) - 1, Math.floor((cam.y + H / cam.z) / ch))
    let pending = false
    for (let cy = y0; cy <= y1; cy++) for (let cx = x0; cx <= x1; cx++) {
      const rx = cx * ch, ry = cy * ch, rw = Math.min(ch, cols - rx), rh = Math.min(ch, rows - ry)
      let c = this.get(L, cx, cy)
      if (!c) {
        pending = true
        for (const l of [L / 2, L / 4, L / 8, L / 16, L * 2, L / 32]) { const c2 = chunkTiles(l); const s = this.get(l, Math.floor(rx / c2), Math.floor(ry / c2)); if (s) { c = s; break } }
        if (!c) continue
      }
      const sch = chunkTiles(c.L)
      gl.bindTexture(gl.TEXTURE_2D, c.t.tex)
      gl.uniform4f(P.u.uRect, rx, ry, rw, rh); gl.uniform4f(P.u.uSrc, c.cx * sch, c.cy * sch, sch, sch)
      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    }
    return pending
  }

  dispose() {
    const gl = this.gl
    for (const c of this.chunks.values()) freeTarget(gl, c.t)
    this.chunks.clear()
    if (this.raw) freeTarget(gl, this.raw)
    for (const t of [this.c0, this.c1, this.tint, this.height, ...this.f, this.tiles]) if (t) gl.deleteTexture(t)
  }
}

export function loadImage(url: string): Promise<HTMLImageElement | null> {
  return new Promise((r) => { const i = new Image(); i.onload = () => r(i); i.onerror = () => r(null); i.src = url })
}

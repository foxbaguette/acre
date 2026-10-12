// Water life, weather and light, all on the GPU:
//   water    the swell catching the light, sun glitter, surf from the depth (terrain.ts), rings of drops
//   clouds   drifting cloud shadows, gathered at a quarter of the resolution so overlaps are never darker
//   light    a buffer where fireflies lift the night's tint and throw a warm pool on the ground
//   final    the weather and daytime grade, tints, vignette and warm cast, in one pass over the finished scene
//   rain     streaks made entirely in the vertex shader from their index and the time; lightning flashes
import type { Daytime, Weather } from '@/engine/types'
import { program, quad, target, freeTarget, type GL, type Program, type Target } from './gl'
import { seeded } from './world'
import { GLSL_TERRAIN } from './terrain'

export const WX: Record<Weather, { gust: number; clouds: number; flies: number; tint: number[] | null; sat: number; bri: number; more: number }> = {
  sun: { gust: 1, clouds: 0.3, flies: 1, tint: null, sat: 1, bri: 1, more: 0 },
  cloudy: { gust: 1.2, clouds: 0.3, flies: 0.6, tint: [150, 160, 178, 0.07], sat: 0.92, bri: 0.98, more: 1 },   // more clouds, none darker
  storm: { gust: 2.3, clouds: 0.5, flies: 0, tint: [18, 28, 48, 0.38], sat: 0.7, bri: 0.82, more: 0 },
  rain: { gust: 1.3, clouds: 0.4, flies: 0.15, tint: [30, 50, 80, 0.16], sat: 0.85, bri: 0.93, more: 0 },
}
export const DAYS: Record<Daytime, { tint: number[] | null; sat: number; bri: number; flies: number; fireflies: number }> = {
  morning: { tint: [255, 214, 170, 0.12], sat: 0.96, bri: 1.02, flies: 0.7, fireflies: 0 },
  day: { tint: null, sat: 1, bri: 1, flies: 1, fireflies: 0 },
  evening: { tint: [255, 150, 70, 0.17], sat: 1.08, bri: 0.92, flies: 0.5, fireflies: 0.5 },
  night: { tint: [9, 18, 56, 0.62], sat: 1, bri: 1, flies: 0, fireflies: 1 },
}

const FULL_VS = `#version 300 es
in vec2 aPos; out vec2 vUV; void main() { vUV = aPos; gl_Position = vec4(aPos * 2. - 1., 0., 1.); }`

// ---- water life, per pixel: each water tile has its glints, two waves and maybe a ring, placed by a hash of the tile
const WATER_FS = `#version 300 es
precision highp float;
uniform sampler2D uH;                // the terrain's height map
uniform vec2 uHSize, uMap, uView;
uniform vec3 uCam;
uniform float uT, uRain, uFoam, uSparkle, uPx;
in vec2 vUV; out vec4 o;
${GLSL_TERRAIN}
const vec3 HALF = vec3(-.286, -.364, .8865);
float h(vec2 c, float s) { return fract(sin(dot(c, vec2(127.1, 311.7)) + s * 74.7) * 43758.5453); }
vec4 over(vec4 d, vec4 s) { return s + d * (1. - s.a); }
float swell(vec2 p, float t) { return gnoise(p * 1.5 + vec2(t * .22, t * .08)) + .45 * gnoise(mat2(.8, -.6, .6, .8) * p * 2.9 - vec2(t * .15, -t * .2)) + .12 * gnoise(p * 6.2 + vec2(-t * .3, t * .25)); }
void main() {
  vec2 px = vec2(gl_FragCoord.x, uView.y - gl_FragCoord.y), p = uCam.xy + px / uCam.z;
  float T = uCam.z, e = 1. / T, t = uT;               // one pixel, in tiles
  vec4 tr = terrain(p, uPx);                         // the same shore the ground was baked with
  float water = clamp(wetness(tr) * T + .5, 0., 1.);
  if (water <= 0.) {
    // waves rolling up the beach now and then: a thin sheet with a foamy front runs up the sand, then slides back and
    // leaves the sand dark and wet for a moment. Sets arrive at their own pace along the coast.
    float x = tr.x;
    if (uFoam > 1.5 || uFoam <= 0. || tr.y > -.4 || x > .9) { o = vec4(0.); return; }
    float ph = t * .11 + gnoise(p * .18 + 2.) * 1.6, k = floor(ph), cyc = fract(ph);
    float big = gnoise(p * .45 + k * 3.7);                                  // how far this wave reaches, varying along the coast
    float reach = (.15 + .65 * smoothstep(.35, .8, big)) * step(.3, fract(k * .618 + .2));   // some sets stay small
    float up = cyc < .22 ? smoothstep(0., .22, cyc) : 1. - smoothstep(.22, .75, cyc);   // a quick run up, a slow slide back
    float R = reach * up;
    vec4 acc = vec4(0.);
    if (x < R) {
      float edgeW = max(e * 1.5, .04);
      float front = (1. - smoothstep(0., edgeW, R - x)) * (cyc < .3 ? 1. : 1. - smoothstep(.3, .6, cyc));
      float lace = smoothstep(.45, .7, gnoise(p * 6. + vec2(t * .3, 0.))) * .35;
      acc = vec4(vec3(52., 122., 130.) / 255., 1.) * .28 * (1. - x / max(R, 1e-3) * .6);   // the thin sheet, clearer near its edge
      acc = over(acc, vec4(vec3(.9, .93, .92), 1.) * clamp(front * .8 + lace * (1. - x / max(R, 1e-3)), 0., 1.));
    } else if (x < reach && cyc > .22) {
      acc = vec4(0., 0., 0., .14 * (1. - smoothstep(.22, 1., cyc)));        // wet sand where the wave has been
    }
    o = acc * clamp(-wetness(tr) * T + .5, 0., 1.);
    return;
  }
  float depth = tr.w; bool pond = tr.y > 0. && tr.x >= 0.;
  vec4 acc = vec4(0.);
  // the swell: facets catching the light and sun glitter, calm right at the shore, only where a pixel can show it
  float zw = smoothstep(14., 48., T) * (uSparkle > 0. ? 1. : .6) * (pond ? .5 : 1.);
  if (zw > 0.) {
    float d = .05, h0 = swell(p, t), hx = swell(p + vec2(d, 0.), t), hy = swell(p + vec2(0., d), t);
    vec3 n = normalize(vec3(-(hx - h0) / d * .05, -(hy - h0) / d * .05, 1.));
    float calm = smoothstep(0., .04, depth);
    float k = (dot(n, LIT) - LIT.z) * 1.1 * zw * calm;
    acc = k < 0. ? vec4(0., 0., 0., -k * .55) : vec4(vec3(.75, .86, .92) * k * .35, 0.);
    acc.rgb += vec3(1., .97, .9) * pow(max(dot(n, HALF), 0.), 260.) * 1.4 * zw * calm;
  }
  // surf: lines rolling in over the shallows, lace on the water and a bright edge where it meets the sand
  if (uFoam > 0. && depth < .07) {
    float ft = uFoam > 1.5 ? 0. : t;
    float fn = gnoise(p * 2.6 + vec2(ft * .12, ft * .05)) * .6 + gnoise(p * 6.5 - vec2(ft * .2, 0.)) * .4;
    float lines = smoothstep(.8, .97, sin(depth * 240. + ft * 1.7 + gnoise(p * 1.2) * 4.)) * smoothstep(.35, .6, fn) * (1. - smoothstep(.012, .055, depth));
    float lace = smoothstep(.42, .66, fn) * (1. - smoothstep(0., .025, depth));
    float wash = (1. - smoothstep(0., .012 + .006 * sin(ft * .8 + gnoise(p * .9) * 5.), depth)) * .35;   // the thin sheet running up the sand
    float edge = (1. - smoothstep(0., max(.007, e * .22), depth)) * (.6 + .4 * sin(ft * 1.2 + gnoise(p * 1.7) * 6.));
    float a = clamp((pond ? 0. : lines * .7 + lace * .6 + wash) + edge * (pond ? .35 : .75), 0., 1.) * (.45 + .55 * smoothstep(10., 40., T));
    acc = over(acc, vec4(vec3(.84, .88, .88), 1.) * a);
  }
  // rings: now and then a drop, often in the rain
  vec2 c = floor(p);
  if (uSparkle > 0. && h(c, 50.) < (uRain > .5 ? .35 : .1)) {
    float ph = h(c, 51.) * 4., period = 3. + h(c, 52.) * 3.;
    float k = uRain > 1.5 ? mod(t * 2.2 + ph, 1.1) / .6 : uRain > .5 ? mod(t * 1.3 + ph, 1.6) / .7 : mod(t + ph, period) / 1.6;
    if (k <= 1.) {
      vec2 rc = c + .2 + vec2(h(c, 53.), h(c, 54.)) * .6, dd = p - rc;
      float lwr = max(e, .018);
      for (int r = 0; r < 2; r++) {
        float kk = k - float(r) * .25; if (kk <= 0.) continue;
        float rr = length(dd / vec2(kk * .28, kk * .17));
        float a = clamp((lwr * .5 - abs(rr - 1.) * kk * .2) / e + .5, 0., 1.) * (1. - k) * .6;
        acc = over(acc, vec4(vec3(225., 245., 255.) / 255., 1.) * a);
      }
    }
  }
  o = acc * water;
}`

// ---- the finished scene: grade, tints (lifted where fireflies shine), their warm light, vignette and warm cast
const FINAL_FS = `#version 300 es
precision highp float;
uniform sampler2D uScene, uLight;
uniform float uSat, uBri, uCloudA, uLook;
uniform vec4 uTint1, uTint2;          // premultiplied: the hour's tint, then the weather's
uniform vec2 uView;
in vec2 vUV; out vec4 o;
vec4 over(vec4 d, vec4 s) { return s + d * (1. - s.a); }
void main() {
  vec3 c = texture(uScene, vUV).rgb;
  float l = dot(c, vec3(.2126, .7152, .0722));
  c = mix(vec3(l), c, uSat) * uBri;
  vec4 light = texture(uLight, vUV);
  vec4 overlay = over(uTint1, uTint2) * light.a;
  c = over(vec4(c, 1.), overlay).rgb + light.rgb;
  if (uLook > .5) {                     // as the CSS did: a soft vignette, a little sky light at top and bottom, a faint warm cast
    float x = vUV.x, y = 1. - vUV.y;
    float r = length(vec2((x - .5) / .5, (y - .45) / .55)) / 1.4142;
    c = mix(c, vec3(18., 22., 28.) / 255., clamp((r - .55) / .45, 0., 1.) * .4);
    c = mix(c, vec3(214., 226., 236.) / 255., clamp(1. - y / .14, 0., 1.) * .16 + clamp((y - .86) / .14, 0., 1.) * .12);
    float s = clamp(y * .94 + x * .34 - .1, 0., 1.);
    c = mix(c, vec3(255., 222., 180.) / 255., .04 * (1. - s));
    c = mix(c, vec3(40., 64., 96.) / 255., .05 * s);
  }
  o = vec4(c, 1.);
}`

// ---- cloud shadows laid down at one strength
const CLOUD_FS = `#version 300 es
precision highp float;
uniform sampler2D uClouds; uniform float uA; uniform vec3 uColor;
in vec2 vUV; out vec4 o;
void main() { float m = texture(uClouds, vUV).a * uA; o = vec4(uColor * m, m); }`

// ---- clouds seen from far out, as on the planet map: whole weather systems from layered noise, brighter on the side
// facing the sun, soft and shaded underneath, and their shadows on the land; they thin out as you come down
const FAR_FS = `#version 300 es
precision highp float;
uniform vec3 uCam; uniform vec2 uView; uniform float uT, uFar, uCover, uRain, uPart; uniform vec3 uLo, uHi;   // part 0: the shadows on the ground, 1: the clouds themselves
in vec2 vUV; out vec4 o;
float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec2 grd(vec2 i) { float a = hash12(i) * 6.2831853; return vec2(cos(a), sin(a)); }
float gnoise(vec2 p) { vec2 i = floor(p), f = fract(p), u = f * f * f * (f * (f * 6. - 15.) + 10.);
  float a = dot(grd(i), f), b = dot(grd(i + vec2(1., 0.)), f - vec2(1., 0.)), c = dot(grd(i + vec2(0., 1.)), f - vec2(0., 1.)), d = dot(grd(i + 1.), f - 1.);
  return .5 + .7 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y); }
const vec2 SUN = vec2(-.507, -.645);
float clouds(vec2 p, float t) { return gnoise(p * .32 + vec2(t * .045, t * .016)) * .5 + gnoise(mat2(.8, -.6, .6, .8) * p * .8 + 7. + vec2(t * .1, -t * .03)) * .28
  + gnoise(p * 2. + 3. + vec2(t * .2, t * .06)) * .17 + gnoise(mat2(.8, .6, -.6, .8) * p * 4.6 + vec2(t * .34, 0.)) * .05; }
void main() {
  vec2 P = uCam.xy + vec2(vUV.x, 1. - vUV.y) * uView / uCam.z;
  vec2 p = P * .16;                                                  // the island's tiles are much smaller than the planet's: far wider systems
  float t = uT;
  if (uPart < .5) { float cs = clouds(p + vec2(.5, .65), t) + uCover;
  float shade = mix(.44, .34, uFar) * smoothstep(.5, .7, cs); /* a tad darker close up */ o = vec4(vec3(.03, .07, .13) * shade, shade); return; }   // their shadows, at every zoom
  float cl = clouds(p, t) + uCover;
  vec4 acc = vec4(0.);
  if (cl > .5 && uFar > 0.) {
    float lit = clamp(.55 + (cl - clouds(p - SUN * .3, t) - uCover) * 4., 0., 1.);
    vec3 cc = mix(uLo, uHi, lit) * (.92 + .1 * smoothstep(.6, .85, cl)) * (1. - uRain * .28);
    float a = smoothstep(.55, .7, cl) * .93 * uFar;
    acc = vec4(cc * a, a) + acc * (1. - a);
  }
  o = acc;
}`

// a picture laid over the scene as it is (premultiplied), scaled up smoothly
const BLIT_FS = `#version 300 es
precision highp float;
uniform sampler2D uTex; in vec2 vUV; out vec4 o;
void main() { o = texture(uTex, vUV); }`

// ---- rain and storm streaks, made from their index and the time
const RAIN_VS = `#version 300 es
in vec2 aPos;
uniform vec2 uView; uniform float uT, uDpr, uStorm, uSnow;
flat out float vA; out vec2 vQ;
float h(float i, float s) { return fract(sin(i * 12.9898 + s * 78.233) * 43758.5453); }
void main() {
  float i = float(gl_InstanceID);
  float sp = (uStorm > .5 ? 900. + h(i, 1.) * 500. : 520. + h(i, 1.) * 260.) * uDpr;
  float len = (uStorm > .5 ? 14. + h(i, 2.) * 16. : 9. + h(i, 2.) * 8.) * uDpr;
  float span = uView.y + 60. * uDpr;
  float fall = mod(h(i, 3.) * span + uT * sp, span);
  float x = mod(h(i, 4.) * uView.x * 1.2 - fall * .28, uView.x * 1.2), y = fall - 20. * uDpr;
  vec2 a = vec2(x, y), b = a + vec2(len * .28, -len), dir = normalize(b - a), n = vec2(-dir.y, dir.x) * max(1., uDpr * (uStorm > .5 ? 1.1 : .8)) * .5;
  vec2 pos = mix(a, b, aPos.y) + n * (aPos.x * 2. - 1.);
  vA = 1.; vQ = aPos * 2. - 1.;
  if (uSnow > .5) {                       // snow: flakes drifting down and swaying; in a storm, driven hard across the view
    float fs = (uStorm > .5 ? 260. + h(i, 1.) * 220. : 38. + h(i, 1.) * 34.) * uDpr;
    float fallS = mod(h(i, 3.) * span + uT * fs, span);
    float sway = sin(uT * (.8 + h(i, 5.)) + i) * (uStorm > .5 ? 6. : 14.) * uDpr;
    float xs = mod(h(i, 4.) * uView.x * 1.4 - fallS * (uStorm > .5 ? 1.1 : .12) + sway, uView.x * 1.4) - uView.x * .2;
    float sz = (uStorm > .5 ? 1.4 + h(i, 2.) * 1.6 : 1.3 + h(i, 2.) * 2.2) * uDpr;
    pos = vec2(xs, fallS - 20. * uDpr) + vQ * sz;
    vA = .55 + .45 * h(i, 6.);
  }
  gl_Position = vec4(pos / uView * 2. - 1., 0., 1.) * vec4(1., -1., 1., 1.);
}`
const RAIN_FS = `#version 300 es
precision highp float;
uniform vec4 uColor; uniform float uSnow; flat in float vA; in vec2 vQ; out vec4 o;
void main() { float a = uSnow > .5 ? smoothstep(1., .35, length(vQ)) : 1.; o = vec4(uColor.rgb * uColor.a, uColor.a) * vA * a; }`

const FLASH_FS = `#version 300 es
precision highp float; uniform float uA; out vec4 o;
void main() { o = vec4(vec3(235., 240., 255.) / 255. * uA, uA); }`

/** One cloud shape: soft blobs in the shape's own 0-1 square, and its blur. */
interface CloudShape { blobs: [number, number, number, number, number][]; blur: number }   // [x, y, rx, ry, tilt]
export interface Puff { shape: CloudShape; w: number; tall: number; x: number; y: number; sp: number; phase: number; delay: number }

/** The cloud shapes of the old renderer, from the same seed: six drifting ones and 28 for a cloudy sky. */
export function cloudShapes() {
  const R = seeded(4711)
  const clouds: CloudShape[] = Array.from({ length: 6 }, (_, n) => {
    const blobs = n === 0 ? [[256, 180, 95], [350, 190, 75], [165, 195, 70], [290, 125, 65], [210, 235, 60], [330, 245, 55]]
      : Array.from({ length: 4 + Math.floor(R() * 5) }, () => { const wide = n % 2 ? 300 : 220; const x = 256 - wide / 2 + R() * wide, y = 180 + (R() - 0.5) * (n % 3 === 0 ? 150 : 90), r = 45 + R() * 50; return [x, y, r] })
    return { blobs: blobs.map(([x, y, r]) => [x / 512, y / 360, r / 512, r / 360, 0]), blur: 30 / 512 }
  })
  const puffs: Puff[] = Array.from({ length: 28 }, () => {
    const rx = 70 + R() * 40, ry = 35 + R() * 35, tilt = (R() - 0.5) * 0.6, n = 5 + Math.floor(R() * 9)
    const blobs: [number, number, number, number, number][] = [[128 / 256, 96 / 192, rx * 0.7 / 256, ry * 0.7 / 192, tilt]]
    for (let i = 0; i < n; i++) {
      const a = R() * 6.2832, d = 0.35 + R() * 0.65
      const x = 128 + Math.cos(a) * rx * d * Math.cos(tilt) - Math.sin(a) * ry * d * Math.sin(tilt), y = 96 + Math.cos(a) * rx * d * Math.sin(tilt) + Math.sin(a) * ry * d * Math.cos(tilt)
      const r = 14 + R() * 30; blobs.push([x / 256, y / 192, r / 256, r / 192, 0])
    }
    const w = 9 + R() * 20, tall = 0.6 + R() * 0.25, x = R(), y = R(), sp = 0.24 + R() * 0.14, phase = R() * 6.28, delay = R() * 0.5
    return { shape: { blobs, blur: 14 / 256 }, w, tall, x, y, sp, phase, delay }
  })
  return { clouds, puffs }
}

export class Sky {
  gl: GL
  private vao: WebGLVertexArrayObject
  private waterP: Program
  private finalP: Program
  private cloudP: Program
  private farP: Program
  private blitP: Program
  private rainP: Program
  private flashP: Program
  scene: Target | null = null
  light: Target | null = null
  clouds: Target | null = null
  flash = 0
  nextFlash = 0
  double = 0
  grow = 0
  constructor(gl: GL) {
    this.gl = gl
    this.vao = quad(gl)
    this.waterP = program(gl, FULL_VS, WATER_FS)
    this.finalP = program(gl, FULL_VS, FINAL_FS)
    this.cloudP = program(gl, FULL_VS, CLOUD_FS)
    this.farP = program(gl, FULL_VS, FAR_FS)
    this.blitP = program(gl, FULL_VS, BLIT_FS)
    this.rainP = program(gl, RAIN_VS, RAIN_FS)
    this.flashP = program(gl, FULL_VS, FLASH_FS)
  }

  /** Makes sure the offscreen targets match the canvas. */
  size(W: number, H: number) {
    const gl = this.gl
    if (!this.scene || this.scene.w !== W || this.scene.h !== H) {
      for (const t of [this.scene, this.light, this.clouds]) if (t) freeTarget(gl, t)
      this.scene = target(gl, W, H)
      this.light = target(gl, Math.max(1, Math.ceil(W / 2)), Math.max(1, Math.ceil(H / 2)))
      this.clouds = target(gl, Math.max(1, Math.ceil(W / 4)), Math.max(1, Math.ceil(H / 4)))
    }
  }

  water(height: WebGLTexture, fieldSize: [number, number], map: [number, number], cam: { x: number; y: number; z: number }, W: number, H: number, t: number, rain: number, foam: number, sparkle: boolean, px: number) {
    const gl = this.gl, P = this.waterP
    gl.useProgram(P.p); gl.bindVertexArray(this.vao)
    gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, height); gl.uniform1i(P.u.uH, 0); gl.uniform1f(P.u.uPx, px)
    gl.uniform2f(P.u.uHSize, fieldSize[0], fieldSize[1]); gl.uniform2f(P.u.uMap, map[0], map[1]); gl.uniform2f(P.u.uView, W, H)
    gl.uniform3f(P.u.uCam, cam.x, cam.y, cam.z); gl.uniform1f(P.u.uT, t); gl.uniform1f(P.u.uRain, rain); gl.uniform1f(P.u.uFoam, foam); gl.uniform1f(P.u.uSparkle, sparkle ? 1 : 0)
    gl.enable(gl.BLEND); gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    gl.disable(gl.BLEND)
  }

  /** Lays the gathered cloud shadows over what is drawn so far. */
  /** Clouds seen from far out (far 0..1: none close up), drawn over the scene. cover: - clearer, + more. */
  farClouds(cam: { x: number; y: number; z: number }, W: number, H: number, t: number, far: number, cover: number, rain: number, part: 0 | 1) {
    if (part === 1 && far <= 0) return
    if (!this.clouds || !this.scene) return
    // clouds are soft: worked out at a quarter of the resolution, then laid over the scene
    const gl = this.gl, P = this.farP, low = this.clouds
    gl.bindFramebuffer(gl.FRAMEBUFFER, low.fb); gl.viewport(0, 0, low.w, low.h); gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT)
    gl.useProgram(P.p); gl.bindVertexArray(this.vao)
    gl.uniform3f(P.u.uCam, cam.x, cam.y, cam.z); gl.uniform2f(P.u.uView, W, H); gl.uniform1f(P.u.uT, t)
    gl.uniform1f(P.u.uFar, far); gl.uniform1f(P.u.uCover, cover); gl.uniform1f(P.u.uRain, rain); gl.uniform1f(P.u.uPart, part)
    gl.uniform3f(P.u.uLo, 0.72, 0.77, 0.86); gl.uniform3f(P.u.uHi, 0.99, 0.98, 0.95)
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.scene.fb); gl.viewport(0, 0, W, H)
    const B = this.blitP; gl.useProgram(B.p)
    gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, low.tex); gl.uniform1i(B.u.uTex, 0)
    gl.enable(gl.BLEND); gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    gl.disable(gl.BLEND)
  }

  cloudShadows(a: number) {
    if (!this.clouds || a <= 0) return
    const gl = this.gl, P = this.cloudP
    gl.useProgram(P.p); gl.bindVertexArray(this.vao)
    gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, this.clouds.tex); gl.uniform1i(P.u.uClouds, 0)
    gl.uniform1f(P.u.uA, a); gl.uniform3f(P.u.uColor, 0x0d / 255, 0x1d / 255, 0x33 / 255)
    gl.enable(gl.BLEND); gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    gl.disable(gl.BLEND)
  }

  final(weather: Weather, daytime: Daytime, W: number, H: number, look: boolean, winter = false) {
    const gl = this.gl, P = this.finalP, d = DAYS[daytime]
    // in winter the rain falls as snow: a snowstorm is a pale whiteout, not a dark sky
    const w = winter && weather === 'storm' ? { ...WX.storm, tint: [214, 222, 234, 0.34], sat: 0.72, bri: 0.98 } : winter && weather === 'rain' ? { ...WX.rain, tint: [200, 210, 226, 0.12], sat: 0.85, bri: 0.99 } : WX[weather]
    gl.bindFramebuffer(gl.FRAMEBUFFER, null); gl.viewport(0, 0, W, H)
    gl.useProgram(P.p); gl.bindVertexArray(this.vao)
    gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, this.scene!.tex); gl.uniform1i(P.u.uScene, 0)
    gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D, this.light!.tex); gl.uniform1i(P.u.uLight, 1)
    gl.uniform1f(P.u.uSat, w.sat * d.sat); gl.uniform1f(P.u.uBri, w.bri * d.bri); gl.uniform1f(P.u.uLook, look ? 1 : 0); gl.uniform2f(P.u.uView, W, H)
    const pm = (c: number[] | null) => c ? [c[0] / 255 * c[3], c[1] / 255 * c[3], c[2] / 255 * c[3], c[3]] : [0, 0, 0, 0]
    gl.uniform4fv(P.u.uTint1, pm(d.tint)); gl.uniform4fv(P.u.uTint2, pm(w.tint))
    gl.disable(gl.BLEND)
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
  }

  /** Streaks of rain and, in a storm, lightning; on the canvas, over everything. dt in seconds. */
  rain(weather: Weather, W: number, H: number, dpr: number, t: number, dt: number, snow = false) {   // snow: in winter, light snow and a snowstorm instead
    if (weather !== 'rain' && weather !== 'storm') return
    const gl = this.gl, P = this.rainP, storm = weather === 'storm'
    const area = W * H / (dpr * dpr), n = snow ? (storm ? Math.round(area / 900) : Math.round(area / 3200)) : storm ? Math.round(area / 2600) : Math.round(area / 7000)
    gl.useProgram(P.p); gl.bindVertexArray(this.vao)
    gl.uniform2f(P.u.uView, W, H); gl.uniform1f(P.u.uT, t); gl.uniform1f(P.u.uDpr, dpr); gl.uniform1f(P.u.uStorm, storm ? 1 : 0); gl.uniform1f(P.u.uSnow, snow ? 1 : 0)
    if (snow) gl.uniform4f(P.u.uColor, 0.97, 0.98, 1, storm ? 0.8 : 0.85)
    else gl.uniform4f(P.u.uColor, storm ? 205 / 255 : 210 / 255, storm ? 222 / 255 : 225 / 255, 245 / 255, storm ? 0.45 : 0.32)
    gl.enable(gl.BLEND); gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
    gl.drawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, n)
    if (storm && !snow) {
      if (t > this.nextFlash) { this.flash = 1; this.nextFlash = t + 5 + Math.random() * 9; this.double = Math.random() < 0.5 ? t + 0.18 : 0 }
      if (this.double && t > this.double) { this.flash = 0.8; this.double = 0 }
      if (this.flash > 0.01) {
        gl.useProgram(this.flashP.p); gl.uniform1f(this.flashP.u.uA, this.flash * 0.55); gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
        this.flash *= Math.pow(0.02, dt)
      }
    }
    gl.disable(gl.BLEND)
  }
}

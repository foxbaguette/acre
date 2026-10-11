// Everything that stands on the ground or moves over it, drawn as instanced quads in one batch: atlas pictures (trees,
// decor, creatures, butterflies) and shapes made in the shader (shadows, the selection ring, ripples, glows).
// Wind sway, breathing and the sprite grade happen on the GPU; swimmers are clipped and tinted where the terrain is under water.
import { program, type GL, type Program } from './gl'
import { GLSL_TERRAIN } from './terrain'
import type { Region } from './atlas'

/** Floats per instance. */
export const STRIDE = 21
export const SHAPE = { softShadow: -1, shadow: -2, halo: -3, glow: -4, ripple: -5, cloud: -6, light: -7, dot: -8, tile: -9, puff: -10 } as const
export const FLAG = { graded: 1, water: 2 } as const

const VS = `#version 300 es
in vec2 aPos;
in vec2 iOrigin; in vec4 iRect; in float iRot; in vec2 iScale; in vec2 iSway; in vec4 iUV; in float iLayer; in vec4 iColor; in float iFlags;
uniform vec3 uCam; uniform vec2 uView; uniform float uFlip, uTime, uGust;
out vec2 vUV; out vec2 vLocal; out vec2 vWorld; flat out float vLayer; flat out vec4 vColor; flat out float vFlags;
void main() {
  vec2 local = mix(iRect.xy, iRect.zw, aPos);
  if (iSway.x > 0.) {                              // wind: a shear that leans the top over, gusting across the island
    float gust = (.25 + .75 * pow(max(0., sin(uTime * .45 - iOrigin.x * .35)), 2.)) * uGust;
    float sw = sin(uTime * 2.1 + iSway.y - iOrigin.x * .5) * .06 * iSway.x * gust;
    local = vec2(local.x + sw * local.y, local.y * (1. + abs(sw) * .15));
  }
  local *= iScale;
  float c = cos(iRot), s = sin(iRot);
  vec2 w = iOrigin + vec2(c * local.x - s * local.y, s * local.x + c * local.y);
  vWorld = w;
  vUV = mix(iUV.xy, iUV.zw, aPos);
  vLocal = aPos * 2. - 1.;
  vLayer = iLayer; vColor = iColor; vFlags = iFlags;
  vec2 sc = (w - uCam.xy) * uCam.z / uView * 2. - 1.;
  gl_Position = vec4(sc.x, uFlip * sc.y, 0., 1.);
}`

const FS = `#version 300 es
precision highp float; precision highp sampler2DArray;
uniform sampler2DArray uAtlas;
uniform sampler2D uH;              // the terrain's height map: where the water is
uniform vec2 uHSize, uMap;
uniform vec3 uCam;
uniform float uTime;
in vec2 vUV; in vec2 vLocal; in vec2 vWorld; flat in float vLayer; flat in vec4 vColor; flat in float vFlags;
out vec4 o;
${GLSL_TERRAIN}
vec3 grade(vec3 c) {                // the sprite layer's look: a touch less saturated, a touch more contrast
  float l = dot(c, vec3(.213, .715, .072));
  c = mix(vec3(l), c, .88);
  return clamp((c - .5) * 1.06 + .5, 0., 1.);
}
float ring(float r, float at, float w) { return clamp(w * .5 - abs(r - at) / fwidth(r) * w * .5 + .5, 0., 1.); }
void main() {
  int flags = int(vFlags + .5);
  vec4 c;
  if (vLayer >= 0.) {
    c = texture(uAtlas, vec3(vUV, vLayer));
    if ((flags & 1) != 0 && c.a > 0.) c.rgb = grade(c.rgb / c.a) * c.a;
    c *= vec4(vColor.rgb, 1.) * vColor.a;
  } else if (vLayer > -1.5) {        // a soft, blurry shadow
    float r = length(vLocal);
    float a = r < .45 ? mix(1., .8, r / .45) : mix(.8, 0., (r - .45) / .55);
    c = vec4(vColor.rgb, 1.) * vColor.a * max(a, 0.) * step(r, 1.);
  } else if (vLayer > -2.5) {        // a contact shadow: a plain ellipse with a soft rim
    float r = length(vLocal), e = fwidth(r);
    c = vec4(vColor.rgb, 1.) * vColor.a * clamp((1. - r) / e, 0., 1.);
  } else if (vLayer > -3.5) {        // the selection ring: glow on the ground, a thin ring, three arcs sweeping round, ticks turning the other way
    float still = vColor.x, t = uTime;
    float breathe = still > .5 ? 1. : 1. + .035 * sin(t * 2.4), spin = still > .5 ? 0. : t * .9, glow = still > .5 ? 1. : .8 + .2 * sin(t * 2.4);
    vec2 q = vLocal * 1.25;          // the quad spans 1.25 ring radii
    float r = length(q), ang = atan(q.y, q.x);
    vec4 acc = vec4(0.);
    float g = r < .7 * 1.25 ? smoothstep(.3, .875, r / 1.25 * 1.25) : 0.;
    float band = r / 1.25;
    float ga = band < .3 ? 0. : band < .7 ? mix(0., .28, (band - .3) / .4) : band < .84 ? mix(.28, .5, (band - .7) / .14) : mix(.5, 0., (band - .84) / .16);
    acc += vec4(1., .86, .5, 1.) * ga * glow;
    float R = breathe, lw = max(.02, vColor.y);
    float rr = r / R;
    float thin = clamp((lw * .6 * .5 - abs(rr - .92)) / fwidth(rr) + .5, 0., 1.);
    acc = vec4(1., .94, .77, 1.) * thin * .55 * glow + acc * (1. - thin * .55 * glow);
    float arcs = 0.;
    for (int k = 0; k < 3; k++) { float a0 = mod(ang - spin - float(k) * 2.0944, 6.2832); arcs = max(arcs, a0 < .95 ? 1. : 0.); }
    float arc = arcs * clamp((lw * 1.4 * .5 - abs(rr - 1.)) / fwidth(rr) + .5, 0., 1.) * .95 * glow;
    acc = vec4(1., .98, .89, 1.) * arc + acc * (1. - arc);
    float tk = mod(ang + spin * .6, .5236);
    float tick = (tk < .03 || tk > .5236 - .03 ? 1. : 0.) * (rr > 1.1 && rr < 1.2 ? 1. : 0.) * .8 * glow;
    acc = vec4(1., .84, .47, 1.) * tick + acc * (1. - tick);
    c = acc;
  } else if (vLayer > -4.5) {        // a glow: a warm light with a bright heart
    float r = length(vLocal);
    float a = r < .18 ? mix(1., .9, r / .18) : r < .5 ? mix(.9, .28, (r - .18) / .32) : mix(.28, 0., (r - .5) / .5);
    c = vec4(vColor.rgb, 1.) * vColor.a * max(a, 0.) * step(r, 1.);
  } else if (vLayer > -5.5) {        // a ripple: a thin ellipse
    float r = length(vLocal);
    c = vec4(vColor.rgb, 1.) * vColor.a * clamp((.05 - abs(r - .92)) / fwidth(r) + .5, 0., 1.);
  } else if (vLayer > -6.5) {        // a cloud blob: a soft ellipse (y: how soft, as a share of its radius), only its alpha counts
    float soft = vColor.y, r = length(vLocal) * (1. + soft);
    c = vec4(0., 0., 0., smoothstep(1. + soft, 1. - soft, r) * vColor.a);
  } else if (vLayer > -7.5) {        // a firefly's light: a warm pool on the ground (rgb, added) and a hole in the dark (alpha)
    float r = length(vLocal);
    float pool = r < .45 ? mix(.5, .18, r / .45) : mix(.18, 0., (r - .45) / .55);
    float cut = r < .35 ? mix(1., .75, r / .35) : mix(.75, 0., (r - .35) / .65);
    c = vec4(vec3(1., 210. / 255., 130. / 255.) * max(pool, 0.) * vColor.x, max(cut, 0.) * vColor.y) * step(r, 1.);
  } else if (vLayer > -8.5) {        // a dot: a small filled circle
    float r = length(vLocal), e = fwidth(r);
    c = vec4(vColor.rgb, 1.) * vColor.a * clamp((1. - r) / e, 0., 1.);
  } else if (vLayer > -9.5) {        // a tile marked for building: a light fill and a crisp rim just inside its edge
    vec2 q = abs(vLocal); float m = max(q.x, q.y), e = fwidth(m);
    float rim = clamp((m - .86) / e + .5, 0., 1.) * clamp((.97 - m) / e + .5, 0., 1.);
    c = vec4(vColor.rgb, 1.) * vColor.a * max(rim, .32 * step(m, .97));
  } else {                           // a puff of smoke: soft, densest in the middle, a little lighter on its upper left
    float r = length(vLocal), a = smoothstep(1., .1, r);
    vec3 col = vColor.rgb * (1.04 - .1 * clamp(vLocal.x + vLocal.y, -1., 1.));
    c = vec4(col, 1.) * vColor.a * a * a;
  }
  if ((flags & 2) != 0) {            // under water: tinted by it, and only where the water is
    float f = wetness(terrain(vWorld, uCam.z));
    float cov = clamp(f * uCam.z + .5, 0., 1.);
    c.rgb = mix(c.rgb, vec3(40., 110., 170.) / 255. * c.a, .35);
    c *= cov;
  }
  o = c;
}`

export class Sprites {
  gl: GL
  private P: Program
  private vao: WebGLVertexArrayObject
  private buf: WebGLBuffer
  data = new Float32Array(STRIDE * 4096)
  n = 0

  constructor(gl: GL) {
    this.gl = gl
    const attrs = ['aPos', 'iOrigin', 'iRect', 'iRot', 'iScale', 'iSway', 'iUV', 'iLayer', 'iColor', 'iFlags']
    this.P = program(gl, VS, FS, attrs)
    this.vao = gl.createVertexArray()!
    gl.bindVertexArray(this.vao)
    const q = gl.createBuffer()!
    gl.bindBuffer(gl.ARRAY_BUFFER, q)
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([0, 0, 1, 0, 0, 1, 1, 1]), gl.STATIC_DRAW)
    gl.enableVertexAttribArray(0); gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
    this.buf = gl.createBuffer()!
    gl.bindBuffer(gl.ARRAY_BUFFER, this.buf)
    const sizes = [2, 4, 1, 2, 2, 4, 1, 4, 1]
    let off = 0
    sizes.forEach((n, i) => {
      gl.enableVertexAttribArray(i + 1)
      gl.vertexAttribPointer(i + 1, n, gl.FLOAT, false, STRIDE * 4, off * 4)
      gl.vertexAttribDivisor(i + 1, 1)
      off += n
    })
    gl.bindVertexArray(null)
  }

  begin() { this.n = 0 }

  private grow() { const d = new Float32Array(this.data.length * 2); d.set(this.data); this.data = d }

  /** A picture from the atlas. rect: its corners around the origin, in tiles (before scale and rotation). */
  picture(r: Region, x: number, y: number, rect: [number, number, number, number], o: { rot?: number; sx?: number; sy?: number; sway?: number; phase?: number; color?: [number, number, number, number]; flags?: number } = {}) {
    this.put(x, y, rect, o.rot ?? 0, o.sx ?? 1, o.sy ?? 1, o.sway ?? 0, o.phase ?? 0, [r.u0, r.v0, r.u1, r.v1], r.layer, o.color ?? [1, 1, 1, 1], o.flags ?? 0)
  }

  /** A shape made in the shader, centred at (x, y) with radii rx, ry in tiles. */
  shape(kind: number, x: number, y: number, rx: number, ry: number, color: [number, number, number, number], flags = 0, rot = 0) {
    this.put(x, y, [-rx, -ry, rx, ry], rot, 1, 1, 0, 0, [0, 0, 1, 1], kind, color, flags)
  }

  private put(x: number, y: number, rect: number[], rot: number, sx: number, sy: number, sway: number, phase: number, uv: number[], layer: number, color: number[], flags: number) {
    if ((this.n + 1) * STRIDE > this.data.length) this.grow()
    const d = this.data, o = this.n * STRIDE
    d[o] = x; d[o + 1] = y; d[o + 2] = rect[0]; d[o + 3] = rect[1]; d[o + 4] = rect[2]; d[o + 5] = rect[3]
    d[o + 6] = rot; d[o + 7] = sx; d[o + 8] = sy; d[o + 9] = sway; d[o + 10] = phase
    d[o + 11] = uv[0]; d[o + 12] = uv[1]; d[o + 13] = uv[2]; d[o + 14] = uv[3]; d[o + 15] = layer
    d[o + 16] = color[0]; d[o + 17] = color[1]; d[o + 18] = color[2]; d[o + 19] = color[3]; d[o + 20] = flags
    this.n++
  }

  /** Draws instances [from, to) with the camera (x, y, device pixels per tile) into a view of W x H pixels. */
  draw(atlas: WebGLTexture, field: WebGLTexture, fieldSize: [number, number], map: [number, number], cam: { x: number; y: number; z: number }, W: number, H: number, o: { flip?: boolean; time?: number; gust?: number; from?: number; to?: number; blend?: 'premult' | 'max' | 'light' } = {}) {
    const from = o.from ?? 0, to = o.to ?? this.n; if (to <= from) return
    const gl = this.gl, P = this.P
    gl.useProgram(P.p); gl.bindVertexArray(this.vao)
    gl.bindBuffer(gl.ARRAY_BUFFER, this.buf)
    gl.bufferData(gl.ARRAY_BUFFER, this.data.subarray(from * STRIDE, to * STRIDE), gl.STREAM_DRAW)
    gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D_ARRAY, atlas); gl.uniform1i(P.u.uAtlas, 0)
    gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D, field); gl.uniform1i(P.u.uH, 1)
    gl.uniform2f(P.u.uHSize, fieldSize[0], fieldSize[1]); gl.uniform2f(P.u.uMap, map[0], map[1])
    gl.uniform3f(P.u.uCam, cam.x, cam.y, cam.z); gl.uniform2f(P.u.uView, W, H)
    gl.uniform1f(P.u.uFlip, o.flip === false ? 1 : -1); gl.uniform1f(P.u.uTime, o.time ?? 0); gl.uniform1f(P.u.uGust, o.gust ?? 1)
    gl.enable(gl.BLEND)
    if (o.blend === 'max') gl.blendEquation(gl.MAX)
    else if (o.blend === 'light') gl.blendFuncSeparate(gl.ONE, gl.ONE, gl.ZERO, gl.ONE_MINUS_SRC_ALPHA)   // light adds up; the dark's remaining strength multiplies down
    else gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
    gl.drawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, to - from)
    gl.blendEquation(gl.FUNC_ADD); gl.disable(gl.BLEND)
    gl.bindVertexArray(null)
  }
}

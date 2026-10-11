// Small WebGL2 helpers: programs, textures, framebuffers and one shared full-screen quad.

export type GL = WebGL2RenderingContext

export interface Program {
  p: WebGLProgram
  u: Record<string, WebGLUniformLocation>
}

export function program(gl: GL, vs: string, fs: string, attribs: string[] = ['aPos']): Program {
  const sh = (type: number, src: string) => {
    const s = gl.createShader(type)!
    gl.shaderSource(s, src.trim())
    gl.compileShader(s)
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
      const log = gl.getShaderInfoLog(s) ?? ''
      const lines = src.trim().split('\n')
      const at = /0:(\d+):/.exec(log)
      throw new Error(`shader: ${log}${at ? `\n> ${lines[Number(at[1]) - 1]}` : ''}`)
    }
    return s
  }
  const p = gl.createProgram()!
  gl.attachShader(p, sh(gl.VERTEX_SHADER, vs))
  gl.attachShader(p, sh(gl.FRAGMENT_SHADER, fs))
  attribs.forEach((a, i) => gl.bindAttribLocation(p, i, a))
  gl.linkProgram(p)
  if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error('link: ' + gl.getProgramInfoLog(p))
  const u: Record<string, WebGLUniformLocation> = {}
  const n = gl.getProgramParameter(p, gl.ACTIVE_UNIFORMS) as number
  for (let i = 0; i < n; i++) {
    const name = gl.getActiveUniform(p, i)!.name
    u[name.replace(/\[0\]$/, '')] = gl.getUniformLocation(p, name)!
  }
  return { p, u }
}

export function texParams(gl: GL, target: number, min: number, mag: number, wrap: number = gl.CLAMP_TO_EDGE) {
  gl.texParameteri(target, gl.TEXTURE_MIN_FILTER, min)
  gl.texParameteri(target, gl.TEXTURE_MAG_FILTER, mag)
  gl.texParameteri(target, gl.TEXTURE_WRAP_S, wrap)
  gl.texParameteri(target, gl.TEXTURE_WRAP_T, wrap)
}

/** A float RGBA image as a filterable half-float texture. */
export function floatTexture(gl: GL, w: number, h: number, data: Float32Array): WebGLTexture {
  const t = gl.createTexture()!
  gl.bindTexture(gl.TEXTURE_2D, t)
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA16F, w, h, 0, gl.RGBA, gl.FLOAT, data)
  texParams(gl, gl.TEXTURE_2D, gl.LINEAR, gl.LINEAR)
  return t
}

/** Integer bytes per cell, read with texelFetch. */
export function byteTexture(gl: GL, w: number, h: number, data: Uint8Array): WebGLTexture {
  const t = gl.createTexture()!
  gl.bindTexture(gl.TEXTURE_2D, t)
  gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1)
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8UI, w, h, 0, gl.RGBA_INTEGER, gl.UNSIGNED_BYTE, data)
  texParams(gl, gl.TEXTURE_2D, gl.NEAREST, gl.NEAREST)
  return t
}

export interface Target { fb: WebGLFramebuffer; tex: WebGLTexture; w: number; h: number }

/** An RGBA8 texture to draw into. */
export function target(gl: GL, w: number, h: number, mips = false): Target {
  const tex = gl.createTexture()!
  gl.bindTexture(gl.TEXTURE_2D, tex)
  const levels = mips ? Math.floor(Math.log2(Math.max(w, h))) + 1 : 1
  gl.texStorage2D(gl.TEXTURE_2D, levels, gl.RGBA8, w, h)
  texParams(gl, gl.TEXTURE_2D, mips ? gl.LINEAR_MIPMAP_LINEAR : gl.LINEAR, gl.LINEAR)
  const fb = gl.createFramebuffer()!
  gl.bindFramebuffer(gl.FRAMEBUFFER, fb)
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0)
  gl.bindFramebuffer(gl.FRAMEBUFFER, null)
  return { fb, tex, w, h }
}
export function freeTarget(gl: GL, t: Target) { gl.deleteFramebuffer(t.fb); gl.deleteTexture(t.tex) }

/** The unit quad (0,0)-(1,1) as a triangle strip, in attribute 0. */
export function quad(gl: GL): WebGLVertexArrayObject {
  const vao = gl.createVertexArray()!
  gl.bindVertexArray(vao)
  const b = gl.createBuffer()!
  gl.bindBuffer(gl.ARRAY_BUFFER, b)
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([0, 0, 1, 0, 0, 1, 1, 1]), gl.STATIC_DRAW)
  gl.enableVertexAttribArray(0)
  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
  gl.bindVertexArray(null)
  return vao
}

/** Shared GLSL: smooth (B-spline) sampling of a field texture from four bilinear taps. */
export const GLSL_BICUBIC = `
vec4 bicubic(sampler2D t, vec2 uv, vec2 size) {
  vec2 st = uv * size - 0.5, i = floor(st), f = fract(st);
  vec2 w0 = (1. - f) * (1. - f) * (1. - f) / 6., w1 = (4. - 6. * f * f + 3. * f * f * f) / 6.;
  vec2 w2 = (1. + 3. * f + 3. * f * f - 3. * f * f * f) / 6., w3 = f * f * f / 6.;
  vec2 g0 = w0 + w1, g1 = w2 + w3, h0 = (w1 / g0 - 1. + i + .5) / size, h1 = (w3 / g1 + 1. + i + .5) / size;
  return (texture(t, h0) * g0.x + texture(t, vec2(h1.x, h0.y)) * g1.x) * g0.y
       + (texture(t, vec2(h0.x, h1.y)) * g0.x + texture(t, h1) * g1.x) * g1.y;
}`

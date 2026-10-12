// The terrain: one height map for the whole island, read the same way by every shader that needs to know where the
// water is (ground bake, water surface, swimmers). The CPU part (fields.ts) stores smooth, slowly varying values per
// field pixel; the GPU adds the fractal shore and the rolling hills on top, with finer octaves joining in as the zoom
// can show them. Because the shoreline, the beach, the shallows, the depth colour and the surf all come from this
// one function, they always line up.
//
// The height texture (RGBA16F, field resolution):
//   r  signed distance to the sea, in tiles (+ on land)
//   g  (free)
//   b  signed distance into a pond, in tiles (+ inside)
//   a  how wooded the ground is, 0..1
import { GLSL_BICUBIC } from './gl'

/** Hash and smooth noise, shared by every ground shader. */
export const GLSL_NOISE = `
float th12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec2 tgrd(vec2 i) { float a = th12(i) * 6.2831853; return vec2(cos(a), sin(a)); }
float gnoise(vec2 p) { vec2 i = floor(p), f = fract(p), u = f * f * f * (f * (f * 6. - 15.) + 10.);
  float a = dot(tgrd(i), f), b = dot(tgrd(i + vec2(1., 0.)), f - vec2(1., 0.)), c = dot(tgrd(i + vec2(0., 1.)), f - vec2(0., 1.)), d = dot(tgrd(i + 1.), f - 1.);
  return .5 + .7 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y); }
float fbm3(vec2 p) { return gnoise(p) * .57 + gnoise(p * 2.03 + 17.1) * .29 + gnoise(p * 4.1 + 9.2) * .14; }
`

/** Height texture uniforms, noise and terrain(). Needs `uniform sampler2D uH; uniform vec2 uHSize, uMap;` declared. */
export const GLSL_TERRAIN = `
${GLSL_BICUBIC}
const vec3 LIT = vec3(-.507, -.645, .5715);            // the sun, from the north-west
const vec2 LD = vec2(-.6181, -.7861);                  // the way toward it, on the ground
const float HS = 4.;                                    // how steep a unit of height looks
${GLSL_NOISE}
float fold(float g) { float x = g * 2. - 1.; return 1. - sqrt(x * x + .0015); }   // a crest, rounded just enough not to alias
// The mountains, drawn the way the picked sheet draws them (alpine snowfields, version C2: a spine with spurs, a long
// gentle foot, eroded ridges over it). uF1 holds, per pixel, where it lies on its mountain in the sheet's own units
// (x, y from the centre), the scale from sheet units to tiles and how much of the mountain shows; mountains.ts fills it.
// The sheet's noise is the noise here, so the shapes match.
#ifdef MOUNTAIN_DETAIL
const vec2 SC = vec2(12., 8.2);                          // the sheet's centre
float eroded(vec2 p) {
  float s = 0., a = .5, w = 1.; vec2 q = p;
  for (int i = 0; i < 3; i++) {
    float n = 1. - abs(gnoise(q) * 2. - 1.); n *= n;
    s += n * a * w; w = clamp(n * 1.4, 0., 1.);
    a *= .45; q = mat2(.8, -.6, .6, .8) * q * 2.1 + 3.7;
  }
  return s;
}
float crest(float n) { float x = n * 2. - 1.; return 1. - sqrt(x * x + .03); }          // rounded, never a crease
// bilinear by hand with exact weights: the hardware's are only 8 bits, which turns the position data into a visible grid
// when the height is magnified; the data is linear across a mountain, so this loses nothing
vec4 mountainAt(vec2 p) {
  vec2 st = p / uMap * uHSize - .5, i = floor(st), f = st - i; ivec2 b = ivec2(i), mx = ivec2(uHSize) - 1;
  vec4 a = texelFetch(uF1, clamp(b, ivec2(0), mx), 0), c = texelFetch(uF1, clamp(b + ivec2(1, 0), ivec2(0), mx), 0);
  vec4 d = texelFetch(uF1, clamp(b + ivec2(0, 1), ivec2(0), mx), 0), e = texelFetch(uF1, clamp(b + 1, ivec2(0), mx), 0);
  return mix(mix(a, c, f.x), mix(d, e, f.x), f.y);
}
// the mountain's height in tiles: x its broad dome alone, y all of it
vec2 mountainHD(vec2 p) {
  vec4 m = mountainAt(p);
  if (m.w <= .001) return vec2(0.);
  float scale = m.z, R = scale * 7.5, hk = clamp(1.4 - (R - 4.3) / 4.6 * .4, 1., 1.4);   // small ones a touch taller for their size
  vec2 q = SC + m.xy;
  vec2 w = q + (vec2(gnoise(q * .2 + 1.), gnoise(q * .2 + 9.)) - .5) * 1.4;              // nothing is a perfect circle
  vec2 d0 = (w - SC) / (vec2(8.8, 6.8) * 1.25); float a = atan(d0.y, d0.x);
  float f = clamp(1. - length(d0) * (1. + .2 * (gnoise(vec2(cos(a), sin(a)) * 1.3 + 4.) - .5)), 0., 1.);   // the long gentle foot
  float on = smoothstep(.15, .745, f);
  vec2 d = (w - SC) / vec2(8.8, 6.8);
  float sp = crest(gnoise(vec2(d.x * 3.2, abs(d.y) * 1.4) + 4.));
  float spine = (exp(-d.y * d.y * 7.) + sp * sp * .35 * smoothstep(.04, .3, abs(d.y))) * on;   // a spine with short spurs
  // a low grassy hill, not a mountain: the buildings are taller than any peak would be, so the land only swells
  float k = scale * hk * smoothstep(0., .6, m.w), hill = f * f * (3. - 2. * f) * 1.3 * k;
  return vec2(hill, hill);
}
float mountainH(vec2 p) { return mountainHD(p).y; }
#else
float mountainH(vec2 p) { return 0.; }
vec2 mountainHD(vec2 p) { return vec2(0.); }
#endif
#ifdef EXACT_HEIGHT
// the bake reads the height exactly (sixteen texels, full precision weights): the hardware's bilinear weights are
// only 8-bit, which the light turns into visible steps when the map is magnified
vec4 hfield(vec2 p) {
  vec2 st = p / uMap * uHSize - .5, i = floor(st), f = st - i;
  vec2 w0 = (1. - f) * (1. - f) * (1. - f) / 6., w1 = (4. - 6. * f * f + 3. * f * f * f) / 6., w2 = (1. + 3. * f + 3. * f * f - 3. * f * f * f) / 6., w3 = f * f * f / 6.;
  ivec2 b = ivec2(i), mx = ivec2(uHSize) - 1;
  vec4 r = vec4(0.);
  for (int y = 0; y < 4; y++) {
    float wy = y == 0 ? w0.y : y == 1 ? w1.y : y == 2 ? w2.y : w3.y;
    vec4 row = vec4(0.);
    for (int x = 0; x < 4; x++) {
      float wx = x == 0 ? w0.x : x == 1 ? w1.x : x == 2 ? w2.x : w3.x;
      row += texelFetch(uH, clamp(b + ivec2(x - 1, y - 1), ivec2(0), mx), 0) * wx;
    }
    r += row * wy;
  }
  return r;
}
#else
vec4 hfield(vec2 p) { return bicubic(uH, p / uMap, uHSize); }
#endif
vec4 hfieldFast(vec2 p) { return bicubic(uH, p / uMap, uHSize); }

// the shore's fractal wobble, in tiles: bays, headlands and little points; finer octaves as the zoom allows
// x: the broad wobble only (for the land's own height), y: with the fine detail (for the waterline)
vec2 coastN(vec2 p, float px) {
  vec2 cw = p + (vec2(gnoise(p * .9), gnoise(p * .9 + vec2(7.3, 1.7))) - .5) * .6;
  float broad = (gnoise(cw * .85) - .5) * .42 + (gnoise(cw * 2.1 + 3.) - .5) * .24;
  return vec2(broad, broad
    + (gnoise(cw * 5.2 + 5.) - .5) * .12 * smoothstep(12., 40., px)
    + (gnoise(cw * 12.5 + 9.) - .5) * .06 * smoothstep(40., 110., px)
    + (gnoise(cw * 29. + 1.) - .5) * .03 * smoothstep(110., 300., px));
}

// x: signed distance to the sea (+ land), y: into a pond (+ inside), z: height (the water's surface is 0), w: water depth
vec4 terrain(vec2 p, float px) {
  vec4 h = hfield(p);
  vec2 n = coastN(p, px);
  float bs = 1. - smoothstep(.5, 2.5, abs(h.r)), bp = 1. - smoothstep(.3, 1.8, abs(h.b));
  float sea = h.r + n.y * bs, pond = h.b + n.y * .55 * bp;
  float seaL = h.r + n.x * bs, pondL = h.b + n.x * .55 * bp;   // the same, smooth: the land's slopes come from these
  float inland = smoothstep(0., 3., seaL);
  float hills = (gnoise(p * .065 + 4.) - .5) * .14 + (gnoise(p * .15 + 9.) - .5) * .04;   // broad, gentle swells, many tiles across
  float land = .035 * (1. - exp(-max(seaL, 0.) / 2.)) + mountainH(p) / HS + hills * inland;
  land *= 1. - .6 * smoothstep(-1.4, 0., pondL);           // banks slope gently down to the pond
  float dS = max(-sea, 0.), dP = max(pond, 0.);
  float edge = min(min(p.x, p.y), min(uMap.x - p.x, uMap.y - p.y));   // the sea keeps deepening toward the map edge
  dS = max(dS, sea < 0. ? (6. - edge) * 2. : 0.);
  float depth = sea < 0. ? dS * .02 + (1. - exp(-dS / 6.)) * .75 * (.8 + .4 * gnoise(p * .22 + 6.))
              : pond > 0. ? dP * .05 + (1. - exp(-dP / 1.4)) * .16 : 0.;
  return vec4(sea, pond, depth > 0. ? -depth : land, depth);
}
// the same height without the fine detail, for casting shadows
float hcoarse(vec2 p) {
  vec4 h = hfield(p);
  return .035 * (1. - exp(-max(h.r, 0.) / 2.)) + mountainH(p) / HS;
}
// how far inside water a point is (> 0 in water): the edge every water shader shares
float wetness(vec4 t) { return max(-t.x, t.y); }
`

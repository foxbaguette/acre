// Everything that stands on the ground or moves over it, drawn as instanced quads in one batch: atlas pictures (trees,
// decor, creatures, butterflies) and shapes made in the shader (shadows, the selection ring, ripples, glows).
// Wind sway, breathing and the sprite grade happen on the GPU; swimmers are clipped and tinted where the terrain is under water.
import { program, type GL, type Program } from './gl'
import { GLSL_TERRAIN } from './terrain'
import type { Region } from './atlas'

/** Floats per instance. */
export const STRIDE = 21
export const SHAPE = { softShadow: -1, shadow: -2, halo: -3, glow: -4, ripple: -5, cloud: -6, light: -7, dot: -8, tile: -9, puff: -10, tree: -11, flame: -12, ice: -13 } as const
export const FLAG = { graded: 1, water: 2, field: 4, seabed: 4194304 } as const   // seabed: on the sea floor, seen through the water by its depth
/** A field tile's flags: wind on; which of its 8 neighbours (row by row, from the upper left) count as field for its outline
 *  (the same crop, or no soil: there the soil's own edge shapes it); which of them carry the same crop (they draw their own
 *  part); and the crop's seed (0-3) above them. Kept below 2^22: larger values did not survive the trip to the GPU intact. */
export const FIELD = { wind: 8, near: 16, same: 4096, seed: 1048576 } as const
/** A field tile's quad reaches this far from its middle (tiles): onto neighbours without a crop, up to the soil's edge. */
export const FIELD_REACH = 1

const VS = `#version 300 es
in vec2 aPos;
in vec2 iOrigin; in vec4 iRect; in float iRot; in vec2 iScale; in vec2 iSway; in vec4 iUV; in float iLayer; in vec4 iColor; in float iFlags;
uniform vec3 uCam; uniform vec2 uView; uniform float uFlip, uTime, uGust;
out vec2 vUV; out vec2 vLocal; out vec2 vWorld; flat out float vLayer; flat out vec4 vColor; flat out float vFlags; flat out vec4 vRegion;
void main() {
  vec2 local = mix(iRect.xy, iRect.zw, aPos);
  if (iSway.x > 0.) {                              // wind: a shear that leans the top over, gusting across the island
    float gust = (.25 + .75 * pow(max(0., sin(uTime * .45 - iOrigin.x * .35)), 2.)) * uGust;
    float sw = sin(uTime * 2.1 + iSway.y - iOrigin.x * .5) * .06 * iSway.x * gust;
    local = vec2(local.x + sw * local.y, local.y * (1. + abs(sw) * .15));
  } else if (iSway.x < 0.) local.x += iSway.y * local.y;   // a slant (shear) before scaling: a picture laid in a tilted plane
  local *= iScale;
  float c = cos(iRot), s = sin(iRot);
  vec2 w = iOrigin + vec2(c * local.x - s * local.y, s * local.x + c * local.y);
  vWorld = w;
  vUV = mix(iUV.xy, iUV.zw, aPos); vRegion = iUV;
  vLocal = aPos * 2. - 1.;
  vLayer = iLayer; vColor = iColor; vFlags = iFlags;
  vec2 sc = (w - uCam.xy) * uCam.z / uView * 2. - 1.;
  gl_Position = vec4(sc.x, uFlip * sc.y, 0., 1.);
}`

const FS = `#version 300 es
precision highp float; precision highp sampler2DArray;
uniform sampler2DArray uAtlas;
uniform sampler2D uH;              // the terrain's height map: where the water is
uniform sampler2D uSoil;           // the ground's field 0 (fields.ts): b is the soil's smooth shape
uniform vec2 uHSize, uMap;
uniform vec3 uCam;
uniform float uTime, uGust;
uniform float uSeason;             // 0 spring, 1 summer, 2 autumn, 3 winter
uniform vec4 uCloud;               // the far clouds (sky.ts): how far out (0 none), cover, their time
in vec2 vUV; in vec2 vLocal; in vec2 vWorld; flat in float vLayer; flat in vec4 vColor; flat in float vFlags; flat in vec4 vRegion;
out vec4 o;
${GLSL_TERRAIN}
vec3 grade(vec3 c) {                // the sprite layer's look: a touch less saturated, a touch more contrast
  float l = dot(c, vec3(.213, .715, .072));
  c = mix(vec3(l), c, .88);
  return clamp((c - .5) * 1.06 + .5, 0., 1.);
}
// a tree seen from above, painted in light and shade, no outline. p in -1..1 (y down), aa: the size of a pixel in p.
// Broadleaf: a canopy of leafy lumps, each a little dome covered in leaf clusters, lit from the upper left.
// Conifer: tiers of boughs radiating from the top, the higher tiers smaller and on top.
const vec3 TL = vec3(-.5, -.62, .6);
// the distance from p to the segment a-b, and how far along it the nearest point lies
vec2 seg(vec2 p, vec2 a, vec2 b) { vec2 ab = b - a; float t = clamp(dot(p - a, ab) / dot(ab, ab), 0., 1.); return vec2(length(p - a - ab * t), t); }
// a broadleaf tree in winter, from above: bare boughs reaching out from the trunk, twigs off them, snow caught along them
vec4 bareTree(vec2 p, float seed, float aa) {
  float cov = 0., snow = 0.;
  for (int k = 0; k < 7; k++) {
    float fk = float(k), a = seed * 6.2832 + fk * .8976 + (th12(vec2(fk, seed)) - .5) * .5, L = .72 + .2 * th12(vec2(seed, fk + 3.));
    vec2 dir = vec2(cos(a), sin(a)), nr = vec2(-dir.y, dir.x);
    float bend = (th12(vec2(fk * 1.7, seed * 2.)) - .5) * .3;
    vec2 m = dir * L * .5 + nr * bend * .4, e = dir * L + nr * bend;
    vec2 s1 = seg(p, vec2(0.), m), s2 = seg(p, m, e);
    float w1 = mix(.075, .045, s1.y), w2 = mix(.045, .014, s2.y);
    cov = max(cov, clamp((w1 - s1.x) / aa + .5, 0., 1.)); cov = max(cov, clamp((w2 - s2.x) / aa + .5, 0., 1.));
    snow = max(snow, clamp((w1 * .55 - length(p - (vec2(0.) + (m) * s1.y) - vec2(-.012, -.016))) / aa + .5, 0., 1.) * step(.5, th12(vec2(fk, seed * 5.))));
    for (int j = 0; j < 2; j++) {                                   // twigs off each bough
      float fj = float(j), sd = fj < .5 ? 1. : -1.;
      vec2 o = mix(m, e, .2 + .4 * fj), td = normalize(dir * .8 + nr * sd * .6) * (.22 + .1 * th12(vec2(fk + fj, seed)));
      vec2 s3 = seg(p, o, o + td);
      cov = max(cov, clamp((mix(.022, .008, s3.y) - s3.x) / aa + .5, 0., 1.));
    }
  }
  cov = max(cov, clamp((.11 - length(p)) / aa + .5, 0., 1.));      // the trunk's top
  float haze = smoothstep(.95, .4, length(p)) * (.55 + .45 * gnoise(p * 7. + seed * 3.)) * .22;   // the fine twigs, a faint mesh
  vec3 bark = mix(vec3(.22, .18, .15), vec3(.36, .31, .26), smoothstep(.1, -.4, p.x + p.y));     // lit from the upper left
  vec3 col = mix(bark, vec3(.9, .92, .95), max(snow, step(.55, cov) * smoothstep(.2, .9, gnoise(p * 11. + seed * 7.)) * .5));
  float a = max(cov, haze);
  return vec4(mix(vec3(.3, .26, .22), col, cov) * a, a);
}
// the far clouds' cover at a world point, exactly as sky.ts works it out (its own noise), so what lies on the water can
// hide under them
float cHash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * .1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec2 cGrd(vec2 i) { float a = cHash(i) * 6.2831853; return vec2(cos(a), sin(a)); }
float cNoise(vec2 p) { vec2 i = floor(p), f = fract(p), u = f * f * f * (f * (f * 6. - 15.) + 10.);
  float a = dot(cGrd(i), f), b = dot(cGrd(i + vec2(1., 0.)), f - vec2(1., 0.)), c = dot(cGrd(i + vec2(0., 1.)), f - vec2(0., 1.)), d = dot(cGrd(i + 1.), f - 1.);
  return .5 + .7 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y); }
float cloudCover(vec2 P) {
  if (uCloud.x <= 0.) return 0.;
  vec2 p = P * .16; float t = uCloud.z;
  float cl = cNoise(p * .32 + vec2(t * .045, t * .016)) * .5 + cNoise(mat2(.8, -.6, .6, .8) * p * .8 + 7. + vec2(t * .1, -t * .03)) * .28
    + cNoise(p * 2. + 3. + vec2(t * .2, t * .06)) * .17 + cNoise(mat2(.8, .6, -.6, .8) * p * 4.6 + vec2(t * .34, 0.)) * .05 + uCloud.y;
  return cl > .5 ? smoothstep(.55, .7, cl) * .93 * uCloud.x : 0.;
}
vec4 treeCol(vec2 p, float seed, float kind, float hue, float aa) {
  if (kind < .5 && uSeason > 2.5) return bareTree(p, seed, aa);
  vec3 L = normalize(TL);
  float h = -1., edge = 9.; vec3 n = vec3(0., 0., 1.);
  float det = 1. - smoothstep(.03, .09, aa);           // leaf detail fades when the tree is small on screen
  vec3 dark, mid, light;
  if (kind < .5) {
    for (int k = 0; k < 8; k++) {
      float fk = float(k), a = fk * 2.39996 + seed * 6.2832;
      float rr = k == 0 ? 0. : .36 + .14 * th12(vec2(seed * 7.1, fk));
      vec2 c = vec2(cos(a), sin(a)) * rr;
      float r = k == 0 ? .52 : .3 + .12 * th12(vec2(fk + 2., seed * 3.3));
      vec2 d = p - c; float l = length(d);
      float wob = (gnoise(d / max(l, 1e-4) * 1.7 + vec2(fk * 3.1, seed * 11.)) - .5) * .22 + (gnoise(p * 9. + seed * 5.) - .5) * .1 * det;
      float R = r * (1. + wob), q = l / R;
      edge = min(edge, l - R);
      if (q < 1.) { float z = sqrt(1. - q * q) * r + (k == 0 ? .1 : 0.); if (z > h) { h = z; n = normalize(vec3(d / R * .9, sqrt(max(1. - q * q, .04)))); } }
    }
    dark = vec3(.09, .14, .06); mid = vec3(.25, .34, .13); light = vec3(.54, .6, .3);
  } else {
    float l = length(p), ang = atan(p.y, p.x);
    for (int t = 0; t < 3; t++) {
      float ft = float(t), nb = 9. - ft * 2., rot = seed * 6.2832 + ft * 1.3;
      float star = .72 + .28 * pow(abs(cos((ang + rot) * nb * .5)), .8);
      vec2 dir = p / max(l, 1e-4);
      star *= (1. - ft * .3) * (1. + (gnoise(dir * 2.2 + vec2(ft * 9., seed * 7.)) - .5) * .3 + (gnoise(dir * 6. + ft * 3. + seed) - .5) * .12);
      float R = star * .95;
      if (t == 0) edge = l - R;
      if (l < R) { float z = ft * .3 + (1. - l / R) * .35; if (z > h) { h = z;
        float ridge = sin((ang + rot) * nb) * .5;
        n = normalize(vec3(p / max(l, 1e-3) * .75 + vec2(-sin(ang), cos(ang)) * ridge * .35, 1.)); } }
    }
    dark = vec3(.06, .12, .08); mid = vec3(.16, .3, .16); light = vec3(.44, .56, .3);
  }
  // each tree its own shade: some yellower, some bluer and darker
  vec3 tint = mix(vec3(.9, .96, 1.08), vec3(1.1, 1.05, .82), hue);
  dark *= tint; mid *= tint; light *= tint;
  if (kind < .5 && uSeason > 1.5 && uSeason < 2.5) {               // autumn: gold, orange or rust, a few still turning
    float pick = fract(seed * 7.31 + hue * .37);
    vec3 leaf = pick < .38 ? vec3(.76, .6, .26) : pick < .72 ? vec3(.74, .46, .22) : pick < .9 ? vec3(.56, .3, .18) : vec3(.56, .56, .27);
    leaf = mix(leaf, vec3(dot(leaf, vec3(.3, .55, .15))), .15);   // a little muted, as on the rest of the island
    dark = leaf * vec3(.32, .26, .22); mid = leaf * .72; light = min(leaf * 1.18 + .06, vec3(1.));
  }
  if (h < -.5) return vec4(0.);
  // the whole crown is one rounded form too: its lower right falls into shade
  n = normalize(mix(n, normalize(vec3(p * .85, 1.)), .4));
  float d1 = 9., d2 = 9.;
  if (kind < .5) {
    // leaf clusters: soft domes of a few sizes on the canopy, dark crevices between them
    vec2 bv = vec2(0.);
    vec2 g = p * 3.3 + seed * 17., gi = floor(g), gf = g - gi;
    for (int k = 0; k < 9; k++) { vec2 o = vec2(float(k % 3 - 1), float(k / 3 - 1)); vec2 v = o + .15 + .7 * vec2(th12(gi + o), th12(gi + o + 9.)) - gf; float d = length(v);
      if (d < d1) { d2 = d1; d1 = d; bv = v; } else if (d < d2) d2 = d; }
    // leaves: a fine broken texture tilting the light, not cells
    vec2 lp = p * 13. + seed * 5.; float e = gnoise(lp), ex = gnoise(lp + vec2(.35, 0.)) - e, ey = gnoise(lp + vec2(0., .35)) - e;
    n = normalize(n + vec3(-bv * .8, 0.) * det + vec3(-ex, -ey, 0.) * 2.2 * det);
  } else {
    // needles: fine streaks running out from the top
    float l = length(p), ang = atan(p.y, p.x);
    float st = gnoise(vec2(ang * 14. + seed * 9., l * 5.)) - .5;
    n = normalize(n + vec3(vec2(-sin(ang), cos(ang)) * st * .9, 0.) * det);
    d1 = 0.; d2 = .2 + abs(st) * .3;
  }
  float lit = dot(n, L);
  vec3 col = mix(dark, mid, smoothstep(-.3, .35, lit));
  col = mix(col, light, smoothstep(.35, .88, lit) * .9);
  col *= mix(1., .76 + .24 * smoothstep(0., .3, d2 - d1), det);          // soft crevices between clusters
  col *= .62 + .38 * smoothstep(.0, .3, h);                              // deeper where lumps meet and toward the rim
  col *= 1. + (th12(floor(p * 40.) + seed) - .5) * .12 * det;            // a painterly speckle
  if (kind > .5 && uSeason > 2.5) {                                // winter: snow on the conifers' boughs, thickest where the light falls
    float sn = smoothstep(.0, .55, lit + (gnoise(p * 7. + seed * 4.) - .5) * .7) * .8;
    col = mix(col, vec3(.86, .9, .95) * (.78 + .3 * smoothstep(-.2, .9, lit)), sn);
  }
  if (kind < .5 && uSeason < .5 && fract(seed * 13.7) < .3) {      // spring: some trees in blossom
    vec2 bc = floor(p * 15. + seed * 3.);
    if (th12(bc) > .72 && lit > -.1) col = mix(col, th12(bc + 2.) < .5 ? vec3(.97, .93, .94) : vec3(.95, .76, .84), .75 * det);
  }
  float a = clamp(-edge / max(aa, 1e-4) * .8 + .5, 0., 1.);
  return vec4(col * a, a);
}
float ring(float r, float at, float w) { return clamp(w * .5 - abs(r - at) / fwidth(r) * w * .5 + .5, 0., 1.); }
void main() {
  int flags = int(vFlags + .5);
  vec4 c;
  if (vLayer >= 0.) {
    vec2 uv = vUV; float m = 1., gust = 0.;
    float edge = 1.;
    if ((flags & 4) != 0) {          // a field tile: its picture repeats, so it can run past the tile, and its outline is one smooth shape
      vec2 t = vLocal;               // FIELD_REACH (1): tile coordinates around the tile's middle (y down)
      // wind: slow gusts rolling across the fields, a soft lift of light and a hair of sway as each one passes
      if ((flags & 8) != 0) {
        float ph = dot(vWorld, vec2(.83, .55)) * 1.1 - uTime * 1.6 + gnoise(vWorld * .35) * 2.5;
        gust = pow(.5 + .5 * sin(ph), 2.) * (.7 + .3 * sin(uTime * .31 + vWorld.y * .2)) * uGust;
        gust += .35 * pow(.5 + .5 * sin(dot(vWorld, vec2(.6, .8)) * 2.7 - uTime * 2.3), 3.) * uGust;   // smaller ripples riding on the gusts
      }
      vec2 inset = 1.5 / max((vRegion.zw - vRegion.xy) * vec2(textureSize(uAtlas, 0).xy), vec2(1.));   // keep a texel and a half from the picture's edge: no seam where it repeats
      uv = mix(vRegion.xy, vRegion.zw, clamp(fract(t + .5 + vec2(.022, .014) * gust), inset, 1. - inset));
      // how much field is here: the 3x3 tiles around, each blended in smoothly (the weights add up to one everywhere), so
      // the outline is the same seen from any tile, rounds the corners and runs diagonals as clean curves
      float fv = 0.;
      for (int k = 0; k < 9; k++) {
        ivec2 o = ivec2(k % 3 - 1, k / 3 - 1);
        float on = k == 4 ? 1. : float((flags >> (4 + (k < 4 ? k : k - 1))) & 1);
        vec2 d = abs(t - vec2(o));
        fv += on * (1. - smoothstep(0., 1., d.x)) * (1. - smoothstep(0., 1., d.y));
      }
      float sd = float(flags >> 20);
      ivec2 cell = ivec2(floor(t + .5));                 // which tile this point is on: its own, or a neighbour
      int ck = (cell.y + 1) * 3 + cell.x + 1;
      bool mine = ck == 4 || ((flags >> (12 + (ck < 4 ? ck : ck - 1))) & 1) == 0;   // a neighbour with the same crop draws there itself
      float n = gnoise(vWorld * 1.6 + sd * 7.31) * .6 + gnoise(vWorld * 4.5 + sd * 3.17) * .28 + gnoise(vWorld * 12. + sd) * .12;
      // a bed stops a little short of its tile where something else begins, so bare soil runs between beds; its edge only gently uneven
      float e = fv - (.66 + (n - .5) * .1), w = max(fwidth(fv) * 1.2, 1e-4);
      // the soil's shape, smoothed over a few samples so the margin between the plants and the soil's edge stays even
      float sv = 0., pv = 0.;
      for (int k = 0; k < 9; k++) { vec4 g = texture(uSoil, (vWorld + vec2(float(k % 3 - 1), float(k / 3 - 1)) * .22) / uMap); sv += g.b; pv = max(pv, g.a); }
      float so = sv / 9. - (.62 + (n - .5) * .04), ws = max(fwidth(so) * 1.2, 1e-4);   // just inside the soil's edge (.535): low enough that the soil's small dips beside a diagonal path never cut holes
      float po = .2 - pv, wpv = max(fwidth(pv) * 1.2, 1e-4);   // and keep off paths, with a little soil between (a path's edge is at .5)
      m = clamp(e / w + .5, 0., 1.) * clamp(so / ws + .5, 0., 1.) * clamp(po / wpv + .5, 0., 1.) * (mine ? 1. : 0.);   // a neighbour of the same crop draws its own part (perhaps at another stage)
      edge = smoothstep(0., .12, min(min(e, so), po * .5));                     // the outermost plants a little darker
    }
    c = texture(uAtlas, vec3(uv, vLayer)) * m;
    if ((flags & 4) != 0) c.rgb *= (1. + .07 * gnoise(vWorld * 1.3) - .035 + .2 * gust) * (.82 + .18 * edge);   // not one flat colour; a gust lifts the light; shade at the rim
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
    // light falls off with the square of the distance, eased to nothing at the edge; a window's light only forward
    float fall = max(0., (1. / (1. + r * r * 14.) - 1. / 15.) / (1. - 1. / 15.));
    if (vColor.z > .5) fall *= smoothstep(-.12, .25, vLocal.y);
    float pool = fall * .6, cut = min(1., fall * 1.3);
    c = vec4(vec3(1., 210. / 255., 130. / 255.) * max(pool, 0.) * vColor.x, max(cut, 0.) * vColor.y) * step(r, 1.);
  } else if (vLayer > -8.5) {        // a dot: a small filled circle
    float r = length(vLocal), e = fwidth(r);
    c = vec4(vColor.rgb, 1.) * vColor.a * clamp((1. - r) / e, 0., 1.);
  } else if (vLayer > -9.5) {        // a tile marked for building: a light fill and a crisp rim just inside its edge
    vec2 q = abs(vLocal); float m = max(q.x, q.y), e = fwidth(m);
    float rim = clamp((m - .86) / e + .5, 0., 1.) * clamp((.97 - m) / e + .5, 0., 1.);
    c = vec4(vColor.rgb, 1.) * vColor.a * max(rim, .32 * step(m, .97));
  } else if (vLayer > -10.5) {       // a puff of smoke: soft, densest in the middle, a little lighter on its upper left
    float r = length(vLocal), a = smoothstep(1., .1, r);
    vec3 col = vColor.rgb * (1.04 - .1 * clamp(vLocal.x + vLocal.y, -1., 1.));
    c = vec4(col, 1.) * vColor.a * a * a;
  } else if (vLayer < -12.5) {       // an ice floe (seed, -, -, alpha): an angular plate, white on top, its sunk rim showing turquoise through the water
    vec2 q = vLocal; float sd = vColor.x, r = length(q), ang = atan(q.y, q.x);
    // an irregular plate: 5-8 corners at uneven angles and distances; the rim is the nearest edge along the ray from the
    // middle (the plate is convex), a little broken
    float n = 5. + floor(sd * 4.), sec = 6.2832 / n, R = 9.; vec2 dr = vec2(cos(ang), sin(ang));
    for (int k = 0; k < 8; k++) { if (float(k) >= n) break;
      float fk = float(k), fk1 = mod(fk + 1., n);
      float b0 = (fk + (th12(vec2(fk, sd * 7.)) - .5) * .5) * sec + sd * 6.2832, b1 = (fk + 1. + (th12(vec2(fk1, sd * 7.)) - .5) * .5) * sec + sd * 6.2832;
      vec2 v0 = vec2(cos(b0), sin(b0)) * (.55 + .4 * th12(vec2(fk, sd * 3.1))), v1 = vec2(cos(b1), sin(b1)) * (.55 + .4 * th12(vec2(fk1, sd * 3.1)));
      vec2 e01 = v1 - v0, nrm = normalize(vec2(e01.y, -e01.x)); float dd = dot(v0, nrm), dn = dot(dr, nrm);
      if (dd < 0.) { nrm = -nrm; dd = -dd; dn = -dn; }
      if (dn > 1e-3) R = min(R, dd / dn); }
    R *= .95 + .08 * gnoise(vec2(ang * 6. + sd * 9., sd * 3.));
    R = clamp(R, .2, .97);
    float e = fwidth(r), top = clamp((R - .09 - r) / e + .5, 0., 1.), sunk = clamp((R - r) / e + .5, 0., 1.);
    vec3 face = mix(vec3(.82, .88, .93), vec3(.96, .98, 1.), smoothstep(.3, -.6, q.x + q.y));          // lit from the upper left
    face *= 1. - .06 * gnoise(q * 4. + sd * 7.);
    vec3 col = mix(vec3(.55, .78, .82), face, top);
    c = vec4(col, 1.) * vColor.a * max(top, sunk * .55) * (1. - cloudCover(vWorld));   // hidden under the clouds like the sea round it
  } else if (vLayer < -11.5) {       // a flame (seed, how lively, -, alpha): tongues licking upward, white-hot at the root
    vec2 q = vLocal; float sd = vColor.x * 17., tm = uTime * (1.6 + vColor.y);
    float h = clamp((.9 - q.y) / 1.8, 0., 1.);                                   // 0 at the root, 1 at the top of the quad
    float lick = (gnoise(vec2(q.x * 1.8 + sd, q.y * 2.2 + tm * 2.6)) - .5) * 1.1 + (gnoise(vec2(q.x * 4. - sd, q.y * 4. + tm * 4.3)) - .5) * .45;
    float x = q.x + lick * h * .55;
    float tall = .78 + .14 * sin(tm * 3.1 + sd) + .08 * sin(tm * 7.7);          // the tip leaps and falls
    float hh = h / tall, width = .62 * pow(max(0., 1. - hh), .9) * smoothstep(0., .22, hh + .05);
    float d = abs(x) / max(width, 1e-3), e = fwidth(d) + .03;
    float inside = (1. - smoothstep(1. - e, 1. + e, d)) * (1. - smoothstep(.82, .98, hh)) * step(.004, width);   // the tip fades out (where the flame is a hair thin it would draw a line)
    float heat = clamp((1. - d) * (1. - hh * .85), 0., 1.);
    vec3 col = mix(vec3(.75, .16, .04), vec3(1., .5, .1), smoothstep(.05, .35, heat));
    col = mix(col, vec3(1., .86, .45), smoothstep(.35, .7, heat));
    col = mix(col, vec3(1., .98, .9), smoothstep(.72, .95, heat));
    c = vec4(col, 1.) * inside * vColor.a * (.85 + .15 * heat);
  } else {                           // a tree, painted (seed, kind 0 broadleaf / 1 conifer, its own shade, alpha)
    c = treeCol(vLocal, vColor.x, vColor.y, vColor.z, fwidth(vLocal.x)) * vColor.a;
  }
  if (vColor.a < 0.) {               // a hologram (alpha -1 blue: planned, -2 red: to be erased): its light, in one colour, with scan lines
    float s = -vColor.a; c /= -s;
    float a = c.a, l = a > 0. ? dot(c.rgb / a, vec3(.299, .587, .114)) : 0.;
    vec3 tint = s > 1.5 ? vec3(1., .34, .3) : vec3(.38, .8, 1.);
    float scan = .8 + .2 * sin(gl_FragCoord.y * 1.3 - uTime * 4.);
    float al = a * (.58 + .06 * sin(uTime * 2.3));
    c = vec4(tint * (.5 + .8 * l) * scan * al, al);
  }
  if ((flags & 4194304) != 0 && c.a > 0.) {   // on the sea floor, seen through the water: a dark shape more than a picture, fainter the deeper it lies
    vec4 tw = terrain(vWorld, uCam.z);
    float l = dot(c.rgb / c.a, vec3(.299, .587, .114)), deep = smoothstep(.1, 1.2, tw.w);
    if (vColor.a > .985) {                                      // a wreck: a dark shape, only a hint of its light and dark left
      vec3 shade = vec3(.03, .17, .22) * (.55 + .5 * l);
      c = vec4(shade, 1.) * c.a * mix(.62, .32, deep);
    } else {                                                    // a reef (drawn at alpha .97): living colour, muted and turned turquoise by the water
      vec3 b = mix(vec3(l), c.rgb / c.a, .45);
      vec3 trans = exp(-clamp(tw.w, 0., 1.5) * vec3(1.6, .85, .7));
      vec3 col = b * trans * vec3(.85, 1., 1.02) + vec3(.1, .4, .46) * (1. - trans);
      c = vec4(col, 1.) * c.a * mix(.62, .4, deep);
    }
  }
  if ((flags & 2) != 0) {            // under water: tinted by it, and only where the water is
    float f = wetness(terrain(vWorld, uCam.z));
    float cov = clamp(f * uCam.z + .5, 0., 1.);
    if ((flags & 4194304) == 0) c.rgb = mix(c.rgb, vec3(40., 110., 170.) / 255. * c.a, .35);   // (the sea floor has its own depth tint)
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
  picture(r: Region, x: number, y: number, rect: [number, number, number, number], o: { rot?: number; sx?: number; sy?: number; sway?: number; phase?: number; shear?: number; color?: [number, number, number, number]; flags?: number } = {}) {
    this.put(x, y, rect, o.rot ?? 0, o.sx ?? 1, o.sy ?? 1, o.shear !== undefined ? -1 : o.sway ?? 0, o.shear ?? o.phase ?? 0, [r.u0, r.v0, r.u1, r.v1], r.layer, o.color ?? [1, 1, 1, 1], o.flags ?? 0)
  }

  /** A tree painted in the shader, centred at (x, y), its crown r tiles across from the middle; sway as for pictures. */
  tree(x: number, y: number, r: number, seed: number, kind: number, hue: number, sway = 0, phase = 0, alpha = 1) {   // alpha -1 / -2: a blue / red hologram
    this.put(x, y, [-r, -r, r, r], 0, 1, 1, sway, phase, [0, 0, 1, 1], SHAPE.tree, [seed, kind, hue, alpha], 0)
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
  /** the season the trees are painted in: 0 spring, 1 summer, 2 autumn, 3 winter */
  season = 1
  draw(atlas: WebGLTexture, field: WebGLTexture, fieldSize: [number, number], map: [number, number], cam: { x: number; y: number; z: number }, W: number, H: number, o: { flip?: boolean; time?: number; gust?: number; from?: number; to?: number; blend?: 'premult' | 'max' | 'light'; soil?: WebGLTexture; cloud?: number[] } = {}) {
    const from = o.from ?? 0, to = o.to ?? this.n; if (to <= from) return
    const gl = this.gl, P = this.P
    gl.useProgram(P.p); gl.bindVertexArray(this.vao)
    gl.bindBuffer(gl.ARRAY_BUFFER, this.buf)
    gl.bufferData(gl.ARRAY_BUFFER, this.data.subarray(from * STRIDE, to * STRIDE), gl.STREAM_DRAW)
    gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D_ARRAY, atlas); gl.uniform1i(P.u.uAtlas, 0)
    gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D, field); gl.uniform1i(P.u.uH, 1)
    gl.activeTexture(gl.TEXTURE9); gl.bindTexture(gl.TEXTURE_2D, o.soil ?? field); gl.uniform1i(P.u.uSoil, 9); gl.activeTexture(gl.TEXTURE0)   // a unit of its own: the ground bake keeps its textures on the low ones
    gl.uniform2f(P.u.uHSize, fieldSize[0], fieldSize[1]); gl.uniform2f(P.u.uMap, map[0], map[1])
    gl.uniform3f(P.u.uCam, cam.x, cam.y, cam.z); gl.uniform2f(P.u.uView, W, H)
    gl.uniform1f(P.u.uFlip, o.flip === false ? 1 : -1); gl.uniform1f(P.u.uTime, o.time ?? 0); gl.uniform1f(P.u.uGust, o.gust ?? 1); gl.uniform1f(P.u.uSeason, this.season); gl.uniform4f(P.u.uCloud, ...(o.cloud ?? [0, 0, 0, 0]) as [number, number, number, number])
    gl.enable(gl.BLEND)
    if (o.blend === 'max') gl.blendEquation(gl.MAX)
    else if (o.blend === 'light') gl.blendFuncSeparate(gl.ONE, gl.ONE, gl.ZERO, gl.ONE_MINUS_SRC_ALPHA)   // light adds up; the dark's remaining strength multiplies down
    else gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
    gl.drawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, to - from)
    gl.blendEquation(gl.FUNC_ADD); gl.disable(gl.BLEND)
    gl.bindVertexArray(null)
  }
}

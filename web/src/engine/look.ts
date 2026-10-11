// The look of the ground, after the planet map: grass in broad soft patches with a fine mottle and a few pale specks,
// sandy beaches, and the planet map's warm light and cozy grade. Paths, soil and mountain rock are painted the same
// way, so every ground belongs to one picture. uLook picks between versions while the look is being chosen:
//   x  path   0 packed earth, 1 gravel, 2 flagstones
//   y  soil   0 furrows, 1 tilled clods, 2 furrows with sprouts
//   z  rock   0 planet rock and snow, 1 greener, a smaller snow cap
// Needs GLSL_NOISE before it and `uniform vec4 uLook;` declared.
export const GLSL_LOOK = `
float vnoise(vec2 p) { vec2 i = floor(p), f = fract(p), u = f * f * (3. - 2. * f);
  return mix(mix(th12(i), th12(i + vec2(1., 0.)), u.x), mix(th12(i + vec2(0., 1.)), th12(i + 1.), u.x), u.y); }
vec2 th22(vec2 p) { return vec2(th12(p), th12(p + 19.19)); }
vec3 rgbL(float r, float g, float b) { return vec3(r, g, b) / 255.; }
float detailAt(float px) { return smoothstep(20., 90., px); }
// the nearest of a scatter of points (one per cell): x its distance, y the distance to the next nearest, zw its cell
vec4 cells(vec2 p) {
  vec2 i = floor(p), f = p - i; float d1 = 8., d2 = 8.; vec2 best = i;
  for (int k = 0; k < 9; k++) { vec2 o = vec2(float(k % 3 - 1), float(k / 3 - 1)); float d = length(o + .15 + .7 * th22(i + o) - f);
    if (d < d1) { d2 = d1; d1 = d; best = i + o; } else if (d < d2) d2 = d; }
  return vec4(d1, d2, best);
}

// grass, as on the planet map: two greens in broad patches, a fine mottle where a pixel can show it, pale specks
vec3 grassCol(vec2 p, float px) {
  float gn = fbm3(p * .3 + 2.) * .7 + fbm3(p * 1.1 + 8.) * .3;
  vec3 c = mix(rgbL(70., 89., 42.), rgbL(108., 120., 64.), gn);
  float det = detailAt(px);
  c *= 1. + (vnoise(p * 6.) * .6 + vnoise(p * 14.) * .4 - .5) * .22 * det;
  c *= 1. + (vnoise(p * 34.) - .5) * .1 * smoothstep(120., 300., px);
  vec2 fc = floor(p * 8.);
  if (th12(fc) > .975 && length(fract(p * 8.) - .5) < .3) c = mix(c, rgbL(176., 170., 140.), .5 * det);
  return c;
}
// sand, as the planet map's beaches
vec3 sandCol(vec2 p, float px) {
  vec3 c = mix(rgbL(176., 162., 130.), rgbL(196., 184., 154.), fbm3(p * .75));
  return c * (1. + (vnoise(p * 20.) - .5) * .1 * detailAt(px));
}
vec3 soilCol(vec2 p, float px) {
  float det = detailAt(px), n = fbm3(p * .8 + 5.);
  vec3 c = mix(rgbL(92., 64., 42.), rgbL(122., 88., 58.), n);
  c *= 1. + (vnoise(p * 12.) - .5) * .2 * det;                                // clods
  int v = int(uLook.y + .5);
  if (v == 1) {                                                               // tilled clods: little lumps, lit on top
    vec4 q = cells(p * 5.);
    c *= .86 + .28 * smoothstep(.45, .05, q.x) * (.7 + .3 * th12(q.zw));
    return c;
  }
  float r = fract(p.y * 2. + (gnoise(p * .45) - .5) * .25);                    // furrows across the field, two a tile
  c *= .74 + .36 * smoothstep(0., .45, r) * smoothstep(1., .55, r);
  if (v == 2) {                                                               // sprouts along the ridges
    vec2 g = floor(vec2(p.x * 3., p.y * 2.)), f = fract(vec2(p.x * 3., p.y * 2.)) - vec2(.5, .3);
    float s = step(.35, th12(g)) * smoothstep(.16, .08, length(f * vec2(1., 1.6)));
    c = mix(c, mix(rgbL(96., 132., 54.), rgbL(132., 160., 74.), th12(g + 3.)), s * det);
  }
  return c;
}
vec3 pathCol(vec2 p, float px) {
  float det = detailAt(px);
  int v = int(uLook.x + .5);
  if (v == 1) {                                                               // gravel: small pebbles, packed close
    vec4 q = cells(p * 10.);
    vec3 c = mix(rgbL(150., 142., 126.), rgbL(184., 176., 158.), th12(q.zw)) * (.9 + .1 * fbm3(p * .7));
    return mix(rgbL(122., 112., 94.), c, smoothstep(.02, .1, q.y - q.x) * det + (1. - det) * .8);
  }
  if (v == 2) {                                                               // flagstones, grass in the joints
    vec4 q = cells(p * 4.2);                                                  // stones sized for a narrow footpath
    vec3 stone = mix(rgbL(150., 144., 132.), rgbL(186., 178., 162.), th12(q.zw)) * (.92 + .16 * vnoise(p * 9.));
    return mix(grassCol(p, px) * .85, stone, smoothstep(.03, .09, q.y - q.x));
  }
  vec3 c = mix(rgbL(164., 140., 102.), rgbL(186., 164., 124.), fbm3(p * .9));     // packed earth, worn smooth
  c *= 1. + (vnoise(p * 9.) - .5) * .14 * det;
  vec2 g = floor(p * 9.), f = fract(p * 9.) - .5 - (th22(g) - .5) * .4;
  float peb = step(.88, th12(g + 7.)) * smoothstep(.2, .12, length(f));
  return mix(c, mix(rgbL(128., 114., 92.), rgbL(208., 196., 170.), th12(g + 1.)), peb * det);
}
// the planet map's grade: fuller colour, a warm white, the shadows lifted with a little cool light, soft highlights
vec3 cozy(vec3 col) {
  float l = dot(col, vec3(.299, .587, .114));
  col = mix(vec3(l), col, 1.22) * vec3(1.03, 1.02, .92) * 1.12;
  col += vec3(.55, .62, .82) * .06 * (1. - smoothstep(0., .55, l));
  col = (col - .45) * .96 + .45;
  return col / (1. + max(col - .9, 0.) * 1.6);
}
`

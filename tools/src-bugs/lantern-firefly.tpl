<palette name="Lantern firefly" c1="#3A3248" c2="#5E5478" c3="#D8D0E8" c4="#14101C" c5="#FFE45A"/>
  <!-- far wing -->
  <fan b="230,212 262,206" t="90,112 190,70" n="3" cls="c3 c2" shape="quad"/>
  <!-- legs -->
  <polygon class="c4" points="250,250 262,290 252,302 244,298 252,266 240,254"/>
  <polygon class="c4" points="232,252 232,292 220,306 212,302 220,288 222,254"/>
  <polygon class="c4" points="214,248 204,286 190,296 184,290 196,282 204,248"/>
  <!-- abdomen with glowing lantern -->
  <ribbon pts="226,230,34 182,252,36 140,274,32" cls="c1" top="c2" under="c4"/>
  <ribbon pts="140,274,32 100,296,30 66,316,22 50,326,10" cls="c5" top="c3" under="c5"/>
  <!-- thorax and head -->
  <polygon class="c1" points="230,206 270,196 290,226 266,256 226,248"/>
  <polygon class="c2" points="230,206 270,196 290,226 252,222"/>
  <polygon class="c1" points="286,214 314,208 328,230 312,252 288,248"/>
  <polygon class="pupil" points="294,214 312,212 320,230 308,244 294,238"/>
  <circle class="eye" cx="304" cy="224" r="2.6"/>
  <ribbon pts="304,212,3 316,184,2 340,168,1.5" cls="c4"/>
  <ribbon pts="296,214,3 290,184,2 304,160,1.5" cls="c4"/>
  <!-- near wing -->
  <fan b="236,206 266,198" t="130,60 250,40" n="4" cls="c3 c2" shape="quad"/>
</svg>

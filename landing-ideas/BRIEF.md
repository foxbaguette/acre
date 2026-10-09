# Unclaimed Acres: landing page concepts

Ten COMPLETELY different landing page ideas for **Unclaimed Acres**, a calm, professional island farming and
creature game on the WAX blockchain. The look is inspired by the Anno games (polished, painterly strategy
game quality), but the game is meant to be played in a very chill way. The current landing page only shows an
island; these concepts must show off the WHOLE game: **islands, creatures and crops**.

Each concept is ONE self-contained file `landing-ideas/NN-slug.html` (NN = 01-10). Served at
`http://localhost:5181/landing-ideas/NN-slug.html`, so reference art with relative paths (`../crops/...`).

## Hard rules

- Plain HTML + CSS (+ a little vanilla JS only if it really helps). No frameworks, no build step, no CDN JS.
  Google Fonts are allowed (pick fonts that fit your concept; do not all use Cinzel).
- A real, finished-looking landing page, not a wireframe: header with logo, hero, 3-5 content sections, a
  final call to action, footer. Desktop first (judge it at 1440 x 900), but it must also work at 375px wide
  with no horizontal scrolling.
- Primary action everywhere: **Connect wallet** (buttons only, they do nothing). Mention the wallets once:
  WAX Cloud Wallet, Wombat, Anchor.
- Use the real art below generously and well: islands, creatures AND crops all need a strong presence.
- Honest copy: the game exists in development. Safe facts: every island is generated and stored on the WAX
  blockchain and owned by your wallet; no two islands alike (peninsulas, bays, beaches, forests, terraced snowy
  mountains, lakes); 64 crops, each drawn through 8 stages from seed to harvest (and wilted); more than 50
  creatures, drawn from the side and from above; play at your own pace. Do NOT invent prices, token names,
  release dates, player counts, trading, PvP or roadmap promises.
- The art style is flat, faceted low-poly with no outlines. Let it breathe on calm backgrounds. Never stretch
  or distort images; keep aspect ratios (all SVGs are square 400 x 400).
- Logo: `assets/emblem.svg` (brass medallion with an island) plus the name "Unclaimed Acres" set in your
  concept's display font. You may restyle the name, not the emblem.
- Accessible: real text (not text in images), alt text on meaningful images, visible focus styles, good
  contrast, `prefers-reduced-motion` respected if you animate anything. Subtle motion only.
- At the top of each file put an HTML comment: concept name, one-line idea, palette, fonts.
- Do not touch any file outside your own `NN-slug.html` (you may add `assets/NN-*` files if you truly need
  them, e.g. an SVG pattern).

## Art you can use (paths relative to landing-ideas/)

Islands (renders of a real on-chain island, 1920 x ~1090 webp):
- `assets/island-hero.webp` whole island on the right, open sea on the left (good behind text)
- `assets/island-overview.webp` whole island centred
- `assets/island-close.webp` close-up: terraced snowy mountain, forests, beaches

Creatures: `../topdown/<id>/side.svg` (side view, the hero view) and `../topdown/<id>/top.svg` (seen from
above, as on the map). Ids:
animals__fox, animals__deer, animals__owl, animals__raven, animals__redpanda, beasts__blossom-stag,
beasts__bone-howler, beasts__frost-mammoth, beasts__lantern-giraffe, bone__crypt-bat, bugs__lantern-firefly,
carnivores__snow-leopard, creatures__crystal-spider, creatures__dragon, creatures__fire-salamander,
creatures__gem-scarab, creatures__kitsune, creatures__lancer-hornet, creatures__phoenix,
creatures__sea-serpent, deepsea__crystal-crab-polished, deepsea__ember-octopus, deepsea__leaf-dragon,
dinos__aurora-pterosaur, dinos__gem-parasaurolophus, dinos__thunder-diplodocus, europe__black-shuck,
europe__fenrir, europe__jormungandr, europe__kraken, europe__nessie, felines__moon-cat, felines__moss-ocelot,
flyers__aether-jelly, flyers__crest-wyrm, flyers__glass-dragonfly, flyers__pegasus, flyers__simurgh,
flyers__sky-squid, hell__hellspinner, hell__nightmare, hell__skull-crab, hell__torment-ram, hoofed__camel,
hoofed__mountain-goat, mythsea__cadborosaurus, orochi__gold-orochi, rats__black-rat, story__wind-hare,
turtles__crystal-turtle, yokai__baku, yokai__kirin, yokai__shachihoko
(Look at a few before choosing; friendly, cosy ones suit a chill game best: fox, red panda, deer, owl,
kitsune, moon-cat, moss-ocelot, wind-hare, blossom-stag, crystal-turtle, pegasus, lantern-giraffe, baku,
kirin, glass-dragonfly, phoenix, aether-jelly, crystal-crab. Avoid the hell__ and bone__ ones unless your
concept needs them.)

Crops: `../crops/<crop>/<stage>.svg`, stages:
`1-seeds-front` (seed packet/seeds), `2-sown`, `3-first-growth`, `4-second-growth`, `5-third-growth`,
`6-harvest` (stages 2-6 are seen from ABOVE on a soil tile, same scale, perfect for a growth sequence),
`7-harvest-front` (the harvested produce, inventory-item style, great as product shots), `8-dead` (wilted).
Crops: banana basil beans beetroot bell-pepper blue-java blueberries broccoli buddhas-hand cabbage cacao
carolina-reaper carrots champignon chanterelle coffee corn cucumber custard-apple dragon-fruit durian
egg-plant (a silly plant that grows eggs) eggplant ember-pepper (fantasy) finger-lime garlic glowcap
(fantasy glowing mushroom) grapes jabuticaba kiwano kiwi lemon lettuce lime mandarin mangosteen milk-pouch
(silly: grows milk pouches) mint monstera moonbloom (fantasy) oats olive orange peanuts peas pineapple
pineberry pink-guava potatoes pumpkin radish rambutan raspberries red-cabbage red-wheat rice rye salak
spring-onions strawberries sugar-cane sunflower thyme tomatoes watermelon wheat zucchini

Tiles (seamless 400 x 400 squares, great as textures/patterns): `../tiles/` grass-01..20, sand-01..04,
sea-01..06, water-01..06, rock-01..04, path-01..04, soil, tree-01..06 (trees seen from above, transparent),
fence-NESW (16 transparent fence pieces, e.g. fence-0101 = east-west run), decor-*.svg (bush-1/2, flowers-1/2,
lily, reeds-1/2, stone-1/2, stump, driftwood, meadow-yellow/white/purple/tall/clover).

## Check your own work

Screenshot at desktop size with headless Edge (use a fresh profile folder each run or it silently does nothing):

```
"/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" --headless=new --disable-gpu --hide-scrollbars --no-first-run --user-data-dir="C:\Users\Foxy\AppData\Local\Temp\edge-<unique>" --window-size=1440,900 --virtual-time-budget=8000 --screenshot="C:\path\to\shot.png" "http://localhost:5181/landing-ideas/NN-slug.html"
```

For the full page height, make the window tall, e.g. `--window-size=1440,4200`. Look at the screenshots
(Read tool) and polish until it looks like a page a top studio would ship: spacing, alignment, type scale,
image quality, no broken images, nothing overlapping. Headless Edge cannot go below ~500px wide; check
375px by reasoning about your CSS (media queries, min(), clamp(), flex-wrap) instead.

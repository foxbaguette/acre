# Crops brief (read fully before starting)

Project C:/Claude/Cute Fox: faceted low-poly SVG game art. Crops are grown in a top-down farming game.
Reference that the user loved: crops/wheat/*.svg, made by tools/crops/wheat.pl. READ wheat.pl and study all 8 wheat
SVGs first. Copy its helper approach (blade, grain, ear, tuft, soil, write_svg) into your own generator
tools/crops/<crop>.pl and add the shapes your crop needs (round fruit, berry, leaf, bulb, vine, cap...).

## The 8 images per crop (exact file names, in crops/<crop>/)
1-seeds-front.svg    the seed / planting material seen from the FRONT (e.g. strawberry runner seeds, potato seed tuber
                     cut piece, pineapple crown, spring-onion seeds or sets, mushroom spores in a little heap)
2-sown.svg           TOP DOWN, just sown: the seeds/sets pressed into small soil pockets (like wheat stage 2)
3-first-growth.svg   TOP DOWN, small seedling
4-second-growth.svg  TOP DOWN, young plant, clearly that crop's leaf shape
5-third-growth.svg   TOP DOWN, mature plant, flowers or small unripe fruit appearing
6-harvest.svg        TOP DOWN, ready to harvest: ripe fruit/heads/roots clearly visible and the most beautiful stage
7-harvest-front.svg  FRONT view of the HARVESTED PRODUCE ONLY: what the player gets from the harvest, like an
                     inventory item. No plant, no soil. E.g. a wheat sheaf, 2-3 strawberries, a lettuce head,
                     a tomato truss, a pineapple with crown, a pile of potatoes, a pumpkin with stalk.
8-dead.svg           TOP DOWN, the plant DIED because it was not watered: cracked dry soil, limp withered dried-out
                     leaves in straw/brown tones lying flat, no healthy fruit (shrivelled is fine). Same scale as 2-6.
                     It must be unmistakably dead and never confusable with the harvest stage.

## Fixed scale (important for the game)
- Stages 2-6 and 8 are top down, centred on (200,200), all at ONE shared scale: the plant visibly grows from tile to
  tile. Rough radii: sown 50-70, first ~70-90, second ~110-130, third ~150, harvest ~165-185 (fills the tile), dead
  ~ like second/third. Bigger plants (pumpkin vine, kiwi bush) may use the full radius earlier.
- NEVER run center.pl on 2-6 or 8. Run perl tools/center.pl only on 1-seeds-front.svg and 7-harvest-front.svg.
- Each SVG: <?xml?> line, <svg viewBox="0 0 400 400" ...>, style block, then ONE <g transform="translate(0 0)"> holding
  every shape (center.pl needs that exact single group; never nest another <g>).

## Style (hard rules)
- Flat polygons only: no strokes, gradients, opacity, filters. Exactly five classes c1..c5 with var() fallbacks, the same
  palette in all 8 files of a crop. Suggested roles: c1 leaf green, c2 light/lit green, c3 pale cream/straw (seed and
  fruit highlights, dried leaves), c4 dark soil brown #5A3A22-ish (soil, shade, seed dark side), c5 the crop's signature
  colour (fruit, root, flower). Pick hues that are beautiful and true to the crop.
- Light from the upper left: lit faces c2/c3, shaded faces darker. Every leaf/fruit has a lit and a shaded half.
- Things attach: fruit hangs from stems, leaves grow from the crown, nothing floats. No scenery beyond the small soil
  patch / pocket used in wheat. No faces on plants (fantasy ones too).
- Top-down shapes must read at small sprite size (~64px): bold silhouettes, signature features large.

## Quality bar
Artistically great and consistent with wheat. Each crop must be instantly recognisable at every stage.

## Method
1. Write your generator, render all 8, review them large AND at ~64px with headless Edge screenshots of
   http://localhost:5181/topdown/crops.html (or your own preview html in your OWN scratch subfolder; never write to the
   scratchpad root, other agents share it; use your own --user-data-dir). Browser pane tabs may not be available.
2. Critique honestly and iterate at least twice per crop: recognisable? stages progress well? scale consistent?
3. When a crop's 8 images are final, write the marker: date +%s > crops/<crop>/done.txt (the sheet polls it and
   shows that crop live). Then do your second crop.
Server http://localhost:5181/ is running. Bash: keep commands under ~6KB; prefer the Write tool for files.

## Screenshot tips (learned)
- Headless Edge often writes the PNG a few seconds AFTER the process returns. Do not rm-and-retry in a tight loop;
  use a new file name per render and wait/poll for it. Use a fresh --user-data-dir per run.
- Raspberry lesson: produce must read as THAT fruit at a glance (raspberry = packed glossy drupelets, blunt thimble,
  no sepals; a round shape with a green crown reads as strawberry/pineapple). Compare against real-world silhouettes.
- Avoid confusion with the 13 existing crops (e.g. strawberries, pumpkin, spring onions, potatoes, tomatoes).

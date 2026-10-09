# Top-down brief (read fully before starting)

Project: C:/Claude/Cute Fox, a gallery of faceted low-poly creature SVGs. For each favorite, folder
topdown/<dir>__<name>/ contains side.svg (the current gallery drawing, DO NOT EDIT). You create top.svg in the same
folder: the SAME creature seen from directly above. Never touch the real gallery files in C:/Claude/Cute Fox/<dir>/.

## What "top-down" means here
- Camera straight above, looking down at the creature's back. The head points UP (toward the top of the canvas).
- Show what is visible from above: back, top of head and ears/horns/crest, back markings and patterns, wings spread
  flat to the sides for flyers, legs splayed out to the sides in a natural stride (front pair and hind pair, feet
  pointing forward/out), tail extending downward (may curve). Serpents and eels: an S-curve or coil seen from above.
  Spiders/crabs/insects: legs radiating evenly and symmetrically.
- Bilaterally symmetric creatures should be symmetric (mirror around x=200), but a slight natural asymmetry in the
  tail curve or stride is welcome for life.
- It must be instantly recognisable as the same creature as side.svg: same palette roles, same markings, same
  special features (crystals, flames, horns, leaves, lanterns, chains, etc.), same character and proportions.
- Eyes: only what is genuinely visible from above. Most animals show the eyes as small shapes at the sides of the
  head (.eye white with a .pupil). Do not invent extra eyes or any face features (no noses, mouths, lips, cheeks,
  blush). If the side view has no eyes (e.g. the ember octopus), the top view has none either.

## The style (hard rules)
- Flat polygons only. No strokes/outlines, gradients, opacity, filters.
- Use exactly the <style> block from side.svg (same five default colours), classes c1..c5 plus .eye and .pupil only.
  Roles: c1 base, c2 lit facet, c3 cream/underside, c4 dark markings, c5 accent.
- Light from the upper left: facets facing upper-left lighter (c2), lower-right darker. From above the spine ridge
  splits the back into a lit left plane and a darker right plane, which gives the form.
- Same kind of part = same colour. Parts attach and overlap their roots; nothing floats. Things that grow out of the
  body (crystals, horns, spikes, flames, leaves) emerge from the surface.
- No scenery, no shadows on the ground.
- File format like side.svg: <?xml?> line, <svg viewBox="0 0 400 400" ...>, the style block, ONE <g> containing all
  shapes. Then from C:/Claude/Cute Fox run  perl tools/center.pl topdown/<folder>/top.svg  (it recentres and scales).

## Quality bar
Artistically great, polished, professional. These were just polished with careful self-review and the user loved the
result. Match that level: graceful silhouettes, well-placed facets, clean symmetry, nothing crude or blocky.

## Working method (for each creature)
1. Read side.svg fully and understand every part (what is a horn, a crest, a marking, an eye).
2. Write top.svg (Write tool), run center.pl.
3. Review large: http://localhost:5181/topdown/view.html?k=<folder> (side and top next to each other) and
   &only=top. Use your own browser tab (tabs_create, then navigate with that tabId; never use or close others).
   If tabs_create fails, take headless Edge screenshots instead, using your OWN subfolder and --user-data-dir in the
   scratchpad (never write to the scratchpad root; other agents share it).
4. Critique honestly and iterate at least twice: recognisable? symmetric? attached? lighting consistent? elegant?
5. Then immediately write the marker:  date +%s > topdown/<folder>/done.txt  (the sheet page polls this and shows
   the drawing live). Move on to the next creature.

Server http://localhost:5181/ is already running. Do not start servers.
Bash: Git Bash; keep single commands under ~6KB; prefer the Write tool for SVG files.

## Purpose (from the user, binding)
These will be game sprites: the creature moves around the map seen from above. It just needs to be clear which creature it is. The pose may differ from the side view.
- Use a neutral locomotion pose: walking/running mid-stride for walkers, wings spread in flight for flyers, swimming S-curve for serpents and fish, legs evenly spread for crawlers.
- Always face straight UP (head at the top), body centred on the canvas so it can be rotated around its centre.
- Prioritise readability at small game size: strong, distinctive silhouette, the signature features big and clear (wings, horns, crystals, flames, tails, colour pattern); skip tiny details that vanish when small.
- Legs (user correction): mammals, birds, hoofed animals and dinosaurs keep their legs under the body seen from above; only paws/hooves peek slightly in front of the chest and behind the hips. Never splay them sideways. Only lizards/amphibians, arthropods and turtle flippers spread to the sides.
- No ruler-straight centre line: the lit/shaded spine boundary must follow the body form (curving with stride and tail, broken by shoulder/hip facets), and mirrored halves must overlap so no seam shows.

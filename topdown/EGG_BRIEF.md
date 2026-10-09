# Egg brief (read fully before starting)

Project: C:/Claude/Cute Fox, faceted low-poly creature SVGs for a cozy island game. Every favourite creature gets an
egg it hatches from. Most of these creatures would never hatch from an egg in nature, so these are fantasy eggs:
each one is clearly an egg, and clearly that creature's egg.

For each creature folder topdown/<folder>/ (it holds side.svg and top.svg, DO NOT EDIT those) you create:
- egg-front.svg: the egg standing upright, seen from the front (inventory, cards, the hatchery).
- egg-top.svg: EXACTLY the egg from egg-front.svg, still standing upright on its base, seen from straight above (the
  map sprite). The same object, same features, same base, only the camera moved overhead. (Corrected by the user:
  an earlier version of this brief said "lying on its side"; that was wrong.)
Never touch the real gallery files in C:/Claude/Cute Fox/<dir>/, and never another agent's creatures.

## The one goal: recognisable by style alone
Players recolour their creatures, and the egg uses the creature's five colours, so colour can never be the clue.
Shape and pattern must say which creature it is. Test this with the sheet's "One palette for all" mode: every egg
in the same colours must still be told apart at a glance, and must point to its creature.
Tools for that, use several at once:
- Silhouette of the shell: proportions (tall and slim, round, squat, pointed, lopsided, faceted like a gem, segmented
  like a shell, coiled like an ammonite...). It must stay an egg, but eggs differ a lot.
- Signature features growing from the shell: horns, crests, crystals, flame tips, leaf sprouts, antlers, fins, frills,
  tentacle tips, feathers, bone ridges, lantern glow, wings folded around it, a tail curled around it. Big and clear,
  not tiny.
- Pattern logic on the shell taken from the creature's own markings: stripes, rosettes, scales, plates, rings,
  sutures, cracks of light, spirals, spots. Same marking idea as the creature, adapted to the egg's curve.
- Optionally a little base that belongs to the creature: a crystal cluster, a nest of twigs, coral, embers, a puddle
  of ink, roots. Keep it small; the egg is the subject.

Egg first, creature second (user feedback): a whole, unbroken egg-shaped ovoid takes most of the picture and its
outline alone must say "egg". The creature lives on and in the shell as hints (pattern, plates, a few features growing
from it, something hugging it low down), never as the creature itself: no full set of legs, no raised claws, no body
shape that reads as the animal. No egg ever has a neck, a head or a face growing out of it.

## The style (hard rules, same as the creatures)
- Flat polygons only (circle only for the .eye/.pupil if an egg ever peeks). No strokes, outlines, gradients,
  opacity, filters, blur.
- Use exactly the <style> block from that creature's side.svg (same five default colours), classes c1..c5 (plus .eye
  and .pupil only if truly needed, usually not). Roles: c1 base, c2 lit facet, c3 cream/underside, c4 dark markings,
  c5 accent. Use the roles the way the creature does: the creature's dominant colour is the shell's dominant colour,
  its markings colour is the pattern, its accent is the special feature.
- The shell is a low-poly ovoid: roughly 14 to 30 facets, never a smooth ellipse, never a noisy mesh. Light from the
  upper left: facets facing upper-left are c2, the body c1, lower-right a darker facet (use c4 sparingly for the
  darkest lower-right band, or the creature's own shade logic). Same kind of part = same colour.
- Parts attach to and grow out of the shell; nothing floats. No ground shadow, no scenery beyond the small base.
- Size so all eggs sit together: egg-front about 210-260 wide and 280-330 tall including features, centred on the
  400x400 canvas; egg-top about the same footprint. Then run center.pl (it recentres and only scales down if too big).
- egg-top: the upright egg seen from straight above. You look down on its crown: the shell is a round, faceted
  outline (its widest girth), the top of the shell in the middle, the pattern on the upper half radiating outwards
  from the crown, and every feature where it really is when seen from above (antlers, horns, crests, crystals,
  flames spread out from their roots; a curled tail or wings wrapped round it show as rings or shapes around the
  outline; a base like a nest or crystal cluster shows as a ring peeking out beyond the shell). Anything that faced
  the viewer in egg-front keeps its position around the circle: front is the bottom of the canvas. Light from the
  upper left: the upper-left part of the dome lit (c2), the lower-right darker. Compare it side by side with
  egg-front: a player must see at once that it is that egg from above.
  Symmetry (user feedback): egg-top must be mirror-symmetric around x=200 for every symmetric creature: shell facets,
  wings, tails, ears, horns, crests and markings matching left and right, only the lighting differing. Tails or plumes
  that sweep to one side in egg-front fan out evenly to both sides from above.

## File format
Like side.svg: <?xml?> line, <svg viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg" role="img"
aria-label="<Creature> egg"> (and "<Creature> egg from above"), the style block, ONE <g> containing all shapes.
Then from C:/Claude/Cute Fox run:  perl tools/center.pl topdown/<folder>/egg-front.svg topdown/<folder>/egg-top.svg
The file must be valid XML that loads as a standalone image: exactly one <g> group of shapes, no extra wrapper
left open (center.pl adds its own). Check by opening the .svg file directly in your tab; it must render.

## Working method (per creature)
1. Read side.svg and top.svg fully: what makes this creature itself (silhouette, signature parts, markings).
2. Decide its egg's identity in one sentence before drawing ("a tall faceted egg with three crystal shards breaking
   through the top and the spider's chevron markings"). It must not resemble the other eggs in your group.
3. Write egg-front.svg and egg-top.svg (Write tool), run center.pl.
4. Review large in the browser: http://localhost:5181/topdown/view.html?k=<folder>&only=egg-front (and egg-top), and
   on the sheet http://localhost:5181/topdown/creatures.html with "Eggs only" and "One palette for all" (press "New
   colours" a few times). Use your OWN browser tab (tabs_create, then navigate with that tabId; never use or close
   others). If that fails, take headless Edge screenshots in your OWN scratchpad subfolder with its own
   --user-data-dir (never the scratchpad root; other agents share it).
5. Critique honestly, iterate at least twice: is it an egg? is it unmistakably this creature's? does it survive any
   colours? lighting consistent? elegant? attached? does it hold at small size (egg-top especially)?
6. Then write the marker:  date +%s > topdown/<folder>/egg-done.txt  (the sheet polls it and shows the eggs live).
   Move on to the next creature. At the end, look at your whole group side by side in one palette and fix any two
   eggs that read alike.

Server http://localhost:5181/ is already running. Do not start servers. Bash is Git Bash; keep single commands under
~6KB; prefer the Write tool for SVG files.

## Quality bar
Artistically great, polished, professional, cozy. Graceful silhouettes, well-placed facets, clean symmetry where the
creature is symmetric, nothing crude or blocky. These will be collected and shown off by players.

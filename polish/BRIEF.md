# Polish brief (read fully before starting)

Project: C:/Claude/Cute Fox. A gallery of faceted low-poly creature SVGs. Each favorite has a folder
polish/<dir>__<name>/ containing original.svg (DO NOT EDIT), and a.svg, b.svg, c.svg (start as copies; you rewrite these).
The real originals in <dir>/<name>.svg must NEVER be touched. Only write inside your assigned polish folders.

## The style (hard rules)
- Flat polygons only. No strokes/outlines, no gradients, no opacity, no filters, no blur.
- Exactly the five palette classes c1..c5 plus .eye (white) and .pupil (black). Keep the <style> block exactly as in
  original.svg (same 5 default colours). Roles: c1 base, c2 lit facet, c3 cream/underside, c4 dark markings, c5 accent.
- Light comes from the upper left: upper-left-facing facets lighter (c2), lower/rear facets darker.
- Same kind of part = same colour (all legs alike, all feathers alike...). Patterns may vary.
- Whole creature, same pose, same identity, same palette. It must still clearly be THE SAME creature, just better.
- Eyes stay white + black pupil (a tiny .eye catchlight on the pupil is allowed).
- Legs taper and attach into the body; nothing floats; parts overlap their roots. Things that grow out of a body
  (crystals, horns, spikes) emerge from the surface, not pasted on top.
- No scenery objects.
- Fits the 400x400 viewBox: after writing, run  perl tools/center.pl polish/<folder>/a.svg (etc.)  from C:/Claude/Cute Fox.
  It recentres and scales into a 380px safe area (it rewrites the single <g transform>; keep all shapes in one <g>).

## The three polish directions (each a distinct, complete, finished drawing)
- A = Refined facets. Same silhouette. Break large flat areas into well-placed facets that describe form (muscle,
  cheek, haunch, shell curvature), consistent upper-left lighting, crisp rim highlights along top edges, small
  shadow facets where limbs/neck meet the body. Richer, more sculpted low-poly. Fix any defects you notice.
- B = Anatomy and silhouette. Same pose and colours, but refine the contour: more graceful curves (more vertices on
  outlines), better proportions, elegant tapering limbs/tails, natural joints, cleaner head shape and expression.
  Remove awkward angles, kinks, gaps and stiff blocky parts. This is the "fix the drawing" pass.
- C = Character and detail. Built on a clean base, add tasteful detail that rewards a close look: fur/feather/scale
  texture as small facets along edges, markings that follow the form, claws/toes, whisker or crest details, a pupil
  catchlight, expressive brow. Never cluttered; detail serves the read at thumbnail size too.

## Quality bar
This is about artistic polish. It must look professional, like a refined illustration, not a quick edit.
Every version must be clearly better than the original. If a version is not better, redo it.

## Working method (do this for each creature)
1. Read original.svg fully. Look at it large: open your own browser tab (tabs_create, then navigate with that tabId) at
   http://localhost:5181/polish/view.html?k=<folder>&only=original . Never use or close other tabs.
2. Write a.svg, b.svg, c.svg as complete files (Write tool; you may restructure polygons freely). Run center.pl on them.
3. Review all four at http://localhost:5181/polish/view.html?k=<folder> (add a cache-busting reload) and each single
   version large with &only=a etc. Screenshot and critique honestly: attachment, proportions, lighting, clutter, fit.
4. Iterate until each version is clearly better than the original. At least two critique passes per creature.
5. Only then write the completion marker:  date +%s > polish/<folder>/done.txt  (the picker page polls this and
   refreshes that row live, so do this immediately after each creature, not at the end).
6. Move to the next creature.

Server: http://localhost:5181/ is already running (serve.ps1). Do not start servers.
Bash notes: Git Bash; keep single commands under ~6KB (heredocs larger than that fail); prefer the Write tool for SVGs.

## User corrections (binding)
- Never invent facial features: no noses, mouths, lips, cheeks or blush that the original does not clearly have. Never make a creature cuter.
- Keep exactly the eyes the original has (same number and place). Spots, suckers, gems and glow marks are never eyes.
- Before editing, identify what each shape in the original actually is.

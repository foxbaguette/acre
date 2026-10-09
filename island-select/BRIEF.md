# Unclaimed Acres: island selection concepts

The player is signed in (wallet `fennel.wam`). This page shows **their islands** and lets them **enter one** or
**chart a new island**. Most players have exactly ONE island; some have many (design for 1 first, and make 20
work well too). This is the screen right after the landing page, so it must feel like the same product.

## The look (fixed)

The landing page is the "Field Journal": `landing-ideas/02-field-journal.html` (open it at
http://localhost:5181/landing-ideas/02-field-journal.html and READ its source before you start). Cream paper,
ink and ink-blue handwriting, IM Fell English + EB Garamond + Caveat, tape, pins, specimen cards, a two-page
book with bookmark tabs on the right page that turn the page in 3D, and the rust "field station" stamp logo.
Your concept must look like it belongs to that site: same fonts, palette, paper, header (stamp + "Unclaimed
Acres / a field journal" + an account chip for `fennel.wam` with a "Sign out" link instead of Connect wallet).
Within that look, each concept is a DIFFERENT way to present and pick islands (see your brief).

## Files and helpers (use them)

- `island-select/journal.css`: the shared journal styles (paper `.sheet`, `.hand`, `.kicker`, `.roman`, `.lede`,
  `.tape`, `.pin`, `.btn`, `.link-hand`, `.photo`, `.specimen` cards, header `.top/.brand/.brand-stamp/.brand-name`,
  the book `.book/.page/.page-l/.page-r/.leaf/.folio/.turn-link/.bookmarks/.bookmark` and the `.turn` page-turn
  animation). Link it, then add your own `<style>` for your concept.
- `island-select/islands.js`: load with `<script src="islands.js"></script>`.
  - `UA.islands()` resolves to the player's islands for the current demo state: `{ index, id, name, note,
    coast, svgTransform, render, renderTransform, stats: { land, forest, mountain, beach, freshWater } (percent of
    the map), charted, lastVisit }`. Real data: the first five are the five maps on the WAX chain.
  - `UA.outline(island, { size, sea, land, ink, stroke, shore, shoreColor, grid, pad, label })` returns the island's
    coastline as an inline SVG string (a clean chart outline: no details, as the user asked for map pickers).
  - `island.render` is a painted top-down view (1600 x 907 webp); apply `style="transform: island.renderTransform"`
    so it matches the coastline. Use renders sparingly (e.g. for the selected island), outlines for lists.
  - `UA.canCreate` (false when `&create=0`): whether to show "chart a new island". Creating is not live yet; the
    button can just be a button. `UA.count`, `UA.player`.
  - It injects SVG symbols: `<svg><use href="#stamp-mark"/></svg>` (logo ring), `#stamp` (full stamp), `#isle`.
  - It adds a small demo switch at the bottom (1 / 5 / 20 islands, show/hide "new island"). `&demo=0` hides it.
- Each island page links: give "Enter island" buttons `href="#enter-<id>"` (no real target yet).

## Rules

- One self-contained page `island-select/NN-slug.html` per concept (plus `island-select/assets/NN-*` only if truly
  needed). Do not touch any other file.
- It must look excellent and intentional at **1 island** (the common case: not an empty-looking page with one
  tiny item), and stay usable and attractive at **20** (scrolling, paging, search or an index are fine).
- Primary action: enter the island. Secondary: chart a new island (respect `UA.canCreate`).
- Honest copy: no prices, tokens, PvP, trading, dates of release. Island names and notes are player-written
  (that is fine). Do not say "on WAX/blockchain" everywhere: nowhere is best on this page.
- Desktop first (1440 x 900), must work at 375px wide with no horizontal scroll. Visible focus styles, alt text /
  aria labels, keyboard usable, `prefers-reduced-motion` respected.
- Put an HTML comment at the top: concept name, one-line idea.

## Check your work

Headless Edge screenshots only work when launched from PowerShell (from Git Bash it silently does nothing):

```
$E='C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$out='C:\Users\Foxy\AppData\Local\Temp\<your-folder>\shot.png'
Start-Process -FilePath $E -ArgumentList "--headless=new --disable-gpu --hide-scrollbars --no-first-run --user-data-dir=`"C:\Users\Foxy\AppData\Local\Temp\<your-folder>\p$(Get-Random)`" --window-size=1440,900 --virtual-time-budget=9000 --screenshot=`"$out`" http://localhost:5181/island-select/NN-slug.html?n=1&demo=0" -Wait -WindowStyle Hidden
```

Then poll until the file exists and look at it with the Read tool. Check `?n=1`, `?n=5`, `?n=20` and
`&create=0`. Iterate at least twice until it is genuinely excellent. The server on :5181 is already running;
do not start or stop it.

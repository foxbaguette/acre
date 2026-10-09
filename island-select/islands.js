// Shared data and helpers for the island selection concepts (island-select/NN-*.html).
//
//   <script src="islands.js"></script>
//   UA.islands().then(list => render(list))   // the signed-in player's islands for this demo state
//   UA.outline(island, { ... })               // the island's coastline as an inline SVG string
//
// Demo state comes from the URL: ?n=1 (default), ?n=5 or ?n=20 islands; &create=0 hides "chart a new island".
// A small demo switch is added at the bottom of every page (UA.toolbar, called automatically).
// The first five islands are the real maps on the chain (coastline + land/forest/mountain shares); the rest
// of the 20 reuse those coastlines mirrored or turned, with their own names, so a long list looks varied.
(function () {
  var params = new URLSearchParams(location.search);
  var n = [1, 5, 20].indexOf(Number(params.get('n'))) >= 0 ? Number(params.get('n')) : 1;

  var NAMES = ['Fernhollow', 'Driftwood Key', 'Lantern Reach', 'Mossback Isle', 'Saltmarsh', 'Pinecrest', 'Little Tern', 'Bramble Bay',
    'Quietwater', 'Cobble Point', 'Heron Rest', 'Juniper Cay', 'Foxglove', 'Amber Shoal', 'Willowmere', 'Sandpiper', 'Thistledown',
    'Kelp Harbour', 'Starling Isle', 'Mistral Rock'];
  var NOTES = ['my first landfall', 'the lake is lovely at dusk', 'two islets to the north', 'more forest than I expected', 'flat and green, good for fields',
    'snow on the summit', 'small and windy', 'a sheltered bay', 'very quiet here', 'stony shore, careful', 'herons everywhere', 'juniper on every hill',
    'foxes in the meadow', 'golden sand', 'willows by the water', 'busy little beach', 'thistles, so many', 'the harbour is calm', 'starlings at sunset', 'windy rock, good views'];
  // 0 = as drawn, 1 = mirrored left-right, 2 = mirrored top-bottom, 3 = turned half round.
  var SVG_T = ['', 'translate(100 0) scale(-1 1)', 'translate(0 100) scale(1 -1)', 'rotate(180 50 50)'];
  var CSS_T = ['none', 'scaleX(-1)', 'scaleY(-1)', 'rotate(180deg)'];

  var cache = null;
  function base() {
    cache = cache || fetch('assets/islands.json').then(function (r) { return r.json(); });
    return cache;
  }

  /** The player's islands for the current demo state (newest last). */
  function islands(count) {
    count = count || n;
    return base().then(function (maps) {
      var list = [];
      for (var i = 0; i < count; i++) {
        var m = maps[i % maps.length], v = Math.floor(i / maps.length) % SVG_T.length;
        var day = new Date(2026, 8, 3 + i * 4);
        list.push({
          index: i,
          id: m.id,                                   // the map on chain this island's coastline comes from
          name: NAMES[i],
          note: NOTES[i],
          coast: m.coast,                             // SVG path, tile units 0..100
          svgTransform: SVG_T[v],                     // apply to the coast path's <g> (UA.outline does this)
          render: 'assets/render-' + m.id + '.webp',  // painted view of the island from above, 1600 x 907
          renderTransform: CSS_T[v],                  // CSS transform for the render so it matches the coast
          stats: m.stats,                             // percentages of the whole map: land, forest, mountain, beach, freshWater
          charted: day.toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' }),
          lastVisit: i === count - 1 ? 'today' : (i % 3 === 0 ? 'yesterday' : (2 + i % 9) + ' days ago')
        });
      }
      return list;
    });
  }

  /**
   * The coastline as inline SVG. Options (all optional): size (css px or '100%'), sea (fill or 'none'),
   * land, ink (coast stroke), stroke (width in tile units), shore (dotted beach line), grid (faint lines),
   * pad (tile units of sea around the 100 x 100 map), label (aria-label; omit for decorative).
   */
  function outline(island, o) {
    o = o || {};
    var pad = o.pad == null ? 4 : o.pad, v = (-pad) + ' ' + (-pad) + ' ' + (100 + 2 * pad) + ' ' + (100 + 2 * pad);
    var size = o.size || '100%', ink = o.ink || '#2b2721', land = o.land || '#f3ead2', sea = o.sea || 'none';
    var g = '<g transform="' + island.svgTransform + '">';
    if (o.shore !== false) g += '<path d="' + island.coast + '" fill="none" stroke="' + (o.shoreColor || 'rgba(37,70,127,.35)') + '" stroke-width="3.2" stroke-linejoin="round"/>';
    g += '<path d="' + island.coast + '" fill="' + land + '" stroke="' + ink + '" stroke-width="' + (o.stroke || .7) + '" stroke-linejoin="round" fill-rule="evenodd"/>';
    g += '</g>';
    var grid = '';
    if (o.grid) for (var k = 10; k < 100; k += 10) grid += '<path d="M' + k + ' ' + (-pad) + 'V' + (100 + pad) + 'M' + (-pad) + ' ' + k + 'H' + (100 + pad) + '" stroke="' + o.grid + '" stroke-width=".25"/>';
    return '<svg viewBox="' + v + '" width="' + size + '" height="' + size + '"' + (o.label ? ' role="img" aria-label="' + o.label + '"' : ' aria-hidden="true"') + '>' +
      (sea !== 'none' ? '<rect x="' + (-pad) + '" y="' + (-pad) + '" width="' + (100 + 2 * pad) + '" height="' + (100 + 2 * pad) + '" fill="' + sea + '"/>' : '') +
      grid + g + '</svg>';
  }

  // The stamp logo and island sketch as SVG symbols: <svg><use href="#stamp-mark"/></svg> (ring + island),
  // <use href="#stamp"/> (full stamp with lettering), <use href="#isle"/> (pen sketch).
  var COAST = 'M14 64L19 55L27 51L31 44L41 41L47 35L57 36L63 32L72 36L80 37L84 45L90 51L86 58L78 58L75 63L80 69L74 75L64 74L57 80L46 77L38 80L29 76L22 77L12 74L8 70Z';
  var DEFS = '<svg width="0" height="0" style="position:absolute" aria-hidden="true" focusable="false"><defs>' +
    '<filter id="worn" x="-5%" y="-5%" width="110%" height="110%"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" seed="11" result="n"/>' +
    '<feColorMatrix in="n" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -2.2 2.05" result="m"/><feComposite in="SourceGraphic" in2="m" operator="in" result="w"/>' +
    '<feTurbulence type="fractalNoise" baseFrequency=".05" numOctaves="2" seed="5" result="d"/><feDisplacementMap in="w" in2="d" scale="2.4"/></filter>' +
    '<symbol id="isle" viewBox="0 0 100 100"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">' +
    '<path stroke-width="2.3" d="' + COAST + '"/><path stroke-width="1.1" stroke-dasharray="1 3.2" opacity=".7" transform="translate(5.9 6.8) scale(.88)" d="' + COAST + '"/>' +
    '<path stroke-width="2.1" d="M42 64 54 43l13 21"/><path stroke-width="1.5" d="m50.2 50 3.8-7 4 7.1-2.1-1.3-1.9 2.2-1.9-2.2z" fill="currentColor" fill-opacity=".1"/>' +
    '<path stroke-width="1" d="M58.5 52l4 8M61 49.5l5 10M57 56.5l2.6 5"/><path stroke-width="1.7" d="M27 67l3-8 3 8zM33.5 71l2.8-7 2.8 7zM71 53l2.6-7 2.6 7z"/>' +
    '<path stroke-width="1.2" d="M59 68.5l10-2M60 71.5l9-1.9"/><path stroke-width="1.5" d="M5 87q4-3.4 8 0t8 0M74 89q4-3.4 8 0t8 0M82 22q3-2.6 6 0t6 0"/></g></symbol>' +
    '<symbol id="stamp" viewBox="0 0 200 200"><g filter="url(#worn)"><circle cx="100" cy="100" r="92" fill="none" stroke="currentColor" stroke-width="4"/>' +
    '<circle cx="100" cy="100" r="84" fill="none" stroke="currentColor" stroke-width="1.4"/><circle cx="100" cy="100" r="58" fill="none" stroke="currentColor" stroke-width="1.4"/>' +
    '<path id="stampTop" d="M30 100a70 70 0 0 1 140 0" fill="none"/><path id="stampBot" d="M24 100a76 76 0 0 0 152 0" fill="none"/>' +
    '<text font-family="IM Fell English SC, EB Garamond, serif" font-size="21" letter-spacing="3.2" fill="currentColor"><textPath href="#stampTop" startOffset="50%" text-anchor="middle">Unclaimed Acres</textPath></text>' +
    '<text font-family="IM Fell English SC, EB Garamond, serif" font-size="12.5" letter-spacing="3" fill="currentColor"><textPath href="#stampBot" startOffset="50%" text-anchor="middle">&#10022; field journal &#10022;</textPath></text>' +
    '<use href="#isle" x="52" y="52" width="96" height="96"/></g></symbol>' +
    '<symbol id="stamp-mark" viewBox="0 0 200 200"><g filter="url(#worn)"><circle cx="100" cy="100" r="90" fill="none" stroke="currentColor" stroke-width="8"/>' +
    '<circle cx="100" cy="100" r="75" fill="none" stroke="currentColor" stroke-width="3"/><use href="#isle" x="28" y="28" width="144" height="144"/></g></symbol>' +
    '</defs></svg>';

  function href(changes) {
    var p = new URLSearchParams(location.search);
    Object.keys(changes).forEach(function (k) { p.set(k, changes[k]); });
    return '?' + p.toString() + location.hash;
  }

  /** The demo switch: not part of the design, pinned to the bottom of the window. */
  function toolbar() {
    var bar = document.createElement('div');
    bar.className = 'ua-demo';
    bar.setAttribute('role', 'navigation');
    bar.setAttribute('aria-label', 'Demo state');
    bar.innerHTML = '<span>Demo</span>' + [1, 5, 20].map(function (k) {
      return '<a href="' + href({ n: k }) + '"' + (k === n ? ' aria-current="true"' : '') + '>' + k + (k === 1 ? ' island' : ' islands') + '</a>';
    }).join('') + '<a href="' + href({ create: UA.canCreate ? 0 : 1 }) + '">' + (UA.canCreate ? 'hide' : 'show') + ' &ldquo;new island&rdquo;</a>';
    var css = document.createElement('style');
    css.textContent = '.ua-demo{position:fixed;left:50%;bottom:12px;transform:translateX(-50%);z-index:9999;display:flex;gap:4px;align-items:center;' +
      'padding:6px 8px;border-radius:999px;background:rgba(20,18,15,.86);color:#efe6d0;font:13px/1 system-ui,sans-serif;box-shadow:0 6px 20px rgba(0,0,0,.3)}' +
      '.ua-demo span{opacity:.6;padding:0 6px}.ua-demo a{color:#efe6d0;text-decoration:none;padding:6px 10px;border-radius:999px;white-space:nowrap}' +
      '.ua-demo a:hover{background:rgba(255,255,255,.12)}.ua-demo a[aria-current]{background:#efe6d0;color:#1d1a16}';
    document.head.appendChild(css);
    document.body.appendChild(bar);
  }

  window.UA = {
    count: n,
    canCreate: params.get('create') !== '0',
    player: 'fennel.wam',
    islands: islands,
    outline: outline,
    toolbar: toolbar
  };
  function init() { document.body.insertAdjacentHTML('afterbegin', DEFS); if (params.get('demo') !== '0') toolbar(); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();

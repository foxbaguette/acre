# Blue Java ("ice cream") banana crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/blue-java.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Look: cool silver-blue-green, few very BROAD whole paddle leaves in a calm cross (no swirl, hardly torn);
# a short compact bunch hanging straight down with stacked chevron hands of plump powder-blue fingers.
# (The regular banana is the slender, wind-torn, swirling, yellow counterpart.)
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/blue-java';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#3F7F6E', c2 => '#9CC8B6', c3 => '#EEF1E6', c4 => '#4D3530', c5 => '#7FA4E2');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub ell { my ($x, $y, $rx, $ry, $n, $rot) = @_; $rot //= 0; map { my ($u, $v) = dir($rot + $_ * 360 / $n); [$x + $u * $rx, $y + $v * $ry] } 0 .. $n - 1 }

# Points [x, y, heading] along a bent path.
sub path {
  my ($x, $y, $ang, $len, $bend, $n) = @_; $n //= 10; my @p; my $a = $ang;
  for my $i (0 .. $n) { push @p, [$x, $y, $a]; my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  @p;
}

# A tapered blade (sword leaf, stalk, root) as in wheat: lit and shaded halves.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $pow) = @_; $pow //= 0.85;
  my $n = 10; my (@l, @r, @m);
  for my $p (path($x, $y, $ang, $len, $bend, $n)) {
    my $i = @m; my $t = $i / $n; my ($dx, $dy) = dir($p->[2]);
    my $hw = $w / 2 * (1 - $t) ** $pow + ($i == $n ? 0 : 0.6);
    push @l, [$p->[0] - $dy * $hw, $p->[1] + $dx * $hw]; push @r, [$p->[0] + $dy * $hw, $p->[1] - $dx * $hw]; push @m, [@$p[0, 1]];
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @m);
  poly($leftLit ? $dark : $light, @r, reverse @m);
}

# A banana leaf from the crown: petiole (fraction $pf of the length), then a long oblong blade with a blunt
# rounded tip, a pale midrib and wind tears (V slits running along the side veins) at the given positions.
# %o: tearsL/tearsR = [u, depth] lists (u = 0..1 along the blade), veins => 1 for side-vein stripes.
sub bleaf {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, %o) = @_;
  my $pf = $o{pf} // 0.2; my $N = 30;
  my @p = path($x, $y, $ang, $len, $bend, $N);
  my $hw = sub {
    my $t = shift; return $w * 0.07 if $t <= $pf;
    my $u = ($t - $pf) / (1 - $pf);
    my $b = $u < 0.18 ? sin(pi / 2 * $u / 0.18) ** 0.8 : 1;              # rounded leaf base
    my $e = $u > 0.72 ? (1 - (($u - 0.72) / 0.28) ** 2.2) ** 0.5 : 1;    # blunt rounded tip
    return max($w * 0.07, $w / 2 * $b * $e * (1 - 0.12 * $u));
  };
  my $at = sub {                                                       # point on the leaf at t, side s, frac f
    my ($t, $s, $f) = @_; my $k = $t * $N; my $i = int($k); $i = $N - 1 if $i >= $N; my $fr = $k - $i;
    my ($a, $b) = ($p[$i], $p[$i + 1]);
    my $mx = $a->[0] + ($b->[0] - $a->[0]) * $fr; my $my = $a->[1] + ($b->[1] - $a->[1]) * $fr;
    my ($dx, $dy) = dir($a->[2]); my $h = $hw->($t) * $f;
    [$mx - $s * $dy * $h, $my + $s * $dx * $h];
  };
  my %tear = (1 => $o{tearsL} // [], -1 => $o{tearsR} // []);
  my ($dx0, $dy0) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy0, $dx0);
  for my $s (1, -1) {
    my @edge; my @tears = sort { $a->[0] <=> $b->[0] } @{ $tear{$s} };
    for my $i (0 .. $N) {
      my $t = $i / $N;
      while (@tears && $pf + $tears[0][0] * (1 - $pf) <= $t) {
        my ($u, $d) = @{ shift @tears }; my $tt = $pf + $u * (1 - $pf);
        push @edge, $at->($tt - 0.012, $s, 1), $at->($tt - 0.05 * $d, $s, 1 - $d), $at->($tt + 0.012, $s, 1);
      }
      push @edge, $at->($t, $s, 1);
    }
    my @mid = map { $at->($_ / $N, 0, 0) } 0 .. $N;
    my $isLit = ($s == 1) == $leftLit;
    poly($isLit ? $light : $dark, @edge, reverse @mid);
    if ($o{veins} && $isLit) {                                          # faint side veins on the lit half
      for (my $u = 0.16; $u < 0.86; $u += 0.11) {
        my $t = $pf + $u * (1 - $pf);
        my ($q0, $q1, $q2) = ($at->($t, $s, 0.12), $at->($t + 0.045, $s, 0.92), $at->($t + 0.05, $s, 0.92));
        poly($dark, $q0, $q1, $q2);
      }
    }
  }
  # pale midrib along the whole leaf
  my $mw = $o{rib} // 1.6; my (@ml, @mr);
  for my $i (0 .. $N - 2) { my $t = $i / $N; my ($dx, $dy) = dir($p[$i][2]); my $h = $mw * (1 - 0.6 * $t);
    push @ml, [$p[$i][0] - $dy * $h, $p[$i][1] + $dx * $h]; push @mr, [$p[$i][0] + $dy * $h, $p[$i][1] - $dx * $h]; }
  poly($o{ribc} // 'c3', @ml, reverse @mr);
}

# One banana finger: stem end at (x,y), heading ang, curving by bend. Slim body with a lit half,
# a green-tinged neck and a dark blunt tip.
sub finger {
  my ($x, $y, $ang, $len, $w, $bend, %o) = @_;
  my $N = 14; my @p = path($x, $y, $ang, $len, $bend, $N); my (@l, @r, @hl, @hr, @sl, @sr);
  my ($dx0, $dy0) = dir($ang + $bend / 2);
  my $ls = lit(-$dy0, $dx0) ? 1 : -1;                                  # which side faces the light
  for my $i (0 .. $N) {
    my $t = $i / $N; my ($dx, $dy) = dir($p[$i][2]);
    my $hw = $t < 0.14 ? $w * 0.15 : $w / 2 * (1 - ((($t - 0.14) / 0.86) * 2 - 1) ** ($o{fat} ? 6 : 4)) ** ($o{fat} ? 0.38 : 0.45);
    $hw = max($hw, $w * 0.12);
    push @l, [$p[$i][0] - $dy * $hw, $p[$i][1] + $dx * $hw]; push @r, [$p[$i][0] + $dy * $hw, $p[$i][1] - $dx * $hw];
    if ($o{shade} && $t >= 0.14) { push @sl, [$p[$i][0] + $ls * $dy * $hw, $p[$i][1] - $ls * $dx * $hw]; push @sr, [$p[$i][0] + $ls * $dy * $hw * 0.72, $p[$i][1] - $ls * $dx * $hw * 0.72]; }
    if ($t >= 0.2 && $t <= 0.86) {                                     # glossy highlight strip on the lit side
      my ($a, $b) = ($o{hin} // 0.15, $o{hout} // 0.62);
      push @hl, [$p[$i][0] - $ls * $dy * $hw * $a, $p[$i][1] + $ls * $dx * $hw * $a];
      push @hr, [$p[$i][0] - $ls * $dy * $hw * $b, $p[$i][1] + $ls * $dx * $hw * $b];
    }
  }
  poly($o{body} // 'c5', @l, reverse @r);
  poly($o{hi} // 'c3', @hl, reverse @hr);
  poly($o{shade}, @sl, reverse @sr) if $o{shade};
  poly($o{neck} // 'c1', @l[0 .. 2], reverse @r[0 .. 2]);                      # green stalk end
  my ($ex, $ey) = @{ $p[$N] }[0, 1]; my ($tx, $ty) = dir($p[$N][2]);
  $o{notip} or poly('c4', [$l[$N - 1][0], $l[$N - 1][1]], [$ex + $tx * 2, $ey + $ty * 2], [$r[$N - 1][0], $r[$N - 1][1]]);   # dark tip
}

# The maroon banana heart (male bell): a teardrop of overlapping bracts pointing along ang.
sub bell {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o; for my $i (0 .. 15) { my $th = 2 * pi * $i / 16; my $u = (1 - cos($th)) / 2; my $h = $w / 2 * sin(pi * $u) ** 0.6 * (1.15 - 0.5 * $u);
    push @o, [$x + $dx * $len * $u + $nx * $h * (sin($th) < 0 ? -1 : 1), $y + $dy * $len * $u + $ny * $h * (sin($th) < 0 ? -1 : 1)]; }
  poly('c4', @o);
  my $L = lit($nx, $ny) ? 1 : -1;
  for my $k (0 .. 2) {                                                   # lit bract edges
    my $u = 0.2 + $k * 0.22;
    my $cx = $x + $dx * $len * $u; my $cy = $y + $dy * $len * $u; my $h = $w * 0.42 * (1 - 0.6 * $u);
    poly('c5', [$cx + $nx * $L * $h, $cy + $ny * $L * $h], [$cx + $dx * $len * 0.2 + $nx * $L * $h * 0.15, $cy + $dy * $len * 0.2 + $ny * $L * $h * 0.15],
               [$cx + $dx * $len * 0.12 + $nx * $L * $h * 0.6, $cy + $dy * $len * 0.12 + $ny * $L * $h * 0.6]);
  }
}

# A bunch hanging from the crown, laid out along ang: a green stalk, then tiers of hands whose fingers all
# point back towards the crown (as on a real bunch), each tier overlapping the bases of the one before,
# then a bare stalk end and the maroon bell. $nh hands, $nf fingers per hand.
sub bunch {
  my ($x, $y, $ang, $len, $fw, $fl, $nh, $nf, $ripe) = @_;
  my %fo = $ripe ? (shade => "c1") : (body => "c2", hi => "c3", neck => "c1", shade => "c1");
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  blade($x, $y, $ang, $len + 20, 12, 0, 'c2', 'c1', 0.1);                   # stalk
  my $step = $len / $nh;
  for my $h (reverse 0 .. $nh - 1) {                                          # lower hands first
    my $s = ($h % 2) ? 1 : -1; my $k = 1 - 0.08 * $h; my $d = $step * ($h + 0.55);
    for my $j (reverse 0 .. $nf - 1) {
      my $m = $j - ($nf - 1) / 2;
      my $o = $d + $m * $fw * 0.62 * $k;
      finger($x + $dx * $o + $nx * $s * 4, $y + $dy * $o + $ny * $s * 4, $ang + $s * (100 - $m * 18), $fl * $k * (1 - 0.06 * abs($m)), $fw * $k, $s * 46, %fo);
    }
  }
  bell($x + $dx * ($len + 16), $y + $dy * ($len + 16), $ang, 34, 24) if defined $ripe;
}

# Small irregular patch of soil.
sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o;
  srand($seed);
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12; my $k = 0.82 + rand(0.3); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
}
# Pale cracks running out through dry soil.
sub cracks {
  my ($n, $seed, $seg) = @_; srand($seed); $seg //= 13;
  for my $i (0 .. $n - 1) {
    my $a = $i * 360 / $n + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
    for my $k (0 .. 4) {
      my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.2 - $k * 0.35;
      push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
      $x += $dx * $seg; $y += $dy * $seg;
    }
    poly('c3', @l, [$x, $y], reverse @r);
  }
}
# Top of the pseudostem / rolled cigar leaf in the crown, seen from above.
sub crown {
  my ($x, $y, $r) = @_;
  poly('c1', ell($x, $y, $r, $r, 12, 15));
  poly('c2', [$x - $r * 0.95, $y + $r * 0.2], ell($x - $r * 0.15, $y - $r * 0.15, $r * 0.8, $r * 0.8, 10, 150), [$x + $r * 0.2, $y - $r * 0.95]);
  poly('c3', ell($x - $r * 0.25, $y - $r * 0.25, $r * 0.32, $r * 0.32, 8, 0));
}
sub write_svg {
  my ($file, $label) = @_;
  open my $fh, '>', "$OUT/$file" or die $!;
  print $fh qq{<?xml version="1.0" encoding="UTF-8"?>\n<svg viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="$label">\n  <style>\n};
  print $fh "    .$_ { fill: var(--$_, $PAL{$_}); }\n" for qw(c1 c2 c3 c4 c5);
  print $fh "  </style>\n  <g transform=\"translate(0 0)\">\n", join("\n", @S), "\n  </g>\n</svg>\n";
  close $fh; @S = ();
}

# A whole plant from above: $n torn leaves swirling around the crown (all bend the same way).
sub plant {
  my ($n, $len, $w, $start, $seed, $tears, %o) = @_;
  srand($seed);
  my @L;
  for my $i (0 .. $n - 1) {
    next if $o{gap} && grep { $_ == $i } @{ $o{gap} };
    my $a = $start + $i * 360 / $n + rand(10) - 5;
    my $l = $len * (0.86 + rand(0.2));
    my (@tl, @tr);
    for (1 .. $tears) { push @tl, [0.12 + rand(0.8), 0.45 + rand(0.5)]; push @tr, [0.12 + rand(0.8), 0.45 + rand(0.5)]; }
    push @L, [$a, $l, \@tl, \@tr];
  }
  for (sort { $b->[1] <=> $a->[1] } @L) {
    my ($dx, $dy) = dir($_->[0]);
    bleaf(200 + $dx * 6, 200 + $dy * 6, $_->[0], $_->[1], $w, $o{bend} // 24, 'c2', 'c1', tearsL => $_->[2], tearsR => $_->[3], veins => 1, pf => $o{pf} // 0.2);
  }
}

# Broad whole leaves at given angles: [angle, length, width, bend, tears per side]. Longest drawn first.
sub leaves {
  my ($seed, @L) = @_; srand($seed);
  for my $l (sort { $b->[1] <=> $a->[1] } @L) {
    my ($a, $len, $w, $bend, $nt) = @$l; my (@tl, @tr);
    for (1 .. ($nt // 0)) { push @tl, [0.3 + rand(0.55), 0.35 + rand(0.3)]; push @tr, [0.3 + rand(0.55), 0.35 + rand(0.3)]; }
    my ($dx, $dy) = dir($a);
    bleaf(200 + $dx * 5, 200 + $dy * 5, $a, $len, $w, $bend, 'c2', 'c1', tearsL => \@tl, tearsR => \@tr, veins => 1, pf => 0.14, rib => 2.4);
  }
}

# ---------------------------------------------------------------------------------------------
# 1. Planting material, front view: a "bit" - a lumpy chunk cut from the corm, its pale cut face up,
#    ring scars on the dark skin, a bud eye pushing out a silver-blue shoot, and a few roots.
for my $r ([140, 46, 14], [112, 56, 8], [82, 58, -8], [56, 44, -16]) {
  my ($a, $l, $b) = @$r; my ($dx, $dy) = dir($a);
  blade(200 + $dx * 40, 300 + $dy * 6, $a, $l, 5, $b, 'c3', 'c4');
}
poly('c4', [136, 270], [142, 296], [164, 316], [204, 324], [246, 314], [266, 290], [262, 264], [236, 258], [200, 262], [160, 260]);
poly('c3', [136, 270], [160, 252], [204, 246], [244, 250], [262, 264], [236, 270], [200, 274], [160, 274]);   # cut face
poly('c2', [160, 252], [204, 246], [244, 250], [214, 258], [176, 260]);                                   # lit fresh tissue
for my $s ([150, 292, 24], [176, 304, 30], [224, 304, 30], [248, 290, 20]) {                              # ring scars
  my ($x, $y, $w) = @$s; poly('c3', [$x - $w / 2, $y], [$x, $y + 3], [$x + $w / 2, $y], [$x, $y + 1.2]);
}
poly('c4', ell(206, 258, 15, 6, 10));
bleaf(204, 238, -140, 92, 50, 30, 'c2', 'c1', pf => 0.12, veins => 1, rib => 2);
blade(206, 260, -88, 112, 20, 6, 'c2', 'c1', 0.55);
poly('c3', [203, 258], [205, 166], [208, 166], [209, 258]);
write_svg('1-seeds-front.svg', 'Blue Java corm piece for planting');

# 2. Just planted, top down: the faceted corm piece pressed into the soil, pale cut faces up, its eye sprouting.
soil(200, 200, 60, 54, 22);
poly('c4', [164, 186], [192, 164], [232, 172], [242, 210], [222, 236], [178, 232]);       # dark corm skin rim
poly('c3', [170, 188], [194, 170], [228, 178], [236, 208], [218, 228], [182, 226]);      # pale cut face
poly('c2', [170, 188], [194, 170], [228, 178], [204, 192]);                               # lit facet
poly('c2', [182, 226], [204, 192], [218, 228]);
for ([190, 212], [222, 206], [214, 186]) { poly('c4', ell($_->[0], $_->[1], 3.5, 3, 6)); }
poly('c1', ell(200, 200, 9, 9, 10));
bleaf(198, 196, -112, 50, 28, 10, 'c2', 'c1', pf => 0.2, rib => 1.6);
write_svg('2-sown.svg', 'Blue Java corm piece just planted');

# 3. First growth: two broad round leaves opening like wings.
soil(200, 200, 34, 30, 32);
leaves(33, [-150, 80, 44, 6, 0], [24, 74, 42, 6, 0]);
crown(200, 200, 10);
write_svg('3-first-growth.svg', 'Blue Java first growth');

# 4. Second growth: three broad leaves.
soil(200, 200, 34, 30, 42);
leaves(43, [-140, 118, 60, 4, 0], [-30, 112, 58, -4, 1], [90, 104, 56, 4, 0]);
crown(200, 200, 12);
write_svg('4-second-growth.svg', 'Blue Java second growth');

# 5. Third growth: a calm cross of four broad leaves; the young bunch hangs down with the bell.
soil(200, 200, 34, 30, 52);
leaves(53, [-150, 146, 72, 4, 1], [-30, 142, 70, -4, 1], [42, 138, 70, 4, 0], [138, 140, 70, -4, 1]);
crown(200, 200, 14);
bunch(200, 188, -90, 58, 17, 40, 3, 3, 0);
write_svg('5-third-growth.svg', 'Blue Java third growth with flower bell');

# 6. Harvest: broad silvery leaves and a short, plump bunch of powder-blue bananas.
soil(200, 200, 34, 30, 62);
leaves(63, [-152, 172, 84, 4, 1], [-28, 168, 82, -4, 2], [40, 162, 80, 4, 1], [140, 164, 80, -4, 1], [90, 110, 54, 0, 0]);
crown(200, 200, 15);
bunch(200, 178, -90, 96, 31, 76, 3, 4, 1);
write_svg('6-harvest.svg', 'Blue Java ready to harvest');

# 7. Harvested produce, front view: a short hand of four plump powder-blue bananas, mirrored and stubbier
#    than the regular banana's long slim hand.
for my $k (0 .. 3) {
  finger(262 - $k * 3, 294 + $k * 8, -124 - $k * 20, 160 - abs($k - 1.5) * 10, 46, 54, fat => 1, shade => "c1");
}
poly('c1', [292, 300], [262, 284], [244, 322], [276, 334]);
poly('c2', [292, 300], [262, 284], [256, 298], [286, 312]);
poly('c4', [292, 300], [286, 312], [296, 316], [300, 304]);
write_svg('7-harvest-front.svg', 'Hand of Blue Java bananas');

# 8. Dead (never watered): cracked soil, a dry stump, four broad leaves crumpled flat and brown.
soil(200, 200, 70, 62, 82);
cracks(7, 84, 15);
srand(86);
for my $l ([-128, 126, 62, 26], [-38, 118, 58, -30], [34, 108, 56, 24], [148, 116, 60, -28]) {
  my ($a, $len, $w, $b) = @$l; my (@tl, @tr);
  for (1 .. 3) { push @tl, [0.15 + rand(0.8), 0.5 + rand(0.35)]; push @tr, [0.15 + rand(0.8), 0.5 + rand(0.35)]; }
  my ($dx, $dy) = dir($a);
  bleaf(200 + $dx * 8, 200 + $dy * 8, $a, $len, $w, $b, 'c3', 'c4', tearsL => \@tl, tearsR => \@tr, veins => 1, pf => 0.14);
}
poly('c4', ell(200, 200, 22, 22, 11, 7));
poly('c3', ell(200, 200, 15, 15, 9, 3));
poly('c4', ell(201, 201, 8, 8, 7));
write_svg('8-dead.svg', 'Blue Java died from lack of water');
print "wrote 8 files to $OUT\n";

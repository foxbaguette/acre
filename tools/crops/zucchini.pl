# Zucchini crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/zucchini.pl
# A compact bush (no vines, no tendrils): huge silver-mottled lobed leaves on long stalks from one crown,
# big orange trumpet flowers and smooth dark fruit in the middle.
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/zucchini';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#2E5E2F', c2 => '#7DB64F', c3 => '#F2EDCF', c4 => '#5A3A22', c5 => '#F09A1E');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub light { my ($nx, $ny) = @_; my $l = sqrt($nx * $nx + $ny * $ny) || 1; ($nx * -0.7071 + $ny * -0.7071) / $l }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A tapered blade or stalk (as in wheat.pl). Returns the points along it: [x, y, angle].
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $lightc, $dark, $taper) = @_;
  $taper //= 1;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $t) ** 0.85 + ($i == $n && $taper == 1 ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py, $a];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang);
  my $leftLit = lit(-$dy, $dx);
  my @m = map { [$_->[0], $_->[1]] } @mid;
  poly($leftLit ? $lightc : $dark, @l, reverse @m);
  poly($leftLit ? $dark : $lightc, @r, reverse @m);
  return @mid;
}

# A huge zucchini leaf from above: five deeply cut, pointed and toothed lobes, each split along its vein
# into lit and shaded facets fanning from the stalk, with silver-white mottling along the veins near the base.
sub zleaf {
  my ($x, $y, $ang, $r, $lc, $dc, $silver, $wilt, $seed) = @_;
  $wilt //= 0; srand($seed // int($x * 13 + $y * 7));
  my @lobes = ([-120, 0.72], [-60, 0.94], [0, 1.0], [60, 0.94], [120, 0.72]);
  my @o;   # [angleOffset, radius, lobeIndex, side]
  push @o, [-160, 0.28];
  for my $k (0 .. $#lobes) {
    my ($la, $lr) = @{$lobes[$k]};
    my $prevS = $k == 0 ? -160 : ($lobes[$k - 1][0] + $la) / 2;
    my $nextS = $k == $#lobes ? 160 : ($lobes[$k + 1][0] + $la) / 2;
    push @o, map { [$la + $_->[0] * abs($prevS - $la), $lr * $_->[1]] } ([-0.8, 0.7], [-0.62, 0.8], [-0.5, 0.78], [-0.3, 0.86], [-0.14, 0.92]);
    push @o, [$la, $lr * 1.04];
    push @o, map { [$la + $_->[0] * abs($nextS - $la), $lr * $_->[1]] } ([0.14, 0.92], [0.3, 0.86], [0.5, 0.78], [0.62, 0.8], [0.8, 0.7]);
    push @o, [$nextS, ($k == $#lobes ? 0.28 : 0.56)];
  }
  my @p;
  for my $q (@o) {
    my ($oa, $or) = @$q;
    my $rr = $r * $or * (1 - $wilt * (0.2 + rand(0.45)));
    my $aa = $ang + $oa * (1 - $wilt * 0.3) + $wilt * (rand(30) - 15);
    my ($dx, $dy) = dir($aa);
    push @p, [$x + $dx * $rr, $y + $dy * $rr];
  }
  my @fac;
  for my $i (0 .. $#p - 1) {
    my $m = ($o[$i][0] + $o[$i + 1][0]) / 2; my $k = 0;
    for my $j (0 .. $#lobes) { $k = $j if abs($lobes[$j][0] - $m) < abs($lobes[$k][0] - $m); }
    my $side = $m < $lobes[$k][0] ? -1 : 1;
    my ($nx, $ny) = dir($ang + $lobes[$k][0] + $side * 90);
    push @fac, [lit($nx, $ny) ? $lc : $dc, $i];
  }
  # merge neighbouring facets of the same shade into one fan polygon (no hairline seams)
  my $j = 0;
  while ($j < @fac) { my $e = $j; $e++ while $e + 1 < @fac && $fac[$e + 1][0] eq $fac[$j][0]; poly($fac[$j][0], [$x, $y], @p[$fac[$j][1] .. $fac[$e][1] + 1]); $j = $e + 1; }
  if ($silver) {    # silver mottling along each main vein: a few pale flecks
    for my $k (0 .. $#lobes) {
      my $la = $ang + $lobes[$k][0];
      for my $s ([0.16, 0.28, 7], [0.34, 0.44, 9], [0.52, 0.6, 7]) {
        my ($u0, $u1, $sp) = @$s; next if $u1 > $lobes[$k][1] * 0.7 && $k != 2;
        for my $sd (-1, 1) {
          my ($ax, $ay) = dir($la + $sd * $sp); my ($bx, $by) = dir($la + $sd * $sp * 0.5);
          poly($silver, [$x + $ax * $r * $u0, $y + $ay * $r * $u0], [$x + $bx * $r * $u1, $y + $by * $r * $u1], [$x + $ax * $r * ($u0 + $u1) / 2 * 1.08, $y + $ay * $r * ($u0 + $u1) / 2 * 1.08]);
        }
      }
    }
  }
}

# A big trumpet flower from above: five pointed, ruffled lobes split into lit and shaded halves, a deep throat.
sub zflower {
  my ($x, $y, $r, $rot) = @_;
  my @o;
  for my $k (0 .. 4) {
    my $a = $rot + $k * 72;
    push @o, [$a - 36, 0.58, 's'], [$a - 22, 0.86, 'e'], [$a - 10, 0.84, 'e'], [$a, 1.0, 't'], [$a + 10, 0.84, 'e'], [$a + 22, 0.86, 'e'];
  }
  my @p = map { my ($dx, $dy) = dir($_->[0]); [$x + $dx * $r * $_->[1], $y + $dy * $r * $_->[1]] } @o;
  for my $i (0 .. $#p) {
    my $j = ($i + 1) % @p;
    my $k = int($i / 6); my $tipA = $rot + $k * 72;
    my $side = ($i % 6) < 3 ? -1 : 1;
    my ($nx, $ny) = dir($tipA + $side * 90);
    poly(lit($nx, $ny) ? 'c3' : 'c5', [$x, $y], $p[$i], $p[$j]);
  }
  my @t = map { my ($dx, $dy) = dir($rot + 36 + $_ * 72); [$x + $dx * $r * 0.4, $y + $dy * $r * 0.4] } 0 .. 4;
  poly('c5', @t);
  poly('c4', map { my ($dx, $dy) = dir($rot + 36 + $_ * 72); [$x + $dx * $r * 0.22 + 1.5, $y + $dy * $r * 0.22 + 1.5] } 0 .. 4);
  poly('c3', map { my ($dx, $dy) = dir($rot + $_ * 72); [$x + $dx * $r * 0.13, $y + $dy * $r * 0.13] } 0 .. 4);
}

# A zucchini: long, smooth, slightly club-shaped, dark green with pale flecks and a lit stripe. From (x,y)
# (the stalk end) heading `ang`. Optional withered or fresh flower on the blossom end.
sub zuke {
  my ($x, $y, $ang, $len, $w, $flower, $seed) = @_;
  srand($seed // 1);
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $P = sub { my ($u, $v) = @_; [$x + $dx * $u * $len + $nx * $v * $w / 2, $y + $dy * $u * $len + $ny * $v * $w / 2] };
  my $prof = sub { my $u = shift; my $h = 0.7 + 0.3 * $u; $h *= sqrt(max(0, 1 - (($u - 0.9) / 0.1) ** 2)) if $u > 0.9; $h *= 0.6 + 0.4 * sqrt($u / 0.06) if $u < 0.06; $h };
  my @us = (0, 0.02, 0.06, 0.2, 0.4, 0.6, 0.8, 0.9, 0.95, 0.98, 1.0);
  my @L = map { $P->($_, $prof->($_)) } @us; my @R = map { $P->($_, -$prof->($_)) } @us;
  poly('c1', @L, reverse @R);
  my $ls = lit($nx, $ny) ? 1 : -1;
  # deep shade along the far side, and a long glossy lit stripe on the near side
  poly('c4', (map { $P->($_, -$ls * $prof->($_)) } @us[1 .. 9]), (map { $P->($_, -$ls * $prof->($_) * 0.74) } reverse @us[2 .. 8]));
  poly('c2', (map { $P->($_, $ls * $prof->($_) * 0.62) } @us[2 .. 8]), (map { $P->($_, $ls * $prof->($_) * 0.3) } reverse @us[3 .. 7]));
  # pale flecks
  for my $i (0 .. int($len / 9)) {
    my $u = 0.1 + rand(0.78); my $v = (rand(1.6) - 0.8) * $prof->($u);
    next if -$ls * $v > 0.55 * $prof->($u);
    my $p = $P->($u, $v); my $q = $len * 0.025;
    poly('c3', [$p->[0] - $dx * $q, $p->[1] - $dy * $q], [$p->[0] + $nx * 1.2, $p->[1] + $ny * 1.2], [$p->[0] + $dx * $q, $p->[1] + $dy * $q], [$p->[0] - $nx * 1.2, $p->[1] - $ny * 1.2]);
  }
  # stalk end: a ridged, flared stem
  my $s0 = $P->(0.02, 0);
  poly("c2", $P->(-0.01, 0.42), $P->(0.06, 0.66), $P->(0.08, 0.2), $P->(0.06, -0.66), $P->(-0.01, -0.42));
  my @st = blade($s0->[0], $s0->[1], $ang + 180, $len * 0.12, $w * 0.36, 0, "c2", "c1", 0.15);
  for my $rg (-1, 1) { my $q = $w * 0.07 * $rg; poly("c1", [$s0->[0] + $nx * $q, $s0->[1] + $ny * $q], [$st[-1][0] + $nx * $q * 0.9, $st[-1][1] + $ny * $q * 0.9], [$st[-1][0] + $nx * $q * 1.3, $st[-1][1] + $ny * $q * 1.3], [$s0->[0] + $nx * $q * 1.5, $s0->[1] + $ny * $q * 1.5]); }
  poly('c3', map { my ($ex, $ey) = dir($ang + 180 + $_ * 72); [$st[-1][0] + $ex * $w * 0.13, $st[-1][1] + $ey * $w * 0.13] } 0 .. 4);
  # blossom end
  my $e = $P->(1.0, 0);
  if ($flower) {       # the wilting flower still on the tip: a flared, twisted trumpet with pointed lobes
    my $F = sub { my ($u, $v) = @_; [$e->[0] + $dx * $u * $w + $nx * $v * $w / 2, $e->[1] + $dy * $u * $w + $ny * $v * $w / 2] };
    my @top = ([-0.06, 0.3], [0.5, 0.38], [0.86, 0.62], [0.8, 0.3], [1.04, 0.22], [0.92, -0.04], [1.08, -0.2], [0.84, -0.34], [0.88, -0.6], [0.5, -0.36], [-0.06, -0.3]);
    poly('c5', map { $F->(@$_) } @top);
    poly('c3', map { $F->($_->[0], $ls * abs($_->[1])) } [-0.04, 0.0], [0.5, 0.04], [0.9, 0.08], [0.98, 0.6], [0.5, 0.42], [-0.04, 0.32]);
    poly('c1', $F->(-0.02, 0.34), $F->(0.18, 0.5), $F->(0.16, 0.0), $F->(0.18, -0.5), $F->(-0.02, -0.34));   # green sepals at its base
  }
  else { poly('c4', map { my ($ex, $ey) = dir($_ * 72); [$e->[0] - $dx * $w * 0.08 + $ex * $w * 0.1, $e->[1] - $dy * $w * 0.08 + $ey * $w * 0.1] } 0 .. 4); }
}

# Flat cream seed: a narrow rounded oval with a shaded edge and a raised rim line.
sub zseed {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 15) {
    my $th = 2 * pi * $i / 16;
    my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 + 0.18 * cos($th)) * (cos($th) < -0.9 ? 0.6 : 1);
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly('c3', @o);
  shade_rim($x, $y, $len * 0.45, 'c4', 0.8, @o);
  poly('c2', [$x - $dx * $len * 0.3 + $nx * 1, $y - $dy * $len * 0.3 + $ny * 1], [$x + $dx * $len * 0.3 + $nx * 1, $y + $dy * $len * 0.3 + $ny * 1],
             [$x + $dx * $len * 0.3 - $nx * 1, $y + $dy * $len * 0.3 - $ny * 1], [$x - $dx * $len * 0.3 - $nx * 1, $y - $dy * $len * 0.3 - $ny * 1]) if 0;
}

# Shaded crescent along the lower-right edge of any convex outline @o around (x,y).
sub shade_rim {
  my ($x, $y, $r, $cls, $kmin, @o) = @_;
  my $n = @o;
  my @d = map { my ($vx, $vy) = ($_->[0] - $x, $_->[1] - $y); my $l = sqrt($vx * $vx + $vy * $vy) || 1; ($vx + $vy) * 0.7071 / $l } @o;
  my $s = 0; for my $i (0 .. $n - 1) { if ($d[$i] > 0.1 && $d[($i - 1) % $n] <= 0.1) { $s = $i; last } }
  my ($cx, $cy) = ($x - $r * 0.3, $y - $r * 0.3);
  my (@out, @in);
  for my $j (0 .. $n - 1) {
    my $i = ($s + $j) % $n; last unless $d[$i] > 0.1;
    push @out, $o[$i];
    my $k = $kmin + (1 - $kmin) * (1 - ($d[$i] - 0.1) / 0.9) ** 1.5;
    push @in, [$cx + ($o[$i][0] - $cx) * $k, $cy + ($o[$i][1] - $cy) * $k];
  }
  poly($cls, @out, reverse @in) if @out > 1;
}

# Small irregular patch of soil.
sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o;
  srand($seed);
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12; my $k = 0.82 + rand(0.3); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
}

sub cracks {
  my ($n, $seed, $seg, $cls) = @_;
  srand($seed);
  for my $i (0 .. $n - 1) {
    my $a = $i * 360 / $n + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
    for my $k (0 .. 4) {
      my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.4 - $k * 0.4;
      push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
      $x += $dx * $seg; $y += $dy * $seg;
    }
    poly($cls, @l, [$x, $y], reverse @r);
  }
}

sub write_svg {
  my ($file, $label) = @_;
  open my $fh, '>', "$OUT/$file" or die $!;
  print $fh qq{<?xml version="1.0" encoding="UTF-8"?>\n<svg viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="$label">\n  <style>\n};
  print $fh "    .$_ { fill: var(--$_, $PAL{$_}); }\n" for qw(c1 c2 c3 c4 c5);
  print $fh "  </style>\n  <g transform=\"translate(0 0)\">\n", join("\n", @S), "\n  </g>\n</svg>\n";
  close $fh; @S = ();
}

# A leaf on its long hollow stalk from the crown: stalk heading `ang`, the blade opening at its end.
sub leaf_on {
  my ($ang, $plen, $r, $lc, $dc, $silver, $wilt, $seed) = @_;
  my ($dx, $dy) = dir($ang);
  my @m = blade(200 + $dx * 4, 200 + $dy * 4, $ang, $plen, 7, 0, $lc // 'c2', $dc // 'c1', 0.3);
  my ($ex, $ey) = @{$m[-1]};
  zleaf($ex - $dx * $r * 0.12, $ey - $dy * $r * 0.12, $ang, $r, $lc // 'c2', $dc // 'c1', $silver, $wilt, $seed);
}

# The bush: leaves [angle, stalk, radius] drawn longest-reach first so the inner ones overlap them.
sub bush {
  my ($silver, @lv) = @_;
  leaf_on($_->[0], $_->[1], $_->[2], 'c2', 'c1', $silver, 0, int($_->[0] * 3 + 500)) for sort { ($b->[1] + $b->[2]) <=> ($a->[1] + $a->[2]) } @lv;
}

# Smooth oval seed leaf (cotyledon), split along its midrib.
sub seedleaf {
  my ($x, $y, $ang, $len, $w) = @_;
  my $n = 10; my (@mid, @l, @r); my ($dx, $dy) = dir($ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my $hw = $w / 2 * sin(pi * (0.08 + 0.92 * $t)) ** 0.55;
    my ($px, $py) = ($x + $dx * $len * $t, $y + $dy * $len * $t);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
  }
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? 'c2' : 'c1', @l, reverse @mid);
  poly($leftLit ? 'c1' : 'c2', @r, reverse @mid);
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a small heap of flat, narrow cream seeds.
for my $s ([128, 300, 10], [196, 312, -170], [262, 300, 168], [160, 262, 196], [230, 262, -16], [196, 224, -94], [292, 268, 130]) {
  zseed($s->[0], $s->[1], $s->[2], 84, 42);
}
write_svg('1-seeds-front.svg', 'Zucchini seeds');

# 2. Just sown, top down: three pockets, two seeds pushed into each.
my @sown = ([170, 174], [236, 182], [198, 238]);
for (@sown) { soil($_->[0], $_->[1], 30, 26, int($_->[0] * 7 + $_->[1])); }
srand(2);
for (@sown) { my ($x, $y) = @$_; my $a = rand(180); my ($dx, $dy) = dir($a + 90); zseed($x + $dx * 7, $y + $dy * 7, $a, 40, 21); zseed($x - $dx * 7, $y - $dy * 7, $a + 12, 40, 21); }
write_svg('2-sown.svg', 'Zucchini just sown');

# 3. First growth, top down: two oval seed leaves and the first small lobed, silver-veined leaf.
soil(200, 200, 34, 30, 3);
seedleaf(200, 200, 165, 74, 42); seedleaf(200, 200, -15, 74, 42);
leaf_on(-100, 22, 54, "c2", "c1", "c3", 0, 31); leaf_on(80, 10, 36, "c2", "c1", "c3", 0, 32);
write_svg('3-first-growth.svg', 'Zucchini first growth');

# 4. Second growth, top down: a young bush of big lobed leaves on long stalks from one crown.
soil(200, 200, 34, 30, 4);
bush("c3", [-130, 50, 70], [-40, 54, 72], [50, 50, 70], [140, 52, 72], [-90, 18, 52], [95, 16, 50]);
write_svg('4-second-growth.svg', 'Zucchini second growth');

# 5. Third growth, top down: a full bush; big orange trumpet flowers open in the crown, a baby zucchini.
soil(200, 200, 34, 30, 5);
bush("c3", [-150, 70, 84], [-80, 72, 86], [-10, 68, 84], [60, 72, 86], [130, 68, 84], [200, 66, 80], [-115, 30, 62], [25, 30, 62], [165, 28, 60]);
zuke(206, 206, 40, 84, 26, 1, 5);
zflower(174, 180, 44, -10); zflower(236, 168, 38, 20);
write_svg('5-third-growth.svg', 'Zucchini third growth with flowers');

# 6. Harvest, top down: a huge bush with long glossy zucchini lying out from the crown under the leaves.
soil(200, 200, 34, 30, 6);
bush("c3", [-150, 86, 96], [-82, 90, 98], [-12, 86, 96], [58, 90, 98], [128, 86, 96], [198, 84, 92]);
zuke(214, 216, 34, 150, 42, 0, 61);
zuke(192, 216, 130, 140, 40, 0, 62);
zuke(208, 188, -50, 132, 38, 1, 63);
bush("c3", [-115, 30, 66], [165, 26, 62]);
zflower(184, 194, 40, -20);
write_svg('6-harvest.svg', 'Zucchini ready to harvest');

# 7. Harvested produce, front view: two zucchini, one still wearing its flower.
zuke(66, 254, -10, 272, 76, 0, 71);
zuke(84, 330, 2, 236, 68, 1, 72);
write_svg('7-harvest-front.svg', 'Harvested zucchini');

# 8. Dead (never watered), top down: cracked dry soil, collapsed shrivelled leaves lying flat, a wizened fruit.
soil(200, 200, 58, 52, 8);
cracks(8, 83, 13, 'c3');
for my $l ([-130, 36, 72], [-40, 40, 76], [50, 36, 70], [140, 38, 72], [-90, 12, 52], [100, 12, 50]) {
  my ($a, $pl, $r) = @$l; my ($dx, $dy) = dir($a);
  my @m = blade(200 + $dx * 4, 200 + $dy * 4, $a, $pl + 10, 6, 40, 'c3', 'c4', 0.3);
  zleaf($m[-1][0], $m[-1][1], $m[-1][2], $r, 'c3', 'c4', 0, 0.55, $a + 900);
}
write_svg('8-dead.svg', 'Zucchini died from lack of water');
print "wrote 8 files to $OUT\n";

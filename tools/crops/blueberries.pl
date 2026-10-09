# Blueberry crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/blueberries.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/blueberries';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#2C6046', c2 => '#7DB466', c3 => '#EFE9DA', c4 => '#3A2A2F', c5 => '#5874B5');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Points along a bent path: 11 entries [x, y, heading] (same stepping as blade).
sub path {
  my ($x, $y, $a, $len, $bend) = @_; my @p;
  for my $i (0 .. 10) { push @p, [$x, $y, $a]; my ($dx, $dy) = dir($a); $x += $dx * $len / 10; $y += $dy * $len / 10; $a += $bend / 10; }
  @p;
}

# A tapered blade / twig from (x,y) heading `ang`, bending `bend` degrees over its length.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $tipw) = @_;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $t * (1 - ($tipw // 0))) ** 0.85 + ($i == $n ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# Ellipse point list (rotated by rot degrees).
sub ell {
  my ($x, $y, $rx, $ry, $n, $rot) = @_; $rot //= 0; my ($c, $s) = dir($rot);
  map { my ($u, $v) = dir($_ * 360 / $n); [$x + $u * $rx * $c - $v * $ry * $s, $y + $u * $rx * $s + $v * $ry * $c] } 0 .. $n - 1;
}

# A smooth elliptic blueberry leaf with a pointed tip, split along the midrib into a lit and a shaded half,
# with a couple of side-vein grooves.
sub oleaf {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, %o) = @_;
  my $N = 12; my $p = $o{p} // 1.0; my $q = $o{q} // 0.62;
  my (@l, @r, @m);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $N) {
    my $t = $i / $N; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (sin(pi * min(0.999, $t ** $p))) ** $q;
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @m, [$px, $py, $dx, $dy, $hw];
    $px += $dx * $len / $N; $py += $dy * $len / $N; $a += $bend / $N;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  my @mm = map { [$_->[0], $_->[1]] } @m;
  poly($leftLit ? $light : $dark, @l, reverse @mm);
  poly($leftLit ? $dark : $light, @r, reverse @mm);
  return unless $o{veins};
  for my $i (4, 7) {
    my ($mx, $my, $vx, $vy, $hw) = @{$m[$i]};
    my $side = $leftLit ? 1 : -1;                            # groove on the lit half only
    my ($sx, $sy) = (-$vy * $side, $vx * $side); my $L = $hw * 0.75;
    poly($dark, [$mx + $vx * 1.2, $my + $vy * 1.2], [$mx + $sx * $L + $vx * $L * 0.7, $my + $sy * $L + $vy * $L * 0.7], [$mx - $vx * 1.2, $my - $vy * 1.2]);
  }
}

# A blueberry. Body, a shaded crescent toward the lower right, a pale bloom facet toward the light and the
# signature star crown at (crown angle, crown offset as a fraction of r). sq squashes it vertically (front views).
sub bberry {
  my ($x, $y, $r, $cang, $cd, %o) = @_;
  my $body = $o{body} // 'c5'; my $shade = $o{shade} // 'c4'; my $hi = $o{hi} // 'c3'; my $sq = $o{sq} // 1;
  poly($body, ell($x, $y, $r, $r * $sq, 20));
  my @out; my @in;
  for my $k (0 .. 10) {                         # crescent from -40 to 130 degrees, thickest at 45
    my $th = -40 + 170 * $k / 10; my ($u, $v) = dir($th);
    push @out, [$x + $u * $r, $y + $v * $r * $sq];
    my $d = 1 - 0.36 * sin(pi * $k / 10);
    unshift @in, [$x + $u * $r * $d, $y + $v * $r * $sq * $d];
  }
  poly($shade, @out, @in);
  unless ($o{nohi}) {
    my ($hx, $hy) = ($x - $r * 0.42, $y - $r * 0.4 * $sq); my $h = $r * 0.2;
    poly($hi, [$hx - $h * 0.9, $hy + $h * 0.5], [$hx - $h * 0.2, $hy - $h * 0.9], [$hx + $h * 0.9, $hy - $h * 0.6], [$hx + $h * 0.1, $hy + $h * 0.2]);
  }
  return if $o{nocrown};
  my ($cu, $cv) = dir($cang);
  my ($cx, $cy) = ($x + $cu * $cd * $r, $y + $cv * $cd * $r * $sq);
  my $fs = 1 - min(0.6, $cd * 0.75);             # foreshortening of the crown toward the rim
  my $cr = $r * ($o{cr} // 0.4);
  my $star = sub {
    my ($ox, $oy, $k) = @_; my @p;
    for my $i (0 .. 9) {
      my $rr = ($i % 2 ? 0.42 : 1) * $cr * $k; my ($a, $b) = dir($i * 36 - 90 + ($o{crot} // 0));
      # squash along the crown direction
      my $along = $a * $cu + $b * $cv; my $acr = -$a * $cv + $b * $cu;
      $along *= $fs; $acr *= 1;
      push @p, [$ox + ($along * $cu - $acr * $cv) * $rr, $oy + ($along * $cv + $acr * $cu) * $rr * ($o{sq} // 1)];
    }
    @p;
  };
  poly($o{crim} // $hi, $star->($cx + 1.2, $cy + 1.2, 1.12)) unless $o{norim};
  poly($o{ccol} // $shade, $star->($cx, $cy, 1));
}

# Small white urn-shaped blueberry flower hanging toward `ang` from its pedicel end (x,y): plump cream urn
# with a shaded side, a flared crimped lip around a dark green mouth, green calyx at the stalk end.
sub bell {
  my ($x, $y, $ang, $len) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $P = sub { my ($u, $v) = @_; [$x + $dx * $u * $len + $nx * $v * $len, $y + $dy * $u * $len + $ny * $v * $len] };
  my @prof = ([0.04, 0.16], [0.18, 0.33], [0.4, 0.4], [0.62, 0.37], [0.8, 0.27], [0.9, 0.24]);
  my $s = lit($nx, $ny) ? -1 : 1;                    # side facing away from the light
  poly('c3', $P->(0, 0), (map { $P->($_->[0], $_->[1]) } @prof), $P->(1.0, 0.3), $P->(1.02, 0),
              $P->(1.0, -0.3), (map { $P->($_->[0], -$_->[1]) } reverse @prof));
  poly('c2', (map { $P->($_->[0], $_->[1] * $s) } @prof[1 .. 5]), $P->(0.86, 0.1 * $s), $P->(0.55, 0.2 * $s), $P->(0.25, 0.16 * $s));
  poly('c1', ell(@{$P->(0.97, 0)}, $len * 0.07, $len * 0.17, 8, $ang));
  poly('c1', $P->(-0.08, 0), $P->(0.1, 0.2), $P->(0.2, 0), $P->(0.1, -0.2));
}
# A spray of bells: short green pedicels fanning from (x,y) toward `ang`.
sub bells {
  my ($x, $y, $ang, $n, $len) = @_;
  my @b = map { my $a = $ang + ($_ - ($n - 1) / 2) * 34; my $pl = $len * (0.5 + 0.25 * ($_ % 2)); my ($u, $v) = dir($a); [$a, $pl, $x + $u * $pl, $y + $v * $pl] } 0 .. $n - 1;
  blade($x, $y, $_->[0], $_->[1], 2.6, 0, 'c2', 'c1', 0.6) for @b;
  bell($_->[2], $_->[3], $_->[0], $len) for sort { ($b->[2] + $b->[3]) <=> ($a->[2] + $a->[3]) } @b;
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
  my ($n, $step, $seed) = @_; srand($seed);
  for my $i (0 .. $n - 1) {
    my $a = $i * 360 / $n + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
    for my $k (0 .. 4) {
      my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.2 - $k * 0.35;
      push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
      $x += $dx * $step; $y += $dy * $step;
    }
    poly('c3', @l, [$x, $y], reverse @r);
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

# A tiny blueberry seed: an oval with a lit half.
sub seed {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 13) {
    my $th = 2 * pi * $i / 14; my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 - 0.25 * cos($th));
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly('c4', @o);
  my @half = lit($nx, $ny) ? @o[7 .. 13] : @o[0 .. 7];
  poly('c3', @half, [$x + $dx * 0.5, $y + $dy * 0.5]);
}

# Top-down shrub: woody twigs radiating from the crown with small oval leaves; leaves drawn outer-first so the
# bush domes up toward the middle. Twigs: [angle, length, bend]. Returns each twig's path.
sub shrub {
  my ($seed, $leafLen, $per, $tw, $L, $D, $tl, $td, @tw) = @_;
  srand($seed); my (@leaves, @paths);
  for my $t (@tw) {
    my @p = path(200, 200, @$t); push @paths, \@p;
    for my $k (1 .. $per) {
      my $f = 0.2 + 0.8 * $k / $per; my ($x, $y, $h) = @{$p[int($f * 10 + 0.5)]};
      my $side = $k % 2 ? 1 : -1;
      push @leaves, [$x, $y, $h + $side * (42 + rand(24)), $leafLen * (0.78 + 0.3 * $f + rand(0.12)), rand(16) - 8];
    }
    my ($x, $y, $h) = @{$p[10]};
    push @leaves, [$x, $y, $h + rand(16) - 8, $leafLen * 1.05, 0];
  }
  if ($leafLen > 38) { for my $k (0 .. 5) { my $a = $tw[0][0] + 30 + $k * 60 + rand(14); my ($u, $v) = dir($a); push @leaves, [200 + $u * 14, 200 + $v * 14, $a, $leafLen * 0.95, rand(16) - 8]; } }
  blade(200, 200, $_->[0], $_->[1], $tw, $_->[2], $tl, $td, 0.4) for @tw;
  for (sort { (($b->[0] - 200) ** 2 + ($b->[1] - 200) ** 2) <=> (($a->[0] - 200) ** 2 + ($a->[1] - 200) ** 2) } @leaves) {
    my ($x, $y, $a, $l, $bd) = @$_;
    oleaf($x, $y, $a, $l, $l * 0.62, $bd, $L, $D, veins => $l > 30);
  }
  @paths;
}

# A top-down cluster of blueberries hanging off a twig at (x,y), spreading toward `ang`.
my @CL = ([0.0, 0.0, 1.0], [1.55, -0.95, 0.92], [1.6, 0.95, 0.96], [2.9, 0.0, 0.9], [0.9, 1.9, 0.82], [2.7, -1.75, 0.8], [3.9, 1.0, 0.78]);
sub cluster {
  my ($x, $y, $ang, $n, $r, %o) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $flip = $o{flip} ? -1 : 1;
  blade($x - $dx * $r * 1.4, $y - $dy * $r * 1.4, $ang, $r * 1.6, 3, 0, 'c2', 'c1');
  my @b;
  for my $i (0 .. $n - 1) {
    my ($u, $v, $s) = @{$CL[$i]};
    push @b, [$x + $dx * $u * $r + $nx * $v * $r * $flip, $y + $dy * $u * $r + $ny * $v * $r * $flip, $r * $s, $i];
  }
  for (sort { ($b->[0] + $b->[1]) <=> ($a->[0] + $a->[1]) } @b) {
    my ($bx, $by, $br, $i) = @$_;
    my $green = $o{green} && $o{green}{$i};
    bberry($bx, $by, $br, $ang + ($i * 37 % 50) - 25, 0.32, crot => $i * 23,
           $green ? (body => 'c2', shade => 'c1', ccol => 'c1', crim => 'c3') : ());
  }
}

# 1. Planting material, front view: a ripe blueberry with its crown and a little heap of its tiny seeds.
bberry(200, 176, 88, -90, 0.6, sq => 0.9, cr => 0.42);
srand(11);
my @seedpos = ([140, 312], [166, 318], [194, 322], [222, 320], [250, 316], [276, 308], [154, 296], [182, 300], [210, 302], [238, 298], [264, 294],
               [170, 282], [198, 284], [226, 282], [250, 278], [186, 266], [214, 266]);
seed(200 + ($_->[0] - 200) * 0.72, 292 + ($_->[1] - 294) * 0.72, rand(360), 17, 11) for @seedpos;
write_svg('1-seeds-front.svg', 'Blueberry seeds');

# 2. Just sown, top down: tiny seeds pressed into small soil pockets.
my @sown = ([168, 170], [236, 166], [202, 216], [156, 240], [248, 238]);
for (@sown) { soil($_->[0], $_->[1], 26, 22, int($_->[0] * 7 + $_->[1])); }
srand(22);
for (@sown) { my ($x, $y) = @$_; seed($x - 8, $y - 3, rand(180), 13, 9); seed($x + 7, $y - 4, rand(180), 13, 9); seed($x, $y + 7, rand(180), 13, 9); }
write_svg('2-sown.svg', 'Blueberries just sown');

# 3. First growth, top down: a little woody seedling with pairs of small oval leaves.
soil(200, 200, 34, 30, 3);
for my $t ([-70, 34, 14], [60, 30, -12], [175, 32, 10]) { blade(200, 200, @$t[0, 1], 5, $t->[2], 'c1', 'c4', 0.5); }
oleaf(200, 200, -130, 36, 24, 6, 'c2', 'c1'); oleaf(200, 200, 15, 38, 25, -6, 'c2', 'c1'); oleaf(200, 200, 110, 34, 23, 8, 'c2', 'c1');
for my $t ([-70, 34, 14], [60, 30, -12], [175, 32, 10]) {
  my @p = path(200, 200, @$t); my ($x, $y, $h) = @{$p[10]};
  oleaf($x, $y, $h - 40, 44, 28, 8, 'c2', 'c1', veins => 1); oleaf($x, $y, $h + 40, 42, 27, -8, 'c2', 'c1', veins => 1);
  oleaf($x, $y, $h, 38, 24, 0, 'c2', 'c1');
}
write_svg('3-first-growth.svg', 'Blueberry first growth');

# 4. Second growth, top down: a young bushy shrub of woody twigs and small oval leaves.
soil(200, 200, 34, 30, 4);
shrub(41, 38, 5, 6, 'c2', 'c1', 'c1', 'c4', [-95, 76, 20], [-25, 81, -18], [45, 74, 22], [115, 78, -20], [185, 76, 18], [-160, 51, -14], [80, 46, 16]);
write_svg('4-second-growth.svg', 'Blueberry second growth');

# 5. Third growth, top down: a full shrub hung with clusters of white bell flowers and first green berries.
soil(200, 200, 34, 30, 5);
my @p5 = shrub(51, 40, 5, 7, 'c2', 'c1', 'c1', 'c4', [-92, 109, 22], [-38, 111, -20], [12, 107, 20], [62, 113, -22], [112, 109, 20],
               [162, 111, -18], [212, 109, 22], [-130, 68, -16], [40, 66, 18], [140, 63, -14]);
for my $i (0 .. 6) {
  my ($x, $y, $h) = @{$p5[$i][$i % 2 ? 6 : 8]};
  my $side = $i % 2 ? 1 : -1; my ($dx, $dy) = dir($h + $side * 70);
  my ($fx, $fy) = ($x + $dx * 6, $y + $dy * 6);
  if ($i % 3 == 2) { cluster($fx, $fy, $h + $side * 70, 5, 10, green => { map { $_ => 1 } 0 .. 6 }); next; }
  bells($fx, $fy, $h + $side * 70, 4, 26);
}
write_svg('5-third-growth.svg', 'Blueberry third growth, flowering');

# 6. Harvest, top down: the leafy shrub laden with clusters of ripe dusty-blue berries.
soil(200, 200, 34, 30, 6);
my @p6 = shrub(61, 42, 5, 8, 'c2', 'c1', 'c1', 'c4', [-92, 132, 22], [-40, 134, -20], [10, 129, 20], [58, 136, -22], [106, 132, 20],
               [154, 134, -18], [202, 132, 22], [-140, 87, -16], [30, 85, 18], [128, 82, -14], [-62, 67, 12], [180, 64, -12]);
for my $i (0 .. 6) {
  for my $at ([6, 1], [9, -1]) {
    my ($x, $y, $h) = @{$p6[$i][$at->[0]]}; my $side = $at->[1] * ($i % 2 ? 1 : -1);
    my $a = $h + $side * 62; my ($dx, $dy) = dir($a);
    cluster($x + $dx * 10, $y + $dy * 10, $a, $at->[0] == 9 ? 6 : 5, 13, flip => $side < 0, green => ($i == 3 && $at->[0] == 6 ? { 3 => 1, 4 => 1 } : undef));
  }
}
write_svg('6-harvest.svg', 'Blueberries ready to harvest');

# 7. Harvested produce, front view: a small heap of blueberries in front of a sprig of leaves.
oleaf(150, 250, -128, 112, 58, 14, 'c2', 'c1', veins => 1);
oleaf(250, 246, -50, 106, 56, -14, 'c2', 'c1', veins => 1);
my @heap = ([126, 286, 42, -100, 0.56], [204, 292, 46, -60, 0.62], [282, 286, 42, -30, 0.78], [162, 236, 44, -130, 0.62], [244, 234, 44, -84, 0.5],
            [204, 186, 44, -96, 0.56], [160, 312, 34, -150, 0.8], [246, 314, 34, -70, 0.66]);
for (sort { $a->[1] <=> $b->[1] } @heap) { my ($x, $y, $r, $c, $cd) = @$_; bberry($x, $y, $r, $c, $cd, sq => 0.9, crot => $x); }
write_svg('7-harvest-front.svg', 'Harvested blueberries');

# 8. Dead (never watered), top down: cracked dry soil, bare brittle twigs, curled dry leaves, shrivelled berries.
soil(200, 200, 58, 50, 8);
cracks(7, 13, 83);
{
  my @tw = ([-95, 96, 30], [-25, 100, -34], [45, 92, 36], [115, 98, -30], [185, 94, 28], [-150, 60, -24], [80, 56, 24]);
  blade(200, 200, $_->[0], $_->[1], 4.5, $_->[2], 'c3', 'c4', 0.3) for @tw;
  srand(88); my @dl;
  for my $t (@tw) {
    my @p = path(200, 200, @$t);
    for my $k (4, 7, 10) {
      my ($x, $y, $h) = @{$p[$k]}; my $side = $k % 2 ? 1 : -1;
      push @dl, [$x, $y, $h + $side * (50 + rand(40)), 36 + rand(8), 17 + rand(5), $side * (25 + rand(30))];
    }
  }
  for (1 .. 7) { my $a = rand(360); my ($u, $v) = dir($a); my $d = 40 + rand(36); push @dl, [200 + $u * $d, 200 + $v * $d, rand(360), 32 + rand(6), 17, rand(60) - 30]; }
  for (@dl) { my ($x, $y, $a, $l, $w, $bd) = @$_; oleaf($x, $y, $a, $l, $w, $bd, 'c3', 'c3'); blade($x, $y, $a, $l * 0.8, 2.4, $bd * 0.8, 'c4', 'c4'); }
  for ([238, 166, 9], [162, 234, 8], [262, 236, 8]) { my ($x, $y, $r) = @$_; poly('c4', map { my ($u, $v) = dir($_ * 36); my $k = $_ % 2 ? 0.78 : 1; [$x + $u * $r * $k, $y + $v * $r * $k] } 0 .. 9); poly('c3', ell($x - 1, $y - 1, 2.2, 2.2, 5)); }
}
write_svg('8-dead.svg', 'Blueberry bush died from lack of water');
print "wrote 8 files to $OUT\n";

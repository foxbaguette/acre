# Kiwi crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/kiwi.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/kiwi';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#3F7A35', c2 => '#86BE4E', c3 => '#F3EBC2', c4 => '#4E3220', c5 => '#A3713F');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A tapered stem / vine from (x,y) heading `ang`, bending `bend` degrees. Returns the end point and angle.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $tipw) = @_;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $t * (1 - ($tipw // 0))) + 0.5;
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py];
    last if $i == $n;
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
  return ($px, $py, $a);
}

# Points along a vine path without drawing it.
sub along {
  my ($x, $y, $ang, $len, $bend, $t) = @_; my $n = 10;
  for my $i (1 .. int($t * $n + 0.5)) { my ($dx, $dy) = dir($ang); $x += $dx * $len / $n; $y += $dy * $len / $n; $ang += $bend / $n; }
  return ($x, $y, $ang);
}

# A round, heart-based kiwi leaf from its stalk end (x,y) pointing `ang`; lit and shaded halves.
my @HEART = ([0.00, 0.00], [-0.07, 0.17], [0.01, 0.37], [0.17, 0.50], [0.38, 0.55], [0.60, 0.49], [0.78, 0.35], [0.92, 0.17], [1.00, 0.00]);
sub heart {
  my ($x, $y, $ang, $len, $light, $dark, $wf) = @_; $wf //= 1;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $P = sub { my ($u, $v) = @_; [$x + $dx * $u * $len + $nx * $v * $wf * $len, $y + $dy * $u * $len + $ny * $v * $wf * $len] };
  my @L = map { $P->($_->[0], $_->[1]) } @HEART;
  my @R = map { $P->($_->[0], -$_->[1]) } @HEART;
  my @mid = map { $P->($_ / 8, 0) } 0 .. 8;
  my $leftLit = lit($nx, $ny);
  poly($leftLit ? $light : $dark, @L, reverse @mid);
  poly($leftLit ? $dark : $light, @R, reverse @mid);
  # a vein facet on the lit half to break up the flat green
  my $lv = $leftLit ? 1 : -1;
  poly($dark, $P->(0.22, 0), $P->(0.52, 0.30 * $lv), $P->(0.50, 0.33 * $lv), $P->(0.30, 0));
}

# A leaf on a short stalk.
sub leaf {
  my ($x, $y, $ang, $len) = @_;
  my ($ex, $ey) = blade($x, $y, $ang, $len * 0.28, 3.4, 0, 'c2', 'c1', 0.7);
  heart($ex, $ey, $ang, $len, 'c2', 'c1');
}

# Fuzzy brown kiwi fruit: an oval with a shaded side, a lit facet and a slightly rough outline.
sub kiwi {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 23) {
    my $th = 2 * pi * $i / 24; my $k = $i % 2 ? 1.0 : 1.035;
    my $u = cos($th) * $len / 2 * $k; my $v = sin($th) * $w / 2 * $k;
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly('c5', @o);
  # shaded crescent: the part of the outline facing away from the light, closed through a chord
  my @sh; my @hi;
  for my $i (0 .. 23) {
    my $th = 2 * pi * $i / 24; my $u = cos($th); my $v = sin($th);
    my $sx = $dx * $u + $nx * $v; my $sy = $dy * $u + $ny * $v;   # outward direction on screen
    push @sh, $i if ($sx * 0.7071 + $sy * 0.7071) > 0.05;
  }
  my %on = map { $_ => 1 } @sh; my ($st) = grep { $on{$_} && !$on{($_ + 23) % 24} } 0 .. 23; $st //= 0;
  my @shp; for my $j (0 .. 23) { my $i = ($st + $j) % 24; last unless $on{$i}; push @shp, $o[$i]; }
  my $off = $w * 0.16;   # inner edge of the shade crescent: the same arc shrunk toward the lower right
  poly('c4', @shp, map { [$x + ($_->[0] - $x) * 0.66 + $off * 0.7071, $y + ($_->[1] - $y) * 0.66 + $off * 0.7071] } reverse @shp);
  # lit facet toward the upper left
  my $hx = $x - 0.7071 * $w * 0.2; my $hy = $y - 0.7071 * $w * 0.2;
  poly($_[5] // 'c3', [$hx - $dx * $len * 0.14, $hy - $dy * $len * 0.14], [$hx + $nx * $w * 0.06, $hy + $ny * $w * 0.06],
             [$hx + $dx * $len * 0.08, $hy + $dy * $len * 0.08], [$hx - $nx * $w * 0.04, $hy - $ny * $w * 0.04]);
}

# A kiwi cut in half, cut face toward the viewer: skin rim, green flesh rays, cream core, ring of dark seeds.
sub kiwi_cut {
  my ($x, $y, $rx, $ry, $tilt) = @_;
  my @rim; for my $i (0 .. 23) { my $th = 2 * pi * $i / 24; push @rim, [$x + 0.06 * $rx + cos($th) * $rx * 1.04, $y + $tilt + sin($th) * $ry * 1.04]; }
  poly('c5', @rim);
  my @ra = map { my $th = 2 * pi * $_ / 24; [$x + cos($th) * $rx, $y + sin($th) * $ry] } 0 .. 23;
  for my $i (0 .. 23) {        # flesh wedges: lit on the upper left, darker on the lower right
    my $th = 2 * pi * ($i + 0.5) / 24; my $b = -cos($th) * 0.7 - sin($th) * 0.7;
    my $cls = ($i % 2) ? ($b > -0.3 ? 'c2' : 'c1') : ($b > 0.5 ? 'c2' : 'c1');
    poly($cls, [$x, $y], $ra[$i], $ra[($i + 1) % 24]);
  }
  my @core = map { my $th = 2 * pi * $_ / 12; [$x + cos($th) * $rx * 0.3, $y + sin($th) * $ry * 0.3] } 0 .. 11;
  poly('c3', @core);
  for my $i (0 .. 17) {        # seeds: small dark teardrops pointing outward
    my $th = 2 * pi * $i / 18 + 0.1; my $r0 = 0.42; my $r1 = 0.56;
    my ($c, $s) = (cos($th), sin($th)); my $sw = 0.06;
    poly('c4', [$x + $c * $rx * $r0, $y + $s * $ry * $r0],
               [$x + ($c * $r1 - $s * $sw) * $rx, $y + ($s * $r1 + $c * $sw) * $ry],
               [$x + $c * $rx * ($r1 + 0.05), $y + $s * $ry * ($r1 + 0.05)],
               [$x + ($c * $r1 + $s * $sw) * $rx, $y + ($s * $r1 - $c * $sw) * $ry]);
  }
}

# A tiny kiwi seed with a lit half.
sub seed {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 13) {
    my $th = 2 * pi * $i / 14; my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 - 0.3 * cos($th));
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly('c4', @o);
  my $leftLit = lit($nx, $ny);
  my @half = $leftLit ? @o[7 .. 13] : @o[0 .. 7];
  poly('c3', @half, [$x, $y]);
}

# Cream five-petal kiwi flower seen from above.
sub flower {
  my ($x, $y, $r, $rot) = @_;
  for my $i (0 .. 4) {
    my $a = $rot + $i * 72; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    my @p = ([0.15, 0], [0.45, 0.42], [0.85, 0.38], [1.0, 0.0], [0.85, -0.38], [0.45, -0.42]);
    my @q = map { [$x + ($dx * $_->[0] + $nx * $_->[1]) * $r, $y + ($dy * $_->[0] + $ny * $_->[1]) * $r] } @p;
    my $leftLit = lit($nx, $ny);
    poly('c3', @q);
    # the shaded side of each cupped petal
    my @h = $leftLit ? (@q[3, 4, 5], $q[0]) : (@q[0 .. 3]);
    poly('c5', $h[0], $h[1], $h[2], $h[3]) if !lit($dx, $dy) && 0;
  }
  my @c = map { my ($dx, $dy) = dir($_ * 40); [$x + $dx * $r * 0.32, $y + $dy * $r * 0.32] } 0 .. 8;
  poly('c5', @c);
  poly('c4', map { my ($dx, $dy) = dir($_ * 60 + 20); [$x + $dx * $r * 0.14 + 1, $y + $dy * $r * 0.14 + 1] } 0 .. 5);
}

# Small irregular patch of soil.
sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o;
  srand($seed);
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12; my $k = 0.82 + rand(0.3); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
}

sub write_svg {
  my ($file, $label) = @_;
  open my $fh, '>', "$OUT/$file" or die $!;
  print $fh qq{<?xml version="1.0" encoding="UTF-8"?>\n<svg viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="$label">\n  <style>\n};
  print $fh "    .$_ { fill: var(--$_, $PAL{$_}); }\n" for qw(c1 c2 c3 c4 c5);
  print $fh "  </style>\n  <g transform=\"translate(0 0)\">\n", join("\n", @S), "\n  </g>\n</svg>\n";
  close $fh; @S = ();
}

# Top-down vine plant: woody canes radiating from the crown, round leaves along them.
# Each cane: [angle, length, bend]. Leaves sorted outer-first so the canopy domes up in the middle.
sub vine_top {
  my ($seed, $cw, $leafLen, $per, $extra, @canes) = @_;
  srand($seed);
  my @leaves;
  for my $c (@canes) {
    my ($a, $len, $bend) = @$c;
    for my $k (1 .. $per) {
      my $t = $k / $per * 0.95;
      my ($px, $py, $pa) = along(200, 200, $a, $len, $bend, $t);
      my $side = $k % 2 ? 1 : -1;
      push @leaves, [$px, $py, $pa + $side * (38 + rand(22)), $leafLen * (0.75 + 0.35 * $t + rand(0.15))];
    }
  }
  push @leaves, @$extra;
  blade(200, 200, $_->[0], $_->[1], $cw, $_->[2], 'c5', 'c4', 0.35) for @canes;
  for (sort { (($b->[0] - 200) ** 2 + ($b->[1] - 200) ** 2) <=> (($a->[0] - 200) ** 2 + ($a->[1] - 200) ** 2) } @leaves) {
    leaf(@$_);
  }
}

# 1. Planting material, front view: half a kiwi showing its seeds, with a few loose seeds in front.
kiwi_cut(200, 200, 92, 108, 0);
seed(150, 330, -20, 18, 10); seed(178, 340, 15, 18, 10); seed(232, 336, -40, 18, 10); seed(256, 326, 25, 17, 9); seed(206, 324, 80, 17, 9);
write_svg('1-seeds-front.svg', 'Kiwi seeds');

# 2. Just sown, top down: tiny seeds pressed into small soil pockets.
my @sown = ([168, 170], [236, 166], [202, 214], [154, 238], [248, 236]);
for (@sown) { soil($_->[0], $_->[1], 26, 22, int($_->[0] * 7 + $_->[1])); }
for (@sown) { my ($x, $y) = @$_; poly('c5', map { my ($dx, $dy) = dir($_ * 30); [$x + $dx * 19, $y + 1 + $dy * 15] } 0 .. 11); }
srand(22);
for (@sown) {
  my ($x, $y) = @$_;
  seed($x - 7, $y - 3, rand(180), 19, 11); seed($x + 8, $y + 3, rand(180), 19, 11);
}
write_svg('2-sown.svg', 'Kiwi just sown');

# 3. First growth, top down: a seedling with two round seed leaves and its first heart-shaped leaves.
soil(200, 200, 36, 32, 3);
blade(200, 200, 160, 20, 4, 10, 'c2', 'c1', 0.6);
leaf(200, 200, 200, 48); leaf(200, 200, 20, 48);
leaf(200, 200, -70, 76); leaf(200, 200, 110, 70); leaf(200, 200, -150, 44);
write_svg('3-first-growth.svg', 'Kiwi first growth');

# 4. Second growth, top down: young woody canes spreading with round leaves.
soil(200, 200, 34, 30, 4);
vine_top(41, 8, 44, 3, [], [-100, 64, 30], [-10, 68, 26], [80, 62, -28], [170, 66, 24], [-150, 43, -20], [30, 47, -16], [130, 37, 20]);
leaf(200, 200, -60, 44); leaf(200, 200, 140, 42);
write_svg('4-second-growth.svg', 'Kiwi second growth');

# 5. Third growth, top down: a full leafy vine with cream flowers opening.
soil(200, 200, 34, 30, 5);
vine_top(51, 11, 52, 4, [], [-95, 98, 30], [-20, 102, 24], [50, 96, -24], [120, 100, 28], [185, 98, -22], [-150, 82, 20], [10, 70, -24], [90, 72, 26], [155, 62, -20]);
leaf(200, 200, -60, 56); leaf(200, 200, 150, 52); leaf(200, 200, 40, 50);
flower(@$_) for ([142, 138, 15, 10], [264, 128, 15, 40], [290, 225, 14, 0], [223, 282, 15, 30], [117, 243, 14, 60], [196, 164, 13, 20], [245, 196, 13, 50], [164, 209, 13, 0]);
write_svg('5-third-growth.svg', 'Kiwi third growth with flowers');

# A cluster of kiwis seen from above, hanging from one short stalk.
sub cluster_top {
  my ($x, $y, $rot) = @_;
  my ($dx, $dy) = dir($rot);
  kiwi($x + $dx * 19 - $dy * 15, $y + $dy * 19 + $dx * 15, $rot + 30, 44, 34);
  kiwi($x + $dx * 19 + $dy * 15, $y + $dy * 19 - $dx * 15, $rot - 30, 44, 34);
  kiwi($x - $dx * 4, $y - $dy * 4, $rot, 46, 36);
  blade($x - $dx * 22, $y - $dy * 22, $rot, 10, 4, 0, 'c5', 'c4', 0.6);
}

# 6. Harvest, top down: the big leafy vine laden with clusters of fuzzy brown kiwis.
soil(200, 200, 34, 30, 6);
vine_top(61, 12, 56, 4, [], [-95, 121, 30], [-20, 126, 24], [50, 118, -24], [120, 124, 28], [185, 121, -22], [-150, 102, 20], [10, 90, -24], [90, 93, 26], [155, 81, -20]);
leaf(200, 200, -60, 58); leaf(200, 200, 150, 54); leaf(200, 200, 40, 52);
cluster_top(@$_) for ([146, 135, 40], [268, 137, 120], [282, 245, 200], [196, 290, 250], [212, 196, 70]);
write_svg('6-harvest.svg', 'Kiwi ready to harvest');

# 7. Harvest item, front view: two fuzzy kiwis and one cut in half (no plant, no soil).
sub kiwi_big {
  my ($x, $y, $ang, $len, $w) = @_;
  kiwi($x, $y, $ang, $len, $w);
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  # broad lit facet on the upper-left shoulder
  my $hx = $x - 0.7071 * $w * 0.2; my $hy = $y - 0.7071 * $w * 0.2;
  poly('c3', [$hx - $dx * $len * 0.3, $hy - $dy * $len * 0.3], [$hx - $dx * $len * 0.05 - 0.7071 * $w * 0.1, $hy - $dy * $len * 0.05 - 0.7071 * $w * 0.1],
             [$hx + $dx * $len * 0.12, $hy + $dy * $len * 0.12], [$hx - $dx * $len * 0.05 + 0.7071 * $w * 0.05, $hy - $dy * $len * 0.05 + 0.7071 * $w * 0.05]);
  # fuzz specks and the dry stem nub at one end
  srand(int($x));
  for (1 .. 9) { my $u = rand(0.7) - 0.35; my $v = rand(0.6) - 0.3; my $px = $x + ($dx * $u * $len + $nx * $v * $w); my $py = $y + ($dy * $u * $len + $ny * $v * $w);
    poly('c4', [$px - 1.5, $py], [$px, $py - 1.2], [$px + 1.5, $py], [$px, $py + 1.2]); }
  my $ex = $x + $dx * $len * 0.49; my $ey = $y + $dy * $len * 0.49;
  poly('c4', map { my ($ox, $oy) = dir($_ * 60); [$ex + $ox * 6, $ey + $oy * 6] } 0 .. 5);
}
kiwi_big(146, 178, 200, 150, 110);
kiwi_big(258, 190, -20, 150, 110);
kiwi_cut(200, 266, 80, 64, 7);
write_svg('7-harvest-front.svg', 'Kiwi harvest');

# 8. Dead (never watered), top down: cracked dry soil, bare woody canes, dried curled leaves lying flat.
soil(200, 200, 62, 54, 8);
srand(83);
for my $i (0 .. 6) {
  my $a = $i * 360 / 7 + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
  for my $k (0 .. 4) {
    my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.2 - $k * 0.35;
    push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
    $x += $dx * 14; $y += $dy * 14;
  }
  poly('c3', @l, [$x, $y], reverse @r);
}
{
  my @canes = ([-100, 110, 50], [-10, 116, -46], [80, 104, 52], [170, 112, -44], [-150, 76, 40], [30, 80, 36]);
  blade(200, 200, $_->[0], $_->[1], 8, $_->[2], 'c5', 'c4', 0.3) for @canes;
  srand(88);
  for my $c (@canes) {
    for my $k (1 .. 3) {
      my ($px, $py, $pa) = along(200, 200, $c->[0], $c->[1], $c->[2], $k * 0.3);
      my $side = $k % 2 ? 1 : -1;
      my $a = $pa + $side * (60 + rand(30)); my $len = 34 + rand(10);
      # a dried, curled leaf: narrow, twisted heart in straw and brown
      heart($px, $py, $a, $len, 'c3', 'c5', 0.45 + rand(0.2));
    }
  }
  kiwi(232, 176, 30, 20, 14); kiwi(170, 236, -40, 18, 13);    # a couple of shrivelled little fruit
}
write_svg('8-dead.svg', 'Kiwi died from lack of water');
print "wrote 8 files to $OUT\n";

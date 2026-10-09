# Broccoli crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/broccoli.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/broccoli';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#2C5A48', c2 => '#7EA86C', c3 => '#E2E8BE', c4 => '#4E3424', c5 => '#3F7B2B');
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

# A broccoli leaf: a bare petiole, then a long blade with a wavy, scalloped margin (deeper lobes near the base),
# split into a lit and a shaded half, with a thick pale midrib and pale side veins.
sub bleaf {
  my ($x, $y, $ang, $len, $w, $bend, %o) = @_;
  my $L = $o{light} // 'c2'; my $D = $o{dark} // 'c1'; my $R = $o{rib} // 'c3';
  my $t0 = $o{pet} // 0.2; my $N = 28; my $sc = $o{sc} // 4;
  my (@l, @r, @m);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $N) {
    my $t = $i / $N; my ($dx, $dy) = dir($a);
    my $hw;
    if ($t < $t0) { $hw = $w * 0.06; }
    else {
      my $s = ($t - $t0) / (1 - $t0);
      $hw = $w / 2 * (sin(pi * min(0.999, $s ** 0.8))) ** 0.55;
      my $wave = abs(cos(pi * $s * $sc)); $hw *= (1 - ($o{lobe} // 0.24) * (1 - $s * 0.5)) + ($o{lobe} // 0.24) * (1 - $s * 0.5) * $wave ** 0.6;
      $hw = max($hw, $w * 0.06);
    }
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @m, [$px, $py, $dx, $dy, $hw];
    $px += $dx * $len / $N; $py += $dy * $len / $N; $a += $bend / $N;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  my @mm = map { [$_->[0], $_->[1]] } @m;
  poly($leftLit ? $L : $D, @l, reverse @mm);
  poly($leftLit ? $D : $L, @r, reverse @mm);
  return if $o{norib};
  # side veins: pale on both halves, sweeping toward the tip
  my $i0 = int($t0 * $N) + 3;
  for (my $i = $i0; $i < $N - 4; $i += 6) {
    my ($mx, $my, $vx, $vy, $hw) = @{$m[$i]};
    for my $side (-1, 1) {
      my ($sx, $sy) = (-$vy * $side, $vx * $side); my $Lv = $hw * 0.8;
      poly($R, [$mx + $vx * 1.4, $my + $vy * 1.4], [$mx + $sx * $Lv + $vx * $Lv * 0.6, $my + $sy * $Lv + $vy * $Lv * 0.6], [$mx - $vx * 1.4, $my - $vy * 1.4]);
    }
  }
  # thick midrib tapering from the stalk to near the tip
  my $mw = $o{mw} // max(2, $w * 0.07); my (@a, @b);
  for my $i (0 .. $N - 3) { my ($mx, $my, $vx, $vy) = @{$m[$i]}; my $k = $mw * (1 - 0.8 * $i / $N); push @a, [$mx - $vy * $k, $my + $vx * $k]; push @b, [$mx + $vy * $k, $my - $vx * $k]; }
  poly($R, @a, reverse @b);
}

# A floret dome: a dark base, then tightly packed round buds; buds facing the light are pale-tipped, buds on the
# far side sink into shadow. (x,y) centre, r radius, sq vertical squash for front views.
sub dome {
  my ($x, $y, $r, %o) = @_;
  my $sq = $o{sq} // 1; my $bead = $o{bead} // 'c5'; my $hi = $o{hi} // 'c2'; my $sh = $o{shade} // 'c1';
  poly($sh, ell($x + $r * 0.06, $y + $r * 0.06, $r * 1.1, $r * $sq * 1.1, 16));
  poly($bead, ell($x - $r * 0.04, $y - $r * 0.04 * $sq, $r * 0.9, $r * $sq * 0.9, 16));
  my $s = $r * ($o{sp} // 0.36); my @d; my $row = 0;
  for (my $gy = -$r; $gy <= $r + 0.01; $gy += $s * 0.86) {
    for (my $gx = -$r - ($row % 2 ? $s / 2 : 0); $gx <= $r + 0.01; $gx += $s) {
      my $r2 = ($gx / $r) ** 2 + ($gy / $r) ** 2; next if $r2 > 0.86;
      push @d, [$gx, $gy, sqrt(1 - $r2)];
    }
    $row++;
  }
  for (sort { $a->[2] <=> $b->[2] } @d) {
    my ($gx, $gy, $z) = @$_;
    my $rd = $s * 0.6 * (0.7 + 0.3 * $z);
    my $l = ($gx * -0.7071 + $gy * -0.7071) / $r;
    $rd *= 0.88 if $l < -0.3;
    my ($bx, $by) = ($x + $gx, $y + $gy * $sq);
    my $c = ($l > 0.32 && !$o{nohi}) ? $hi : $bead;
    poly($l < -0.45 ? $sh : $c, ell($bx, $by, $rd, $rd * ($sq < 1 ? 0.9 : 1), 7, $gx * 3));
    next if $l < -0.1 || $o{nohi} || $l > 0.32;
    my $h = $rd * 0.42;
    poly($hi, ell($bx - $rd * 0.3, $by - $rd * 0.3, $h, $h * 0.8, 6, -45));
  }
}

# A whole broccoli head from above: a ring of florets around a high central floret.
sub head_top {
  my ($R, %o) = @_;
  my @f;
  my $n2 = $o{n2} // 12; my $n1 = $o{n1} // 6;
  for my $i (0 .. $n2 - 1) { my ($u, $v) = dir($i * 360 / $n2 + 15); push @f, [200 + $u * $R * 0.86, 200 + $v * $R * 0.86, $R * ($n2 > 9 ? 0.25 : 0.34)]; }
  for my $i (0 .. $n1 - 1) { my ($u, $v) = dir($i * 360 / $n1); push @f, [200 + $u * $R * 0.56, 200 + $v * $R * 0.56, $R * 0.31]; }
  push @f, [200 - $R * 0.02, 200 - $R * 0.02, $R * 0.31];
  poly($o{shade} // 'c1', ell(201, 201, $R * 1.04, $R * 1.04, 20));
  dome(@$_, %o) for @f;
}

# A tiny round brassica seed with a lit highlight.
sub seed {
  my ($x, $y, $r) = @_;
  poly('c4', ell($x, $y, $r, $r, 10));
  poly('c5', ell($x + $r * 0.12, $y + $r * 0.12, $r * 0.72, $r * 0.72, 10)) if 0;
  poly('c3', ell($x - $r * 0.35, $y - $r * 0.35, $r * 0.32, $r * 0.24, 6, -45));
}

# A heart-shaped notched seed leaf (cotyledon) on a short stalk.
sub coty {
  my ($x, $y, $ang, $len) = @_;
  blade($x, $y, $ang, $len * 0.45, 4, 0, 'c2', 'c1', 0.7);
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my ($cx, $cy) = ($x + $dx * $len * 0.45, $y + $dy * $len * 0.45);
  my $P = sub { my ($u, $v) = @_; [$cx + $dx * $u * $len + $nx * $v * $len, $cy + $dy * $u * $len + $ny * $v * $len] };
  my @half = ([-0.02, 0], [0.02, 0.16], [0.12, 0.3], [0.28, 0.38], [0.44, 0.36], [0.56, 0.26], [0.6, 0.12], [0.55, 0.04], [0.5, 0]);
  my $leftLit = lit($nx, $ny);
  poly($leftLit ? 'c2' : 'c1', map { $P->(@$_) } @half);
  poly($leftLit ? 'c1' : 'c2', map { $P->($_->[0], -$_->[1]) } @half);
}

# Leaf rosette from the centre: [angle, length, width, bend], drawn longest first.
sub rosette { bleaf(200, 200, @$_[0 .. 3], %{$_->[4] // {}}) for sort { $b->[1] <=> $a->[1] } @_; }

# 1. Seeds, front view: tiny round blue-black seeds scattered in a low, wide drift (no heap).
srand(5);
{
  my @h; my $tries = 0;
  while (@h < 30 && $tries++ < 4000) {
    my ($u, $v) = (rand(2) - 1, rand(2) - 1); next if $u * $u + $v * $v > 1;
    my ($x, $y) = (200 + $u * 150, 270 + $v * 34 * (1 - 0.4 * abs($u))); my $r = 8.5 + rand(2.5);
    next if grep { ($_->[0] - $x) ** 2 + ($_->[1] - $y) ** 2 < (($_->[2] + $r) * 1.25) ** 2 } @h;
    push @h, [$x, $y, $r];
  }
  for (sort { $a->[1] <=> $b->[1] } @h) {
    my ($x, $y, $r) = @$_;
    poly(rand(1) < 0.75 ? 'c1' : 'c4', ell($x, $y, $r, $r * 0.94, 10));
    poly('c3', ell($x - $r * 0.35, $y - $r * 0.35, $r * 0.3, $r * 0.22, 6, -45));
  }
}
write_svg('1-seeds-front.svg', 'Broccoli seeds');

# 2. Just sown, top down: little round seeds pressed into small soil pockets.
my @sown = ([168, 170], [236, 166], [202, 216], [156, 240], [248, 238]);
for (@sown) { soil($_->[0], $_->[1], 25, 21, int($_->[0] * 7 + $_->[1])); }
srand(22);
for (@sown) { my ($x, $y) = @$_; seed($x - 7, $y - 3, 7); seed($x + 7, $y - 1, 7); seed($x, $y + 8, 7); }
write_svg('2-sown.svg', 'Broccoli just sown');

# 3. First growth, top down: two notched seed leaves and the first wavy true leaves.
soil(200, 200, 32, 28, 3);
coty(200, 200, 165, 56); coty(200, 200, -15, 52);
rosette([-95, 82, 46, 14, { sc => 3 }], [55, 78, 44, -12, { sc => 3 }]);
write_svg('3-first-growth.svg', 'Broccoli first growth');

# 4. Second growth, top down: a rosette of long blue-green lobed leaves with pale midribs.
soil(200, 200, 34, 30, 4);
rosette(map { [-90 + $_ * 60 + ($_ % 2 ? 10 : -6), 112 + ($_ % 3) * 6, 62, ($_ % 2 ? 14 : -14)] } 0 .. 5);
rosette([-60, 70, 40, 10], [60, 72, 40, -8], [180, 68, 38, 10]);
write_svg('4-second-growth.svg', 'Broccoli second growth');

# 5. Third growth, top down: a big rosette with a small tight green head forming in the heart.
soil(200, 200, 34, 30, 5);
rosette(map { [-80 + $_ * 45 + ($_ % 2 ? 8 : -6), 140 + ($_ % 3) * 6, 70, ($_ % 2 ? 16 : -16)] } 0 .. 7);
rosette(map { [-60 + $_ * 72, 86, 50, ($_ % 2 ? 10 : -10)] } 0 .. 4);
head_top(30, n2 => 7, n1 => 0, sp => 0.42);
write_svg('5-third-growth.svg', 'Broccoli third growth');

# 6. Harvest, top down: the large rosette cradling a big dense dome of dark green florets.
soil(200, 200, 34, 30, 6);
rosette(map { [-84 + $_ * 40 + ($_ % 2 ? 8 : -6), 162 + ($_ % 3) * 7, 76, ($_ % 2 ? 16 : -16)] } 0 .. 8);
rosette(map { [-50 + $_ * 72, 100, 58, ($_ % 2 ? 12 : -12)] } 0 .. 4);
head_top(70);
write_svg('6-harvest.svg', 'Broccoli ready to harvest');

# 7. Harvested produce, front view: a broccoli head - a cloud of floret domes on a thick pale branching stalk.
{
  my ($sx, $sy) = (200, 330);
  # the branches spreading up from the stalk into each floret
  my @fl = ([118, 196, 44], [282, 196, 44], [156, 150, 48], [244, 150, 48], [200, 128, 52], [200, 196, 50], [146, 214, 38], [254, 214, 38]);
  for (@fl) {
    my ($fx, $fy) = @$_; my $a = rad2deg(atan2($fy - 262, $fx - $sx)); my $l = sqrt(($fx - $sx) ** 2 + ($fy - 262) ** 2);
    blade($sx + ($fx - $sx) * 0.1, 262, $a, $l * 0.9, 18, 0, 'c3', 'c2', 0.5);
  }
  # main stalk, lit on the left, with a cut end and two small leaf scars
  poly('c3', [$sx - 32, 250], [$sx, 250], [$sx, $sy + 5], [$sx - 27, $sy]);
  poly('c2', [$sx, 250], [$sx + 32, 250], [$sx + 27, $sy], [$sx, $sy + 5]);
  poly('c2', ell($sx, $sy + 1, 27, 8, 14)); poly('c3', ell($sx - 1, $sy, 22, 6, 14));
  poly('c2', [$sx - 24, 290], [$sx - 40, 280], [$sx - 36, 274], [$sx - 22, 282]);
  poly('c1', [$sx + 23, 300], [$sx + 40, 292], [$sx + 37, 286], [$sx + 22, 292]);
    dome(@$_[0, 1], $_->[2], sq => 0.92, sp => 0.3, hi => 'c2') for sort { $a->[1] <=> $b->[1] } @fl;
}
write_svg('7-harvest-front.svg', 'Broccoli head');

# 8. Dead (never watered), top down: cracked dry soil, limp straw leaves lying flat, a shrivelled brown head.
soil(200, 200, 60, 52, 8);
cracks(7, 14, 83);
srand(81);
rosette(map { [-84 + $_ * 52 + rand(14), 96 + rand(30), 30, (rand(1) < 0.5 ? -1 : 1) * (40 + rand(40)), { light => 'c3', dark => 'c3', rib => 'c4', lobe => 0.3, mw => 1.6 }] } 0 .. 6);
head_top(22, n2 => 6, n1 => 0, sp => 0.5, bead => 'c4', hi => 'c3', shade => 'c4');
write_svg('8-dead.svg', 'Broccoli died from lack of water');
print "wrote 8 files to $OUT\n";

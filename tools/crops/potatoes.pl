# Potato crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/potatoes.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Then: perl tools/center.pl crops/potatoes/1-seeds-front.svg crops/potatoes/7-harvest-front.svg
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/potatoes';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#4C8A3C', c2 => '#86C25A', c3 => '#F4E6B4', c4 => '#5A3A22', c5 => '#C68C44');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Walk a bending path; returns list of [x, y, angle] samples (n+1).
sub path {
  my ($x, $y, $ang, $len, $bend, $n) = @_; $n //= 10;
  my @p; my $a = $ang;
  for my $i (0 .. $n) { push @p, [$x, $y, $a]; my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  @p;
}

# Tapered blade/stalk (as in wheat).
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark) = @_;
  my (@mid, @l, @r); my @p = path($x, $y, $ang, $len, $bend, 10);
  for my $i (0 .. 10) {
    my ($px, $py, $a) = @{$p[$i]}; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $i / 10) ** 0.85 + ($i == 10 ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
  }
  my ($dx, $dy) = dir($ang);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# An oval leaflet with a midrib: two halves, lit and shaded. $curl narrows/asymmetric for wilting.
sub leaflet {
  my ($x, $y, $ang, $len, $w, $light, $dark, $bend) = @_; $bend //= 0;
  my @p = path($x, $y, $ang, $len, $bend, 8);
  my (@l, @r, @mid);
  for my $i (0 .. 8) {
    my $t = $i / 8; my ($px, $py, $a) = @{$p[$i]}; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * sin(pi * (0.04 + 0.96 * $t) ** 0.8) ** 0.75;
    $hw = 0 if $i == 8;
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# Pinnate potato leaf: rachis with $pairs leaflet pairs (growing toward the tip) and a terminal leaflet.
sub compound {
  my ($x, $y, $ang, $len, $bend, $pairs, $lsz, $light, $dark, $wilt) = @_; $wilt //= 0;
  my @p = path($x, $y, $ang, $len, $bend, 20);
  blade($x, $y, $ang, $len, max(3, $lsz * 0.16), $bend, $light, $dark);
  my @leaves;
  for my $k (1 .. $pairs) {
    my $t = 0.18 + 0.62 * $k / ($pairs + 0.4);
    my $s = $p[int($t * 20)]; my $sz = $lsz * (0.62 + 0.38 * $k / $pairs);
    for my $side (-1, 1) {
      my $la = $s->[2] + $side * (52 - 8 * $k / $pairs) + $side * $wilt * 0.5;
      push @leaves, [$s->[0], $s->[1], $la, $sz, $sz * (0.62 - $wilt * 0.006), $side * $wilt];
    }
    # tiny interjected leaflets between pairs (potato hallmark)
    if ($k < $pairs && $wilt == 0) {
      my $s2 = $p[int(($t + 0.09) * 20)];
      push @leaves, [$s2->[0], $s2->[1], $s2->[2] + $_ * 70, $sz * 0.34, $sz * 0.22, 0] for (-1, 1);
    }
  }
  my $e = $p[20];
  push @leaves, [$e->[0], $e->[1], $e->[2], $lsz * 1.12, $lsz * (0.64 - $wilt * 0.006), $wilt * 0.6];
  leaflet(@$_[0 .. 4], $light, $dark, $_->[5]) for @leaves;
}

# A potato tuber: irregular oval, golden-tan skin, lit cap, a few dark eyes.
sub potato {
  my ($x, $y, $ang, $len, $w, $seed, $eyes) = @_; $eyes //= 3;
  srand($seed);
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o; my @th;
  for my $i (0 .. 13) {
    my $th = 2 * pi * $i / 14; my $k = 0.92 + rand(0.14);
    my $u = cos($th) * $len / 2 * $k; my $v = sin($th) * $w / 2 * $k;
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly('c5', @o);
  # lit facet: outline points facing the upper-left plus an inner point shifted to the light
  my @idx = grep { my ($ox, $oy) = ($o[$_][0] - $x, $o[$_][1] - $y); ($ox * -0.7071 + $oy * -0.7071) > 0.12 * sqrt($ox * $ox + $oy * $oy) } 0 .. 13;
  if (@idx >= 2) {
    # keep the lit run in outline order, then come back along an inner, light-shifted copy: a crescent facet
    my $st = 0; for my $j (0 .. $#idx) { my $prev = ($idx[$j] - 1) % 14; $st = $j unless grep { $_ == $prev } @idx; }
    my @run = map { $o[$idx[($st + $_) % @idx]] } 0 .. $#idx;
    my ($cx, $cy) = ($x - min($len, $w) * 0.12, $y - min($len, $w) * 0.12);
    my @in = map { [$cx + ($_->[0] - $cx) * 0.55, $cy + ($_->[1] - $cy) * 0.55] } @run[1 .. $#run - 1];
    poly('c3', @run, reverse @in);
  }
  for my $e (1 .. $eyes) {
    my $u = (rand(1.2) - 0.6) * $len / 2; my $v = (rand(1.0) - 0.5) * $w / 2;
    my $ex = $x + $dx * $u + $nx * $v; my $ey = $y + $dy * $u + $ny * $v; my $r = max(1.6, $w * 0.045);
    poly('c4', [$ex - $r * 1.6, $ey], [$ex, $ey - $r * 0.7], [$ex + $r * 1.6, $ey], [$ex, $ey + $r * 0.9]);
  }
}

# Star flower: five cream petals around a golden centre.
sub flower {
  my ($x, $y, $r, $rot) = @_;
  my @o; for my $i (0 .. 9) { my $a = $rot + $i * 36; my $rr = $i % 2 ? $r * 0.42 : $r; my ($dx, $dy) = dir($a); push @o, [$x + $dx * $rr, $y + $dy * $rr]; }
  poly('c3', @o);
  my @c; for my $i (0 .. 9) { my $a = $rot + 18 + $i * 36; my $rr = $i % 2 ? $r * 0.16 : $r * 0.36; my ($dx, $dy) = dir($a); push @c, [$x + $dx * $rr, $y + $dy * $rr]; }
  poly('c5', @c);
}
sub flowers {   # a little truss of 3-4 flowers on short stalks
  my ($x, $y, $r, $seed, $ang) = @_; srand($seed); $ang //= rand(360);
  my @f;
  for my $i (0 .. 3) { my $a = $ang + $i * 90 + rand(30); my ($dx, $dy) = dir($a); my $d = $r * (1.0 + rand(0.5)); push @f, [$x + $dx * $d, $y + $dy * $d, $a, $d]; }
  blade($x, $y, $_->[2], $_->[3], 3.5, 0, 'c2', 'c1') for @f;
  flower($_->[0], $_->[1], $r * (0.95 + rand(0.2)), rand(72)) for @f;
}

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

# Sprout: a stubby pale-green shoot with a tiny curled leaf bud.
sub sprout {
  my ($x, $y, $ang, $len, $w) = @_;
  blade($x, $y, $ang, $len, $w, 14, 'c2', 'c1');
  my @p = path($x, $y, $ang, $len * 0.7, 14 * 0.7, 4); my $s = $p[-1];
  leaflet($s->[0], $s->[1], $s->[2] - 50, $len * 0.42, $len * 0.26, 'c2', 'c1');
}


# Cut seed-potato piece (front): skin with a pale flat cut face and its faint ring; $face = 1 shows the cut face.
sub ring {
  my ($x, $y, $rx, $ry, $k, $cls) = @_;
  my @o = map { my $th = 2 * pi * $_ / 14; [$x + cos($th) * $rx, $y + sin($th) * $ry] } 0 .. 14;
  my @i = map { my $th = 2 * pi * $_ / 14; [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k] } reverse 0 .. 14;
  poly($cls, @o, @i);
}
sub piece {
  my ($x, $y, $rx, $ry, $seed, $face) = @_;
  potato($x, $y, 0, $rx * 2, $ry * 2, $seed, $face ? 1 : 3);
  if ($face) {
    my ($fx, $fy) = ($x + $rx * 0.16, $y + $ry * 0.14);
    my @f = map { my $th = 2 * pi * $_ / 14; [$fx + cos($th) * $rx * 0.72, $fy + sin($th) * $ry * 0.7] } 0 .. 13;
    poly('c3', @f);
    ring($fx, $fy, $rx * 0.5, $ry * 0.48, 0.86, 'c5');
  }
}

# 1. Seeds, front: a small heap of sprouting seed-potato pieces.
sprout(158, 204, -100, 40, 17); sprout(186, 200, -64, 30, 15);
sprout(262, 240, -78, 34, 16);
piece(252, 272, 54, 40, 12, 1);
sprout(118, 262, -140, 30, 15);
piece(164, 230, 56, 42, 11, 0);
piece(176, 300, 66, 44, 15, 0); sprout(150, 296, -120, 26, 14);
write_svg('1-seeds-front.svg', 'Seed potatoes');

# 2. Just sown, top down: three seed pieces pressed into soil pockets, sprout tips showing.
my @sown = ([170, 166, -25], [246, 198, 60], [178, 246, 150]);
for (@sown) { soil($_->[0], $_->[1], 38, 32, int($_->[0] * 7 + $_->[1])); }
for (@sown) {
  potato($_->[0], $_->[1], $_->[2], 52, 38, int($_->[1]), 2);
  my ($dx, $dy) = dir($_->[2] - 90); sprout($_->[0] + $dx * 4, $_->[1] + $dy * 4, $_->[2] - 120, 20, 9);
}
write_svg('2-sown.svg', 'Potatoes just sown');

# Ring of compound leaves around the crown, longest first.
sub crown {
  my ($n, $len, $var, $pairs, $lsz, $bendMax, $seed, $start, $light, $dark, $wilt) = @_;
  srand($seed); my @b;
  for my $i (0 .. $n - 1) {
    my $a = $start + $i * 360 / $n + rand(16) - 8;
    push @b, [$a, $len + rand($var), (rand(1) < 0.5 ? -1 : 1) * $bendMax * (0.4 + rand(0.6))];
  }
  for my $b (sort { $b->[1] <=> $a->[1] } @b) {
    my ($dx, $dy) = dir($b->[0]);
    compound(200 + $dx * 6, 200 + $dy * 6, $b->[0], $b->[1], $b->[2], $pairs, $lsz * ($b->[1] / $len) ** 0.5, $light, $dark, $wilt);
  }
}

# 3. First growth: a hilled soil mound with a few small young leaves.
soil(200, 200, 40, 36, 3);
crown(5, 44, 10, 1, 28, 16, 31, -80, 'c2', 'c1');
write_svg('3-first-growth.svg', 'Potato first growth');

# 4. Second growth: a bushy young plant with pinnate leaves.
soil(200, 200, 44, 40, 4);
crown(7, 70, 14, 2, 36, 22, 41, -95, 'c2', 'c1');
crown(4, 36, 8, 1, 26, 14, 42, -50, 'c2', 'c1');
write_svg('4-second-growth.svg', 'Potato second growth');

# 5. Third growth: full bush, white star flowers opening.
soil(200, 200, 46, 42, 5);
crown(9, 92, 16, 3, 42, 26, 51, -70, 'c2', 'c1');
crown(6, 50, 12, 2, 32, 18, 52, -40, 'c2', 'c1');
for ([190, 172, 11], [232, 214, 7]) { flowers($_->[0], $_->[1], 16, $_->[2] * 13); }
write_svg('5-third-growth.svg', 'Potato third growth with flowers');

# 6. Harvest: lush plant over loosened soil, golden potatoes peeking out from under the leaves.
soil(200, 200, 118, 112, 64);
crown(11, 104, 14, 3, 46, 24, 61, -90, "c2", "c1");
for my $p ([-30, 124, 70, 50], [58, 128, 62, 44], [140, 122, 72, 50], [218, 128, 60, 44], [296, 124, 58, 42]) {
  my ($sx, $sy) = dir($p->[0]); soil(200 + $sx * $p->[1], 200 + $sy * $p->[1], $p->[2] * 0.62, $p->[3] * 0.8, int($p->[0] + 900));
  my ($dx, $dy) = dir($p->[0]); my ($px, $py) = (200 + $dx * $p->[1], 200 + $dy * $p->[1]);
  potato($px, $py, $p->[0] + 90, $p->[2], $p->[3], int($p->[0] + 500), 3);
}
crown(7, 62, 12, 2, 36, 18, 62, -60, 'c2', 'c1');
for ([186, 170, 21], [236, 206, 23], [176, 232, 25]) { flowers($_->[0], $_->[1], 16, $_->[2] * 7); }
write_svg('6-harvest.svg', 'Potatoes ready to harvest');

# Crescent along the outline run facing ($lx,$ly), returning along an inner copy pulled toward ($cx,$cy) by $k.
sub crescent {
  my ($cls, $o, $x, $y, $lx, $ly, $thr, $cx, $cy, $k) = @_;
  my $n = @$o;
  my @idx = grep { my ($ox, $oy) = ($o->[$_][0] - $x, $o->[$_][1] - $y); ($ox * $lx + $oy * $ly) > $thr * sqrt($ox * $ox + $oy * $oy) } 0 .. $n - 1;
  return if @idx < 3;
  my $st = 0; for my $j (0 .. $#idx) { my $prev = ($idx[$j] - 1) % $n; $st = $j unless grep { $_ == $prev } @idx; }
  my @run = map { $o->[$idx[($st + $_) % @idx]] } 0 .. $#idx;
  my @in = map { [$cx + ($_->[0] - $cx) * $k, $cy + ($_->[1] - $cy) * $k] } @run[1 .. $#run - 1];
  poly($cls, @run, reverse @in);
}

# Lumpy front-view potato for the produce pile: bumpy outline, thin lit sliver, dark shaded side, dimpled eyes.
sub spud {
  my ($x, $y, $ang, $len, $w, $seed, $eyes) = @_;
  srand($seed);
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my ($p1, $p2, $p3) = (rand(6.28), rand(6.28), rand(6.28));
  my @o;
  for my $i (0 .. 27) {
    my $th = 2 * pi * $i / 28;
    my $k = 1 + 0.06 * sin(3 * $th + $p1) + 0.04 * sin(5 * $th + $p2) + 0.03 * sin(2 * $th + $p3);
    my $u = cos($th) * $len / 2 * $k; my $v = sin($th) * $w / 2 * $k;
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly('c5', @o);
  my $m = min($len, $w);
  crescent('c4', \@o, $x, $y, 0.6, 0.8, 0.3, $x - $m * 0.3, $y - $m * 0.4, 0.9);   # shaded lower-right side
  crescent('c3', \@o, $x, $y, -0.6, -0.8, 0.55, $x + $m * 0.2, $y + $m * 0.3, 0.9);  # thin lit sliver
  for my $e (1 .. $eyes) {
    my $u = (rand(1.1) - 0.55) * $len / 2; my $v = (rand(0.8) - 0.5) * $w / 2;
    my $ex = $x + $dx * $u + $nx * $v; my $ey = $y + $dy * $u + $ny * $v; my $r = $m * 0.05;
    poly('c3', [$ex - $r * 1.7, $ey + $r * 0.1], [$ex - $r * 0.2, $ey - $r * 1.1], [$ex + $r * 1.5, $ey - $r * 0.3], [$ex, $ey - $r * 0.3]);
    poly('c4', [$ex - $r * 1.4, $ey + $r * 0.2], [$ex, $ey - $r * 0.4], [$ex + $r * 1.4, $ey + $r * 0.1], [$ex, $ey + $r * 0.8]);
  }
}

# 7. Harvest, front: the produce itself, a small stacked pile of potatoes (no plant, no soil).
spud(158, 216, -18, 112, 80, 101, 3); spud(258, 210, 14, 118, 84, 102, 3);
sprout(244, 176, -72, 26, 11);
spud(112, 282, 8, 120, 86, 103, 3); spud(292, 280, -10, 116, 82, 104, 3); spud(206, 292, 2, 128, 90, 105, 4);
spud(232, 350, -8, 74, 54, 106, 2);
write_svg('7-harvest-front.svg', 'Potato harvest');

# 8. Dead (never watered): cracked dry soil, withered straw leaves collapsed flat.
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
crown(8, 80, 22, 2, 36, 70, 81, -70, 'c3', 'c5', 30);
for ([-20, 22], [110, 18], [220, 20]) { blade(200, 200, $_->[0], $_->[1], 9, 0, 'c3', 'c5'); }
write_svg('8-dead.svg', 'Potato died from lack of water');
print "wrote 8 files to $OUT\n";

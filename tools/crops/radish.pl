# Radish crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/radish.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/radish';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#3A7434', c2 => '#86BD50', c3 => '#F7F1E6', c4 => '#4E3224', c5 => '#EC3B69');
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

# A rounded lobe (leaf segment) from (x,y) heading `ang`, split into a lit and a shaded half, slightly toothed.
sub lobe {
  my ($x, $y, $ang, $len, $w, $bend, $L, $D, %o) = @_;
  my $N = 12; my (@l, @r, @m);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $N) {
    my $t = $i / $N; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (sin(pi * min(0.999, $t ** ($o{p} // 0.75)))) ** ($o{q} // 0.5);
    $hw *= 0.9 if $i % 2 && $i > 1 && $i < $N;
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @m, [$px, $py];
    $px += $dx * $len / $N; $py += $dy * $len / $N; $a += $bend / $N;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $L : $D, @l, reverse @m);
  poly($leftLit ? $D : $L, @r, reverse @m);
}

# A rough lyre-shaped radish leaf: a stalk with pairs of small rounded side lobes that grow larger toward the big,
# rounded terminal lobe. `pairs` = number of side-lobe pairs.
sub rleaf {
  my ($x, $y, $ang, $len, $bend, %o) = @_;
  my $L = $o{light} // 'c2'; my $D = $o{dark} // 'c1'; my $pairs = $o{pairs} // 3; my $wk = $o{wk} // 1;
  my @p = path($x, $y, $ang, $len * 0.62, $bend * 0.62);
  blade($x, $y, $ang, $len * 0.66, max(2.4, $len * 0.05), $bend * 0.66, $o{sl} // $L, $o{sd} // $D, 0.5);
  for my $k (reverse 1 .. $pairs) {
    my $f = 0.3 + 0.55 * $k / ($pairs + 0.5); my ($px, $py, $pa) = @{$p[int($f * 10 + 0.5)]};
    my $sz = $len * (0.16 + 0.1 * $k / $pairs);
    for my $side (-1, 1) { lobe($px, $py, $pa + $side * 62, $sz, $sz * 0.78 * $wk, $side * -10, $L, $D); }
  }
  my ($tx, $ty, $ta) = @{$p[10]};
  my ($dx, $dy) = dir($ta);
  lobe($tx - $dx * $len * 0.06, $ty - $dy * $len * 0.06, $ta, $len * 0.44, $len * 0.36 * $wk, $bend * 0.3, $L, $D, p => 0.7, q => 0.45);
  # pale midrib through the terminal lobe
  blade($tx - $dx * $len * 0.06, $ty - $dy * $len * 0.06, $ta, $len * 0.32, 2.4, $bend * 0.2, $o{rib} // $L, $o{rib} // $L, 0.2) unless $o{norib};
}

# The red radish shoulder seen from above, pushing out of the soil: soil ring, red dome, white-pink highlight,
# shaded side, leaf stalk bases rising from its crown.
sub shoulder {
  my ($x, $y, $r, %o) = @_;
  my $body = $o{body} // 'c5'; my $shade = $o{shade} // 'c4'; my $hi = $o{hi} // 'c3';
  poly('c4', ell($x + 1, $y + 2, $r * 1.16, $r * 1.12, 12, 15)) unless $o{nosoil};
  if (defined $o{tail}) {                       # the white lower end of the root, bared beside the shoulder
    my ($dx, $dy) = dir($o{tail}); my ($nx, $ny) = (-$dy, $dx);
    my $P = sub { my ($u, $v) = @_; [$x + $dx * $u * $r + $nx * $v * $r, $y + $dy * $u * $r + $ny * $v * $r] };
    blade(@{$P->(1.7, 0)}, $o{tail} + 12, $r * 1.5, 3.4, 18, 'c3', 'c3', 0);
    poly('c3', $P->(0, 0.8), $P->(1.15, 0.42), $P->(1.8, 0), $P->(1.15, -0.42), $P->(0, -0.8));
    poly('c4', $P->(0.9, -0.44), $P->(1.16, -0.38), $P->(1.8, 0), $P->(1.24, -0.12));
  }
  poly($body, ell($x, $y, $r, $r, 18));
  my (@out, @in);
  for my $k (0 .. 10) {
    my $th = -40 + 170 * $k / 10; my ($u, $v) = dir($th);
    push @out, [$x + $u * $r, $y + $v * $r]; my $d = 1 - 0.28 * sin(pi * $k / 10);
    unshift @in, [$x + $u * $r * $d, $y + $v * $r * $d];
  }
  poly($shade, @out, @in);
  unless ($o{nohi}) {
    my ($hx, $hy) = ($x - $r * 0.42, $y - $r * 0.42); my $h = $r * 0.3;
    poly($hi, [$hx - $h, $hy + $h * 0.4], [$hx - $h * 0.3, $hy - $h * 0.7], [$hx + $h * 0.8, $hy - $h * 0.5], [$hx, $hy + $h * 0.2]);
  }
  return if $o{nostalks};
  my ($cx, $cy) = ($x - $r * 0.1, $y - $r * 0.1);       # a tuft of broad leaf-stalk bases rising from the crown
  for my $a (@{$o{stalks} // [-60, 30, 120, 210]}) { lobe($cx, $cy, $a, $r * 0.62, $r * 0.34, 0, 'c2', 'c1'); }
  poly('c1', ell($cx, $cy, $r * 0.12, $r * 0.12, 8));
}

# One radish plant top down: a rosette of lyre leaves, then its shoulder (if any) on top.
sub plant {
  my ($x, $y, $n, $len, $sh, $seed, %o) = @_;
  srand($seed); my @lv;
  my $st = $o{start} // rand(360);
  for my $i (0 .. $n - 1) { push @lv, [$st + $i * 360 / $n + rand(16) - 8, $len * (0.85 + rand(0.25)), (rand(1) < 0.5 ? -1 : 1) * (8 + rand(14))]; }
  my @stalks = map { $_->[0] } @lv;
  rleaf($x, $y, @$_[0 .. 2], %o) for sort { $b->[1] <=> $a->[1] } @lv;
  shoulder($x, $y, $sh, stalks => [@stalks], %o) if $sh;
}

# A radish seed: a slightly irregular round seed with a lit highlight.
sub seed {
  my ($x, $y, $r, $rot) = @_;
  poly('c4', map { my ($u, $v) = dir($_ * 36 + $rot); my $k = $_ % 3 ? 1 : 0.9; [$x + $u * $r * $k * 1.1, $y + $v * $r * $k] } 0 .. 9);
  my (@o, @i); for my $k (0 .. 8) { my ($u, $v) = dir(150 + $k * 18); push @o, [$x + $u * $r * 0.96, $y + $v * $r * 0.9]; my $d = 1 - 0.42 * sin(pi * $k / 8); unshift @i, [$x + $u * $r * 0.96 * $d + $r * 0.08, $y + $v * $r * 0.9 * $d + $r * 0.08]; }
  poly('c5', @o, @i);                                   # reddish lit rim toward the light
  poly('c3', ell($x - $r * 0.5, $y - $r * 0.44, $r * 0.18, $r * 0.12, 6, -45));
}

# A heart-shaped notched seed leaf on a short stalk (radish cotyledons are broad and deeply notched).
sub coty {
  my ($x, $y, $ang, $len) = @_;
  blade($x, $y, $ang, $len * 0.42, 3.6, 0, 'c2', 'c1', 0.7);
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my ($cx, $cy) = ($x + $dx * $len * 0.4, $y + $dy * $len * 0.4);
  my $P = sub { my ($u, $v) = @_; [$cx + $dx * $u * $len + $nx * $v * $len, $cy + $dy * $u * $len + $ny * $v * $len] };
  my @half = ([-0.02, 0], [0.02, 0.18], [0.14, 0.34], [0.32, 0.42], [0.5, 0.38], [0.62, 0.24], [0.62, 0.1], [0.5, 0]);
  my $leftLit = lit($nx, $ny);
  poly($leftLit ? 'c2' : 'c1', map { $P->(@$_) } @half);
  poly($leftLit ? 'c1' : 'c2', map { $P->($_->[0], -$_->[1]) } @half);
}

# A whole radish seen from the front, hanging with its tail toward `ang`: red globe that turns white toward the
# tapering tip, a thin white root tail, a lit highlight and shaded side.
sub radish {
  my ($x, $y, $r, $ang) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $P = sub { my ($u, $v) = @_; [$x + $dx * $u * $r + $nx * $v * $r, $y + $dy * $u * $r + $ny * $v * $r] };
  # root tail
  blade(@{$P->(1.25, 0)}, $ang + 6, $r * 1.6, 3.4, 14, 'c3', 'c3', 0);
  # white tip: a cone below the globe
  poly('c3', $P->(0.2, 0.86), $P->(0.95, 0.42), $P->(1.4, 0.06), $P->(1.4, -0.06), $P->(0.95, -0.42), $P->(0.2, -0.86));
  # red globe (outline flattened on the tip side so the white shows as a tapering end)
  my @g = map { my $th = $_ * 20; my ($c, $s) = dir($th); my $k = $c > 0 ? 1 - 0.18 * $c ** 2 : 1; $P->($c * $k, $s * $k) } 0 .. 17;
  poly('c5', @g);
  # shaded crescent on the lower right of the globe
  my (@out, @in);
  for my $k (0 .. 10) { my $th = $ang - 150 + 120 * $k / 10; my ($u, $v) = dir($th); push @out, [$x + $u * $r * 0.98, $y + $v * $r * 0.98]; my $d = 1 - 0.26 * sin(pi * $k / 10); unshift @in, [$x + $u * $r * 0.98 * $d, $y + $v * $r * 0.98 * $d]; }
  poly('c4', @out, @in);
  # glossy highlight
  my ($hx, $hy) = ($x - $r * 0.42, $y - $r * 0.4); my $h = $r * 0.28;
  poly('c3', [$hx - $h, $hy + $h * 0.5], [$hx - $h * 0.3, $hy - $h * 0.7], [$hx + $h * 0.9, $hy - $h * 0.6], [$hx + $h * 0.1, $hy + $h * 0.2]);
  # leaf-stalk base on the crown
  my $c = $P->(-0.92, 0); poly('c1', ell(@$c, $r * 0.22, $r * 0.12, 8, $ang + 90));
}

my @PL = ([164, 174], [240, 170], [202, 238]);   # three plants in the tile

# 1. Seeds, front view: a dry straw-coloured radish seed pod split open, its larger reddish-brown seeds
# spilling out in an arc below it.
{
  my ($x0, $y0, $ang, $len, $w) = (110, 150, 24, 190, 34);
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $P = sub { my ($t, $s) = @_; [$x0 + $dx * $len * $t + $nx * $s, $y0 + $dy * $len * $t + $ny * $s] };
  my $hw = sub { my $t = shift; $w / 2 * (sin(pi * min(1, max(0, ($t - 0.04) / 0.8)))) ** 0.5 };
  blade(@{$P->(0, 0)}, $ang + 180, 26, 5, 10, 'c3', 'c4', 0.5);                      # stalk end
  my (@top, @bot); for my $i (0 .. 20) { my $t = $i / 20 * 0.86; push @top, $P->($t, -$hw->($t)); push @bot, $P->($t, $hw->($t)); }
  poly('c3', @bot, $P->(1, 0), reverse @top);                                         # straw pod
  poly('c4', (map { my $t = $_ / 20 * 0.86; $P->($t, $hw->($t) * 0.78) } 0 .. 20), $P->(1, 0), $P->(0.86, $w * 0.22));   # shaded lower edge
  poly('c3', (map { my $t = $_ / 20 * 0.86; $P->($t, $hw->($t) * 0.9) } 0 .. 20), $P->(1, 0), $P->(0.86, $w * 0.3)) if 0;
  poly('c4', (map { my $t = 0.1 + $_ / 20 * 0.7; $P->($t, -$hw->($t) * 0.45) } 0 .. 20), (map { my $t = 0.8 - $_ / 20 * 0.7; $P->($t, $hw->($t) * 0.3) } 0 .. 20));   # the split seam, open
  for my $t (0.2, 0.36, 0.52, 0.68) { seed(@{$P->($t, 2)}, 11, $t * 99); }            # seeds still in the pod
  my @arc = ([150, 262, 16], [190, 286, 18], [234, 296, 17], [278, 290, 18], [316, 270, 16], [212, 252, 15], [258, 252, 16]);
  seed(@$_[0, 1], $_->[2], $_->[0]) for sort { $a->[1] <=> $b->[1] } @arc;
}
write_svg('1-seeds-front.svg', 'Radish seeds and pod');

# 2. Just sown, top down: seeds pressed into three small soil pockets.
for (@PL) { soil($_->[0], $_->[1], 28, 24, int($_->[0] * 7 + $_->[1])); }
srand(22);
for (@PL) { my ($x, $y) = @$_; seed($x - 8, $y - 4, 7.5, rand(36)); seed($x + 8, $y - 2, 7.5, rand(36)); seed($x, $y + 8, 7.5, rand(36)); }
write_svg('2-sown.svg', 'Radishes just sown');

# 3. First growth, top down: three seedlings, each with two heart-shaped seed leaves and a first rough leaf.
for (@PL) { soil($_->[0], $_->[1], 22, 19, int($_->[0] * 3 + $_->[1])); }
srand(31);
for (@PL) {
  my ($x, $y) = @$_; my $a = rand(180);
  rleaf($x, $y, $a + 90, 40, 10, pairs => 1, norib => 1);
  coty($x, $y, $a, 34); coty($x, $y, $a + 180, 32);
}
write_svg('3-first-growth.svg', 'Radish first growth');

# 4. Second growth, top down: three small rosettes of rough lyre-shaped leaves.
for (@PL) { soil($_->[0], $_->[1], 22, 19, int($_->[0] * 3 + $_->[1] + 4)); }
plant(@{$PL[0]}, 5, 78, 0, 41, pairs => 2);
plant(@{$PL[1]}, 5, 76, 0, 42, pairs => 2);
plant(@{$PL[2]}, 5, 78, 0, 43, pairs => 2);
write_svg('4-second-growth.svg', 'Radish second growth');

# 5. Third growth, top down: fuller rosettes, small pink shoulders just showing at the crowns.
for (@PL) { soil($_->[0], $_->[1], 24, 21, int($_->[0] * 3 + $_->[1] + 5)); }
plant(@{$PL[0]}, 6, 102, 0, 51);
plant(@{$PL[1]}, 6, 100, 0, 52);
plant(@{$PL[2]}, 6, 102, 0, 53);
for my $i (0 .. 2) { shoulder(@{$PL[$i]}, 13, stalks => [map { -150 + $i * 70 + $_ * 40 } 0 .. 3]); }
write_svg('5-third-growth.svg', 'Radish third growth');

# 6. Harvest, top down: lush rosettes around fat bright red radish shoulders pushing out of the soil.
for (@PL) { soil($_->[0], $_->[1], 28, 24, int($_->[0] * 3 + $_->[1] + 6)); }
plant(@{$PL[0]}, 6, 132, 0, 61);
plant(@{$PL[1]}, 6, 128, 0, 62);
plant(@{$PL[2]}, 6, 132, 0, 63);
my @tails = (200, -20, 95);
for my $i (0 .. 2) { shoulder(@{$PL[$i]}, 30, tail => $tails[$i], stalks => [map { $tails[$i] + 110 + $_ * 35 } 0 .. 4]); }
write_svg('6-harvest.svg', 'Radishes ready to harvest');

# 7. Harvested produce, front view: a bunch of four radishes tied together under their leaves.
{
  my ($bx, $by) = (200, 196);
  rleaf($bx - 6, $by, -122, 150, 16, pairs => 3);
  rleaf($bx + 6, $by, -58, 150, -16, pairs => 3);
  rleaf($bx, $by, -90, 164, 6, pairs => 3);
  rleaf($bx - 4, $by, -150, 110, 20, pairs => 2);
  rleaf($bx + 4, $by, -30, 110, -20, pairs => 2);
  my @R = ([132, 278, 32, 118], [268, 276, 32, 62], [180, 304, 35, 100], [224, 306, 35, 80]);
  for (@R) { my ($x, $y) = @$_; my $a = rad2deg(atan2($y - 34 - $by, $x - $bx)); my $l = sqrt(($x - $bx) ** 2 + ($y - 34 - $by) ** 2); blade($bx, $by, $a, $l, 6, 0, 'c2', 'c1', 0.7); }
  radish(@$_) for @R;
  poly('c4', [$bx - 16, $by - 6], [$bx + 16, $by - 8], [$bx + 17, $by + 8], [$bx - 17, $by + 9]);
  poly('c5', [$bx - 16, $by - 6], [$bx + 16, $by - 8], [$bx + 16, $by - 2], [$bx - 16, $by]);
}
write_svg('7-harvest-front.svg', 'Bunch of radishes');

# 8. Dead (never watered), top down: cracked dry soil, limp yellowed leaves lying flat, shrivelled shoulders.
soil(200, 200, 66, 58, 8);
cracks(7, 15, 83);
srand(81);
for my $i (0 .. 2) {
  my ($x, $y) = @{$PL[$i]};
  for my $k (0 .. 3) { rleaf($x, $y, $k * 90 + $i * 25 + rand(20), 70 + rand(18), (rand(1) < 0.5 ? -1 : 1) * (20 + rand(25)), light => 'c3', dark => 'c3', rib => 'c4', sl => 'c4', sd => 'c4', wk => 0.85, pairs => 2); }
  shoulder($x, $y, 11, body => 'c4', shade => 'c4', hi => 'c3', nostalks => 1, nosoil => 1);
  for my $w (-30, 40, 120) { my ($u, $v) = dir($w); poly('c3', [$x, $y], [$x + $u * 9 - $v * 1.2, $y + $v * 9 + $u * 1.2], [$x + $u * 9 + $v * 1.2, $y + $v * 9 - $u * 1.2]); }
}
write_svg('8-dead.svg', 'Radishes died from lack of water');
print "wrote 8 files to $OUT\n";

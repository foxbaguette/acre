# Peanut crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/peanuts.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Then: perl tools/center.pl crops/peanuts/1-seeds-front.svg crops/peanuts/7-harvest-front.svg
# Signatures: leaves of four rounded leaflets (two pairs), small golden pea flowers, pegs diving into the soil,
# and the waisted, net-veined two-bump shell with red-skinned kernels inside.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/peanuts';
mkdir 'crops'; mkdir $OUT;
# c1 leaf green, c2 lit green, c3 golden tan (shell, flowers, dry leaves), c4 dark soil / shade, c5 russet (kernel skin, shell grooves)
my %PAL = (c1 => '#4A8A3C', c2 => '#8DC35A', c3 => '#F2CA6C', c4 => '#5A3A22', c5 => '#B0583A');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Walk a bending path; returns list of [x, y, angle] samples (n+1).
sub path {
  my ($x, $y, $ang, $len, $bend, $n) = @_; $n //= 10;
  my @p; my $a = $ang;
  for my $i (0 .. $n) { push @p, [$x, $y, $a]; my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  @p;
}

# Tapered blade/stalk (as in wheat). $taper < 1 leaves a blunt end.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $taper) = @_; $taper //= 1;
  my (@mid, @l, @r); my @p = path($x, $y, $ang, $len, $bend, 10);
  for my $i (0 .. 10) {
    my ($px, $py, $a) = @{$p[$i]}; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $i / 10) ** 0.85 + ($i == 10 && $taper == 1 ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# Rounded obovate leaflet (widest beyond the middle, blunt tip), lit and shaded halves along the midrib.
sub leaflet {
  my ($x, $y, $ang, $len, $w, $light, $dark, $bend) = @_; $bend //= 0;
  my @p = path($x, $y, $ang, $len, $bend, 10);
  my (@l, @r, @mid);
  for my $i (0 .. 10) {
    my $t = $i / 10; my ($px, $py, $a) = @{$p[$i]}; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * sin(pi * $t ** 1.35) ** 0.55;
    $hw = 0 if $i == 10;
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# Peanut leaf: petiole, then two pairs of leaflets (a lower spreading pair and a terminal pair).
# $wilt (0..1) folds the leaflets narrow and droops them; $yel = colours for a yellowing leaf.
sub pleaf {
  my ($x, $y, $ang, $P, $L, $bend, $wilt, $light, $dark) = @_;
  $wilt //= 0; $light //= 'c2'; $dark //= 'c1';
  my ($sl, $sd) = $light eq 'c3' ? ('c3', 'c5') : ('c2', 'c1');
  blade($x, $y, $ang, $P + $L * 0.22, max(2.2, $L * 0.11), $bend, $sl, $sd, 0.6);
  my @p = path($x, $y, $ang, $P + $L * 0.22, $bend, 10);
  my $e1 = $p[int(10 * $P / ($P + $L * 0.22))]; my $e2 = $p[10];
  my $wf = 0.62 * (1 - 0.5 * $wilt);
  for my $s (-1, 1) {
    leaflet($e1->[0], $e1->[1], $e1->[2] + $s * (64 + 20 * $wilt), $L * 0.9, $L * $wf, $light, $dark, $s * 30 * $wilt);
  }
  for my $s (-1, 1) {
    leaflet($e2->[0], $e2->[1], $e2->[2] + $s * (24 + 16 * $wilt), $L, $L * $wf, $light, $dark, $s * 34 * $wilt);
  }
}

our @NODES;   # [x, y, angle, side] of leaf nodes, for flowers and pegs
# A leafy stem: stalk from (x,y) with alternate leaves at nodes and a terminal leaf.
sub branch {
  my ($x, $y, $ang, $len, $bend, $n, $P, $L, $wilt, $seed, $yel) = @_;
  $wilt //= 0; $yel //= 0;
  srand($seed);
  my $dead = $wilt > 0.3;
  my ($sl, $sd) = $dead ? ('c3', 'c5') : ('c2', 'c1');
  blade($x, $y, $ang, $len, 6, $bend, $sl, $sd, 0.55);
  my @p = path($x, $y, $ang, $len, $bend, 20);
  my @leaves;
  for my $k (1 .. $n) {
    my $t = 0.22 + 0.7 * ($k - 1) / max(1, $n);
    my $s = $p[int($t * 20 + 0.5)]; my $side = $k % 2 ? 1 : -1;
    my $sz = 0.82 + 0.18 * $k / $n;
    push @leaves, [$s->[0], $s->[1], $s->[2] + $side * (50 + rand(14)), $P * $sz, $L * $sz, $side * (rand(14) + 6 + 40 * $wilt)];
    push @NODES, [$s->[0], $s->[1], $s->[2], $side];
  }
  my $e = $p[20];
  push @leaves, [$e->[0], $e->[1], $e->[2] + rand(16) - 8, $P * 0.55, $L * 1.04, (rand(1) < 0.5 ? -1 : 1) * (6 + 40 * $wilt)];
  for my $i (0 .. $#leaves) {
    my ($lx, $ly, $la, $lp, $ll, $lb) = @{$leaves[$i]};
    my ($a, $b) = $dead ? ('c3', 'c5') : ($yel && ($i >= $#leaves - 1) && rand(1) < $yel) ? ('c3', 'c2') : ('c2', 'c1');
    pleaf($lx, $ly, $la, $lp, $ll, $lb, $wilt, $a, $b);
  }
}

# A ring of branches around the crown, longest first so short ones sit on top.
sub bush {
  my ($n, $len, $var, $nl, $P, $L, $bendMax, $seed, $start, $wilt, $yel) = @_;
  srand($seed); my @b;
  for my $i (0 .. $n - 1) {
    my $a = $start + $i * 360 / $n + rand(16) - 8;
    push @b, [$a, $len + rand($var), (rand(1) < 0.5 ? -1 : 1) * $bendMax * (0.4 + rand(0.6)), int(rand(1000))];
  }
  for my $b (sort { $b->[1] <=> $a->[1] } @b) {
    my ($dx, $dy) = dir($b->[0]);
    branch(200 + $dx * 4, 200 + $dy * 4, $b->[0], $b->[1], $b->[2], $nl, $P, $L, $wilt, $b->[3], $yel);
  }
}

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

# Thin line segment polygon.
sub seg { my ($cls, $a, $b, $w) = @_; my ($dx, $dy) = ($b->[0] - $a->[0], $b->[1] - $a->[1]); my $l = sqrt($dx * $dx + $dy * $dy) || 1;
  my ($nx, $ny) = (-$dy / $l * $w / 2, $dx / $l * $w / 2);
  poly($cls, [$a->[0] + $nx, $a->[1] + $ny], [$b->[0] + $nx, $b->[1] + $ny], [$b->[0] - $nx, $b->[1] - $ny], [$a->[0] - $nx, $a->[1] - $ny]); }

# Peanut in the shell: waisted two-bump pod with a little beak, net of grooves, lit and shaded sides.
# Returns the local frame so cracked pods can add their insides.
sub shell {
  my ($x, $y, $ang, $len, $w, $seed, $net) = @_; $net //= 1;
  srand($seed);
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $curve = (rand(1) - 0.5) * 0.16 * $len;
  my $n = 22;
  my $prof = sub {          # half width at t, plus the bent midline offset
    my $t = shift;
    my $hw = $w / 2 * sin(pi * $t) ** 0.5 * (1 - 0.3 * exp(-((($t - 0.52) / 0.1) ** 2)));
    $hw *= 1 - 0.18 * max(0, ($t - 0.86) / 0.14);   # the beak end narrows
    my $off = $curve * sin(pi * $t);
    ($hw, $off);
  };
  my $P = sub { my ($t, $v) = @_; my ($hw, $off) = $prof->($t); my $u = ($t - 0.5) * $len;
    [$x + $dx * $u + $nx * ($off + $v * $hw), $y + $dy * $u + $ny * ($off + $v * $hw)] };
  my (@l, @r);
  for my $i (0 .. $n) { my $t = $i / $n; push @l, $P->($t, -1); push @r, $P->($t, 1); }
  my @o = (@l, reverse @r[1 .. $n - 1]);
  poly('c3', @o);
  my $m = min($len, $w);
  if ($net) {
    # lengthwise ridges and cross-links: the reticulated shell
    my $gw = max(1.1, $w * 0.035);
    my @rid = (-0.6, -0.05, 0.5);
    for my $v (@rid) {
      for my $i (1 .. $n - 2) { my ($t0, $t1) = ($i / $n, ($i + 1) / $n);
        next if abs(($t0 + $t1) / 2 - 0.52) < 0.06;
        seg('c5', $P->($t0, $v), $P->($t1, $v), $gw); }
    }
    for my $j (0 .. 1) {
      for my $i (2 .. $n - 3) { next unless ($i + $j) % 2; my $t = $i / $n; next if abs($t - 0.52) < 0.08;
        seg('c5', $P->($t, $rid[$j]), $P->($t + 0.012, $rid[$j + 1]), $gw); }
    }
  }
  crescent('c5', \@o, $x, $y, 0.6, 0.8, 0.05, $x - $m * 0.3, $y - $m * 0.36, 0.78);   # warm shaded side
  crescent('c4', \@o, $x, $y, 0.6, 0.8, 0.45, $x - $m * 0.1, $y - $m * 0.12, 0.93);    # dark rim
  return ($P, \@o);
}

# Red-skinned peanut kernel: plump oval, russet skin with dark shade, a glossy streak and a pale germ tip.
sub kernel {
  my ($x, $y, $ang, $len, $w, $split) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 17) {
    my $th = 2 * pi * $i / 18; my $k = 1 + 0.08 * cos($th);   # fuller at the far end
    my $u = cos($th) * $len / 2 * (cos($th) < 0 ? 0.9 : 1); my $v = sin($th) * $w / 2 * $k * (1 - 0.14 * max(0, -cos($th)) ** 3);
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  my $m = min($len, $w);
  if ($split) {     # half kernel: pale cotyledon face with a skin rim and the little germ
    poly('c5', @o);
    my @f = map { [$x + ($_->[0] - $x) * 0.82 - $m * 0.03, $y + ($_->[1] - $y) * 0.82 - $m * 0.03] } @o;
    poly('c3', @f);
    my ($gx, $gy) = ($x - $dx * $len * 0.3, $y - $dy * $len * 0.3);
    poly('c5', [$gx - $dx * $len * 0.1, $gy - $dy * $len * 0.1], [$gx + $nx * $w * 0.1, $gy + $ny * $w * 0.1],
               [$gx + $dx * $len * 0.14, $gy + $dy * $len * 0.14], [$gx - $nx * $w * 0.1, $gy - $ny * $w * 0.1]);
    return;
  }
  poly('c5', @o);
  crescent('c4', \@o, $x, $y, 0.6, 0.8, 0.2, $x - $m * 0.3, $y - $m * 0.35, 0.86);
  crescent('c3', \@o, $x, $y, -0.6, -0.8, 0.62, $x + $m * 0.25, $y + $m * 0.3, 0.88);
  my ($gx, $gy) = ($x - $dx * $len * 0.42, $y - $dy * $len * 0.42);
  poly('c3', [$gx - $nx * $w * 0.07, $gy - $ny * $w * 0.07], [$gx - $dx * $len * 0.08, $gy - $dy * $len * 0.08],
             [$gx + $nx * $w * 0.07, $gy + $ny * $w * 0.07], [$gx + $dx * $len * 0.06, $gy + $dy * $len * 0.06]);
}

# A peanut cracked open: the lower half-shell lying open with two kernels resting in it.
sub openpod {
  my ($x, $y, $ang, $len, $w, $seed) = @_;
  my ($P, $o) = shell($x, $y, $ang, $len, $w, $seed, 0);
  my (@in, @sh);   # pale inner hollow inset from the rim, with the rim's shadow along its upper wall
  for my $i (1 .. 21) { my $t = $i / 22; push @in, $P->($t, -0.74); }
  for my $i (reverse 1 .. 21) { my $t = $i / 22; push @in, $P->($t, 0.66); }
  poly('c3', @in);
  for my $i (1 .. 21) { my $t = $i / 22; push @sh, $P->($t, -0.74); }
  for my $i (reverse 1 .. 21) { my $t = $i / 22; push @sh, $P->($t, -0.36 + 0.1 * sin(pi * $t)); }
  poly('c4', @sh);
  for my $t (0.29, 0.74) { my $c = $P->($t, 0.0); kernel($c->[0], $c->[1], $ang + ($t < 0.5 ? -4 : 6), $len * 0.38, $w * 0.66); }
}

# Peanut flower from above: a rounded golden banner petal with a russet heart and two small wings.
sub flower {
  my ($x, $y, $r, $rot) = @_;
  my ($dx, $dy) = dir($rot); my ($nx, $ny) = (-$dy, $dx);
  my $Q = sub { my ($u, $v) = @_; [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v] };
  # keel and wings pointing back toward the stalk
  poly('c3', $Q->(-$r * 0.1, -$r * 0.45), $Q->(-$r * 1.15, -$r * 0.12), $Q->(-$r * 1.2, $r * 0.1), $Q->(-$r * 0.1, $r * 0.45));
  poly('c5', $Q->(-$r * 0.3, 0), $Q->(-$r * 1.2, -$r * 0.02), $Q->(-$r * 1.2, $r * 0.1), $Q->(-$r * 0.3, $r * 0.3));
  # broad banner petal, notched at its outer edge
  my @b;
  for my $i (0 .. 15) { my $th = 2 * pi * $i / 16; my $k = 1 - 0.35 * exp(-($th ** 2) / 0.06) - 0.35 * exp(-((2 * pi - $th) ** 2) / 0.06);
    push @b, $Q->(cos($th) * $r * 0.8 * $k, sin($th) * $r * 1.12 * $k); }
  poly('c3', @b);
  crescent('c5', \@b, $x, $y, 0.6, 0.8, 0.45, $x - $r * 0.3, $y - $r * 0.3, 0.82);
  # russet nectar guide: fine veins fanning from the base
  for my $v (-0.5, 0, 0.5) { my $e = $Q->($r * 0.5, $r * $v * 0.9);
    poly('c5', $Q->(-$r * 0.3, -$r * 0.09), $e, $Q->(-$r * 0.3, $r * 0.09)); }
}

# Peg (gynophore): a thin stalk arching from a node down into the soil, ending in a little soil hole.
sub peg {
  my ($x, $y, $ang, $len) = @_;
  my ($ex, $ey) = ($x + cos(deg2rad($ang)) * $len, $y + sin(deg2rad($ang)) * $len);
  poly('c4', map { my $th = 2 * pi * $_ / 8; [$ex + cos($th) * 6.5, $ey + sin($th) * 5] } 0 .. 7);
  blade($x, $y, $ang, $len, 3.6, 10, 'c3', 'c5', 0.4);
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

# 1. Seeds, front: two peanuts in the shell and loose red-skinned kernels in front.
shell(160, 196, -24, 150, 60, 11);
shell(262, 222, 18, 138, 56, 12);
kernel(126, 286, -14, 62, 36); kernel(246, 298, 16, 62, 36); kernel(188, 304, 8, 60, 35);
kernel(306, 280, -40, 56, 33);
write_svg('1-seeds-front.svg', 'Peanut seeds');

# 2. Just sown, top down: kernels pressed into small soil pockets.
my @sown = ([164, 170, -30], [244, 176, 40], [178, 244, 110], [250, 246, -70]);
for (@sown) { soil($_->[0], $_->[1], 28, 24, int($_->[0] * 7 + $_->[1])); }
for (@sown) { kernel($_->[0], $_->[1], $_->[2], 36, 22); }
write_svg('2-sown.svg', 'Peanuts just sown');

# 3. First growth: a seedling with its first four-leaflet leaves around two fleshy seed leaves.
soil(200, 200, 34, 30, 3);
for ([-30, 1], [150, 1]) { my ($dx, $dy) = dir($_->[0]); kernel(200 + $dx * 9, 200 + $dy * 9, $_->[0], 20, 13, 1); }
for ([-125, 38, 36, -12], [-15, 36, 35, 14], [95, 34, 34, -10], [200, 30, 32, 12]) {
  pleaf(200, 200, $_->[0], $_->[1], $_->[2], $_->[3], 0);
}
write_svg('3-first-growth.svg', 'Peanut first growth');

# 4. Second growth: a low bushy young plant.
soil(200, 200, 38, 34, 4);
@NODES = ();
bush(6, 66, 16, 2, 20, 28, 26, 41, -100);
bush(4, 24, 6, 1, 14, 25, 14, 42, -55);
write_svg('4-second-growth.svg', 'Peanut second growth');

# 5. Third growth: full bush with golden pea flowers and pegs diving into the soil.
soil(200, 200, 40, 36, 5);
@NODES = ();
bush(8, 88, 18, 3, 22, 31, 30, 51, -95);
my @n5 = @NODES;
bush(5, 36, 10, 1, 16, 27, 16, 52, -60);
my $fi = 0;
for my $nd (@n5) {
  $fi++;
  my $r = sqrt(($nd->[0] - 200) ** 2 + ($nd->[1] - 200) ** 2);
  if ($fi % 4 == 0 && $r > 60) { peg($nd->[0], $nd->[1], $nd->[2] + $nd->[3] * 75, 30); next; }
  next unless $fi % 2;
  my $fa = $nd->[2] - $nd->[3] * 40; my ($dx, $dy) = dir($fa);
  flower($nd->[0] + $dx * 12, $nd->[1] + $dy * 12, 12, $fa);
}
write_svg('5-third-growth.svg', 'Peanut third growth with flowers');

# 6. Harvest: lush bush going yellow at the edges; the plant is lifted so ripe peanuts show in loose soil around it.
soil(200, 200, 112, 104, 64);
@NODES = ();
bush(10, 100, 16, 3, 24, 32, 30, 61, -90, 0, 0.35);
for my $c ([-54, 1], [18, 2], [90, 3], [162, 4], [234, 5]) {
  my ($a, $s) = @$c; my ($dx, $dy) = dir($a); my $r = 128;
  my ($cx, $cy) = (200 + $dx * $r, 200 + $dy * $r);
  soil($cx, $cy, 42, 36, $s * 31);
  blade($cx - $dx * 50, $cy - $dy * 50, $a - 8, 44, 3.6, 30, 'c3', 'c5', 0.4);
  blade($cx - $dx * 50, $cy - $dy * 50, $a + 10, 46, 3.6, -26, 'c3', 'c5', 0.4);
  shell($cx - $dy * 15 + $dx * 4, $cy + $dx * 15 + $dy * 4, $a + 72, 76, 32, $s * 7);
  shell($cx + $dy * 15 + $dx * 2, $cy - $dx * 15 + $dy * 2, $a - 70, 72, 31, $s * 7 + 3);
}
bush(7, 60, 12, 2, 20, 30, 18, 62, -70);
write_svg('6-harvest.svg', 'Peanuts ready to harvest');

# 7. Harvest, front: a small pile of peanuts in the shell, two cracked open to show the kernels.
shell(146, 206, -16, 132, 54, 71);
shell(256, 196, 22, 128, 52, 72);
shell(200, 160, -4, 124, 50, 73);
openpod(134, 266, 6, 138, 62, 74);
shell(270, 270, -12, 134, 54, 75);
openpod(204, 318, -4, 128, 58, 76);
write_svg('7-harvest-front.svg', 'Peanut harvest');

# 8. Dead (never watered): cracked dry soil, withered leaves collapsed flat.
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
bush(8, 80, 22, 2, 18, 27, 60, 81, -70, 0.6);
for ([-20, 22], [110, 18], [220, 20]) { blade(200, 200, $_->[0], $_->[1], 7, 0, 'c3', 'c5'); }
write_svg('8-dead.svg', 'Peanut plant died from lack of water');
print "wrote 8 files to $OUT\n";

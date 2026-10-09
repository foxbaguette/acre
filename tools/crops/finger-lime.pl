# Finger Lime crop art (thorny citrus bush): 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/finger-lime.pl
# Shared citrus parts live in tools/crops/citrus-common.pl. Top-down stages (2-6, 8) share one fixed scale
# centred on (200,200). Signature: an airy, zig-zag thorny bush with tiny leaves, hung with long slim
# finger-shaped fruit in dark purple-red; split open they spill round pink "caviar" pearls.
use strict; use warnings; use Math::Trig;
our ($OUT, %PAL, @S);
do './tools/crops/citrus-common.pl' or die "citrus-common: $@ $!";
$OUT = 'crops/finger-lime';
# c1 olive leaf green, c2 lit olive, c3 pearl pink (pearls, blossom, gloss, dry leaves), c4 plum-brown soil / shade /
# thorns, c5 deep burgundy finger-lime skin
%PAL = (c1 => '#3C5E2C', c2 => '#7FA244', c3 => "#F6D0CC", c4 => '#4F2D27', c5 => "#8E2A40");

# A finger lime: a long slim cylinder with rounded ends, slightly bent, a shaded side, a gloss streak,
# fine oil-gland dots and a little green calyx at the stalk end. $ripe 0 = green.
sub finger {
  my ($x, $y, $ang, $len, $w, $bend, %o) = @_;
  my $ripe = $o{ripe} // 1;
  my ($body, $shade) = $ripe ? ('c5', 'c4') : ('c2', 'c1');
  my $n = 16; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $e = min(1, (5 * $t * (1 - $t))) ** 0.45 * (1 - 0.1 * $t);
    my $hw = $w / 2 * $e;
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  my ($L, $R) = $leftLit ? (\@l, \@r) : (\@r, \@l);
  if ($o{stem}) { blade($x + $dx * 2, $y + $dy * 2, $ang + 180 + ($o{sb} // 0), $o{stem}, max(2.5, $w * 0.22), 0, 'c2', 'c1', 0.5); }
  poly($body, @l, reverse @r);
  # shaded side: from the dark outline in toward the midline
  poly($shade, @$R, reverse map { [$mid[$_][0] + ($R->[$_][0] - $mid[$_][0]) * 0.35, $mid[$_][1] + ($R->[$_][1] - $mid[$_][1]) * 0.08] } 0 .. $n);
  # gloss streak along the lit side
  my (@ga, @gb);
  for my $i (2 .. int($n * 0.55)) {
    my $u = ($i - 2) / (int($n * 0.55) - 2); my $k = 0.6; my $hw = 0.06 + 0.1 * sin(pi * $u);
    push @ga, [$mid[$i][0] + ($L->[$i][0] - $mid[$i][0]) * ($k - $hw), $mid[$i][1] + ($L->[$i][1] - $mid[$i][1]) * ($k - $hw)];
    push @gb, [$mid[$i][0] + ($L->[$i][0] - $mid[$i][0]) * ($k + $hw), $mid[$i][1] + ($L->[$i][1] - $mid[$i][1]) * ($k + $hw)];
  }
  poly($o{gloss} // 'c3', @ga, reverse @gb) if $w > 7;
  if ($o{dots}) {   # bumpy oil glands
    srand(int($x + $y * 3));
    for (1 .. $o{dots}) {
      my $i = 2 + int(rand($n - 4)); my $k = rand(1.5) - 0.75; my $side = $k < 0 ? $R : $L;
      my ($cx, $cy) = ($mid[$i][0] + ($side->[$i][0] - $mid[$i][0]) * abs($k), $mid[$i][1] + ($side->[$i][1] - $mid[$i][1]) * abs($k));
      my $s = $w * 0.035 + 0.4;
      poly($k < 0 ? 'c5' : 'c4', [$cx - $s, $cy], [$cx, $cy - $s], [$cx + $s, $cy], [$cx, $cy + $s]) if $ripe;
    }
  }
  # calyx stub at the stalk end
  my ($ex, $ey) = dir($ang);
  poly('c1', map { my ($cx, $cy) = dir($ang + 180 + $_ * 45 - 90); [$x + $ex * $w * 0.08 + $cx * $w * 0.26, $y + $ey * $w * 0.08 + $cy * $w * 0.26] } 0 .. 4);
  return (\@mid, $L, $R);
}

# One caviar pearl: a pink bead with a darker crescent and a pale glint.
sub pearl {
  my ($x, $y, $r) = @_;
  my @o = map { my $th = 2 * pi * $_ / 10; [$x + cos($th) * $r, $y + sin($th) * $r] } 0 .. 9;
  poly('c3', @o);
  crescent('c5', $x, $y, 0.7071, 0.7071, 0.25, 0.62, $r * 0.12, @o);
}

# A finger lime split open lengthwise: the rind as a long boat, packed with pearls, some spilling out.
sub split_finger {
  my ($x, $y, $ang, $len, $w, $spill, $seed) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $n = 18; my (@top, @bot, @s1, @s2);
  my $P = sub { my ($u, $v) = @_; [$x + $dx * $len * $u + $nx * $w * $v, $y + $dy * $len * $u + $ny * $w * $v] };
  for my $i (0 .. $n) {
    my $t = $i / $n; my $e = min(1, 4 * $t * (1 - $t)) ** 0.32;
    push @top, $P->($t, -0.5 * $e); push @bot, $P->($t, 0.5 * $e);
  }
  # the slit: a lens along the upper side from 10% to 92% of the length
  for my $i (0 .. $n) {
    my $t = 0.1 + 0.82 * $i / $n; my $o = sin(pi * $i / $n) ** 0.7;
    push @s1, $P->($t, -0.36 * $o - 0.02); push @s2, $P->($t, 0.2 * $o - 0.02);
  }
  poly('c5', @top, reverse @bot);
  poly('c4', @bot[0 .. $n], reverse map { $P->($_ / $n, 0.5 * min(1, 4 * ($_ / $n) * (1 - $_ / $n)) ** 0.32 * 0.45) } 0 .. $n);
  poly('c4', @s1, reverse @s2);
  # rind lip on the lower edge of the slit (lit), gloss on the upper back
  poly('c3', @s2[2 .. $n - 2], reverse map { my $t = 0.1 + 0.82 * $_ / $n; $P->($t, 0.2 * sin(pi * $_ / $n) ** 0.7 + 0.035 * sin(pi * $_ / $n)) } 2 .. $n - 2);
  srand($seed);
  my @p;
  for my $tries (1 .. 400) {
    my $i = 2 + rand($n - 4); my $t = 0.1 + 0.82 * $i / $n; my $o = sin(pi * $i / $n) ** 0.7;
    my $v = -0.36 * $o + rand(0.5 * $o) - 0.06;
    my $r = $w * (0.13 + rand(0.05)) * (0.6 + 0.4 * $o);
    my $c = $P->($t, $v);
    next if grep { (($_->[0] - $c->[0]) ** 2 + ($_->[1] - $c->[1]) ** 2) < ($_->[2] + $r) ** 2 * 0.62 } @p;
    push @p, [@$c, $r];
  }
  push @p, map { [@$_] } @{$spill // []};
  pearl(@$_) for sort { $a->[1] <=> $b->[1] } @p;
}

# A tiny finger-lime leaf: small rounded-diamond, cuneate.
sub tleaf { my ($x, $y, $a, $l, $L, $D) = @_; cleaf($x, $y, $a, $l, $l * 0.55, 0, $L // 'c2', $D // 'c1'); }

# Top-down thorny bush: zig-zag woody branches with side twigs, needle thorns at the nodes, tiny leaves.
# Returns fruit spots [x, y, heading].
sub thornbush {
  my (%o) = @_;
  srand($o{seed});
  my $nb = $o{nb}; my $R = $o{reach}; my $ll = $o{leaf};
  my (@wood, @thorns, @leaves, @spots);
  for my $i (0 .. $nb - 1) {
    my $a = ($o{start} // -90) + $i * 360 / $nb + rand(14) - 7;
    my $segs = $o{segs} // 5; my $sl = $R * ($i % 2 ? 0.98 : 0.8) * (0.92 + rand(0.08)) / $segs;
    my ($x, $y) = (200, 200);
    for my $k (0 .. $segs - 1) {
      my $h = $a + ($k % 2 ? 16 : -16) * ($i % 2 ? 1 : -1);
      push @wood, [$x, $y, $h, $sl * 1.04, max(3, ($o{ww} // 7) * (1 - $k / ($segs + 1)))];
      my ($dx, $dy) = dir($h); $x += $dx * $sl; $y += $dy * $sl;
      my $side = ($k % 2 ? 1 : -1) * ($i % 2 ? 1 : -1);
      # thorn at the node, pointing outward on the side of the bend
      push @thorns, [$x, $y, $h + $side * 52, $sl * 0.5];
      push @thorns, [$x, $y, $h - $side * 70, $sl * 0.3] if $k % 2;
      # side twig
      if ($k >= 1) {
        my $ta = $h - $side * 44; my ($tx, $ty) = dir($ta);
        my $tl = $sl * 0.9;
        push @wood, [$x, $y, $ta, $tl, 3];
        for my $q (0.35, 0.7, 1.0) { my $px = $x + $tx * $tl * $q; my $py = $y + $ty * $tl * $q;
          push @leaves, [$px, $py, $ta + 40 + rand(30), $ll * (0.85 + rand(0.3))], [$px, $py, $ta - 40 - rand(30), $ll * (0.85 + rand(0.3))]; }
        push @leaves, [$x + $tx * $tl, $y + $ty * $tl, $ta + rand(20) - 10, $ll];
        push @spots, [$x + $tx * $tl * 0.55, $y + $ty * $tl * 0.55, $ta, $k];
      }
      for my $s (-1, 1) { push @leaves, [$x, $y, $h + $s * (36 + rand(30)), $ll * (0.8 + rand(0.35))] if $k >= ($o{bare} // 1); }
      push @spots, [$x, $y, $h, $k];
    }
    push @leaves, [$x, $y, $a + rand(20) - 10, $ll * 1.05];
  }
  if ($o{mass}) { my ($r0, $r1) = @{$o{mass}}; my $N = 20; my @k = map { 0.85 + rand(0.3) } 0 .. $N - 1;
    for my $i (0 .. $N - 1) { my ($ax, $ay) = dir(360 * $i / $N); my ($bx, $by) = dir(360 * ($i + 1.06) / $N); my $j = ($i + 1) % $N;
      poly("c1", [200 + $ax * $R * $r0, 200 + $ay * $R * $r0], [200 + $ax * $R * $r1 * $k[$i], 200 + $ay * $R * $r1 * $k[$i]], [200 + $bx * $R * $r1 * $k[$j], 200 + $by * $R * $r1 * $k[$j]], [200 + $bx * $R * $r0, 200 + $by * $R * $r0]); } }
  blade(@$_[0 .. 3], $_->[4], 0, "c5", "c4", 0.45) for @wood;
  for (sort { (($b->[0] - 200) ** 2 + ($b->[1] - 200) ** 2) <=> (($a->[0] - 200) ** 2 + ($a->[1] - 200) ** 2) } @leaves) {
    tleaf(@$_);
  }
  blade(@$_[0 .. 3], 4.4, 0, $o{thorn} // "c3", "c3") for @thorns;
  return @spots;
}

# 1. Seeds, front view: a finger lime split open behind a little heap of pale pips and a few pearls.
split_finger(70, 150, -4, 262, 64, [[110, 222, 9], [282, 214, 8], [262, 234, 7.5]], 11);
{ srand(14); my @sd;
  for my $row ([330, 4], [302, 3], [276, 2]) { my ($y, $c) = @$row;
    for my $k (0 .. $c - 1) { push @sd, [200 + ($k - ($c - 1) / 2) * 38 + rand(8) - 4, $y + rand(6) - 3, -90 + rand(70) - 35, 40, 24]; } }
  pip(@$_) for sort { $a->[1] <=> $b->[1] } @sd; }
write_svg('1-seeds-front.svg', 'Finger Lime seeds');

# 2. Just sown, top down: pips pressed into small soil pockets.
my @sown = ([170, 172, -40], [234, 168, 30], [202, 230, 120]);
for (@sown) { soil($_->[0], $_->[1], 31, 26, int($_->[0] * 3 + $_->[1])); }
for (@sown) { pip($_->[0] - 9, $_->[1] + 4, $_->[2], 22, 13); pip($_->[0] + 10, $_->[1] - 5, $_->[2] + 160, 21, 12); }
write_svg('2-sown.svg', 'Finger Lime just sown');

# 3. First growth, top down: a wiry seedling, tiny leaves in pairs and the first thorns.
soil(200, 200, 34, 30, 3);
thornbush(nb => 3, reach => 82, seed => 31, start => -100, leaf => 22, segs => 3, ww => 4, bare => 0);
write_svg('3-first-growth.svg', 'Finger Lime first growth');

# 4. Second growth, top down: a young zig-zag thorny bush with tiny leaves.
soil(200, 200, 34, 30, 4);
thornbush(nb => 8, reach => 122, seed => 41, start => -80, leaf => 22, segs => 4, ww => 6);
write_svg('4-second-growth.svg', 'Finger Lime second growth');

# 5. Third growth, top down: the bush thickens, small pale-pink blossoms and the first slim green fingers.
soil(200, 200, 34, 30, 5);
my @s5 = thornbush(nb => 10, reach => 150, seed => 51, start => -84, leaf => 24, segs => 5, ww => 7);
srand(52);
for my $k (0 .. $#s5) {
  my ($x, $y, $a, $d) = @{$s5[$k]};
  next unless $d >= 2;
  if ($k % 3 == 0) { finger($x, $y, $a + 50, 34, 8, 8, ripe => 0, stem => 4); }
  elsif ($k % 3 == 1) { flower($x, $y, 11, rand(72), 'c2', 'c5'); }
}
write_svg('5-third-growth.svg', 'Finger Lime third growth with blossom');

# 6. Harvest, top down: a thorny bush hung with many long slim burgundy finger limes.
soil(200, 200, 34, 30, 6);
my @s6 = thornbush(nb => 11, reach => 164, seed => 61, start => -76, leaf => 26, bare => 0, segs => 5, ww => 8);
srand(62);
for my $k (0 .. $#s6) {
  my ($x, $y, $a, $d) = @{$s6[$k]};
  next unless $d >= 1 && $k % 2 == 0;
  finger($x, $y, $a + ($k % 4 ? 62 : -62), 46, 12, ($k % 4 ? 14 : -14), stem => 5);
}
write_svg('6-harvest.svg', 'Finger Lime ready to harvest');

# 7. Harvest, front view: two whole finger limes and one split open, spilling pink caviar pearls.
finger(70, 112, 14, 236, 46, 8, stem => 16, dots => 40);
finger(56, 176, 8, 250, 48, 4, stem => 14, dots => 40);
{ my @sp; srand(72);
  for my $row ([318, 7, 0], [304, 5, 6], [291, 3, 12]) { my ($y, $c, $o) = @$row;
    for my $k (0 .. $c - 1) { push @sp, [232 + $o + $k * 15 + rand(4) - 2, $y + rand(4) - 2, 8 + rand(1.6)]; } }
  push @sp, [190, 318, 7.5], [210, 322, 8], [352, 312, 7], [340, 324, 7.5];
  split_finger(70, 254, 4, 236, 52, \@sp, 71); }
write_svg('7-harvest-front.svg', 'Harvested Finger Limes');

# 8. Dead (never watered), top down: cracked soil, bare thorny branches, tiny curled straw leaves, shrivelled fingers.
my @d8 = dead_bush(nb => 7, reach => 124, leaf => 22, lw => 0.5, seed => 86, ww => 6);
for my $k (1, 3, 5) { my ($x, $y, $a) = @{$d8[$k]};
  finger($x, $y, $a + 70, 30, 8, 30, ripe => 1, gloss => 'c4');
  blade($x, $y, $a - 60, 14, 2.4, 0, 'c3', 'c4'); }
write_svg('8-dead.svg', 'Finger Lime died from lack of water');
print "wrote 8 files to $OUT\n";

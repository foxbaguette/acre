# Buddha's Hand Citron crop art (citrus bush): 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/buddhas-hand.pl
# Shared citrus parts live in tools/crops/citrus-common.pl. Top-down stages (2-6, 8) share one fixed scale
# centred on (200,200). Signature: golden citrons split into many long curling fingers like a hand.
# The fruit is seedless, so it is planted as a rooted cutting.
use strict; use warnings; use Math::Trig;
our ($OUT, %PAL, @S);
do './tools/crops/citrus-common.pl' or die "citrus-common: $@ $!";
$OUT = 'crops/buddhas-hand';
# c1 leaf green, c2 lit green, c3 lemon-chiffon (finger highlights, blossom, dry leaves), c4 soil / shade, c5 golden citron
%PAL = (c1 => '#2F6236', c2 => '#76A94B', c3 => '#FFF0BE', c4 => '#5A3A22', c5 => '#EDB52A');

# One finger of the citron: thick at the root, tapering to a blunt rounded tip, curling by `bend`.
# Body c5 with a shaded strip on the side away from the light and a chiffon highlight strip on the lit side.
sub bfinger {
  my ($x, $y, $ang, $len, $w, $bend, %o) = @_;
  my ($body, $shade, $hi) = ($o{body} // 'c5', $o{shade} // 'c4', $o{hi} // 'c3');
  my $n = 14; my (@mid, @l, @r, @an);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - 0.72 * $t ** 1.2);
    $hw *= sqrt(max(0, 1 - (($t - 0.86) / 0.14) ** 2)) if $t > 0.86;
    $hw = max($hw, 0.6) if $i < $n;
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n * (0.4 + 1.2 * $t);
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  my ($L, $R) = $leftLit ? (\@l, \@r) : (\@r, \@l);
  poly($body, @l, reverse @r);
  poly($shade, @$R[0 .. $n - 1], reverse map { [$mid[$_][0] + ($R->[$_][0] - $mid[$_][0]) * ($o{sk} // 0.25), $mid[$_][1] + ($R->[$_][1] - $mid[$_][1]) * ($o{sk} // 0.25)] } 0 .. $n - 1);
  poly($hi, map { [$mid[$_][0] + ($L->[$_][0] - $mid[$_][0]) * 0.75, $mid[$_][1] + ($L->[$_][1] - $mid[$_][1]) * 0.75] } 1 .. $n - 3)
    if $hi && $w > 6;
  return ($px, $py);
}

# The whole Buddha's hand, front view: a short knobbly "palm" under the stalk, fingers fanning down and out,
# the outer ones curling up and in. (x,y) = stalk end; `ang` = the direction the hand hangs.
sub bhand {
  my ($x, $y, $ang, $size, %o) = @_;
  srand($o{seed} // 1);
  my $k = $o{fingers} // 11; my $spread = $o{spread} // 150;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my ($bx, $by) = ($x + $dx * $size * 0.17, $y + $dy * $size * 0.17);   # centre of the rounded base
  my @f;
  for my $row (0, 1) {             # back row: wide fan, curling up and out; front row: shorter, hanging, tips in
    my $kk = $row ? int($k / 2) : $k - int($k / 2);
    for my $i (0 .. $kk - 1) {
      my $u = $kk > 1 ? ($i / ($kk - 1)) * 2 - 1 : 0;
      $u *= $row ? 0.62 : 1;
      my $a = $ang + $u * $spread / 2 + rand(8) - 4;
      my $len = $size * ($row ? 0.5 + 0.12 * (1 - abs($u)) : 0.55 + 0.2 * (1 - abs($u)) ** 0.6) * (0.9 + rand(0.2));
      my $bend = ($row ? 1 : -1) * $u * ($o{curl} // 70) * (0.7 + rand(0.5)) + rand(24) - 12;
      $bend = $u * ($o{curl} // 70) * 1.6 if !$row && abs($u) > 0.7;
      my $r0 = $size * 0.1;
      push @f, [$bx + cos(deg2rad($a)) * $r0, $by + sin(deg2rad($a)) * $r0, $a, $len, $size * (0.17 + rand(0.03)) * ($row ? 1.08 : 1), $bend, $row * 10 - abs($u)];
    }
  }
  # the rounded base behind the front fingers
  fruit($bx, $by - $dy * $size * 0.02, $ang, $size * 0.5, $size * 0.62, body => $o{body} // 'c5', shade => $o{shade} // 'c4', gloss => $o{hi} // 'c3', gsize => 0.9, n => 24)
    if 0;
  my @back = grep { $_->[6] < 5 } @f; my @front = grep { $_->[6] >= 5 } @f;
  bfinger(@$_[0 .. 5], %o, sk => 0.7) for sort { $a->[6] <=> $b->[6] } @back;
  fruit($bx, $by, $ang, $size * 0.34, $size * 0.5, body => $o{body} // 'c5', shade => $o{shade} // 'c4', gloss => $o{hi} // 'c3', gsize => 0.9, n => 24);
  bfinger(@$_[0 .. 5], %o, sk => 0.7) for sort { $a->[6] <=> $b->[6] } @front;
}

# Top-down: the hanging hand seen from above, fingers splayed all round the stalk like a star.
sub bhand_top {
  my ($x, $y, $size, $rot, %o) = @_;
  srand($o{seed} // 1);
  my $k = $o{fingers} // 9; my @f;
  for my $i (0 .. $k - 1) {
    my $a = $rot + $i * 360 / $k + rand(14) - 7;
    my $len = $size * (0.42 + rand(0.16)); my $bend = (rand(1) < 0.5 ? -1 : 1) * (40 + rand(50));
    push @f, [$x + cos(deg2rad($a)) * $size * 0.14, $y + sin(deg2rad($a)) * $size * 0.14, $a, $len, $size * 0.24, $bend];
  }
  bfinger(@$_, %o, sk => 0.62) for @f;
  fruit($x, $y, $rot, $size * 0.44, $size * 0.42, body => $o{body} // 'c5', shade => $o{shade} // 'c4', gloss => $o{hi} // 'c3', gsize => 0.7, n => 16,
        calyx => ['c1', $size * 0.09, 0, 0, 'c2']);
}

# A rooted cutting (front view): a woody stick with a slanted pale cut end and a few leaves at the top.
sub cutting_front {
  my ($x, $y) = @_;   # bottom cut end
  my ($ex, $ey) = blade($x, $y, -84, 220, 16, 6, 'c2', 'c1', 0.4);
  # cut end: a pale slanted oval with a dark rim
  poly('c4', map { my $th = 2 * pi * $_ / 12; [$x + cos($th) * 10, $y + 2 + sin($th) * 5] } 0 .. 11);
  poly('c3', map { my $th = 2 * pi * $_ / 12; [$x + cos($th) * 7.5, $y + 1 + sin($th) * 3.6] } 0 .. 11);
  # a few short roots
  for my $r ([200, 50, 30], [150, 42, -26], [240, 36, 34], [110, 30, 20], [ 60, 34, -30]) {
    blade($x + cos(deg2rad($r->[0])) * 4, $y + 3, $r->[0] > 90 ? 180 - (180 - $r->[0]) * 0.6 : $r->[0], $r->[1], 4, $r->[2], 'c3', 'c4');
  }
  # leaves: two big ones near the top and a small fresh one at the tip
  my ($lx, $ly) = walk($x, $y, -84, 220, 6, 0.62);
  cleaf($lx, $ly, -160, 118, 48, 18, 'c2', 'c1', 'c3');
  my ($mx, $my) = walk($x, $y, -84, 220, 6, 0.82);
  cleaf($mx, $my, -18, 112, 46, -16, 'c2', 'c1', 'c3');
  cleaf($ex, $ey, -100, 64, 28, 12, 'c2', 'c1', 'c3');
}

# 1. Planting material, front view: a rooted cutting (Buddha's hand has no seeds).
cutting_front(196, 330);
write_svg('1-seeds-front.svg', "Buddha's Hand Citron cutting");

# 2. Just planted, top down: the cutting pushed into a soil pocket: its stick end and first leaves from above.
soil(200, 200, 42, 36, 21);
cleaf(200, 200, -140, 62, 26, 14, 'c2', 'c1', 'c3'); cleaf(200, 200, 30, 58, 24, -12, 'c2', 'c1', 'c3');
poly('c4', map { my $th = 2 * pi * $_ / 10; [200 + cos($th) * 9, 200 + sin($th) * 9] } 0 .. 9);
poly('c2', map { my $th = 2 * pi * $_ / 10; [199 + cos($th) * 6.5, 199 + sin($th) * 6.5] } 0 .. 9);
write_svg('2-sown.svg', "Buddha's Hand Citron just planted");

# 3. First growth, top down: the cutting has taken; a ring of young leaves.
soil(200, 200, 36, 32, 3);
for my $l ([-110, 84, 12], [-20, 76, -10], [70, 80, 12], [160, 74, -12], [-65, 56, 8], [115, 54, -8]) {
  cleaf(200, 200, $l->[0], $l->[1], $l->[1] * 0.42, $l->[2], 'c2', 'c1', 'c3'); }
poly('c4', map { my $th = 2 * pi * $_ / 10; [200 + cos($th) * 8, 200 + sin($th) * 8] } 0 .. 9);
write_svg('3-first-growth.svg', "Buddha's Hand Citron first growth");

# 4. Second growth, top down: a young citrus bush with long oblong leaves.
soil(200, 200, 34, 30, 4);
bush(nb => 7, reach => 124, seed => 43, start => -100, leaf => 46, lw => 0.42, per => 3, inner => 0.25, centre => 5, mass => [0.24, 0.58], wood => [8, 'c1', 'c4']);
write_svg('4-second-growth.svg', "Buddha's Hand Citron second growth");

# 5. Third growth, top down: white star blossoms, buds and the first small green hands.
soil(200, 200, 34, 30, 5);
my @s5 = bush(nb => 9, reach => 152, seed => 53, start => -96, leaf => 52, lw => 0.42, per => 4, inner => 0.22, centre => 6, mass => [0.22, 0.6], spots => [0.55, 0.85]);
srand(54);
for my $k (0 .. $#s5) {
  my ($x, $y, $a) = @{$s5[$k]};
  if ($k % 4 == 0) { bhand($x, $y, $a + 20, 40, seed => $k, fingers => 9, spread => 100, curl => 60, body => "c2", shade => "c1", hi => "c3"); }
  elsif ($k % 4 == 2) { flower($x, $y, 16, rand(72)); }
  elsif ($k % 4 == 3) { bud($x, $y, $a + 30, 6); bud($x + 9, $y - 6, $a - 20, 5); }
  else { flower($x, $y, 13, rand(72)); }
}
write_svg('5-third-growth.svg', "Buddha's Hand Citron third growth");

# 6. Harvest, top down: the bush hung with big golden many-fingered citrons.
soil(200, 200, 34, 30, 6);
my @s6 = bush(nb => 9, reach => 176, seed => 63, start => -80, leaf => 56, lw => 0.42, per => 4, inner => 0.2, centre => 7, mass => [0.2, 0.6], spots => [0.62]);
srand(64);
for my $k (0 .. $#s6) { next if $k % 3 == 1; my ($x, $y, $a) = @{$s6[$k]}; bhand($x, $y, $a + 25, 86, seed => 60 + $k, fingers => 11, spread => 110, curl => 70); }
bhand(196, 190, 40, 80, seed => 77, fingers => 11, spread => 110, curl => 70);
write_svg('6-harvest.svg', "Buddha's Hand Citron ready to harvest");

# 7. Harvest, front view: one big Buddha's hand on a short stalk with a leaf.
blade(196, 92, -70, 34, 10, -20, 'c2', 'c1', 0.4);
cleaf(204, 74, -24, 116, 50, 20, 'c2', 'c1', 'c3');
bhand(196, 92, 90, 236, seed => 7, fingers => 16, spread => 140, curl => 80);
write_svg('7-harvest-front.svg', "Harvested Buddha's Hand Citron");

# 8. Dead (never watered), top down: cracked soil, bare branches, curled straw leaves, a shrivelled brown hand.
my @d8 = dead_bush(nb => 7, reach => 126, leaf => 48, lw => 0.38, seed => 87);
for my $k (2, 5) { my ($x, $y, $a) = @{$d8[$k]}; bhand($x, $y, $a + 40, 40, seed => $k, fingers => 9, spread => 140, curl => 120, body => "c4", shade => "c4", hi => "c3"); }
write_svg('8-dead.svg', "Buddha's Hand Citron died from lack of water");
print "wrote 8 files to $OUT\n";

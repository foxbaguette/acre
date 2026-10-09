# Mandarin crop art (compact citrus bush): 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/mandarin.pl
# Shared citrus parts live in tools/crops/citrus-common.pl. Top-down stages (2-6, 8) share one fixed scale
# centred on (200,200). Signature: small, flattened (oblate), deep red-orange mandarins, often still carrying
# a leaf or two on the stalk; the produce includes one half-peeled mandarin showing its segments.
use strict; use warnings; use Math::Trig;
our ($OUT, %PAL, @S);
do './tools/crops/citrus-common.pl' or die "citrus-common: $@ $!";
$OUT = 'crops/mandarin';
# c1 deep leaf green, c2 lit green, c3 warm peach-cream (gloss, pith, blossom, dry leaves), c4 soil / shade,
# c5 deep red-orange mandarin
%PAL = (c1 => '#26532F', c2 => '#5F9C45', c3 => '#FFE8CC', c4 => '#5A3A22', c5 => '#E8571B');

# A mandarin seen from the side: wider than tall, a small dimple and calyx on top (ang = hanging direction).
sub mandarin {
  my ($x, $y, $ang, $wid, %o) = @_;
  my $ripe = $o{ripe} // 1;
  fruit($x, $y, $ang, $wid * 0.76, $wid, n => 36,
        body => $ripe ? 'c5' : 'c2', shade => $ripe ? 'c4' : 'c1', gloss => 'c3', gsize => 0.85,
        stem => $o{stem} ? [$o{stem}, max(3, $wid * 0.06), 'c2'] : undef, stembend => $o{sb} // 0,
        pores => $o{pores} // 0, porelit => 'c3', neck => -0.02, sthr => 0.08,
        calyx => ['c2', $wid * 0.09, -0.42, 0, 'c1']);
}

# A mandarin from above: round, calyx in the middle, one glossy leaf left on its short stalk.
sub mandarin_top {
  my ($x, $y, $ang, $d, %o) = @_;
  my ($dx, $dy) = dir($ang);
  cleaf($x - $dx * $d * 0.2, $y - $dy * $d * 0.2, $ang + ($o{la} // 150), $d * 1.05, $d * 0.5, 14, 'c2', 'c1', 'c3') if $o{leaf};
  fruit($x, $y, $ang, $d, $d, n => 30, body => $o{body} // 'c5', shade => $o{shade} // 'c4', gloss => 'c3', gsize => 0.85,
        calyx => [$o{cc} // 'c2', $d * 0.11, 0.05, 0.05, 'c1']);
}

# A half-peeled mandarin: the top is bare fruit (segments meeting at the top, pale pith strands), the bottom still
# sits in its torn peel cup, whose flaps fold out and show the white inner side.
# The opened peel lying flat: rind petals around a centre, white pith side up, orange rim.
sub peel_star {
  my ($x, $py0, $rx) = @_;
  my @pet = ([-168, 1.0], [-118, 0.62], [-62, 0.62], [-12, 1.0], [52, 0.9], [128, 0.9]);
  for my $p (sort { sin(deg2rad($a->[0])) <=> sin(deg2rad($b->[0])) } @pet) {
    my ($a, $s) = @$p; my ($dx, $dy) = (cos(deg2rad($a)), sin(deg2rad($a)) * 0.42);
    my $L = $rx * 1.6 * $s; my ($nx, $ny) = (-$dy, $dx); my $nl = sqrt($nx * $nx + $ny * $ny) || 1; ($nx, $ny) = ($nx / $nl, $ny / $nl);
    my $W = $rx * 0.44;
    my @q = ([$x + $nx * $W * 0.7, $py0 + $ny * $W * 0.7]);
    for my $i (1 .. 6) { my $t = $i / 6; my $hw = $W * (1 - $t ** 2.2) * (0.8 + 0.3 * sin(pi * $t));
      push @q, [$x + $dx * $L * $t + $nx * $hw, $py0 + $dy * $L * $t + $ny * $hw]; }
    my @r = ([$x - $nx * $W * 0.7, $py0 - $ny * $W * 0.7]);
    for my $i (1 .. 5) { my $t = $i / 6; my $hw = $W * (1 - $t ** 2.2) * (0.8 + 0.3 * sin(pi * $t));
      push @r, [$x + $dx * $L * $t - $nx * $hw, $py0 + $dy * $L * $t - $ny * $hw]; }
    poly('c5', @q, reverse @r);
    poly('c3', map { [$x + ($_->[0] - $x) * 0.9, $py0 + ($_->[1] - $py0) * 0.86 - 1.5] } @q, reverse @r);
  }
}

sub peeled {
  my ($x, $y, $wid) = @_;
  my $rx = $wid / 2; my $ry = $wid * 0.8 / 2;
  peel_star($x, $y + $ry * 0.62, $rx);
  # the bare fruit: segments as meridian bands meeting at the top, seen a little from above
  my $tau = deg2rad(24); my $N = 11;
  my $P = sub { my ($lat, $th) = @_; my ($cl, $sl) = (cos($lat), sin($lat));
    [$x + $rx * $cl * sin($th), $y - $ry * $sl * cos($tau) + $ry * $cl * cos($th) * sin($tau), $cl * cos($th) * cos($tau) + $sl * sin($tau)] };
  my @o = map { my $t = 2 * pi * $_ / 40; [$x + cos($t) * $rx, $y + sin($t) * $ry] } 0 .. 39;
  poly('c4', @o);
  my @segs;
  for my $k (0 .. $N - 1) {
    my $t0 = 2 * pi * $k / $N + 0.1; my $t1 = 2 * pi * ($k + 1) / $N + 0.1; my $tm = ($t0 + $t1) / 2;
    my @a = grep { $_->[2] > 0 } map { $P->(deg2rad($_), $t0 + 0.014) } map { -88 + $_ * 11 } 0 .. 16;
    my @b = grep { $_->[2] > 0 } map { $P->(deg2rad($_), $t1 - 0.014) } map { -88 + $_ * 11 } 0 .. 16;
    next unless @a > 1 && @b > 1;
    my @m = grep { $_->[2] > 0.25 } map { $P->(deg2rad($_), $tm - 0.06) } map { -30 + $_ * 12 } 0 .. 9;
    push @segs, [$tm, [@a, $P->(deg2rad(89), $tm), reverse @b], \@m];
  }
  for my $s (@segs) {
    my ($tm, $pts, $m) = @$s;
    poly('c5', map { [$_->[0], $_->[1]] } @$pts);
    my $lt = -sin($tm) * 0.8 + cos($tm) * 0.3;   # light from the upper left
    if ($lt > 0.15 && @$m > 2) { my $hw = 1.2 + 2.4 * $lt;
      poly('c3', (map { [$_->[0] - $hw, $_->[1]] } @$m), (map { [$_->[0] + $hw, $_->[1] + 1] } reverse @$m)); }
  }
  crescent('c4', $x, $y, 0.7071, 0.7071, 0.25, 0.8, $rx * 0.1, @o);
  # a few pale pith strands clinging to the fruit
  for my $th (0.35, -0.75, 1.1) {
    my @l = map { $P->(deg2rad($_), $th + 0.07 * sin($_ / 14 + $th * 4)) } (-30, -14, 2, 18, 34, 50);
    poly('c3', (map { [$_->[0] - 1, $_->[1]] } @l), (map { [$_->[0] + 1, $_->[1] + 0.8] } reverse @l));
  }
  # the little stalk-end tuft of pith at the top
  my $tp = $P->(deg2rad(90), 0);
  poly('c3', map { my ($ex, $ey) = dir($_ * 45); [$tp->[0] + $ex * $rx * 0.06, $tp->[1] + $ey * $rx * 0.04] } 0 .. 7);
}

# One loose mandarin segment lying on its side: a plump crescent, sheen along the back, pith strands.
sub wedge {
  my ($x, $y, $ang, $len, $h) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $P = sub { my ($u, $v) = @_; [$x + $dx * $len * $u + $nx * $h * $v, $y + $dy * $len * $u + $ny * $h * $v] };
  my @out = map { my $t = $_ / 16; $P->($t, -sin(pi * $t) ** 0.85) } 0 .. 16;
  my @in = map { my $t = $_ / 16; $P->($t, -0.3 * sin(pi * $t) ** 1.3) } reverse 1 .. 15;
  poly('c5', @out, @in);
  poly("c4", (map { my $t = $_ / 16; $P->($t, -0.3 * sin(pi * $t) ** 1.3) } 1 .. 15), reverse map { my $t = $_ / 16; $P->($t, -0.44 * sin(pi * $t) ** 1.1) } 1 .. 15);
  poly('c3', (map { my $t = $_ / 12; $P->($t, -0.84 * sin(pi * $t) ** 0.855) } 2 .. 9), reverse map { my $t = $_ / 12; $P->($t, -0.62 * sin(pi * $t) ** 0.855) } 2 .. 9);
  poly("c3", (map { my $t = $_ / 16; $P->($t, -0.8 * sin(pi * $t) ** 0.85 + 0.04) } 4 .. 12), reverse map { my $t = $_ / 16; $P->($t, -0.8 * sin(pi * $t) ** 0.85 - 0.05) } 5 .. 12);
}

# 1. Seeds, front view: a mandarin with its leaves behind a little heap of pale pips.
{ my ($x, $y, $w) = (200, 150, 176); my $sy = $y - $w * 0.76 * 0.5 + 6;
  cleaf($x + 6, $sy - 12, -150, 96, 44, 24, "c2", "c1", "c3"); cleaf($x + 6, $sy - 12, -36, 90, 42, -20, "c2", "c1", "c3");
  mandarin($x, $y, 92, $w, stem => 16, pores => 50); }
{ srand(16); my @sd;
  for my $row ([340, 5], [312, 4], [286, 3]) { my ($y, $c) = @$row;
    for my $k (0 .. $c - 1) { push @sd, [200 + ($k - ($c - 1) / 2) * 42 + rand(8) - 4, $y + rand(6) - 3, -90 + rand(70) - 35, 44, 27]; } }
  pip(@$_) for sort { $a->[1] <=> $b->[1] } @sd; }
write_svg('1-seeds-front.svg', 'Mandarin seeds');

# 2. Just sown, top down: pips pressed into small soil pockets.
my @sown = ([170, 168, -60], [234, 174, 20], [196, 230, 100]);
for (@sown) { soil($_->[0], $_->[1], 32, 27, int($_->[0] * 13 + $_->[1])); }
for (@sown) { pip($_->[0] - 9, $_->[1] + 4, $_->[2], 23, 14); pip($_->[0] + 10, $_->[1] - 5, $_->[2] + 150, 22, 13); }
write_svg('2-sown.svg', 'Mandarin just sown');

# 3. First growth, top down: two rounded seed leaves and the first glossy leaves.
soil(200, 200, 34, 30, 3);
cleaf(200, 200, 210, 42, 28, -6, 'c2', 'c1');  cleaf(200, 200, 30, 42, 28, 6, 'c2', 'c1');
cleaf(200, 200, -70, 80, 34, 10, 'c2', 'c1', 'c3'); cleaf(200, 200, 110, 76, 32, -10, 'c2', 'c1', 'c3');
cleaf(200, 200, -150, 58, 25, -8, 'c2', 'c1', 'c3'); cleaf(200, 200, 20, 56, 24, 8, 'c2', 'c1', 'c3');
write_svg('3-first-growth.svg', 'Mandarin first growth');

# 4. Second growth, top down: a young citrus bush with slim glossy leaves.
soil(200, 200, 34, 30, 4);
bush(nb => 9, reach => 120, seed => 45, start => -70, leaf => 38, lw => 0.42, per => 3, inner => 0.25, centre => 5, mass => [0.24, 0.6], wood => [7, 'c1', 'c4']);
write_svg('4-second-growth.svg', 'Mandarin second growth');

# 5. Third growth, top down: white star blossoms, buds and the first small green mandarins.
soil(200, 200, 34, 30, 5);
my @s5 = bush(nb => 11, reach => 150, seed => 55, start => -76, leaf => 44, lw => 0.42, per => 4, inner => 0.22, centre => 6, mass => [0.22, 0.6], spots => [0.55, 0.85]);
srand(56);
for my $k (0 .. $#s5) {
  my ($x, $y, $a) = @{$s5[$k]};
  if ($k % 4 == 0) { mandarin_top($x, $y, $a, 28, body => 'c2', shade => 'c1', cc => 'c1'); }
  elsif ($k % 4 == 2) { flower($x, $y, 15, rand(72)); }
  elsif ($k % 4 == 3) { bud($x, $y, $a + 30, 6); bud($x + 9, $y - 6, $a - 20, 5); }
  else { flower($x, $y, 12, rand(72)); }
}
write_svg('5-third-growth.svg', 'Mandarin third growth with blossom');

# 6. Harvest, top down: a dense bush with many small deep red-orange mandarins, some with a leaf on the stalk.
soil(200, 200, 34, 30, 6);
my @s6 = bush(nb => 11, reach => 176, seed => 65, start => -64, leaf => 48, lw => 0.42, per => 4, inner => 0.2, centre => 7, mass => [0.2, 0.6], spots => [0.46, 0.8]);
srand(66);
for my $k (0 .. $#s6) { next if $k % 3 == 2; my ($x, $y, $a) = @{$s6[$k]}; mandarin_top($x, $y, $a, 40, leaf => $k % 3 == 0, la => ($k % 2 ? 140 : -140)); }
mandarin_top(212, 184, -40, 38, leaf => 1);
write_svg('6-harvest.svg', 'Mandarin ready to harvest');

# 7. Harvest, front view: two flattened mandarins (one with two leaves on its stalk) and one half-peeled.
{ my ($x, $y, $w) = (150, 150, 170);
  my ($sx, $sy) = ($x + 4, $y - $w * 0.76 * 0.5 + 6);
  cleaf($sx + 2, $sy - 12, -150, 110, 50, 24, 'c2', 'c1', 'c3');
  cleaf($sx + 2, $sy - 12, -40, 100, 46, -20, 'c2', 'c1', 'c3');
  mandarin($x, $y, 92, $w, stem => 16, pores => 50); }
mandarin(284, 178, 86, 146, stem => 8, pores => 44);
peeled(204, 262, 150);
write_svg('7-harvest-front.svg', 'Harvested mandarins');

# 8. Dead (never watered), top down: cracked soil, bare branches, curled straw leaves, two shrivelled mandarins.
my @d8 = dead_bush(nb => 8, reach => 122, leaf => 42, lw => 0.4, seed => 89);
for my $k (1, 5) { my ($x, $y, $a) = @{$d8[$k]};
  fruit($x, $y, $a, 24, 22, body => 'c4', shade => 'c4', gloss => 0);
  fruit($x - 2, $y - 2, $a + 30, 12, 8, body => 'c5', shade => 'c4', gloss => 0); }
write_svg('8-dead.svg', 'Mandarin died from lack of water');
print "wrote 8 files to $OUT\n";

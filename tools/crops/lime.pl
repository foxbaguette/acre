# Lime crop art (compact citrus bush): 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/lime.pl
# Shared citrus parts live in tools/crops/citrus-common.pl. Top-down stages (2-6, 8) share one fixed scale
# centred on (200,200). Signature: small, round, glossy green limes (rounder and greener than unripe lemons)
# on a dark blue-green bush; the cut lime shows bright green-yellow segments inside a dark green rind.
use strict; use warnings; use Math::Trig;
our ($OUT, %PAL, @S);
do './tools/crops/citrus-common.pl' or die "citrus-common: $@ $!";
$OUT = 'crops/lime';
# c1 deep blue-green leaf / lime shade, c2 lit leaf, c3 pale lime cream (gloss, pith, blossom, dry leaves),
# c4 soil, c5 glossy lime green
%PAL = (c1 => '#1F4A2E', c2 => '#3F7F45', c3 => '#EEF4C6', c4 => '#5A3A22', c5 => "#62A42B");

# A lime: nearly round, a tiny nub at the blossom end, short stalk at the stem end, a bright gloss spark.
sub lime {
  my ($x, $y, $ang, $len, %o) = @_;
  fruit($x, $y, $ang, $len, $len * 0.93, tip => 0.035, n => 40,
        body => $o{body} // 'c5', shade => 'c1', gloss => 'c3', gsize => $o{gs} // 1.05, spark => 1,
        stem => $o{stem} ? [$o{stem}, max(3, $len * 0.09), 'c2'] : undef, stembend => $o{sb} // 0,
        pores => $o{pores} // 0, porelit => 'c3', sthr => 0.05);
}

# 1. Seeds, front view: a lime wheel (dark rind, green segments) behind a little heap of pale pips.
cut_face(200, 156, 100, 100, nseg => 10, side => 9, rot => 0.1, segr => 0.86, rim => 'c1', seg => 'c5', shade => 'c1');
{ srand(13); my @sd;
  for my $row ([336, 5], [306, 4], [278, 3]) { my ($y, $c) = @$row;
    for my $k (0 .. $c - 1) { push @sd, [200 + ($k - ($c - 1) / 2) * 40 + rand(8) - 4, $y + rand(6) - 3, -90 + rand(70) - 35, 42, 25]; } }
  pip(@$_) for sort { $a->[1] <=> $b->[1] } @sd; }
write_svg('1-seeds-front.svg', 'Lime seeds');

# 2. Just sown, top down: pips pressed into small soil pockets.
my @sown = ([170, 170, -50], [234, 172, 30], [200, 230, 120]);
for (@sown) { soil($_->[0], $_->[1], 32, 27, int($_->[0] * 5 + $_->[1])); }
for (@sown) { pip($_->[0] - 9, $_->[1] + 4, $_->[2], 23, 13); pip($_->[0] + 10, $_->[1] - 5, $_->[2] + 160, 22, 13); }
write_svg('2-sown.svg', 'Lime just sown');

# 3. First growth, top down: two rounded seed leaves and the first glossy pointed leaves.
soil(200, 200, 34, 30, 3);
cleaf(200, 200, 230, 42, 28, -6, 'c2', 'c1');  cleaf(200, 200, 50, 42, 28, 6, 'c2', 'c1');
cleaf(200, 200, -60, 82, 36, 12, 'c2', 'c1', 'c3'); cleaf(200, 200, 124, 78, 34, -12, 'c2', 'c1', 'c3');
cleaf(200, 200, -150, 60, 27, -10, 'c2', 'c1', 'c3'); cleaf(200, 200, 30, 58, 26, 8, 'c2', 'c1', 'c3');
write_svg('3-first-growth.svg', 'Lime first growth');

# 4. Second growth, top down: a young citrus bush, woody centre, glossy dark leaves.
soil(200, 200, 34, 30, 4);
bush(nb => 8, reach => 120, seed => 42, start => -60, leaf => 40, lw => 0.46, per => 3, inner => 0.25, centre => 5, mass => [0.3, 0.6], wood => [7, 'c2', 'c4']);
write_svg('4-second-growth.svg', 'Lime second growth');

# 5. Third growth, top down: fuller bush with white star blossoms, buds and the first tiny limes.
soil(200, 200, 34, 30, 5);
my @s5 = bush(nb => 10, reach => 150, seed => 52, start => -70, leaf => 46, lw => 0.46, per => 4, inner => 0.22, centre => 6, mass => [0.28, 0.6], spots => [0.55, 0.85], wood => [9, 'c2', 'c4']);
srand(53);
for my $k (0 .. $#s5) {
  my ($x, $y, $a) = @{$s5[$k]};
  if ($k % 4 == 0) { lime($x, $y, $a + 40, 28, stem => 7, gs => 0.9); }
  elsif ($k % 4 == 2) { flower($x, $y, 16, rand(72)); }
  elsif ($k % 4 == 3) { bud($x, $y, $a + 30, 6); bud($x + 9, $y - 6, $a - 20, 5); }
  else { flower($x, $y, 13, rand(72)); }
}
write_svg('5-third-growth.svg', 'Lime third growth with blossom');

# 6. Harvest, top down: a dense dark bush studded with many small round glossy limes.
soil(200, 200, 34, 30, 6);
my @s6 = bush(nb => 11, reach => 178, seed => 62, start => -60, leaf => 50, lw => 0.46, per => 4, inner => 0.2, centre => 7, mass => [0.26, 0.6], spots => [0.48, 0.8], wood => [10, 'c2', 'c4']);
srand(63);
for my $k (0 .. $#s6) { my ($x, $y, $a) = @{$s6[$k]}; next if $k % 3 == 2; lime($x, $y, $a + ($k % 2 ? 40 : -40), 38, stem => 8, sb => ($k % 2 ? -30 : 30)); }
lime(214, 178, -30, 36, stem => 7); lime(180, 222, 150, 36, stem => 7);
write_svg('6-harvest.svg', 'Lime ready to harvest');

# 7. Harvest, front view: two round glossy limes (one with a leaf) and a halved lime showing its segments.
{ my ($x, $y, $a, $l) = (232, 150, 76, 150); my ($dx, $dy) = dir($a);
  my ($sx, $sy) = ($x - $dx * $l * 0.48, $y - $dy * $l * 0.48);
  cleaf($sx - 4, $sy - 6, -150, 104, 46, 20, 'c2', 'c1', 'c3');
  lime($x, $y, $a, $l, stem => 16, sb => -10, pores => 46); }
lime(132, 214, -60, 140, pores => 40);
cut_face(226, 290, 84, 50, nseg => 10, side => 24, rot => 0.15, rim => 'c1', seg => 'c5', shade => 'c1');
write_svg('7-harvest-front.svg', 'Harvested limes');

# 8. Dead (never watered), top down: cracked soil, bare branches, curled straw leaves, two shrivelled limes.
my @d8 = dead_bush(nb => 7, reach => 122, leaf => 42, seed => 85);
for my $k (2, 5) { my ($x, $y, $a) = @{$d8[$k]};
  fruit($x, $y, $a + 60, 22, 19, body => 'c4', shade => 'c4', gloss => 0);
  fruit($x - 2, $y - 2, $a + 60, 12, 8, body => "c5", shade => "c4", gloss => 0); }
write_svg('8-dead.svg', 'Lime died from lack of water');
print "wrote 8 files to $OUT\n";

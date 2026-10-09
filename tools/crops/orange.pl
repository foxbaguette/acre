# Orange crop art (compact citrus bush): 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/orange.pl
# Shared citrus parts live in tools/crops/citrus-common.pl. Top-down stages (2-6, 8) share one fixed scale
# centred on (200,200). Signature: big round bright-orange oranges with dimpled peel and a small green calyx.
use strict; use warnings; use Math::Trig;
our ($OUT, %PAL, @S);
do './tools/crops/citrus-common.pl' or die "citrus-common: $@ $!";
$OUT = 'crops/orange';
# c1 deep glossy leaf green, c2 lit green, c3 warm cream (gloss, pith, blossom, dry leaves), c4 soil / shade, c5 orange
%PAL = (c1 => '#295A2F', c2 => '#68A145', c3 => '#FFEFD2', c4 => '#5A3A22', c5 => '#F58A1F');

# An orange: round, dimpled peel, little green calyx star where the stalk joins.
sub orange {
  my ($x, $y, $ang, $len, %o) = @_;
  my $ripe = $o{ripe} // 1;
  fruit($x, $y, $ang, $len, $len * 0.97, n => 36,
        body => $ripe ? 'c5' : 'c2', shade => $ripe ? 'c4' : 'c1', gloss => 'c3', gsize => $o{gs} // 0.9,
        stem => $o{stem} ? [$o{stem}, max(3, $len * 0.07), 'c2'] : undef, stembend => $o{sb} // 0,
        pores => $o{pores} // 0, porelit => 'c3', poredark => undef, sthr => 0.08,
        calyx => $o{calyx} // ['c2', $len * 0.1, -0.62, 0, 'c1']);
}

# 1. Seeds, front view: an orange wheel behind a little heap of pale pips.
cut_face(200, 156, 102, 102, nseg => 10, side => 9, rot => 0.2, segr => 0.86);
{ srand(15); my @sd;
  for my $row ([336, 5], [306, 4], [278, 3]) { my ($y, $c) = @$row;
    for my $k (0 .. $c - 1) { push @sd, [200 + ($k - ($c - 1) / 2) * 42 + rand(8) - 4, $y + rand(6) - 3, -90 + rand(70) - 35, 46, 28]; } }
  pip(@$_) for sort { $a->[1] <=> $b->[1] } @sd; }
write_svg('1-seeds-front.svg', 'Orange seeds');

# 2. Just sown, top down: pips pressed into small soil pockets.
my @sown = ([166, 170, -20], [236, 170, 60], [202, 232, 130]);
for (@sown) { soil($_->[0], $_->[1], 32, 27, int($_->[0] * 11 + $_->[1])); }
for (@sown) { pip($_->[0] - 9, $_->[1] + 4, $_->[2], 24, 14); pip($_->[0] + 10, $_->[1] - 5, $_->[2] + 150, 23, 14); }
write_svg('2-sown.svg', 'Orange just sown');

# 3. First growth, top down: two rounded seed leaves and the first glossy leaves.
soil(200, 200, 34, 30, 3);
cleaf(200, 200, 180, 44, 30, -6, 'c2', 'c1');  cleaf(200, 200, 0, 44, 30, 6, 'c2', 'c1');
cleaf(200, 200, -96, 84, 42, 10, 'c2', 'c1', 'c3'); cleaf(200, 200, 84, 80, 40, -10, 'c2', 'c1', 'c3');
cleaf(200, 200, -40, 62, 31, 8, 'c2', 'c1', 'c3'); cleaf(200, 200, 140, 60, 30, -8, 'c2', 'c1', 'c3');
write_svg('3-first-growth.svg', 'Orange first growth');

# 4. Second growth, top down: a young round citrus bush with broad glossy leaves.
soil(200, 200, 34, 30, 4);
bush(nb => 8, reach => 124, seed => 44, start => -96, leaf => 42, lw => 0.54, per => 3, inner => 0.25, centre => 5, mass => [0.24, 0.6], wood => [8, 'c1', 'c4']);
write_svg('4-second-growth.svg', 'Orange second growth');

# 5. Third growth, top down: white star blossoms, buds and the first small green oranges.
soil(200, 200, 34, 30, 5);
my @s5 = bush(nb => 10, reach => 152, seed => 54, start => -90, leaf => 48, lw => 0.54, per => 4, inner => 0.22, centre => 6, mass => [0.22, 0.6], spots => [0.55, 0.85]);
srand(55);
for my $k (0 .. $#s5) {
  my ($x, $y, $a) = @{$s5[$k]};
  if ($k % 4 == 0) { orange($x, $y, $a, 34, ripe => 0, stem => 6, calyx => ['c1', 3.4, -0.5, 0, 'c1']); }
  elsif ($k % 4 == 2) { flower($x, $y, 17, rand(72)); }
  elsif ($k % 4 == 3) { bud($x, $y, $a + 30, 6); bud($x + 9, $y - 6, $a - 20, 5); }
  else { flower($x, $y, 14, rand(72)); }
}
write_svg('5-third-growth.svg', 'Orange third growth with blossom');

# 6. Harvest, top down: a round dark bush with big bright oranges.
soil(200, 200, 34, 30, 6);
my @s6 = bush(nb => 10, reach => 178, seed => 64, start => -86, leaf => 54, lw => 0.54, per => 4, inner => 0.2, centre => 7, mass => [0.2, 0.6], spots => [0.46, 0.8]);
srand(65);
for my $k (0 .. $#s6) { next if $k % 2 != int($k / 2) % 2; my ($x, $y, $a) = @{$s6[$k]}; orange($x, $y, $a, 56, stem => 8, pores => 10); }
orange(214, 184, -40, 52, stem => 6, pores => 10);
write_svg('6-harvest.svg', 'Orange ready to harvest');

# 7. Harvest, front view: two dimpled oranges (one with a leaf on its stalk) and a juicy halved orange.
cleaf(168, 70, -34, 118, 56, 22, 'c2', 'c1', 'c3');
orange(156, 160, 100, 168, pores => 60, stem => 14, sb => -20, calyx => ['c2', 15, -0.42, 0.12, 'c1']);
orange(272, 196, 80, 150, pores => 54, calyx => ['c2', 13, -0.45, -0.1, 'c1']);
cut_face(196, 294, 92, 48, nseg => 10, side => 28, rot => 0.1, pips => [3]);
write_svg('7-harvest-front.svg', 'Harvested oranges');

# 8. Dead (never watered), top down: cracked soil, bare branches, curled straw leaves, two shrivelled oranges.
my @d8 = dead_bush(nb => 7, reach => 126, leaf => 46, lw => 0.46, seed => 88);
for my $k (0, 4) { my ($x, $y, $a) = @{$d8[$k]};
  fruit($x, $y, $a, 26, 23, body => 'c4', shade => 'c4', gloss => 0);
  fruit($x - 2, $y - 2, $a + 30, 14, 9, body => 'c5', shade => 'c4', gloss => 0); }
write_svg('8-dead.svg', 'Orange died from lack of water');
print "wrote 8 files to $OUT\n";

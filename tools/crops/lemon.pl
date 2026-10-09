# Lemon crop art (compact citrus bush): 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/lemon.pl
# Shared citrus parts live in tools/crops/citrus-common.pl. Top-down stages (2-6, 8) share one fixed scale
# centred on (200,200). Signature: bright yellow oval lemons with a pointed nipple tip on a glossy dark bush.
use strict; use warnings; use Math::Trig;
our ($OUT, %PAL, @S);
do './tools/crops/citrus-common.pl' or die "citrus-common: $@ $!";
$OUT = 'crops/lemon';
# c1 glossy leaf green, c2 lit green, c3 pale lemon cream (gloss, pith, blossom, dry leaves), c4 soil / shade, c5 lemon yellow
%PAL = (c1 => '#2E6A34', c2 => '#71AE47', c3 => '#FBF4C4', c4 => '#5A3A22', c5 => '#F6D232');

# A lemon: oval with a nipple tip, pinched ends, short stalk at the other end.
sub lemon {
  my ($x, $y, $ang, $len, %o) = @_;
  my $ripe = $o{ripe} // 1;
  fruit($x, $y, $ang, $len, $len * 0.74, tip => 0.1, neck => -0.03, taper => 0.3, n => 48,
        body => $ripe ? 'c5' : 'c2', shade => $ripe ? 'c4' : 'c1', gloss => 'c3', gsize => $o{gs} // 1,
        stem => $o{stem} ? [$o{stem}, max(3, $len * 0.08), 'c1'] : undef, stembend => $o{sb} // 0,
        pores => $o{pores} // 0, porelit => 'c3', sthr => 0.15);
}

# 1. Seeds, front view: a lemon wheel standing behind a little heap of pale pips.
cut_face(200, 156, 104, 104, nseg => 9, side => 9, rot => 0.3, segr => 0.86);
{ srand(12); my @sd;
  for my $row ([336, 5], [306, 4], [278, 3]) { my ($y, $c) = @$row;
    for my $k (0 .. $c - 1) { push @sd, [200 + ($k - ($c - 1) / 2) * 42 + rand(8) - 4, $y + rand(6) - 3, -90 + rand(70) - 35, 46, 27]; } }
  pip(@$_) for sort { $a->[1] <=> $b->[1] } @sd; }
write_svg('1-seeds-front.svg', 'Lemon seeds');

# 2. Just sown, top down: pips pressed into small soil pockets.
my @sown = ([168, 172, -30], [236, 168, 40], [204, 230, 110]);
for (@sown) { soil($_->[0], $_->[1], 32, 27, int($_->[0] * 7 + $_->[1])); }
for (@sown) { pip($_->[0] - 9, $_->[1] + 3, $_->[2], 24, 14); pip($_->[0] + 10, $_->[1] - 5, $_->[2] + 150, 22, 13); }
write_svg('2-sown.svg', 'Lemon just sown');

# 3. First growth, top down: two rounded seed leaves and the first glossy pointed leaves.
soil(200, 200, 34, 30, 3);
cleaf(200, 200, 200, 44, 30, -6, "c2", "c1");  cleaf(200, 200, 20, 44, 30, 6, "c2", "c1");
cleaf(200, 200, -84, 84, 40, 12, "c2", "c1", "c3"); cleaf(200, 200, 96, 80, 38, -12, "c2", "c1", "c3");
cleaf(200, 200, -24, 62, 30, 10, "c2", "c1", "c3"); cleaf(200, 200, 160, 58, 28, -8, "c2", "c1", "c3");
write_svg('3-first-growth.svg', 'Lemon first growth');

# 4. Second growth, top down: a young citrus bush, woody centre, glossy leaves.
soil(200, 200, 34, 30, 4);
bush(nb => 8, reach => 122, seed => 41, start => -80, leaf => 40, lw => 0.5, per => 3, inner => 0.25, centre => 5, mass => [0.3, 0.6], wood => [7, 'c1', 'c4']);
write_svg('4-second-growth.svg', 'Lemon second growth');

# 5. Third growth, top down: fuller bush with white star blossoms, buds and small green lemons.
soil(200, 200, 34, 30, 5);
my @s5 = bush(nb => 10, reach => 152, seed => 51, start => -86, leaf => 46, lw => 0.5, per => 4, inner => 0.22, centre => 6, mass => [0.28, 0.6], spots => [0.55, 0.85]);
srand(52);
for my $k (0 .. $#s5) {
  my ($x, $y, $a) = @{$s5[$k]};
  if ($k % 4 == 0) { lemon($x, $y, $a + 40, 36, ripe => 0, stem => 8, gs => 0.8); }
  elsif ($k % 4 == 2) { flower($x, $y, 16, rand(72)); }
  elsif ($k % 4 == 3) { bud($x, $y, $a + 30, 6); bud($x + 9, $y - 6, $a - 20, 5); }
  else { flower($x, $y, 13, rand(72)); }
}
write_svg('5-third-growth.svg', 'Lemon third growth with blossom');

# 6. Harvest, top down: a lush round bush hung with bright yellow lemons.
soil(200, 200, 34, 30, 6);
my @s6 = bush(nb => 11, reach => 180, seed => 61, start => -72, leaf => 52, lw => 0.5, per => 4, inner => 0.2, centre => 7, mass => [0.26, 0.6], spots => [0.5, 0.82]);
srand(62);
for my $k (0 .. $#s6) { next if ($k % 2) != (int($k / 2) % 2); my ($x, $y, $a) = @{$s6[$k]}; lemon($x, $y, $a + ($k % 2 ? 50 : -50), 54, stem => 10, sb => ($k % 2 ? -30 : 30)); }
lemon(212, 176, -30, 46, stem => 8); lemon(176, 226, 150, 44, stem => 8);
write_svg('6-harvest.svg', 'Lemon ready to harvest');

# 7. Harvest, front view: two lemons (one with a leaf on its stalk) and a cut half showing pale segments.
{ my ($x, $y, $a, $l) = (196, 156, 196, 184); my ($dx, $dy) = dir($a);
  my ($sx, $sy) = ($x - $dx * $l * 0.46, $y - $dy * $l * 0.46); my ($ex, $ey) = ($sx + cos(deg2rad($a + 160)) * 20, $sy + sin(deg2rad($a + 160)) * 20);
  cleaf($ex, $ey, -58, 112, 52, -24, "c2", "c1", "c3");
  lemon($x, $y, $a, $l, stem => 22, sb => -20, pores => 40); }
lemon(122, 252, 160, 150, stem => 14, pores => 30);
cut_face(266, 294, 86, 46, nseg => 9, side => 26, rot => 0.25, pips => [2, 6]);
write_svg('7-harvest-front.svg', 'Harvested lemons');

# 8. Dead (never watered), top down: cracked soil, bare branches, curled straw leaves, two shrivelled lemons.
my @d8 = dead_bush(nb => 7, reach => 124, leaf => 44, seed => 84);
for my $k (1, 4) { my ($x, $y, $a) = @{$d8[$k]};
  fruit($x, $y, $a + 60, 30, 20, tip => 0.07, taper => 0.2, body => 'c4', shade => 'c4', gloss => 0);
  fruit($x - 2, $y - 2, $a + 60, 16, 8, body => "c5", shade => "c4", gloss => 0); }
write_svg('8-dead.svg', 'Lemon died from lack of water');
print "wrote 8 files to $OUT\n";

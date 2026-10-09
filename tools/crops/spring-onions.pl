# Spring onion crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/spring-onions.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/spring-onions';
mkdir 'crops'; mkdir $OUT;
# c1 deep blue-green, c2 lit blue-green, c3 white shank / roots / dry straw, c4 soil brown, c5 black seed
my %PAL = (c1 => '#2E6B5C', c2 => '#72B49A', c3 => '#F3F1E2', c4 => '#5A3A22', c5 => '#25212A');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }

# A tapered blade (as in wheat): roots and dry curls.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark) = @_;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $t) ** 0.85 + ($i == $n ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang); my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# A hollow onion leaf: an even-width tube with a pointed tip. Shaded like a cylinder:
# the dark body, a lit band on the side facing the light and a thin pale sheen line.
# $sheen = class for the sheen ('' for none). Returns the tip point.
sub tube {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $sheen) = @_;
  my $n = 14; my (@l, @r, @bl, @sh1, @sh2);
  my ($px, $py, $a) = ($x, $y, $ang);
  my ($dx0, $dy0) = dir($ang); my $s = lit(-$dy0, $dx0) ? 1 : -1;   # which side faces the light
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    my $hw = $w / 2 * min(1, (1 - $t) / 0.32) ** 0.75; $hw = 0.4 if $i == $n;
    push @l, [$px + $nx * $hw, $py + $ny * $hw]; push @r, [$px - $nx * $hw, $py - $ny * $hw];
    push @bl, [$px - $s * $nx * $hw * 0.18, $py - $s * $ny * $hw * 0.18];
    if ($sheen && $t > 0.08 && $t < 0.7) {
      push @sh1, [$px + $s * $nx * $hw * 0.62, $py + $s * $ny * $hw * 0.62];
      push @sh2, [$px + $s * $nx * $hw * 0.4, $py + $s * $ny * $hw * 0.4];
    }
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  poly($dark, @l, reverse @r);
  my @litEdge = $s > 0 ? @l : @r;
  poly($light, @litEdge, reverse @bl);
  poly($sheen, @sh1, reverse @sh2) if @sh1;
  return @{$l[$n]};
}

# A black onion seed: an angular, wrinkled half-moon with a dull lit facet and a tiny glint.
sub oseed {
  my ($x, $y, $ang, $sz) = @_;
  my @shape = ([-1, 0.1], [-0.7, -0.55], [-0.1, -0.8], [0.55, -0.6], [1, -0.05], [0.7, 0.45], [0.05, 0.62], [-0.6, 0.5]);
  my ($c, $s) = (cos(deg2rad($ang)), sin(deg2rad($ang)));
  my $T = sub { my ($u, $v) = @_; [$x + ($u * $c - $v * $s) * $sz, $y + ($u * $s + $v * $c) * $sz] };
  poly('c5', map { $T->(@$_) } @shape);
  # lit facet: the corner of the seed nearest the upper-left light
  my @facet = sort { ($a->[0] + $a->[1]) <=> ($b->[0] + $b->[1]) } map { $T->(@$_) } @shape;
  my ($cx, $cy) = ($x, $y);
  poly('c4', $facet[0], $facet[1], [($facet[0][0] + $facet[1][0]) / 2 * 0.3 + $cx * 0.7, ($facet[0][1] + $facet[1][1]) / 2 * 0.3 + $cy * 0.7]);
  my $g = $T->(-0.2, -0.35); my $g2 = $T->(0.25, -0.45);
  poly('c3', [$g->[0], $g->[1]], [$g2->[0], $g2->[1]], [($g->[0] + $g2->[0]) / 2 + 1.5, ($g->[1] + $g2->[1]) / 2 + 1.5]);
}

# The white top of a shank seen from above: a small round end, lit half white, shaded half pale green.
sub shank_top {
  my ($x, $y, $r, $dark) = @_; my @o;
  for my $i (0 .. 9) { my $th = 2 * pi * $i / 10; push @o, [$x + cos($th) * $r, $y + sin($th) * $r]; }
  poly($dark // 'c2', @o);
  poly('c3', @o[2 .. 8]);   # upper-left half (angles ~108..288 deg)
}

sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o; srand($seed);
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

# A bunch seen from above: $np plants clustered round the centre, each fanning $nl tubes outward.
sub bunch {
  my ($np, $spread, $nl, $len, $lenVar, $w, $bendMax, $shankR, $seed, $sheen) = @_;
  srand($seed); my (@plants, @tubes);
  for my $p (0 .. $np - 1) {
    my $pa = $p * 360 / $np + rand(30); my $pr = $p == 0 ? 0 : $spread * (0.6 + rand(0.4));
    my ($px, $py) = (200 + cos(deg2rad($pa)) * $pr, 200 + sin(deg2rad($pa)) * $pr);
    push @plants, [$px, $py];
    for my $k (0 .. $nl - 1) {
      my $a = ($p == 0 ? -90 : $pa) + ($k - ($nl - 1) / 2) * (360 / ($np * $nl) + 22) + rand(20) - 10;
      $a = -90 + $k * 360 / $nl + rand(20) if $p == 0;
      push @tubes, [$px, $py, $a, $len + rand($lenVar), (rand(1) < 0.5 ? -1 : 1) * $bendMax * (0.4 + rand(0.6))];
    }
  }
  tube($_->[0], $_->[1], $_->[2], $_->[3], $w, $_->[4], 'c2', 'c1', $sheen) for sort { $b->[3] <=> $a->[3] } @tubes;
  # upright leaves seen from above: short, foreshortened tubes crowding the middle of the bunch
  for my $p (@plants) { for (0 .. 2) { tube($p->[0], $p->[1], rand(360), $len * 0.24 + rand($len * 0.1), $w * 0.95, 0, 'c2', 'c1', ''); } }
  shank_top($_->[0], $_->[1], $shankR) for @plants;
}

# 1. Seeds, front view: a small heap of black, angular onion seeds.
for ([140, 306, 10], [196, 312, -6], [252, 308, 170], [168, 278, 30], [226, 280, -24], [198, 250, 4],
     [112, 318, -12], [286, 318, 196], [182, 236, 60], [150, 330, 180], [244, 330, 0]) {
  oseed($_->[0], $_->[1], $_->[2], 25);
}
write_svg('1-seeds-front.svg', 'Spring onion seeds');

# 2. Just sown, top down: little clusters of black seeds pressed into soil pockets, close together for a bunch.
my @sown = ([170, 170], [236, 168], [204, 214], [160, 236], [246, 236]);
soil($_->[0], $_->[1], 26, 22, int($_->[0] * 7 + $_->[1])) for @sown;
srand(22);
for (@sown) { oseed($_->[0] - 7, $_->[1] - 3, rand(360), 11); oseed($_->[0] + 8, $_->[1] + 4, rand(360), 10); }
write_svg('2-sown.svg', 'Spring onions just sown');

# 3. First growth: thin bent "flag" seedlings, two still wearing their black seed coat on the tip.
soil(200, 200, 34, 30, 3);
my @tips;
srand(31);
for my $s ([194, 196, -100, 72, 20], [206, 204, -10, 66, -24], [198, 208, 120, 70, 22], [204, 194, -160, 58, -18],
           [200, 200, 50, 54, 16]) {
  push @tips, [tube($s->[0], $s->[1], $s->[2], $s->[3], 9, $s->[4], 'c2', 'c1', '')];
}
shank_top(194, 196, 5); shank_top(206, 204, 5); shank_top(200, 201, 4.5);
oseed($tips[0][0] + 3, $tips[0][1] + 5, 60, 8); oseed($tips[2][0] - 4, $tips[2][1] - 4, 230, 8);
write_svg('3-first-growth.svg', 'Spring onions first growth');

# 4. Second growth: a small bunch of hollow blue-green leaves.
soil(200, 200, 34, 30, 4);
bunch(5, 14, 3, 96, 26, 13, 64, 7, 41, 'c3');
write_svg('4-second-growth.svg', 'Spring onions second growth');

# 5. Third growth: a fuller bunch, white shanks thickening.
soil(200, 200, 36, 32, 5);
bunch(7, 18, 3, 124, 34, 15, 70, 9, 51, 'c3');
write_svg('5-third-growth.svg', 'Spring onions third growth');

# 6. Harvest: a tight cluster of tall tube leaves fanning out round thick white shanks.
soil(200, 200, 38, 34, 6);
bunch(8, 22, 4, 148, 36, 18, 76, 13, 61, 'c3');
write_svg('6-harvest.svg', 'Spring onions ready to harvest');

# 7. Harvest, front view: the harvested bundle (inventory item), five spring onions tied with a band.
my @on = ([-2, 168, -16], [-1, 186, -8], [0, 200, 0], [1, 186, 8], [2, 168, 16]);
my @tops; my $BY = 330;
srand(77);
for my $o (@on) {                                    # little roots under each bulb
  my ($k) = @$o; my $bx = 200 + $k * 19;
  for my $j (-3 .. 3) {
    blade($bx + $k * 2 + $j * 3, $BY + 8, 90 + $j * 15 + $k * 6 + rand(8) - 4, 22 + rand(12) - abs($j) * 1.5, 4.5, (rand(1) < 0.5 ? -1 : 1) * 22, 'c3', 'c4');
  }
}
for my $o (sort { abs($b->[0]) <=> abs($a->[0]) } @on) {   # outer onions behind, centre one in front
  my ($k, $l, $bend) = @$o; my $bx = 200 + $k * 19 + $k * 2; my $by = $BY; my $a = -90 - $k * 3.5;
  my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx); my $hw = 9.5; my $H = 128;
  my (@L, @R, @Rin);
  for my $i (0 .. 10) {
    my $t = $i / 10; my $sw = $hw * (1 + 0.6 * sin(pi * min(1, ($t + 0.12) * 2.6)) * ($t < 0.27 ? 1 : 0));
    my ($cx, $cy) = ($bx + $dx * $H * $t, $by + $dy * $H * $t);
    push @L, [$cx - $nx * $sw, $cy - $ny * $sw]; push @R, [$cx + $nx * $sw, $cy + $ny * $sw];
    push @Rin, [$cx + $nx * $sw * 0.3, $cy + $ny * $sw * 0.3];
  }
  my $sw0 = $hw * (1 + 0.6 * sin(pi * 0.312));
  my @bot = map { my $th = pi * $_ / 8; [$bx - $nx * $sw0 * cos($th) - $dx * 11 * sin($th), $by - $ny * $sw0 * cos($th) - $dy * 11 * sin($th)] } 0 .. 8;
  poly('c3', @L, reverse(@R), reverse(@bot));
  poly('c2', @R, reverse(@Rin), [$bx + $nx * $sw0 * 0.3 - $dx * 9, $by + $ny * $sw0 * 0.3 - $dy * 9], @bot[6 .. 8]);
  push @tops, [$bx + $dx * $H, $by + $dy * $H, $a, $l, $bend, $k];
}
for my $t (sort { abs($b->[5]) <=> abs($a->[5]) } @tops) {   # blue-green tops fanning out of the bundle
  my ($tx, $ty, $a, $l, $bend, $k) = @$t; my $fa = $a + $k * 7;
  tube($tx - 4, $ty + 6, $fa - 9, $l * 0.8, 12, $bend - 14, 'c2', 'c1', 'c3');
  tube($tx + 4, $ty + 6, $fa + 9, $l * 0.84, 12, $bend + 14, 'c2', 'c1', 'c3');
  tube($tx, $ty + 6, $fa, $l * 0.95, 13, $bend * 0.5, 'c2', 'c1', 'c3');
}
# the band tying the bundle round the white shanks, with a small knot
my ($y0, $x0, $x1) = (262, 146, 254);
poly('c4', [$x0, $y0 - 7], [$x1, $y0 - 7], [$x1 + 1, $y0 + 7], [$x0 - 1, $y0 + 7]);
poly('c5', [$x0 - 1, $y0 + 2], [$x1 + 1, $y0 + 2], [$x1 + 1, $y0 + 7], [$x0 - 1, $y0 + 7]);
poly('c4', [200, $y0], [184, $y0 - 12], [180, $y0 + 2], [186, $y0 + 9]);
poly('c4', [200, $y0], [216, $y0 - 12], [220, $y0 + 2], [214, $y0 + 9]);
poly('c3', [200, $y0], [185, $y0 - 10], [183, $y0 - 5]);
poly('c5', [200, $y0], [216, $y0 + 4], [214, $y0 + 9]);
poly('c4', [194, $y0 - 6], [206, $y0 - 6], [207, $y0 + 6], [193, $y0 + 6]);
poly('c4', [196, $y0 + 4], [190, $y0 + 26], [195, $y0 + 25], [200, $y0 + 6]);
poly('c4', [204, $y0 + 4], [212, $y0 + 24], [207, $y0 + 25], [200, $y0 + 6]);
write_svg('7-harvest-front.svg', 'Spring onion harvest');

# 8. Dead (never watered): cracked dry soil, the tube leaves collapsed flat, kinked and dried to straw.
soil(200, 200, 54, 46, 8);
srand(83);
for my $i (0 .. 6) {
  my $a = $i * 360 / 7 + rand(20); my ($x, $y) = (200, 200); my (@l, @r);
  for my $k (0 .. 4) {
    my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.2 - $k * 0.35;
    push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
    $x += $dx * 14; $y += $dy * 14;
  }
  poly('c3', @l, [$x, $y], reverse @r);
}
srand(81);
for my $i (0 .. 10) {
  my $a = -90 + $i * 360 / 11 + rand(16) - 8; my $l1 = 34 + rand(20);
  my ($dx, $dy) = dir($a); my $k = (rand(1) < 0.5 ? -1 : 1) * (40 + rand(50));
  tube(200 + $dx * 6, 200 + $dy * 6, $a, $l1 + 6, 9, 0, 'c3', 'c4', '');         # standing part
  tube(200 + $dx * ($l1 + 4), 200 + $dy * ($l1 + 4), $a + $k, 52 + rand(50), 8, $k * 0.7, 'c3', 'c4', '');  # kinked, flopped over
}
for ([194, 196], [207, 203], [199, 208], [204, 192]) { shank_top($_->[0], $_->[1], 5, 'c4'); }
write_svg('8-dead.svg', 'Spring onions died from lack of water');
print "wrote 8 files to $OUT\n";

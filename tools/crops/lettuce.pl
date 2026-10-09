# Lettuce crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/lettuce.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/lettuce';
mkdir 'crops'; mkdir $OUT;
# c1 deep leaf green, c2 lit leaf green, c3 pale cream heart / seed / dry straw, c4 soil brown, c5 crisp lime-green head
my %PAL = (c1 => '#3F8A33', c2 => '#7EC24E', c3 => '#EEF0B4', c4 => '#5A3A22', c5 => '#B9DE62');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A tapered blade (as in wheat) for stems, cotyledon stalks and dead curls.
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

# A broad lettuce leaf: narrow stalk, widest at ~60%, round ruffled (scalloped) tip.
# $ruf = ruffle depth, $rib = class for a pale midrib (or ''), $seed for the ruffle jitter.
sub leaf {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $ruf, $rib, $seed) = @_;
  srand($seed // 1);
  my $n = 30; my $ph = rand(1); my $f = 3 + $len / 30; my (@mid, @l, @r, @nrm);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = 1 - (1 - $i / $n) ** 1.35;           # more samples near the round tip
    $t = $i / $n if $i == 0;
    push @mid, [$px, $py, $t, $a];
    my $t2 = $i < $n ? 1 - (1 - ($i + 1) / $n) ** 1.35 : 1;
    my $step = ($t2 - $t) * $len; my ($dx, $dy) = dir($a);
    $px += $dx * $step; $py += $dy * $step; $a += $bend * ($t2 - $t);
  }
  for my $i (0 .. $n) {
    my ($mx, $my, $t, $aa) = @{$mid[$i]};
    my $c = 0.58;
    my $hw = $t < $c ? $w / 2 * sin(pi / 2 * $t / $c) ** 1.3 : $w / 2 * sqrt(max(0, 1 - (($t - $c) / (1 - $c)) ** 2));
    $hw = max($hw, 1.2) if $i < $n;
    my ($dx, $dy) = dir($aa); my ($nx, $ny) = (-$dy, $dx);
    # ruffle: alternate scallops pushed outward, mostly on the outer part of the leaf
    my $wl = abs(sin(pi * ($f * $t + $ph))) ** 0.6; my $wr = abs(sin(pi * ($f * $t + $ph + 0.5))) ** 0.6;
    my $amp = $ruf * min(1, $t * 1.8);
    my $hl = $hw + $amp * ($wl - 0.4); my $hr = $hw + $amp * ($wr - 0.4);
    my $fw = $t > 0.8 ? ($t - 0.8) * 5 * $amp * (($wl + $wr) / 2 - 0.3) : 0;
    push @l, [$mx + $nx * $hl + $dx * $fw, $my + $ny * $hl + $dy * $fw];
    push @r, [$mx - $nx * $hr + $dx * $fw, $my - $ny * $hr + $dy * $fw];
  }
  my @tip = ($mid[$n][0], $mid[$n][1]);
  my ($dx, $dy) = dir($ang); my $leftLit = lit(-$dy, $dx);
  my @m = map { [$_->[0], $_->[1]] } @mid;
  # the round tip: blend the last edge points of both halves into one ruffled cap
  poly($leftLit ? $dark : $light, @r[0 .. $n - 1], reverse @m);
  poly($leftLit ? $light : $dark, @l[0 .. $n - 1], [($l[$n][0] + $r[$n][0]) / 2, ($l[$n][1] + $r[$n][1]) / 2], reverse @m);
  if ($rib) {
    my @rl; my @rr;
    for my $i (0 .. int($n * 0.7)) {
      my ($mx, $my, $t, $aa) = @{$mid[$i]}; my ($ddx, $ddy) = dir($aa);
      my $rw = $w * 0.045 * (1 - $t / 0.75) + 0.5;
      push @rl, [$mx - $ddy * $rw, $my + $ddx * $rw]; push @rr, [$mx + $ddy * $rw, $my - $ddx * $rw];
    }
    poly($rib, @rl, reverse @rr);
  }
}

# A slender lettuce seed: pointed at both ends, lit half, a dark rib.
sub seed {
  my ($x, $y, $ang, $len, $w, $light, $dark, $rib) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx); my @o;
  for my $i (0 .. 15) {
    my $th = 2 * pi * $i / 16;
    my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * abs(sin($th)) ** 0.2 * (1 - 0.25 * cos($th));
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly($dark, @o);
  my @half = lit($nx, $ny) ? @o[8 .. 15, 0] : @o[0 .. 8];
  poly($light, @half);
  for my $s (-0.22, 0.22) {
    my ($cx, $cy) = ($x + $nx * $w * $s, $y + $ny * $w * $s);
    poly($rib, [$cx - $dx * $len * 0.3 + $nx * 0.9, $cy - $dy * $len * 0.3 + $ny * 0.9], [$cx + $dx * $len * 0.3, $cy + $dy * $len * 0.3],
               [$cx - $dx * $len * 0.3 - $nx * 0.9, $cy - $dy * $len * 0.3 - $ny * 0.9]);
  }
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

# A ring of leaves around (200,200). $off = start radius, $twist rotates leaves off the radial (wrapping).
sub ring {
  my ($n, $start, $off, $len, $lenVar, $w, $bendMax, $light, $dark, $ruf, $rib, $seed, $twist) = @_;
  srand($seed); my @b;
  for my $i (0 .. $n - 1) {
    my $a = $start + $i * 360 / $n + rand(12) - 6;
    push @b, [$a, $len + rand($lenVar), (rand(1) < 0.5 ? -1 : 1) * $bendMax * (0.4 + rand(0.6)), int(rand(1000))];
  }
  for (@b) {
    my ($a, $l, $bd, $s) = @$_; my ($dx, $dy) = dir($a);
    leaf(200 + $dx * $off, 200 + $dy * $off, $a + ($twist // 0), $l, $w, $bd, $light, $dark, $ruf, $rib, $s);
  }
}

# 1. Seeds, front view: a little heap of ribbed lettuce seeds.
for ([150, 300, -6], [250, 302, 184], [200, 308, 2], [174, 270, -24], [228, 272, 204], [200, 236, -84],
     [124, 312, 10], [276, 312, 172]) {
  seed($_->[0], $_->[1], $_->[2], 74, 30, 'c3', 'c4', 'c4');
}
write_svg('1-seeds-front.svg', 'Lettuce seeds');

# 2. Just sown, top down: seeds pressed into small soil pockets.
my @sown = ([164, 166, -30], [240, 164, 40], [202, 210, 100], [152, 240, 150], [250, 240, -60]);
soil($_->[0], $_->[1], 28, 22, int($_->[0] * 7 + $_->[1])) for @sown;
seed($_->[0], $_->[1], $_->[2], 40, 16, 'c3', 'c4', 'c4') for @sown;
write_svg('2-sown.svg', 'Lettuce just sown');

# 3. First growth: two oval seed leaves and the first small ruffled true leaves.
soil(200, 200, 34, 30, 3);
leaf(200, 200, -150, 52, 36, 0, 'c5', 'c2', 0, '', 31);
leaf(200, 200, 30, 52, 36, 0, 'c5', 'c2', 0, '', 32);
leaf(200, 200, -62, 80, 58, 8, 'c2', 'c1', 5, '', 33);
leaf(200, 200, 112, 74, 54, -8, 'c2', 'c1', 5, '', 34);
leaf(200, 200, -100, 34, 26, 0, 'c5', 'c2', 3, '', 35);
write_svg('3-first-growth.svg', 'Lettuce first growth');

# 4. Second growth: an open rosette of broad ruffled leaves.
soil(200, 200, 34, 30, 4);
ring(6, -70, 4, 112, 12, 96, 16, 'c2', 'c1', 8, 'c3', 41);
ring(4, -25, 2, 62, 10, 58, 12, 'c5', 'c2', 6, '', 42);
write_svg('4-second-growth.svg', 'Lettuce second growth');

# 5. Third growth: a full rosette, the inner leaves starting to cup into a head.
soil(200, 200, 34, 30, 5);
ring(8, -80, 6, 140, 12, 116, 18, 'c2', 'c1', 9, 'c3', 51);
ring(6, -50, 4, 96, 10, 90, 16, 'c5', 'c2', 8, 'c3', 52);
ring(5, -20, 4, 52, 6, 56, 0, 'c3', 'c5', 5, '', 53, 50);
write_svg('5-third-growth.svg', 'Lettuce third growth');

# 6. Harvest: a full crisp head, layer on layer of ruffled leaves around a pale heart.
ring(10, -90, 8, 164, 12, 128, 18, 'c2', 'c1', 11, 'c3', 61);
ring(8, -68, 6, 124, 10, 112, 16, 'c5', 'c2', 9, 'c3', 62);
ring(7, -40, 6, 88, 8, 92, 0, 'c5', 'c2', 7, '', 63, 30);
ring(6, -10, 4, 56, 6, 70, 0, 'c3', 'c5', 5, '', 64, 55);
ring(4, 20, 2, 32, 4, 44, 0, 'c3', 'c5', 3, '', 65, 70);
write_svg('6-harvest.svg', 'Lettuce ready to harvest');

# 7. Harvest, front view: one harvested lettuce head (inventory item), crisp ruffled leaves and a cut base.
for ([-160, 128, -10], [-20, 128, 10]) {                                               # loose outer leaves curling up
  leaf(200, 334, $_->[0], $_->[1], 96, $_->[2] < 0 ? 22 : -22, 'c2', 'c1', 10, 'c3', int($_->[0] * -3 + 7));
}
for ([-128, 160, -10], [-52, 160, 10]) {                                               # back of the head
  leaf(200, 336, $_->[0], $_->[1], 126, $_->[2], 'c2', 'c1', 10, 'c3', int($_->[0] * -5 + 3));
}
leaf(196, 336, -100, 196, 156, 6, 'c5', 'c2', 9, 'c3', 71);                            # crisp inner head leaves
leaf(204, 336, -80, 196, 156, -6, 'c5', 'c2', 9, 'c3', 72);
leaf(200, 234, -90, 64, 82, 0, 'c3', 'c5', 6, '', 75);                                 # pale heart at the crown
leaf(196, 340, -118, 140, 100, -16, 'c2', 'c1', 10, 'c3', 73);                        # front wrapper leaves
leaf(204, 340, -62, 140, 100, 16, 'c2', 'c1', 10, 'c3', 74);
leaf(200, 342, -90, 96, 92, 0, 'c5', 'c2', 9, 'c3', 76);
# the cut stem under the head: a short pale stub with its flat cut face
poly('c3', [184, 334], [200, 334], [200, 360], [187, 358]);
poly('c5', [200, 334], [216, 334], [213, 358], [200, 360]);
my @cut = map { my $th = 2 * pi * $_ / 10; [200 + cos($th) * 13.5, 359 + sin($th) * 4.5] } 0 .. 9;
poly('c3', @cut);
poly('c5', [196, 358], [204, 358], [200, 361]);
write_svg('7-harvest-front.svg', 'Lettuce harvest');

# 8. Dead (never watered): cracked dry soil and a collapsed, shrivelled straw-brown rosette.
soil(200, 200, 70, 60, 8);
srand(83);
for my $i (0 .. 7) {
  my $a = $i * 360 / 8 + rand(20); my ($x, $y) = (200, 200); my (@l, @r);
  for my $k (0 .. 4) {
    my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.4 - $k * 0.4;
    push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
    $x += $dx * 16; $y += $dy * 16;
  }
  poly('c3', @l, [$x, $y], reverse @r);
}
srand(81); my @dl;
for my $i (0 .. 6) {
  my $a = -80 + $i * 360 / 7 + rand(20) - 10;
  push @dl, [$a, 76 + rand(40), 26 + rand(10), ($i % 2 ? -1 : 1) * (30 + rand(40)), int(rand(999))];
}
leaf(200, 200, $_->[0], $_->[1], $_->[2], $_->[3], 'c3', 'c4', 10, '', $_->[4]) for sort { $b->[1] <=> $a->[1] } @dl;
for my $i (0 .. 4) { my $a = -20 + $i * 72 + rand(20); blade(200, 200, $a, 30, 11, ($i % 2 ? 90 : -90), 'c3', 'c4'); }
write_svg('8-dead.svg', 'Lettuce died from lack of water');
print "wrote 8 files to $OUT\n";

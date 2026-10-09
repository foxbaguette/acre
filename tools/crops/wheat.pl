# Wheat crop art: 7 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/wheat.pl
# Top-down stages (2-6) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/wheat';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#5E9A3A', c2 => '#8CC456', c3 => '#F2D58A', c4 => '#5A3A22', c5 => '#D9A23A');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?

# A tapered leaf blade or stalk from (x,y) heading `ang`, bending `bend` degrees over its length.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark) = @_;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $t) ** 0.85 + ($i == $n ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# One wheat grain (kernel), seen from the side/top, with a lit half and a crease.
sub grain {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 15) {
    my $th = 2 * pi * $i / 16;
    my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 - 0.18 * cos($th) ** 2);
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly('c5', @o);
  my $leftLit = lit($nx, $ny);
  my @half = $leftLit ? @o[8 .. 15, 0] : @o[0 .. 8];
  poly('c3', @half);
  my @cr = ([$x - $dx * $len * 0.26, $y - $dy * $len * 0.26], [$x + $dx * $len * 0.26, $y + $dy * $len * 0.26]);
  poly('c4', [$cr[0][0] + $nx * 1.2, $cr[0][1] + $ny * 1.2], [$cr[1][0] + $nx * 1.2, $cr[1][1] + $ny * 1.2],
             [$cr[1][0] - $nx * 1.2, $cr[1][1] - $ny * 1.2], [$cr[0][0] - $nx * 1.2, $cr[0][1] - $ny * 1.2]);
}

# A wheat ear (spike): alternating spikelets along the axis plus awns at the tip.
sub ear {
  my ($x, $y, $ang, $len, $w, $light, $dark, $awn) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $n = 7;
  blade($x - $dx * 6, $y - $dy * 6, $ang, $len * 0.25, $w * 0.35, 0, $light, $dark);   # neck
  # solid ear body under the spikelets so the head reads as one plump shape
  my (@bl, @br);
  for my $i (0 .. 10) {
    my $t = $i / 10; my $hw = $w * 0.42 * sin(pi * (0.08 + 0.86 * $t)) ** 0.7;
    my $cx = $x + $dx * $len * $t; my $cy = $y + $dy * $len * $t;
    push @bl, [$cx + $nx * $hw, $cy + $ny * $hw]; push @br, [$cx - $nx * $hw, $cy - $ny * $hw];
  }
  poly($dark, @bl, reverse @br);
  for my $i (0 .. $n - 1) {
    my $t = ($i + 0.5) / $n;
    my $cx = $x + $dx * $len * $t; my $cy = $y + $dy * $len * $t;
    my $side = $i % 2 ? 1 : -1;
    my $sw = $w * (0.55 + 0.45 * sin(pi * min(1, $t * 1.25)));
    my $sl = $len / $n * 2.5;
    my $ox = $cx + $nx * $side * $sw * 0.22; my $oy = $cy + $ny * $side * $sw * 0.22;
    my @d = ([$ox - $dx * $sl * 0.5, $oy - $dy * $sl * 0.5],
             [$ox + $nx * $side * $sw * 0.5, $oy + $ny * $side * $sw * 0.5],
             [$ox + $dx * $sl * 0.5, $oy + $dy * $sl * 0.5],
             [$ox - $nx * $side * $sw * 0.18, $oy - $ny * $side * $sw * 0.18]);
    my $isLit = lit($nx * $side, $ny * $side);
    poly($isLit ? $light : $dark, @d);
    if ($awn) {
      my $aa = $ang + $side * 16; my ($ax, $ay) = dir($aa);
      my @tip = ($ox + $dx * $sl * 0.5, $oy + $dy * $sl * 0.5);
      poly($awn, [$tip[0] - $nx * 0.9, $tip[1] - $ny * 0.9], [$tip[0] + $ax * $len * 0.42, $tip[1] + $ay * $len * 0.42],
                 [$tip[0] + $nx * 0.9, $tip[1] + $ny * 0.9]);
    }
  }
  # top spikelet
  my @tp = ($x + $dx * $len, $y + $dy * $len);
  poly($dark, [$tp[0] - $dx * 10 + $nx * 4, $tp[1] - $dy * 10 + $ny * 4], [$tp[0] + $dx * 6, $tp[1] + $dy * 6],
              [$tp[0] - $dx * 10 - $nx * 4, $tp[1] - $dy * 10 - $ny * 4]);
}
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }

# Small irregular patch of soil.
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

# 1. Seeds, front view: a small heap of kernels.
grain(150, 268, -12, 96, 52); grain(250, 270, 192, 96, 52); grain(200, 286, 4, 100, 54);
grain(176, 222, -28, 92, 50); grain(232, 224, 205, 92, 50); grain(204, 180, -80, 90, 48);
write_svg('1-seeds-front.svg', 'Wheat seeds');

# 2. Just sown, top down: kernels pressed into small soil pockets.
my @sown = ([166, 168, -30], [240, 162, 40], [202, 212, 95], [150, 240, 150], [252, 238, -60]);
for (@sown) { soil($_->[0], $_->[1], 30, 24, int($_->[0] * 7 + $_->[1])); }
for (@sown) { grain($_->[0], $_->[1], $_->[2], 46, 25); }
write_svg('2-sown.svg', 'Wheat just sown');

# A grass tuft: $n blades with seeded jitter in angle, length and bend.
sub tuft {
  my ($n, $len, $lenVar, $w, $bendMax, $light, $dark, $seed, $start) = @_;
  srand($seed);
  my @b;
  for my $i (0 .. $n - 1) {
    my $a = ($start // -90) + $i * 360 / $n + rand(18) - 9;
    my $l = $len + rand($lenVar);
    my $bend = (rand(1) < 0.5 ? -1 : 1) * ($bendMax * (0.5 + rand(0.5)));
    push @b, [$a, $l, $bend];
  }
  # draw longer blades first so short ones sit on top
  blade(200, 200, $_->[0], $_->[1], $w, $_->[2], $light, $dark) for sort { $b->[1] <=> $a->[1] } @b;
}

# 3. First growth, top down: a few young shoots from a soil pocket.
soil(200, 200, 34, 30, 3);
tuft(5, 70, 26, 12, 22, 'c2', 'c1', 31, -80);
write_svg('3-first-growth.svg', 'Wheat first growth');

# 4. Second growth, top down: a leafy grass tuft.
soil(200, 200, 34, 30, 4);
tuft(11, 104, 40, 13, 34, 'c2', 'c1', 41);
write_svg('4-second-growth.svg', 'Wheat second growth');

# 5. Third growth, top down: tall leaves with green ears forming.
soil(200, 200, 34, 30, 5);
tuft(15, 132, 40, 13, 38, 'c2', 'c1', 51);
for my $i (0 .. 5) { my $a = -60 + $i * 60 + ($i % 2 ? 12 : -8); my ($dx, $dy) = dir($a); ear(200 + $dx * 24, 200 + $dy * 24, $a, 74, 22, 'c2', 'c1', 0); }
write_svg('5-third-growth.svg', 'Wheat third growth');

# 6. Harvest, top down: dry golden leaves and heavy ripe ears with awns.
soil(200, 200, 34, 30, 6);
tuft(10, 118, 30, 12, 36, 'c3', 'c5', 61, -75);
for my $i (0 .. 9) { my $a = -90 + $i * 36 + ($i % 2 ? 9 : -5); my ($dx, $dy) = dir($a); ear(200 + $dx * 30, 200 + $dy * 30, $a, 100, 36, 'c3', 'c5', 'c5'); }
write_svg('6-harvest.svg', 'Wheat ready to harvest');

# 7. Harvested produce, front view: a wheat sheaf tied in the middle, ears fanning out on top.
my ($bx, $by) = (200, 262);                       # where the band ties the bundle
my @sheaf = (-128, -114, -101, -90, -79, -66, -52); # stalk angles above the band
# lower stalks: from the band down to the cut ends, spreading slightly
for my $i (0 .. 6) {
  my $ex = $bx + ($i - 3) * 11; my $ey = 372;
  my $a = rad2deg(atan2($ey - $by, $ex - $bx));
  blade($bx + ($i - 3) * 3, $by, $a, sqrt(($ex - $bx) ** 2 + ($ey - $by) ** 2), 10, 0, 'c3', 'c5');
}
for my $i (0 .. 6) {                               # cut stalk ends
  my $ex = $bx + ($i - 3) * 11; my $ey = 372;
  my @o; for my $k (0 .. 7) { my $th = 2 * pi * $k / 8; push @o, [$ex + cos($th) * 5.5, $ey + sin($th) * 3]; }
  poly('c4', @o);
}
# upper stalks and ears
for my $i (0 .. $#sheaf) {
  my $a = $sheaf[$i]; my $len = 92 - abs($i - 3) * 9;
  blade($bx + ($i - 3) * 3, $by, $a, $len, 9, ($i - 3) * 3, 'c3', 'c5');
}
for my $i (0 .. $#sheaf) {
  my $a = $sheaf[$i]; my $len = 92 - abs($i - 3) * 9;
  my ($dx, $dy) = dir($a + ($i - 3) * 1.5);
  ear($bx + ($i - 3) * 3 + $dx * $len, $by + $dy * $len, $a + ($i - 3) * 3, 96, 34, 'c3', 'c5', 'c5');
}
# the band: a twisted straw tie (dark wrap with a lit edge)
poly('c4', [$bx - 34, $by - 9], [$bx + 34, $by - 13], [$bx + 36, $by + 9], [$bx - 36, $by + 12]);
poly('c5', [$bx - 34, $by - 9], [$bx + 34, $by - 13], [$bx + 34, $by - 6], [$bx - 34, $by - 2]);
poly('c4', [$bx + 26, $by + 6], [$bx + 44, $by + 30], [$bx + 36, $by + 32], [$bx + 20, $by + 10]);
write_svg('7-harvest-front.svg', 'Harvested wheat sheaf');

# 8. Dead (never watered), top down: cracked dry soil and a withered, curled tuft.
soil(200, 200, 56, 48, 8);
srand(83);
for my $i (0 .. 6) {                       # pale cracks running out through the dry soil
  my $a = $i * 360 / 7 + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
  for my $k (0 .. 4) {
    my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.2 - $k * 0.35;
    push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
    $x += $dx * 13; $y += $dy * 13;
  }
  poly('c3', @l, [$x, $y], reverse @r);
}
srand(81);
my @dead;
for my $i (0 .. 9) {
  my $a = -90 + $i * 36 + rand(16) - 8;
  push @dead, [$a, 78 + rand(40), (rand(1) < 0.5 ? -1 : 1) * (48 + rand(42))];
}
blade(200, 200, $_->[0], $_->[1], 13, $_->[2], "c3", "c5") for sort { $b->[1] <=> $a->[1] } @dead;
for ([-30, 22], [100, 18], [210, 20]) { blade(200, 200, $_->[0], $_->[1], 11, 0, "c3", "c5"); }  # broken stubs
write_svg('8-dead.svg', 'Wheat died from lack of water');
print "wrote 8 files to $OUT\n";

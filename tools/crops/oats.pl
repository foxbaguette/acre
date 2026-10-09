# Oats crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/oats.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Oats vs wheat/rye/rice: no dense ear at all. The head is an open, airy PANICLE: thin branching threads, each
# ending in a dangling spikelet (a pair of papery husks like a little bell). Leaves are broad. Ripens pale cream.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/oats';
mkdir 'crops'; mkdir $OUT;
# c1 leaf green, c2 lit green, c3 pale cream (lit husks, grain), c4 dark soil brown, c5 pale straw (shaded husks, threads)
my %PAL = (c1 => '#5A8D3C', c2 => '#97C460', c3 => '#F6EFD3', c4 => '#5A3A22', c5 => '#BC9E5E');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A tapered leaf blade or stalk from (x,y) heading `ang`, bending `bend` degrees (as in wheat.pl). $taper < 1 = cut end.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $taper) = @_;
  $taper //= 1;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $t) ** 0.85 + ($i == $n && $taper == 1 ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
  return ($px, $py, $a - $bend / $n);
}

# A broad oat leaf: widest a little above the base, long pointed tip.
sub leaf {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark) = @_;
  my $n = 12; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * ($t < 0.18 ? 0.55 + 0.45 * $t / 0.18 : max(0, 1 - ($t - 0.18) / 0.82) ** 0.75);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# One papery husk: a slim teardrop from (x,y) heading `ang`, lit and shaded halves.
sub husk {
  my ($x, $y, $ang, $len, $w, $light, $dark) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my (@l, @r);
  for my $i (0 .. 8) {
    my $t = $i / 8; my $hw = $w / 2 * sin(pi * $t ** 0.8) ** 0.9;
    my ($cx, $cy) = ($x + $dx * $len * $t, $y + $dy * $len * $t);
    push @l, [$cx + $nx * $hw, $cy + $ny * $hw]; push @r, [$cx - $nx * $hw, $cy - $ny * $hw];
  }
  my $leftLit = lit($nx, $ny);
  poly($leftLit ? $light : $dark, @l);
  poly($leftLit ? $dark : $light, @r);
}

# A spikelet: two husks splayed into a little bell, hanging from (x,y) along `ang`.
sub spikelet {
  my ($x, $y, $ang, $len, $w, $light, $dark) = @_;
  my ($dx, $dy) = dir($ang); my $pl = lit(-$dy, $dx) ? 1 : -1;   # which husk of the pair faces the light
  husk($x, $y, $ang - $pl * 13, $len * 0.92, $w * 0.6, $dark, $dark);
  husk($x, $y, $ang + $pl * 13, $len, $w * 0.62, $light, $light);
}

# An oat panicle. (x,y) = where the head starts, `ang` = axis heading, `bend` = curve of the axis.
# $front: branches droop to hang their spikelets straight down (side view); otherwise they splay outward (top down).
sub panicle {
  my ($x, $y, $ang, $len, $bend, $sz, $thread, $light, $dark, $seed, $front) = @_;
  srand($seed);
  my $n = 10; my @p; my $a = $ang; my ($px, $py) = ($x, $y);
  for my $i (0 .. $n) { push @p, [$px, $py, $a]; my ($dx, $dy) = dir($a); $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n; }
  my @sp; my @br;
  my $side = 1;
  for my $k ($front ? ([3, 2], [5, 2], [8, 2]) : ([2, 2], [4, 2], [6, 2], [8, 2], [9, 1])) {
    my ($i, $m) = @$k; my ($cx, $cy, $ca) = @{$p[$i]};
    for my $j (1 .. $m) {
      $side = -$side;
      my $spread = 30 + rand(28);
      my $ba = $ca + $side * $spread;
      my $bl = $sz * ($front ? 2.6 + rand(1.2) : 1.7 + rand(0.8)) * (1.2 - 0.5 * $i / $n);
      my $bb;
      if ($front) { my $d = ((90 - $ba + 540) % 360) - 180; $bb = $d * 0.75; }   # droop toward straight down
      else { $bb = $side * (10 + rand(14)); }
      push @br, [$cx, $cy, $ba, $bl, $bb];
    }
  }
  # threads
  my @mid;
  for (@br) {
    my ($cx, $cy, $ba, $bl, $bb) = @$_;
    my @e = blade($cx, $cy, $ba, $bl, 3.4, $bb, $thread, $thread, 0.4); push @sp, [@e];
    next unless $bl > $sz * 2.7;                          # longer threads carry a second spikelet halfway
    my ($mx, $my, $ma) = ($cx, $cy, $ba);
    for (1 .. 5) { my ($dx, $dy) = dir($ma); $mx += $dx * $bl / 10; $my += $dy * $bl / 10; $ma += $bb / 10; }
    push @mid, [$mx, $my, $ma + ($bb > 0 ? 34 : -34)];
  }
  unshift @sp, @mid;
  my @ax = @{$p[$n]};
  blade($x, $y, $ang, $len, 3.8, $bend, $thread, $thread, 0.5);
  push @sp, [@ax];
  # spikelets (a second one sometimes rides partway along the thread)
  for (@sp) {
    my ($ex, $ey, $ea) = @$_;
    my $ha = $front ? 90 + ($ea - 90) * 0.2 : $ea;
    spikelet($ex, $ey, $ha, $sz * 2.2, $sz * 1.25, $light, $dark);
  }
}

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

# A tuft of broad leaves (longest drawn first).
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
  leaf(200, 200, $_->[0], $_->[1], $w, $_->[2], $light, $dark) for sort { $b->[1] <=> $a->[1] } @b;
}

# A plump husked oat grain: a spindle pointed at both ends, lit half, a groove line and a fine tip hair.
sub grain {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  # half-width profile: blunt at the base (-u), drawn out to a point at the tip (+u)
  my $hv = sub { my $c = shift; sqrt(max(0, 1 - $c * $c)) * (1 - 0.15 * $c * $c) * ($c > 0 ? 1 - 0.35 * $c ** 2 : 1) };
  my @o;
  for my $i (0 .. 19) {
    my $th = 2 * pi * $i / 20; my $c = cos($th);
    my $u = $c * $len / 2; my $v = ($i <= 10 ? 1 : -1) * $w / 2 * $hv->($c);
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly('c5', @o);
  my $k = lit($nx, $ny) ? 1 : -1;                    # +1: the +n half faces the light
  poly('c3', $k > 0 ? @o[0 .. 10] : (@o[10 .. 19], $o[0]));
  # fine husk ridges along the lit half, a groove just inside the shaded half
  for my $r ([0.14, 1.3]) {
    my ($f, $hw) = @$r; my (@a, @b);
    for my $j (0 .. 6) {
      my $c = -0.72 + 1.38 * $j / 6; my $v = $k * $f * $w * $hv->($c);
      my ($px, $py) = ($x + $dx * $c * $len / 2 + $nx * $v, $y + $dy * $c * $len / 2 + $ny * $v);
      my $h = $hw * sin(pi * $j / 6) + 0.2;
      push @a, [$px + $nx * $h, $py + $ny * $h]; push @b, [$px - $nx * $h, $py - $ny * $h];
    }
    poly('c5', @a, reverse @b);
  }
}

# A rolled oat flake: an irregular flat disc, cream on top with a shaded straw rim below.
sub flake {
  my ($x, $y, $r, $rot, $seed) = @_;
  srand($seed); my @o;
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12 + deg2rad($rot); my $k = 0.82 + rand(0.26); push @o, [$x + cos($th) * $r * $k, $y + sin($th) * $r * 0.62 * $k]; }
  poly('c5', map { [$_->[0] + 1.5, $_->[1] + 5] } @o);
  poly('c3', @o);
  poly('c5', [$x - $r * 0.3, $y - $r * 0.05], [$x + $r * 0.25, $y - $r * 0.14], [$x + $r * 0.3, $y - $r * 0.06], [$x - $r * 0.25, $y + $r * 0.04]);
}

# 1. Seeds, front view: plump pale husked oat grains with a few rolled flakes in front.
grain(150, 236, -28, 132, 46); grain(250, 232, 212, 130, 45); grain(208, 214, -40, 126, 44);
grain(124, 276, -4, 134, 47);  grain(276, 278, 184, 134, 47); grain(200, 266, 8, 132, 46);
flake(150, 334, 38, 10, 1); flake(250, 336, 36, -20, 2);
write_svg('1-seeds-front.svg', 'Oat seeds');

# 2. Just sown, top down: plump grains pressed into small soil pockets.
my @sown = ([164, 166, -40], [242, 164, 30], [202, 214, 100], [148, 242, 150], [254, 240, -70]);
for (@sown) { soil($_->[0], $_->[1], 30, 24, int($_->[0] * 7 + $_->[1])); }
for (@sown) { grain($_->[0], $_->[1], $_->[2], 44, 18); }
write_svg('2-sown.svg', 'Oats just sown');

# 3. First growth, top down: a few broad young leaves.
soil(200, 200, 34, 30, 3);
tuft(4, 68, 22, 15, 24, 'c2', 'c1', 31, -70);
write_svg('3-first-growth.svg', 'Oats first growth');

# 4. Second growth, top down: a leafy tuft of broad, softly arching leaves.
soil(200, 200, 34, 30, 4);
tuft(9, 100, 34, 20, 40, 'c2', 'c1', 41);
write_svg('4-second-growth.svg', 'Oats second growth');

# 5. Third growth, top down: broad leaves with open green panicles of little dangling spikelets.
soil(200, 200, 34, 30, 5);
tuft(11, 118, 30, 21, 42, 'c2', 'c1', 51);
for my $i (0 .. 4) { my $a = -60 + $i * 72 + ($i % 2 ? 10 : -8); my ($dx, $dy) = dir($a);
  panicle(200 + $dx * 40, 200 + $dy * 40, $a, 84, ($i % 2 ? 14 : -14), 9, 'c1', 'c2', 'c1', 50 + $i, 0); }
write_svg('5-third-growth.svg', 'Oats third growth');

# 6. Harvest, top down: wide airy cream panicles hung with papery spikelets over broad leaves.
soil(200, 200, 34, 30, 6);
tuft(9, 104, 26, 20, 40, 'c3', 'c5', 61, -70);
for my $i (0 .. 5) { my $a = -80 + $i * 60 + ($i % 2 ? 9 : -6); my ($dx, $dy) = dir($a);
  panicle(200 + $dx * 30, 200 + $dy * 30, $a, 124, ($i % 2 ? 18 : -18), 13, 'c5', 'c3', 'c5', 60 + $i, 0); }
write_svg('6-harvest.svg', 'Oats ready to harvest');

# 7. Harvested produce, front view: a bundle of oat stalks tied together, loose panicles dangling their spikelets.
my ($bx, $by) = (200, 270);
for my $i (0 .. 5) {
  my $ex = $bx + ($i - 2.5) * 11; my $ey = 384;
  my $a = rad2deg(atan2($ey - $by, $ex - $bx));
  blade($bx + ($i - 2.5) * 3, $by, $a, sqrt(($ex - $bx) ** 2 + ($ey - $by) ** 2), 10, 0, 'c3', 'c5');
}
for my $i (0 .. 5) { my $ex = $bx + ($i - 2.5) * 11; my @o; for my $k (0 .. 7) { my $th = 2 * pi * $k / 8; push @o, [$ex + cos($th) * 5, 384 + sin($th) * 2.8]; } poly('c4', @o); }
my @st = ([-136, 70, 24], [-114, 104, 12], [-91, 124, 2], [-68, 104, -12], [-46, 70, -24]);
my @heads;
for my $i (0 .. $#st) { my ($a, $len, $b) = @{$st[$i]}; push @heads, [blade($bx + ($i - 2) * 3, $by, $a, $len, 8, $b * 0.4, 'c3', 'c5'), $b]; }
for my $i (0 .. $#heads) { my ($x, $y, $a, $b) = @{$heads[$i]}; panicle($x, $y, $a, 100, $b, 15, 'c5', 'c3', 'c5', 70 + $i, 1); }
poly('c4', [$bx - 26, $by - 8], [$bx + 26, $by - 10], [$bx + 27, $by + 8], [$bx - 27, $by + 10]);
poly('c5', [$bx - 26, $by - 8], [$bx + 26, $by - 10], [$bx + 26, $by - 4], [$bx - 26, $by - 2]);
poly('c4', [$bx + 18, $by + 6], [$bx + 34, $by + 32], [$bx + 27, $by + 34], [$bx + 12, $by + 10]);
write_svg('7-harvest-front.svg', 'Harvested oats bundle');

# 8. Dead (never watered), top down: cracked dry soil and broad leaves withered to straw, curled and lying flat.
soil(200, 200, 56, 48, 8);
srand(83);
for my $i (0 .. 6) {
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
for my $i (0 .. 8) { my $a = -90 + $i * 40 + rand(16) - 8; push @dead, [$a, 76 + rand(40), (rand(1) < 0.5 ? -1 : 1) * (60 + rand(50))]; }
leaf(200, 200, $_->[0], $_->[1], 15, $_->[2], 'c3', 'c5') for sort { $b->[1] <=> $a->[1] } @dead;
for ([-30, 20], [100, 17], [210, 19]) { blade(200, 200, $_->[0], $_->[1], 10, 0, 'c3', 'c5'); }
write_svg('8-dead.svg', 'Oats died from lack of water');
print "wrote 8 files to $OUT\n";

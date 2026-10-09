# Paddy rice crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/rice.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/rice';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#2E7444', c2 => '#7CC264', c3 => '#F7E9B0', c4 => '#3F2D22', c5 => '#DDA93E');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub ell { my ($x, $y, $rx, $ry, $n, $rot) = @_; $rot //= 0; map { my ($u, $v) = dir($rot + $_ * 360 / $n); [$x + $u * $rx, $y + $v * $ry] } 0 .. $n - 1 }

# A tapered blade / stalk from (x,y) heading `ang`, bending `bend` degrees over its length.
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
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# Points [x, y, heading] along a bent path (same stepping as blade).
sub path {
  my ($x, $y, $ang, $len, $bend, $n) = @_; $n //= 10; my @p; my $a = $ang;
  for my $i (0 .. $n) { push @p, [$x, $y, $a]; my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  @p;
}

# One narrow leaf segment (a slim diamond) split into a lit and a shaded half.
# Small irregular patch of soil.
sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o;
  srand($seed);
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12; my $k = 0.82 + rand(0.3); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
}
# Pale cracks running out through dry soil.
sub cracks {
  my ($n, $seed) = @_; srand($seed);
  for my $i (0 .. $n - 1) {
    my $a = $i * 360 / $n + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
    for my $k (0 .. 4) {
      my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.2 - $k * 0.35;
      push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
      $x += $dx * 13; $y += $dy * 13;
    }
    poly('c3', @l, [$x, $y], reverse @r);
  }
}
sub write_svg {
  my ($file, $label) = @_;
  open my $fh, '>', "$OUT/$file" or die $!;
  print $fh qq{<?xml version="1.0" encoding="UTF-8"?>\n<svg viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="$label">\n  <style>\n};
  print $fh "    .$_ { fill: var(--$_, $PAL{$_}); }\n" for qw(c1 c2 c3 c4 c5);
  print $fh "  </style>\n  <g transform=\"translate(0 0)\">\n", join("\n", @S), "\n  </g>\n</svg>\n";
  close $fh; @S = ();
}

# A wet paddy pocket: dark soaked soil with a few pale water glints (ripple arcs) catching the light.
sub wet {
  my ($x, $y, $rx, $ry, $seed) = @_;
  soil($x, $y, $rx, $ry, $seed);
  for my $g ([-0.42, -0.4, 0.5, 200, 250], [-0.12, -0.6, 0.34, 225, 280], [0.36, 0.42, 0.36, 20, 70], [-0.55, 0.18, 0.28, 150, 200]) {
    my ($ox, $oy, $r, $a0, $a1) = @$g; my ($cx, $cy) = ($x + $ox * $rx, $y + $oy * $ry); my $R = $r * $rx;
    my (@o, @i);
    for my $k (0 .. 6) { my $a = $a0 + ($a1 - $a0) * $k / 6; my ($u, $v) = dir($a); my $t = sin(pi * $k / 6);
      push @o, [$cx + $u * $R, $cy + $v * $R * 0.7]; push @i, [$cx + $u * ($R - 4 * $t), $cy + $v * ($R - 4 * $t) * 0.7]; }
    poly('c3', @o, reverse @i);
  }
}

# A rice grain (spikelet): slim pointed oval with a lit half, a hull seam and a tiny dark tip.
sub rgrain {
  my ($x, $y, $ang, $len, $w, $light, $dark, $tip) = @_; $light //= 'c3'; $dark //= 'c5';
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 13) { my $th = 2 * pi * $i / 14; my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 - 0.15 * cos($th));
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v]; }
  poly($dark, @o);
  my $lLit = lit($nx, $ny);
  poly($light, $lLit ? @o[0 .. 7] : (@o[7 .. 13], $o[0]));
  if ($len > 14) {                                                         # hull seam
    my $s = $len * 0.34; my $h = max(0.6, $w * 0.06);
    poly($dark, [$x - $dx * $s + $nx * $h, $y - $dy * $s + $ny * $h], [$x + $dx * $s + $nx * $h, $y + $dy * $s + $ny * $h], [$x + $dx * $s - $nx * $h, $y + $dy * $s - $ny * $h], [$x - $dx * $s - $nx * $h, $y - $dy * $s - $ny * $h]);
  }
  if ($len > 40) { for my $r (0.5, -0.45) { my $off = $r * $w * 0.5 * ($lLit ? 1 : -1); my $s = $len * 0.3; my $h = 0.6;
    poly($r > 0 ? $dark : $light, [$x - $dx * $s + $nx * ($off + $h), $y - $dy * $s + $ny * ($off + $h)], [$x + $dx * $s + $nx * ($off + $h), $y + $dy * $s + $ny * ($off + $h)], [$x + $dx * $s + $nx * ($off - $h), $y + $dy * $s + $ny * ($off - $h)], [$x - $dx * $s + $nx * ($off - $h), $y - $dy * $s + $ny * ($off - $h)]); } }
  my $tc = $tip // $dark; my ($tx, $ty) = ($x + $dx * $len / 2, $y + $dy * $len / 2);   # apiculus
  poly($tc, [$tx - $nx * $w * 0.16, $ty - $ny * $w * 0.16], [$tx + $dx * $len * 0.08, $ty + $dy * $len * 0.08], [$tx + $nx * $w * 0.16, $ty + $ny * $w * 0.16]);
}

# A drooping rice panicle: a thin arching axis, short side branches, grains hanging in loose rows.
sub panicle {
  my ($x, $y, $ang, $len, $bend, %o) = @_;
  my $L = $o{light} // 'c3'; my $D = $o{dark} // 'c5'; my $AL = $o{al} // $L; my $AD = $o{ad} // $D;
  my $gl = $o{gl} // $len * 0.1; my $gw = $o{gw} // $gl * 0.48; my $nb = $o{nb} // 7;
  my @p = path($x, $y, $ang, $len, $bend, 20);
  blade($x, $y, $ang, $len, $o{aw} // 3, $bend, $AL, $AD);
  my @g;
  for my $b (0 .. $nb - 1) {
    my $t = 0.18 + 0.8 * $b / $nb; my ($px, $py, $pa) = @{$p[int($t * 20)]};
    my $side = $b % 2 ? 1 : -1; my $bl = $len * ($o{bk} // 0.24) * (1 - 0.55 * $t) + $len * 0.05;
    my $ba = $pa + $side * ($o{spread} // 26);
    blade($px, $py, $ba, $bl, 1.8, -$side * 10 + $bend * 0.3, $AL, $AD);
    my @q = path($px, $py, $ba, $bl, -$side * 10 + $bend * 0.3, 6);
    for my $k (1 .. 5) { my ($qx, $qy, $qa) = @{$q[$k + 1 > 6 ? 6 : $k + 1]}; my $s2 = $k % 2 ? 1 : -1; my ($ux, $uy) = dir($qa + 90);
      push @g, [$qx + $ux * $s2 * $gw * 0.4, $qy + $uy * $s2 * $gw * 0.4, $qa + $s2 * 12]; }
  }
  my ($ex, $ey, $ea) = @{$p[20]};                                         # grains at the tip
  push @g, [$ex, $ey, $ea], [@{$p[18]}[0, 1], $p[18][2] + 20], [@{$p[18]}[0, 1], $p[18][2] - 20];
  rgrain($_->[0], $_->[1], $_->[2], $gl, $gw, $L, $D, $o{tip}) for @g;
}

# A rice clump: many narrow arching leaves fanning out from the tillers, in two layers.
sub clump {
  my ($n, $len, $var, $w, $bendMax, $light, $dark, $seed, %o) = @_; srand($seed); my @b;
  for my $i (0 .. $n - 1) {
    my $a = ($o{start} // -90) + $i * 360 / $n + rand(16) - 8;
    my $l = $len * ($i % 2 ? 0.78 : 1) + rand($var);
    push @b, [$a, $l, (rand(1) < 0.5 ? -1 : 1) * $bendMax * (0.6 + rand(0.4))];
  }
  for (sort { $b->[1] <=> $a->[1] } @b) { my ($dx, $dy) = dir($_->[0]); blade(200 + $dx * 5, 200 + $dy * 5, @$_[0, 1], $w, $_->[2], $light, $dark); }
}
sub tillers { my ($r, $n, $L, $D) = @_; for my $k (0 .. $n - 1) { my ($u, $v) = dir($k * 360 / $n + 20); my @c = ell(200 + $u * $r, 200 + $v * $r, 4.2, 4.2, 7); poly($D // 'c1', @c); poly($L // 'c2', @c[3 .. 6]); } }

# 1. Seeds, front view: a heap of slim golden paddy-rice grains in their ridged hulls, two pre-sprouted for planting.
sub sprout {
  my ($x, $y, $ang, $len, $sa, $ra) = @_; my ($dx, $dy) = dir($ang);
  my ($bx, $by) = ($x - $dx * $len / 2, $y - $dy * $len / 2);
  blade($bx, $by, $ra, $len * 0.4, 6, 40, "c3", "c3");                 # pale root
  blade($bx, $by, $sa, $len * 0.55, 9, 20, "c2", "c1");                # green shoot
}
rgrain(150, 288, -12, 100, 30); rgrain(252, 288, 192, 100, 30); rgrain(200, 300, 3, 104, 31);
rgrain(176, 254, -30, 98, 29); rgrain(228, 254, 210, 98, 29); rgrain(204, 216, -78, 98, 29);
sprout(200, 300, 3, 104, -130, 160); sprout(252, 288, 192, 100, -60, 30);
write_svg('1-seeds-front.svg', 'Rice seeds');

# 2. Just sown, top down: grains pressed into small wet, dark paddy pockets.
my @sown = ([200, 164], [164, 226], [238, 224]);
for (@sown) { wet($_->[0], $_->[1], 31, 26, int($_->[0] * 7 + $_->[1])); }
for (@sown) { my ($x, $y) = @$_; rgrain($x - 6, $y + 4, -50, 30, 12); rgrain($x + 8, $y - 2, 30, 30, 12); }
write_svg('2-sown.svg', 'Rice just sown');

# 3. First growth: a fine fan of narrow seedling leaves from a wet pocket.
wet(200, 200, 36, 32, 3);
clump(9, 64, 18, 10, 30, "c2", "c1", 31, start => -80);
write_svg('3-first-growth.svg', 'Rice first growth');

# 4. Second growth: a dense fountain of narrow leaves from many tillers.
wet(200, 200, 38, 34, 4);
clump(26, 104, 26, 12, 46, "c2", "c1", 41);
tillers(6, 5);
write_svg('4-second-growth.svg', 'Rice second growth');

# 5. Third growth: full clump, green panicles just pushing out and starting to bend.
wet(200, 200, 40, 36, 5);
clump(28, 124, 28, 13, 50, "c2", "c1", 51);
for my $i (0 .. 4) { my $a = -70 + $i * 72; my ($dx, $dy) = dir($a); panicle(200 + $dx * 10, 200 + $dy * 10, $a, 74, 30 * ($i % 2 ? 1 : -1), light => 'c2', dark => 'c1', nb => 5, gl => 9, spread => 18); }
tillers(7, 5);
write_svg('5-third-growth.svg', 'Rice third growth');

# 6. Harvest: golden panicles heavy with grain, drooping out over the green clump.
wet(200, 200, 40, 36, 6);
clump(22, 128, 30, 12, 50, "c2", "c1", 61);
for my $i (0 .. 8) { my $a = -100 + $i * 40 + ($i % 2 ? 6 : -4); my ($dx, $dy) = dir($a); panicle(200 + $dx * 12, 200 + $dy * 12, $a, 124 + ($i % 3) * 8, 58, nb => 7, gl => 13, gw => 6.4, spread => 24, al => 'c5', ad => 'c4'); }
tillers(7, 5);
write_svg('6-harvest.svg', 'Rice ready to harvest');

# 7. Harvested produce, front view: a tied bundle of rice stalks, the heavy panicles nodding over on both sides.
my ($bx, $by) = (200, 250);
for my $i (0 .. 6) { my $ex = $bx + ($i - 3) * 9; blade($bx + ($i - 3) * 3, $by, rad2deg(atan2(372 - $by, $ex - $bx)), sqrt(($ex - $bx) ** 2 + (372 - $by) ** 2), 9, 0, 'c3', 'c5'); }
for my $i (0 .. 6) { my $ex = $bx + ($i - 3) * 9; poly('c4', ell($ex, 372, 4.6, 2.6, 8)); }
my @st = ([-104, 120, -120], [-97, 134, -100], [-83, 134, 100], [-76, 120, 120], [-112, 100, -130], [-68, 100, 130], [-90, 126, 70]);
for my $s (@st) { my ($a, $l, $b) = @$s; blade($bx + ($a + 90) * 0.15, $by, $a, $l * 0.5, 6, $b * 0.5, "c3", "c5"); }
for my $s (@st) {
  my ($a, $l, $b) = @$s; my ($ex, $ey, $ea) = @{(path($bx + ($a + 90) * 0.15, $by, $a, $l * 0.5, $b * 0.5, 10))[10]};
  panicle($ex, $ey, $ea, $l * 0.95, $b * 0.8, nb => 8, gl => 17, gw => 8, spread => 34, al => 'c5', ad => 'c4', aw => 3.6);
}
poly('c4', [$bx - 28, $by - 8], [$bx + 28, $by - 11], [$bx + 30, $by + 8], [$bx - 30, $by + 11]);
poly('c5', [$bx - 28, $by - 8], [$bx + 28, $by - 11], [$bx + 28, $by - 5], [$bx - 28, $by - 2]);
write_svg('7-harvest-front.svg', 'Bundle of harvested rice');

# 8. Dead (never watered): the paddy dried out and cracked, limp straw leaves lying flat, empty grey panicles.
soil(200, 200, 56, 48, 8);
cracks(7, 83);
clump(14, 96, 30, 9, 90, 'c3', 'c5', 81);
for my $a (-40, 100, 220) { panicle(200, 200, $a, 70, 90, light => 'c4', dark => 'c4', al => 'c3', ad => 'c5', nb => 4, gl => 8, gw => 3, tip => 'c4'); }
write_svg('8-dead.svg', 'Rice died from lack of water');
print "wrote 8 files to $OUT\n";

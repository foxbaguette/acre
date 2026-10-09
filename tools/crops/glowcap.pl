# Glowcap (fantasy luminous mushroom) crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/glowcap.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Then: perl tools/center.pl crops/glowcap/1-seeds-front.svg crops/glowcap/7-harvest-front.svg
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/glowcap';
mkdir 'crops'; mkdir $OUT;
# c1 deep purple cap shade, c2 violet lit cap, c3 pale bone (stems, glow cores, dried caps), c4 dark plum soil, c5 cyan glow
my %PAL = (c1 => '#4E2C80', c2 => '#9363D3', c3 => '#D6CCB6', c4 => '#4A3238', c5 => '#3EE3D2');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Tapered blade/stalk (as in wheat).
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $taper) = @_; $taper //= 1;
  my $n = 10; my (@mid, @l, @r); my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $t) ** 0.85 + ($i == $n && $taper == 1 ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang); my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# Glow spot: small faceted hexagon, cyan with a pale core when big enough.
sub spot {
  my ($x, $y, $r, $rot) = @_; $rot //= 0;
  poly('c5', map { my ($dx, $dy) = dir($rot + $_ * 60); [$x + $dx * $r, $y + $dy * $r * 0.86] } 0 .. 5);
  poly('c3', map { my ($dx, $dy) = dir($rot + 30 + $_ * 120); [$x - $r * 0.18 + $dx * $r * 0.42, $y - $r * 0.18 + $dy * $r * 0.42] } 0 .. 2) if $r >= 5;
}


# Crescent along the outline run facing direction ($lx,$ly), returning along an inner copy pulled to ($cx,$cy).
sub crescent {
  my ($cls, $o, $x, $y, $lx, $ly, $thr, $cx, $cy, $k) = @_;
  my $n = @$o;
  my @idx = grep { my ($ox, $oy) = ($o->[$_][0] - $x, $o->[$_][1] - $y); ($ox * $lx + $oy * $ly) > $thr * sqrt($ox * $ox + $oy * $oy) } 0 .. $n - 1;
  return if @idx < 3;
  my $st = 0; for my $j (0 .. $#idx) { my $prev = ($idx[$j] - 1) % $n; $st = $j unless grep { $_ == $prev } @idx; }
  my @run = map { $o->[$idx[($st + $_) % @idx]] } 0 .. $#idx;
  my @in = map { [$cx + ($_->[0] - $cx) * $k, $cy + ($_->[1] - $cy) * $k] } @run[1 .. $#run - 1];
  poly($cls, @run, reverse @in);
}

# Spore pod (seed): a glowing egg-shaped orb, pale lit crescent, and (front view) a tiny purple dome cap on top.
sub pod {
  my ($x, $y, $ang, $r, $hat) = @_;            # $ang: direction the pod tip points (-90 = up)
  my ($ux, $uy) = dir($ang); my ($nx, $ny) = (-$uy, $ux);
  my @o = map { my $th = 2 * pi * $_ / 16; my $u = cos($th) * $r * (cos($th) > 0 ? 1.18 : 1.0); my $v = sin($th) * $r * 0.92;
    [$x + $ux * $u + $nx * $v, $y + $uy * $u + $ny * $v] } 0 .. 15;
  poly('c5', @o);
  crescent('c3', \@o, $x, $y, -0.7071, -0.7071, 0.3, $x + $r * 0.4, $y + $r * 0.4, 0.78);
  return unless $hat;
  my ($hx, $hy) = ($x + $ux * $r * 0.82, $y + $uy * $r * 0.82); my $hw = $r * 0.62; my $hh = $r * 0.5;
  my @d; for my $i (0 .. 8) { my $th = pi * $i / 8; push @d, [$hx - $nx * cos($th) * $hw + $ux * sin($th) * $hh, $hy - $ny * cos($th) * $hw + $uy * sin($th) * $hh]; }
  poly('c1', @d);
  poly('c2', @d[0 .. 4], [$hx + $ux * $hh * 0.3, $hy + $uy * $hh * 0.3]);
  spot($hx + $ux * $hh * 0.5 + $nx * $hw * 0.15, $hy + $uy * $hh * 0.5 + $ny * $hw * 0.15, $r * 0.13, 0);
}

# Top-down cap: glowing frilly gill rim, violet dome with a dark shaded crescent, glowing spots.
sub cap {
  my ($x, $y, $r, $seed, $spots, $frill, $ix, $iy) = @_; $spots //= 4; $frill //= 1; $ix //= 0; $iy //= 0;
  srand($seed); my $rot = rand(30);
  if ($frill) {   # glowing frilly gills peek out under the cap on the side it tilts away from
    my $sh = ($ix || $iy) ? 0.3 : 0; my $k0 = $sh ? 1.0 : 1.1;
    my @f; for my $i (0 .. 29) { my $a = $rot + $i * 12; my $k = $i % 2 ? $k0 - 0.07 : $k0; my ($dx, $dy) = dir($a);
      push @f, [$x + $ix * $r * $sh + $dx * $r * $k, $y + $iy * $r * $sh + $dy * $r * $k]; }
    poly('c5', @f);
    if ($sh) {   # radial gill lines in the visible crescent
      my ($gx, $gy) = ($x + $ix * $r * $sh, $y + $iy * $r * $sh); my $ia = rad2deg(atan2($iy, $ix));
      for my $g (-3 .. 3) { my ($dx, $dy) = dir($ia + $g * 17); my ($px, $py) = (-$dy, $dx); my $w = $r * 0.025 + 0.5;
        poly("c1", [$gx + $dx * $r * 0.55 + $px * $w * 0.4, $gy + $dy * $r * 0.55 + $py * $w * 0.4], [$gx + $dx * $r * 0.9 + $px * $w, $gy + $dy * $r * 0.9 + $py * $w],
                   [$gx + $dx * $r * 0.9 - $px * $w, $gy + $dy * $r * 0.9 - $py * $w], [$gx + $dx * $r * 0.55 - $px * $w * 0.4, $gy + $dy * $r * 0.55 - $py * $w * 0.4]); }
    }
  }
  my @o; for my $i (0 .. 13) { my $a = $rot + $i * 360 / 14; my ($dx, $dy) = dir($a); my $k = 0.96 + rand(0.06); push @o, [$x + $dx * $r * $k, $y + $dy * $r * $k]; }
  poly('c2', @o);
  crescent('c1', \@o, $x, $y, 0.7071, 0.7071, 0.15, $x - $r * 0.45, $y - $r * 0.45, 0.74);
  for my $s (1 .. $spots) {
    my $a = $rot + $s * 360 / $spots + rand(30); my $d = $r * (0.5 + rand(0.14)); my ($dx, $dy) = dir($a);
    spot($x + $dx * $d, $y + $dy * $d, $r * (0.13 + rand(0.05)), rand(60));
  }
  spot($x - $r * 0.12, $y - $r * 0.12, $r * ($spots ? 0.17 : 0.24), 10);
}

# One mushroom seen from above, leaning out from base ($bx,$by) so a short stem shows.
sub stalkcap {
  my ($bx, $by, $cx, $cy, $r, $seed, $spots, $frill, $w) = @_;
  my $d = sqrt(($cx - $bx) ** 2 + ($cy - $by) ** 2);
  if ($d > 4) {
    my $a = rad2deg(atan2($cy - $by, $cx - $bx));
    blade($bx, $by, $a, $d, $w, 0, 'c3', 'c5', 0.35);
  }
  my $dd = sqrt(($cx - $bx) ** 2 + ($cy - $by) ** 2) || 1;
  cap($cx, $cy, $r, $seed, $spots, $frill, $dd > 4 ? (($bx - $cx) / $dd, ($by - $cy) / $dd) : (0, 0));
}

# A cluster: list of [angle, base distance, cap distance, radius]; drawn smallest first, the big ones on top.
sub cluster {
  my ($seed, $spots, $frill, $wk, @m) = @_;
  for my $m (sort { $a->[3] <=> $b->[3] } @m) {
    my ($a, $bd, $cd, $r) = @$m; my ($dx, $dy) = dir($a);
    stalkcap(200 + $dx * $bd, 200 + $dy * $bd, 200 + $dx * $cd, 200 + $dy * $cd, $r, $seed + int($a + 400), $r < 14 ? 0 : $spots, $r < 14 ? 0 : $frill, max(6, $r * $wk));
  }
}
# Front-view mushroom: stem, frilly glowing gills under a faceted dome cap with spots.
sub shroom {
  my ($x, $y, $h, $cw, $ch, $lean, $seed) = @_;
  srand($seed);
  my ($tx, $ty) = ($x + $lean, $y - $h);           # cap underside centre
  my $sw = $cw * 0.17;
  # stem: lit left half bone, shaded right half glowing
  my @L = ([$x - $sw * 1.25, $y], [$tx - $sw * 0.8, $ty]); my @R = ([$x + $sw * 1.25, $y], [$tx + $sw * 0.8, $ty]);
  my @M = ([$x, $y], [$tx, $ty]);
  poly('c3', $L[0], $L[1], $M[1], $M[0]); poly('c5', $M[0], $M[1], $R[1], $R[0]);
  # gills: a frilled band under the cap
  my @g; for my $i (0 .. 16) { my $t = $i / 16; my $gx = $tx - $cw / 2 + $cw * $t; my $gy = $ty + ($i % 2 ? 15 : 4) * ($cw / 120) * sin(pi * $t) ** 0.4 + 4;
    push @g, [$gx, $gy]; }
  poly('c5', [$tx - $cw / 2, $ty - 2], [$tx + $cw / 2, $ty - 2], reverse @g);
  # dome: vertical facets, lit on the left
  my $n = 7; my @top;
  for my $i (0 .. $n) { my $t = $i / $n; my $th = pi * $t; push @top, [$tx - cos($th) * $cw / 2, $ty - sin($th) ** 0.85 * $ch]; }
  my @base = map { [$tx - $cw / 2 + $cw * $_ / $n, $ty] } 0 .. $n;
  my @apex = ($tx - $cw * 0.1, $ty - $ch * 0.35);
  for my $i (0 .. $n - 1) {
    poly($i < 4 ? "c2" : "c1", \@apex, $top[$i], $top[$i + 1]);
    poly($i < 2 ? 'c2' : 'c1', \@apex, $base[$i + 1], $base[$i]) if 0;
  }
  poly('c1', \@apex, $top[$n], [$tx + $cw / 2, $ty + 1], [$tx - $cw / 2, $ty + 1], $top[0]);
  poly('c2', \@apex, $top[0], [$tx - $cw / 2, $ty + 1], [$tx - $cw * 0.15, $ty + 1]);
  for my $s (0 .. 3) {
    my $t = 0.18 + $s * 0.21 + rand(0.05); my $hh = 0.2 + rand(0.45);
    spot($tx - $cw / 2 + $cw * $t, $ty - $ch * $hh * sin(pi * $t), $cw * (0.05 + rand(0.035)), rand(60));
  }
}
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

# 1. Seeds, front: a little heap of glowing spore pods in their husks.
pod(204, 178, -96, 32, 1); pod(170, 226, -112, 34, 1); pod(236, 228, -70, 34, 1);
pod(140, 280, -124, 38, 1); pod(262, 282, -58, 38, 1); pod(200, 290, -90, 40, 1);
write_svg('1-seeds-front.svg', 'Glowcap spore pods');

# 2. Just sown, top down: pods pressed into small soil pockets.
my @sown = ([166, 168], [240, 162], [202, 212], [150, 240], [252, 238]);
for (@sown) { soil($_->[0], $_->[1], 30, 24, int($_->[0] * 7 + $_->[1])); }
for (@sown) { pod($_->[0], $_->[1], -90 + ($_->[0] - 200) * 0.6, 17); }
write_svg('2-sown.svg', 'Glowcap just sown');

# 3. First growth: tiny pin caps pushing up from a mycelium bed.
soil(200, 200, 62, 56, 3);
cluster(30, 0, 0, 0.5, [-120, 34, 56, 15], [-40, 38, 64, 17], [40, 32, 56, 14], [110, 38, 62, 16], [190, 36, 60, 15], [260, 30, 50, 13], [0, 0, 6, 19], [150, 14, 26, 12], [-80, 12, 24, 11]);
write_svg('3-first-growth.svg', 'Glowcap first growth');

# 4. Second growth: slender stems with small domed caps.
soil(200, 200, 64, 58, 4);
cluster(40, 2, 1, 0.36, [-110, 34, 86, 22], [-30, 38, 84, 20], [50, 36, 92, 24], [130, 34, 82, 20], [205, 38, 90, 23], [280, 30, 70, 17], [10, 14, 40, 15], [160, 12, 40, 14], [0, 0, 4, 24]);
write_svg('4-second-growth.svg', 'Glowcap second growth');

# 5. Third growth: a lush cluster of caps of different sizes, frilly glowing rims.
soil(200, 200, 70, 64, 5);
cluster(50, 3, 1, 0.34, [-150, 50, 112, 26], [-80, 52, 108, 30], [-6, 50, 114, 27], [64, 52, 106, 31], [136, 50, 112, 26], [204, 52, 106, 30], [276, 44, 100, 22],
        [-110, 20, 60, 30], [-10, 22, 62, 27], [100, 20, 58, 31], [200, 22, 60, 26], [0, 0, 4, 38]);
write_svg('5-third-growth.svg', 'Glowcap third growth');

# 6. Harvest: big luminous caps crowding the tile.
soil(200, 200, 76, 70, 6);
cluster(60, 5, 1, 0.3, [-160, 60, 132, 34], [-92, 64, 130, 40], [-22, 60, 126, 36], [50, 64, 132, 41], [124, 60, 128, 36], [196, 64, 132, 40], [268, 58, 128, 33],
        [-128, 28, 74, 41], [-18, 30, 76, 43], [98, 28, 72, 41], [214, 28, 74, 39], [0, 0, 6, 58]);
write_svg('6-harvest.svg', 'Glowcap ready to harvest');

# 7. Harvest, front: the produce itself, three picked glowcaps with cut stems (no plant, no soil).
sub cutend { my ($x, $y, $w) = @_; poly('c3', map { my $th = 2 * pi * $_ / 12; [$x + cos($th) * $w, $y + sin($th) * $w * 0.32] } 0 .. 11);
  poly('c5', map { my $th = 2 * pi * $_ / 12; [$x + cos($th) * $w * 0.55, $y + sin($th) * $w * 0.18] } 0 .. 11); }
shroom(130, 320, 96, 120, 66, -10, 81); cutend(130, 320, 120 * 0.17 * 1.25);
shroom(276, 324, 84, 108, 60, 10, 82); cutend(276, 324, 108 * 0.17 * 1.25);
shroom(204, 334, 150, 156, 90, 0, 83); cutend(204, 334, 156 * 0.17 * 1.25);
write_svg('7-harvest-front.svg', 'Glowcap harvest');

# 8. Dead (never watered): cracked dry soil, collapsed shrivelled grey-brown caps lying flat.
soil(200, 200, 66, 58, 8);
srand(83);
for my $i (0 .. 6) {
  my $a = $i * 360 / 7 + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
  for my $k (0 .. 4) {
    my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.2 - $k * 0.35;
    push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
    $x += $dx * 15; $y += $dy * 15;
  }
  poly('c3', @l, [$x, $y], reverse @r);
}
sub deadcap {   # collapsed cap: flattened, wavy shrivelled outline, dark radial wrinkles and a shaded side
  my ($x, $y, $r, $ang, $seed) = @_; srand($seed);
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o; my $n = 16;
  for my $i (0 .. $n - 1) { my $th = 2 * pi * $i / $n; my $k = ($i % 2 ? 0.88 : 1.0) * (0.92 + rand(0.12));
    my $u = cos($th) * $r * $k; my $v = sin($th) * $r * 0.8 * $k; push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v]; }
  poly('c3', @o);
  crescent('c4', \@o, $x, $y, 0.7071, 0.7071, 0.2, $x - $r * 0.35, $y - $r * 0.35, 0.74);
  for my $i (grep { $_ % 4 == 1 } 0 .. $n - 1) {   # wrinkles running in from the rim
    my $p = $o[$i]; my ($wx, $wy) = ($x + ($p->[0] - $x) * 0.3, $y + ($p->[1] - $y) * 0.3);
    my ($ex, $ey) = ($p->[0] - $wx, $p->[1] - $wy); my $l = sqrt($ex * $ex + $ey * $ey) || 1; ($ex, $ey) = (-$ey / $l * 1.6, $ex / $l * 1.6);
    poly('c4', [$p->[0] + $ex, $p->[1] + $ey], [$wx, $wy], [$p->[0] - $ex, $p->[1] - $ey]);
  }
}
for ([-130, 92, 34, 1, 24], [-48, 98, 30, 2, -30], [42, 94, 36, 3, 32], [134, 88, 30, 4, -26], [216, 96, 34, 5, 28], [296, 80, 26, 6, 20]) {
  my ($a, $d, $r, $sd, $bend) = @$_;
  blade(200, 200, $a, $d * 0.7, 13, $bend, "c3", "c4", 0.45);
  my ($x, $y, $aa) = (200, 200, $a);
  for (1 .. 10) { my ($ex, $ey) = dir($aa); $x += $ex * $d * 0.1; $y += $ey * $d * 0.1; $aa += $bend / 10; }
  deadcap($x, $y, $r, $aa + 90, $sd + 80);
}
deadcap(200, 200, 36, 20, 99);
write_svg('8-dead.svg', 'Glowcap died from lack of water');
print "wrote 8 files to $OUT\n";

# Pumpkin crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/pumpkin.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/pumpkin';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#3D7A35', c2 => '#7DBA4C', c3 => "#F8D27A", c4 => '#5A3A22', c5 => '#E0661C');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub light { my ($nx, $ny) = @_; my $l = sqrt($nx * $nx + $ny * $ny) || 1; ($nx * -0.7071 + $ny * -0.7071) / $l }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A tapered blade or stalk from (x,y) heading `ang`, bending `bend` degrees over its length (as in wheat.pl).
# $taper < 1 keeps some width at the tip (vines, stalks).
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $lightc, $dark, $taper) = @_;
  $taper //= 1;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $t) ** 0.85 + ($i == $n && $taper == 1 ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py, $a];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang);
  my $leftLit = lit(-$dy, $dx);
  my @m = map { [$_->[0], $_->[1]] } @mid;
  poly($leftLit ? $lightc : $dark, @l, reverse @m);
  poly($leftLit ? $dark : $lightc, @r, reverse @m);
  return @mid;   # points along the stalk: [x, y, angle]
}

# A curly tendril: a thin strip whose curvature tightens toward the tip.
sub tendril {
  my ($x, $y, $ang, $len, $turn, $w, $cls) = @_;
  my $n = 30; my (@l, @r); my $a = $ang; my $step = $len / $n * 1.6;
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a); my $hw = $w / 2 * (1 - 0.6 * $t);
    push @l, [$x - $dy * $hw, $y + $dx * $hw]; push @r, [$x + $dy * $hw, $y - $dx * $hw];
    $x += $dx * $step * (1 - 0.7 * $t); $y += $dy * $step * (1 - 0.7 * $t); $a += $turn * (0.15 + 1.7 * $t ** 1.6);
  }
  poly($cls // 'c2', @l, reverse @r);
}

# A big lobed pumpkin leaf seen from above: five pointed lobes, each split along its vein into lit and
# shaded halves; facets fan out from the leaf base where the petiole meets it.
sub pleaf {
  my ($x, $y, $ang, $r, $lightc, $dark, $wilt, $seed) = @_;
  $wilt //= 0; srand($seed // int($x * 13 + $y * 7));
  my @lobes = ([-112, 0.76], [-57, 0.94], [0, 1.0], [57, 0.94], [112, 0.76]);
  my @o;   # outline points [angleOffset, radius, kind]  kind: s = sinus, t = tip, e = edge tooth
  push @o, [-152, 0.34, "s"];
  for my $k (0 .. $#lobes) {
    my ($la, $lr) = @{$lobes[$k]};
    my $prevS = $k == 0 ? -152 : ($lobes[$k - 1][0] + $la) / 2;
    my $nextS = $k == $#lobes ? 152 : ($lobes[$k + 1][0] + $la) / 2;
    push @o, [$la + ($prevS - $la) * 0.5, $lr * 0.9, "e"];
    push @o, [$la, $lr, 't'];
    push @o, [$la + ($nextS - $la) * 0.5, $lr * 0.9, "e"];
    push @o, [$nextS, ($k == $#lobes ? 0.34 : 0.7), 's'];
  }
  my @p;
  for my $q (@o) {
    my ($oa, $or) = @$q;
    my $rr = $r * $or * (1 - $wilt * (0.25 + rand(0.45)));
    my $aa = $ang + $oa * (1 - $wilt * 0.35) + $wilt * (rand(30) - 15);
    my ($dx, $dy) = dir($aa);
    push @p, [$x + $dx * $rr, $y + $dy * $rr];
  }
  # fan facets from the base; each facet is coloured by the side of its lobe vein it lies on
  for my $i (0 .. $#p - 1) {
    my $tipA = $lobes[int($i / 4)][0]; my $side = $i % 4 < 2 ? -1 : 1;
    my ($nx, $ny) = dir($ang + $tipA + $side * 90);
    poly(lit($nx, $ny) ? $lightc : $dark, [$x, $y], $p[$i], $p[$i + 1]);
  }
  return @p;
}

# A big yellow trumpet flower seen from above: five pointed lobes, deep throat and stamen.
sub pflower {
  my ($x, $y, $r, $rot) = @_;
  my @o;
  for my $k (0 .. 4) {
    my $a = $rot + $k * 72;
    push @o, [$a - 36, 0.6, 's'], [$a - 16, 0.9, 'e'], [$a, 1.0, 't'], [$a + 16, 0.9, 'e'];
  }
  my @p = map { my ($dx, $dy) = dir($_->[0]); [$x + $dx * $r * $_->[1], $y + $dy * $r * $_->[1]] } @o;
  for my $i (0 .. $#p) {
    my $j = ($i + 1) % @p;
    my $k = int($i / 4); my $tipA = $rot + $k * 72;
    my $mid = $o[$i][0] + 9;
    my $side = $mid < $tipA ? -1 : 1;
    my ($nx, $ny) = dir($tipA + $side * 90);
    poly(lit($nx, $ny) ? 'c3' : 'c5', [$x, $y], $p[$i], $p[$j]);
  }
  my @t = map { my ($dx, $dy) = dir($rot + 36 + $_ * 72); [$x + $dx * $r * 0.36, $y + $dy * $r * 0.36] } 0 .. 4;
  poly('c5', @t);
  my @u = map { my ($dx, $dy) = dir($rot + 36 + $_ * 72); [$x + $dx * $r * 0.2, $y + $dy * $r * 0.2] } 0 .. 4;
  poly('c4', @u);
  my @s = map { my ($dx, $dy) = dir($rot + $_ * 72); [$x + $dx * $r * 0.12, $y + $dy * $r * 0.12] } 0 .. 4;
  poly('c3', @s);
}


# Ribbed pumpkin seen from above: scalloped dome; each rib split into halves lit by side and slope, dark grooves.
sub ptop {
  my ($x, $y, $r, $nrib, $rot, $stalkA, $body, $lightc, $shade) = @_;
  $body //= 'c5'; $lightc //= 'c3'; $shade //= 'c4';
  my $P = sub { my ($a, $k) = @_; my ($dx, $dy) = dir($a); [$x + $dx * $r * $k, $y + $dy * $r * $k] };
  my $st = 360 / $nrib; my $G = 0.91;
  my @out;
  for my $k (0 .. $nrib - 1) { my $g = $rot + $k * $st; push @out, $P->($g, $G), $P->($g + $st * 0.22, 0.98), $P->($g + $st * 0.5, 1.0), $P->($g + $st * 0.78, 0.98); }
  poly($body, @out);
  for my $k (0 .. $nrib - 1) {
    my $g = $rot + $k * $st; my $c = $g + $st / 2;
    my $rl = light(dir($c));
    for my $h ([-1, $g, $g + $st * 0.22, $c, $G, 1.0], [1, $c, $g + $st * 0.78, $g + $st, 1.0, $G]) {
      my ($side, $a0, $am, $a1, $k0, $k1) = @$h;
      my $sl = light(dir($c + $side * 90)) > 0 ? 1 : -1;
      my $b = 1.4 * $rl + 0.35 * $sl;
      if ($b > 0.75) {
        my $in = 0.12 + 0.1 * (1 - $rl);
        poly($lightc, $P->($a0, $in), $P->($a0, $k0), $P->($am, 0.98), $P->($a1, $k1), $P->($a1, $in));
      } elsif ($b < -0.95) {
        my $in = 0.6 + 0.12 * (1 + $rl);
        poly($shade, $P->($a0, $in + 0.05), $P->($a0, $k0), $P->($am, 0.98), $P->($a1, $k1), $P->($a1, $in + 0.05), $P->($am, $in));
      }
    }
  }
  for my $k (0 .. $nrib - 1) {          # grooves: orange on the lit side, dark in shade
    my $g = $rot + $k * $st; my ($dx, $dy) = dir($g); my ($nx, $ny) = (-$dy, $dx);
    my $wd = $r * 0.03;
    poly((light(dir($g)) > 0.2 ? $body : $shade), $P->($g, 0.2), [$x + $dx * $r * 0.6 + $nx * $wd, $y + $dy * $r * 0.6 + $ny * $wd], $P->($g, $G + 0.01), [$x + $dx * $r * 0.6 - $nx * $wd, $y + $dy * $r * 0.6 - $ny * $wd]);
  }
  # stalk: a woody star-shaped scar and a short thick stem
  my @sc = map { $P->($rot + $_ * $st, 0.2), $P->($rot + ($_ + 0.5) * $st, 0.13) } 0 .. $nrib - 1;
  poly('c1', @sc);
  blade($x, $y, $stalkA, $r * 0.42, $r * 0.2, 25, 'c2', 'c1', 0.35) if defined $stalkA;
}

# Ribbed pumpkin seen from the front: vertical lobes split into lit/shaded halves, dark grooves.
sub pfront {
  my ($cx, $cy, $rx, $ry, $n) = @_;
  my $m = 14;
  my $curve = sub {    # points down one meridian at longitude phi (degrees), radial scale k
    my ($phi, $k) = @_; my @c; my $e = 1 - abs(sin(deg2rad($phi)));
    for my $i (0 .. $m) {
      my $th = pi * $i / $m;
      my $cs = cos($th); my $yy = $cy - ($cs < 0 ? -1 : 1) * abs($cs) ** 0.75 * $ry * 0.97;
      $yy += $ry * 0.24 * max(0, 1 - $th / (0.3 * pi)) ** 1.2;   # stalk dimple
      $yy -= $ry * 0.07 * $e if $i == $m;
      push @c, [$cx + $rx * sin(deg2rad($phi)) * sin($th) ** 0.85 * $k, $yy];
    }
    return @c;
  };
  my $pick = sub { my $b = shift; $b > 0.55 ? "c3" : $b > -1.2 ? "c5" : "c4" };
  for my $j (0 .. $n - 1) {
    my $p0 = -90 + 180 * $j / $n; my $p1 = -90 + 180 * ($j + 1) / $n; my $pm = ($p0 + $p1) / 2;
    my @g0 = $curve->($p0, 0.94); my @g1 = $curve->($p1, 0.94); my @cm = $curve->($pm, 1.0);
    my $bl = -sin(deg2rad($pm));
    poly($pick->(1.4 * $bl + 0.35), @g0, reverse @cm);
    poly($pick->(1.4 * $bl - 0.35), @cm, reverse @g1);
    if ($j > 0) {          # groove: dark in shade, orange on the lit side
      my @gl = $curve->($p0, 0.94); my $wd = 2.2 + 1.6 * abs($p0 + 45) / 135;
      poly($p0 > -45 ? "c4" : "c5", (map { [$_->[0] - $wd * sin(pi * $_->[2]), $_->[1]] } map { [@{$gl[$_]}, $_ / $m] } 1 .. $m - 1),
                 (map { [$_->[0] + $wd * sin(pi * $_->[2]), $_->[1]] } reverse map { [@{$gl[$_]}, $_ / $m] } 1 .. $m - 1));
    }
  }
}

# Flat pumpkin seed: a long rounded teardrop with a thin shaded edge.
sub pseed {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 15) {
    my $th = 2 * pi * $i / 16;
    my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 + 0.3 * cos($th)) * (cos($th) < -0.9 ? 0.55 : 1);
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly('c3', @o);
  shade_rim($x, $y, $len * 0.5, 'c4', 0.8, @o);
}

# Shaded crescent along the lower-right edge of any convex outline @o around (x,y).
sub shade_rim {
  my ($x, $y, $r, $cls, $kmin, @o) = @_;
  my $n = @o;
  my @d = map { my ($vx, $vy) = ($_->[0] - $x, $_->[1] - $y); my $l = sqrt($vx * $vx + $vy * $vy) || 1; ($vx + $vy) * 0.7071 / $l } @o;
  my $s = 0; for my $i (0 .. $n - 1) { if ($d[$i] > 0.1 && $d[($i - 1) % $n] <= 0.1) { $s = $i; last } }
  my ($cx, $cy) = ($x - $r * 0.3, $y - $r * 0.3);
  my (@out, @in);
  for my $j (0 .. $n - 1) {
    my $i = ($s + $j) % $n; last unless $d[$i] > 0.1;
    push @out, $o[$i];
    my $k = $kmin + (1 - $kmin) * (1 - ($d[$i] - 0.1) / 0.9) ** 1.5;
    push @in, [$cx + ($o[$i][0] - $cx) * $k, $cy + ($o[$i][1] - $cy) * $k];
  }
  poly($cls, @out, reverse @in) if @out > 1;
}

# Small irregular patch of soil.
sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o;
  srand($seed);
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12; my $k = 0.82 + rand(0.3); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
}

sub cracks {
  my ($n, $seed, $seg, $cls) = @_;
  srand($seed);
  for my $i (0 .. $n - 1) {
    my $a = $i * 360 / $n + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
    for my $k (0 .. 4) {
      my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.4 - $k * 0.4;
      push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
      $x += $dx * $seg; $y += $dy * $seg;
    }
    poly($cls, @l, [$x, $y], reverse @r);
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

# A leaf on its petiole: stalk from (x,y) heading `ang`, the blade opening at its end.
sub leaf_on {
  my ($x, $y, $ang, $plen, $r, $lc, $dc, $wilt, $seed) = @_;
  my @m = blade($x, $y, $ang, $plen, 5, 0, $lc // 'c2', $dc // 'c1', 0.4);
  my ($ex, $ey) = @{$m[-1]};
  pleaf($ex, $ey, $ang, $r, $lc // 'c2', $dc // 'c1', $wilt, $seed);
}

# A sprawling vine from the crown: returns its node points.
sub vine {
  my ($ang, $len, $bend, $w, $lc, $dc) = @_;
  my ($dx, $dy) = dir($ang);
  return blade(200 + $dx * 4, 200 + $dy * 4, $ang, $len, $w, $bend, $lc // 'c2', $dc // 'c1', 0.55);
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a small heap of flat cream pumpkin seeds.
for my $s ([132, 300, 8], [200, 312, -172], [268, 300, 172], [166, 262, 200], [234, 262, -18], [200, 222, -96]) {
  pseed($s->[0], $s->[1], $s->[2], 76, 50);
}
write_svg('1-seeds-front.svg', 'Pumpkin seeds');

# 2. Just sown, top down: three big seeds pushed into a small hill.
my @sown = ([172, 176, -30], [234, 180, 40], [200, 232, 100]);
for (@sown) { soil($_->[0], $_->[1], 32, 27, int($_->[0] * 7 + $_->[1])); }
for (@sown) { pseed($_->[0], $_->[1], $_->[2], 46, 30); }
write_svg('2-sown.svg', 'Pumpkin just sown');

# Smooth rounded seed leaf (cotyledon), split along its midrib.
sub seedleaf {
  my ($x, $y, $ang, $len, $w) = @_;
  my $n = 10; my (@mid, @l, @r); my ($dx, $dy) = dir($ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my $hw = $w / 2 * sin(pi * (0.08 + 0.92 * $t)) ** 0.55;
    my ($px, $py) = ($x + $dx * $len * $t, $y + $dy * $len * $t);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
  }
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? 'c2' : 'c1', @l, reverse @mid);
  poly($leftLit ? 'c1' : 'c2', @r, reverse @mid);
}

# Leaves, flowers or tendrils along a vine (list of blade() points).
sub at { my ($pts, $t) = @_; my $i = int($t * $#$pts + 0.5); @{$pts->[$i]} }

# 3. First growth, top down: two round seed leaves and the first small lobed leaf.
soil(200, 200, 34, 30, 3);
seedleaf(200, 200, 160, 70, 40);
seedleaf(200, 200, -20, 70, 40);
leaf_on(200, 200, -96, 18, 40, 'c2', 'c1', 0, 31);
write_svg('3-first-growth.svg', 'Pumpkin first growth');

# 4. Second growth, top down: a young plant with big lobed leaves and the first runner.
soil(200, 200, 34, 30, 4);
{
  my @v = vine(15, 104, 30, 9);
  tendril((at(\@v, 0.95))[0], (at(\@v, 0.95))[1], 80, 34, 26, 3);
  my ($x, $y, $a) = at(\@v, 1.0); leaf_on($x, $y, $a - 10, 8, 28, 'c2', 'c1', 0, 42);
  leaf_on(200, 200, 135, 34, 54, 'c2', 'c1', 0, 43);
  leaf_on(200, 200, -150, 30, 50, 'c2', 'c1', 0, 44);
  leaf_on(200, 200, 70, 30, 50, 'c2', 'c1', 0, 45);
  leaf_on(200, 200, -60, 36, 56, 'c2', 'c1', 0, 46);
}
write_svg('4-second-growth.svg', 'Pumpkin second growth');

# 5. Third growth, top down: sprawling vines, big leaves, curly tendrils and yellow trumpet flowers.
soil(200, 200, 34, 30, 5);
{
  my @v1 = vine(-30, 150, 40, 10); my @v2 = vine(100, 140, -36, 10); my @v3 = vine(205, 140, 30, 10);
  for my $v (\@v1, \@v2, \@v3) {
    my ($x, $y, $a) = at($v, 0.55); tendril($x, $y, $a + 70, 40, 22, 3);
    ($x, $y, $a) = at($v, 0.9); tendril($x, $y, $a - 80, 36, -22, 3);
  }
  for my $v (\@v1, \@v2, \@v3) {
    my ($x, $y, $a) = at($v, 1.0); leaf_on($x, $y, $a, 6, 36, 'c2', 'c1', 0, int($x));
    ($x, $y, $a) = at($v, 0.7); leaf_on($x, $y, $a + 60, 22, 46, 'c2', 'c1', 0, int($y));
  }
  for my $l ([-110, 40, 54], [10, 34, 52], [150, 36, 52], [255, 32, 50]) { leaf_on(200, 200, $l->[0], $l->[1], $l->[2], 'c2', 'c1', 0, $l->[0] + 500); }
  # flowers held up above the leaves on short stalks from the vines
  for my $fl ([\@v1, 0.45, -70, 34], [\@v2, 0.5, 20, 32], [\@v3, 0.55, 130, 33]) {
    my ($v, $t, $da, $r) = @$fl; my ($x, $y, $a) = at($v, $t);
    my @s = blade($x, $y, $a + $da, 26, 5, 0, 'c2', 'c1', 0.4);
    pflower($s[-1][0], $s[-1][1], $r, $a + $da + 18);
  }
  my ($x, $y, $a) = at(\@v2, 0.82);       # a tiny green fruit forming behind a female flower
  ptop($x + 10, $y + 4, 16, 8, 0, $a, 'c2', 'c3', 'c1');
}
write_svg('5-third-growth.svg', 'Pumpkin third growth');

# 6. Harvest, top down: two big ribbed orange pumpkins among the leaves of a sprawling vine.
soil(200, 200, 34, 30, 6);
{
  my @v1 = vine(-40, 166, 34, 11); my @v2 = vine(120, 150, -20, 11); my @v3 = vine(215, 150, 26, 10); my @v4 = vine(40, 150, -30, 10);
  for my $v (\@v1, \@v2, \@v3) {
    my ($x, $y, $a) = at($v, 0.6); tendril($x, $y, $a - 70, 42, -22, 3);
    ($x, $y, $a) = at($v, 0.95); tendril($x, $y, $a + 80, 36, 22, 3);
  }
  for my $l ([\@v1, 1.0, 0, 6, 40], [\@v1, 0.5, -70, 20, 50], [\@v2, 1.0, 0, 6, 42], [\@v3, 1.0, 0, 6, 40], [\@v3, 0.5, 70, 22, 50],
             [\@v4, 1.0, 0, 6, 42], [\@v4, 0.55, 60, 18, 46]) {
    my ($v, $t, $da, $pl, $r) = @$l; my ($x, $y, $a) = at($v, $t); leaf_on($x, $y, $a + $da, $pl, $r, 'c2', 'c1', 0, int($x + $y));
  }
  for my $l ([-110, 40, 56], [-10, 36, 54], [180, 40, 54], [70, 30, 50]) { leaf_on(200, 200, $l->[0], $l->[1], $l->[2], 'c2', 'c1', 0, $l->[0] + 600); }
  ptop(132, 268, 66, 10, -84, -40);       # big pumpkin, stalk toward the vine
  ptop(282, 150, 54, 9, -70, 150);
}
write_svg('6-harvest.svg', 'Pumpkin ready to harvest');

# 7. Harvest, front view: the harvested pumpkin itself (inventory item): big ribbed pumpkin, curly stalk,
#    a cut stub of vine with a small leaf and a tendril. No plant, no soil.
{
  my @st = blade(203, 170, -96, 54, 26, 46, 'c2', 'c1', 0.3);         # thick curving stalk
  splice(@S, -2);                                                       # (only needed its end point)
  my ($sx, $sy) = @{$st[-1]};
  my @v = blade($sx - 46, $sy + 8, -12, 96, 11, 6, 'c2', 'c1', 0.25);  # cut piece of vine
  tendril($v[-1][0], $v[-1][1], -40, 46, 24, 4);
  leaf_on($sx - 30, $sy + 4, -128, 10, 46, 'c2', 'c1', 0, 77);
  pfront(200, 238, 150, 104, 7);
  blade(203, 170, -96, 54, 26, 46, 'c2', 'c1', 0.3);                   # stalk again on top of the body
}
write_svg('7-harvest-front.svg', 'Harvested pumpkin');

# 8. Dead (never watered), top down: cracked dry soil, a dried-out vine and shrivelled curled leaves.
soil(200, 200, 52, 46, 8);
cracks(8, 83, 12, 'c3');
{
  my @v1 = vine(-25, 120, 70, 7, 'c3', 'c4'); my @v2 = vine(150, 110, -60, 7, 'c3', 'c4');
  for my $v (\@v1, \@v2) { my ($x, $y, $a) = at($v, 0.8); tendril($x, $y, $a + 60, 30, 30, 3, 'c3'); }
  for my $l ([-100, 26, 44], [20, 24, 46], [100, 30, 44], [200, 24, 46], [-160, 30, 40]) {
    leaf_on(200, 200, $l->[0], $l->[1] + 22, $l->[2] + 16, "c3", "c4", 0.55, $l->[0] + 800);
  }
}
write_svg('8-dead.svg', 'Pumpkin died from lack of water');
print "wrote 8 files to $OUT\n";

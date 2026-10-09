# Mint crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/mint.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Signature: square stems with opposite leaf pairs crossing at right angles (each shoot is a neat 4-way cross
# from above), small bright leaves that are serrated and deeply quilted, lilac flower spikes, a spreading clump.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/mint';
mkdir 'crops'; mkdir $OUT;
# c1 mint green (shade, vein grooves), c2 fresh lit green, c3 pale mint (bulge highlights, roots, dried leaves),
# c4 dark soil, c5 lilac (flower spikes)
my %PAL = (c1 => '#2E8B4E', c2 => '#86D46A', c3 => '#EFF0C6', c4 => '#553826', c5 => '#A673D6');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub ell { my ($x, $y, $rx, $ry, $n, $rot) = @_; $rot //= 0; map { my ($u, $v) = dir($rot + $_ * 360 / $n); [$x + $u * $rx, $y + $v * $ry] } 0 .. $n - 1 }

# A tapered stem from (x,y) heading `ang`, bending `bend` degrees. Returns end point and heading.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $tipw) = @_;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $t * (1 - ($tipw // 0))) + 0.4;
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py];
    last if $i == $n;
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
  return ($px, $py, $a);
}
sub walk {
  my ($x, $y, $ang, $len, $bend, $t) = @_; my $n = 10;
  for my $i (1 .. int($t * $n + 0.5)) { my ($dx, $dy) = dir($ang); $x += $dx * $len / $n; $y += $dy * $len / $n; $ang += $bend / $n; }
  return ($x, $y, $ang);
}

# Mint leaf: ovate, sharply serrated, deeply quilted. Sunken veins (grooves) split each half into bulging
# panels; every bulge catches its own highlight on the side toward the light.
# %o: lit => [groove, panel, highlight] for the lit half, dark => [base, highlight] for the shaded half,
#     wd => width factor (withered), teeth => teeth per side.
sub mleaf {
  my ($x, $y, $ang, $len, $w, %o) = @_;
  my ($Lg, $Lp, $Lh) = @{$o{lit} // ['c1', 'c2', 'c3']};
  my ($Db, $Dh) = @{$o{dark} // ['c1', 'c2']};
  my $wd = $o{wd} // 1;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $f = sub { my $u = min(1, max(0, $_[0])); sin(pi * (0.06 + 0.94 * $u) ** 0.8) ** 0.75 };
  my $P = sub { my ($u, $v) = @_; my $h = $f->($u) * $v * $w / 2 * $wd; [$x + $dx * $u * $len + $nx * $h, $y + $dy * $u * $len + $ny * $h] };
  my $N = $o{teeth} // 7; my (@L, @R);
  for my $i (0 .. $N * 2) {
    my $u = $i / ($N * 2); my $tip = $i % 2;
    my $k = ($i == 0) ? 0.6 : $tip ? 1.04 : 0.84;
    my $uu = $tip ? $u + 0.35 / ($N * 2) : $u;                 # teeth lean toward the leaf tip
    $uu = 1 if $i == $N * 2; $k = 0 if $i == $N * 2;
    push @L, $P->($uu, $k); push @R, $P->($uu, -$k);
  }
  my @mid = map { $P->($_ / 8, 0) } 0 .. 8;
  my $plusLit = lit($nx, $ny);
  my ($LS, $DS) = $plusLit ? (\@L, \@R) : (\@R, \@L);
  my $sg = $plusLit ? 1 : -1;
  poly($Lg, @$LS, reverse @mid);
  poly($Db, @$DS, reverse @mid);
  return if $o{plain};
  # quilted panels between the side veins
  my @vu = (0.0, 0.24, 0.52);
  my ($lx, $ly) = (-0.7071, -0.7071);
  for my $k (0 .. $#vu) {
    my ($ua, $ub) = ($vu[$k], $k < $#vu ? $vu[$k + 1] : 0.97);
    my $g = 0.022; my $sl = 0.17;                              # groove half-width, vein forward slant
    for my $side (1, -1) {
      my $s = $side * $sg;                                     # +1 = lit half
      my @q = ($P->($ua + $g + 0.01, 0.13 * $s), $P->($ua + $sl + $g, 0.8 * $s),
               $k < $#vu ? ($P->($ub + $sl - $g, 0.8 * $s), $P->($ub - $g + 0.01, 0.13 * $s)) : ($P->(0.94, 0.2 * $s)));
      my ($cx, $cy) = (0, 0); $cx += $_->[0] / @q, $cy += $_->[1] / @q for @q;
      @q = chamfer(@q); my $sz = sqrt(($q[1][0] - $q[0][0]) ** 2 + ($q[1][1] - $q[0][1]) ** 2);
      my ($hx, $hy) = ($cx + $lx * $sz * 0.14, $cy + $ly * $sz * 0.14);
      if ($side == 1) {
        poly($Lp, @q);
        poly($Lh, map { [$hx + ($_->[0] - $cx) * 0.36, $hy + ($_->[1] - $cy) * 0.36] } @q) if $Lh;
      } else {
        poly($Dh, map { [$hx + ($_->[0] - $cx) * 0.5, $hy + ($_->[1] - $cy) * 0.5] } @q) if $Dh;
      }
    }
  }
}

# Round off a polygon: replace every corner by two points a quarter in along its edges.
sub chamfer { my @q = @_; my @o; for my $i (0 .. $#q) { my ($a, $b) = ($q[$i], $q[($i + 1) % @q]);
  push @o, [$a->[0] + ($b->[0] - $a->[0]) * 0.25, $a->[1] + ($b->[1] - $a->[1]) * 0.25], [$a->[0] + ($b->[0] - $a->[0]) * 0.75, $a->[1] + ($b->[1] - $a->[1]) * 0.75]; } @o }

# A mint shoot from above: decussate leaf pairs (each pair turned 90 degrees), largest at the bottom, so the
# shoot reads as a neat four-way cross. $flower adds a lilac spike at the tip.
sub shoot {
  my ($x, $y, $rot, $s, $pairs, $seed, %o) = @_;
  srand($seed);
  for my $p (0 .. $pairs - 1) {
    my $k = 1 - 0.2 * $p; my $len = 40 * $s * $k; my $a0 = $rot + $p * 90;
    for my $side (0, 180) {
      my $a = $a0 + $side + rand(12) - 6; my ($ux, $uy) = dir($a);
      mleaf($x + $ux * 2.5 * $s, $y + $uy * 2.5 * $s, $a, $len, $len * 0.66, %o);
    }
  }
  my $a = $rot + $pairs * 90;
  if ($o{spike}) { spike($x, $y, $o{spike}, $rot); return; }
  for my $side (0, 180) { my ($ux, $uy) = dir($a + $side); mleaf($x + $ux, $y + $uy, $a + $side, 16 * $s, 11 * $s, %o, teeth => 4); }
  poly('c1', ell($x, $y, 2.6 * $s, 2.6 * $s, 6, 45));
}

# Lilac flower spike seen from above, leaning a little: stacked whorls of tiny florets tapering to the tip.
sub spike {
  my ($x, $y, $r, $rot) = @_;
  my ($dx, $dy) = dir($rot + 30);
  for my $k (0 .. 3) {
    my $t = $k / 3; my $rr = $r * (1 - 0.45 * $t);
    my ($cx, $cy) = ($x + $dx * $r * 1.8 * $t, $y + $dy * $r * 1.8 * $t);
    poly('c1', ell($cx + 1.5, $cy + 1.5, $rr * 0.9, $rr * 0.9, 10, $rot));
    my $n = $k == 3 ? 3 : 6;
    for my $i (0 .. $n - 1) {
      my ($u, $v) = dir($rot + $i * 360 / $n + $k * 30);
      my ($fx, $fy) = ($cx + $u * $rr * 0.52, $cy + $v * $rr * 0.52);
      my $q = $rr * 0.4;
      poly('c5', ell($fx, $fy, $q, $q, 6, 30));
      poly('c3', ell($fx - $q * 0.35, $fy - $q * 0.35, $q * 0.3, $q * 0.3, 5));
    }
  }
}

sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o;
  srand($seed);
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12; my $k = 0.82 + rand(0.3); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
}
sub cracks {
  my ($n, $seed, $seg) = @_; srand($seed);
  for my $i (0 .. $n - 1) {
    my $a = $i * 360 / $n + rand(20); my ($x, $y) = (200, 200); my (@l, @r);
    for my $k (0 .. 4) {
      my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.4 - $k * 0.4;
      push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
      $x += $dx * $seg; $y += $dy * $seg;
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

# A clump: shoots scattered over a disc; outer (lower) shoots first so the middle domes up.
sub clump {
  my ($seed, $R, $n, $s, $pairs, $spikes) = @_;
  srand($seed); my @sh;
  my $ga = 137.508;
  for my $i (0 .. $n - 1) {
    my $r = $i == 0 ? 0 : $R * sqrt(($i - 0.3) / ($n - 1)); my ($u, $v) = dir($i * $ga + 20);
    push @sh, [200 + $u * $r + rand(8) - 4, 200 + $v * $r + rand(8) - 4, $r, rand(90), $s * (1 - 0.18 * $r / max(1, $R)) * (0.92 + rand(0.16)), $i];
  }
  for (sort { $b->[2] <=> $a->[2] } @sh) {
    my ($x, $y, $r, $rot, $sc, $i) = @$_;
    shoot($x, $y, $rot, $sc, $pairs, 100 + $i, $spikes && ($i % $spikes == 0) ? (spike => 17 * $sc) : ());
  }
}

# ---------------------------------------------------------------------------------------------
# 1. Planting material, front view: a rooted mint cutting (square stem, two leaf pairs, a fresh tip, white roots).
{ my ($x, $y0, $y1) = (200, 322, 112);
  srand(11);
  for my $k (0 .. 6) {                                         # roots fanning out from the cut end
    my $a = 40 + $k * 17 + rand(8) - 4; my ($rx, $ry) = ($x + ($k - 3) * 2, $y0 - 2);
    blade($rx, $ry, $a, 58 + rand(24), 5, ($k < 3 ? 1 : -1) * (20 + rand(25)), 'c3', 'c3', 0.3);
    blade($rx, $ry, $a, 30 + rand(10), 3, ($k < 3 ? -1 : 1) * 30, 'c3', 'c3', 0.3) if $k % 2;
  }
  blade($x, $y0, -90, $y0 - $y1, 11, 4, 'c2', 'c1', 0.75);
  poly('c1', [$x - 7, $y0 + 2], [$x + 7, $y0 + 2], [$x + 6, $y0 - 4], [$x - 6, $y0 - 4]);
  for my $node ([270, 6], [200, 0], [150, 0]) { poly('c1', [$x - 8, $node->[0] - 2], [$x + 8, $node->[0] - 2], [$x + 7, $node->[0] + 3], [$x - 7, $node->[0] + 3]); }
  mleaf($x - 5, 202, 200, 96, 62); mleaf($x + 5, 202, -20, 96, 62);
  mleaf($x - 4, 152, -140, 66, 44, teeth => 6); mleaf($x + 4, 152, -40, 66, 44, teeth => 6);
  mleaf($x - 2, 118, -112, 34, 22, teeth => 4); mleaf($x + 2, 118, -68, 34, 22, teeth => 4);
}
write_svg('1-seeds-front.svg', 'Rooted mint cutting');

# 2. Just planted, top down: three cuttings set in small soil pockets, one small leaf pair each.
for my $c ([168, 172, 20], [240, 176, 70], [204, 236, -30]) {
  my ($x, $y, $r) = @$c;
  soil($x, $y, 30, 25, int($x * 7 + $y));
  poly('c1', ell($x, $y, 4.5, 4.5, 4, 45)); poly('c2', ell($x - 1, $y - 1, 2.5, 2.5, 4, 45));
  for my $s (0, 180) { my ($u, $v) = dir($r + $s); mleaf($x + $u * 2, $y + $v * 2, $r + $s, 34, 23, teeth => 5); }
}
write_svg('2-sown.svg', 'Mint cuttings just planted');

# 3. First growth, top down: the cutting has rooted: a young shoot with crossing pairs, a side shoot starting.
soil(200, 200, 34, 30, 3);
shoot(236, 234, 30, 0.95, 2, 33);
shoot(192, 192, 10, 1.75, 3, 31);
write_svg('3-first-growth.svg', 'Mint first growth');

# 4. Second growth, top down: a little patch of shoots spreading from the runners.
soil(200, 200, 40, 34, 4);
clump(41, 78, 7, 1.2, 3, 0);
write_svg('4-second-growth.svg', 'Mint second growth');

# 5. Third growth, top down: a bushy patch with lilac flower spikes opening at some shoot tips.
soil(200, 200, 40, 34, 5);
clump(51, 108, 14, 1.1, 3, 2);
write_svg('5-third-growth.svg', 'Mint third growth with flowers');

# 6. Harvest, top down: a lush, dense spreading clump of fresh shoots.
soil(200, 200, 40, 34, 6);
clump(61, 138, 24, 1.15, 3, 0);
write_svg('6-harvest.svg', 'Mint ready to harvest');

# 7. Harvest item, front view: a bunch of four fresh mint sprigs tied with twine.
{ my ($bx, $by) = (200, 290);
  my @sp = ([-112, 176, 71], [-66, 166, 72], [-98, 196, 73], [-82, 186, 74]);
  for my $i (0 .. 3) {                                         # cut stems below the tie
    my $ex = $bx + ($i - 1.5) * 9; blade($bx + ($i - 1.5) * 3, $by, rad2deg(atan2(372 - $by, $ex - $bx - ($i - 1.5) * 3)), 84, 8, 0, 'c2', 'c1', 0.9);
    poly('c3', ell($ex, 372, 4, 2.6, 8));
  }
  for my $sp (@sp) {
    my ($a, $len, $seed) = @$sp; srand($seed); my $bend = (($a + 90) > 0 ? 1 : -1) * 10;
    my ($x0, $y0) = ($bx + ($a + 90) * 0.1, $by);
    blade($x0, $y0, $a, $len, 8, $bend, 'c2', 'c1', 0.5);
    my $pi = 0;
    for my $t (0.32, 0.56, 0.76, 0.92) {
      my ($px, $py, $pa) = walk($x0, $y0, $a, $len, $bend, $t);
      my $k = 1.2 - $t * 0.75; my $sp2 = 58 - $t * 26;
      for my $s (-1, 1) { mleaf($px, $py, $pa + $s * ($pi % 2 ? $sp2 + 14 : $sp2) + rand(10) - 5, 64 * $k, 44 * $k, teeth => $k > 0.6 ? 8 : 5); }
      $pi++;
    }
    my ($tx, $ty, $ta) = walk($x0, $y0, $a, $len, $bend, 1);
    for my $s (-1, 1) { mleaf($tx, $ty, $ta + $s * 18, 20, 13, teeth => 4); }
  }
  poly('c4', [$bx - 20, $by - 5], [$bx + 20, $by - 8], [$bx + 21, $by + 7], [$bx - 21, $by + 10]);
  poly('c3', [$bx - 20, $by - 5], [$bx + 20, $by - 8], [$bx + 20, $by - 2], [$bx - 20, $by + 1]);
  poly('c3', [$bx + 14, $by + 4], [$bx + 30, $by + 26], [$bx + 24, $by + 28], [$bx + 10, $by + 8]);
}
write_svg('7-harvest-front.svg', 'Harvested mint bunch');

# 8. Dead (never watered), top down: cracked dry soil, limp stems lying flat with shrivelled straw leaves.
soil(200, 200, 66, 56, 8);
cracks(9, 83, 14);
{ srand(84);
  for my $i (0 .. 6) {
    my $a = -80 + $i * 51 + rand(20) - 10; my $len = 70 + rand(36); my $bend = (rand(1) < .5 ? -1 : 1) * (40 + rand(40));
    my ($sx, $sy) = (200 + rand(30) - 15, 200 + rand(30) - 15);
    blade($sx, $sy, $a, $len, 8, $bend, 'c3', 'c4', 0.5);
    for my $t (0.3, 0.55, 0.8, 1) {
      my ($px, $py, $pa) = walk($sx, $sy, $a, $len, $bend, $t);
      for my $s (-1, 1) { next if rand(1) < 0.4;
        mleaf($px, $py, $pa + $s * (40 + rand(50)), 40 + rand(12), 28, wd => 0.75 + rand(0.15), lit => ['c3'], dark => ['c4'], plain => 1, teeth => 5); }
    }
  }
}
write_svg('8-dead.svg', 'Mint died from lack of water');
print "wrote 8 files to $OUT\n";

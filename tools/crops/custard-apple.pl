# Custard Apple crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/custard-apple.pl
# Grown as a compact bush. Top-down stages (2-6, 8) share one fixed scale centred on (200,200).
# Signature: round-to-heart-shaped pale green fruit made of rounded knobbly scales; long dull pale leaves;
# inside, creamy white flesh with glossy black seeds.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/custard-apple';
mkdir 'crops'; mkdir $OUT;
# c1 leaf green (also crevices between the fruit scales), c2 lit leaf green (also the shaded side of each scale),
# c3 cream (flesh, highlights, flowers, dried leaves), c4 dark soil / black seeds, c5 pale yellow-green fruit
my %PAL = (c1 => '#3F6B38', c2 => '#7FA653', c3 => '#F6F1DE', c4 => '#3B2A20', c5 => '#E3E79A');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub ell { my ($x, $y, $rx, $ry, $n, $rot) = @_; $rot //= 0; map { my ($u, $v) = dir($rot + $_ * 360 / $n); [$x + $u * $rx, $y + $v * $ry] } 0 .. $n - 1 }

# A tapered blade / stalk / hair from (x,y) heading `ang`, bending `bend` degrees. $taper < 1 leaves a blunt end.
# Returns the end point and heading.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $taper) = @_;
  $taper //= 1;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $t) ** 0.85 + ($i == $n && $taper == 1 ? 0 : 0.5);
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

# Point and heading at fraction $t along a bent path (same stepping as blade).
sub walk {
  my ($x, $y, $ang, $len, $bend, $t) = @_; my $n = 10; my $a = $ang;
  for (1 .. int($t * $n + 0.5)) { my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  ($x, $y, $a);
}

# Glossy elliptic leaf with a pointed (acuminate) tip on a short petiole: lit and shaded halves, a sunk midrib on
# the lit half and a pale glint along the shaded half so it reads shiny.
sub oleaf {
  my ($x, $y, $ang, $len, $w, $bend, $L, $D, %o) = @_;
  my $pf = $o{pf} // 0.1; my $n = 16; my (@mid, @l, @r, @hw, @dir);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a);
    my $u = $t < $pf ? 0 : ($t - $pf) / (1 - $pf);
    my $hw = $t < $pf ? 1.3 : $w / 2 * sin(pi * min(0.999, $u ** ($o{p} // 0.9))) ** ($o{q} // 0.75);
    $hw = 0 if $i == $n;
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py]; push @hw, $hw; push @dir, [$dx, $dy];
    last if $i == $n;
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $L : $D, @l, reverse @mid);
  poly($leftLit ? $D : $L, @r, reverse @mid);
  return if $o{plain};
  my $s = $leftLit ? -1 : 1;              # sign that points into the lit half
  my $i0 = int($n * ($pf + 0.08)); my $i1 = $n - 3;
  # midrib groove on the lit half
  poly($D, (map { my ($mx, $my) = @{$mid[$_]}; my ($ux, $uy) = @{$dir[$_]}; my $k = $o{rib} // 1.4; [$mx - $uy * $s * $k * (1 - ($_ - $i0) / ($i1 - $i0 + 2)), $my + $ux * $s * $k * (1 - ($_ - $i0) / ($i1 - $i0 + 2))] } $i0 .. $i1),
           $mid[$i1 + 1], reverse(@mid[$i0 .. $i1]));
  # side veins as thin grooves on the lit half
  for my $k (1 .. ($o{veins} // 0)) {
    my $i = int($i0 + ($i1 - $i0) * $k / (($o{veins}) + 1)); my ($mx, $my) = @{$mid[$i]}; my ($ux, $uy) = @{$dir[$i]};
    my $h = $hw[$i] * 0.8; my ($ex, $ey) = ($mx - $uy * $s * $h + $ux * $h * 0.7, $my + $ux * $s * $h + $uy * $h * 0.7);
    poly($D, [$mx - $ux * 1.1, $my - $uy * 1.1], [$ex, $ey], [$mx + $ux * 1.1, $my + $uy * 1.1]);
  }
  # glint on the shaded half
  unless ($o{noglint}) {
    my @g1; my @g2; my $ga = int($n * 0.28); my $gb = int($n * 0.72);
    for my $i ($ga .. $gb) {
      my ($mx, $my) = @{$mid[$i]}; my ($ux, $uy) = @{$dir[$i]}; my $v = sin(pi * ($i - $ga) / ($gb - $ga));
      my $c = $hw[$i] * 0.5; my $gw = $hw[$i] * 0.13 * $v + 0.2;
      push @g1, [$mx + $uy * $s * ($c - $gw), $my - $ux * $s * ($c - $gw)];
      push @g2, [$mx + $uy * $s * ($c + $gw), $my - $ux * $s * ($c + $gw)];
    }
    poly($o{glint} // $L, @g1, reverse @g2);
  }
}

# A rambutan: oval red fruit wrapped in long soft curling hairs with green-yellow tips.
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
    my $a = $i * 360 / $n + rand(20); my ($x, $y) = (200, 200); my (@l, @r);
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

# Top-down bush: woody branches from the crown carrying pairs of glossy leaflets; returns branch paths.
# Leaves are drawn outer-first so the canopy domes up toward the middle.
sub bush {
  my (%o) = @_;
  srand($o{seed});
  my ($L, $D) = ($o{light} // 'c2', $o{dark} // 'c1');
  my (@leaves, @br);
  my $nb = $o{n};
  for my $i (0 .. $nb - 1) {
    my $a = ($o{start} // -90) + $i * 360 / $nb + rand(14) - 7;
    my $len = $o{len} * (0.86 + rand(0.2)); my $bend = (rand(1) < 0.5 ? -1 : 1) * (12 + rand(16));
    push @br, [$a, $len, $bend];
    my $per = $o{per};
    for my $k (1 .. $per) {
      my $t = 0.25 + 0.7 * $k / $per;
      my ($px, $py, $pa) = walk(200, 200, $a, $len, $bend, $t);
      for my $side (-1, 1) {
        my $ll = $o{leaf} * (0.8 + 0.3 * $t + rand(0.12));
        push @leaves, [$px, $py, $pa + $side * (44 + rand(18)), $ll, $ll * ($o{wf} // 0.42), $side * ($o{curl} // 10) * (0.5 + rand(1))];
      }
    }
    my ($px, $py, $pa) = walk(200, 200, $a, $len, $bend, 1);
    my $ll = $o{leaf} * 1.12;
    push @leaves, [$px, $py, $pa + rand(10) - 5, $ll, $ll * ($o{wf} // 0.42), rand(12) - 6];
  }
  push @leaves, @{$o{extra} // []};
  blade(200, 200, $_->[0], $_->[1], $o{bw} // 8, $_->[2], $o{blight} // 'c1', $o{bdark} // 'c4', 0.6) for @br;
  for (sort { (($b->[0] - 200) ** 2 + ($b->[1] - 200) ** 2) <=> (($a->[0] - 200) ** 2 + ($a->[1] - 200) ** 2) } @leaves) {
    oleaf(@$_, $L, $D, %{$o{lo} // {}});
  }
  @br;
}


# A custard apple: rounded knobbly scales packed over a round-to-heart body.
# %o: top (seen from above, round with the stem in the middle), s (scale size), unripe, dead, stem, rot.
sub capple {
  my ($x, $y, $r, %o) = @_;
  my $rot = $o{rot} // 0; my $s = $o{s} // $r * 0.36;
  my ($B, $M, $C, $H) = $o{unripe} ? ('c2', 'c1', 'c1', 'c5') : $o{dead} ? ('c4', 'c4', 'c4', 'c2') : ("c5", "c2", "c1", "c3");
  my ($cr, $sr) = (cos(deg2rad($rot)), sin(deg2rad($rot)));
  my $heart = $o{top} ? 0 : 0.14;
  # body shape: x stretched near the top, narrowing toward the bottom (heart-ish)
  my $F = sub { my ($u, $v) = @_; my $k = 1 + $heart * (-$v); my $yy = $v * $r * ($o{top} ? 1 : 1.04); [$u * $r * $k, $yy] };
  my $E = sub { my ($u, $v) = @_; my $p = $F->($u, $v); [$x + $p->[0] * $cr - $p->[1] * $sr, $y + $p->[0] * $sr + $p->[1] * $cr] };
  # stalk behind (front view)
  if ($o{stem}) {
    my $p = $E->(0, -0.86);
    blade(@$p, $rot - 90 + 8, $o{stem}, $r * 0.13, 16, 'c2', 'c1', 0.3);
  }
  # crevice-coloured silhouette, a little bumpy
  my @o = map { my ($u, $v) = dir($_ * 10); my $b = 1 + 0.035 * cos(deg2rad($_ * 10 * 9)); $E->($u * $b, $v * $b) } 0 .. 35;
  poly($C, @o);
  # scales: hex grid in (u,v) on the unit disc; rounded bumps squashed toward the rim, far ones first
  my @d; my $row = 0; my $st = $s / $r;
  for (my $gv = -1; $gv <= 1.001; $gv += $st * 0.87) {
    for (my $gu = -1 - ($row % 2 ? $st / 2 : 0); $gu <= 1.001; $gu += $st) {
      my $r2 = $gu * $gu + $gv * $gv; next if $r2 > 0.98;
      push @d, [$gu, $gv, $r2];
    }
    $row++;
  }
  for (sort { $b->[2] <=> $a->[2] } @d) {
    my ($gu, $gv, $r2) = @$_; my $z = sqrt(max(0.04, 1 - $r2));
    my $rl = sqrt($r2) || 1e-6; my ($ru, $rv) = ($gu / $rl, $gv / $rl);
    my $fk = max(0.36, $z ** 0.75);
    my $sh = ($gu + $gv) * 0.7071 > ($o{bright} ? 0.6 : 0.38);      # this scale sits in the shaded side
    my @c;
    for my $k (0 .. 9) {
      my ($cu, $cv) = dir($k * 36 + 18); $cu *= $st * 0.54; $cv *= $st * 0.54;
      my $pr = ($cu * $ru + $cv * $rv) * $fk; my $pt = -$cu * $rv + $cv * $ru;
      push @c, $E->($gu + $pr * $ru - $pt * $rv, $gv + $pr * $rv + $pt * $ru);
    }
    my $cx = 0; my $cy = 0; $cx += $_->[0] / 10, $cy += $_->[1] / 10 for @c;
    poly($sh ? $M : $B, @c);
    # shaded lower-right half of each knob
    my @rs = sort { (($c[$b][0] - $cx) + ($c[$b][1] - $cy)) <=> (($c[$a][0] - $cx) + ($c[$a][1] - $cy)) } 0 .. 9;
    my $i0 = $rs[0];
    my @sh = map { $c[($i0 - 2 + $_) % 10] } 0 .. 4;
    poly($sh ? $C : $M, @sh, [$cx + ($sh[4][0] - $cx) * 0.3 + ($sh[0][0] - $cx) * 0.3, $cy + ($sh[4][1] - $cy) * 0.3 + ($sh[0][1] - $cy) * 0.3]) if $sh || !$o{bright} || ($gu + $gv) > -0.2;
    # bright tip on lit knobs
    unless ($sh || $o{dead}) {
      my @hs = sort { (($c[$a][0] - $cx) + ($c[$a][1] - $cy)) <=> (($c[$b][0] - $cx) + ($c[$b][1] - $cy)) } 0 .. 9;
      my $j = $hs[0]; my $p = $c[$j]; my $q = $c[($j + 1) % 10]; my $m = $c[($j + 9) % 10];
      poly($H, [$cx + ($m->[0] - $cx) * 0.75, $cy + ($m->[1] - $cy) * 0.75], [$cx + ($p->[0] - $cx) * 0.85, $cy + ($p->[1] - $cy) * 0.85],
               [$cx + ($q->[0] - $cx) * 0.75, $cy + ($q->[1] - $cy) * 0.75], [$cx + ($p->[0] - $cx) * 0.35, $cy + ($p->[1] - $cy) * 0.35]) if ($gu + $gv) < -0.15 || $o{top} && ($gu + $gv) < ($o{bright} ? -0.1 : 0.1);
    }
  }
  # stalk seen from above: a short stub with a little calyx star in the middle
  if ($o{top} && !$o{nostub}) {
    for my $k (0 .. 2) { my $a = $k * 120 + $rot; blade($x, $y, $a, $r * 0.32, $r * 0.2, 0, 'c2', 'c1'); }
    poly('c1', ell($x + 1, $y + 1, $r * 0.12, $r * 0.12, 7)); poly('c2', ell($x - 0.5, $y - 0.5, $r * 0.07, $r * 0.07, 6));
  }
}

# A shiny black-brown custard apple seed.
sub cseed {
  my ($x, $y, $ang, $len, $w, $hi) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o = map { my $th = 2 * pi * $_ / 14; my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 - 0.15 * cos($th)); [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v] } 0 .. 13;
  poly('c4', @o);
  my $sg = lit($nx, $ny) ? 1 : -1;
  my ($gx, $gy) = ($x + $nx * $sg * $w * 0.2 - $dx * $len * 0.05, $y + $ny * $sg * $w * 0.2 - $dy * $len * 0.05);
  my @hf = $sg > 0 ? @o[2 .. 6] : @o[9 .. 13];
  poly("c2", @hf, map { [$x + ($_->[0] - $x) * 0.45 + $nx * $sg * $w * 0.08, $y + ($_->[1] - $y) * 0.45 + $ny * $sg * $w * 0.08] } reverse @hf) if $_[6];
  poly($hi // "c3", [$gx - $dx * $len * 0.24, $gy - $dy * $len * 0.24], [$gx + $nx * $sg * $w * 0.07, $gy + $ny * $sg * $w * 0.07], [$gx + $dx * $len * 0.16, $gy + $dy * $len * 0.16], [$gx - $nx * $sg * $w * 0.05, $gy - $ny * $sg * $w * 0.05]);
}

# A custard apple cut in half, cut face toward the viewer: knobbly rim, creamy segmented flesh, black seeds.
sub capple_cut {
  my ($x, $y, $r, $ry) = @_;
  # knobbly skin edge all round
  my $n = 18;
  poly('c1', ell($x + 3, $y + 3, $r * 1.04, $ry * 1.04, 30));
  for my $k (0 .. $n - 1) {
    my $th = 360 * $k / $n; my ($u, $v) = dir($th);
    my $l = ($u * -0.7071 + $v * -0.7071);
    poly($l > 0.2 ? 'c5' : 'c2', ell($x + $u * $r * 0.96, $y + $v * $ry * 0.96, $r * 0.17, $ry * 0.15, 8, $th));
  }
  poly('c2', ell($x, $y, $r * 0.92, $ry * 0.92, 30));
  my @f = ell($x - $r * 0.01, $y - $ry * 0.01, $r * 0.86, $ry * 0.86, 30);
  poly('c3', @f);
  # soft segment grooves radiating from the core
  for my $k (0 .. 11) {
    my $th = $k * 30 + 15; my ($u, $v) = dir($th);
    poly('c5', [$x + $u * $r * 0.22, $y + $v * $ry * 0.22], [$x + ($u * 0.8 - $v * 0.02) * $r, $y + ($v * 0.8 + $u * 0.02) * $ry], [$x + ($u * 0.8 + $v * 0.02) * $r, $y + ($v * 0.8 - $u * 0.02) * $ry]);
  }
  # fibrous core
  poly('c5', ell($x, $y, $r * 0.12, $ry * 0.3, 10));
  poly('c3', ell($x - $r * 0.03, $y - $ry * 0.04, $r * 0.05, $ry * 0.18, 8));
  # black seeds bedded in the segments
  for my $k (0 .. 9) {
    my $th = $k * 36 + 8 + ($k % 2) * 6; my ($u, $v) = dir($th); my $rr = 0.5 + ($k % 2) * 0.12;
    cseed($x + $u * $r * $rr, $y + $v * $ry * $rr, $th, $r * 0.22, $r * 0.12);
  }
}

# Annona flower from above: three thick narrow cream-green petals.
sub aflower {
  my ($x, $y, $r, $rot) = @_;
  for my $k (0 .. 2) { blade($x, $y, $rot + $k * 120, $r, $r * 0.36, 10, 'c3', 'c2'); }
  poly('c1', ell($x, $y, $r * 0.16, $r * 0.16, 6));
}

# ---------------------------------------------------------------------------------------------
# 1. Planting material, front view: glossy black seeds in front of a whole custard apple.
capple(232, 168, 82, stem => 22, rot => 8);
cseed(126, 284, -30, 64, 36); cseed(196, 312, 4, 66, 38); cseed(270, 300, 32, 62, 36); cseed(176, 262, -70, 58, 34);
write_svg('1-seeds-front.svg', 'Custard apple seeds');

# 2. Just sown, top down: black seeds pressed into soil pockets.
my @sown = ([166, 168, -30], [240, 164, 40], [202, 214, 95], [150, 240, 150], [252, 238, -60]);
for (@sown) { soil($_->[0], $_->[1], 28, 23, int($_->[0] * 7 + $_->[1])); }
for (@sown) { cseed($_->[0], $_->[1], $_->[2], 34, 20, undef, 1); }
write_svg('2-sown.svg', 'Custard apple just sown');

# 3. First growth, top down: a seedling with a few long pale leaves.
soil(200, 200, 34, 30, 3);
blade(200, 200, -120, 16, 6, 0, 'c2', 'c1', 0.5);
oleaf(200, 200, -62, 86, 30, 12, 'c2', 'c1', noglint => 1, veins => 3); oleaf(200, 200, 122, 82, 28, -12, 'c2', 'c1', noglint => 1, veins => 3);
oleaf(200, 200, -170, 62, 22, 8, 'c2', 'c1', noglint => 1); oleaf(200, 200, 30, 64, 22, -8, 'c2', 'c1', noglint => 1);
write_svg('3-first-growth.svg', 'Custard apple first growth');

# 4. Second growth, top down: young bush.
soil(200, 200, 34, 30, 4);
bush(seed => 41, n => 6, len => 70, per => 2, leaf => 54, wf => 0.36, start => -80, bw => 8, blight => 'c2', lo => { noglint => 1, veins => 3 });
write_svg('4-second-growth.svg', 'Custard apple second growth');

# 5. Third growth, top down: full bush with three-petalled flowers and small green fruit.
soil(200, 200, 34, 30, 5);
{
  my @br = bush(seed => 51, n => 8, len => 98, per => 3, leaf => 58, wf => 0.36, start => -84, bw => 9, blight => 'c2', lo => { noglint => 1, veins => 3 });
  my $j = 0;
  for my $bb (@br) {
    my ($x, $y, $ba) = walk(200, 200, @$bb, 0.62); $j++;
    my ($dx, $dy) = dir($ba + ($j % 2 ? 70 : -70));
    if ($j % 2) { aflower($x + $dx * 12, $y + $dy * 12, 21, $j * 27); aflower($x - $dx * 10, $y - $dy * 10, 17, $j * 51); }
    else { blade($x, $y, $ba + ($j % 4 ? 70 : -70), 12, 3, 0, 'c2', 'c1'); capple($x + $dx * 16, $y + $dy * 16, 12, top => 1, unripe => 1, s => 6, nostub => 1); }
  }
  aflower(186, 186, 17, 10); aflower(218, 214, 16, 50);
}
write_svg('5-third-growth.svg', 'Custard apple third growth, flowering');

# 6. Harvest, top down: the bush hung with ripe knobbly custard apples.
soil(200, 200, 34, 30, 6);
{
  my @br = bush(seed => 61, n => 8, len => 116, per => 3, leaf => 62, wf => 0.36, start => -76, bw => 10, blight => 'c2', lo => { noglint => 1, veins => 3 });
  my $j = 0; my @f;
  for my $bb (@br) { $j++; next unless $j % 2 == 0; push @f, [walk(200, 200, @$bb, 0.8)]; }
  # big ripe fruit: cast shadow on the leaves, a dark rim, short stalk from the branch, then the knobbly fruit
  for (@f) { my ($x, $y) = @$_; poly("c1", ell($x + 10, $y + 11, 41, 41, 20)); }
  for (@f) {
    my ($x, $y, $ba) = @$_; my ($dx, $dy) = dir($ba);
    blade($x - $dx * 46, $y - $dy * 46, $ba, 40, 6, 0, 'c2', 'c1', 0.4);
    poly("c4", ell($x + 1.5, $y + 1.5, 41.5, 41.5, 24));
    capple($x, $y, 39, top => 1, s => 17, rot => $ba, bright => 1);
  }
}
write_svg('6-harvest.svg', 'Custard apples ready to harvest');

# 7. Harvested produce, front view: a whole custard apple and one cut in half.
capple(152, 176, 96, stem => 26, rot => -8);
capple_cut(262, 266, 84, 92);
write_svg('7-harvest-front.svg', 'Harvested custard apples');

# 8. Dead (never watered), top down: cracked dry soil, bare branches, curled dry leaves, a shrivelled dark fruit.
soil(200, 200, 66, 56, 8);
cracks(8, 83, 14, 'c3');
{
  srand(84);
  my @br;
  for my $i (0 .. 5) { push @br, [-80 + $i * 60 + rand(14) - 7, 86 + rand(30), (rand(1) < 0.5 ? -1 : 1) * (30 + rand(30))]; }
  blade(200, 200, $_->[0], $_->[1], 7, $_->[2], 'c3', 'c4', 0.7) for @br;
  my $j = 0;
  for my $bb (@br) {
    for my $t (0.35, 0.62, 0.9) {
      my ($px, $py, $pa) = walk(200, 200, @$bb, $t); my $s = ($j++ % 2) ? 1 : -1;
      oleaf($px, $py, $pa + $s * (60 + rand(30)), 50 + rand(10), 14 + rand(4), $s * (40 + rand(40)), 'c3', 'c4', noglint => 1);
    }
  }
  my ($px, $py) = walk(200, 200, @{$br[3]}, 0.7);
  capple($px, $py, 15, top => 1, s => 6, dead => 1, nostub => 1);
}
write_svg('8-dead.svg', 'Custard apple died from lack of water');
print "wrote 8 files to $OUT\n";

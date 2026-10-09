# Carolina Reaper crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/carolina-reaper.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# The pod is the signature: short, fat, lumpy and wrinkled, glossy deep red, ending in a curled scorpion tail.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/carolina-reaper';
mkdir 'crops'; mkdir $OUT;
# c1 leaf green, c2 lit green, c3 cream (seeds, flowers, gloss, dried leaves), c4 dark soil / pod shade, c5 reaper red
my %PAL = (c1 => '#3B7330', c2 => '#78B24A', c3 => '#F4E6BE', c4 => '#55291F', c5 => '#C8202C');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A tapered blade or stalk from (x,y) heading `ang`, bending `bend` degrees (as in wheat.pl). $taper < 1 = cut end.
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

# End point and heading of a bent path at fraction $upto (same stepping as blade).
sub walk {
  my ($x, $y, $ang, $len, $bend, $upto) = @_; $upto //= 1;
  my $n = 10; my $a = $ang;
  for my $i (1 .. int($n * $upto + 0.5)) { my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  return ($x, $y, $a);
}

# Pepper leaf: pointed oval on a short petiole with a softly wavy (wrinkled) edge, lit and shaded halves.
sub pleaf {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $wav, $ph) = @_;
  $wav //= 0.07; $ph //= 0;
  my $n = 14; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $u = $t < 0.1 ? 0 : ($t - 0.1) / 0.9;
    my $hw = $t < 0.1 ? 1.4 : $w / 2 * sin(pi * $u ** 0.72) ** 0.8;
    my $hl = $hw * (1 + $wav * sin($t * 23 + $ph)); my $hr = $hw * (1 + $wav * sin($t * 23 + $ph + 2.1));
    $hl = $hr = 0 if $i == $n;
    push @l, [$px - $dy * $hl, $py + $dx * $hl];
    push @r, [$px + $dy * $hr, $py - $dx * $hr];
    push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# The Carolina Reaper pod. (x,y) = top of the shoulders where the calyx sits, heading `ang` toward the tail.
# $curl = degrees the scorpion tail hooks over its last stretch (sign = side). $ripe: 1 red, 0 green.
# $stem = length of the stalk leaving the calyx; $shr = 1 shrivels it (dead stage).
sub pod {
  my ($x, $y, $ang, $len, $w, $curl, $ripe, $seed, $stem, $shr) = @_;
  $stem //= 0; $shr //= 0;
  srand($seed);
  my ($body, $shade) = $ripe ? ('c5', 'c4') : ('c2', 'c1');
  $body = 'c4' if $shr;
  my $n = 30;
  my $sway = rand(16) - 8;
  my @ph = (rand(3.14), rand(3.14));
  my $lump = 0.14;
  my $sq = 1 - 0.3 * $shr;
  my (@mid, @l, @r, @ang, @bl, @br);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $f = $t < 0.12 ? 0.78 + 0.22 * sin(pi / 2 * $t / 0.12)
          : $t < 0.46 ? 1 - 0.12 * (($t - 0.12) / 0.34) ** 1.5
          : $t < 0.7  ? 0.2 + 0.68 * cos(pi / 2 * ($t - 0.46) / 0.24) ** 1.3
          : 0.2 * ((1 - $t) / 0.3) ** 0.8;
    $f *= $sq;
    my $on = $t > 0.05 && $t < 0.68 ? 1 : 0;
    # lumps: rounded bulges with sharp dents between them (|sin|)
    my $bl = abs(sin(pi * 5.2 * $t + $ph[0])); my $br = abs(sin(pi * 4.6 * $t + $ph[1]));
    my $hl = $w / 2 * $f * (1 + $on * $lump * (2 * $bl ** 0.6 - 1.2));
    my $hr = $w / 2 * $f * (1 + $on * $lump * (2 * $br ** 0.6 - 1.2));
    ($hl, $hr) = (0, 0) if $i == $n;
    push @l, [$px - $dy * $hl, $py + $dx * $hl];
    push @r, [$px + $dy * $hr, $py - $dx * $hr];
    push @mid, [$px, $py]; push @ang, $a; push @bl, $bl; push @br, $br;
    my $turn = $t < 0.6 ? $sway / ($n * 0.6) : $curl * 2 * (($t - 0.6) / 0.4) / ($n * 0.4);
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $turn;
  }
  my ($dx, $dy) = dir($ang);
  my $leftLit = lit(-$dy, $dx);
  my $side = $leftLit ? 1 : -1;                                    # +1: lit side is the left outline
  my ($cl, $cd) = $shr ? ('c3', 'c4') : ('c2', 'c1');
  # stem first (behind): a thick bent green stalk leaving the calyx backwards
  blade($x - $dx * $w * 0.02, $y - $dy * $w * 0.02, $ang + 180, $stem, max(4, $w * 0.2), ($curl > 0 ? -1 : 1) * 30, $cl, $cd, 0.4) if $stem;
  # rounded shoulders behind the calyx
  my $h0 = $w / 2 * 0.78 * $sq;
  my @back;
  for my $k (1 .. 7) {
    my $phi = deg2rad(-90 + $k * 180 / 8);
    my $c = cos($phi) * 0.5; my $s = sin($phi);
    push @back, [$x - $dx * $h0 * $c - $dy * $h0 * $s, $y - $dy * $h0 * $c + $dx * $h0 * $s];
  }
  poly($shade, @l, reverse(@r), @back);
  my ($L, $R, $LB) = $leftLit ? (\@l, \@r, \@bl) : (\@r, \@l, \@br);
  unless ($shr) {
    # lit body: lit half in full, shaded half pulled in so a dark rim stays on the shaded side
    my @inner = map { my $k = 0.22 + 0.14 * sin($_ * 0.9 + $ph[1]); [$mid[$_][0] + ($R->[$_][0] - $mid[$_][0]) * $k, $mid[$_][1] + ($R->[$_][1] - $mid[$_][1]) * $k] } 0 .. $n - 2;
    my @backL = $leftLit ? @back[3 .. 6] : reverse(@back[0 .. 3]);
    poly($body, @backL, @$L[0 .. $n - 1], reverse @inner);
  } else {
    poly("c5", map { [$mid[$_][0] + ($L->[$_][0] - $mid[$_][0]) * 0.5, $mid[$_][1] + ($L->[$_][1] - $mid[$_][1]) * 0.5] } 3 .. $n - 10);
  }
  # wrinkles: dark creases cut in from the lit edge at the dents between lumps, curving toward the tail
  for my $i (2 .. int($n * 0.66)) {
    next unless $LB->[$i] < $LB->[$i - 1] && $LB->[$i] <= $LB->[$i + 1];
    my ($mx, $my) = @{$mid[$i]}; my ($ex, $ey) = @{$L->[$i]};
    my ($ax, $ay) = dir($ang[$i]); my $d = $w * 0.045;
    my $k = 0.3 + rand(0.15);
    my ($ix, $iy) = ($mx + ($ex - $mx) * $k + $ax * $w * 0.08, $my + ($ey - $my) * $k + $ay * $w * 0.08);
    my ($jx, $jy) = ($mx + ($ex - $mx) * 0.72 + $ax * $w * 0.01, $my + ($ey - $my) * 0.72 + $ay * $w * 0.01);
    poly($shade, [$ex - $ax * $d, $ey - $ay * $d], [$jx - $ax * $d * 0.5, $jy - $ay * $d * 0.5], [$ix, $iy], [$jx + $ax * $d * 0.4, $jy + $ay * $d * 0.4], [$ex + $ax * $d * 0.5, $ey + $ay * $d * 0.5]);
  }
  # glossy streaks along the lit shoulder
  unless ($shr) {
    for my $g ([0.07, 0.3, 0.6, 0.075], [0.38, 0.5, 0.52, 0.05]) {
      my ($t0, $t1, $k, $gw) = @$g; my (@a, @b);
      my ($i0, $i1) = (int($t0 * $n), int($t1 * $n));
      for my $i ($i0 .. $i1) {
        my $u = ($i - $i0) / max(1, $i1 - $i0); my $hw = $w * $gw * sin(pi * $u) ** 0.7 + 0.3;
        my ($mx, $my) = @{$mid[$i]}; my ($ex, $ey) = @{$L->[$i]};
        my $kk = $k + 0.1 * sin(pi * $u);
        my ($cx, $cy) = ($mx + ($ex - $mx) * $kk, $my + ($ey - $my) * $kk);
        my ($ax, $ay) = dir($ang[$i]);
        push @a, [$cx - $ay * $hw, $cy + $ax * $hw]; push @b, [$cx + $ay * $hw, $cy - $ax * $hw];
      }
      poly('c3', @a, reverse @b);
    }
  }
  # calyx: a cupped green cap with a wavy lower edge clasping the shoulders
  my $cw = $h0 * 0.86; my (@top, @bot);
  for my $k (0 .. 8) {
    my $s = -1 + 2 * $k / 8; my $v = $s * $cw;
    my $ft = -$w * 0.05 * (1 - $s * $s) - $w * 0.01;
    my $fb = $w * (0.05 + ($k % 2 ? 0.06 : 0.015)) * (1 - 0.5 * $s * $s) + $w * 0.03;
    push @top, [$x + $dx * $ft - $dy * $v, $y + $dy * $ft + $dx * $v];
    push @bot, [$x + $dx * $fb - $dy * $v, $y + $dy * $fb + $dx * $v];
  }
  poly($cd, @top, reverse @bot);
  my @litk = $leftLit ? (4 .. 8) : (0 .. 4);
  poly($cl, @top[@litk], reverse(@bot[@litk]));
}


# Flat chili seed: a round-ish disc with a small notch (hilum), cream with a shaded rim.
sub seed {
  my ($x, $y, $rot, $r, $sq) = @_; $sq //= 0.8;
  my @o;
  for my $i (0 .. 15) {
    my $th = 2 * pi * $i / 16; my $k = 1 - 0.3 * exp(-((($th - pi) ** 2) / 0.1));
    my ($c, $s) = (cos($th) * $r * $k, sin($th) * $r * $sq * $k);
    my $ra = deg2rad($rot);
    push @o, [$x + $c * cos($ra) - $s * sin($ra), $y + $c * sin($ra) + $s * cos($ra)];
  }
  poly('c4', @o);
  my @in = map { [$x + ($_->[0] - $x) * 0.9 - $r * 0.05, $y + ($_->[1] - $y) * 0.9 - $r * 0.05] } @o;
  poly('c3', @in);
}

# Small 5-petal star flower (white-greenish), seen from above.
sub flower {
  my ($x, $y, $r, $rot) = @_;
  for my $i (0 .. 4) { my $a = $rot + 36 + $i * 72; blade($x, $y, $a, $r * 0.55, $r * 0.3, 0, 'c2', 'c1'); }
  for my $i (0 .. 4) {
    my $a = $rot + $i * 72; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    poly('c3', [$x + $nx * $r * 0.22, $y + $ny * $r * 0.22], [$x + $dx * $r * 0.7 + $nx * $r * 0.3, $y + $dy * $r * 0.7 + $ny * $r * 0.3],
               [$x + $dx * $r, $y + $dy * $r], [$x + $dx * $r * 0.7 - $nx * $r * 0.3, $y + $dy * $r * 0.7 - $ny * $r * 0.3],
               [$x - $nx * $r * 0.22, $y - $ny * $r * 0.22]);
  }
  my @p; for my $i (0 .. 4) { my ($dx, $dy) = dir($rot + 36 + $i * 72); push @p, [$x + $dx * $r * 0.3, $y + $dy * $r * 0.3]; }
  poly('c2', @p);
  my @q; for my $i (0 .. 4) { my ($dx, $dy) = dir($rot + $i * 72); push @q, [$x + $dx * $r * 0.13, $y + $dy * $r * 0.13]; }
  poly('c1', @q);
}

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
      my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.6 - $k * 0.45;
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

# A top-down pepper bush: $nb branches, each with layered wavy pointed leaves; returns branch tips.
our ($WF, $CURL, $WAV) = (0.48, 0, 0.07);   # leaf width ratio, extra curl, edge wave (the dead plant shrivels)
sub bush {
  my ($nb, $reach, $seed, $start, $light, $dark) = @_;
  $light //= 'c2'; $dark //= 'c1';
  srand($seed); my (@leaves, @tips);
  for my $i (0 .. $nb - 1) {
    my $a = ($start // -90) + $i * 360 / $nb + rand(14) - 7;
    my $r = $reach * (0.88 + rand(0.16));
    my ($dx, $dy) = dir($a);
    for my $k (1 .. 3) {
      my $d = $r * (0.08 + 0.24 * ($k - 1)); my $len = $r * (0.4 + 0.1 * $k) + rand(6);
      for my $s (-1, 1) { push @leaves, [200 + $dx * $d, 200 + $dy * $d, $a + $s * (50 - $k * 10) + rand(12) - 6, $len, $len * $WF, $s * (8 + rand(12) + rand($CURL)), rand(6)]; }
    }
    push @leaves, [200 + $dx * $r * 0.5, 200 + $dy * $r * 0.5, $a + rand(10) - 5, $r * 0.52, $r * 0.52 * $WF, rand(14) - 7 + rand($CURL), rand(6)];
    push @tips, [200 + $dx * $r * 0.62, 200 + $dy * $r * 0.62, $a];
  }
  for (sort { $b->[3] <=> $a->[3] } @leaves) { my @v = @$_; pleaf(@v[0 .. 5], $light, $dark, $WAV, $v[6]); }
  return @tips;
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a little heap of flat pale chili seeds, one dried reaper pod behind them.
pod(226, 138, 64, 140, 82, -190, 1, 11, 24);
{ srand(12); my @sd;
  for my $row ([318, 5], [286, 4], [256, 3], [228, 2]) { my ($y, $c) = @$row;
    for my $k (0 .. $c - 1) { push @sd, [200 + ($k - ($c - 1) / 2) * 50 + rand(10) - 5 - 6, $y + rand(8) - 4, rand(360), 25 + rand(3)]; } }
  push @sd, [194, 204, 30, 25];
  seed(@$_) for sort { $a->[1] <=> $b->[1] } @sd; }
write_svg('1-seeds-front.svg', 'Carolina Reaper seeds');

# 2. Just sown, top down: seeds pressed into small soil pockets.
my @sown = ([170, 172, -20], [236, 170, 50], [200, 228, 100]);
for (@sown) { soil($_->[0], $_->[1], 34, 28, int($_->[0] * 7 + $_->[1])); }
for (@sown) { seed($_->[0] - 10, $_->[1] + 5, $_->[2], 13); seed($_->[0] + 11, $_->[1] - 6, $_->[2] + 140, 12.5); }
write_svg('2-sown.svg', 'Carolina Reaper just sown');

# 3. First growth, top down: two long seed leaves and the first pair of true leaves.
soil(200, 200, 34, 30, 3);
pleaf(200, 200, -160, 86, 24, -10, 'c2', 'c1', 0.02); pleaf(200, 200, 20, 86, 24, -10, 'c2', 'c1', 0.02);
pleaf(200, 200, -76, 68, 38, 10, 'c2', 'c1', 0.08, 1); pleaf(200, 200, 104, 64, 36, 10, 'c2', 'c1', 0.08, 3);
write_svg('3-first-growth.svg', 'Carolina Reaper first growth');

# 4. Second growth, top down: a young bushy pepper plant.
soil(200, 200, 34, 30, 4);
bush(6, 104, 41, -80);
write_svg('4-second-growth.svg', 'Carolina Reaper second growth');

# 5. Third growth, top down: full bush with small white flowers and the first green pods.
soil(200, 200, 34, 30, 5);
my @t5 = bush(8, 122, 51, -86);
srand(52);
my $j = 0;
for my $t (@t5) {
  my ($x, $y, $a) = @$t; my ($dx, $dy) = dir($a);
  if ($j++ % 2) { pod($x + $dx * 30, $y + $dy * 30, $a + rand(16) - 8, 54, 31, ($j % 4 ? 1 : -1) * 110, 0, 50 + $j, 10); }
  else { flower($x + $dx * 22, $y + $dy * 22, 15, rand(72)); }
}
flower(186, 184, 12, 10); flower(216, 212, 13, 40);
write_svg('5-third-growth.svg', 'Carolina Reaper third growth');

# 6. Harvest, top down: lush bush hung with ripe red reaper pods.
soil(200, 200, 34, 30, 6);
my @t6 = bush(9, 126, 61, -70);
srand(62);
$j = 0;
for my $t (@t6) {
  my ($x, $y, $a) = @$t; my ($dx, $dy) = dir($a); $j++;
  pod($x + $dx * 12, $y + $dy * 12, $a + rand(14) - 7, 76, 44, ($j % 2 ? 1 : -1) * 150, 1, 60 + $j, 16);
}
pod(204, 186, -40, 62, 38, 150, 1, 70, 10); pod(188, 214, 140, 58, 36, -150, 1, 74, 10);
write_svg('6-harvest.svg', 'Carolina Reaper ready to harvest');

# 7. Harvest, front view: three ripe reaper pods with green stems, lumpy and hooked.
pod(112, 118, 104, 196, 112, 185, 1, 71, 40);
pod(290, 112, 78, 188, 108, -185, 1, 72, 40);
pod(200, 150, 92, 210, 120, 195, 1, 73, 44);
write_svg('7-harvest-front.svg', 'Harvested Carolina Reapers');

# 8. Dead (never watered), top down: cracked dry soil, limp bare stalks lying flat with a few curled straw
#    leaves, and shrivelled dark pods dropped among them.
soil(200, 200, 70, 60, 8);
cracks(9, 83, 14, 'c3');
srand(84);
my @pods8;
for my $i (0 .. 6) {
  my $a = -80 + $i * 51 + rand(18) - 9; my $len = 96 + rand(30); my $bend = (rand(1) < .5 ? -1 : 1) * (30 + rand(40));
  my @lv;
  for my $t (0.35, 0.62, 0.86) {
    my ($px, $py, $pa) = walk(200, 200, $a, $len, $bend, $t); my $s = rand(1) < .5 ? -1 : 1;
    push @lv, [$px, $py, $pa + $s * (40 + rand(30)), 48 + rand(18), 19 + rand(5), $s * (40 + rand(50))];
  }
  blade(200, 200, $a, $len, 9, $bend, "c3", "c4");
  pleaf(@$_, 'c3', 'c4', 0.28, $_->[0]) for @lv;
  push @pods8, [walk(200, 200, $a, $len, $bend, 0.8)] if $i % 2;
}
for my $k (0 .. $#pods8) { my ($x, $y, $a) = @{$pods8[$k]}; pod($x, $y, $a + 50, 54, 34, ($k % 2 ? -1 : 1) * 110, 1, 81 + $k, 8, 1); }
write_svg('8-dead.svg', 'Carolina Reaper died from lack of water');
print "wrote 8 files to $OUT\n";

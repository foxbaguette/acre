# Basil crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/basil.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Signature: an upright bushy herb of LARGE, glossy, smooth, cupped bright-green leaves in opposite pairs:
# fewer and much bigger leaves than mint, puffy and shiny instead of quilted; white flower spikes at the tips.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/basil';
mkdir 'crops'; mkdir $OUT;
# c1 deep basil green (shade), c2 bright gloss green, c3 cream white (specular glints, flowers, dried leaves),
# c4 dark soil / seeds, c5 rich basil green (lit leaf body)
my %PAL = (c1 => '#236E2C', c2 => '#8FD448', c3 => '#F5F7E0', c4 => '#4F3322', c5 => '#46A537');
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

# Basil leaf: broad smooth ovate blade on a short petiole, puffy and glossy. The lit half carries a broad gloss
# lens and a white glint; the shaded half catches a sliver of light where it rises to the midrib.
# %o: wd => width factor and plain/withered colours (lit => , dark =>), bend => curl, glint => 0.
sub bleaf {
  my ($x, $y, $ang, $len, $w, %o) = @_;
  my ($cl, $cd) = ($o{lit} // 'c5', $o{dark} // 'c1');
  my $wd = $o{wd} // 1; my $bend = $o{bend} // 0;
  my $pl = $len * 0.14;
  blade($x, $y, $ang, $pl + 2, max(3, $w * 0.09), 0, $o{plain} ? ($cl, $cd) : ('c5', 'c1'), 0.8);
  my ($sx, $sy) = (dir($ang)); ($sx, $sy) = ($x + $sx * $pl, $y + $sy * $pl);
  # bent frame: points along the midrib
  my $n = 12; my @fr; my ($px, $py, $a) = ($sx, $sy, $ang);
  for my $i (0 .. $n) { push @fr, [$px, $py, $a]; my ($dx, $dy) = dir($a); $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n; }
  my $P = sub { my ($u, $v) = @_; my $f = $u * $n; my $i = min($n - 1, int($f)); my $r = $f - $i;
    my ($x0, $y0, $a0) = @{$fr[$i]}; my ($x1, $y1) = @{$fr[$i + 1]}; my ($dx, $dy) = dir($a0);
    my $hw = $w / 2 * $wd * sin(pi * (0.05 + 0.95 * $u) ** 0.92) ** 0.72 * (1 + ($o{wav} // 0.025) * sin($u * 26));
    [$x0 + ($x1 - $x0) * $r - $dy * $v * $hw, $y0 + ($y1 - $y0) * $r + $dx * $v * $hw] };
  my @L = map { $P->($_ / 16, 1) } 0 .. 16; my @R = map { $P->($_ / 16, -1) } 0 .. 16;
  my @mid = map { $P->($_ / 16, 0) } 0 .. 16;
  my ($mx, $my) = dir($ang + $bend / 2);
  my $pLit = lit(-$my, $mx);                                   # does the +v side face the light?
  my $s = $pLit ? 1 : -1;
  poly($pLit ? $cl : $cd, @L, reverse @mid);
  poly($pLit ? $cd : $cl, @R, reverse @mid);
  return if $o{plain};
  # light rising on the shaded half next to the midrib (the leaf is puffed up along its middle)
  poly('c5', (map { $P->($_ / 10 * 0.8 + 0.06, -$s * 0.05) } 0 .. 10), reverse map { $P->($_ / 10 * 0.8 + 0.06, -$s * (0.05 + 0.24 * sin(pi * $_ / 10))) } 0 .. 10);
  # broad gloss lens on the lit half
  poly('c2', (map { $P->(0.1 + 0.66 * $_ / 10, $s * (0.2 + 0.08 * sin(pi * $_ / 10))) } 0 .. 10),
             reverse map { $P->(0.1 + 0.66 * $_ / 10, $s * (0.2 + 0.55 * sin(pi * $_ / 10) ** 0.8)) } 0 .. 10);
  # white specular glint
  poly('c3', (map { $P->(0.2 + 0.26 * $_ / 6, $s * (0.36)) } 0 .. 6), reverse map { $P->(0.2 + 0.26 * $_ / 6, $s * (0.36 + 0.16 * sin(pi * $_ / 6))) } 0 .. 6)
    unless defined $o{glint} && !$o{glint};
  # a fine midrib groove and two side veins on the lit half
  poly('c1', (map { $P->($_ / 10 * 0.92, $s * 0.0) } 0 .. 10), reverse map { $P->($_ / 10 * 0.92, $s * 0.045 * (1 - $_ / 10)) } 0 .. 10);
}

# Basil flower spike from above, leaning a little: tiers of small white flowers between green bracts.
sub spike {
  my ($x, $y, $r, $rot) = @_;
  my ($dx, $dy) = dir($rot);
  for my $k (0 .. 4) {
    my $t = $k / 4; my $rr = $r * (1 - 0.5 * $t);
    my ($cx, $cy) = ($x + $dx * $r * 2.4 * $t, $y + $dy * $r * 2.4 * $t);
    for my $b (0 .. 3) { my ($u, $v) = dir($rot + 45 + $b * 90 + $k * 20); poly($b < 2 ? 'c5' : 'c1', [$cx, $cy], [$cx + $u * $rr * 1.1 - $v * $rr * 0.45, $cy + $v * $rr * 1.1 + $u * $rr * 0.45], [$cx + $u * $rr * 1.25, $cy + $v * $rr * 1.25], [$cx + $u * $rr * 1.1 + $v * $rr * 0.45, $cy + $v * $rr * 1.1 - $u * $rr * 0.45]); }
    my $nf = $k == 4 ? 2 : 4;
    for my $i (0 .. $nf - 1) {
      my ($u, $v) = dir($rot + $i * 360 / $nf + $k * 35);
      my ($fx, $fy) = ($cx + $u * $rr * 0.5, $cy + $v * $rr * 0.5); my $q = $rr * 0.42;
      poly('c3', [$fx - $q, $fy - $q * 0.2], [$fx - $q * 0.3, $fy - $q], [$fx + $q * 0.6, $fy - $q * 0.6], [$fx + $q, $fy + $q * 0.3], [$fx + $q * 0.1, $fy + $q * 0.9], [$fx - $q * 0.8, $fy + $q * 0.6]);
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

# Basil seed: a small glossy near-black oval with a pale glint.
sub seed {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o = map { my $th = 2 * pi * $_ / 14; [$x + $dx * cos($th) * $len / 2 + $nx * sin($th) * $w / 2, $y + $dy * cos($th) * $len / 2 + $ny * sin($th) * $w / 2] } 0 .. 13;
  poly('c3', map { [$_->[0] - $w * 0.08 - 0.6, $_->[1] - $w * 0.08 - 0.6] } @o);       # glossy rim light on the upper left
  poly('c4', @o);
  my ($gx, $gy) = ($x - 0.7071 * $w * 0.26, $y - 0.7071 * $w * 0.26);
  poly('c3', map { my $th = 2 * pi * $_ / 8; [$gx + $dx * cos($th) * $len * 0.2 + $nx * sin($th) * $w * 0.08, $gy + $dy * cos($th) * $len * 0.22 + $ny * sin($th) * $w * 0.13] } 0 .. 7);
}

sub write_svg {
  my ($file, $label) = @_;
  open my $fh, '>', "$OUT/$file" or die $!;
  print $fh qq{<?xml version="1.0" encoding="UTF-8"?>\n<svg viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="$label">\n  <style>\n};
  print $fh "    .$_ { fill: var(--$_, $PAL{$_}); }\n" for qw(c1 c2 c3 c4 c5);
  print $fh "  </style>\n  <g transform=\"translate(0 0)\">\n", join("\n", @S), "\n  </g>\n</svg>\n";
  close $fh; @S = ();
}

# A basil shoot from above: decussate pairs of big leaves, lower pairs larger, a small tip (or a flower spike).
sub shoot {
  my ($x, $y, $rot, $L, $pairs, $seed, %o) = @_;
  srand($seed);
  for my $p (0 .. $pairs - 1) {
    my $k = 1 - 0.2 * $p; my $a0 = $rot + $p * 90;
    for my $sd (0, 180) {
      my $a = $a0 + $sd + rand(14) - 7;
      bleaf($x, $y, $a, $L * $k * (0.94 + rand(0.12)), $L * $k * 0.7, bend => rand(16) - 8);
    }
  }
  if ($o{spike}) { spike($x, $y, $o{spike}, $rot + 30); return; }
  my $a = $rot + $pairs * 90;
  for my $sd (0, 180) { bleaf($x, $y, $a + $sd, $L * 0.34, $L * 0.25, glint => 0); }
}

# The bush: a big central shoot plus side shoots out of the leaf axils, outer (lower) ones drawn first.
sub bush {
  my ($seed, $L, $side, $sideR, $spk) = @_;
  srand($seed);
  my @sh;
  for my $i (0 .. $side - 1) {
    my $a = 45 + $i * 360 / $side + rand(16) - 8; my ($u, $v) = dir($a);
    push @sh, [200 + $u * $sideR, 200 + $v * $sideR, rand(90), $L * 0.72, 2, 300 + $i];
  }
  # the main stem's lower big pairs lie underneath everything
  srand($seed + 1);
  for my $p (0 .. 1) { for my $sd (0, 180) { my $a = $p * 90 + $sd + rand(10) - 5; bleaf(200, 200, $a, $L * (1.3 - 0.12 * $p), $L * (1.3 - 0.12 * $p) * 0.68, bend => rand(14) - 7); } }
  for (@sh) { shoot(@$_, $spk ? (spike => $spk * 0.8) : ()); }
  shoot(200, 200, 45, $L * 0.85, 2, $seed + 9, $spk ? (spike => $spk) : ());
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a scatter of small glossy black basil seeds.
{ srand(11);
  my @sd = ([150, 280, -20], [196, 296, 10], [246, 282, 35], [126, 236, 60], [174, 244, -40], [222, 240, 20], [270, 236, -60],
            [160, 196, 15], [208, 194, -25], [252, 190, 50], [190, 152, 80], [232, 150, -10]);
  seed($_->[0], $_->[1], $_->[2], 46 + rand(6), 30 + rand(4)) for sort { $a->[1] <=> $b->[1] } @sd;
}
write_svg('1-seeds-front.svg', 'Basil seeds');

# 2. Just sown, top down: seeds pressed into small soil pockets.
{ my @sown = ([166, 168], [240, 166], [202, 224], [150, 246], [256, 242]);
  for (@sown) { soil($_->[0], $_->[1], 28, 23, int($_->[0] * 7 + $_->[1])); }
  srand(22);
  for (@sown) { my ($x, $y) = @$_; seed($x, $y, rand(180), 22, 14); }
}
write_svg('2-sown.svg', 'Basil just sown');

# 3. First growth, top down: two round seed leaves and the first glossy true pair.
soil(200, 200, 32, 28, 3);
bleaf(200, 200, 160, 52, 44, glint => 0); bleaf(200, 200, -20, 52, 44, glint => 0);
bleaf(200, 200, -110, 90, 64, bend => 6); bleaf(200, 200, 70, 90, 64, bend => -6);
bleaf(200, 200, -20, 32, 22, glint => 0); bleaf(200, 200, 160, 32, 22, glint => 0);
write_svg('3-first-growth.svg', 'Basil first growth');

# 4. Second growth, top down: a young upright plant, three crossing pairs of big glossy leaves.
soil(200, 200, 32, 28, 4);
shoot(200, 200, 20, 116, 3, 41);
write_svg('4-second-growth.svg', 'Basil second growth');

# 5. Third growth, top down: a bushy plant with side shoots; white flower spikes rising at the tips.
soil(200, 200, 32, 28, 5);
bush(51, 100, 4, 74, 21);
write_svg('5-third-growth.svg', 'Basil third growth with flowers');

# 6. Harvest, top down: a lush bush of big glossy leaves, pinched before flowering.
soil(200, 200, 32, 28, 6);
bush(61, 112, 6, 100, 0);
write_svg('6-harvest.svg', 'Basil ready to harvest');

# 7. Harvest item, front view: a bunch of three basil stems with big glossy leaves.
{ my ($bx, $by) = (200, 300);
  my @st = ([-108, 190, 8, 71], [-72, 186, -8, 72], [-91, 214, 2, 73]);
  for my $i (0 .. 2) { my $ex = $bx + ($i - 1) * 12; blade($bx + ($i - 1) * 4, $by, rad2deg(atan2(370 - $by, $ex - $bx - ($i - 1) * 4)), 72, 9, 0, 'c5', 'c1', 0.9); poly('c3', ell($ex, 370, 4.5, 2.8, 8)); }
  for my $st (@st) {
    my ($a, $len, $bend, $seed) = @$st; srand($seed);
    my ($x0, $y0) = ($bx + ($a + 90) * 0.12, $by);
    blade($x0, $y0, $a, $len, 9, $bend, 'c5', 'c1', 0.5);
    my $j = 0;
    for my $t (0.34, 0.62, 0.86) {
      my ($px, $py, $pa) = walk($x0, $y0, $a, $len, $bend, $t);
      my $k = 1.25 - $t * 0.7; my $sp = $j++ % 2 ? 62 : 48;
      for my $s (-1, 1) { bleaf($px, $py, $pa + $s * $sp + rand(10) - 5, 82 * $k, 60 * $k, bend => $s * 18); }
    }
    my ($tx, $ty, $ta) = walk($x0, $y0, $a, $len, $bend, 1);
    for my $s (-1, 1) { bleaf($tx, $ty, $ta + $s * 22, 34, 26, bend => $s * 10, glint => 0); }
  }
  poly('c4', [$bx - 19, $by - 5], [$bx + 19, $by - 8], [$bx + 20, $by + 7], [$bx - 20, $by + 10]);
  poly('c3', [$bx - 19, $by - 5], [$bx + 19, $by - 8], [$bx + 19, $by - 2], [$bx - 19, $by + 1]);
  poly('c3', [$bx + 14, $by + 4], [$bx + 30, $by + 26], [$bx + 24, $by + 28], [$bx + 10, $by + 8]);
}
write_svg('7-harvest-front.svg', 'Harvested basil bunch');

# 8. Dead (never watered), top down: cracked dry soil, limp stems flat on the ground, big leaves shrivelled
#    and curled into dry straw and brown.
soil(200, 200, 64, 56, 8);
cracks(9, 83, 14);
{ srand(84);
  for my $i (0 .. 5) {
    my $a = -70 + $i * 60 + rand(20) - 10; my $len = 84 + rand(30); my $bend = (rand(1) < .5 ? -1 : 1) * (30 + rand(40));
    blade(200, 200, $a, $len, 8, $bend, 'c3', 'c4', 0.5);
    for my $t (0.45, 0.9) {
      my ($px, $py, $pa) = walk(200, 200, $a, $len, $bend, $t);
      for my $s (-1, 1) { next if rand(1) < 0.25;
        bleaf($px, $py, $pa + $s * (40 + rand(40)), 62 + rand(16), 46, wd => 0.55 + rand(0.15), bend => $s * (40 + rand(40)), wav => 0.12, lit => 'c3', dark => 'c4', plain => 1); }
    }
  }
}
write_svg('8-dead.svg', 'Basil died from lack of water');
print "wrote 8 files to $OUT\n";

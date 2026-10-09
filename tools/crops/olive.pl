# Olive Bush crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/olive.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Olive signature: a twisted grey-brown woody trunk, narrow willow-like leaves that are dark green on top and
# silvery underneath, tiny creamy flower clusters, then glossy oval olives from green to purple-black.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/olive';
mkdir 'crops'; mkdir $OUT;
# c1 dark olive-leaf green, c2 silvery grey-green (leaf undersides, lit bark, green olives), c3 cream (flowers, gloss,
# lit pit, dried leaves), c4 dark brown (soil, bark shade, pit shade), c5 ripe olive purple-black
my %PAL = (c1 => '#4C6B3C', c2 => '#B2C38C', c3 => '#EEE8CA', c4 => '#55392A', c5 => '#4A2A44');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A tapered blade/stalk (as in wheat.pl). $taper < 1 leaves a blunt end. Returns end point and heading.
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

# A twisted woody branch: a wandering path that thins toward the tip, dark bark with a lit grey edge.
# Returns the list of [x, y, heading] points along it so leaves and fruit can hang on it.
sub branch {
  my ($x, $y, $ang, $len, $w0, $w1, $twist, $seed, $lightc, $darkc) = @_;
  $lightc //= 'c2'; $darkc //= 'c4';
  srand($seed);
  my $n = 12; my (@l, @r, @p);
  my ($px, $py) = ($x, $y); my $ph = rand(6.28);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my $a = $ang + $twist * sin($t * 5.5 + $ph);
    my ($dx, $dy) = dir($a);
    my $hw = ($w0 + ($w1 - $w0) * $t) / 2 * (1 + 0.18 * sin($t * 13 + $ph));
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @p, [$px, $py, $a];
    $px += $dx * $len / $n; $py += $dy * $len / $n;
  }
  poly($darkc, @l, reverse @r);
  # lit edge strip on the side facing the light
  my ($dx, $dy) = dir($ang); my $ls = lit(-$dy, $dx) ? \@l : \@r;
  my @in = map { [($p[$_][0] * 0.45 + $ls->[$_][0] * 0.55), ($p[$_][1] * 0.45 + $ls->[$_][1] * 0.55)] } 0 .. $n;
  poly($lightc, @$ls[0 .. $n - 1], reverse @in[0 .. $n - 1]);
  return @p;
}

# A narrow olive leaf: lanceolate, pointed at both ends. $flip shows the silvery underside.
sub leaf {
  my ($x, $y, $ang, $len, $w, $bend, $flip) = @_;
  my ($light, $dark) = !$flip ? ('c2', 'c1') : $flip eq 'dead' ? ('c3', 'c4') : ('c3', 'c2');
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $t < 0.06 ? 0.8 : $w / 2 * sin(pi * (($t - 0.06) / 0.94) ** 0.9) ** 0.75;
    $hw = 0 if $i == $n;
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# An olive: a glossy oval on a short stalk, heading `ang` from where it hangs. $ripe: 1 purple-black, 0 green.
# $shr shrivels it (dead stage).
sub olive {
  my ($x, $y, $ang, $len, $w, $ripe, $stalk, $shr) = @_;
  $stalk //= 0; $shr //= 0;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  if ($stalk) { blade($x, $y, $ang, $stalk, 2.6, 0, 'c2', 'c1', 0.3); $x += $dx * $stalk; $y += $dy * $stalk; }
  my ($cx, $cy) = ($x + $dx * $len / 2, $y + $dy * $len / 2);
  my @o;
  for my $i (0 .. 17) {
    my $th = 2 * pi * $i / 18; my $c = cos($th);
    my $u = $c * $len / 2; my $v = sin($th) * $w / 2 * (1 + 0.06 * $c) * ($shr ? 1 + 0.12 * sin($th * 5) : 1);
    push @o, [$cx + $dx * $u + $nx * $v, $cy + $dy * $u + $ny * $v];
  }
  my ($body, $shade) = $ripe ? ('c5', 'c4') : ('c2', 'c1');
  ($body, $shade) = ('c5', 'c4') if $shr;
  poly($shade, @o);
  # lit body: the oval shrunk and nudged toward the upper-left light, leaving a shaded crescent lower right
  my $m = min($len, $w);
  poly($body, map { [$cx + ($_->[0] - $cx) * 0.84 - $m * 0.07, $cy + ($_->[1] - $cy) * 0.84 - $m * 0.07] } @o);
  return if $shr;
  # gloss: a small cream highlight toward the upper left
  my ($gx, $gy) = ($cx - $len * 0.12 - $w * 0.08, $cy - $len * 0.12 - $w * 0.08);
  my @g; for my $i (0 .. 7) { my $th = 2 * pi * $i / 8; push @g, [$gx + cos($th) * $w * 0.13 + sin($th) * $w * 0.05, $gy + sin($th) * $w * 0.1 - cos($th) * $w * 0.04]; }
  poly('c3', @g);
}

# A small cluster of creamy olive flowers: a short stalk with tiny four-petal blossoms.
sub flowers {
  my ($x, $y, $ang, $r, $seed) = @_;
  srand($seed);
  my ($dx, $dy) = dir($ang);
  blade($x, $y, $ang, $r * 1.6, 2.4, 0, 'c2', 'c1', 0.4);
  my @f = map { my $t = 0.35 + 0.65 * $_ / 5; my $s = $_ % 2 ? 1 : -1; my ($ox, $oy) = dir($ang + $s * 50);
                [$x + $dx * $r * 1.6 * $t + $ox * $r * 0.5, $y + $dy * $r * 1.6 * $t + $oy * $r * 0.5] } 0 .. 5;
  push @f, [$x + $dx * $r * 1.9, $y + $dy * $r * 1.9];
  for (@f) {
    my ($fx, $fy) = @$_; my $rot = rand(90); my $fr = $r * (0.42 + rand(0.1));
    for my $p (0 .. 3) {
      my ($px, $py) = dir($rot + $p * 90); my ($qx, $qy) = (-$py, $px);
      poly(lit($px, $py) || $p == 0 ? 'c3' : 'c2', [$fx + $qx * $fr * 0.25, $fy + $qy * $fr * 0.25], [$fx + $px * $fr * 0.8 + $qx * $fr * 0.4, $fy + $py * $fr * 0.8 + $qy * $fr * 0.4],
                [$fx + $px * $fr, $fy + $py * $fr], [$fx + $px * $fr * 0.8 - $qx * $fr * 0.4, $fy + $py * $fr * 0.8 - $qy * $fr * 0.4], [$fx - $qx * $fr * 0.25, $fy - $qy * $fr * 0.25]);
    }
    poly('c3', map { my ($px, $py) = dir($rot + 45 + $_ * 90); [$fx + $px * $fr * 0.3, $fy + $py * $fr * 0.3] } 0 .. 3);
  }
}

# An olive pit (stone): a pointed oval with lengthwise grooves, cream lit half and brown shade.
sub pit {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $hv = sub { my $c = shift; sqrt(max(0, 1 - $c * $c)) * (1 - ($c > 0 ? 0.38 : 0.26) * $c * $c) };
  my @o;
  for my $i (0 .. 19) {
    my $th = 2 * pi * $i / 20; my $c = cos($th);
    my $v = ($i <= 10 ? 1 : -1) * $w / 2 * $hv->($c);
    push @o, [$x + $dx * $c * $len / 2 + $nx * $v, $y + $dy * $c * $len / 2 + $ny * $v];
  }
  poly('c4', @o);
  my $k = lit($nx, $ny) ? 1 : -1;
  my @h = $k > 0 ? @o[0 .. 10] : (@o[10 .. 19], $o[0]);
  poly('c3', @h, [$x - $nx * $k * $w * 0.12, $y - $ny * $k * $w * 0.12]);
  # grooves: dark lengthwise furrows on the lit face
  for my $g ([0.4, "c4"]) { my ($f, $gc) = @$g;
    my (@a, @b);
    for my $j (0 .. 6) {
      my $c = -0.8 + 1.6 * $j / 6; my $v = $k * $f * $w / 2 * $hv->($c);
      my ($px, $py) = ($x + $dx * $c * $len / 2 + $nx * $v, $y + $dy * $c * $len / 2 + $ny * $v);
      my $h = 1.1 * sin(pi * $j / 6) + 0.2;
      push @a, [$px + $nx * $h, $py + $ny * $h]; push @b, [$px - $nx * $h, $py - $ny * $h];
    }
    poly($gc, @a, reverse @b);
  }
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

# A gnarled trunk top seen from above: a knotted lump of bark at the centre.
sub knot {
  my ($r, $seed, $lc) = @_; $lc //= "c2";
  srand($seed); my @o;
  for my $i (0 .. 9) { my $th = 2 * pi * $i / 10; my $k = 0.8 + rand(0.35); push @o, [200 + cos($th) * $r * $k, 200 + sin($th) * $r * $k]; }
  poly('c4', @o);
  poly($lc, @o[5 .. 8], [200 - $r * 0.1, 200 - $r * 0.1]);
}

# Top-down olive crown: $nb twisted branches, each lined with narrow leaves in pairs.
# Returns hang points [x, y, heading] along the outer half of each branch for flowers or fruit.
sub crown {
  my ($nb, $reach, $seed, $start, $lw, $flipFrac) = @_;
  $lw //= 1; $flipFrac //= 0.3;
  srand($seed);
  my (@br, @leaves, @hang);
  for my $i (0 .. $nb - 1) {
    my $a = $start + $i * 360 / $nb + rand(16) - 8;
    my $r = $reach * (0.86 + rand(0.16));
    push @br, [$a, $r, int(rand(1000))];
  }
  my @paths;
  for (@br) { my ($a, $r, $s) = @$_; push @paths, [branch(200, 200, $a, $r * 0.78, 9 * $lw + 2, 2.5, 16, $s)]; }
  srand($seed + 7);
  for my $bp (@paths) {
    my @p = @$bp; my $n = $#p;
    for my $j (2 .. $n) {
      my ($x, $y, $a) = @{$p[$j]};
      my $t = $j / $n;
      my $len = (26 + 18 * $t) * $lw + rand(6);
      for my $s (-1, 1) {
        next if rand(1) < 0.25 && $j < $n;
        push @leaves, [$x, $y, $a + $s * (34 + rand(22)) - $s * 10 * $t, $len, $len * 0.2, $s * (rand(14)), rand(1) < $flipFrac ? 1 : 0, $t];
      }
      push @hang, [$x, $y, $a] if $t > 0.45 && $j % 2 == 0;
    }
    my ($x, $y, $a) = @{$p[$n]};
    push @leaves, [$x, $y, $a + rand(10) - 5, 40 * $lw, 8 * $lw, rand(10) - 5, 0, 1.1];
  }
  # inner leaves first, outer leaves on top so the crown edge reads cleanly
  leaf(@$_[0 .. 6]) for sort { $a->[7] <=> $b->[7] } @leaves;
  return @hang;
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a little heap of olive pits (stones) with one ripe olive behind them.
{ my ($sx, $sy) = (262, 132); my @st = branch($sx, $sy, 96, 26, 4, 3, 6, 9, q(c2), q(c4)); leaf($sx, $sy, -160, 62, 13, -8, 0); leaf($sx, $sy, -26, 58, 12, 10, 1);
  olive($st[-1][0], $st[-1][1], 92, 72, 50, 1, 0); }
pit(140, 276, -10, 122, 52); pit(266, 280, 192, 122, 52); pit(204, 308, 3, 126, 54);
pit(194, 236, -52, 116, 50);
write_svg('1-seeds-front.svg', 'Olive pits');

# 2. Just sown, top down: olive pits pressed into small soil pockets.
my @sown = ([168, 170, -30], [238, 172, 40], [202, 230, 100]);
for (@sown) { soil($_->[0], $_->[1], 34, 28, int($_->[0] * 7 + $_->[1])); }
for (@sown) { pit($_->[0], $_->[1], $_->[2], 54, 27); }
write_svg('2-sown.svg', 'Olive just sown');

# 3. First growth, top down: a seedling with pairs of narrow leaves set crosswise.
soil(200, 200, 34, 30, 3);
leaf(200, 200, -150, 69, 14, -8, 0); leaf(200, 200, 30, 69, 14, -8, 0);
leaf(200, 200, -60, 79, 16, 10, 0);  leaf(200, 200, 120, 76, 16, 10, 1);
leaf(200, 200, -105, 52, 12, 6, 0);  leaf(200, 200, 75, 50, 12, 6, 0);
write_svg('3-first-growth.svg', 'Olive first growth');

# 4. Second growth, top down: a young olive with a few twisted branches and narrow silvery leaves.
soil(200, 200, 34, 30, 4);
crown(5, 120, 41, -80, 0.9, 0.3);
knot(10, 4);
write_svg('4-second-growth.svg', 'Olive second growth');

# 5. Third growth, top down: a fuller rounded crown sprinkled with creamy flower clusters.
soil(200, 200, 34, 30, 5);
my @h5 = crown(7, 150, 51, -86, 1, 0.3);
knot(13, 5);
srand(52);
my $j = 0;
for (@h5) { next if $j++ % 2; my ($x, $y, $a) = @$_; flowers($x, $y, $a + (rand(1) < .5 ? -40 : 40), 14, 50 + $j); }
write_svg('5-third-growth.svg', 'Olive third growth');

# 6. Harvest, top down: a full silvery crown hung with glossy olives, green and purple-black.
soil(200, 200, 34, 30, 6);
my @h6 = crown(8, 176, 61, -70, 1.05, 0.3);
knot(14, 6);
srand(62);
$j = 0;
for (@h6) { my ($x, $y, $a) = @$_; $j++; my $s = rand(1) < .5 ? -1 : 1;
  olive($x, $y, $a + $s * (30 + rand(30)), 24, 17, ($j % 3 ? 1 : 0), 7);
  olive($x, $y, $a - $s * (40 + rand(30)), 22, 16, ($j % 4 == 1 ? 0 : 1), 5) if $j % 2; }
write_svg('6-harvest.svg', 'Olive Bush ready to harvest');

# 7. Harvested produce, front view: a small heap of olives, green and dark purple, topped by a little sprig.
my @ol = ([120, 300, 4, 1], [182, 312, -6, 0], [246, 310, 8, 1], [302, 296, -4, 0],
          [150, 254, -14, 0], [214, 260, 10, 1], [272, 250, -10, 1], [184, 214, 6, 1], [242, 210, -8, 0]);
for (@ol) { my ($x, $y, $a, $r) = @$_; olive($x - 44, $y - $a * 0.7, $a * 1.6, 88, 56, $r, 0); }
# sprig: a short twig with four narrow leaves, lying across the top of the heap
my @tw = branch(118, 222, -14, 150, 7, 3, 8, 77, 'c2', 'c4');
leaf(@{$tw[3]}[0, 1], $tw[3][2] - 52, 70, 15, -10, 0);
leaf(@{$tw[6]}[0, 1], $tw[6][2] + 48, 66, 14, 10, 1);
leaf(@{$tw[9]}[0, 1], $tw[9][2] - 44, 64, 14, -8, 0);
leaf(@{$tw[12]}[0, 1], $tw[12][2] + 6, 72, 15, 6, 0);
write_svg('7-harvest-front.svg', 'Harvested olives');

# 8. Dead (never watered), top down: cracked dry soil, bare twisted branches, a few curled dead leaves
#    still clinging, fallen dry leaves and shrivelled olives.
soil(200, 200, 74, 64, 8);
cracks(9, 83, 15, 'c3');
srand(85);
for my $i (0 .. 7) {                       # fallen dry leaves lying on the ground around the bush
  my $a = $i * 45 + rand(20); my $d = 90 + rand(34); my ($dx, $dy) = dir($a);
  leaf(200 + $dx * $d, 200 + $dy * $d, rand(360), 34 + rand(8), 12, (rand(1) < .5 ? -1 : 1) * (20 + rand(30)), 'dead');
}
srand(84);
my @dl;
for my $i (0 .. 5) {
  my $a = -80 + $i * 60 + rand(18) - 9; my $r = 112 + rand(26);
  my @p = branch(200, 200, $a, $r, 14, 3, 20, 300 + $i, 'c3', 'c4');
  for my $k (6, 9, 12) { my ($x, $y, $ha) = @{$p[$k]}; push @dl, [$x, $y, $ha + (rand(1) < .5 ? -1 : 1) * (40 + rand(40)), 36 + rand(10)]; }
}
for (@dl) { my ($x, $y, $a, $l) = @$_; leaf($x, $y, $a, $l, 13, (rand(1) < .5 ? -1 : 1) * (25 + rand(30)), "dead"); }
knot(15, 8, "c3");
olive(112, 236, 30, 22, 15, 1, 0, 1); olive(286, 158, 200, 21, 14, 1, 0, 1); olive(262, 300, 120, 20, 14, 1, 0, 1);
write_svg('8-dead.svg', 'Olive Bush died from lack of water');
print "wrote 8 files to $OUT\n";

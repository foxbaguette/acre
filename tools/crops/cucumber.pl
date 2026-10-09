# Cucumber crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/cucumber.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/cucumber';
mkdir 'crops'; mkdir $OUT;
# c1 deep leaf green (also the lit side of the fruit), c2 lit leaf green, c3 warm yellow (flowers, spines,
# stripes, seeds, dry leaves), c4 dark soil brown, c5 dark bottle-green cucumber skin
my %PAL = (c1 => '#3D7B35', c2 => '#7DB64C', c3 => '#F1D768', c4 => '#5A3A22', c5 => '#24502C');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 }
sub light { my ($nx, $ny) = @_; my $l = sqrt($nx * $nx + $ny * $ny) || 1; ($nx * -0.7071 + $ny * -0.7071) / $l }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Tapered blade or stalk (as in wheat). $taper < 1 keeps width at the tip. Returns points [x, y, angle].
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $lightc, $dark, $taper) = @_;
  $taper //= 1;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $t) ** 0.85 + ($i == $n && $taper == 1 ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py, $a];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang); my $leftLit = lit(-$dy, $dx);
  my @m = map { [$_->[0], $_->[1]] } @mid;
  poly($leftLit ? $lightc : $dark, @l, reverse @m);
  poly($leftLit ? $dark : $lightc, @r, reverse @m);
  return @mid;
}

# Curly tendril: a thin strip whose curvature tightens toward the tip (as in pumpkin).
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

# Cucumber leaf seen from above: broad heart-shaped base, five shallow, sharply pointed lobes (the middle
# one longest) and a finely toothed rim. Facets fan from the base and split on each lobe's vein.
sub cleaf {
  my ($x, $y, $ang, $r, $lightc, $dark, $wilt, $seed) = @_;
  $wilt //= 0; srand($seed // int($x * 13 + $y * 7));
  my @lobes = ([-104, 0.66], [-54, 0.86], [0, 1.0], [54, 0.86], [104, 0.66]);
  my @o; push @o, [-158, 0.42];
  for my $k (0 .. $#lobes) {
    my ($la, $lr) = @{$lobes[$k]};
    my $prevS = $k == 0 ? -158 : ($lobes[$k - 1][0] + $la) / 2;
    my $nextS = $k == $#lobes ? 158 : ($lobes[$k + 1][0] + $la) / 2;
    my $sr = $k == $#lobes ? 0.42 : 0.8 * min($lr, $lobes[$k + 1][1]);
    push @o, [$la + ($prevS - $la) * 0.62, $lr * 0.86], [$la + ($prevS - $la) * 0.3, $lr * 0.9];   # toothed flanks
    push @o, [$la, $lr * 1.04];
    push @o, [$la + ($nextS - $la) * 0.3, $lr * 0.9], [$la + ($nextS - $la) * 0.62, $lr * 0.86];
    push @o, [$nextS, $sr];
  }
  my @p;
  for my $q (@o) {
    my ($oa, $or) = @$q;
    my $rr = $r * $or * (1 - $wilt * (0.25 + rand(0.45))) * (1 + (rand(0.06) - 0.03));
    my $aa = $ang + $oa * (1 - $wilt * 0.35) + $wilt * (rand(30) - 15);
    my ($dx, $dy) = dir($aa);
    push @p, [$x + $dx * $rr, $y + $dy * $rr];
  }
  my ($bx, $by) = ($x + cos(deg2rad($ang)) * $r * 0.1, $y + sin(deg2rad($ang)) * $r * 0.1);   # vein hub
  # the blade folds slightly along its midrib: one half lit, one half shaded
  my ($lx, $ly) = dir($ang - 90 + $wilt * 40); my $leftLit = lit($lx, $ly);
  poly($leftLit ? $lightc : $dark, [$bx, $by], @p[0 .. 15]);
  poly($leftLit ? $dark : $lightc, [$bx, $by], @p[15 .. 30]);
  # palmate veins from the hub to each lobe tip: darker on the lit half, lighter on the shaded half
  for my $k (0 .. $#lobes) {
    my $tp = $p[3 + 6 * $k];
    my $onLeft = $k < 2 ? 1 : $k > 2 ? 0 : -1;
    my $cls = $onLeft == -1 ? ($leftLit ? $dark : $lightc) : (($onLeft xor !$leftLit) ? $dark : $lightc);
    my @v = map { my $t = $_ / 6 * 0.86; [$bx + ($tp->[0] - $bx) * $t, $by + ($tp->[1] - $by) * $t] } 0 .. 6;
    strip($cls, $r * 0.06, $r * 0.012, @v);
  }
}

# Small five-petalled yellow flower seen from above (rounded, crinkled petals, green heart).
sub flower {
  my ($x, $y, $r, $rot) = @_;
  for my $k (0 .. 4) {
    my $a = $rot + $k * 72; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    my @pp = map { my $t = $_ / 8; my $w = $r * 0.5 * sin(pi * min(1, $t * 1.05)) ** 0.6;
                   my ($u) = $r * $t; [$x + $dx * $u, $y + $dy * $u] } 0 .. 8;
    my (@l, @rr);
    for my $i (0 .. 8) { my $t = $i / 8; my $w = $r * 0.5 * sin(pi * (0.1 + 0.85 * $t)) ** 0.5; push @l, [$pp[$i][0] + $nx * $w, $pp[$i][1] + $ny * $w]; push @rr, [$pp[$i][0] - $nx * $w, $pp[$i][1] - $ny * $w]; }
    poly('c3', @l, reverse @rr);
    # crease: a darker fold on the petal half facing away from the light
    my $sd = lit($nx, $ny) ? -1 : 1;
    poly('c1', [$x + $dx * $r * 0.25, $y + $dy * $r * 0.25], (map { [$pp[$_][0] + $sd * $nx * $r * 0.1, $pp[$_][1] + $sd * $ny * $r * 0.1] } 3, 6), [$pp[7][0], $pp[7][1]]) if 0;
  }
  poly('c2', map { my ($dx, $dy) = dir($rot + 36 + $_ * 72); [$x + $dx * $r * 0.24, $y + $dy * $r * 0.24] } 0 .. 4);
  poly('c1', map { my ($dx, $dy) = dir($rot + $_ * 72); [$x + $dx * $r * 0.11, $y + $dy * $r * 0.11] } 0 .. 4);
}

# A cucumber lying along `ang` (stem end at (x,y)): a long, slightly curved, blunt cylinder with a lit
# side, rows of pale spiny bumps, pale stripes toward the blossom end and a short stalk.
sub cuke {
  my ($x, $y, $ang, $len, $w, $bend, $ripe, $remnant) = @_;
  $ripe //= 1;
  my $n = 16; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (0.5 + 0.5 * sin(pi * min(0.5, $t * 2.2)) ** 0.6) * sqrt(max(0, 1 - max(0, ($t - 0.84) / 0.16) ** 2)) * (1 - 0.06 * sin(pi * $t));
    $hw = $w / 2 * 0.42 if $t == 0;
    push @mid, [$px, $py, $a, $hw];
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2); my $leftLit = lit(-$dy, $dx);
  my $sgn = $leftLit ? -1 : 1;            # side (relative to the axis normal) that faces the light
  my $dead = $ripe < 0; $ripe = 0 if $dead;
  poly($dead ? 'c4' : 'c5', @l, reverse @r);
  # lit band along the light-facing side, and a narrow highlight
  my (@b1, @b2, @h1, @h2);
  for my $m (@mid[1 .. $n - 1]) {
    my ($mx, $my, $ma, $hw) = @$m; my ($ex, $ey) = dir($ma); my ($nx, $ny) = (-$ey, $ex);
    push @b1, [$mx + $sgn * $nx * $hw * 0.98, $my + $sgn * $ny * $hw * 0.98]; push @b2, [$mx + $sgn * $nx * $hw * 0.05, $my + $sgn * $ny * $hw * 0.05];
    push @h1, [$mx + $sgn * $nx * $hw * 0.72, $my + $sgn * $ny * $hw * 0.72]; push @h2, [$mx + $sgn * $nx * $hw * 0.48, $my + $sgn * $ny * $hw * 0.48];
  }
  poly($dead ? 'c3' : $ripe ? 'c1' : 'c2', @b1, reverse @b2);
  poly($dead ? 'c4' : $ripe ? 'c2' : 'c3', @h1[2 .. $#h1 - 3], reverse @h2[2 .. $#h2 - 3]);
  # pale stripes fading in from the blossom end
  for my $s (-0.55, 0, 0.55) {
    my @st;
    for my $i (int($n * 0.55) .. $n - 1) { my ($mx, $my, $ma, $hw) = @{$mid[$i]}; my ($ex, $ey) = dir($ma); my ($nx, $ny) = (-$ey, $ex); push @st, [$mx + $nx * $hw * $s, $my + $ny * $hw * $s]; }
    strip('c2', 0.4, $w * 0.13, @st) if $ripe;
  }
  # spiny bumps: little pale warts with a dark tip, in staggered rows
  for my $i ($dead ? () : (2 .. $n - 3)) {
    for my $s ($i % 2 ? (-0.55, 0.15, 0.75) : (-0.2, 0.48)) {
      my ($mx, $my, $ma, $hw) = @{$mid[$i]}; my ($ex, $ey) = dir($ma); my ($nx, $ny) = (-$ey, $ex);
      my ($bx, $by) = ($mx + $nx * $hw * $s, $my + $ny * $hw * $s); my $br = $w * 0.05;
      poly($ripe ? "c1" : "c3", [$bx - $br * 1.3, $by], [$bx, $by - $br * 1.3], [$bx + $br * 1.3, $by], [$bx, $by + $br * 1.3]);   # wart
      poly("c3", [$bx - $br * 1.1, $by - $br * 1.1], [$bx + $br * 0.2, $by - $br * 0.6], [$bx - $br * 0.6, $by + $br * 0.2]) if $ripe;   # its pale spine
    }
  }
  # stalk at the stem end; dried flower scar at the blossom end
  my ($sx, $sy, $sa) = @{$mid[0]};
  blade($sx + cos(deg2rad($sa)) * 2, $sy + sin(deg2rad($sa)) * 2, $sa + 180, $w * 0.5, $w * 0.24, 0, $dead ? 'c3' : 'c2', $dead ? 'c4' : 'c1', 0.4);
  my ($ex, $ey, $ea, $eh) = @{$mid[$n]};
  if ($remnant) { flower($ex + cos(deg2rad($ea)) * $w * 0.12, $ey + sin(deg2rad($ea)) * $w * 0.12, $w * ($remnant > 1 ? 0.55 : 0.36), $ea + 18); }
  else { poly('c3', map { my $th = 2 * pi * $_ / 6; [$ex - cos(deg2rad($ea)) * 2 + cos($th) * $w * 0.07, $ey - sin(deg2rad($ea)) * 2 + sin($th) * $w * 0.07] } 0 .. 5); }
}

# Thin strip along a list of points, width tapering from w0 to w1.
sub strip {
  my ($cls, $w0, $w1, @p) = @_;
  return if @p < 2;
  my (@l, @r);
  for my $i (0 .. $#p) {
    my $j = $i < $#p ? $i + 1 : $i; my $k = $i < $#p ? $i : $i - 1;
    my ($dx, $dy) = ($p[$j][0] - $p[$k][0], $p[$j][1] - $p[$k][1]); my $l = sqrt($dx * $dx + $dy * $dy) || 1;
    my $w = ($w0 + ($w1 - $w0) * $i / $#p) / 2;
    push @l, [$p[$i][0] - $dy / $l * $w, $p[$i][1] + $dx / $l * $w]; push @r, [$p[$i][0] + $dy / $l * $w, $p[$i][1] - $dx / $l * $w];
  }
  poly($cls, @l, reverse @r);
}

# Flat slender cucumber seed: pointed oval with a shaded edge.
sub seed {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx); my @o;
  for my $i (0 .. 15) {
    my $th = 2 * pi * $i / 16;
    my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 + 0.12 * cos($th)) * (cos($th) < -0.9 ? 0.5 : 1);
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly('c3', @o);
  my @half = lit($nx, $ny) ? @o[0 .. 8] : @o[8 .. 15, 0];
  my @inner = map { [$x + ($_->[0] - $x) * 0.6, $y + ($_->[1] - $y) * 0.6] } reverse @half;
  poly('c4', @half, @inner[1 .. $#inner - 1]);
}

sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o; srand($seed);
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

# A leaf on its stalk from (x,y).
sub leaf_on {
  my ($x, $y, $ang, $plen, $r, $lc, $dc, $wilt, $seed) = @_;
  my @m = blade($x, $y, $ang, $plen, 5, 0, $lc // 'c2', $dc // 'c1', 0.4);
  my ($ex, $ey) = @{$m[-1]};
  cleaf($ex, $ey, $ang, $r, $lc // 'c2', $dc // 'c1', $wilt, $seed);
}

# A runner from the crown; returns its points.
sub vine {
  my ($ang, $len, $bend, $w, $lc, $dc) = @_;
  my ($dx, $dy) = dir($ang);
  return blade(200 + $dx * 4, 200 + $dy * 4, $ang, $len, $w, $bend, $lc // 'c2', $dc // 'c1', 0.55);
}
sub at { my ($pts, $t) = @_; my $i = int($t * $#$pts + 0.5); @{$pts->[$i]} }

# Smooth oval seed leaf (cotyledon), split along its midrib.
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

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a little heap of flat, slender cream cucumber seeds.
for my $s ([120, 300, 8], [176, 312, -170], [234, 308, 176], [288, 298, 168], [148, 270, -20], [206, 276, 196], [262, 268, 14],
           [176, 240, 200], [232, 240, -8], [204, 210, -100]) {
  seed($s->[0], $s->[1], $s->[2], 64, 22);
}
write_svg('1-seeds-front.svg', 'Cucumber seeds');

# 2. Just sown, top down: seeds pushed into small soil pockets.
my @sown = ([166, 168, -30], [238, 166, 40], [202, 214, 100], [154, 244, 150], [250, 242, -60]);
soil($_->[0], $_->[1], 28, 22, int($_->[0] * 7 + $_->[1])) for @sown;
seed($_->[0], $_->[1], $_->[2], 38, 16) for @sown;
write_svg('2-sown.svg', 'Cucumber just sown');

# 3. First growth, top down: two oval seed leaves and the first small pointed true leaf.
soil(200, 200, 34, 30, 3);
seedleaf(200, 200, 165, 74, 36);
seedleaf(200, 200, -15, 74, 36);
leaf_on(200, 200, -96, 20, 48, "c2", "c1", 0, 31);
write_svg('3-first-growth.svg', 'Cucumber first growth');

# 4. Second growth, top down: a young plant, pointed heart-shaped leaves and the first runner with a tendril.
soil(200, 200, 34, 30, 4);
{
  my @v1 = vine(-150, 104, -40, 7); my @v2 = vine(40, 96, 36, 7);
  for my $v (\@v1, \@v2) {
    my ($x, $y, $a) = at($v, 0.55); tendril($x, $y, $a + 80, 36, 26, 2.8);
    ($x, $y, $a) = at($v, 1.0); tendril($x, $y, $a, 30, -24, 2.6);
    ($x, $y, $a) = at($v, 0.85); leaf_on($x, $y, $a - 60, 8, 34, "c2", "c1", 0, int($x));
  }
  seedleaf(200, 200, 170, 50, 26); seedleaf(200, 200, -10, 50, 26);
  leaf_on(200, 200, -96, 30, 56, "c2", "c1", 0, 43);
  leaf_on(200, 200, 100, 28, 54, "c2", "c1", 0, 44);
  leaf_on(200, 200, -30, 22, 44, "c2", "c1", 0, 45);
}
write_svg('4-second-growth.svg', 'Cucumber second growth');

# 5. Third growth, top down: long runners with curling tendrils, yellow flowers and tiny prickly fruit.
soil(200, 200, 34, 30, 5);
{
  my @v1 = vine(-75, 150, 50, 7); my @v2 = vine(50, 146, 44, 7); my @v3 = vine(170, 148, 40, 7);
  for my $v (\@v1, \@v2, \@v3) {
    my ($x, $y, $a) = at($v, 0.45); tendril($x, $y, $a + 75, 40, 24, 2.6);
    ($x, $y, $a) = at($v, 0.85); tendril($x, $y, $a - 80, 38, -24, 2.6);
    ($x, $y, $a) = at($v, 1.0); tendril($x, $y, $a + 10, 30, 22, 2.4);
  }
  for my $v (\@v1, \@v2, \@v3) {
    my ($x, $y, $a) = at($v, 0.92); leaf_on($x, $y, $a - 50, 8, 34, 'c2', 'c1', 0, int($x));
    ($x, $y, $a) = at($v, 0.65); leaf_on($x, $y, $a + 62, 18, 44, 'c2', 'c1', 0, int($y));
  }
  for my $l ([-130, 36, 54], [-15, 32, 52], [105, 34, 54], [225, 30, 50]) { leaf_on(200, 200, $l->[0], $l->[1], $l->[2], "c2", "c1", 0, $l->[0] + 500); }
  # flowers on short stalks; female flowers sit on the tip of a tiny prickly cucumber
  for my $fl ([\@v1, 0.5, -62, 18], [\@v2, 0.72, 58, 17], [\@v3, 0.4, -60, 18], [\@v1, 0.78, 66, 16]) {
    my ($v, $t, $da, $r) = @$fl; my ($x, $y, $a) = at($v, $t);
    my @s = blade($x, $y, $a + $da, 16, 4, 0, 'c2', 'c1', 0.4);
    flower($s[-1][0], $s[-1][1], $r, $a + $da + 20);
  }
  for my $ff ([\@v2, 0.38, -64], [\@v3, 0.78, 62]) {
    my ($v, $t, $da) = @$ff; my ($x, $y, $a) = at($v, $t);
    cuke($x, $y, $a + $da, 40, 12, 6, 0, 2);
  }
}
write_svg('5-third-growth.svg', 'Cucumber third growth');

# 6. Harvest, top down: a lush vine with big pointed leaves and several long prickly cucumbers lying in it.
soil(200, 200, 34, 30, 6);
{
  my @v1 = vine(-40, 168, 40, 8); my @v2 = vine(110, 160, -26, 8); my @v3 = vine(210, 158, 30, 8); my @v4 = vine(35, 156, -34, 8);
  for my $v (\@v1, \@v2, \@v3, \@v4) {
    my ($x, $y, $a) = at($v, 0.55); tendril($x, $y, $a - 72, 40, -24, 2.6);
    ($x, $y, $a) = at($v, 1.0); tendril($x, $y, $a + 10, 34, 22, 2.6);
  }
  for my $l ([\@v1, 0.9, -40, 8, 40], [\@v1, 0.5, -64, 18, 48], [\@v2, 0.9, 40, 8, 42], [\@v3, 0.9, -40, 8, 40], [\@v3, 0.5, 66, 20, 48],
             [\@v4, 0.9, 40, 8, 40], [\@v4, 0.5, 60, 18, 46], [\@v2, 0.5, -60, 16, 44]) {
    my ($v, $t, $da, $pl, $r) = @$l; my ($x, $y, $a) = at($v, $t); leaf_on($x, $y, $a + $da, $pl, $r, 'c2', 'c1', 0, int($x + $y));
  }
  for my $l ([-110, 40, 56], [-8, 36, 54], [178, 40, 54], [72, 32, 52]) { leaf_on(200, 200, $l->[0], $l->[1], $l->[2], 'c2', 'c1', 0, $l->[0] + 600); }
  # cucumbers hang from the runners and lie on top of the leaves
  for my $c ([\@v1, 0.34, 70, 104], [\@v2, 0.62, -84, 100], [\@v3, 0.66, 82, 98]) {
    my ($v, $t, $da, $len) = @$c; my ($x, $y, $a) = at($v, $t);
    cuke($x, $y, $a + $da, $len, 30, ($da > 0 ? 10 : -10), 1, 0);
  }
  for my $fl ([\@v4, 0.72, -60, 17], [\@v2, 0.3, 64, 16], [\@v1, 0.7, 64, 17]) {
    my ($v, $t, $da, $r) = @$fl; my ($x, $y, $a) = at($v, $t);
    my @s = blade($x, $y, $a + $da, 14, 4, 0, 'c2', 'c1', 0.4);
    flower($s[-1][0], $s[-1][1], $r, $a + $da + 20);
  }
}
write_svg('6-harvest.svg', 'Cucumber ready to harvest');

# 7. Harvest, front view: three crisp prickly cucumbers lying crossed, one with its little flower still on.
leaf_on(150, 250, -120, 20, 70, "c2", "c1", 0, 77);
tendril(140, 236, -170, 50, 24, 4);
cuke(100, 246, -22, 228, 54, 8, 1, 0);
cuke(104, 262, 10, 224, 54, -8, 1, 0);
cuke(94, 262, -6, 240, 58, 6, 1, 1);
write_svg('7-harvest-front.svg', 'Harvested cucumbers');

# 8. Dead (never watered), top down: cracked dry soil, three limp runners and flat, curled, dried leaves;
#    one shrivelled yellowed cucumber.
soil(200, 200, 60, 52, 8);
cracks(9, 87, 14, 'c3');
{
  my @v1 = vine(-50, 118, 80, 6, 'c3', 'c4'); my @v2 = vine(75, 112, -76, 6, 'c3', 'c4'); my @v3 = vine(190, 116, 78, 6, 'c3', 'c4');
  for my $v (\@v1, \@v2, \@v3) { my ($x, $y, $a) = at($v, 1.0); tendril($x, $y, $a + 20, 26, 34, 2.4, 'c3'); }
  for my $l ([\@v1, 0.6, 70, 34], [\@v2, 0.55, -70, 36], [\@v3, 0.6, 70, 36], [\@v1, 0.95, -40, 30], [\@v3, 0.95, -50, 30]) {
    my ($v, $t, $da, $r) = @$l; my ($x, $y, $a) = at($v, $t);
    leaf_on($x, $y, $a + $da, 10, $r, 'c3', 'c4', 0.42, int($x * 3 + $y));
  }
  for my $l ([-120, 30, 48], [5, 26, 50], [125, 28, 48]) { leaf_on(200, 200, $l->[0], $l->[1], $l->[2], 'c3', 'c4', 0.45, $l->[0] + 900); }
  my ($x, $y, $a) = at(\@v2, 0.75);          # one shrivelled cucumber, yellowed and wrinkled
  cuke($x, $y, $a - 70, 56, 16, 30, -1, 0);
}
write_svg('8-dead.svg', 'Cucumber died from lack of water');
print "wrote 8 files to $OUT\n";

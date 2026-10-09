# Watermelon crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/watermelon.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/watermelon';
mkdir 'crops'; mkdir $OUT;
# c1 deep green (leaf shade, melon stripes), c2 light green (lit leaf, melon ground colour),
# c3 pale cream-yellow (rind, flowers, glints, dry leaves), c4 dark soil brown (soil, seeds, shade), c5 melon red
my %PAL = (c1 => '#2E6633', c2 => '#8DC164', c3 => '#F2E394', c4 => '#4E3121', c5 => '#E2444B');
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

# Curly tendril: a thin strip whose curvature tightens toward the tip.
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

# One rounded leaf lobe from (x,y) along `ang`, split along its axis into lit and shaded halves;
# $bumps adds rounded secondary lobes on its edge.
sub lobe {
  my ($x, $y, $ang, $len, $w, $bend, $lightc, $dark, $bumps, $wilt) = @_;
  $wilt //= 0;
  my $n = 14; my (@mid, @l, @r); my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * sin(pi * (0.04 + 0.96 * $t)) ** 0.7 * (0.35 + 0.65 * min(1, $t * 2.5));
    $hw *= 1 + ($bumps // 0) * 0.3 * cos($t * 3 * pi * 2) * sin(pi * $t);
    $hw *= 1 - $wilt * 0.45;
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2); my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $lightc : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $lightc, @r, reverse @mid);
}

# Watermelon leaf from above: deeply cut into a big rounded end lobe and two pairs of side lobes, each
# with rounded secondary lobes, on a pale midrib. Unmistakably different from the broad pumpkin leaf.
sub wleaf {
  my ($x, $y, $ang, $len, $lightc, $dark, $wilt, $seed) = @_;
  $lightc //= 'c2'; $dark //= 'c1'; $wilt //= 0; srand($seed // 1);
  my $curl = $wilt ? (rand(1) < 0.5 ? -1 : 1) * $wilt * 50 : 0;
  my $P = sub { my $t = shift; my $aa = $ang + $curl * $t; my ($dx, $dy) = dir($ang + $curl * $t / 2); [$x + $dx * $len * $t, $y + $dy * $len * $t, $aa] };
  # side lobes (lower pair first so the upper ones overlap them), then the end lobe
  for my $sl ([0.22, 66, 0.5, 0.3], [0.5, 52, 0.52, 0.32]) {
    my ($t, $sp, $lf, $wf) = @$sl; my ($px, $py, $pa) = @{$P->($t)};
    for my $side (-1, 1) {
      lobe($px, $py, $pa + $side * ($sp + rand(8)), $len * $lf * (1 - $wilt * 0.3), $len * $wf, -$side * 18 + $side * $wilt * 50, $lightc, $dark, 1, $wilt);
    }
  }
  my ($px, $py, $pa) = @{$P->(0.66)};
  lobe($px, $py, $pa, $len * 0.42, $len * 0.34, $curl * 0.4, $lightc, $dark, 1, $wilt);
  my @mr = map { my $p = $P->($_ / 8 * 0.9); [$p->[0], $p->[1]] } 0 .. 8;
  strip($wilt ? 'c4' : 'c3', $len * 0.04, $len * 0.01, @mr);
}

# A leaf on its stalk from (x,y).
sub leaf_on {
  my ($x, $y, $ang, $plen, $len, $lc, $dc, $wilt, $seed) = @_;
  my @m = blade($x, $y, $ang, $plen, 4.5, 0, $lc // 'c2', $dc // 'c1', 0.4);
  my ($ex, $ey) = @{$m[-1]};
  wleaf($ex, $ey, $ang, $len, $lc, $dc, $wilt, $seed);
}

# Small pale-yellow five-petalled flower seen from above.
sub flower {
  my ($x, $y, $r, $rot) = @_;
  for my $k (0 .. 4) {
    my $a = $rot + $k * 72; my ($dx, $dy) = dir($a);
    lobe($x, $y, $a, $r, $r * 0.9, 0, 'c3', 'c3', 0);
  }
  poly('c2', map { my ($dx, $dy) = dir($rot + 36 + $_ * 72); [$x + $dx * $r * 0.26, $y + $dy * $r * 0.26] } 0 .. 4);
  poly('c1', map { my ($dx, $dy) = dir($rot + $_ * 72); [$x + $dx * $r * 0.12, $y + $dy * $r * 0.12] } 0 .. 4);
}

# Shaded crescent along the lower-right edge of a closed outline @o around (x,y).
sub shade_rim {
  my ($x, $y, $r, $cls, $kmin, @o) = @_;
  my $n = @o;
  my @d = map { my ($vx, $vy) = ($_->[0] - $x, $_->[1] - $y); my $l = sqrt($vx * $vx + $vy * $vy) || 1; ($vx + $vy) * 0.7071 / $l } @o;
  my $s = 0; for my $i (0 .. $n - 1) { if ($d[$i] > 0.1 && $d[($i - 1) % $n] <= 0.1) { $s = $i; last } }
  my ($cx, $cy) = ($x - $r * 0.3, $y - $r * 0.3);
  my (@out, @in);
  for my $j (0 .. $n - 1) {
    my $i = ($s + $j) % $n; last unless $d[$i] > 0.1;
    my $k = $kmin + (1 - $kmin) * (1 - ($d[$i] - 0.1) / 0.9) ** 1.5;
    push @out, $o[$i]; push @in, [$cx + ($o[$i][0] - $cx) * $k, $cy + ($o[$i][1] - $cy) * $k];
  }
  poly($cls, @out, reverse @in) if @out > 1;
}

# A watermelon (oblong ellipsoid) lying along `ang`, half-lengths rx (along) and ry (across):
# light green ground, jagged dark stripes running end to end, shade on the lower right, a glint,
# a cast shadow and a short curly stalk at the stem end.
sub melon {
  my ($x, $y, $rx, $ry, $ang, $nstripe, $young, $dead) = @_;
  my ($G, $D) = $dead ? ("c3", "c4") : ("c2", "c1");
  $nstripe //= 7;
  my ($ux, $uy) = dir($ang); my ($vx, $vy) = (-$uy, $ux);
  my $M = sub { my ($u, $v) = @_; [$x + $ux * $u * $rx + $vx * $v * $ry, $y + $uy * $u * $rx + $vy * $v * $ry] };
  my @o = map { my $th = 2 * pi * $_ / 32; $M->(cos($th), sin($th)) } 0 .. 31;
  poly('c4', map { [$_->[0] + $ry * 0.08, $_->[1] + $ry * 0.12] } @o) unless $young;   # cast shadow
  poly($G, @o);
  # stripes: bands around meridians at angle th (0..pi across the visible face), with jagged edges
  for my $k (1 .. $nstripe) {
    my $th0 = pi * ($k - 0.5) / $nstripe;
    my (@a, @b);
    for my $i (0 .. 24) {
      my $u = -0.97 + 1.94 * $i / 24; my $s = sqrt(max(0, 1 - $u * $u));
      my $jag = ($i % 2 ? 1 : -1) * 0.05 + 0.03 * sin($u * 9 + $k * 2.1);
      my $hw = pi / $nstripe * (0.2 + 0.08 * $s) + $jag * pi / $nstripe;
      push @a, $M->($u, -cos(max(0.02, $th0 - $hw)) * $s);
      push @b, $M->($u, -cos(min(pi - 0.02, $th0 + $hw)) * $s);
    }
    poly($D, @a, reverse @b);
  }
  # shade: the lower-right part of the melon turns deep green
  shade_rim($x, $y, max($rx, $ry), $D, 0.7, @o);
  # glint on the upper left
  my $side = light($vx, $vy) > 0 ? 1 : -1;     # +v faces the light?
  my $endS = light($ux, $uy) > 0 ? 1 : -1;     # +u faces the light?
  my (@go, @gi);                               # a curved glint sliver following the top edge
  for my $i (0 .. 8) {
    my $u = (0.62 - 0.6 * $i / 8) * $endS; my $w = sin(pi * $i / 8) ** 0.7; my $s = sqrt(1 - $u * $u);
    push @go, $M->($u, $side * $s * 0.86); push @gi, $M->($u, $side * $s * (0.86 - 0.16 * $w));
  }
  poly("c3", @go, reverse @gi) unless $dead;
  # stalk at the stem end (-u) with a curl
  unless ($young || $dead) {
    my $st = $M->(-0.98, 0);
    my @sm = blade($st->[0], $st->[1], $ang + 180, $rx * 0.16, $ry * 0.12, 30, 'c2', 'c1', 0.4);
    tendril($sm[-1][0], $sm[-1][1], $ang + 220, $rx * 0.3, 26, 3);
  }
}

# Flat watermelon seed: a dark teardrop with a pale glint and a light rim on the lit side.
sub seed {
  my ($x, $y, $ang, $len, $w, $bright) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx); my @o;
  for my $i (0 .. 15) {
    my $th = 2 * pi * $i / 16; my $c = cos($th);
    my $u = $c * $len / 2; my $v = sin($th) * $w / 2 * (1 + 0.28 * $c) * ($c < -0.85 ? 0.6 : 1);
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly('c4', @o);
  my @half = lit($nx, $ny) ? @o[0 .. 8] : @o[8 .. 15, 0];
  my $k = $bright ? 0.35 : 0.72;
  my @inner = map { [$x + ($_->[0] - $x) * $k, $y + ($_->[1] - $y) * $k] } reverse @half;
  poly('c3', @half, @inner[1 .. $#inner - 1]);
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

# A runner from the crown; returns its points.
sub vine {
  my ($ang, $len, $bend, $w, $lc, $dc) = @_;
  my ($dx, $dy) = dir($ang);
  return blade(200 + $dx * 4, 200 + $dy * 4, $ang, $len, $w, $bend, $lc // 'c2', $dc // 'c1', 0.55);
}
sub at { my ($pts, $t) = @_; my $i = int($t * $#$pts + 0.5); @{$pts->[$i]} }

# Smooth oval seed leaf (cotyledon).
sub seedleaf {
  my ($x, $y, $ang, $len, $w) = @_;
  lobe($x, $y, $ang, $len, $w, 0, 'c2', 'c1', 0);
}

# Leaves along a runner: [t, angle offset, stalk, size].
sub dress {
  my ($v, @L) = @_;
  for my $l (@L) { my ($t, $da, $pl, $sz) = @$l; my ($x, $y, $a) = at($v, $t); leaf_on($x, $y, $a + $da, $pl, $sz, 'c2', 'c1', 0, int($x * 7 + $y)); }
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a small heap of glossy dark watermelon seeds.
for my $s ([130, 300, 14], [196, 310, -170], [262, 302, 168], [162, 262, 200], [228, 266, -18], [196, 226, -100],
           [290, 268, 150], [104, 266, 30]) {
  seed($s->[0], $s->[1], $s->[2], 66, 42);
}
write_svg('1-seeds-front.svg', 'Watermelon seeds');

# 2. Just sown, top down: seeds pushed into small soil pockets (lit by the sun so they read on the dark soil).
my @sown = ([166, 168, -30], [238, 166, 40], [202, 214, 100], [154, 244, 150], [250, 242, -60]);
soil($_->[0], $_->[1], 28, 23, int($_->[0] * 7 + $_->[1])) for @sown;
seed($_->[0], $_->[1], $_->[2], 30, 20, 1) for @sown;
write_svg('2-sown.svg', 'Watermelon just sown');

# 3. First growth, top down: two oval seed leaves and the first small, deeply cut true leaf.
soil(200, 200, 34, 30, 3);
seedleaf(200, 200, 165, 70, 34);
seedleaf(200, 200, -15, 70, 34);
leaf_on(200, 200, -96, 12, 72, "c2", "c1", 0, 31);
write_svg('3-first-growth.svg', 'Watermelon first growth');

# 4. Second growth, top down: a young plant of deeply lobed leaves and the first runner.
soil(200, 200, 34, 30, 4);
{
  my @v = vine(-20, 104, 30, 7);
  my ($x, $y, $a) = at(\@v, 0.95); tendril($x, $y, $a + 70, 40, 26, 3);
  dress(\@v, [1.0, -10, 4, 44], [0.55, -70, 10, 50]);
  leaf_on(200, 200, $_->[0], $_->[1], $_->[2], 'c2', 'c1', 0, $_->[0] + 300) for [-100, 14, 86], [60, 14, 84], [150, 14, 88], [220, 12, 80];
}
write_svg('4-second-growth.svg', 'Watermelon second growth');

# 5. Third growth, top down: sprawling runners, lacy leaves, tendrils, small yellow flowers and a baby melon.
soil(200, 200, 34, 30, 5);
{
  my @v1 = vine(-40, 128, 40, 7); my @v2 = vine(80, 124, -34, 7); my @v3 = vine(190, 126, 36, 7);
  for my $v (\@v1, \@v2, \@v3) {
    my ($x, $y, $a) = at($v, 0.5); tendril($x, $y, $a + 75, 40, 24, 2.6);
    ($x, $y, $a) = at($v, 1.0); tendril($x, $y, $a + 10, 34, -22, 2.6);
  }
  dress(\@v1, [0.35, 70, 10, 62], [0.75, -70, 10, 60], [1.0, 20, 4, 50]);
  dress(\@v2, [0.4, -70, 10, 62], [0.8, 70, 10, 58], [1.0, -20, 4, 50]);
  dress(\@v3, [0.4, 70, 10, 62], [0.75, -70, 10, 58], [1.0, 20, 4, 50]);
  leaf_on(200, 200, $_->[0], $_->[1], $_->[2], 'c2', 'c1', 0, $_->[0] + 500) for [-110, 10, 92], [20, 10, 90], [135, 10, 90], [250, 10, 88];
  for my $fl ([\@v1, 0.6, -60, 15], [\@v2, 0.62, 60, 15], [\@v3, 0.58, -60, 15], [\@v2, 0.25, -64, 14]) {
    my ($v, $t, $da, $r) = @$fl; my ($x, $y, $a) = at($v, $t);
    my @s = blade($x, $y, $a + $da, 14, 4, 0, 'c2', 'c1', 0.4);
    flower($s[-1][0], $s[-1][1], $r, $a + $da + 20);
  }
  my ($x, $y, $a) = at(\@v3, 0.88);           # a baby melon with its flower still on
  my ($dx, $dy) = dir($a + 70);
  melon($x + $dx * 18, $y + $dy * 18, 17, 12, $a + 70, 5, 1);
}
write_svg('5-third-growth.svg', 'Watermelon third growth');

# 6. Harvest, top down: two big striped melons lying among the lacy leaves of the sprawling vine.
soil(200, 200, 34, 30, 6);
{
  my @v1 = vine(-50, 150, 34, 8); my @v2 = vine(100, 126, -30, 8); my @v3 = vine(200, 140, 32, 8); my @v4 = vine(30, 140, -34, 8);
  for my $v (\@v1, \@v2, \@v3, \@v4) {
    my ($x, $y, $a) = at($v, 0.55); tendril($x, $y, $a - 72, 40, -24, 2.6);
    ($x, $y, $a) = at($v, 1.0); tendril($x, $y, $a + 10, 34, 22, 2.6);
  }
  dress(\@v1, [0.45, -70, 10, 66], [0.85, 70, 10, 62], [1.0, -20, 4, 52]);
  dress(\@v2, [0.4, 70, 10, 64], [1.0, 20, 4, 52]);
  dress(\@v3, [0.45, -70, 10, 66], [0.85, 70, 10, 60], [1.0, 20, 4, 52]);
  dress(\@v4, [0.5, 70, 10, 64], [1.0, -20, 4, 52]);
  leaf_on(200, 200, $_->[0], $_->[1], $_->[2], 'c2', 'c1', 0, $_->[0] + 600) for [-110, 10, 96], [-10, 10, 92], [160, 10, 94], [250, 10, 90];
  melon(132, 260, 72, 50, -36, 7);
  melon(282, 152, 60, 42, 62, 6);
  for my $fl ([\@v4, 0.75, 60, 15], [\@v1, 0.25, 64, 14], [\@v3, 0.25, -64, 14]) {
    my ($v, $t, $da, $r) = @$fl; my ($x, $y, $a) = at($v, $t);
    my @s = blade($x, $y, $a + $da, 14, 4, 0, 'c2', 'c1', 0.4);
    flower($s[-1][0], $s[-1][1], $r, $a + $da + 20);
  }
}
write_svg('6-harvest.svg', 'Watermelon ready to harvest');

# A wedge cut from a watermelon, seen from the front: red flesh with dark seeds, pale rind, green skin.
sub wedge {
  my ($x, $y, $r, $a0, $a1) = @_;        # apex (x,y), radius r, arc from a0 to a1 (degrees, 90 = down)
  my $arc = sub { my $k = shift; map { my $a = $a0 + ($a1 - $a0) * $_ / 16; my ($dx, $dy) = dir($a); [$x + $dx * $r * $k, $y + $dy * $r * $k] } 0 .. 16 };
  my @skin = $arc->(1.0); my @rind = $arc->(0.93); my @flesh = $arc->(0.84);
  # thickness: the skin side visible below the face
  poly('c1', (map { [$_->[0] + 6, $_->[1] + 9] } @skin), reverse @skin);
  poly('c2', @skin, reverse @rind);
  poly('c3', @rind, reverse @flesh);
  poly('c5', [$x, $y], @flesh);
  # the face catches the light on its upper left: a pale sheen near the tip
  # seeds in two curved rows
  for my $row ([0.5, 3], [0.7, 4]) {
    my ($k, $cnt) = @$row;
    for my $i (0 .. $cnt - 1) {
      my $a = $a0 + ($a1 - $a0) * ($i + 0.5) / $cnt; my ($dx, $dy) = dir($a);
      seed($x + $dx * $r * $k, $y + $dy * $r * $k, $a, $r * 0.1, $r * 0.065);
    }
  }
}

# 7. Harvest, front view: a whole striped watermelon with its stalk, and a juicy red wedge leaning in front.
melon(196, 212, 136, 96, 0, 7);
wedge(296, 214, 124, 62, 122);
write_svg('7-harvest-front.svg', 'Harvested watermelon');

# 8. Dead (never watered), top down: cracked dry soil, withered runners, curled lacy leaves gone to straw,
#    one small shrivelled, yellowed melon.
soil(200, 200, 62, 54, 8);
cracks(9, 89, 15, 'c3');
{
  my @v1 = vine(-50, 126, 34, 6, 'c3', 'c4'); my @v2 = vine(70, 118, -30, 6, 'c3', 'c4'); my @v3 = vine(195, 120, 32, 6, 'c3', 'c4');
  for my $v (\@v1, \@v2, \@v3) { my ($x, $y, $a) = at($v, 1.0); tendril($x, $y, $a + 30, 28, 30, 2.4, 'c3'); }
  for my $l ([\@v1, 0.55, 70, 60], [\@v2, 0.6, -70, 60], [\@v3, 0.6, 70, 58]) {
    my ($v, $t, $da, $sz) = @$l; my ($x, $y, $a) = at($v, $t); leaf_on($x, $y, $a + $da, 8, $sz, 'c3', 'c4', 0.35, int($x + $y));
  }
  leaf_on(200, 200, $_->[0], 10, $_->[1], 'c3', 'c4', 0.4, $_->[0] + 700) for [-100, 76], [30, 72], [150, 74], [250, 66];
  my ($x, $y, $a) = at(\@v2, 0.85);
  melon($x + 22, $y - 6, 30, 22, $a - 60, 5, 0, 1);
}
write_svg('8-dead.svg', 'Watermelon died from lack of water');
print "wrote 8 files to $OUT\n";

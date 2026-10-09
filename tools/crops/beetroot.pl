# Beetroot crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/beetroot.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/beetroot';
mkdir 'crops'; mkdir $OUT;
# c1 deep glossy leaf green, c2 lit leaf green, c3 cream (glints, seed light side, dry leaves),
# c4 dark soil brown (soil, shade, root shadow), c5 beet crimson (root, stems, veins)
my %PAL = (c1 => '#3B7432', c2 => '#74B348', c3 => '#F1DDB0', c4 => '#55322A', c5 => '#A3234E');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Tapered blade (as in wheat). $taper < 1 keeps width at the tip (stems). Returns points [x, y, angle].
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $taper) = @_;
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
  poly($leftLit ? $light : $dark, @l, reverse @m);
  poly($leftLit ? $dark : $light, @r, reverse @m);
  return @mid;
}

# Thin strip along a list of points (veins), width tapering from w0 to w1.
sub strip {
  my ($cls, $w0, $w1, @p) = @_;
  my (@l, @r);
  for my $i (0 .. $#p) {
    my $j = $i < $#p ? $i + 1 : $i; my $k = $i < $#p ? $i : $i - 1;
    my ($dx, $dy) = ($p[$j][0] - $p[$k][0], $p[$j][1] - $p[$k][1]); my $l = sqrt($dx * $dx + $dy * $dy) || 1;
    my $w = ($w0 + ($w1 - $w0) * $i / $#p) / 2;
    push @l, [$p[$i][0] - $dy / $l * $w, $p[$i][1] + $dx / $l * $w]; push @r, [$p[$i][0] + $dy / $l * $w, $p[$i][1] - $dx / $l * $w];
  }
  poly($cls, @l, reverse @r);
}

# A glossy beet leaf: ovate blade, slightly wavy margin, crimson midrib and side veins.
# $wilt crumples and narrows it (dead stage); $vein = class of the veins ('' for none).
sub leaf {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $vein, $seed, $wilt) = @_;
  srand($seed // 1); $wilt //= 0;
  my $n = 24; my (@mid, @l, @r, @hw);
  my ($px, $py, $a) = ($x, $y, $ang);
  my $ph = rand(6); my $ph2 = rand(6);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my $hw = $w / 2 * sin(pi * $t ** 0.78) ** 0.62;
    $hw *= 1 - $wilt * (0.35 + 0.3 * abs(sin($t * 9 + $ph)));
    my $wl = $hw * (1 + (0.06 + $wilt * 0.25) * sin($t * 17 + $ph));
    my $wr = $hw * (1 + (0.06 + $wilt * 0.25) * sin($t * 17 + $ph2));
    my ($dx, $dy) = dir($a);
    push @mid, [$px, $py, $a, $t]; push @hw, $hw;
    push @l, [$px - $dy * $wl, $py + $dx * $wl]; push @r, [$px + $dy * $wr, $py - $dx * $wr];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n + ($wilt ? (rand(1) - 0.5) * $wilt * 14 : 0);
  }
  my ($dx, $dy) = dir($ang + $bend * 0.3); my $leftLit = lit(-$dy, $dx);
  my @m = map { [$_->[0], $_->[1]] } @mid;
  poly($leftLit ? $light : $dark, @l, reverse @m);
  poly($leftLit ? $dark : $light, @r, reverse @m);
  return unless $vein;
  strip($vein, max(2.2, $w * 0.075), 0.6, @m[0 .. int($n * 0.88)]);
  for my $k (0 .. 3) {                       # side veins sweeping toward the tip
    my $i = int($n * (0.16 + 0.17 * $k)); my ($mx, $my, $ma) = @{$mid[$i]};
    for my $side (-1, 1) {
      my $vl = $hw[$i] * 1.05; my @p; my $va = $ma + $side * 52;
      my ($vx, $vy) = ($mx, $my);
      for my $s (0 .. 4) { push @p, [$vx, $vy]; my ($ex, $ey) = dir($va); $vx += $ex * $vl / 4; $vy += $ey * $vl / 4; $va -= $side * 8; }
      strip($vein, max(1.2, $w * 0.035), 0.4, @p);
    }
  }
}

# A leaf on its crimson stalk; returns nothing. $plen petiole length.
sub leaf_on {
  my ($x, $y, $ang, $plen, $len, $w, $bend, $light, $dark, $vein, $seed, $wilt, $sl, $sd) = @_;
  my @m = blade($x, $y, $ang, $plen, max(4, $w * 0.11), $bend * 0.3, $sl // 'c5', $sd // 'c4', 0.45);
  my ($ex, $ey, $ea) = @{$m[-1]};
  leaf($ex, $ey, $ea, $len, $w, $bend * 0.7, $light, $dark, $vein, $seed, $wilt);
}

# Shaded crescent along the lower-right edge of a closed outline @o around (x,y); kept inside a thin rim.
sub shade_rim {
  my ($x, $y, $r, $cls, $kmin, $rim, @o) = @_;
  my $n = @o;
  my @d = map { my ($vx, $vy) = ($_->[0] - $x, $_->[1] - $y); my $l = sqrt($vx * $vx + $vy * $vy) || 1; ($vx + $vy) * 0.7071 / $l } @o;
  my $s = 0; for my $i (0 .. $n - 1) { if ($d[$i] > 0.1 && $d[($i - 1) % $n] <= 0.1) { $s = $i; last } }
  my ($cx, $cy) = ($x - $r * 0.3, $y - $r * 0.3);
  my (@out, @in);
  for my $j (0 .. $n - 1) {
    my $i = ($s + $j) % $n; last unless $d[$i] > 0.1;
    my $k = $kmin + (1 - $kmin) * (1 - ($d[$i] - 0.1) / 0.9) ** 1.5;
    my $ko = 1 - $rim * min(1, ($d[$i] - 0.1) * 4);
    push @out, [$x + ($o[$i][0] - $x) * $ko, $y + ($o[$i][1] - $y) * $ko];
    push @in, [$cx + ($o[$i][0] - $cx) * $k, $cy + ($o[$i][1] - $cy) * $k];
  }
  poly($cls, @out, reverse @in) if @out > 1;
}

# Beet shoulder seen from above: crimson dome with a shaded crescent, cream glint and leaf-scar crown.
sub beet_top {
  my ($x, $y, $r, $seed) = @_; srand($seed // 7);
  my @o = map { my $th = 2 * pi * $_ / 16; my $k = 0.98 + rand(0.04); [$x + cos($th) * $r * $k, $y + sin($th) * $r * $k] } 0 .. 15;
  poly('c5', @o);
  shade_rim($x, $y, $r, 'c4', 0.74, 0.0, @o);
  glint($x, $y, $r, 1);
}

# Curved cream glint on the upper-left of a round body.
sub glint {
  my ($x, $y, $r, $sq) = @_; my (@o, @i);
  for my $k (0 .. 6) {
    my $a = deg2rad(-176 + $k * 10); my $w = sin(pi * $k / 6) ** 0.8;
    push @o, [$x + cos($a) * $r * 0.82, $y + sin($a) * $r * 0.82 * $sq];
    push @i, [$x + cos($a) * $r * (0.82 - 0.2 * $w), $y + sin($a) * $r * (0.82 - 0.2 * $w) * $sq];
  }
  poly("c3", @o, reverse @i);
}

# Beet seed ball: knobbly corky cluster, dark body with lit cream knobs.
sub seedball {
  my ($x, $y, $r, $seed) = @_; srand($seed);
  # a corky cluster of rounded knobs; each knob dark brown with a lit cream cap toward the upper left
  my @kn = map { my $a = -100 + $_ * 72 + rand(16) - 8; my ($dx, $dy) = dir($a); [$x + $dx * $r * 0.5, $y + $dy * $r * 0.5, $r * (0.48 + rand(0.08))] } 0 .. 4;
  push @kn, [$x - $r * 0.08, $y - $r * 0.1, $r * 0.46];
  my @q = map { 0.9 + rand(0.16) } 0 .. 11;
  for my $k (@kn) {
    my ($kx, $ky, $kr) = @$k;
    poly('c4', map { my $th = 2 * pi * $_ / 12; [$kx + cos($th) * $kr * $q[$_], $ky + sin($th) * $kr * $q[$_]] } 0 .. 11);
  }
  for my $k (@kn) {
    my ($kx, $ky, $kr) = @$k; my (@o, @i);
    for my $s (0 .. 6) {
      my $th = deg2rad(150 + $s * 25); my $w = sin(pi * $s / 6) ** 0.7;
      push @o, [$kx + cos($th) * $kr * 0.86, $ky + sin($th) * $kr * 0.86];
      push @i, [$kx - $kr * 0.12 + cos($th) * $kr * (0.86 - 0.5 * $w), $ky - $kr * 0.12 + sin($th) * $kr * (0.86 - 0.5 * $w)];
    }
    poly('c3', @o, reverse @i);
  }
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

# A rosette of beet leaves around (cx,cy). Each entry: [angle, petiole, len, width, bend].
sub rosette {
  my ($cx, $cy, $seed, @L) = @_;
  my $i = 0;
  for my $l (sort { $b->[2] <=> $a->[2] } @L) {
    my ($a, $pl, $len, $w, $bd) = @$l; my ($dx, $dy) = dir($a);
    leaf_on($cx + $dx * 3, $cy + $dy * 3, $a, $pl, $len, $w, $bd, 'c2', 'c1', 'c5', $seed + $i++);
  }
}

# 1. Seeds, front view: a little heap of knobbly corky beet seed balls.
for ([136, 300, 34, 11], [204, 306, 38, 12], [270, 298, 33, 13], [170, 250, 34, 14], [238, 250, 35, 15], [204, 200, 32, 16]) {
  seedball(@$_);
}
write_svg('1-seeds-front.svg', 'Beetroot seeds');

# 2. Just sown, top down: seed balls pressed into small soil pockets.
my @sown = ([166, 168], [238, 166], [202, 214], [154, 244], [250, 242]);
soil($_->[0], $_->[1], 28, 23, int($_->[0] * 7 + $_->[1])) for @sown;
seedball($_->[0], $_->[1], 15, int($_->[0] + $_->[1])) for @sown;
write_svg('2-sown.svg', 'Beetroot just sown');

# 3. First growth, top down: two strap-shaped seed leaves on crimson stalks and the first true leaves.
soil(200, 200, 34, 30, 3);
leaf_on(200, 200, -160, 24, 62, 22, 6, 'c2', 'c1', '', 31);
leaf_on(200, 200, 20, 24, 62, 22, -6, 'c2', 'c1', '', 32);
leaf_on(200, 200, -80, 18, 60, 36, 8, 'c2', 'c1', 'c5', 33);
leaf_on(200, 200, 100, 16, 54, 34, -8, 'c2', 'c1', 'c5', 34);
write_svg('3-first-growth.svg', 'Beetroot first growth');

# 4. Second growth, top down: a young rosette of glossy veined leaves on crimson stalks.
soil(200, 200, 34, 30, 4);
rosette(200, 200, 40, [-100, 26, 80, 48, 10], [-25, 24, 78, 46, -12], [50, 26, 80, 48, 12], [125, 24, 76, 46, -10],
        [195, 26, 80, 48, 12], [-60, 10, 46, 30, 0], [160, 10, 42, 28, 0]);
beet_top(200, 200, 9, 4);
write_svg('4-second-growth.svg', 'Beetroot second growth');

# 5. Third growth, top down: a full rosette, the crimson root shoulder starting to show.
soil(200, 200, 40, 36, 5);
rosette(200, 200, 50, [-110, 34, 98, 58, 12], [-50, 34, 100, 58, -12], [10, 32, 96, 56, 14], [70, 34, 100, 58, -10],
        [130, 32, 96, 56, 12], [190, 34, 100, 58, -12], [250, 32, 94, 56, 10]);
beet_top(200, 200, 26, 5);
for ([-80, 12, 50, 32, 8], [40, 12, 48, 30, -8], [160, 12, 48, 30, 8]) {
  my ($a, $pl, $len, $w, $bd) = @$_; my ($dx, $dy) = dir($a);
  leaf_on(200 + $dx * 4, 200 + $dy * 4, $a, $pl, $len, $w, $bd, 'c2', 'c1', 'c5', $a + 900);
}
write_svg('5-third-growth.svg', 'Beetroot third growth');

# 6. Harvest, top down: a big round crimson beet shouldering out of the soil under a crown of glossy leaves.
soil(200, 200, 62, 58, 6);
{
  my @L = ([-128, 60, 112, 66, 14], [-84, 62, 116, 68, -10], [-40, 60, 112, 66, 12], [4, 62, 116, 68, -12], [48, 60, 112, 66, 14],
           [92, 62, 116, 68, -12], [136, 60, 112, 66, 12], [180, 62, 116, 68, -14], [224, 60, 112, 66, 10]);
  rosette(200, 200, 160, map { [$_->[0] + 22, 46, 100, 60, -$_->[4]] } @L[0, 2, 4, 6, 7]);   # a second layer behind
  rosette(200, 200, 60, @L);
  beet_top(200, 200, 54, 6);
  # the young heart leaves unfolding from the crown in the middle of the shoulder
  for my $h ([-120, 40, 26, 10], [-10, 38, 24, -10], [100, 38, 26, 10]) {
    my ($a, $len, $w, $bd) = @$h; my ($dx, $dy) = dir($a);
    leaf_on(200 + $dx * 2, 200 + $dy * 2, $a, 3, $len, $w, $bd, "c2", "c1", "c5", $a + 700);
  }
}
write_svg('6-harvest.svg', 'Beetroot ready to harvest');

# Beet seen from the front: round crimson root tapering into a thin tail, stalks rising from its crown.
sub beet_front {
  my ($x, $y, $r, $seed, @stalks) = @_; srand($seed);
  # leaf stalks first (behind the root)
  for my $s (@stalks) {
    my ($a, $pl, $len, $w, $bd) = @$s;
    if ($len) { leaf_on($x, $y - $r * 0.8, $a, $pl, $len, $w, $bd, 'c2', 'c1', 'c5', $seed + $a); }
    else { blade($x, $y - $r * 0.8, $a, $pl, 8, $bd, 'c5', 'c4', 0.35); }
  }
  blade($x + $r * 0.05, $y + $r * 0.9, 96, $r * 1.4, $r * 0.3, -22, 'c5', 'c4');   # taproot tail
  my @o;
  for my $i (0 .. 23) {
    my $th = 2 * pi * $i / 24; my $c = cos($th);
    my $yy = $y - $r * $c * ($c > 0 ? 0.86 : 1.18);
    my $xx = $x + $r * sin($th) * (1 - 0.32 * max(0, -$c) ** 2.2) * (0.97 + rand(0.05));
    push @o, [$xx, $yy];
  }
  poly('c5', @o);
  shade_rim($x, $y, $r, 'c4', 0.66, 0.05, @o);
  for my $k ([0.45, 0.62], [0.68, 0.46]) {        # fine root rings low on the body
    my ($v, $hw) = @$k; my $yy = $y + $r * $v;
    poly('c4', [$x - $r * $hw, $yy], [$x + $r * $hw * 0.2, $yy + 2.4], [$x + $r * $hw * 0.6, $yy + 0.6], [$x - $r * $hw * 0.1, $yy + 0.9]);
  }
  glint($x, $y, $r, 0.9);
  # crown: the stalk scars on top
  poly('c4', [$x - $r * 0.28, $y - $r * 0.8], [$x, $y - $r * 0.9], [$x + $r * 0.28, $y - $r * 0.8], [$x, $y - $r * 0.72]);
}

# 7. Harvest, front view: a bunch of three beets with their crimson stalks and a few glossy leaves.
beet_front(146, 250, 50, 71, [-126, 50, 92, 52, -12], [-100, 76, 90, 50, 8], [-146, 30, 0, 0, -10]);
beet_front(258, 246, 50, 72, [-56, 50, 92, 52, 12], [-80, 80, 90, 50, -8], [-36, 30, 0, 0, 10]);
beet_front(202, 280, 58, 73, [-92, 70, 104, 58, 6], [-114, 52, 0, 0, -8], [-70, 54, 0, 0, 8]);
write_svg('7-harvest-front.svg', 'Harvested beetroot');

# 8. Dead (never watered), top down: cracked dry soil, a small shrivelled root and limp straw-brown leaves.
soil(200, 200, 66, 58, 8);
cracks(9, 83, 15, "c3");
srand(81);
{
  my @dl;
  for my $i (0 .. 6) { my $a = -80 + $i * 360 / 7 + rand(20) - 10; push @dl, [$a, 30 + rand(16), 66 + rand(26), 40 + rand(8), ($i % 2 ? -1 : 1) * (40 + rand(40))]; }
  for (sort { $b->[2] <=> $a->[2] } @dl) {
    my ($a, $pl, $len, $w, $bd) = @$_; my ($dx, $dy) = dir($a);
    leaf_on(200 + $dx * 3, 200 + $dy * 3, $a, $pl, $len, $w, $bd, 'c3', 'c4', 'c4', int($a + 400), 0.55, 'c3', 'c4');
  }
}
{ # a small shrivelled root top: shrunken, wrinkled, dull
  my @o = map { my $th = 2 * pi * $_ / 14; my $k = $_ % 2 ? 0.84 : 1; [200 + cos($th) * 22 * $k, 200 + sin($th) * 20 * $k] } 0 .. 13;
  poly("c4", @o);
  poly("c5", @o[7 .. 12], [196, 196]);
  for my $w ([-150, 0.75], [-100, 0.8], [-200, 0.7]) { my ($dx, $dy) = dir($w->[0]); poly("c4", [200 + $dx * 6, 200 + $dy * 6], [200 + $dx * 22 * $w->[1] - $dy * 2, 200 + $dy * 22 * $w->[1] + $dx * 2], [200 + $dx * 22 * $w->[1] + $dy * 2, 200 + $dy * 22 * $w->[1] - $dx * 2]); }
}
write_svg('8-dead.svg', 'Beetroot died from lack of water');
print "wrote 8 files to $OUT\n";

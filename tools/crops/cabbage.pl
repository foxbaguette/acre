# Cabbage crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/cabbage.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/cabbage';
mkdir 'crops'; mkdir $OUT;
# c1 deep waxy blue-green, c2 lit blue-green (also the head's shade), c3 pale cream (veins, head light, dry leaves),
# c4 dark soil brown (soil, seeds, shade), c5 pale spring-green head
my %PAL = (c1 => '#3F6E62', c2 => '#93BEAE', c3 => '#EBEBC6', c4 => '#5A3A22', c5 => '#B6D597');
my @S; our $OUTER_ON_TOP = 0;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 }
sub light { my ($nx, $ny) = @_; my $l = sqrt($nx * $nx + $ny * $ny) || 1; ($nx * -0.7071 + $ny * -0.7071) / $l }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Tapered blade (as in wheat). $taper < 1 keeps width at the tip. Returns points [x, y, angle].
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

# Thin strip along a list of points (veins, leaf edges), width tapering from w0 to w1.
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

# A broad, smooth, waxy cabbage leaf: almost round blade on a thick pale midrib, pale side veins.
# $wilt crumples and narrows it (dead stage); $vein = class of the veins ('' for none).
sub leaf {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $vein, $seed, $wilt) = @_;
  srand($seed // 1); $wilt //= 0;
  my $n = 24; my (@mid, @l, @r, @hw);
  my ($px, $py, $a) = ($x, $y, $ang);
  my $ph = rand(6); my $ph2 = rand(6);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my $hw = $t < 0.18 ? $w / 2 * 0.3 * ($t / 0.18) ** 0.8 : $w / 2 * max(0, sin(pi * (0.1 + 0.9 * ($t - 0.18) / 0.82) ** 0.95)) ** 0.42;
    $hw = max($hw, $w * 0.15 * min(1, $t / 0.18)) if $t < 0.3;
    $hw *= 1 - $wilt * (0.3 + 0.35 * abs(sin($t * 9 + $ph)));
    my $wl = $hw * (1 + (0.035 + $wilt * 0.25) * sin($t * 13 + $ph));
    my $wr = $hw * (1 + (0.035 + $wilt * 0.25) * sin($t * 13 + $ph2));
    my ($dx, $dy) = dir($a);
    push @mid, [$px, $py, $a, $t]; push @hw, $hw;
    push @l, [$px - $dy * $wl, $py + $dx * $wl]; push @r, [$px + $dy * $wr, $py - $dx * $wr];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n + ($wilt ? (rand(1) - 0.5) * $wilt * 16 : 0);
  }
  my ($dx, $dy) = dir($ang + $bend * 0.3); my $leftLit = lit(-$dy, $dx);
  my @m = map { [$_->[0], $_->[1]] } @mid;
  poly($leftLit ? $light : $dark, @l, reverse @m);
  poly($leftLit ? $dark : $light, @r, reverse @m);
  return unless $vein;
  strip($vein, max(3, $w * 0.11), 1, @m[0 .. int($n * 0.85)]);
  for my $k (0 .. 3) {                       # side veins fanning toward the rim
    my $i = int($n * (0.24 + 0.15 * $k)); my ($mx, $my, $ma) = @{$mid[$i]};
    for my $side (-1, 1) {
      my $vl = $hw[$i] * 0.95; my @p; my $va = $ma + $side * (64 - $k * 6);
      my ($vx, $vy) = ($mx, $my);
      for my $s (0 .. 4) { push @p, [$vx, $vy]; my ($ex, $ey) = dir($va); $vx += $ex * $vl / 4; $vy += $ey * $vl / 4; $va -= $side * 7; }
      strip($vein, max(1.4, $w * 0.04), 0.4, @p);
    }
  }
}

# Brassica seed leaf: a broad heart (two round lobes with a notch at the tip) on a short stalk.
sub cotyledon {
  my ($x, $y, $ang, $stalk, $s) = @_;
  my @m = blade($x, $y, $ang, $stalk, 4, 0, 'c2', 'c1', 0.4);
  my ($ex, $ey) = @{$m[-1]};
  leaf($ex, $ey, $ang - 22, $s, $s * 0.95, 0, 'c2', 'c1', '', 5);
  leaf($ex, $ey, $ang + 22, $s, $s * 0.95, 0, 'c2', 'c1', '', 6);
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

# Curved glint on the upper-left of a round body.
sub glint {
  my ($x, $y, $r, $sq, $cls, $k0, $wd) = @_; my (@o, @i); $k0 //= 0.82; $wd //= 0.2;
  for my $k (0 .. 6) {
    my $a = deg2rad(-178 + $k * 11); my $w = sin(pi * $k / 6) ** 0.8;
    push @o, [$x + cos($a) * $r * $k0, $y + sin($a) * $r * $k0 * $sq];
    push @i, [$x + cos($a) * $r * ($k0 - $wd * $w), $y + sin($a) * $r * ($k0 - $wd * $w) * $sq];
  }
  poly($cls // 'c3', @o, reverse @i);
}

# Quadratic curve through P0 and P2 whose midpoint is M.
sub curve {
  my ($p0, $m, $p2, $n) = @_; $n //= 12;
  my @c = (2 * $m->[0] - 0.5 * ($p0->[0] + $p2->[0]), 2 * $m->[1] - 0.5 * ($p0->[1] + $p2->[1]));
  map { my $t = $_ / $n; [(1 - $t) ** 2 * $p0->[0] + 2 * $t * (1 - $t) * $c[0] + $t * $t * $p2->[0],
                          (1 - $t) ** 2 * $p0->[1] + 2 * $t * (1 - $t) * $c[1] + $t * $t * $p2->[1]] } 0 .. $n;
}

# A firm round head (top or front view): pale dome with a dark rim shadow, a shaded crescent and a lit cap,
# wrapped in broad leaves. Each wrapper leaf grows from a point on the rim (angle a) and covers the part of
# the ball inside a circle (centre d out along a, radius R, unit = ball radius); later leaves lie on top.
# Its free edge shows as a pale lip with a shadow line on the side it overlaps, its midrib as a pale vein.
sub ball {
  my ($x, $y, $r, $sq, @leaves) = @_;
  my $M = sub { [$x + $_[0] * $r, $y + $_[1] * $r * $sq] };
  poly('c1', map { my $th = 2 * pi * $_ / 28; [$x + 3 + cos($th) * ($r + 3), $y + 4 + sin($th) * ($r + 3) * $sq] } 0 .. 27);
  my @o = map { my $th = 2 * pi * $_ / 32; $M->(cos($th), sin($th)) } 0 .. 31;
  poly('c5', @o);
  shade_rim($x, $y, $r, 'c2', 0.68, @o);
  glint($x, $y, $r, $sq, 'c3', 0.9, 0.24);
  my @C = map { my ($dx, $dy) = dir($_->[0]); [$dx * $_->[1], $dy * $_->[1], $_->[2]] } @leaves;
  my $covered = sub { my ($u, $v, $k) = @_; for my $j ($main::OUTER_ON_TOP ? (0 .. $k - 1) : ($k + 1 .. $#C)) { return 1 if ($u - $C[$j][0]) ** 2 + ($v - $C[$j][1]) ** 2 < $C[$j][2] ** 2 } 0 };
  my $runs = sub {    # split a point list into runs that are inside the ball and not covered by later leaves
    my ($k, @p) = @_; my @out; my @cur;
    for my $q (@p) {
      my $ok = $q->[0] ** 2 + $q->[1] ** 2 < 0.94 && !$covered->($q->[0], $q->[1], $k);
      if ($ok) { push @cur, $q } else { push @out, [@cur] if @cur > 2; @cur = () }
    }
    push @out, [@cur] if @cur > 2; @out;
  };
  for my $k (0 .. $#C) {
    my ($cu, $cv, $R) = @{$C[$k]}; my $a = $leaves[$k][0]; my ($dx, $dy) = dir($a);
    # midrib: from the rim toward the leaf's edge, bending a little
    my @vein = map { my $t = $_ / 10; my $d = 0.98 + (($leaves[$k][1] - $R + 0.14) - 0.98) * $t;
                     [cos(deg2rad($a + 10 * sin(pi * $t))) * $d, sin(deg2rad($a + 10 * sin(pi * $t))) * $d] } 0 .. 10;
    for my $run ($runs->($k, @vein)) { strip('c3', $r * 0.075, $r * 0.02, map { $M->(@$_) } @$run); }
    # side veins
    for my $sv (0.2, 0.4, 0.6) {
      my $i = int($sv * 10); my ($pu, $pv) = @{$vein[$i]};
      for my $side (-1, 1) {
        my ($ex, $ey) = dir($a + 180 + $side * 50);
        my @sp = map { my $t = $_ / 6; my ($fx, $fy) = dir($a + 180 + $side * (50 - 25 * $t)); [$pu + ($ex + $fx) * 0.2 * $t, $pv + ($ey + $fy) * 0.2 * $t] } 0 .. 6;
        for my $run ($runs->($k, @sp)) { strip('c3', $r * 0.035, $r * 0.01, map { $M->(@$_) } @$run); }
      }
    }
    # free edge: the arc of this leaf's circle; shadow just beyond it, pale lip on it
    my $base = rad2deg(atan2(-$cv, -$cu));
    my @arc = map { my $th = deg2rad($base - 90 + 180 * $_ / 40); [$cu + cos($th) * $R, $cv + sin($th) * $R] } 0 .. 40;
    my @sha = map { my $th = deg2rad($base - 90 + 180 * $_ / 40); [$cu + cos($th) * ($R + 0.05), $cv + sin($th) * ($R + 0.05)] } 0 .. 40;
    for my $run ($runs->($k, @sha)) { strip(light(-$dx, -$dy) > 0.4 ? 'c5' : 'c2', $r * 0.07, $r * 0.07, map { $M->(@$_) } @$run); }
    for my $run ($runs->($k, @arc)) { strip('c3', $r * 0.045, $r * 0.045, map { $M->(@$_) } @$run); }
  }
}

# The tight round head seen from above: broad wrapper leaves overlapping round a small tight heart.
sub head_top {
  my ($x, $y, $r, $rot) = @_;
  local $OUTER_ON_TOP = 1;
  ball($x, $y, $r, 1, map { [$rot + $_ * 62, 1.0, 1.1 - 0.02 * $_] } 0 .. 5);
  my @c = map { my $th = 2 * pi * $_ / 10; [$x + cos($th) * $r * 0.14, $y + sin($th) * $r * 0.14] } 0 .. 9;
  poly("c3", @c); shade_rim($x, $y, $r * 0.14, "c5", 0.45, @c);
}

# Smooth round cabbage seed: dark sphere with a pale glint.
sub seed {
  my ($x, $y, $r, $bright) = @_;
  my @o = map { my $th = 2 * pi * $_ / 14; [$x + cos($th) * $r, $y + sin($th) * $r] } 0 .. 13;
  if ($bright) { poly("c3", @o); shade_rim($x, $y, $r, "c4", 0.4, @o); return; }   # lit seed lying on dark soil
  poly("c4", @o);
  glint($x, $y, $r, 1, "c3", 0.78, 0.3);
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

# A ring of broad leaves around (200,200). Each entry: [angle, start offset, len, width, bend].
sub ring {
  my ($seed, @L) = @_; my $i = 0;
  for my $l (sort { $b->[2] <=> $a->[2] } @L) {
    my ($a, $off, $len, $w, $bd) = @$l; my ($dx, $dy) = dir($a);
    leaf(200 + $dx * $off, 200 + $dy * $off, $a, $len, $w, $bd, 'c2', 'c1', 'c3', $seed + $i++);
  }
}

# 1. Seeds, front view: a little heap of round dark cabbage seeds.
for ([128, 296, 26], [188, 304, 27], [250, 300, 26], [158, 246, 26], [220, 250, 27], [282, 252, 25], [190, 196, 25]) { seed(@$_); }
write_svg('1-seeds-front.svg', 'Cabbage seeds');

# 2. Just sown, top down: seeds pressed into small soil pockets.
my @sown = ([166, 168], [238, 166], [202, 214], [154, 244], [250, 242]);
soil($_->[0], $_->[1], 26, 21, int($_->[0] * 7 + $_->[1])) for @sown;
for (@sown) { seed($_->[0] - 8, $_->[1] + 3, 7, 1); seed($_->[0] + 6, $_->[1] + 6, 6.5, 1); seed($_->[0] + 1, $_->[1] - 7, 7, 1); }
write_svg('2-sown.svg', 'Cabbage just sown');

# 3. First growth, top down: two heart-shaped seed leaves and the first round true leaves.
soil(200, 200, 34, 30, 3);
cotyledon(200, 200, -168, 30, 44);
cotyledon(200, 200, 12, 30, 44);
leaf(200, 200, -84, 56, 44, 6, 'c2', 'c1', 'c3', 33);
leaf(200, 200, 96, 46, 36, -6, 'c2', 'c1', 'c3', 34);
write_svg('3-first-growth.svg', 'Cabbage first growth');

# 4. Second growth, top down: an open rosette of round waxy blue-green leaves with pale veins.
soil(200, 200, 34, 30, 4);
ring(40, [-100, 2, 118, 96, 8], [-28, 2, 114, 94, -8], [44, 2, 118, 96, 8], [116, 2, 112, 92, -8], [188, 2, 116, 94, 8]);
ring(45, [-64, 2, 66, 56, 0], [70, 2, 62, 54, 0], [190, 2, 60, 50, 0]);
write_svg('4-second-growth.svg', 'Cabbage second growth');

# 5. Third growth, top down: big outer leaves and the inner leaves cupping into a young head.
soil(200, 200, 36, 32, 5);
ring(50, [-110, 4, 146, 116, 10], [-50, 4, 150, 118, -10], [10, 4, 146, 116, 10], [70, 4, 150, 118, -10],
         [130, 4, 146, 116, 10], [190, 4, 150, 118, -10], [250, 4, 144, 114, 10]);
head_top(200, 200, 46, -60);
write_svg('5-third-growth.svg', 'Cabbage third growth');

# 6. Harvest, top down: a big firm round head sitting in a ring of broad blue-green outer leaves.
ring(60, map { [-100 + $_ * 45 + ($_ % 2 ? 8 : -6), 6, 172 - ($_ % 2) * 8, 132, ($_ % 2 ? -10 : 10)] } 0 .. 7);
ring(70, map { [-78 + $_ * 72, 6, 128, 112, ($_ % 2 ? 8 : -8)] } 0 .. 4);
head_top(200, 200, 86, -70);
write_svg('6-harvest.svg', 'Cabbage ready to harvest');

# A cabbage cut in half, the cut face toward the viewer: blue-green outer leaf rim, pale face packed with
# wavy green leaf layers arching over the pale core.
sub half_front {
  my ($x, $y, $r) = @_;              # (x, y) = middle of the flat bottom edge
  my $D = sub { my ($k, $a, $sq) = @_; [$x + cos(deg2rad($a)) * $r * $k, $y + sin(deg2rad($a)) * $r * $k * ($sq // 0.95)] };
  poly('c1', map { $D->(1.0, 180 + $_ * 180 / 20) } 0 .. 20);                    # outer leaf: dark rim
  poly('c2', (map { $D->(1.0, 180 + $_ * 9) } 0 .. 9), (map { $D->(0.9, 261 - $_ * 9) } 0 .. 9));   # lit left half of the rim
  poly('c3', map { $D->(0.9, 180 + $_ * 180 / 20) } 0 .. 20);                   # the cut face
  for my $L (0 .. 4) {                                                           # leaf layers arching over the core
    my $k = 0.8 - $L * 0.15; my @p;
    for my $s (0 .. 40) { my $a = 182 + $s * 176 / 40; my $w = 1 + 0.07 * sin($s * 0.75 + $L * 1.7); push @p, $D->($k * $w, $a, 0.95 * (1.05 - 0.1 * $L / 4)); }
    strip('c5', $r * 0.055, $r * 0.055, @p);
  }
  poly('c5', [$x - $r * 0.16, $y], [$x - $r * 0.05, $y - $r * 0.42], [$x + $r * 0.05, $y - $r * 0.42], [$x + $r * 0.16, $y]);   # core
  poly('c3', [$x - $r * 0.08, $y], [$x - $r * 0.02, $y - $r * 0.32], [$x + $r * 0.02, $y - $r * 0.32], [$x + $r * 0.08, $y]);
  poly('c1', [$x - $r, $y], [$x + $r, $y], [$x + $r * 0.96, $y + $r * 0.07], [$x - $r * 0.96, $y + $r * 0.07]);  # shaded underside
}

# 7. Harvest, front view: one firm round cabbage head with two loose outer leaves flaring from its base.
leaf(200, 300, -176, 124, 112, 18, 'c2', 'c1', 'c3', 71);
leaf(200, 300, -4, 124, 112, -18, 'c2', 'c1', 'c3', 72);
ball(200, 214, 112, 0.92, [205, 1.0, 0.95], [-25, 1.0, 0.95], [150, 1.0, 1.12], [30, 1.0, 1.12], [90, 1.0, 1.34]);
blade(200, 304, 90, 24, 30, 0, 'c3', 'c5', 0.3);          # cut stem
poly('c5', map { my $th = 2 * pi * $_ / 10; [200 + cos($th) * 13, 327 + sin($th) * 4.5] } 0 .. 9);
poly('c3', map { my $th = 2 * pi * $_ / 10; [200 + cos($th) * 9, 327 + sin($th) * 3] } 0 .. 9);
half_front(290, 338, 80);
write_svg("7-harvest-front.svg", "Harvested cabbage");

# 8. Dead (never watered), top down: cracked dry soil, broad leaves collapsed flat and dried to straw.
soil(200, 200, 80, 70, 8);
cracks(10, 83, 18, "c3");
srand(81);
{
  my @dl;
  for my $i (0 .. 4) { my $a = -60 + $i * 72 + rand(16) - 8; push @dl, [$a, 10, 98 + rand(22), 58 + rand(10), ($i % 2 ? -1 : 1) * (24 + rand(24))]; }
  for (sort { $b->[2] <=> $a->[2] } @dl) {
    my ($a, $off, $len, $w, $bd) = @$_; my ($dx, $dy) = dir($a);
    leaf(203 + $dx * $off, 204 + $dy * $off, $a, $len, $w, $bd, 'c4', 'c4', '', int($a + 400), 0.5);   # its shadow
    leaf(200 + $dx * $off, 200 + $dy * $off, $a, $len, $w, $bd, 'c3', 'c3', 'c4', int($a + 400), 0.5);
  }
  # a small shrunken, browned heart that never formed a head
  my @o = map { my $th = 2 * pi * $_ / 12; my $k = $_ % 2 ? 0.8 : 1; [200 + cos($th) * 20 * $k, 200 + sin($th) * 18 * $k] } 0 .. 11;
  poly('c4', @o); poly('c3', @o[6 .. 10], [197, 197]);
}
write_svg('8-dead.svg', 'Cabbage died from lack of water');
print "wrote 8 files to $OUT\n";

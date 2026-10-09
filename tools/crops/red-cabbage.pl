# Red cabbage crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/red-cabbage.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/red-cabbage';
mkdir 'crops'; mkdir $OUT;
# c1 deep aubergine purple (shaded leaves, head shade, seeds), c2 blue-grey violet bloom (lit leaves, bloom glints),
# c3 pale pink-cream (veins, white of the cut face, dry leaves), c4 dark soil brown, c5 vivid red-cabbage magenta-purple head
my %PAL = (c1 => "#4B2A5C", c2 => "#9389B8", c3 => "#F0E6E6", c4 => "#5A3A22", c5 => "#8E3A8C");
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
    my $wl = $hw * (1 + (0.05 + $wilt * 0.22) * sin($t * 11 + $ph));
    my $wr = $hw * (1 + (0.05 + $wilt * 0.22) * sin($t * 11 + $ph2));
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
  shade_rim($x, $y, $r, 'c1', 0.7, @o);
  glint($x, $y, $r, $sq, 'c2', 0.9, 0.24);
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
    for my $run ($runs->($k, @sha)) { strip(light(-$dx, -$dy) > 0.4 ? 'c5' : 'c1', $r * 0.07, $r * 0.07, map { $M->(@$_) } @$run); }
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

# Tiny round brassica seed: dark red-brown sphere, purple-shaded underside, bloom-grey glint.
# $bright: a seed lying on dark soil, drawn lit (bloom grey with a purple shade) so it shows.
sub seed {
  my ($x, $y, $r, $bright) = @_;
  my @o = map { my $th = 2 * pi * $_ / 12; [$x + cos($th) * $r, $y + sin($th) * $r] } 0 .. 11;
  if ($bright) { poly("c2", @o); shade_rim($x, $y, $r, "c1", 0.45, @o); glint($x, $y, $r, 1, "c3", 0.78, 0.3); return; }
  poly("c4", @o);
  shade_rim($x, $y, $r, "c1", 0.55, @o);
  glint($x, $y, $r, 1, "c2", 0.78, 0.3);
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

# 1. Seeds, front view: a little mound of tiny round red-brown seeds.
{
  my @h; srand(11);
  for my $row (0 .. 7) {                                   # packed rows of seeds, trimmed to a rounded mound
    my $y = 322 - $row * 17;
    for my $i (-7 .. 7) {
      my $x = 200 + ($i + ($row % 2) * 0.5) * 20.5;
      next if (($x - 200) / 100) ** 2 + ((322 - $y) / 128) ** 2 > 1;
      push @h, [$x + rand(3) - 1.5, $y + rand(3) - 1.5, 10.5 + rand(1.5)];
    }
  }
  seed(@$_) for sort { $a->[1] <=> $b->[1] } @h;          # back (upper) seeds first
}
write_svg('1-seeds-front.svg', 'Red cabbage seeds');

# 2. Just sown, top down: seeds pressed into small soil pockets.
my @sown = ([200, 160], [154, 206], [246, 204], [176, 252], [228, 254]);
soil($_->[0], $_->[1], 25, 20, int($_->[0] * 5 + $_->[1])) for @sown;
for (@sown) { seed($_->[0] - 7, $_->[1] + 4, 7, 1); seed($_->[0] + 7, $_->[1] + 2, 6.5, 1); seed($_->[0], $_->[1] - 7, 6.5, 1); }
write_svg('2-sown.svg', 'Red cabbage just sown');

# 3. First growth, top down: two heart-shaped seed leaves and the first round purple true leaves.
soil(200, 200, 34, 30, 3);
cotyledon(200, 200, -125, 30, 44);
cotyledon(200, 200, 55, 30, 44);
leaf(200, 200, -30, 58, 46, 6, 'c2', 'c1', 'c3', 33);
leaf(200, 200, 145, 48, 38, -6, 'c2', 'c1', 'c3', 34);
write_svg('3-first-growth.svg', 'Red cabbage first growth');

# 4. Second growth, top down: an open rosette of round waxy purple leaves with pale veins.
soil(200, 200, 34, 30, 4);
ring(140, [-130, 2, 116, 96, -8], [-58, 2, 120, 98, 8], [14, 2, 114, 94, -8], [86, 2, 118, 96, 8], [158, 2, 114, 94, -8], [228, 2, 112, 92, 8]);
ring(145, [-94, 2, 64, 56, 0], [26, 2, 62, 54, 0], [146, 2, 60, 52, 0]);
write_svg('4-second-growth.svg', 'Red cabbage second growth');

# 5. Third growth, top down: big outer leaves and the inner leaves cupping into a young purple head.
soil(200, 200, 36, 32, 5);
ring(150, map { [-96 + $_ * 51.4 + ($_ % 2 ? 6 : -4), 4, 148 - ($_ % 2) * 4, 118, ($_ % 2 ? -10 : 10)] } 0 .. 6);
head_top(200, 200, 50, -30);
write_svg('5-third-growth.svg', 'Red cabbage third growth');

# 6. Harvest, top down: a big firm purple head in a ring of broad bloom-grey outer leaves.
ring(160, map { [-80 + $_ * 40 + ($_ % 2 ? 7 : -5), 6, 174 - ($_ % 2) * 10, 128, ($_ % 2 ? -10 : 10)] } 0 .. 8);
ring(170, map { [-50 + $_ * 72, 6, 132, 112, ($_ % 2 ? 8 : -8)] } 0 .. 4);
head_top(200, 200, 90, -40);
write_svg('6-harvest.svg', 'Red cabbage ready to harvest');

# Red cabbage cut in half straight through the middle, the full cut face toward the viewer: an oval
# cross-section of tight purple leaf layers separated by fine wavy white ribbons that arch round the
# white core rising from the stem. (x, y) = centre of the cut face, r = its radius.
sub half_front {
  my ($x, $y, $r) = @_;
  my $sq = 0.9;
  my $E = sub { my ($k, $a, $cx, $cy) = @_; [($cx // $x) + cos(deg2rad($a)) * $r * $k, ($cy // $y) + sin(deg2rad($a)) * $r * $k * $sq] };
  # cast shadow on the ground, then the outer leaf rim (dark, bloom-lit on the upper left)
  poly('c1', map { my $th = 2 * pi * $_ / 24; [$x + 6 + cos($th) * $r * 1.02, $y + $r * 0.86 + sin($th) * $r * 0.16] } 0 .. 23);
  poly('c1', map { $E->(1.0, $_ * 15) } 0 .. 23);
  poly('c2', (map { $E->(1.0, 150 + $_ * 9) } 0 .. 14), (map { $E->(0.9, 276 - $_ * 9) } 0 .. 14));
  poly('c5', map { $E->(0.9, $_ * 15) } 0 .. 23);                                # the cut face: purple
  # white ribbons: wavy loops arching over the core, open at the bottom where the core comes in
  srand(7);
  for my $L (0 .. 6) {
    my $k = 0.8 - $L * 0.105; my $cy = $y + $r * 0.3 * (1 - $k / 0.8) ;
    my @p; my $ph = rand(6); my $f = 0.3 + rand(0.18);
    my ($a0, $a1) = (100 + $L * 3, 440 - $L * 3);
    for my $s (0 .. 60) {
      my $a = $a0 + ($a1 - $a0) * $s / 60;
      my $w = 1 + (0.05 + 0.012 * $L) * sin($s * $f * 1.6 + $ph) + 0.02 * sin($s * 1.1 + $L);
      push @p, $E->($k * $w, $a, $x, $cy);
    }
    strip('c3', $r * 0.026, $r * 0.026, @p);
  }
  # the white core: from the stem at the bottom rim up into the middle, with short side branches
  my $by = $y + $r * 0.9 * $sq;
  poly("c3", [$x - $r * 0.2, $by], [$x - $r * 0.12, $y + $r * 0.32], [$x - $r * 0.06, $y + $r * 0.14], [$x, $y + $r * 0.1], [$x + $r * 0.06, $y + $r * 0.14], [$x + $r * 0.12, $y + $r * 0.32], [$x + $r * 0.2, $by]);
  for my $s (-1, 1) {
    strip('c3', $r * 0.045, $r * 0.012, curve([$x + $s * $r * 0.08, $y + $r * 0.35], [$x + $s * $r * 0.28, $y + $r * 0.2], [$x + $s * $r * 0.44, $y + $r * 0.26]));
    strip('c3', $r * 0.035, $r * 0.01, curve([$x + $s * $r * 0.05, $y + $r * 0.1], [$x + $s * $r * 0.2, $y - $r * 0.06], [$x + $s * $r * 0.34, $y - $r * 0.02]));
  }
  # cut stem stub at the bottom, resting on the ground
  poly('c3', [$x - $r * 0.15, $by - 2], [$x + $r * 0.15, $by - 2], [$x + $r * 0.12, $by + $r * 0.12], [$x - $r * 0.12, $by + $r * 0.12]);
  poly('c5', [$x + $r * 0.02, $by - 2], [$x + $r * 0.15, $by - 2], [$x + $r * 0.12, $by + $r * 0.12], [$x + $r * 0.02, $by + $r * 0.12]);
}

# 7. Harvest, front view: a firm round red cabbage, and a full half, its whole cut face showing the white-and-purple swirl.
ball(250, 200, 100, 0.92, [205, 1.0, 0.95], [-25, 1.0, 0.95], [150, 1.0, 1.12], [30, 1.0, 1.12], [90, 1.0, 1.34]);
half_front(148, 258, 104);
write_svg("7-harvest-front.svg", "Harvested red cabbage");

# 8. Dead (never watered), top down: cracked dry soil, leaves collapsed flat and dried to papery straw with
# dark purple veins, and a small shrivelled heart that never formed a head.
soil(200, 200, 78, 68, 8);
cracks(9, 183, 17, "c3");
srand(181);
{
  my @dl;
  for my $i (0 .. 5) { my $a = -100 + $i * 60 + rand(16) - 8; push @dl, [$a, 10, 92 + rand(24), 54 + rand(10), ($i % 2 ? -1 : 1) * (24 + rand(24))]; }
  for (sort { $b->[2] <=> $a->[2] } @dl) {
    my ($a, $off, $len, $w, $bd) = @$_; my ($dx, $dy) = dir($a);
    leaf(203 + $dx * $off, 204 + $dy * $off, $a, $len, $w, $bd, 'c4', 'c4', '', int($a + 500), 0.55);   # its shadow
    leaf(200 + $dx * $off, 200 + $dy * $off, $a, $len, $w, $bd, 'c3', 'c4', 'c1', int($a + 500), 0.55);
  }
  my @o = map { my $th = 2 * pi * $_ / 12; my $k = $_ % 2 ? 0.74 : 1; [200 + cos($th) * 21 * $k, 200 + sin($th) * 19 * $k] } 0 .. 11;
  poly('c1', @o); poly('c4', @o[0 .. 4], [203, 203]);
}
write_svg('8-dead.svg', 'Red cabbage died from lack of water');
print "wrote 8 files to $OUT\n";

# Grape crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/grapes.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/grapes';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#3B6B2C', c2 => '#8EBF4F', c3 => '#F0E3BE', c4 => '#4A2C27', c5 => '#7A3C8C');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Points along a bent path: 11 entries [x, y, heading] (same stepping as blade).
sub path {
  my ($x, $y, $a, $len, $bend) = @_; my @p;
  for my $i (0 .. 10) { push @p, [$x, $y, $a]; my ($dx, $dy) = dir($a); $x += $dx * $len / 10; $y += $dy * $len / 10; $a += $bend / 10; }
  @p;
}

# A tapered blade / cane from (x,y) heading `ang`, bending `bend` degrees; tipw = tip width fraction.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $tipw) = @_;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $t * (1 - ($tipw // 0))) ** 0.85 + ($i == $n ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# Ellipse point list (rotated by rot degrees).
sub ell {
  my ($x, $y, $rx, $ry, $n, $rot) = @_; $rot //= 0; my ($c, $s) = dir($rot);
  map { my ($u, $v) = dir($_ * 360 / $n); [$x + $u * $rx * $c - $v * $ry * $s, $y + $u * $rx * $s + $v * $ry * $c] } 0 .. $n - 1;
}

# A grape vine leaf: petiole from (x,y) heading `ang`, then a broad, roughly round blade with a big pointed top lobe,
# two upper and two smaller lower side lobes, finely toothed, and a deep heart-shaped sinus where the stalk joins.
# Each lobe is folded along its vein into a lit and a shaded facet. deep = lobe depth, wf = width factor (curling).
my @LOBES = ([-128, 0.80], [-62, 0.94], [0, 1.0], [62, 0.94], [128, 0.80]);
my @BOUND = (-180, -95, -31, 31, 95, 180);
sub vleaf {
  my ($x, $y, $ang, $len, %o) = @_;
  my $L = $o{light} // 'c2'; my $D = $o{dark} // 'c1'; my $deep = $o{deep} // 0.3; my $wf = $o{wf} // 1;
  my $pl = $len * ($o{pet} // 0.22);
  blade($x, $y, $ang, $pl + $len * 0.1, max(2.4, $len * 0.06), 0, $L, $D, 0.6) unless $o{nopet};
  my ($dx, $dy) = dir($ang);
  my $R = $len * 0.5;
  my ($cx, $cy) = ($x + $dx * ($pl + $R * 0.3), $y + $dy * ($pl + $R * 0.3));
  my $f = sub {
    my $th = shift; my $g = 1 - $deep;
    for (@LOBES) { my ($p, $a) = @$_; my $d = abs($th - $p); $g = max($g, $a * (1 - $deep * min(1, $d / 32) ** 2.2)); }
    $g * (1 - 0.72 * exp(-((180 - abs($th)) / 20) ** 2));
  };
  my %pt;
  for (my $th = -180; $th <= 180; $th += 4) {
    my $k = $f->($th); $k *= 0.94 if ($th / 4) % 2 && abs($th) < 168;
    my ($u, $v) = dir($ang + $th); # wf narrows the leaf across its midrib (curling)
    my $along = $u * $dx + $v * $dy; my $across = -$u * $dy + $v * $dx;
    $pt{$th} = [$cx + ($along * $dx - $across * $dy * $wf) * $R * $k, $cy + ($along * $dy + $across * $dx * $wf) * $R * $k];
  }
  my ($nx, $ny) = dir($ang - 90); my $leftLit = lit($nx, $ny);       # two halves split along the midrib
  poly($leftLit ? $L : $D, [$cx, $cy], map { $pt{$_ * 4} } -45 .. 0);
  poly($leftLit ? $D : $L, [$cx, $cy], map { $pt{$_ * 4} } 0 .. 45);
  return if $o{noveins};
  if ($o{vein}) { my $tp = $pt{0}; my ($u, $v) = dir($ang + 90); poly($o{vein}, [$cx + $u * 1.2, $cy + $v * 1.2], [$cx + ($tp->[0] - $cx) * 0.8, $cy + ($tp->[1] - $cy) * 0.8], [$cx - $u * 1.2, $cy - $v * 1.2]); }
  for my $i (0, 1, 3, 4) {                       # thin vein grooves out to the side lobes
    my $lobe = $LOBES[$i][0]; my $a4 = 4 * int($lobe / 4 + ($lobe < 0 ? -0.5 : 0.5));
    my $tp = $pt{$a4}; my $tip = [$cx + ($tp->[0] - $cx) * 0.66, $cy + ($tp->[1] - $cy) * 0.66];
    my ($u, $v) = dir($ang + $lobe + 90); my $onLit = ($lobe < 0) == ($leftLit ? 1 : 0);
    poly($o{vein} // ($onLit ? $D : $L), [$cx + $u * 1.0, $cy + $v * 1.0], $tip, [$cx - $u * 1.0, $cy - $v * 1.0]);
  }
}

# A curly tendril: a short reach that winds into a tightening coil.
sub tendril {
  my ($x, $y, $ang, $len, $turn, $cls) = @_; $cls //= 'c2';
  my (@l, @r); my $a = $ang; my $w = 1.5; my $step = $len / 22;
  for my $i (0 .. 22) {
    my ($dx, $dy) = dir($a);
    push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
    $x += $dx * $step; $y += $dy * $step;
    $a += $i < 8 ? $turn * 0.15 : $turn * (0.6 + ($i - 8) * 0.12);
    $step *= $i < 8 ? 1 : 0.94; $w = max(0.8, $w * 0.97);
  }
  poly($cls, @l, reverse @r);
}

# One grape: body, a shaded crescent toward the lower right and a small glossy highlight toward the light.
sub grape {
  my ($x, $y, $rx, $ry, %o) = @_; $ry //= $rx;
  my $body = $o{body} // 'c5'; my $shade = $o{shade} // 'c4'; my $hi = $o{hi} // 'c3';
  poly($body, ell($x, $y, $rx, $ry, 18));
  my (@out, @in);
  for my $k (0 .. 10) {
    my $th = -40 + 170 * $k / 10; my ($u, $v) = dir($th);
    push @out, [$x + $u * $rx, $y + $v * $ry];
    my $d = 1 - ($o{sd} // 0.34) * sin(pi * $k / 10);
    unshift @in, [$x + $u * $rx * $d, $y + $v * $ry * $d];
  }
  poly($shade, @out, @in);
  return if $o{nohi};
  my ($hx, $hy) = ($x - $rx * 0.4, $y - $ry * 0.42); my $h = min($rx, $ry) * 0.26;
  poly($hi, [$hx - $h, $hy + $h * 0.3], [$hx - $h * 0.1, $hy - $h * 0.8], [$hx + $h * 0.7, $hy - $h * 0.4], [$hx, $hy + $h * 0.3]);
}

# A top-down bunch hanging below a cane at (x,y), its tip pointing toward `ang`: a cone of grapes, the wide
# shoulder near the stalk drawn last because it is nearest to the viewer.
my @ROWS = ([0.5, 4], [1.45, 4], [2.4, 3], [3.3, 3], [4.15, 2], [4.9, 1]);
sub bunch_top {
  my ($x, $y, $ang, $r, %o) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  blade($x - $dx * $r * 0.6, $y - $dy * $r * 0.6, $ang, $r * 1.4, 4, 0, 'c3', 'c4', 0.6);
  my @g; srand(int($x * 3 + $y));
  my @rows = @{$o{rows} // \@ROWS};
  for my $row (reverse @rows) {
    my ($u, $n) = @$row; my $rr = $r * (1 - $u * 0.035);
    for my $i (0 .. $n - 1) {
      my $v = ($i - ($n - 1) / 2) * 1.58 * $r + (rand(0.36) - 0.18) * $r;
      my $uu = $u + rand(0.3) - 0.15; push @g, [$x + $dx * $uu * $r + $nx * $v, $y + $dy * $uu * $r + $ny * $v, $rr * (0.92 + rand(0.14))];
    }
  }
  poly($o{shade} // 'c4', ell($_->[0] + 2, $_->[1] + 2, $_->[2] * 1.12, $_->[2] * 1.12, 12)) for @g;   # dark gaps between the berries
  grape(@$_[0, 1], $_->[2], $_->[2], %o) for @g;
}

# Small irregular patch of soil.
sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o;
  srand($seed);
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12; my $k = 0.82 + rand(0.3); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
}

# Pale cracks running out through dry soil.
sub cracks {
  my ($n, $step, $seed) = @_; srand($seed);
  for my $i (0 .. $n - 1) {
    my $a = $i * 360 / $n + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
    for my $k (0 .. 4) {
      my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.2 - $k * 0.35;
      push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
      $x += $dx * $step; $y += $dy * $step;
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

# The gnarled woody trunk seen from above: a rough dark stump with pale bark fissures.
sub trunk {
  my ($r) = @_; srand(7);
  poly('c4', map { my ($u, $v) = dir($_ * 30 + 8); my $k = $_ % 2 ? 0.86 : 1.04; [200 + $u * $r * $k, 200 + $v * $r * $k] } 0 .. 11);
  for my $i (0 .. 5) {
    my $a = $i * 60 + rand(20); my ($u, $v) = dir($a); my ($p, $q) = dir($a + 90);
    poly('c3', [200 + $u * $r * 0.3, 200 + $v * $r * 0.3], [200 + $u * $r * 0.9 + $p * 1.6, 200 + $v * $r * 0.9 + $q * 1.6], [200 + $u * $r * 0.9 - $p * 1.6, 200 + $v * $r * 0.9 - $q * 1.6]);
  }
  poly('c3', ell(200 - $r * 0.2, 200 - $r * 0.2, $r * 0.3, $r * 0.22, 8, -30));
}

# A woody arm: dark bark with a narrow lit ridge (green canes when given green classes).
sub wood {
  my ($x, $y, $a, $len, $w, $bend, $l, $d) = @_;
  if ($l eq 'c3') { blade($x, $y, $a, $len, $w, $bend, 'c4', 'c4', 0.45); blade($x, $y, $a, $len, $w * 0.42, $bend, 'c3', 'c4', 0.45); }
  else { blade($x, $y, $a, $len, $w, $bend, $l, $d, 0.45); }
}

# Top-down vine: arms (cordons / canes) radiating from the trunk, vine leaves along them outer-first, tendrils.
# Arms: [angle, length, bend]. Returns each arm's path.
sub vine {
  my ($seed, $leafLen, $per, $aw, $light, $dark, @arms) = @_;
  srand($seed); my (@leaves, @paths, @tend);
  for my $t (@arms) {
    my @p = path(200, 200, @$t); push @paths, \@p;
    for my $k (1 .. $per) {
      my $f = 0.25 + 0.75 * $k / $per; my ($x, $y, $h) = @{$p[int($f * 10 + 0.5)]};
      my $side = $k % 2 ? 1 : -1;
      push @leaves, [$x, $y, $h + $side * (40 + rand(25)), $leafLen * (0.8 + 0.25 * $f + rand(0.1))];
      push @tend, [$x, $y, $h - $side * 50, $leafLen * 0.55, -$side * 40] if $k == 2;
    }
    my ($x, $y, $h) = @{$p[10]};
    push @leaves, [$x, $y, $h + rand(16) - 8, $leafLen * 0.9];
  }
  wood(200, 200, $_->[0], $_->[1], $aw, $_->[2], $light, $dark) for @arms;
  tendril(@$_) for @tend;
  for (sort { (($b->[0] - 200) ** 2 + ($b->[1] - 200) ** 2) <=> (($a->[0] - 200) ** 2 + ($a->[1] - 200) ** 2) } @leaves) {
    vleaf(@$_);
  }
  @paths;
}

# 1. Planting material, front view: a rooted hardwood cutting - a knobbly woody rod with buds at its nodes,
# roots at the bottom and the first young leaf and tendril breaking from the top bud.
{
  my ($x0, $y0, $x1, $y1) = (168, 318, 236, 146); my $w = 26;
  for my $r ([110, 56, 18], [90, 46, -14], [130, 50, 16], [100, 38, 30], [120, 62, -8], [146, 38, -24], [78, 34, 20]) {
    blade($x0 + ($r->[0] - 110) * 0.2, $y0 - 4, $r->[0], $r->[1], 5, $r->[2], 'c3', 'c4');
  }
  my $a = rad2deg(atan2($y1 - $y0, $x1 - $x0)); my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
  my $len = sqrt(($x1 - $x0) ** 2 + ($y1 - $y0) ** 2);
  my $at = sub { my ($t, $o) = @_; [$x0 + $dx * $len * $t + $nx * $o, $y0 + $dy * $len * $t + $ny * $o] };
  my $hwf = sub { my $t = shift; my $node = 0; for my $k (1, 2) { $node = max($node, 1 - abs($t - $k / 3) / 0.06) } $w / 2 * (1 + 0.2 * max(0, $node)) * (1 - 0.12 * $t) };
  my (@L, @R, @M);
  for my $i (0 .. 30) { my $t = $i / 30; my $hw = $hwf->($t); push @L, $at->($t, $hw); push @R, $at->($t, -$hw); push @M, $at->($t, 0); }
  my $lLit = lit($nx, $ny);
  poly($lLit ? 'c3' : 'c4', @L, reverse @M); poly($lLit ? 'c4' : 'c3', @R, reverse @M);
  for my $s ([0.06, 0.25, 0.22], [0.42, -0.2, 0.18], [0.72, 0.28, 0.2], [0.2, -0.32, 0.12], [0.55, 0.12, 0.1]) {   # bark fissures
    my ($t, $o, $l) = @$s; my $c = ($o > 0) == $lLit ? 'c4' : 'c3';
    poly($c, $at->($t, $o * $w), $at->($t + $l * 0.5, $o * $w + 1.6), $at->($t + $l, $o * $w), $at->($t + $l * 0.5, $o * $w - 1.6));
  }
  for my $k (1, 2) {                               # node rings and a bud at each node
    my $t = $k / 3; my $hw = $hwf->($t);
    poly('c4', $at->($t - 0.012, $hw), $at->($t + 0.012, $hw), $at->($t + 0.012, -$hw), $at->($t - 0.012, -$hw));
    my $side = $k % 2 ? 1 : -1; my $b = $at->($t, $side * $hw * 0.95);
    blade(@$b, $a + $side * 60, 18, 13, -$side * 14, 'c2', 'c1');
  }
  my $top = $at->(1, 0);
  poly('c4', ell(@$top, $w / 2 * 0.9, 4.5, 12, $a + 90)); poly('c3', ell($top->[0] - 1, $top->[1], $w / 2 * 0.55, 2.6, 12, $a + 90));
  # the breaking top bud: a little green shoot with a tendril and a young vine leaf
  my $s0 = $at->(0.93, -$w * 0.45);
  my @tp = path(@$s0, $a - 40, 44, 30);
  blade(@$s0, $a - 40, 44, 7, 30, 'c2', 'c1', 0.5);
  tendril(@{$tp[5]}[0, 1], $tp[5][2] + 70, 46, 34);
  vleaf(@{$tp[10]}[0, 1], $tp[10][2] - 10, 96, pet => 0.14);
}
write_svg('1-seeds-front.svg', 'Grapevine cutting');

# 2. Just planted, top down: the cutting stub in its planting hole, two buds swelling into tiny leaves.
soil(200, 200, 56, 48, 2);
poly('c3', ell(198, 198, 17, 17, 12));
poly('c4', ell(201, 201, 17, 17, 12)); poly('c3', ell(199, 199, 12, 12, 12)); poly('c4', ell(200, 200, 4, 4, 6));
for my $b ([-50, 1], [150, -1]) { my ($u, $v) = dir($b->[0]); blade(200 + $u * 14, 200 + $v * 14, $b->[0], 20, 13, $b->[1] * 18, 'c2', 'c1', 0.4); }
{ my ($u, $v) = dir(-50); my @p = path(200 + $u * 14, 200 + $v * 14, -50, 20, 18); vleaf(@{$p[10]}[0, 1], -36, 40, pet => 0.08); }
{ my ($u, $v) = dir(150); my @p = path(200 + $u * 14, 200 + $v * 14, 150, 20, -18); vleaf(@{$p[10]}[0, 1], 140, 30, pet => 0.08, noveins => 1); }
write_svg('2-sown.svg', 'Grapevine just planted');

# 3. First growth, top down: the young green shoot with its first vine leaves and a curling tendril.
soil(200, 200, 34, 30, 3);
{
  my @p = path(200, 200, -100, 64, 50);
  blade(200, 200, -100, 64, 7, 50, 'c2', 'c1', 0.5);
  tendril(@{$p[6]}[0, 1], $p[6][2] - 70, 44, -40);
  vleaf(200, 200, 150, 64); vleaf(200, 200, 40, 66);
  vleaf(@{$p[3]}[0, 1], $p[3][2] - 80, 70);
  vleaf(@{$p[7]}[0, 1], $p[7][2] + 80, 66);
  vleaf(@{$p[10]}[0, 1], $p[10][2] + 10, 60);
  poly('c4', ell(200, 200, 11, 11, 12)); poly('c3', ell(199, 199, 7, 7, 12));
}
write_svg('3-first-growth.svg', 'Grapevine first growth');

# 4. Second growth, top down: short trunk with young green canes, vine leaves and tendrils.
soil(200, 200, 34, 30, 4);
vine(41, 52, 2, 7, 'c2', 'c1', [-90, 72, 30], [-18, 74, -28], [54, 70, 30], [126, 74, -26], [198, 70, 28]);
trunk(14);
write_svg('4-second-growth.svg', 'Grapevine second growth');

# 5. Third growth, top down: woody arms, a full leafy canopy with tendrils and small green bunches forming.
soil(200, 200, 34, 30, 5);
my @p5 = vine(51, 58, 3, 10, 'c3', 'c4', [-95, 100, 28], [-25, 102, -26], [45, 98, 28], [115, 102, -26], [185, 98, 26], [-150, 70, -20], [80, 66, 22]);
for my $i (0 .. 4) {
  my ($x, $y, $h) = @{$p5[$i][6]}; my $side = $i % 2 ? 1 : -1; my $a = $h + $side * 80;
  bunch_top($x, $y, $a, 6.5, body => 'c2', shade => 'c1');
}
trunk(17);
write_svg('5-third-growth.svg', 'Grapevine third growth');

# 6. Harvest, top down: the full vine with heavy purple bunches hanging between the leaves.
soil(200, 200, 34, 30, 6);
my @p6 = vine(61, 64, 3, 12, 'c3', 'c4', [-95, 122, 28], [-25, 124, -26], [45, 120, 28], [115, 124, -26], [185, 120, 26], [-150, 86, -20], [80, 82, 22]);
for my $b ([-96, 12, 14], [-22, 11.5, -12], [50, 12, 14], [122, 11.5, -14], [194, 12, 12]) {
  my ($a, $r, $tw) = @$b; my ($u, $v) = dir($a);
  bunch_top(200 + $u * 60, 200 + $v * 60, $a + $tw, $r);
}
for my $i (0 .. 4) { my $a = -60 + $i * 72; my ($u, $v) = dir($a); vleaf(200 + $u * 10, 200 + $v * 10, $a, 58); }
trunk(19);
write_svg('6-harvest.svg', 'Grapes ready to harvest');

# 7. Harvested produce, front view: one classic bunch of purple grapes on its woody stalk with a vine leaf.
vleaf(214, 104, -24, 156, nopet => 1);
tendril(200, 66, 196, 96, 30);
wood(204, 40, 104, 62, 10, -8, 'c3', 'c4');
{
  my @rows = ([102, 5, -0.3], [134, 6, 0.2], [166, 6, -0.2], [198, 5, 0.3], [228, 4, 0], [256, 4, 0.4], [284, 3, 0.1], [310, 2, 0.3], [334, 1, 0.2]);
  my $r = 19.5; my @g; srand(9);
  for my $row (@rows) {
    my ($y, $n, $sh) = @$row; my $sp = 2 * $r * 0.88;
    for my $i (0 .. $n - 1) { push @g, [196 + ($i - ($n - 1) / 2) * $sp + $sh * 12 + rand(8) - 4, $y + rand(8) - 4, $r * (0.92 + rand(0.14))]; }
  }
  poly('c4', ell($_->[0] + 3, $_->[1] + 3, $_->[2] * 1.06, $_->[2] * 1.14, 12)) for @g;
  for (sort { $a->[1] <=> $b->[1] } @g) { grape($_->[0], $_->[1], $_->[2] * 0.92, $_->[2] * 1.05); }
}
write_svg('7-harvest-front.svg', 'Bunch of grapes');

# 8. Dead (never watered), top down: cracked dry soil, bare woody arms, dry curled leaves, shrivelled raisins.
soil(200, 200, 60, 52, 8);
cracks(7, 14, 83);
{
  my @arms = ([-95, 100, 40], [-25, 104, -36], [45, 96, 42], [115, 102, -34], [185, 98, 36], [-150, 66, -30]);
  wood(200, 200, $_->[0], $_->[1], 9, $_->[2], 'c3', 'c4') for @arms;
  srand(88);
  for my $t (@arms) {
    my @p = path(200, 200, @$t);
    tendril(@{$p[6]}[0, 1], $p[6][2] + 60, 34, 36, 'c3');
    for my $k (5, 9) {
      my ($x, $y, $h) = @{$p[$k]}; my $side = $k == 5 ? 1 : -1;
      vleaf($x, $y, $h + $side * (60 + rand(30)), 46 + rand(8), light => 'c3', dark => 'c3', vein => 'c4', deep => 0.36, wf => 0.7 + rand(0.2));
    }
  }
  for ([238, 168], [247, 180], [232, 182], [160, 236], [171, 246], [258, 250]) { grape(@$_, 6.5, 5.5, body => 'c4', shade => 'c4', hi => 'c3'); }
  trunk(17);
}
write_svg('8-dead.svg', 'Grapevine died from lack of water');
print "wrote 8 files to $OUT\n";

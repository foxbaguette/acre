# Jabuticaba crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/jabuticaba.pl
# Grown as a compact bush. Top-down stages (2-6, 8) share one fixed scale centred on (200,200).
# Signature: cauliflory - glossy round black-purple berries packed DIRECTLY on the pale trunk and branches,
# with small leaves only toward the branch ends. No crown on the berries, no bunches.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/jabuticaba';
mkdir 'crops'; mkdir $OUT;
# c1 leaf green, c2 lit green, c3 pale cream (bark light, white flesh, flowers, gloss, dried leaves), c4 dark soil / bark shade,
# c5 jabuticaba black-purple
my %PAL = (c1 => '#3A7136', c2 => '#86BC57', c3 => '#EEE4CF', c4 => '#3F2A1F', c5 => '#431A4B');
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


# A glossy jabuticaba berry: near-black purple ball, a hard white highlight and a faint rim light. No crown.
sub berry {
  my ($x, $y, $r, %o) = @_;
  my $B = $o{body} // 'c5'; my $H = $o{hi} // 'c3';
  poly($o{shadow} // 'c4', ell($x + $r * 0.18, $y + $r * 0.18, $r, $r, 12)) if $o{shadow};
  my @o = ell($x, $y, $r, $r, 14);
  poly($B, @o);
  return if $o{matte};
  # shaded lower right: a near-black crescent
  poly($o{dark} // "c4", @o[0 .. 7], map { [$x + ($_->[0] - $x) * 0.72 - $r * 0.12, $y + ($_->[1] - $y) * 0.72 - $r * 0.12] } reverse @o[0 .. 7]) unless $o{norim};
  # specular highlight: a curved window glint and a dot
  my ($hx, $hy) = ($x - $r * 0.38, $y - $r * 0.38);
  poly($H, [$hx - $r * 0.26, $hy + $r * 0.12], [$hx - $r * 0.12, $hy - $r * 0.16], [$hx + $r * 0.16, $hy - $r * 0.24], [$hx + $r * 0.02, $hy - $r * 0.04]);
  poly($H, ell($x - $r * 0.1, $y - $r * 0.52, $r * 0.09, $r * 0.09, 6)) if $r > 9;
}

# A split berry: dark skin cup with translucent white flesh and a seed showing.
sub split_berry {
  my ($x, $y, $r) = @_;
  poly('c5', ell($x, $y, $r, $r * 0.98, 16));
  poly('c4', (ell($x, $y, $r, $r * 0.98, 16))[1 .. 7], map { [$x + ($_->[0] - $x) * 0.8 - 1, $y + ($_->[1] - $y) * 0.8 - 1] } reverse((ell($x, $y, $r, $r * 0.98, 16))[1 .. 7]));
  my @f = ell($x - $r * 0.02, $y - $r * 0.04, $r * 0.82, $r * 0.8, 16);
  poly('c3', @f);
  # seed: a flat tan oval in the middle with a lit edge
  poly('c4', ell($x + $r * 0.06, $y + $r * 0.04, $r * 0.36, $r * 0.26, 10, -25));
  poly("c3", ell($x - $r * 0.06, $y - $r * 0.04, $r * 0.1, $r * 0.05, 6, -25));
}

# Jabuticaba seed: small flat oval, pale tan with a darker half.
sub jseed {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o = map { my $th = 2 * pi * $_ / 16; my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 - 0.12 * cos($th)); [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v] } 0 .. 15;
  poly('c3', @o);
  my $leftLit = lit($nx, $ny);
  my @half = $leftLit ? @o[9 .. 15] : @o[1 .. 7];
  poly('c4', @half, map { [$x + ($_->[0] - $x) * 0.45, $y + ($_->[1] - $y) * 0.45] } reverse @half);
}

# White powder-puff flower sitting right on the bark: a ring of fine stamens round a small cream heart.
sub puff {
  my ($x, $y, $r, $rot) = @_;
  for my $k (0 .. 11) {
    my $a = $rot + $k * 30; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    poly(lit($dx, $dy) || $k % 2 ? 'c3' : 'c2', [$x + $nx * $r * 0.18, $y + $ny * $r * 0.18], [$x + $dx * $r, $y + $dy * $r], [$x - $nx * $r * 0.18, $y - $ny * $r * 0.18]);
  }
  poly('c3', ell($x, $y, $r * 0.42, $r * 0.42, 8));
  poly('c2', ell($x + $r * 0.06, $y + $r * 0.06, $r * 0.16, $r * 0.16, 6));
}

# A cluster of small paired leaves on a short twig (seen from above).
sub twig {
  my ($x, $y, $ang, $len, $ll, $L, $D, %o) = @_;
  blade($x, $y, $ang, $len, 2.6, 0, $o{tl} // 'c2', $o{td} // 'c1');
  my @lv;
  for my $k (1 .. ($o{pairs} // 3)) {
    my $t = $k / (($o{pairs} // 3) + 0.4);
    my ($px, $py, $pa) = walk($x, $y, $ang, $len, 0, $t);
    for my $s (-1, 1) { push @lv, [$px, $py, $pa + $s * (48 + ($o{spread} // 0)), $ll * (1.05 - 0.1 * $k), $ll * 0.42 * ($o{wk} // 1), $s * ($o{curl} // 8)]; }
  }
  my ($ex, $ey, $ea) = walk($x, $y, $ang, $len, 0, 1);
  push @lv, [$ex, $ey, $ea, $ll * 0.95, $ll * 0.42 * ($o{wk} // 1), 0];
  oleaf(@$_, $L, $D, pf => 0.08, rib => 0.9, %{$o{lo} // {}}) for @lv;
}

# Multi-stemmed jabuticaba frame seen from above: pale smooth trunks forking out of the crown.
# Returns segments [x, y, ang, len, bend, w] for hanging berries, flowers and leaves on.
sub frame {
  my (%o) = @_;
  srand($o{seed});
  my @seg; my $n = $o{n};
  for my $i (0 .. $n - 1) {
    my $a = ($o{start} // -90) + $i * 360 / $n + rand(16) - 8;
    my $L1 = $o{len} * (0.5 + rand(0.1)); my $b1 = (rand(1) < 0.5 ? -1 : 1) * (8 + rand(10));
    push @seg, [200, 200, $a, $L1, $b1, $o{w}];
    my ($ex, $ey, $ea) = walk(200, 200, $a, $L1, $b1, 1);
    for my $f (-1, 1) {
      next if $o{single} && $f == 1;
      my $L2 = $o{len} * (0.5 + rand(0.12)); my $a2 = $ea + $f * (20 + rand(10)) * ($o{single} ? 0 : 1);
      push @seg, [$ex, $ey, $a2, $L2, -$f * (6 + rand(10)), $o{w} * 0.66];
    }
  }
  my ($cl, $cd) = ($o{light} // 'c3', $o{dark} // 'c4');
  for my $s (@seg) { my ($x, $y, $a, $l, $b, $w) = @$s; blade($x, $y, $a, $l, $w, $b, $cl, $cd, 0.45); }
  # mottled bark: paler and darker flecks along the lit side
  srand($o{seed} + 1);
  for my $s (@seg) {
    my ($x, $y, $a, $l, $b, $w) = @$s;
    for my $t (0.25, 0.6, 0.85) {
      my ($px, $py, $pa) = walk($x, $y, $a, $l, $b, $t); my ($dx, $dy) = dir($pa);
      my $hw = $w / 2 * (1 - 0.45 * $t) ** 0.85;
      my $side = lit(-$dy, $dx) ? 1 : -1;
      my ($fx, $fy) = ($px - $dy * $hw * 0.45 * $side, $py + $dx * $hw * 0.45 * $side);
      poly($o{fleck} // 'c4', [$fx - $dx * $hw * 0.7, $fy - $dy * $hw * 0.7], [$fx - $dy * $hw * 0.18, $fy + $dx * $hw * 0.18], [$fx + $dx * $hw * 0.5, $fy + $dy * $hw * 0.5], [$fx + $dy * $hw * 0.2, $fy - $dx * $hw * 0.2]) if rand(1) < 0.55;
    }
  }
  @seg;
}

# Berries packed along a segment from t0 to t1, on both flanks and on top of the bark.
sub load {
  my ($seg, $t0, $t1, $r, $dens, $out, %o) = @_;
  my ($x, $y, $a, $l, $b, $w) = @$seg;
  my $steps = int(($t1 - $t0) * $l / ($r * 1.5 / $dens)) + 1;
  for my $k (0 .. $steps) {
    my $t = $t0 + ($t1 - $t0) * $k / $steps;
    my ($px, $py, $pa) = walk($x, $y, $a, $l, $b, $t); my ($dx, $dy) = dir($pa);
    my $hw = $w / 2 * (1 - 0.45 * $t) ** 0.85;
    for my $s (-1, 1) {
      next if rand(1) < ($o{skip} // 0.1);
      my $off = $hw + $r * (0.35 + rand(0.4));
      my $rr = $r * (0.85 + rand(0.3));
      my $sh = rand($r * 0.8) - $r * 0.4;
      push @$out, [$px - $dy * $off * $s + $dx * $sh, $py + $dx * $off * $s + $dy * $sh, $rr];
    }
    push @$out, [$px + $dx * $r * 0.4, $py + $dy * $r * 0.4, $r * 0.9] if rand(1) < ($o{top} // 0.35);
  }
}

# A ring of leafy twigs under the frame so the bush has a full leafy silhouette (from above).
sub canopy {
  my ($seed, $n, $r0, $r1, $tl, $ll, %o) = @_;
  srand($seed);
  my @t;
  for my $i (0 .. $n - 1) {
    my $a = ($o{start} // 0) + $i * 360 / $n + rand(14) - 7; my $r = $r0 + rand($r1 - $r0);
    my ($dx, $dy) = dir($a);
    push @t, [200 + $dx * $r, 200 + $dy * $r, $a + rand(30) - 15];
  }
  twig(@$_, $tl, $ll, $o{light} // "c2", $o{dark} // "c1", pairs => $o{pairs} // 2, wk => 1.25, %o) for @t;
}

# ---------------------------------------------------------------------------------------------
# 1. Planting material, front view: small flat seeds in front of two glossy berries.
berry(168, 176, 62); berry(262, 196, 54);
jseed(130, 290, -24, 62, 40); jseed(196, 306, 6, 64, 42); jseed(268, 292, 30, 60, 40); jseed(212, 256, -60, 56, 37);
write_svg('1-seeds-front.svg', 'Jabuticaba seeds');

# 2. Just sown, top down: little flat seeds pressed into soil pockets.
my @sown = ([166, 168, -30], [240, 164, 40], [202, 214, 95], [150, 240, 150], [252, 238, -60]);
for (@sown) { soil($_->[0], $_->[1], 28, 23, int($_->[0] * 7 + $_->[1])); }
for (@sown) { jseed($_->[0], $_->[1], $_->[2], 30, 20); }
write_svg('2-sown.svg', 'Jabuticaba just sown');

# 3. First growth, top down: a slender seedling with pairs of small pointed leaves.
soil(200, 200, 34, 30, 3);
twig(200, 200, -70, 52, 40, 'c2', 'c1', pairs => 2);
twig(200, 200, 110, 46, 38, 'c2', 'c1', pairs => 2);
twig(200, 200, 15, 22, 32, 'c2', 'c1', pairs => 1);
write_svg('3-first-growth.svg', 'Jabuticaba first growth');

# 4. Second growth, top down: a few thin pale stems with clusters of small glossy leaves.
soil(200, 200, 34, 30, 4);
{
  canopy(42, 7, 46, 70, 22, 32, start => -40, pairs => 2);
  my @seg = frame(seed => 41, n => 4, len => 74, w => 8, start => -60);
  for my $s (@seg) {
    my ($x, $y, $a, $l, $b) = @$s; next if $x == 200 && $y == 200;
    my ($ex, $ey, $ea) = walk($x, $y, $a, $l, $b, 1);
    twig($ex - cos(deg2rad($ea)) * 6, $ey - sin(deg2rad($ea)) * 6, $ea, 26, 32, 'c2', 'c1', pairs => 2);
  }
}
write_svg('4-second-growth.svg', 'Jabuticaba second growth');

# 5. Third growth, top down: white powder-puff flowers bursting straight out of the trunk and branches.
soil(200, 200, 34, 30, 5);
{
  canopy(53, 10, 70, 98, 26, 40, start => -70);
  canopy(54, 5, 40, 60, 26, 36, start => -48);
  my @seg = frame(seed => 51, n => 5, len => 94, w => 13, start => -84);
  for my $s (@seg) {
    my ($x, $y, $a, $l, $b) = @$s; next if $x == 200 && $y == 200;
    my ($ex, $ey, $ea) = walk($x, $y, $a, $l, $b, 1);
    twig($ex - cos(deg2rad($ea)) * 8, $ey - sin(deg2rad($ea)) * 8, $ea, 28, 34, 'c2', 'c1', pairs => 2);
  }
  srand(52);
  my @p; load($_, 0.12, 0.85, 7, 0.6, \@p, skip => 0.3, top => 0.25) for @seg;
  puff($_->[0], $_->[1], $_->[2] * 1.2, rand(30)) for sort { $a->[1] <=> $b->[1] } @p;
}
write_svg('5-third-growth.svg', 'Jabuticaba third growth, flowering on the trunk');

# 6. Harvest, top down: trunk and branches packed with glossy black-purple berries, leaf tufts all round.
soil(200, 200, 34, 30, 6);
{
  canopy(64, 12, 92, 120, 28, 42, start => -70);
  canopy(65, 5, 50, 70, 30, 40, start => -42);
  canopy(66, 5, 20, 34, 30, 38, start => -60);
  my @seg = frame(seed => 61, n => 5, len => 108, w => 15, start => -78);
  for my $s (@seg) {
    my ($x, $y, $a, $l, $b) = @$s; next if $x == 200 && $y == 200;
    my ($ex, $ey, $ea) = walk($x, $y, $a, $l, $b, 1);
    twig($ex - cos(deg2rad($ea)) * 10, $ey - sin(deg2rad($ea)) * 10, $ea, 30, 36, 'c2', 'c1', pairs => 2);
  }
  srand(63);
  my @p; load($_, 0.06, 0.9, 8.5, 1, \@p, skip => 0.08, top => 0.12) for @seg;
  berry(@$_) for sort { $a->[1] <=> $b->[1] } @p;
}
write_svg('6-harvest.svg', 'Jabuticaba ready to harvest');

# 7. Harvested produce, front view: a small heap of glossy berries, one split open to show the white flesh.
{
  my @h;
  for my $row ([300, 5, 0], [258, 4, 0], [218, 3, 0], [184, 2, 0]) {
    my ($y, $c) = @$row;
    for my $k (0 .. $c - 1) { push @h, [200 + ($k - ($c - 1) / 2) * 64 + (($k * 37 + $y) % 11) - 5, $y + (($k * 53) % 9) - 4, 32 + (($k + $y) % 5)]; }
  }
  my @front = grep { $_->[1] > 280 } @h; my @back = grep { $_->[1] <= 280 } @h;
  berry(@$_) for sort { $a->[1] <=> $b->[1] } @back;
  berry(@$_) for grep { $_->[0] < 240 } @front;
  split_berry(272, 316, 46);
}
write_svg('7-harvest-front.svg', 'Harvested jabuticabas');

# 8. Dead (never watered), top down: cracked dry soil, bare grey-pale stems, curled dry leaves, a few shrivelled berries.
soil(200, 200, 70, 60, 8);
cracks(8, 83, 15, 'c3');
{
  my @seg = frame(seed => 81, n => 4, len => 118, w => 11, start => -60, light => 'c3', dark => 'c4');
  srand(85);
  for my $s (@seg) {
    my ($x, $y, $a, $l, $b) = @$s;
    next if $x == 200 && $y == 200;
    my ($ex, $ey, $ea) = walk($x, $y, $a, $l, $b, 0.9);
    twig($ex, $ey, $ea + rand(40) - 20, 26, 26, 'c3', 'c4', pairs => 2, tl => 'c3', td => 'c4', curl => 50, wk => 0.75, lo => { noglint => 1 });
  }
  my @p; load($_, 0.3, 0.7, 5.5, 0.4, \@p, skip => 0.6, top => 0) for @seg[0 .. 3];
  berry(@$_, body => 'c4', matte => 1) for @p;
}
write_svg('8-dead.svg', 'Jabuticaba died from lack of water');
print "wrote 8 files to $OUT\n";

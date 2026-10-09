# Pink guava crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/pink-guava.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Signatures: opposite oval leaves with deeply impressed parallel veins, mottled peeling bark, white pompom
# flowers, pale yellow-green pear-round fruit with a dark crown at the blossom end, bright pink flesh inside.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/pink-guava';
mkdir 'crops'; mkdir $OUT;
# c1 leaf green, c2 lit yellow-green (leaf light, fruit skin shade), c3 pale cream-lime (fruit light, flowers, seeds,
# dried leaves), c4 dark soil / bark brown, c5 guava pink (flesh)
my %PAL = (c1 => '#3E7A37', c2 => '#A9CB52', c3 => '#F3F0C4', c4 => '#5A3826', c5 => '#F2617F');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub ring { my ($x, $y, $rx, $ry, $n, $rot) = @_; $rot //= 0; map { my ($u, $v) = dir($rot + $_ * 360 / $n); [$x + $u * $rx, $y + $v * $ry] } 0 .. $n - 1 }

# A tapered blade / twig from (x,y) heading `ang`, bending `bend` degrees. Returns the end point and heading.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $tipw) = @_; $tipw //= 0;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $t * (1 - $tipw)) ** 0.85 + 0.5;
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    last if $i == $n;
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
  return ($px, $py, $a);
}

# Point and heading at fraction t along a bent path (same stepping as blade).
sub along {
  my ($x, $y, $ang, $len, $bend, $t) = @_;
  for (1 .. int($t * 10 + 0.5)) { my ($dx, $dy) = dir($ang); $x += $dx * $len / 10; $y += $dy * $len / 10; $ang += $bend / 10; }
  return ($x, $y, $ang);
}

# A woody guava branch: a tapering twig with lit/shaded halves and pale peeling-bark flecks.
sub branch {
  my ($x, $y, $ang, $len, $w, $bend, %o) = @_;
  my ($ex, $ey, $ea) = blade($x, $y, $ang, $len, $w, $bend, $o{light} // 'c3', $o{dark} // 'c4', 0.35);
  return ($ex, $ey, $ea) if $o{plain};
  for my $k (1 .. int($len / 26)) {                  # mottled peeling patches
    my $t = ($k - 0.4) / ($len / 26);
    my ($px, $py, $pa) = along($x, $y, $ang, $len, $bend, $t);
    my ($dx, $dy) = dir($pa); my ($nx, $ny) = (-$dy, $dx); my $hw = $w / 2 * (1 - 0.65 * $t);
    my $s = $k % 2 ? 1 : -1;
    poly($k % 3 ? 'c4' : ($o{patch} // 'c2'), [$px + $nx * $s * $hw * 0.1, $py + $ny * $s * $hw * 0.1], [$px + $dx * 6 + $nx * $s * $hw * 0.8, $py + $dy * 6 + $ny * $s * $hw * 0.8],
         [$px + $dx * 11 + $nx * $s * $hw * 0.2, $py + $dy * 11 + $ny * $s * $hw * 0.2]);
  }
  return ($ex, $ey, $ea);
}

# Guava leaf: oblong oval with a blunt tip, split along the midrib, with deeply impressed parallel lateral veins.
sub gleaf {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, %o) = @_;
  my $N = 14; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  my $curl = $o{curl} // 0;                          # >0 = one edge rolled in (dry leaves)
  for my $i (0 .. $N) {
    my $t = $i / $N; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (sin(pi * min(0.999, 0.04 + 0.96 * $t ** 0.92))) ** 0.62;
    $hw = $w / 2 * 0.1 if $i == $N;
    my $wl = $hw * (1 - $curl * 0.6); my $wr = $hw;
    push @l, [$px - $dy * $wl, $py + $dx * $wl]; push @r, [$px + $dy * $wr, $py - $dx * $wr];
    push @mid, [$px, $py, $dx, $dy, $hw];
    last if $i == $N;
    $px += $dx * $len / $N; $py += $dy * $len / $N; $a += $bend / $N;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  my @m2 = map { [$_->[0], $_->[1]] } @mid;
  poly($leftLit ? $light : $dark, @l, reverse @m2);
  poly($leftLit ? $dark : $light, @r, reverse @m2);
  my $nv = $o{veins} // 7; return unless $nv;
  my $vw = $o{vw} // max(0.8, $len * 0.02);
  for my $k (1 .. $nv) {
    my $i = int(0.5 + $N * (0.1 + 0.8 * $k / ($nv + 1)));
    my ($mx, $my, $vx, $vy, $hw) = @{$mid[$i]};
    my $j = min($N - 1, $i + 2);                     # the vein runs forward to the edge two steps on
    my ($jx, $jy, $ux, $uy, $hj) = @{$mid[$j]};
    for my $side (1, -1) {                           # side 1 = the "l" side (normal (-dy, dx))
      my ($sx, $sy) = (-$uy * $side, $ux * $side);
      my $sideLit = ($side == 1) == ($leftLit ? 1 : 0);
      my $L = $hj * ($side == 1 ? (1 - $curl * 0.6) : 1) * 0.84;
      my @e = ($jx + $sx * $L, $jy + $sy * $L);
      poly($sideLit ? $dark : $light, [$mx + $vx * $vw * 1.4, $my + $vy * $vw * 1.4], [$e[0] + $ux * $vw * 0.5, $e[1] + $uy * $vw * 0.5],
           [$e[0] - $ux * $vw * 0.5, $e[1] - $uy * $vw * 0.5], [$mx - $vx * $vw * 0.9, $my - $vy * $vw * 0.9]);
    }
  }
}

# Guava fruit seen side-on from stalk end (x,y) toward `ang`: pear-round body, lit cream-lime face, yellow-green shade,
# a dark crown at the blossom end. Optional pink blush.
sub guava {
  my ($x, $y, $ang, $L, $W, %o) = @_;
  my $body = $o{body} // 'c2'; my $light = $o{light} // 'c3'; my $crown = $o{crown} // 'c4';
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $pear = $o{pear} // 0.25;
  # profile: narrow neck at the stalk, round full body, slightly flattened blossom end
  my $f = sub { my $t = shift; my $u = 2 * $t - 1; my $e = 1 - $u * $u; $e = 0 if $e < 0;
    ($e ** 0.5) * (1 + $pear * $u * 0.9) * (1 - $pear * 0.35 * (1 - $t) ** 6) / (1 + $pear * 0.5) };
  my $N = 20; my (@l, @r);
  for my $i (0 .. $N) {
    my $t = $i / $N; my $hw = $W / 2 * $f->($t);
    my ($cx, $cy) = ($x + $dx * $L * $t, $y + $dy * $L * $t);
    push @l, [$cx + $nx * $hw, $cy + $ny * $hw]; push @r, [$cx - $nx * $hw, $cy - $ny * $hw];
  }
  poly($body, @l, reverse @r);
  my $leftLit = lit($nx, $ny); my $s = $leftLit ? 1 : -1;
  my $P = sub { my ($t, $k) = @_; my $hw = $W / 2 * $f->($t) * $k; [$x + $dx * $L * $t + $nx * $s * $hw, $y + $dy * $L * $t + $ny * $s * $hw] };
  # lit face: hugs the outline toward the upper-left light and recedes on the far side with a curved terminator
  my ($gx, $gy) = ($x + $dx * $L * 0.52, $y + $dy * $L * 0.52);
  my @face = map { my ($ox, $oy) = ($_->[0] - $gx, $_->[1] - $gy); my $d = sqrt($ox * $ox + $oy * $oy) || 1;
    my $dot = ($ox * -0.7071 + $oy * -0.7071) / $d; my $k = $dot > 0.25 ? 0.93 : max(0.3, 0.93 - 0.55 * (0.25 - $dot));
    [$gx + $ox * $k, $gy + $oy * $k] } (@l, reverse @r);
  poly($light, @face);
  # a soft pink blush low on the cheek, straddling the lit face and the shade
  if ($o{blush}) { poly($o{blush}, map { my $a = 2 * pi * $_ / 12; [$gx + $W * 0.06 + cos($a) * $W * 0.2, $gy + $W * 0.2 + sin($a) * $W * 0.12] } 0 .. 11); }
  # thin dark rim on the side away from the light so the fruit stands off the foliage
  unless ($o{norim}) {
    my @all = (@l, reverse @r); my $n = @all;
    my %on; for my $i (0 .. $n - 1) { my ($ox, $oy) = ($all[$i][0] - $gx, $all[$i][1] - $gy); my $d = sqrt($ox * $ox + $oy * $oy) || 1;
      $on{$i} = 1 if ($ox * 0.7071 + $oy * 0.7071) / $d > 0.3; }
    my ($st) = grep { $on{$_} && !$on{($_ - 1) % $n} } 0 .. $n - 1;
    if (defined $st) {
      my @arc; for my $j (0 .. $n - 1) { my $i = ($st + $j) % $n; last unless $on{$i}; push @arc, $all[$i]; }
      my $m = $#arc || 1;
      poly($o{rim} // 'c1', @arc, reverse map { my $k = 1 - 0.12 * sin(pi * $_ / $m); [$gx + ($arc[$_][0] - $gx) * $k, $gy + ($arc[$_][1] - $gy) * $k] } 0 .. $#arc);
    }
  }
  # small gloss facet
  poly($o{gloss} // $light, $P->(0.3, 0.55), $P->(0.42, 0.8), $P->(0.55, 0.6), $P->(0.42, 0.42)) if $o{gloss};
  # blossom-end crown: a little dark star of dried sepals
  unless ($o{nocrown}) {
    my $cr = $W * 0.13 * ($o{cs} // 1); my ($cx, $cy) = ($x + $dx * ($L - $cr * 0.35), $y + $dy * ($L - $cr * 0.35));
    my @st; for my $k (0 .. 9) { my ($u, $v) = dir($ang + $k * 36); my $rr = $k % 2 ? $cr * 0.45 : $cr; push @st, [$cx + $u * $rr, $cy + $v * $rr * 0.8]; }
    poly($crown, @st);
  }
  # stalk stub at the neck
  blade($x + $dx * 2, $y + $dy * 2, $ang + 180, $o{stalk} // $W * 0.16, $W * 0.09, 0, 'c3', 'c4', 0.7) unless $o{nostalk};
}

# White guava pompom flower from above: four cupped petals and a burst of fine stamens with pale tips.
sub pompom {
  my ($x, $y, $r, $rot, %o) = @_;
  for my $i (0 .. 4) {                               # cupped petals; the side away from the light in leaf green
    my $a = $rot + $i * 72; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    my @q = map { [$x + ($dx * $_->[0] + $nx * $_->[1]) * $r, $y + ($dy * $_->[0] + $ny * $_->[1]) * $r] }
      ([0.2, 0], [0.45, 0.4], [0.76, 0.34], [0.88, 0.0], [0.76, -0.34], [0.45, -0.4]);
    poly('c3', @q);
    poly('c2', @q[2, 3, 4], [$x + $dx * $r * 0.7, $y + $dy * $r * 0.7]) unless lit($dx, $dy);
  }
  poly('c2', ring($x, $y, $r * 0.66, $r * 0.66, 14));
  for my $k (0 .. 39) {                              # stamens: fine needles radiating past the petals' base
    my $a = $rot + $k * 9 + ($k % 2 ? 4 : 0); my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    my $len = $r * ($k % 3 == 0 ? 1.16 : ($k % 3 == 1 ? 0.98 : 0.8));
    my ($bx, $by) = ($x + $dx * $r * 0.12, $y + $dy * $r * 0.12);
    poly('c3', [$bx + $nx * 0.8, $by + $ny * 0.8], [$x + $dx * $len, $y + $dy * $len], [$bx - $nx * 0.8, $by - $ny * 0.8]);
    my ($tx, $ty) = ($x + $dx * $len, $y + $dy * $len); my $tr = max(1.2, $r * 0.06);
    poly($o{tip} // 'c3', [$tx - $tr, $ty], [$tx, $ty - $tr], [$tx + $tr, $ty], [$tx, $ty + $tr]);
  }
  poly('c1', ring($x, $y, $r * 0.14, $r * 0.14, 6));  # style / ovary at the very centre
}

# A guava seed: small hard kidney with a lit cream half, a pinkish shaded half and a dark hilum.
sub gseed {
  my ($x, $y, $ang, $len, $w, %o) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 15) {
    my $th = 2 * pi * $i / 16; my $u = cos($th) * $len / 2 * (1 + 0.08 * sin($th)); my $v = sin($th) * $w / 2 * (1 + 0.12 * cos($th));
    $v += $w * 0.12 * (1 - abs(cos($th))) if sin($th) < 0;   # kidney dent on one side
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly($o{light} // 'c3', @o);
  # shaded crescent on the side away from the light: outline arc plus the same arc pulled in toward the lit side
  my @sh = grep { my ($ox, $oy) = ($o[$_][0] - $x, $o[$_][1] - $y); ($ox + $oy) > 0 } 0 .. 15;
  my %on = map { $_ => 1 } @sh; my ($st) = grep { !$on{($_ + 15) % 16} } @sh; $st //= 0;
  my @arc; for my $j (0 .. 15) { my $i = ($st + $j) % 16; last unless $on{$i}; push @arc, $o[$i]; }
  my $k = $o{ck} // 0.72; my $off = min($len, $w) * 0.06;
  poly($o{dark} // 'c4', @arc, map { [$x + ($_->[0] - $x) * $k - $off, $y + ($_->[1] - $y) * $k - $off] } reverse @arc) if @arc > 2;
  poly($o{hilum} // 'c4', map { my ($u, $v) = dir($ang + $_ * 90); [$x - $dx * $len * 0.42 + $u * $len * 0.06, $y - $dy * $len * 0.42 + $v * $len * 0.06] } 0 .. 3) unless $o{nohilum};
}

# Small irregular patch of soil.
sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o;
  srand($seed);
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12; my $k = 0.82 + rand(0.3); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
}

sub write_svg {
  my ($file, $label) = @_;
  open my $fh, '>', "$OUT/$file" or die $!;
  print $fh qq{<?xml version="1.0" encoding="UTF-8"?>\n<svg viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="$label">\n  <style>\n};
  print $fh "    .$_ { fill: var(--$_, $PAL{$_}); }\n" for qw(c1 c2 c3 c4 c5);
  print $fh "  </style>\n  <g transform=\"translate(0 0)\">\n", join("\n", @S), "\n  </g>\n</svg>\n";
  close $fh; @S = ();
}

# Mottled trunk seen from above: a dark disc with pale and green-grey peeling patches.
sub trunk {
  my ($r, $pc) = @_;
  poly('c4', ring(200, 200, $r, $r * 0.92, 10, 8));
  poly('c3', [200 - $r * 0.7, 200 - $r * 0.2], [200 - $r * 0.25, 200 - $r * 0.75], [200 + $r * 0.05, 200 - $r * 0.35], [200 - $r * 0.35, 200 + $r * 0.05]);
  poly($pc // 'c2', [200 + $r * 0.1, 200 + $r * 0.15], [200 + $r * 0.55, 200 - $r * 0.05], [200 + $r * 0.4, 200 + $r * 0.5]);
}

# Top-down guava bush: branches radiate from the trunk; leaves in opposite pairs along them, plus a terminal pair.
# Returns the branch list ([x, y, heading] at the tips and mid points) for flowers and fruit.
my @TIPS;
sub bush {
  my (%o) = @_;
  srand($o{seed});
  my $n = $o{n}; my @br; my @leaves; @TIPS = ();
  for my $i (0 .. $n - 1) {
    my $a = $o{start} + $i * 360 / $n + rand(16) - 8;
    my $len = $o{blen} * (0.86 + rand(0.28)); my $bend = (rand(1) < 0.5 ? -1 : 1) * (8 + rand(14));
    push @br, [$a, $len, $bend];
    my $pairs = $o{pairs};
    for my $k (1 .. $pairs) {
      my $t = 0.3 + 0.7 * $k / $pairs;
      my ($px, $py, $pa) = along(200, 200, $a, $len, $bend, $t);
      my $ll = $o{llen} * (0.72 + 0.3 * $t) * (0.92 + rand(0.16));
      my $spread = $k == $pairs ? 24 : 58 + rand(14);
      push @leaves, [$px, $py, $pa - $spread + rand(8), $ll, -10 + rand(6)];
      push @leaves, [$px, $py, $pa + $spread - rand(8), $ll, 10 - rand(6)];
      push @TIPS, [$px, $py, $pa, $t];
    }
  }
  trunk($o{trunk}, ($o{light} // '') eq 'c3' ? 'c3' : 'c2') if $o{trunk};
  branch(200, 200, $_->[0], $_->[1], $o{bw}, $_->[2], patch => ($o{light} // '') eq 'c3' ? 'c3' : 'c2') for @br;
  my $w = $o{wk} // 0.5;
  for (sort { (($b->[0] - 200) ** 2 + ($b->[1] - 200) ** 2) <=> (($a->[0] - 200) ** 2 + ($a->[1] - 200) ** 2) } @leaves) {
    my ($px, $py, $pa, $ll, $bd) = @$_;
    my ($sx, $sy) = blade($px, $py, $pa, $ll * 0.1, 3, 0, $o{light} // 'c2', $o{dark} // 'c1');
    gleaf($sx, $sy, $pa, $ll, $ll * $w, $bd, $o{light} // 'c2', $o{dark} // 'c1', veins => $o{veins} // 7, curl => $o{curl} // 0);
  }
}

# Crack lines in dry soil.
sub cracks {
  my ($n, $seed, $step) = @_; srand($seed);
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

# 1. Planting material, front view: a rooted guava cutting - a mottled woody stem, two pairs of veined leaves, fresh roots.
{
  my ($bx, $by) = (196, 300);                          # stem base
  for my $r ([96, 52, 18], [76, 60, -14], [116, 56, 16], [62, 40, -26], [130, 40, 24], [90, 34, -30], [104, 30, 30]) {   # roots
    blade($bx + ($r->[0] - 96) * 0.1, $by - 4, $r->[0], $r->[1], 4.4, $r->[2], 'c3', 'c4');
  }
  my ($tx, $ty) = branch($bx, $by, -88, 168, 15, -6);  # the woody cutting, cut square at the top
  poly('c3', [$tx - 6, $ty + 1], [$tx + 1, $ty - 4], [$tx + 6, $ty], [$tx - 1, $ty + 4]);
  for my $p ([0.52, 56, 64, 6], [0.86, 40, 74, 8]) { # opposite leaf pairs (lower pair larger)
    my ($t, $sp, $len, $bd) = @$p;
    my ($px, $py, $pa) = along($bx, $by, -88, 168, -6, $t);
    for my $s (-1, 1) {
      my ($sx, $sy) = blade($px, $py, $pa + $s * $sp, 9, 3.6, 0, 'c2', 'c1');
      gleaf($sx, $sy, $pa + $s * ($sp + 14), $len, $len * 0.5, $s * $bd, 'c2', 'c1', veins => 7);
    }
  }
  # a tiny bud between the top leaves
  blade($tx, $ty + 6, -90, 14, 5, 0, 'c2', 'c1');
}
write_svg('1-seeds-front.svg', 'Pink guava rooted cutting');

# 2. Just sown, top down: rooted cuttings set into small soil pockets.
my @sown = ([166, 168, -20], [238, 164, 30], [202, 214, 100], [150, 240, 160], [252, 238, -60]);
for (@sown) { soil($_->[0], $_->[1], 28, 23, int($_->[0] * 7 + $_->[1])); }
for (@sown) {                                         # cuttings pushed into the pockets: a woody stub and one tiny leaf pair
  my ($x, $y, $a) = @$_;
  for my $s (-1, 1) { gleaf($x, $y, $a + $s * 90, 20, 11, 0, 'c2', 'c1', veins => 3, vw => 0.8); }
  poly('c4', ring($x, $y, 4.5, 4.5, 6)); poly('c3', ring($x - 1, $y - 1, 2.6, 2.6, 6));
}
write_svg('2-sown.svg', 'Pink guava just planted');

# 3. First growth: a seedling with crossed pairs of oval veined leaves.
soil(200, 200, 34, 30, 3);
{
  my @l = ([-118, 62, 8], [62, 62, -8], [-28, 70, -6], [152, 70, 6], [-74, 40, 4], [106, 40, -4]);
  for (@l) { my ($sx, $sy) = blade(200, 200, $_->[0], 8, 3.6, 0, 'c2', 'c1'); gleaf($sx, $sy, $_->[0], $_->[1], $_->[1] * 0.52, $_->[2], 'c2', 'c1', veins => 5); }
  poly('c4', ring(200, 200, 5, 5, 6)); poly('c2', ring(199, 199, 2.6, 2.6, 6));
}
write_svg('3-first-growth.svg', 'Pink guava first growth');

# 4. Second growth: a young bush with woody branches and veined oval leaves in pairs.
soil(200, 200, 36, 32, 4);
bush(seed => 41, n => 5, start => -70, blen => 72, pairs => 2, llen => 58, bw => 7, trunk => 10, veins => 6);
write_svg('4-second-growth.svg', 'Pink guava second growth');

# 5. Third growth: a full bush in flower, white pompoms and small green fruit.
soil(200, 200, 36, 32, 5);
bush(seed => 51, n => 7, start => -80, blen => 96, pairs => 3, llen => 62, bw => 9, trunk => 13, veins => 7);
{
  my $i = 0;
  for my $p (grep { $_->[3] > 0.9 } @TIPS) {
    my ($dx, $dy) = dir($p->[2]);
    if ($i % 3 == 2) { guava($p->[0] - $dx * 2, $p->[1] - $dy * 2, $p->[2] + 20, 30, 27, body => 'c1', light => 'c2', rim => 'c1', crown => 'c4', pear => 0.2, stalk => 6); }
    else { pompom($p->[0] + $dx * 10, $p->[1] + $dy * 10, 27, $i * 23); }
    $i++;
  }
}
write_svg('5-third-growth.svg', 'Pink guava flowering');

# 6. Harvest: a lush bush hung with big ripe guavas.
soil(200, 200, 36, 32, 6);
bush(seed => 61, n => 8, start => -76, blen => 106, pairs => 4, llen => 62, bw => 10, trunk => 14, veins => 7);
{
  my $i = 0;
  for my $p (grep { $_->[3] > 0.9 } @TIPS) {
    my ($dx, $dy) = dir($p->[2]);
    guava($p->[0] - $dx * 14, $p->[1] - $dy * 14, $p->[2] + ($i % 2 ? 12 : -12), 60, 57, stalk => 8, pear => 0.16);
    $i++;
  }
}
write_svg('6-harvest.svg', 'Pink guava ready to harvest');

# 7. Harvested produce, front view: one whole guava and one halved guava showing pink flesh and a ring of seeds.
{
  my ($sx, $sy) = (138, 96);
  my ($lx, $ly) = blade($sx, $sy, -100, 26, 7, 14, 'c3', 'c4', 0.7);                 # stalk
  my ($px, $py) = blade($sx - 2, $sy - 18, -160, 10, 4, 0, 'c2', 'c1');
  gleaf($px, $py, -168, 70, 34, -14, 'c2', 'c1', veins => 6);                        # one leaf on the stalk
  guava($sx, $sy, 92, 168, 156, pear => 0.14, stalk => 4);
}
{
  my ($cx, $cy, $rx, $ry) = (264, 236, 84, 90);
  my $E = sub { my ($k, $ox, $oy) = @_; map { my $th = 2 * pi * $_ / 32; my $p = 1 + 0.1 * sin($th);
    [$cx + $ox + cos($th) * $rx * $p * $k, $cy + $oy + sin($th) * $ry * $k] } 0 .. 31 };
  poly('c1', $E->(1.04, 7, 6));          # the skin seen past the cut edge, on the shaded lower right
  poly('c2', $E->(1.04, 2, 2));          # skin rim
  poly('c3', $E->(0.97, 0, 0));          # thin pale rind
  poly('c5', $E->(0.9, 0, 0));           # pink flesh
  poly('c3', [$cx - $rx * 0.62, $cy - $ry * 0.42], [$cx - $rx * 0.42, $cy - $ry * 0.7], [$cx - $rx * 0.3, $cy - $ry * 0.66], [$cx - $rx * 0.5, $cy - $ry * 0.4]);  # gloss on the cut face
  for my $ring ([0.5, 15, 0.0, 12, 9], [0.33, 10, 0.3, 10, 7.5]) {
    my ($rr, $n, $ph, $sl, $sw) = @$ring;
    for my $i (0 .. $n - 1) {
      my $th = 2 * pi * ($i + $ph) / $n;
      gseed($cx + cos($th) * $rx * $rr, $cy + sin($th) * $ry * $rr, rad2deg($th), $sl, $sw, light => 'c3', dark => 'c3', nohilum => 1);
    }
  }
}
write_svg('7-harvest-front.svg', 'Pink guava harvest');

# 8. Dead (never watered): cracked dry soil, a bare twiggy bush with dry curled leaves fallen flat.
soil(200, 200, 58, 50, 8);
cracks(7, 83, 13);
bush(seed => 81, n => 6, start => -60, blen => 84, pairs => 2, llen => 52, bw => 7, trunk => 11, veins => 5, light => 'c3', dark => 'c4', curl => 0.7, wk => 0.4, veins => 3);
guava(200 + 66, 200 + 52, 40, 24, 19, body => 'c4', light => 'c4', crown => 'c3', nostalk => 1, norim => 1, pear => 0.4);
guava(200 - 82, 200 - 24, 200, 22, 17, body => 'c4', light => 'c4', crown => 'c3', nostalk => 1, norim => 1, pear => 0.4);
write_svg('8-dead.svg', 'Pink guava died from lack of water');
print "wrote 8 files to $OUT\n";

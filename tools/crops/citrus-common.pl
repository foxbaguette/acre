# Shared helpers for the citrus-bush crops (lemon, lime, finger-lime, buddhas-hand, orange, mandarin).
# Loaded by each crop's generator:  our ($OUT, %PAL); do './tools/crops/citrus-common.pl' or die;
# Same helper style as wheat.pl (blade, soil, write_svg) plus citrus parts: glossy pointed leaf, bush,
# fruit with shade crescent and gloss, cut half, white star flower, pip.
use strict; use warnings; use Math::Trig;
our ($OUT, %PAL, @S);
@S = ();

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A tapered stalk / branch from (x,y) heading `ang`, bending `bend` degrees. $taper < 1 keeps a blunt end.
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
  my ($x, $y, $ang, $len, $bend, $t) = @_; my $n = 10;
  my $steps = $t * $n; my $a = $ang;
  for my $i (1 .. int($steps)) { my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  my $f = $steps - int($steps); my ($dx, $dy) = dir($a); $x += $dx * $len / $n * $f; $y += $dy * $len / $n * $f;
  return ($x, $y, $a);
}

# Glossy pointed oval citrus leaf on a short petiole: lit and shaded halves, a pale gloss sliver.
# $gloss: class for the sliver (or undef). $curl > 0 narrows and twists the leaf (dried leaves).
sub cleaf {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $gloss, $curl) = @_;
  $curl //= 0;
  my $n = 14; my (@mid, @l, @r, @ang);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $u = $t < 0.1 ? 0 : ($t - 0.1) / 0.9;
    my $hw = $t < 0.1 ? 1.2 : $w / 2 * sin(pi * $u ** 0.82) ** 0.62;
    my $hl = $hw * (1 - $curl * (0.5 + 0.5 * sin($t * 9))); my $hr = $hw * (1 - $curl * (0.5 + 0.5 * cos($t * 7)));
    ($hl, $hr) = (0, 0) if $i == $n;
    push @l, [$px - $dy * $hl, $py + $dx * $hl];
    push @r, [$px + $dy * $hr, $py - $dx * $hr];
    push @mid, [$px, $py]; push @ang, $a;
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
  if ($gloss) {   # a thin shine streak along the lit half, near the midrib
    my $L = $leftLit ? \@l : \@r; my (@a, @b);
    for my $i (3 .. 8) {
      my $k = 0.28 + 0.1 * sin(pi * ($i - 3) / 5); my $hw = 0.1 + 0.16 * sin(pi * ($i - 3) / 5);
      my ($mx, $my) = @{$mid[$i]}; my ($ex, $ey) = @{$L->[$i]};
      push @a, [$mx + ($ex - $mx) * ($k - $hw), $my + ($ey - $my) * ($k - $hw)];
      push @b, [$mx + ($ex - $mx) * ($k + $hw), $my + ($ey - $my) * ($k + $hw)];
    }
    poly($gloss, @a, reverse @b);
  }
}

# Outline of a citrus fruit: ellipse along `ang`, optional nipple tip ($o{tip}) and stem-end bump ($o{neck}),
# $o{taper} pinches both ends (lemon), $o{jag} adds facet jitter.
sub fruit_outline {
  my ($x, $y, $ang, $len, $w, %o) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $N = $o{n} // 28; my @o;
  my $tip = $o{tip} // 0; my $neck = $o{neck} // 0; my $taper = $o{taper} // 0;
  for my $i (0 .. $N - 1) {
    my $th = 2 * pi * $i / $N; my $c = cos($th); my $s = sin($th);
    my $u = $c * $len / 2; my $v = $s * $w / 2 * (1 - $taper * $c ** 4);
    $u += $len * $tip * exp(-($s ** 2) / 0.012) if $c > 0;
    $v *= 1 - 0.75 * exp(-($s ** 2) / 0.012) if $c > 0.9 && $tip;
    $u -= $len * $neck * exp(-($s ** 2) / 0.03) if $c < 0;
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  return @o;
}

# Crescent along the part of outline @o facing direction (fx,fy): the outline arc closed through the same
# arc pulled inward by $k toward the centre and shifted by $off along (fx,fy).
sub crescent {
  my ($cls, $cx, $cy, $fx, $fy, $thr, $k, $off, @o) = @_;
  my $N = @o; my @on;
  for my $i (0 .. $N - 1) {
    my ($ox, $oy) = ($o[$i][0] - $cx, $o[$i][1] - $cy); my $d = sqrt($ox * $ox + $oy * $oy) || 1;
    $on[$i] = ($ox * $fx + $oy * $fy) / $d > $thr ? 1 : 0;
  }
  my ($st) = grep { $on[$_] && !$on[($_ - 1) % $N] } 0 .. $N - 1;
  return unless defined $st;
  my @arc; for my $j (0 .. $N - 1) { my $i = ($st + $j) % $N; last unless $on[$i]; push @arc, $o[$i]; }
  return if @arc < 3;
  poly($cls, @arc, map { [$cx + ($_->[0] - $cx) * $k + $off * $fx, $cy + ($_->[1] - $cy) * $k + $off * $fy] } reverse @arc);
}

# A citrus fruit (top-down or front): body, shaded crescent lower right, lit band and a gloss facet upper left.
# %o: body shade lit gloss (classes), tip neck taper (shape), calyx => [class, r, ux, uy] star at a spot
# (fractions of len/w from centre), pores => n (tiny pale dimples on the lit side), stem => [len, w, class].
sub fruit {
  my ($x, $y, $ang, $len, $w, %o) = @_;
  my ($body, $shade) = ($o{body} // 'c5', $o{shade} // 'c4');
  my @o = fruit_outline($x, $y, $ang, $len, $w, %o);
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  if ($o{stem}) {   # stalk leaving the stem end, drawn behind
    my ($sl, $sw, $sc) = @{$o{stem}};
    my $sx = $x - $dx * $len * (0.5 - ($o{neck} // 0)) * 0.96; my $sy = $y - $dy * $len * (0.5 - ($o{neck} // 0)) * 0.96;
    blade($sx + $dx * 3, $sy + $dy * 3, $ang + 180 + ($o{stembend} // 0), $sl, $sw, $o{stemcurl} // 0, $sc // 'c2', 'c1', 0.4);
  }
  poly($body, @o);
  my $r = min($len, $w) / 2;
  my @base = ($o{tip} || $o{neck}) ? fruit_outline($x, $y, $ang, $len, $w, %o, tip => 0, neck => 0) : @o;
  crescent($shade, $x, $y, 0.7071, 0.7071, $o{sthr} // 0.1, 0.72, $r * 0.16, @base);
  crescent($o{lit}, $x, $y, -0.7071, -0.7071, 0.55, 0.86, -$r * 0.02, @o) if $o{lit};
  my $g = $o{gloss} // 'c3';
  if ($g) {        # gloss facet: a long diamond on the upper-left shoulder, along the outline
    my $gx = $x - 0.7071 * $r * 0.5; my $gy = $y - 0.7071 * $r * 0.5;
    my $gs = $o{gsize} // 1;
    my ($ux, $uy) = (0.7071, -0.7071);   # tangent of the shoulder
    poly($g, [$gx - $ux * $r * 0.36 * $gs, $gy - $uy * $r * 0.36 * $gs], [$gx - 0.7071 * $r * 0.08 * $gs, $gy - 0.7071 * $r * 0.08 * $gs],
             [$gx + $ux * $r * 0.22 * $gs, $gy + $uy * $r * 0.22 * $gs], [$gx + 0.7071 * $r * 0.1 * $gs, $gy + 0.7071 * $r * 0.1 * $gs]);
    poly($g, map { my ($cx, $cy) = dir($_ * 60); [$gx + $ux * $r * 0.38 * $gs + $cx * $r * 0.055 * $gs, $gy + $uy * $r * 0.38 * $gs + $cy * $r * 0.055 * $gs] } 0 .. 5)
      if $o{spark};
  }
  if ($o{pores}) {  # dimpled peel: tiny pale pits on the lit half, tiny dark pits on the shade side
    srand(int($x * 3 + $y));
    for (1 .. $o{pores}) {
      my $a = rand(2 * pi); my $rr = sqrt(rand(1)) * 0.8;
      my $px = $x + cos($a) * $rr * $len / 2; my $py = $y + sin($a) * $rr * $w / 2;
      my $side = (cos($a) + sin($a)) * $rr;    # > 0 lower right
      next if abs($side) < 0.15;
      next if $side > 0 && !$o{poredark}; my $cls = $side < 0 ? ($o{porelit} // "c3") : $o{poredark}; my $s = $r * 0.028 + 0.4;
      poly($cls, [$px - $s, $py], [$px, $py - $s * 0.8], [$px + $s, $py], [$px, $py + $s * 0.8]);
    }
  }
  if ($o{calyx}) {  # little green star where the stem attaches
    my ($cc, $cr, $cu, $cv, $cd) = @{$o{calyx}};
    my $cx = $x + $dx * $cu * $len / 2 + $nx * $cv * $w / 2; my $cy = $y + $dy * $cu * $len / 2 + $ny * $cv * $w / 2;
    my @p; for my $k (0 .. 9) { my ($ex, $ey) = dir($k * 36 + 9); my $rr = $k % 2 ? $cr * 0.45 : $cr; push @p, [$cx + $ex * $rr, $cy + $ey * $rr]; }
    poly($cc, @p);
    poly($cd // 'c1', map { my ($ex, $ey) = dir($_ * 60); [$cx + $ex * $cr * 0.32 + $cr * 0.1, $cy + $ey * $cr * 0.32 + $cr * 0.1] } 0 .. 5);
  }
  return @o;
}

# A citrus pip: pointed teardrop with a lit half.
sub pip {
  my ($x, $y, $ang, $len, $w, $light, $dark) = @_;
  $light //= 'c3'; $dark //= 'c4';
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 15) {
    my $th = 2 * pi * $i / 16; my $c = cos($th);
    my $u = $c * $len / 2; my $v = sin($th) * $w / 2 * (1 - 0.55 * max(0, $c)) * (1 - 0.1 * max(0, -$c));
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly($light, @o);
  crescent($dark, $x, $y, 0.7071, 0.7071, 0.2, 0.7, $w * 0.12, @o);
  my $k = $len * 0.18; poly($dark, [$x + $dx * $k * 1.6 + $nx * 0.8, $y + $dy * $k * 1.6 + $ny * 0.8], [$x + $dx * $len * 0.47, $y + $dy * $len * 0.47], [$x + $dx * $k * 1.6 - $nx * 0.8, $y + $dy * $k * 1.6 - $ny * 0.8]);
}

# Cut face of a citrus (ellipse rx, ry): peel rim, pith ring, wedge segments with pale membranes and core.
# %o: rim pith seg seghi (classes), nseg, side => depth of the peel dome shown below the face (front view).
sub cut_face {
  my ($x, $y, $rx, $ry, %o) = @_;
  my ($rim, $pith, $seg, $hi) = ($o{rim} // 'c5', $o{pith} // 'c3', $o{seg} // 'c5', $o{seghi} // 'c3');
  my $ns = $o{nseg} // 10; my $rot = $o{rot} // 0;
  if ($o{side}) {   # the peel dome under the cut face
    my @d; for my $i (0 .. 16) { my $th = pi * $i / 16; push @d, [$x + cos($th) * $rx * 1.04, $y + sin($th) * ($ry + $o{side})]; }
    poly($rim, [$x + $rx * 1.04, $y], @d, [$x - $rx * 1.04, $y]);
    my @sh; for my $i (0 .. 9) { my $th = pi * $i / 16; push @sh, [$x + cos($th) * $rx * 1.04, $y + sin($th) * ($ry + $o{side})]; }
    poly($o{shade} // 'c4', @sh, map { [$x + ($_->[0] - $x) * 0.8 + $rx * 0.02, $y + ($_->[1] - $y) * 0.86 - $o{side} * 0.05] } reverse @sh);
  }
  my @e = map { my $th = 2 * pi * $_ / 32; [$x + cos($th) * $rx * 1.04, $y + sin($th) * $ry * 1.04] } 0 .. 31;
  poly($rim, @e);
  poly($pith, map { my $th = 2 * pi * $_ / 32; [$x + cos($th) * $rx * 0.95, $y + sin($th) * $ry * 0.95] } 0 .. 31);
  my $sr = $o{segr} // 0.86;
  for my $k (0 .. $ns - 1) {
    my $a0 = 2 * pi * $k / $ns + $rot; my $a1 = 2 * pi * ($k + 1) / $ns + $rot; my $g = 0.07;
    my @w = ([$x + cos(($a0 + $a1) / 2) * $rx * 0.13, $y + sin(($a0 + $a1) / 2) * $ry * 0.13]);
    for my $j (0 .. 4) { my $a = $a0 + $g + ($a1 - $a0 - 2 * $g) * $j / 4; push @w, [$x + cos($a) * $rx * $sr, $y + sin($a) * $ry * $sr]; }
    poly($seg, @w);
    # juicy shine on each wedge, toward the light
    my $am = ($a0 + $a1) / 2; my ($c, $s) = (cos($am), sin($am));
    my $lt = -0.7071 * $c - 0.7071 * $s;
    if ($lt > -0.2 || $o{allhi}) {
      my ($qa, $qb) = ($am - 0.13, $am + 0.03);
      poly($hi, [$x + $c * $rx * 0.4, $y + $s * $ry * 0.4], [$x + cos($qa) * $rx * 0.66, $y + sin($qa) * $ry * 0.66],
                [$x + cos($am) * $rx * 0.76, $y + sin($am) * $ry * 0.76], [$x + cos($qb) * $rx * 0.62, $y + sin($qb) * $ry * 0.62]);
    }
  }
  poly($pith, map { my $th = 2 * pi * $_ / 10; [$x + cos($th) * $rx * 0.11, $y + sin($th) * $ry * 0.11] } 0 .. 9);
  if ($o{pips}) {
    for my $p (@{$o{pips}}) { my $a = 2 * pi * ($p + 0.5) / $ns + $rot; pip($x + cos($a) * $rx * 0.45, $y + sin($a) * $ry * 0.45, rad2deg(atan2(sin($a) * $ry, cos($a) * $rx)), $rx * 0.2, $rx * 0.11, $o{pipl}, $o{pipd}); }
  }
}

# White citrus blossom from above: five thick pointed petals around a tuft of yellow stamens.
sub flower {
  my ($x, $y, $r, $rot, $centre, $shade) = @_;
  $centre //= 'c5'; $shade //= 'c2';
  for my $i (0 .. 4) {
    my $a = $rot + $i * 72; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    my @q = ([$x + $nx * $r * 0.2, $y + $ny * $r * 0.2], [$x + $dx * $r * 0.62 + $nx * $r * 0.3, $y + $dy * $r * 0.62 + $ny * $r * 0.3],
             [$x + $dx * $r, $y + $dy * $r], [$x + $dx * $r * 0.62 - $nx * $r * 0.3, $y + $dy * $r * 0.62 - $ny * $r * 0.3],
             [$x - $nx * $r * 0.2, $y - $ny * $r * 0.2]);
    poly('c3', @q);
    # the shaded half of each cupped petal (the one turned away from the light)
    my $sideLit = lit($nx, $ny);
    poly($shade, $sideLit ? ($q[2], $q[3], $q[4], [$x, $y]) : ($q[0], $q[1], $q[2], [$x, $y])) if !lit($dx, $dy);
  }
  my @c; for my $k (0 .. 9) { my ($dx, $dy) = dir($rot + 18 + $k * 36); my $rr = $k % 2 ? 0.2 : 0.32; push @c, [$x + $dx * $r * $rr, $y + $dy * $r * $rr]; }
  poly($centre, @c);
  poly('c1', map { my ($dx, $dy) = dir($_ * 72 + $rot); [$x + $dx * $r * 0.09 + 0.6, $y + $dy * $r * 0.09 + 0.6] } 0 .. 4);
}

# A closed flower bud: small cream oval with a green cup.
sub bud {
  my ($x, $y, $ang, $r) = @_;
  my ($dx, $dy) = dir($ang);
  blade($x - $dx * $r * 1.6, $y - $dy * $r * 1.6, $ang, $r * 1.0, $r * 0.35, 0, 'c2', 'c1', 0.5);
  fruit($x, $y, $ang, $r * 2.1, $r * 1.6, body => 'c3', shade => 'c2', gloss => 0);
  poly('c2', [$x - $dx * $r * 1.0 - $dy * $r * 0.6, $y - $dy * $r * 1.0 + $dx * $r * 0.6], [$x - $dx * $r * 0.3, $y - $dy * $r * 0.3],
             [$x - $dx * $r * 1.0 + $dy * $r * 0.6, $y - $dy * $r * 1.0 - $dx * $r * 0.6]);
}

# Top-down citrus bush: woody branches from the crown, glossy leaves in clusters along them (outer leaves first,
# so the canopy domes up toward the middle). Returns fruit spots [x, y, heading] between the leaf clusters.
# %o: nb reach seed start leaf (length) lw (width ratio) per inner (fraction where leaves start) wood => [w, light, dark]
#     light dark gloss centre (extra leaves around the crown) curl (dried leaves) spots (fractions along branches)
sub bush {
  my (%o) = @_;
  my $nb = $o{nb}; my $R = $o{reach}; srand($o{seed});
  my ($light, $dark, $gloss) = ($o{light} // 'c2', $o{dark} // 'c1', exists $o{gloss} ? $o{gloss} : 'c3');
  my $ll = $o{leaf}; my $lw = $o{lw} // 0.44; my $per = $o{per} // 4; my $inner = $o{inner} // 0.3;
  my (@leaves, @spots, @br);
  for my $i (0 .. $nb - 1) {
    my $a = ($o{start} // -90) + $i * 360 / $nb + rand(16) - 8;
    my $len = $R * (0.86 + rand(0.14)) - $ll * 0.7; my $bend = (rand(1) < 0.5 ? -1 : 1) * (14 + rand(22));
    push @br, [$a, $len, $bend];
    for my $k (0 .. $per - 1) {
      my $t = $inner + (1 - $inner) * ($k + 0.3 + rand(0.3)) / $per;
      my ($px, $py, $pa) = walk(200, 200, $a, $len, $bend, $t);
      for my $s (-1, 1) {
        my $l = $ll * (0.78 + 0.3 * $t + rand(0.14));
        push @leaves, [$px, $py, $pa + $s * (34 + rand(26)), $l, $l * $lw, $s * (rand(14)), rand(1)];
      }
    }
    my ($px, $py, $pa) = walk(200, 200, $a, $len, $bend, 1);
    push @leaves, [$px, $py, $pa + rand(10) - 5, $ll * 1.05, $ll * 1.05 * $lw, rand(10) - 5, 1];
    for my $f (@{$o{spots} // [0.62]}) { push @spots, [walk(200, 200, $a, $len, $bend, $f), $i]; }
  }
  for my $k (1 .. ($o{centre} // 0)) {   # leaves sprouting around the crown
    my $a = $k * 360 / ($o{centre}) + 20 + rand(20); my ($dx, $dy) = dir($a);
    my $l = $ll * (0.8 + rand(0.2));
    push @leaves, [200 + $dx * $R * 0.12, 200 + $dy * $R * 0.12, $a, $l, $l * $lw, rand(16) - 8, 0];
  }
  my ($ww, $wl, $wd) = @{$o{wood} // [9, "c1", "c4"]};
  if ($o{mass}) {   # dark leafy mass under the canopy (a ring, so the woody crown stays visible)
    my ($r0, $r1) = @{$o{mass}}; $r1 *= 0.88; my $N = 24; my @k = map { 0.9 + rand(0.2) } 0 .. $N - 1;
    for my $i (0 .. $N - 1) { my ($a, $b) = (360 * $i / $N, 360 * ($i + 1.06) / $N); my ($ax, $ay) = dir($a); my ($bx, $by) = dir($b); my $j = ($i + 1) % $N;
      poly($dark, [200 + $ax * $R * $r0, 200 + $ay * $R * $r0], [200 + $ax * $R * $r1 * $k[$i], 200 + $ay * $R * $r1 * $k[$i]], [200 + $bx * $R * $r1 * $k[$j], 200 + $by * $R * $r1 * $k[$j]], [200 + $bx * $R * $r0, 200 + $by * $R * $r0]); }
  }
  blade(200, 200, $_->[0], $_->[1], $ww, $_->[2], $wl, $wd, 0.7) for @br;
  for (sort { (($b->[0] - 200) ** 2 + ($b->[1] - 200) ** 2) <=> (($a->[0] - 200) ** 2 + ($a->[1] - 200) ** 2) } @leaves) {
    my @v = @$_;
    cleaf(@v[0 .. 5], $light, $dark, ($gloss && $v[6] > 0.35 ? $gloss : undef), $o{curl});
  }
  return @spots;
}

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
  mkdir 'crops'; mkdir $OUT;
  open my $fh, '>', "$OUT/$file" or die $!;
  print $fh qq{<?xml version="1.0" encoding="UTF-8"?>\n<svg viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="$label">\n  <style>\n};
  print $fh "    .$_ { fill: var(--$_, $PAL{$_}); }\n" for qw(c1 c2 c3 c4 c5);
  print $fh "  </style>\n  <g transform=\"translate(0 0)\">\n", join("\n", @S), "\n  </g>\n</svg>\n";
  close $fh; @S = ();
}

# Dead bush (never watered), top down: cracked dry soil, bare grey-brown branches, curled straw leaves lying flat.
# Returns spots along the dead branches (for shrivelled fruit).
sub dead_bush {
  my (%o) = @_;
  soil(200, 200, 66, 58, 8);
  cracks(9, 83, 14, 'c3');
  srand($o{seed} // 84);
  my (@lv, @br, @spots);
  for my $i (0 .. ($o{nb} // 7) - 1) {
    my $a = -80 + $i * 360 / ($o{nb} // 7) + rand(18) - 9; my $len = ($o{reach} // 118) * (0.8 + rand(0.25));
    my $bend = (rand(1) < .5 ? -1 : 1) * (24 + rand(30));
    push @br, [$a, $len, $bend];
    for my $t (0.4, 0.66, 0.9) {
      my ($px, $py, $pa) = walk(200, 200, $a, $len, $bend, $t); my $s = rand(1) < .5 ? -1 : 1;
      my $l = ($o{leaf} // 44) * (0.85 + rand(0.3));
      push @lv, [$px, $py, $pa + $s * (50 + rand(40)), $l, $l * ($o{lw} // 0.42), $s * (40 + rand(50))];
    }
    push @spots, [walk(200, 200, $a, $len, $bend, 0.75)];
  }
  blade(200, 200, $_->[0], $_->[1], $o{ww} // 8, $_->[2], 'c3', 'c4', 0.8) for @br;
  cleaf(@$_, 'c3', 'c4', undef, 0.3) for @lv;
  return @spots;
}

1;

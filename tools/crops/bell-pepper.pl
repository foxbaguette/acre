# Bell pepper (yellow) crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/bell-pepper.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/bell-pepper';
mkdir 'crops'; mkdir $OUT;
# c1 deep leaf green, c2 lit glossy green, c3 cream (white flowers, gloss, seeds, dry leaves),
# c4 warm dark brown (soil, pepper shade), c5 golden yellow (the peppers)
my %PAL = (c1 => '#2F6A36', c2 => '#6DAE4C', c3 => '#F6E4AC', c4 => '#5E3B22', c5 => '#F4B41E');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Bent shape from (x,y) heading `ang`; $pl/$pr give left/right half-width factors for t in 0..1.
# Split along its midline into a lit and a shaded half. Returns end point, end angle, lit flag and outlines.
sub shape2 {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $pl, $pr, $n) = @_;
  $n //= 14; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hl = $w / 2 * $pl->($t) + ($i == $n ? 0 : 0.5);
    my $hr = $w / 2 * $pr->($t) + ($i == $n ? 0 : 0.5);
    push @l, [$px - $dy * $hl, $py + $dx * $hl];
    push @r, [$px + $dy * $hr, $py - $dx * $hr];
    push @mid, [$px, $py];
    last if $i == $n;
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid) if $light;
  poly($leftLit ? $dark : $light, @r, reverse @mid) if $light;
  return ($px, $py, $a, $leftLit, \@mid, \@l, \@r);
}
sub blade { my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $tip) = @_; $tip //= 0;
  shape2($x, $y, $ang, $len, $w, $bend, $light, $dark, (sub { 1 - (1 - $tip) * $_[0] }) x 2, 10) }

# Glossy pepper leaf: smooth ovate blade with a pointed tip on a short stalk, plus a sheen facet.
our $WILT = 0;
sub pleaf {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark) = @_;
  $light //= 'c2'; $dark //= 'c1';
  my ($sx, $sy, $sa) = blade($x, $y, $ang, $len * 0.14, max(2.5, $len * 0.045), $bend * 0.1, $light, $dark, 0.8);
  my $prof = sub { my $t = shift; my $b = sin(pi * $t ** 0.62) ** 0.8; $WILT ? $b * (0.7 + 0.3 * abs(sin($t * 9))) : $b };
  my ($ex, $ey, $ea, $leftLit, $mid, $l, $r) = shape2($sx, $sy, $sa, $len * 0.86, $w, $bend, $light, $dark, $prof, $prof, 14);
  return if $WILT;
  # sheen: a pale sliver on the lit half
  my $side = $leftLit ? $l : $r; my $n = $#$mid;
  my $f = sub { my ($i, $k) = @_; [$mid->[$i][0] + ($side->[$i][0] - $mid->[$i][0]) * $k, $mid->[$i][1] + ($side->[$i][1] - $mid->[$i][1]) * $k] };
  poly($dark, $mid->[int($n * 0.5)], $f->(int($n * 0.72), 0.78), $mid->[int($n * 0.86)]);
}

# Yellow bell pepper seen from ABOVE (it hangs; we look at its shoulders): a lobed square, shaded lobes,
# creases between lobes, sunken stem cavity, green calyx star and a thick stalk toward the plant.
sub pepper_top {
  my ($x, $y, $r, $rot, $stalkAng, %o) = @_;
  my $body = $o{body} // 'c5'; my $shade = $o{shade} // 'c4'; my $hi = $o{hi} // 'c3';
  my ($cl, $cd) = ($o{cl} // 'c2', $o{cd} // 'c1');
  my $nl = $o{lobes} // 4; my $n = 8 * $nl;
  my @o;
  for my $i (0 .. $n - 1) {
    my $ph = 2 * pi * $i / $n; my $th = $ph + deg2rad($rot);
    my $k = 0.8 + 0.2 * abs(cos($nl * $ph / 2)) ** 0.5;      # lobe bumps with indents between
    push @o, [$x + cos($th) * $r * $k, $y + sin($th) * $r * $k];
  }
  poly($body, @o);
  # each lobe: a facet lit or shaded by its facing
  for my $j (0 .. $nl - 1) {
    my $i0 = $j * 8 - 4; my @arc = map { $o[$_ % $n] } $i0 .. $i0 + 8;
    my $ca = deg2rad($rot) + 2 * pi * $j / $nl; my $b = -(cos($ca) + sin($ca)) * 0.7071;   # >0 faces the light
    my ($ix, $iy) = ($x + cos($ca) * $r * 0.3, $y + sin($ca) * $r * 0.3);
    if ($b < 0.2) {        # shaded lobe: dark crescent on its outer part
      my $k = $b < -0.5 ? 0.45 : 0.68;
      poly($shade, @arc[1 .. 7], reverse map { [$ix + ($_->[0] - $ix) * $k, $iy + ($_->[1] - $iy) * $k] } @arc[1 .. 7]);
    }
    if ($b > 0.3) {        # lit lobe: gloss facet
      my @g = map { [$ix + ($_->[0] - $ix) * 0.72, $iy + ($_->[1] - $iy) * 0.72] } @arc[2 .. 5];
      poly($hi, @g, [$ix + ($arc[4][0] - $ix) * 0.4, $iy + ($arc[4][1] - $iy) * 0.4]);
    }
  }
  # creases from the cavity out to the indents
  for my $j (0 .. $nl - 1) {
    my $ia = deg2rad($rot) + 2 * pi * ($j + 0.5) / $nl; my ($cx, $cy) = (cos($ia), sin($ia)); my ($nx, $ny) = (-$cy, $cx);
    my $w = $r * 0.07;
    poly($shade, [$x + $cx * $r * 0.25 + $nx * $w, $y + $cy * $r * 0.25 + $ny * $w], [$x + $cx * $r * 0.82, $y + $cy * $r * 0.82],
                 [$x + $cx * $r * 0.25 - $nx * $w, $y + $cy * $r * 0.25 - $ny * $w]);
  }
  # sunken cavity, calyx star, stalk
  poly($shade, map { my $th = 2 * pi * $_ / 10; [$x + cos($th) * $r * 0.34 + $r * 0.04, $y + sin($th) * $r * 0.34 + $r * 0.04] } 0 .. 9);
  for my $i (0 .. 4) { my $a = $rot + 36 + $i * 72; blade($x, $y, $a, $r * 0.38, $r * 0.2, 14, $cl, $cd); }
  blade($x, $y, $stalkAng, $r * ($o{stalk} // 0.9), $r * 0.26, 18, $cl, $cd, 0.8);
}

# Yellow bell pepper from the FRONT: three blocky lobes (middle one in front), glossy streaks,
# a shaded right side, a sunken stem cavity, a green calyx collar and a thick curved stem.
sub pepper_front {
  my ($x, $y, $W, $H, $tilt, $stemBend, %o) = @_;
  my ($body, $shade, $hi) = ($o{body} // 'c5', $o{shade} // 'c4', $o{hi} // 'c3');
  my ($cl, $cd) = ($o{cl} // 'c2', $o{cd} // 'c1');
  my $ta = deg2rad($tilt);
  # local +u should point away from the upper-left light; mirror the pepper if it does not
  my $m = (cos($ta) * -0.7071 + sin($ta) * -0.7071) > 0 ? -1 : 1;
  my $R = sub { my ($u, $v) = @_; $u *= $m; [$x + $u * cos($ta) - $v * sin($ta), $y + $u * sin($ta) + $v * cos($ta)] };
  my $lobe = sub {          # rounded column: centre u, half-width a, top v0, bottom v1
    my ($cu, $a, $v0, $v1) = @_; my @p;
    my ($vc, $b) = (($v0 + $v1) / 2, ($v1 - $v0) / 2);
    for my $i (0 .. 27) {
      my $th = 2 * pi * $i / 28; my ($c, $s) = (cos($th), sin($th));
      my $ex = $s > 0 ? 2.6 : 3.2;                            # rounder at the bottom
      my $u = $a * ($c < 0 ? -1 : 1) * abs($c) ** (2 / $ex); my $v = $b * ($s < 0 ? -1 : 1) * abs($s) ** (2 / $ex);
      $u *= 1 - 0.14 * max(0, ($v / $b)) ** 2;                 # taper toward the bottom
      push @p, [$cu + $u, $vc + $v];
    }
    return @p;
  };
  my $col = sub { my ($cu, $a, $v0, $v1, $lightness, $crease) = @_;
    my @p = $lobe->($cu, $a, $v0, $v1);
    poly($shade, map { $R->($_->[0] - $crease, $_->[1] - abs($crease) * 0.6) } @p) if $crease;   # thin dark crease beside the lobe
    poly($body, map { $R->(@$_) } @p);
    my ($vc, $b) = (($v0 + $v1) / 2, ($v1 - $v0) / 2);
    # shade along the right side of the lobe
    my $k = $lightness > 0 ? 0.75 : $lightness < 0 ? 0.42 : 0.68;
    poly($shade, map { my ($u, $v) = @$_; my $cut = $cu + $a * ($k - 0.1 * ($v - $vc) / $b); $R->(max($u, $cut), $v) } @p);
    # gloss streak on the left side
    if ($lightness >= 0) {
      my $gu = $cu - $a * 0.45; my $gw = $a * ($lightness > 0 ? 0.17 : 0.13);
      poly($hi, map { $R->(@$_) } [$gu - $gw * 0.3, $v0 + $b * 0.3], [$gu + $gw, $v0 + $b * 0.4], [$gu + $gw * 0.7, $vc + $b * 0.4],
                                  [$gu - $gw * 0.2, $vc + $b * 0.5], [$gu - $gw, $vc + $b * 0.1]);
    }
  };
  my $h = $H / 2;
  $col->(-$W * 0.27, $W * 0.25, -$h + $H * 0.02, $h - $H * 0.08, 1, 0);       # left lobe (lit)
  $col->($W * 0.27, $W * 0.25, -$h + $H * 0.03, $h - $H * 0.07, -1, 0);       # right lobe (shaded)
  $col->(0, $W * 0.27, -$h + $H * 0.06, $h, 0, $W * 0.025);                     # middle lobe in front
  # cavity, calyx collar and thick stem
  poly($shade, map { my $th = 2 * pi * $_ / 12; $R->(cos($th) * $W * 0.17, -$h + $H * 0.08 + sin($th) * $H * 0.05) } 0 .. 11);
  my ($sx, $sy) = @{$R->(0, -$h + $H * 0.08)};
  my $up = -90 + $tilt;
  for my $s ([162, 0.28], [18, 0.28], [198, 0.18], [-18, 0.18]) {
    my $sa = $m < 0 ? 180 - $s->[0] : $s->[0];
    blade($sx, $sy, $sa + $tilt, $W * $s->[1], $W * 0.1, ($sa > 90 ? -1 : 1) * 14, $cl, $cd);
  }
  my ($ex, $ey, $ea) = blade($sx, $sy, $up, $H * ($o{stem} // 0.34), $W * 0.15, $stemBend * $m, $cl, $cd, 0.8);
  my ($dx, $dy) = dir($ea); my ($nx, $ny) = (-$dy, $dx); my $cw = $W * 0.065;
  poly($hi, map { my $th = 2 * pi * $_ / 8; [$ex + $nx * cos($th) * $cw + $dx * sin($th) * $cw * 0.45, $ey + $ny * cos($th) * $cw + $dy * sin($th) * $cw * 0.45] } 0 .. 7) unless $o{nocut};
}

# Small white pepper flower, nodding face up: five cream petals, green-yellow eye.
sub flower {
  my ($x, $y, $r, $rot) = @_;
  for my $i (0 .. 4) { my $a = $rot + 36 + $i * 72; blade($x, $y, $a, $r * 0.55, $r * 0.28, 0, 'c2', 'c1'); }
  for my $i (0 .. 4) {
    my $a = $rot + $i * 72; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    poly('c3', [$x + $nx * $r * 0.22, $y + $ny * $r * 0.22], [$x + $dx * $r * 0.7 + $nx * $r * 0.3, $y + $dy * $r * 0.7 + $ny * $r * 0.3],
               [$x + $dx * $r, $y + $dy * $r], [$x + $dx * $r * 0.7 - $nx * $r * 0.3, $y + $dy * $r * 0.7 - $ny * $r * 0.3],
               [$x - $nx * $r * 0.22, $y - $ny * $r * 0.22]);
  }
  my @p; for my $i (0 .. 5) { my ($dx, $dy) = dir($rot + $i * 60); push @p, [$x + $dx * $r * 0.28, $y + $dy * $r * 0.28]; }
  poly('c5', @p);
  my @q; for my $i (0 .. 4) { my ($dx, $dy) = dir($rot + 36 + $i * 72); push @q, [$x + $dx * $r * 0.12, $y + $dy * $r * 0.12]; }
  poly('c2', @q);
}

# Flat, round, pale pepper seed with a little notch and a golden shaded rim.
sub seed {
  my ($x, $y, $rot, $r) = @_; my @o;
  for my $i (0 .. 15) {
    my $th = 2 * pi * $i / 16; my $k = 1 - 0.25 * exp(-((($th - pi / 2) ** 2) / 0.1));
    my ($c, $s) = (cos($th) * $r * $k, sin($th) * $r * 0.9 * $k);
    my $ra = deg2rad($rot);
    push @o, [$x + $c * cos($ra) - $s * sin($ra), $y + $c * sin($ra) + $s * cos($ra)];
  }
  poly('c4', @o);
  poly('c5', map { [$x + ($_->[0] - $x) * 0.9 - $r * 0.05, $y + ($_->[1] - $y) * 0.9 - $r * 0.05] } @o);
  poly("c3", map { [$x + ($_->[0] - $x) * 0.8 - $r * 0.08, $y + ($_->[1] - $y) * 0.8 - $r * 0.08] } @o);
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
    my $a = $i * 360 / $n + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
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

# A top-down pepper bush: $nb branches, each with whorls of glossy leaves. Returns branch info for fruit/flowers.
sub bush {
  my ($nb, $reach, $seed, $start, $lf) = @_; $lf //= 1;
  srand($seed); my (@leaves, @br);
  for my $i (0 .. $nb - 1) {
    my $a = ($start // -90) + $i * 360 / $nb + rand(14) - 7;
    my $r = $reach * (0.88 + rand(0.16));
    my ($dx, $dy) = dir($a);
    for my $k (0 .. 2) {
      my $d = $r * (0.08 + 0.3 * $k); my $len = $r * (0.5 + 0.06 * $k) * $lf + rand(8);
      for my $s (-1, 1) { push @leaves, [200 + $dx * $d, 200 + $dy * $d, $a + $s * (50 - $k * 12) + rand(12) - 6, $len, $len * 0.48, $s * (8 + rand(10))]; }
    }
    push @leaves, [200 + $dx * $r * 0.6, 200 + $dy * $r * 0.6, $a + rand(10) - 5, $r * 0.42 * $lf, $r * 0.22 * $lf, rand(14) - 7];
    push @br, [$a, $r];
  }
  pleaf(@$_) for sort { $b->[3] <=> $a->[3] } @leaves;
  return @br;
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: half a yellow pepper, cut face to us: yellow wall, shadowed hollow,
#    the pale core (placenta) hanging from the stem with round seeds clinging to it.
{
  my ($cx, $cy, $W, $H) = (200, 210, 230, 220);
  my @o;
  for my $i (0 .. 39) {
    my $th = 2 * pi * $i / 40; my ($c, $s) = (cos($th), sin($th));
    my $ex = $s > 0 ? 2.6 : 3.4;
    my $u = $W / 2 * ($c < 0 ? -1 : 1) * abs($c) ** (2 / $ex); my $v = $H / 2 * ($s < 0 ? -1 : 1) * abs($s) ** (2 / $ex);
    $u *= 1 - 0.14 * max(0, $v / ($H / 2)) ** 2;
    $v += $H * 0.05 * cos(3 * $th) * ($s > 0 ? 1 : 0.4);               # lobed bottom and shoulders
    $v += $H * 0.09 * exp(-(($u / ($W * 0.14)) ** 2)) if $s < 0;      # dip where the stem sits
    push @o, [$cx + $u, $cy + $v];
  }
  poly('c5', @o);
  poly('c4', map { [$cx + ($_->[0] - $cx) * 0.97 + 6, $cy + ($_->[1] - $cy) * 0.97 + 7] } @o[2 .. 18]);   # outer shade (lower right)
  poly('c5', map { [$cx + ($_->[0] - $cx) * 0.95, $cy + ($_->[1] - $cy) * 0.95] } @o);
  poly('c4', map { [$cx + ($_->[0] - $cx) * 0.78 + 3, $cy + ($_->[1] - $cy) * 0.76 + 8] } @o);           # hollow in shadow
  # cut wall lit on the upper left: a pale sliver
  poly('c3', @o[22 .. 31], reverse map { [$cx + ($_->[0] - $cx) * 0.92, $cy + ($_->[1] - $cy) * 0.92] } @o[22 .. 31]);
  # stem on top
  blade($cx, $cy - $H * 0.43, -96, 60, 30, 18, 'c2', 'c1', 0.8);
  # placenta: a pale lumpy core hanging from the top
  my @p;
  for my $i (0 .. 15) { my $th = 2 * pi * $i / 16; my $k = 1 + 0.12 * sin($i * 2.1);
    push @p, [$cx + cos($th) * 42 * $k, $cy - 30 + sin($th) * 50 * $k]; }
  poly('c3', @p);
  # seeds clinging to the core and a few fallen into the hollow
  for my $s ([170, 150, 20], [196, 140, -30], [226, 150, 40], [160, 180, -20], [190, 172, 10], [232, 182, -40],
             [168, 210, 30], [204, 204, -10], [234, 214, 20], [186, 236, 60], [214, 240, -30],
             [150, 280, 20], [184, 292, -40], [236, 286, 30]) { seed($s->[0], $s->[1], $s->[2], 11); }
}
write_svg('1-seeds-front.svg', 'Bell pepper seeds');

# 2. Just sown, top down: seeds pressed into small soil pockets.
my @sown = ([170, 172, -20], [236, 170, 50], [200, 228, 100]);
for (@sown) { soil($_->[0], $_->[1], 34, 28, int($_->[0] * 7 + $_->[1])); }
for (@sown) { seed($_->[0] - 9, $_->[1] + 4, $_->[2], 11); seed($_->[0] + 10, $_->[1] - 6, $_->[2] + 140, 10); }
write_svg('2-sown.svg', 'Bell pepper just sown');

# 3. First growth, top down: two narrow seed leaves and two first true leaves.
soil(200, 200, 34, 30, 3);
shape2(200, 200, 200, 70, 20, -8, 'c2', 'c1', (sub { sin(pi * $_[0] ** 0.7) ** 0.7 }) x 2);
shape2(200, 200, 20, 70, 20, -8, 'c2', 'c1', (sub { sin(pi * $_[0] ** 0.7) ** 0.7 }) x 2);
pleaf(200, 200, -70, 92, 46, 10); pleaf(200, 200, 110, 80, 40, -8);
write_svg('3-first-growth.svg', 'Bell pepper first growth');

# 4. Second growth, top down: a young bushy plant.
soil(200, 200, 34, 30, 4);
bush(5, 118, 41, -80);
write_svg('4-second-growth.svg', 'Bell pepper second growth');

# 5. Third growth, top down: dense bush with white flowers and small green peppers.
soil(200, 200, 34, 30, 5);
my @b5 = bush(7, 140, 51, -76);
srand(53);
for my $i (0 .. $#b5) {
  my ($a, $r) = @{$b5[$i]}; my $fa = $a + 360 / @b5 / 2; my ($dx, $dy) = dir($fa);
  if ($i % 3 == 1) { pepper_front(200 + $dx * 66, 200 + $dy * 66, 30, 30, $fa + 270, 10, body => 'c2', shade => 'c1', hi => 'c3', cl => 'c2', cd => 'c1', stem => 0.9, nocut => 1); }
  else { flower(200 + $dx * $r * 0.5, 200 + $dy * $r * 0.5, 15, rand(72)); flower(200 + $dx * $r * 0.36 + $dy * 13, 200 + $dy * $r * 0.36 - $dx * 13, 12, rand(72)) if $i % 2 == 0; }
}
write_svg('5-third-growth.svg', 'Bell pepper third growth');

# 6. Harvest, top down: lush bush with big glossy yellow peppers hanging between the leaves.
soil(200, 200, 34, 30, 6);
my @b6 = bush(8, 160, 61, -70);
my @pp;
for my $i (0 .. $#b6) {
  next if $i % 2;
  my ($a, $r) = @{$b6[$i]}; my $fa = $a + 360 / @b6 / 2; my ($dx, $dy) = dir($fa);
  push @pp, [200 + $dx * 96, 200 + $dy * 96, 70, 70, $fa + 270, 8, stem => 0.55, nocut => 1];
}
pepper_front(@$_) for sort { $a->[1] <=> $b->[1] } @pp;
flower(200, 196, 15, 10); flower(214, 214, 12, 40);
write_svg('6-harvest.svg', 'Bell peppers ready to harvest');

# 7. Harvested produce, front view: two yellow bell peppers with thick green stems.
pepper_front(250, 206, 140, 142, 10, 18);
pepper_front(162, 232, 160, 162, -8, -20);
write_svg('7-harvest-front.svg', 'Harvested bell peppers');

# 8. Dead (never watered), top down: cracked dry soil, limp shrivelled leaves, a shrivelled pepper.
soil(200, 200, 60, 52, 8);
cracks(8, 83, 11, 'c3');
srand(81); $WILT = 1;
for my $i (0 .. 7) {
  my $a = -80 + $i * 45 + rand(16) - 8; my ($dx, $dy) = dir($a); my $bend = (rand(1) < 0.5 ? -1 : 1) * (60 + rand(60));
  my ($ex, $ey, $ea) = blade(200, 200, $a, 30 + rand(20), 6, $bend * 0.3, 'c3', 'c4');
  pleaf($ex, $ey, $ea, 76 + rand(30), 38, $bend, "c3", "c4");
}
pepper_front(262, 258, 34, 32, 225 + 270, 10, body => "c3", shade => "c4", hi => "c3", cl => "c3", cd => "c4", stem => 0.9, nocut => 1);
for ([-20, 20], [150, 16], [250, 18]) { blade(200, 200, $_->[0], $_->[1], 9, 0, 'c3', 'c4'); }
write_svg('8-dead.svg', 'Bell pepper died from lack of water');
print "wrote 8 files to $OUT\n";

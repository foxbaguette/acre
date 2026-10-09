# Mangosteen crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/mangosteen.pl
# Grown as a compact bush. Top-down stages (2-6, 8) share one fixed scale centred on (200,200).
# Signature: round deep purple-maroon fruit wearing a big green cap of four thick rounded sepals; large thick glossy
# dark leaves; inside, snow-white segments like garlic cloves.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/mangosteen';
mkdir 'crops'; mkdir $OUT;
# c1 dark glossy leaf green, c2 lit green (also the sepal cap), c3 snow white (flesh, gloss, flowers, dried leaves),
# c4 dark plum-brown soil / shade, c5 mangosteen purple-maroon
my %PAL = (c1 => '#245A31', c2 => '#64A048', c3 => '#F3EDDD', c4 => '#43262A', c5 => '#5E1B45');
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


# Shaded crescent on the lower right of a convex outline (list of points round centre x,y).
sub crescent {
  my ($cls, $x, $y, $k, $off, @o) = @_;
  my $N = @o;
  my @on = grep { my ($u, $v) = ($o[$_][0] - $x, $o[$_][1] - $y); ($u + $v) / (sqrt($u * $u + $v * $v) || 1) * 0.7071 > 0.12 } 0 .. $N - 1;
  my %on = map { $_ => 1 } @on; my ($st) = grep { $on{$_} && !$on{($_ + $N - 1) % $N} } 0 .. $N - 1; $st //= 0;
  my @a; for my $j (0 .. $N - 1) { my $i = ($st + $j) % $N; last unless $on{$i}; push @a, $o[$i]; }
  poly($cls, @a, map { [$x + ($_->[0] - $x) * $k + $off, $y + ($_->[1] - $y) * $k + $off] } reverse @a);
}

# One thick rounded sepal (seen from above or the front): a fat rounded lobe with a lit and a shaded half.
sub sepal {
  my ($x, $y, $ang, $len, $w, $L, $D) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my (@l, @r, @m);
  for my $i (0 .. 8) {
    my $t = $i / 8; my $hw = $w / 2 * (0.55 + 0.45 * sin(pi * min(1, $t * 0.9 + 0.1))) * ($i == 8 ? 0.5 : 1);
    my ($px, $py) = ($x + $dx * $len * $t, $y + $dy * $len * $t);
    push @l, [$px - $nx * $hw, $py - $ny * $hw]; push @r, [$px + $nx * $hw, $py + $ny * $hw]; push @m, [$px, $py];
  }
  my $tip = [$x + $dx * $len * 1.06, $y + $dy * $len * 1.06];
  my $leftLit = lit(-$nx, -$ny);
  poly($leftLit ? $L : $D, @l, $tip, reverse @m);
  poly($leftLit ? $D : $L, @r, $tip, reverse @m);
}

# A mangosteen. %o: top (seen from above), unripe, dead, ry, cap (size factor), stalk.
sub mfruit {
  my ($x, $y, $r, %o) = @_;
  my ($B, $D, $H) = $o{unripe} ? ('c2', 'c1', 'c3') : $o{dead} ? ('c4', 'c4', 'c5') : ('c5', 'c4', 'c3');
  my $ry = $o{ry} // ($o{top} ? $r : $r * 0.92);
  my $cap = $o{cap} // ($o{top} ? 1.35 : 1); my $rot = $o{rot} // 0;
  my @o = ell($x, $y, $r, $ry, 28);
  poly($B, @o);
  crescent($D, $x, $y, 0.74, $r * 0.1, @o);
  unless ($o{dead}) {
    # glossy window highlight on the upper left
    my ($hx, $hy) = $o{top} ? ($x - $r * 0.5, $y - $r * 0.42) : ($x - $r * 0.52, $y - $ry * 0.2);
    poly($H, [$hx - $r * 0.12, $hy + $r * 0.16], [$hx - $r * 0.06, $hy - $r * 0.12], [$hx + $r * 0.12, $hy - $r * 0.2], [$hx + $r * 0.02, $hy + $r * 0.04]);
    poly($H, ell($hx + $r * 0.2, $hy - $r * 0.22, $r * 0.05, $r * 0.05, 6)) if $r > 14;
  }
  my ($cl, $cd) = $o{dead} ? ('c3', 'c5') : ('c2', 'c1');
  if ($o{top}) {
    # four thick sepals in a cross round the stalk, then the stalk stub
    for my $k (0 .. 3) { sepal($x, $y, $rot + 45 + $k * 90, $r * 0.5 * $cap, $r * 0.42 * $cap, $cl, $cd); }
    poly($cd, ell($x + 1, $y + 1, $r * 0.13, $r * 0.13, 8)); poly($cl, ell($x - 0.6, $y - 0.6, $r * 0.08, $r * 0.08, 7));
  } else {
    # front view: the cap sits on the top, sepals curving down over the shoulders, short thick stalk above
    my $ty = $y - $ry * 0.84;
    blade($x + 1, $ty - $r * 0.02, -90 + ($o{lean} // 6), $o{stalk} // $r * 0.34, $r * 0.13, 10, $cl, $cd, 0.25);
    for my $a (150, 30) { my ($dx, $dy) = dir($a); sepal($x + $dx * $r * 0.1, $ty, $a, $r * 0.42 * $cap, $r * 0.32 * $cap, $cl, $cd); }
    for my $a (118, 62) { my ($dx, $dy) = dir($a); sepal($x, $ty - $r * 0.02, $a, $r * 0.42 * $cap, $r * 0.36 * $cap, $cl, $cd); }
    poly($cd, ell($x, $ty, $r * 0.16, $r * 0.06, 8));
    # flower-like scar at the base
    if ($o{scar}) {
      my $by = $y + $ry * 0.8;
      for my $k (0 .. 5) { my ($dx, $dy) = dir($k * 60 + 15); poly($o{dead} ? 'c5' : 'c4', ell($x + $dx * $r * 0.07, $by + $dy * $r * 0.03, $r * 0.06, $r * 0.03, 6, $k * 60 + 15)); }
    }
  }
}

# Opened mangosteen, front view: the bottom of the thick purple rind as a cup, the white segments standing in it.
sub mopen {
  my ($x, $y, $r, $nseg) = @_;
  my $rr = $r * 0.5;
  # cup outer wall (lower half of the fruit): dark glossy skin
  my @wall = (map { my ($u, $v) = dir($_ * 10); [$x + $u * $r, $y + $v * $r * 0.84] } 0 .. 18);
  poly('c5', @wall);
  crescent('c4', $x, $y, 0.66, $r * 0.12, @wall, map { my ($u, $v) = dir($_ * 10); [$x + $u * $r, $y + $v * $rr] } reverse 0 .. 18);
  poly('c3', [$x - $r * 0.8, $y + $r * 0.3], [$x - $r * 0.72, $y + $r * 0.24], [$x - $r * 0.46, $y + $r * 0.6], [$x - $r * 0.54, $y + $r * 0.62]);
  # the cut rim: a thick purple ring of rind
  poly('c5', ell($x, $y, $r, $rr, 32));
  my ($iw, $ih) = ($r * 0.74, $rr * 0.72);
  poly('c4', ell($x, $y - $rr * 0.04, $iw, $ih, 32));
  # the white segments: a flower of plump cloves radiating from the middle, standing a little proud of the rim
  my ($cx, $cy) = ($x, $y - $rr * 0.3);
  my $lift = $r * 0.12;
  my @lobes;
  for my $k (0 .. $nseg - 1) {
    my $am = 360 * ($k + 0.5) / $nseg + 10; my $hw = 180 / $nseg * 0.9;
    my (@L, @R);
    for my $i (0 .. 10) {
      my $rho = 0.06 + 0.93 * $i / 10; my $wa = $hw * sin(pi * min(1, 0.1 + $rho * 0.9)) ** 0.3;
      for my $sd ([-1, \@L], [1, \@R]) {
        my ($u, $v) = dir($am + $sd->[0] * $wa);
        push @{$sd->[1]}, [$cx + $u * $rho * $iw, $cy + $v * $rho * $ih - $lift * (1 - $rho * $rho)];
      }
    }
    my ($u, $v) = dir($am);
    push @lobes, [$v - $u * 0.2, \@L, \@R, $am];
  }
  for (sort { $a->[0] <=> $b->[0] } @lobes) {
    my (undef, $L, $R, $am) = @$_;
    poly("c3", @$L, reverse @$R);
    my $l = -cos(deg2rad($am)) - sin(deg2rad($am));
    my $sideR = (cos(deg2rad($am + 90)) + sin(deg2rad($am + 90))) > 0;   # which edge faces away from the light
    my $E = $sideR ? $R : $L;
    poly("c5", @$E[2 .. 10], map { [($E->[$_][0] * 0.7 + ($L->[$_][0] + $R->[$_][0]) / 2 * 0.3), ($E->[$_][1] * 0.7 + ($L->[$_][1] + $R->[$_][1]) / 2 * 0.3)] } reverse 2 .. 10) if $l < 0.2;
  }
  # the near rim over the cloves' outer feet
  my @rim = map { my ($u, $v) = dir($_ * 10); [$x + $u * $r, $y + $v * $rr] } 0 .. 18;
  my @rin = map { my ($u, $v) = dir($_ * 10); [$x + $u * $iw, $y - $rr * 0.04 + $v * $ih] } reverse 0 .. 18;
  poly('c5', @rim, @rin);
}

# Flat mangosteen seed with a clinging white fibre on one side.
sub mseed {
  my ($x, $y, $ang, $len, $w, $fl) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o = map { my $th = 2 * pi * $_ / 16; my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 - 0.2 * cos($th)); [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v] } 0 .. 15;
  poly("c4", @o);
  my $sg = lit($nx, $ny) ? 1 : -1;
  my @dk = $sg > 0 ? @o[1 .. 7] : @o[9 .. 15];
  poly("c5", @dk, map { [$x + ($_->[0] - $x) * 0.5, $y + ($_->[1] - $y) * 0.5] } reverse @dk);
  my @lt = $sg > 0 ? @o[1 .. 7] : @o[9 .. 15];
  poly('c3', @lt, map { [$x + ($_->[0] - $x) * 0.62 + $nx * $sg * $w * 0.06, $y + ($_->[1] - $y) * 0.62 + $ny * $sg * $w * 0.06] } reverse @lt) if $fl;
}

# A single white flesh segment (clove), front view.
sub clove {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 17) { my $th = 2 * pi * $i / 18; my $u = cos($th); my $v = sin($th) * (1 - 0.35 * max(0, $u));
    push @o, [$x + $dx * $u * $len / 2 + $nx * $v * $w / 2, $y + $dy * $u * $len / 2 + $ny * $v * $w / 2]; }
  poly('c3', @o);
  crescent('c5', $x, $y, 0.86, 0, @o);
}

# Mangosteen flower from above: four thick rounded cream petals with rosy edges round a pale stigma.
sub mflower {
  my ($x, $y, $r, $rot) = @_;
  for my $k (0 .. 3) { sepal($x, $y, $rot + $k * 90, $r * 0.7, $r * 0.55, 'c2', 'c1'); }
  for my $k (0 .. 3) {
    my $a = $rot + 45 + $k * 90; my ($dx, $dy) = dir($a);
    my @p = ell($x + $dx * $r * 0.5, $y + $dy * $r * 0.5, $r * 0.5, $r * 0.42, 10, $a);
    poly('c5', @p); poly('c3', map { [$x + $dx * $r * 0.44 + ($_->[0] - $x - $dx * $r * 0.5) * 0.8, $y + $dy * $r * 0.44 + ($_->[1] - $y - $dy * $r * 0.5) * 0.8] } @p);
  }
  poly('c2', ell($x, $y, $r * 0.24, $r * 0.24, 8)); poly('c3', ell($x - 1, $y - 1, $r * 0.1, $r * 0.1, 6));
}

# ---------------------------------------------------------------------------------------------
# 1. Planting material, front view: flat seeds (one still wrapped in white fibre) in front of a whole mangosteen.
mfruit(236, 168, 82, scar => 0, cap => 1.3);
mseed(128, 288, -28, 66, 46, 1); mseed(204, 312, 6, 70, 48, 0); mseed(278, 296, 34, 64, 44, 1);
write_svg('1-seeds-front.svg', 'Mangosteen seeds');

# 2. Just sown, top down: flat seeds with clinging white fibre pressed into soil pockets.
my @sown = ([168, 172, -30], [238, 176, 40], [198, 236, 100]);
for (@sown) { soil($_->[0], $_->[1], 34, 28, int($_->[0] * 7 + $_->[1])); }
for (@sown) { mseed($_->[0], $_->[1], $_->[2], 38, 26, 1); }
write_svg('2-sown.svg', 'Mangosteen just sown');

# 3. First growth, top down: a seedling with a few big thick glossy leaves.
soil(200, 200, 34, 30, 3);
blade(200, 200, -120, 16, 6, 0, 'c1', 'c4', 0.5);
oleaf(200, 200, -64, 84, 40, 8, 'c2', 'c1', veins => 3); oleaf(200, 200, 116, 80, 38, -8, 'c2', 'c1', veins => 3);
oleaf(200, 200, -168, 56, 28, 6, 'c2', 'c1'); oleaf(200, 200, 26, 58, 28, -6, 'c2', 'c1');
write_svg('3-first-growth.svg', 'Mangosteen first growth');

# 4. Second growth, top down: young bush of big glossy leaves.
soil(200, 200, 34, 30, 4);
bush(seed => 41, n => 5, len => 66, per => 2, leaf => 58, wf => 0.48, start => -80, bw => 8, lo => { veins => 3 });
write_svg('4-second-growth.svg', 'Mangosteen second growth');

# 5. Third growth, top down: full bush with thick-petalled flowers and small green capped fruit.
soil(200, 200, 34, 30, 5);
{
  my @br = bush(seed => 51, n => 7, len => 94, per => 2, leaf => 66, wf => 0.48, start => -84, bw => 9, lo => { veins => 3 });
  my $j = 0;
  for my $bb (@br) {
    my ($x, $y, $ba) = walk(200, 200, @$bb, 0.62); $j++;
    my ($dx, $dy) = dir($ba + ($j % 2 ? 60 : -60));
    if ($j % 2) { mflower($x + $dx * 12, $y + $dy * 12, 17, $j * 23); }
    else { mfruit($x + $dx * 14, $y + $dy * 14, 12, top => 1, unripe => 1, rot => $j * 17); }
  }
  mflower(198, 196, 15, 20);
}
write_svg('5-third-growth.svg', 'Mangosteen third growth, flowering');

# 6. Harvest, top down: the bush hung with round purple mangosteens wearing green caps.
soil(200, 200, 34, 30, 6);
{
  my @br = bush(seed => 61, n => 8, len => 112, per => 2, leaf => 70, wf => 0.48, start => -76, bw => 10, lo => { veins => 3 });
  my $j = 0; my @f;
  for my $bb (@br) { $j++; push @f, [walk(200, 200, @$bb, $j % 2 ? 0.85 : 0.42), $j] if $j % 2 || $j == 4; }
  # big glossy fruit: cast shadow on the leaves, a short stalk from the branch, then the capped fruit
  for (@f) { my ($x, $y, $ba, $k) = @$_; my $r = $k == 4 ? 30 : 36; poly('c1', ell($x + 8, $y + 9, $r + 2, $r + 2, 20)); }
  for (@f) {
    my ($x, $y, $ba, $k) = @$_; my ($dx, $dy) = dir($ba); my $r = $k == 4 ? 30 : 36;
    blade($x - $dx * ($r + 14), $y - $dy * ($r + 14), $ba, $r + 14, 6, 0, 'c2', 'c1', 0.4);
    mfruit($x, $y, $r, top => 1, rot => $k * 29, cap => 1.0);
  }
}
write_svg('6-harvest.svg', 'Mangosteens ready to harvest');

# 7. Harvested produce, front view: one whole mangosteen with its cap, one with the top of the rind lifted off.
mfruit(146, 168, 84, scar => 1, lean => -8, cap => 1.3);
mopen(258, 278, 92, 6);
write_svg('7-harvest-front.svg', 'Harvested mangosteens');

# 8. Dead (never watered), top down: cracked dry soil, bare branches, curled dry leaves, a shrivelled dark fruit.
soil(200, 200, 66, 56, 8);
cracks(8, 83, 14, 'c3');
{
  srand(84);
  my @br;
  for my $i (0 .. 4) { push @br, [-80 + $i * 72 + rand(14) - 7, 86 + rand(30), (rand(1) < 0.5 ? -1 : 1) * (30 + rand(30))]; }
  blade(200, 200, $_->[0], $_->[1], 8, $_->[2], 'c3', 'c4', 0.7) for @br;
  my $j = 0;
  for my $bb (@br) {
    for my $t (0.4, 0.75) {
      my ($px, $py, $pa) = walk(200, 200, @$bb, $t); my $s = ($j++ % 2) ? 1 : -1;
      oleaf($px, $py, $pa + $s * (60 + rand(30)), 56 + rand(10), 20 + rand(4), $s * (40 + rand(40)), 'c3', 'c4', noglint => 1);
    }
  }
  my ($px, $py) = walk(200, 200, @{$br[2]}, 0.6);
  mfruit($px + 14, $py, 14, top => 1, dead => 1, ry => 12);
}
write_svg('8-dead.svg', 'Mangosteen died from lack of water');
print "wrote 8 files to $OUT\n";

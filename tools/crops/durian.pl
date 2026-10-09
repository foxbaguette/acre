# Durian crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/durian.pl
# Grown as a compact bush. Top-down stages (2-6, 8) share one fixed scale centred on (200,200).
# Signature: big olive-green to yellow-brown oval fruit armoured in sharp pyramid thorns, hanging from thick branches;
# inside, pale yellow custard pods.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/durian';
mkdir 'crops'; mkdir $OUT;
# c1 leaf green, c2 lit green, c3 pale custard yellow (pods, lit thorn faces, flowers, dried leaves), c4 dark soil / shade,
# c5 durian husk olive-khaki (also woody stalks)
my %PAL = (c1 => '#35662E', c2 => '#86B347', c3 => '#F2DC84', c4 => '#4C3520', c5 => '#C49A36');
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


# A durian: an oval husk covered edge to edge in faceted pyramid thorns, sharp spikes around the silhouette.
# %o: rot (long axis), s (thorn size), cut (fraction 0..1 of the height where the top is sliced off), stem, unripe.
sub durian {
  my ($x, $y, $rx, $ry, %o) = @_;
  my $rot = $o{rot} // 0; my $s = $o{s} // $rx * 0.3;
  my ($B, $Lc, $Dc) = $o{unripe} ? ("c2", "c3", "c1") : ('c5', 'c3', 'c4');
  my $BD = $o{unripe} ? "c1" : "c4"; my $Mc = $o{unripe} ? "c1" : "c4"; my $Gc = "c1"; ($Lc, $Gc) = ("c5", "c4") if $o{dead};
  my ($cr, $sr) = (cos(deg2rad($rot)), sin(deg2rad($rot)));
  my $E = sub { my ($u, $v) = @_; [$x + $u * $cr - $v * $sr, $y + $u * $sr + $v * $cr] };
  my $cut = $o{cut}; my ($cw, $ch, $cy);
  if (defined $cut) { $cy = -$ry + 2 * $ry * $cut; $cw = $rx * sqrt(max(0, 1 - ($cy / $ry) ** 2)); $ch = $cw * 0.34; }
  my $above = sub { my ($u, $v) = @_; return 0 unless defined $cut; my $k = 1 - ($u / $cw) ** 2; return 1 if $k <= 0 && $v < $cy; $v < $cy + ($k > 0 ? $ch * sqrt($k) * 0.2 : 0) };
  # stalk behind (front view: rising from the top)
  if ($o{stem} && !defined $cut) {
    my $p = $E->(0, -$ry * 0.86);
    blade(@$p, $rot - 90 + ($o{stemBend} // 0) / 2, $o{stem}, $rx * 0.26, $o{stemBend} // 0, 'c5', 'c4', 0.3);
  }
  if ($o{topstem}) { my ($sx, $sy, $sa, $sl) = @{$o{topstem}}; blade($sx, $sy, $sa, $sl, $rx * 0.3, 0, "c5", "c4", 0.25); }
  # spikes around the silhouette
  my $n = max(12, int(2 * pi * sqrt(($rx * $rx + $ry * $ry) / 2) / ($s * 0.95)));
  for my $k (0 .. $n - 1) {
    my $th = 360 * ($k + 0.5) / $n; my ($u, $v) = dir($th); my $h = 360 / $n / 2 * 0.9;
    next if $above->($u * $rx, $v * $ry);
    my ($u0, $v0) = dir($th - $h); my ($u1, $v1) = dir($th + $h);
    my $a = $E->($u0 * $rx * 0.9, $v0 * $ry * 0.9); my $b = $E->($u1 * $rx * 0.9, $v1 * $ry * 0.9);
    my $m = $E->($u * $rx * 0.86, $v * $ry * 0.86);
    my $t = $E->($u * ($rx + $s * 0.55), $v * ($ry + $s * 0.55));
    my $oa = rad2deg(atan2($v * $rx * $cr + $u * $ry * $sr, $u * $ry * $cr - $v * $rx * $sr));
    my $l = cos(deg2rad($oa)) * -0.7071 + sin(deg2rad($oa)) * -0.7071;
    my ($c0, $c1) = $l > 0.35 ? ($Lc, $B) : $l > -0.35 ? ($B, $Mc) : ($Mc, $Dc);
    # a = clockwise-earlier edge: decide which half faces the light
    my $aLit = ((($a->[0] - $m->[0]) * -0.7071 + ($a->[1] - $m->[1]) * -0.7071) > (($b->[0] - $m->[0]) * -0.7071 + ($b->[1] - $m->[1]) * -0.7071));
    poly($aLit ? $c0 : $c1, $a, $t, $m); poly($aLit ? $c1 : $c0, $b, $t, $m);
  }
  # body
  my @o = map { my ($u, $v) = dir($_ * 10); $E->($u * $rx, $v * $ry) } 0 .. 35;
  if (defined $cut) { @o = map { my ($u, $v) = dir($_ * 5); $E->($u * $rx, max($cy, $v * $ry)) } 0 .. 71; }
  poly($B, @o);
  { my $N = @o; my @on = grep { my ($u, $v) = dir($_ * 360 / $N + $rot); ($u * 0.7071 + $v * 0.7071) > 0.2 } 0 .. $N - 1;
    my %on = map { $_ => 1 } @on; my ($st) = grep { $on{$_} && !$on{($_ + $N - 1) % $N} } 0 .. $N - 1; $st //= 0;
    my @shp; for my $j (0 .. $N - 1) { my $i = ($st + $j) % $N; last unless $on{$i}; push @shp, $o[$i]; }
    poly($Mc, @shp, map { [$x + ($_->[0] - $x) * 0.8 + $rx * 0.08, $y + ($_->[1] - $y) * 0.8 + $rx * 0.08] } reverse @shp); }
  # pyramid thorns tiling the husk (hexagonal bases), far ones first
  my @d; my $row = 0; my $hs = $s * 0.87;
  for (my $gv = -$ry; $gv <= $ry + 0.01; $gv += $hs) {
    for (my $gu = -$rx - ($row % 2 ? $s / 2 : 0); $gu <= $rx + 0.01; $gu += $s) {
      my $r2 = ($gu / $rx) ** 2 + ($gv / $ry) ** 2; next if $r2 > 0.86;
      next if $above->($gu, $gv - $s * 0.3);
      push @d, [$gu, $gv, $r2];
    }
    $row++;
  }
  for (sort { $b->[2] <=> $a->[2] } @d) {
    my ($gu, $gv, $r2) = @$_; my $z = sqrt(max(0.05, 1 - $r2));
    my $rl = sqrt($r2) || 1e-6; my ($ru, $rv) = ($gu / $rx / $rl, $gv / $ry / $rl);   # radial direction (local)
    my $fk = max(0.4, $z ** 0.7);
    my $sh = ($gu / $rx + $gv / $ry) * 0.7071 > 0.42;
    my @c;
    for my $k (0 .. 5) {
      my ($cu, $cv) = dir(30 + $k * 60); $cu *= $s * ($o{hex} // 0.6); $cv *= $s * ($o{hex} // 0.6);
      my $pr = $cu * $ru + $cv * $rv; my $pt = -$cu * $rv + $cv * $ru;   # radial / tangential parts
      $pr *= $fk;
      push @c, $E->($gu + $pr * $ru - $pt * $rv, $gv + $pr * $rv + $pt * $ru);
    }
    my $ap = $E->($gu + $ru * $s * 0.22 * (1 - $z), $gv + $rv * $s * 0.22 * (1 - $z));
    my @L; my $best = 0;
    for my $k (0 .. 5) {
      my ($p, $q) = ($c[$k], $c[($k + 1) % 6]);
      my $fx = ($p->[0] + $q->[0]) / 2 - $ap->[0]; my $fy = ($p->[1] + $q->[1]) / 2 - $ap->[1];
      my $d = sqrt($fx * $fx + $fy * $fy) || 1;
      $L[$k] = ($fx * -0.7071 + $fy * -0.7071) / $d * 0.8 + ($z - 0.6) * 0.4;
      $best = $k if $L[$k] > $L[$best];
    }
    for my $k (0 .. 5) {
      my $l = $L[$k];
      my $cls = ($k == $best && $l > 0.3) ? $Lc : $l > -0.32 ? $B : $l > -0.62 ? $Gc : $Dc;
      $cls = {$Lc => $B, $B => $Gc, $Gc => $Dc, $Dc => $Dc}->{$cls} if $sh;
      poly($cls, $c[$k], $c[($k + 1) % 6], $ap);
    }
  }
  # stalk on top (seen from above it enters the middle of the fruit)
  if ($o{topstem}) {
    my ($sx, $sy, $sa, $sl) = @{$o{topstem}};
    poly('c4', ell($x + 1, $y + 1, $rx * 0.2, $rx * 0.2, 8)); poly('c5', ell($x - 1, $y - 1, $rx * 0.13, $rx * 0.13, 8));
  }
  return unless defined $cut;
  # sliced top: pale husk wall ring, dark hollow, then the custard pods nestled inside
  my $cc = $E->(0, $cy);
  poly('c3', ell($cc->[0], $cc->[1], $cw, $ch, 28, $rot));
  my ($iw, $ih) = ($cw * 0.84, $ch * 0.74);
  poly('c4', ell($cc->[0], $cc->[1] + $ch * 0.06, $iw, $ih, 28, $rot));
  my @pods = @{$o{pods} // []};
  for my $p (@pods) {
    my ($pu, $pv, $pw, $ph) = @$p; my $c = $E->($pu * $iw, $cy + $pv * $ih);
    pod($c->[0], $c->[1], $pw * $rx, $ph * $rx, $p->[4]);
  }
  # near lip of the wall over the pods' feet
  my @fr = map { my ($u, $v) = dir($_ * 10); [$cc->[0] + $u * $cw, $cc->[1] + $v * $ch] } 0 .. 18;
  my @fi = map { my ($u, $v) = dir($_ * 10); [$cc->[0] + $u * $iw, $cc->[1] + $ch * 0.06 + $v * $ih] } reverse 0 .. 18;
  poly('c3', @fr, @fi);
}

# A custard pod (aril): a plump pale yellow pillow of soft lobes, shaded on its lower right, creases between lobes.
sub pod {
  my ($x, $y, $w, $h, $nl) = @_; $nl //= 3;
  my @o;
  for my $i (0 .. 35) {
    my $th = $i * 10; my ($u, $v) = dir($th);
    my $k = 1 + 0.07 * abs(sin(deg2rad($th * $nl / 2)));
    push @o, [$x + $u * $w * $k, $y + $v * $h * $k];
  }
  poly("c4", map { [$_->[0] + 3, $_->[1] + 3] } @o);
  poly("c3", @o);
  my @sh = @o[33 .. 35, 0 .. 15];
  poly("c5", @sh, map { [$x + ($_->[0] - $x) * 0.7 + $w * 0.1, $y + ($_->[1] - $y) * 0.62 + $h * 0.12] } reverse @sh);
  for my $c (1 .. $nl - 1) {          # creases dividing the lobes
    my $u = -1 + 2 * $c / $nl; my $cx = $x + $u * $w * 0.95;
    my $hh = $h * sqrt(max(0.1, 1 - $u * $u));
    poly("c5", [$cx - 1.4, $y - $hh * 0.85], [$cx + $w * 0.06, $y], [$cx - 1.4, $y + $hh * 0.85], [$cx - $w * 0.03, $y]);
  }
}

# Durian seed: big glossy brown oval seed.
sub dseed {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 19) { my $th = 2 * pi * $i / 20; my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 - 0.1 * cos($th));
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v]; }
  poly('c4', @o);
  my $leftLit = lit($nx, $ny); my $sg = $leftLit ? 1 : -1;
  my @half = $leftLit ? @o[1 .. 9] : @o[11 .. 19];
  poly('c5', @half, map { [$x + ($_->[0] - $x) * 0.5 + $nx * $sg * $w * 0.06, $y + ($_->[1] - $y) * 0.5 + $ny * $sg * $w * 0.06] } reverse @half);
  my ($gx, $gy) = ($x + $nx * $sg * $w * 0.22 - $dx * $len * 0.08, $y + $ny * $sg * $w * 0.22 - $dy * $len * 0.08);
  poly('c3', [$gx - $dx * $len * 0.2, $gy - $dy * $len * 0.2], [$gx + $nx * $sg * $w * 0.06, $gy + $ny * $sg * $w * 0.06], [$gx + $dx * $len * 0.14, $gy + $dy * $len * 0.14], [$gx - $nx * $sg * $w * 0.04, $gy - $ny * $sg * $w * 0.04]);
}

# Durian flower cluster seen from above: creamy cupped petals with a brush of long stamens.
sub dflower {
  my ($x, $y, $r, $rot) = @_;
  for my $k (0 .. 4) {
    my $a = $rot + $k * 72; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    my @p = map { [$x + ($dx * $_->[0] + $nx * $_->[1]) * $r, $y + ($dy * $_->[0] + $ny * $_->[1]) * $r] } ([0.1, 0], [0.5, 0.36], [1, 0.22], [1.05, 0], [1, -0.22], [0.5, -0.36]);
    poly('c3', @p);
    poly(lit($dx, $dy) ? 'c3' : 'c5', @p[0, 4, 5]) unless lit($dx, $dy);
  }
  for my $k (0 .. 8) { my ($dx, $dy) = dir($rot + 20 + $k * 40); blade($x, $y, $rot + 20 + $k * 40, $r * 0.7, 2, 0, 'c3', 'c5'); poly('c5', ell($x + $dx * $r * 0.72, $y + $dy * $r * 0.72, 2.2, 2.2, 6)); }
  poly('c2', ell($x, $y, $r * 0.22, $r * 0.22, 7));
}

# ---------------------------------------------------------------------------------------------
# 1. Planting material, front view: a custard pod behind three big glossy durian seeds.
durian(236, 168, 84, 96, rot => 14, s => 27, stem => 26, stemBend => 10);
dseed(140, 262, -30, 92, 60); dseed(262, 266, 205, 92, 60); dseed(200, 296, -2, 96, 62);
write_svg('1-seeds-front.svg', 'Durian seeds');

# 2. Just sown, top down: big seeds pressed into soil pockets.
my @sown = ([168, 172, -30], [238, 176, 40], [198, 236, 100]);
for (@sown) { soil($_->[0], $_->[1], 36, 30, int($_->[0] * 7 + $_->[1])); }
for (@sown) { dseed($_->[0], $_->[1], $_->[2], 48, 32); }
write_svg('2-sown.svg', 'Durian just sown');

# 3. First growth, top down: a sapling with a few long glossy leaves.
soil(200, 200, 34, 30, 3);
blade(200, 200, -120, 18, 7, 0, 'c5', 'c4', 0.5);
oleaf(200, 200, -70, 90, 32, 10, 'c2', 'c1'); oleaf(200, 200, 110, 86, 30, -12, 'c2', 'c1');
oleaf(200, 200, -175, 70, 26, 8, 'c2', 'c1'); oleaf(200, 200, 25, 72, 26, -8, 'c2', 'c1');
write_svg('3-first-growth.svg', 'Durian first growth');

# 4. Second growth, top down: young bush.
soil(200, 200, 34, 30, 4);
bush(seed => 41, n => 6, len => 72, per => 2, leaf => 56, wf => 0.36, start => -80, bw => 9, blight => 'c5', lo => { veins => 3 });
write_svg('4-second-growth.svg', 'Durian second growth');

# 5. Third growth, top down: full bush with creamy flower clusters and the first small thorny fruit.
soil(200, 200, 34, 30, 5);
{
  my @br = bush(seed => 51, n => 8, len => 98, per => 3, leaf => 60, wf => 0.36, start => -84, bw => 10, blight => 'c5', lo => { veins => 3 });
  my $j = 0;
  for my $bb (@br) {
    my ($x, $y, $ba) = walk(200, 200, @$bb, 0.6); $j++;
    my ($dx, $dy) = dir($ba);
    if ($j % 3 == 0) { durian($x + $dx * 6, $y + $dy * 6, 15, 17, rot => $ba + 90, unripe => 1, s => 6.5, topstem => [$x - $dx * 14, $y - $dy * 14, $ba, 20]); }
    else { dflower($x + $dx * 4 - $dy * 10, $y + $dy * 4 + $dx * 10, 14, $j * 23); dflower($x + $dx * 12 + $dy * 10, $y + $dy * 12 - $dx * 10, 12, $j * 41); }
  }
}
write_svg('5-third-growth.svg', 'Durian third growth, flowering');

# 6. Harvest, top down: the bush hung with big ripe thorny durians.
soil(200, 200, 34, 30, 6);
{
  my @br = bush(seed => 61, n => 8, len => 116, per => 3, leaf => 62, wf => 0.36, start => -76, bw => 11, blight => 'c5', lo => { veins => 3 });
  my $j = 0; my @f;
  for my $bb (@br) {
    $j++; next unless $j % 2 == 0;
    my ($x, $y, $ba) = walk(200, 200, @$bb, 0.82);
    push @f, [$x, $y, $ba];
  }
  # big ripe fruit hanging under the branches: cast shadow on the leaves, stalk from the branch, then the fruit
  for (@f) { my ($x, $y, $ba) = @$_; poly('c1', ell($x + 9, $y + 10, 40, 43, 20)); }
  for (@f) {
    my ($x, $y, $ba) = @$_; my ($dx, $dy) = dir($ba);
    durian($x, $y, 37, 41, rot => $ba + 90, s => 13.5, topstem => [$x - $dx * 50, $y - $dy * 50, $ba, 50]);
  }
}
write_svg('6-harvest.svg', 'Durians ready to harvest');

# 7. Harvested produce, front view: a whole durian on its stalk and one opened to show the custard pods.
durian(150, 182, 96, 116, rot => -12, s => 30, stem => 34, stemBend => -12);
durian(258, 270, 104, 84, rot => 6, s => 28, cut => 0.36,
       pods => [[-0.36, -0.42, 0.42, 0.24, 2], [0.4, -0.36, 0.4, 0.23, 2]]);
write_svg('7-harvest-front.svg', 'Harvested durians');

# 8. Dead (never watered), top down: cracked dry soil, bare branches, curled dry leaves, a shrivelled brown fruit.
soil(200, 200, 66, 56, 8);
cracks(8, 83, 14, 'c3');
{
  srand(84);
  my @br;
  for my $i (0 .. 5) { push @br, [-80 + $i * 60 + rand(14) - 7, 86 + rand(30), (rand(1) < 0.5 ? -1 : 1) * (30 + rand(30))]; }
  blade(200, 200, $_->[0], $_->[1], 9, $_->[2], 'c5', 'c4', 0.7) for @br;
  my $j = 0;
  for my $bb (@br) {
    for my $t (0.35, 0.62, 0.9) {
      my ($px, $py, $pa) = walk(200, 200, @$bb, $t); my $s = ($j++ % 2) ? 1 : -1;
      oleaf($px, $py, $pa + $s * (60 + rand(30)), 50 + rand(10), 14 + rand(4), $s * (40 + rand(40)), 'c3', 'c5', noglint => 1);
    }
  }
  my ($px, $py) = walk(200, 200, @{$br[2]}, 0.7);
  durian($px, $py, 17, 14, rot => 30, s => 7, dead => 1);
}
write_svg('8-dead.svg', 'Durian died from lack of water');
print "wrote 8 files to $OUT\n";

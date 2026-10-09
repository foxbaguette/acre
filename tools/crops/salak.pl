# Snake fruit (salak) crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/salak.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Salak is a stemless, very spiny palm: long pinnate fronds rise from the ground in a clump and the
# teardrop fruits, clad in red-brown overlapping snake-like scales, sit in tight clusters at the base.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/salak';
mkdir 'crops'; mkdir $OUT;
# c1 palm green, c2 lit green, c3 ivory (flesh, spines, glints, dried fronds), c4 dark brown (soil, scale gaps), c5 salak red-brown
my %PAL = (c1 => '#2F6638', c2 => '#6FA851', c3 => '#F5EAD0', c4 => '#4A2419', c5 => '#A8432B');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A tapered blade or stalk from (x,y) heading `ang`, bending `bend` degrees (as in wheat.pl). $taper < 1 = blunt end.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $taper) = @_;
  $taper //= 1;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $t) ** 0.85 + ($i == $n && $taper == 1 ? 0 : 0.6);
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

# Lanceolate leaflet: widest a third of the way out, long drawn-out drooping tip; lit and shaded halves.
sub leaflet {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark) = @_;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $i == $n ? 0 : $w / 2 * sin(pi * min(1, $t / 0.7) * 0.5 + ($t > 0.35 ? 0 : 0)) ** 0.6 * (1 - $t) ** 0.55 * 1.5;
    $hw = 1 if $i == 0;
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n * (0.4 + 1.2 * $t);
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# Point and heading along a bent path at fraction $upto (same stepping as blade).
sub walk {
  my ($x, $y, $ang, $len, $bend, $upto) = @_; $upto //= 1;
  my $n = 40; my $a = $ang;
  for my $i (1 .. int($n * $upto + 0.5)) { my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  return ($x, $y, $a);
}

# Needle spines: thin pale triangles standing out from both edges of a stalk between fractions t0..t1.
sub spines {
  my ($x, $y, $ang, $len, $bend, $t0, $t1, $n, $slen, $sw, $cls) = @_;
  for my $k (0 .. $n - 1) {
    my $t = $t0 + ($t1 - $t0) * ($k + 0.5) / $n;
    my ($px, $py, $a) = walk($x, $y, $ang, $len, $bend, $t);
    for my $s (-1, 1) {
      my $sa = $a + $s * (62 + ($k * 37 % 20)); my ($dx, $dy) = dir($sa); my ($ax, $ay) = dir($a);
      my $l = $slen * (0.75 + 0.5 * (($k * 53 + ($s + 1) * 17) % 10) / 10);
      my ($bx, $by) = ($px + $dx * $sw, $py + $dy * $sw);
      poly($cls // 'c3', [$bx - $ax * 1.3, $by - $ay * 1.3], [$bx + $dx * $l, $by + $dy * $l], [$bx + $ax * 1.3, $by + $ay * 1.3]);
    }
  }
}

# A pinnate salak frond seen from above: spiny petiole, then pairs of drooping lanceolate leaflets along a
# curving rachis. $lf scales the leaflet size; $wilt crumples it (dead stage).
sub frond {
  my ($x, $y, $ang, $len, $bend, $light, $dark, $lf, $wilt, $seed) = @_;
  $lf //= 1; $wilt //= 0; srand($seed // int($ang * 7 + $len));
  my $n = int(3 + $len / 30);
  my @lv;
  for my $k (0 .. $n - 1) {
    my $t = 0.26 + 0.7 * $k / ($n - 1);
    my ($px, $py, $a) = walk($x, $y, $ang, $len, $bend, $t);
    my $ll = $len * 0.44 * $lf * (0.45 + 0.55 * sin(pi * min(1, 0.25 + 0.9 * (1 - $t)))) * (0.9 + rand(0.2));
    for my $s (-1, 1) {
      my $la = $a + $s * (42 - 12 * $t + rand(10) - 5 + $wilt * (rand(40) - 10));
      push @lv, [$px, $py, $la, $ll * (1 - $wilt * rand(0.35)), $ll * (0.3 - 0.1 * $wilt), $s * (22 + rand(16) + $wilt * 50)];
    }
  }
  my ($tx, $ty, $ta) = walk($x, $y, $ang, $len, $bend, 1);   # terminal leaflet pair, a little fishtail
  for my $s (-1, 1) { push @lv, [$tx, $ty, $ta + $s * 16, $len * 0.2 * $lf, $len * 0.07 * $lf, $s * 14]; }
  leaflet(@$_, $light, $dark) for @lv;
  blade($x, $y, $ang, $len * 1.02, max(3, $len * 0.05), $bend, $light eq 'c3' ? 'c3' : 'c2', $dark eq 'c4' ? 'c4' : 'c1', 0.75);
  spines($x, $y, $ang, $len, $bend, 0.08, 0.6, int(4 + $len / 18), $len * 0.085, $len * 0.022, $wilt ? 'c4' : 'c3') if $len > 50;
}

# Surface shading: n = (x, y-down, z-toward-viewer); light from the upper left and the front.
sub shade {
  my ($nx, $ny, $nz) = @_; my $l = sqrt($nx * $nx + $ny * $ny + $nz * $nz) || 1;
  my $b = ($nx * -0.55 + $ny * -0.55 + $nz * 0.63) / $l;
  return $b > 0.86 ? "c3" : $b > -0.12 ? 'c5' : 'c4';
}

# Salak fruit: teardrop with its pointed tip at heading `ang` from the centre (cx,cy), length H, width W,
# covered in rows of overlapping pointed scales, each a two-faced shield with a dark spine line at its tip.
# $from limits the scales/outline to u >= $from (u: 0 tip .. 1 base) for the peeled fruit's skin cup.
sub sfruit {
  my ($cx, $cy, $ang, $H, $W, $from, $shr) = @_;
  $from //= 0; $shr //= 0;
  my ($ax, $ay) = dir($ang); my ($bx, $by) = (-$ay, $ax);        # a: toward the tip, b: across
  my ($tx, $ty) = ($cx + $ax * $H / 2, $cy + $ay * $H / 2);
  my $r = sub { my $u = max(0, min(1, $_[0])); my $up = $u ** 1.5; $W / 2 * sqrt(max(0, 1 - (2 * $up - 1) ** 2)) * (1 - $shr * 0.25 * sin(7 * $u)) };
  my $P = sub { my ($u, $s) = @_; [$tx - $ax * $u * $H + $bx * $s, $ty - $ay * $u * $H + $by * $s] };
  my $S = sub { my ($u, $phi) = @_; $phi = max(-pi / 2, min(pi / 2, $phi)); $P->($u, $r->($u) * sin($phi)) };
  my @o;
  my $m = 24;
  for my $i (0 .. $m) { my $u = $from + (1 - $from) * $i / $m; push @o, $P->($u, $r->($u) * 1.03); }
  for my $i (reverse 0 .. $m) { my $u = $from + (1 - $from) * $i / $m; push @o, $P->($u, -$r->($u) * 1.03); }
  poly('c4', @o);
  my $nr = max(5, int($H / ($W * 0.15))); my $du = 1 / $nr;
  my $nc = $W > 70 ? 7 : $W > 36 ? 5 : 4; my $dp = pi / $nc;
  my $toS = sub { my ($ac, $al, $z) = @_; ($bx * $ac + $ax * $al, $by * $ac + $ay * $al, $z) };   # local -> screen normal
  for my $row (0 .. $nr) {
    my $u = $row * $du + $du * 0.35;
    next if $u - $du * 0.2 < $from || $u > 1.02;
    my $rr = $r->($u); next if $rr < 3;
    my $tilt = (0.55 - $u) * 1.6;                                 # toward the tip on the upper part
    for my $j (-$nc .. $nc) {
      my $phi = ($j + ($row % 2 ? 0.5 : 0)) * $dp;
      next if abs($phi) > pi / 2 + 0.1;
      my $ut = $u - $du * 1.05; $ut = max($from, $ut) if $from;
      my $T = $S->($ut, $phi);
      my $L = $S->($u + $du * 0.05, $phi - $dp * 0.56); my $R = $S->($u + $du * 0.05, $phi + $dp * 0.56);
      my $BL = $S->($u + $du * 0.45, $phi - $dp * 0.3); my $BR = $S->($u + $du * 0.45, $phi + $dp * 0.3);
      my $B = $S->($u + $du * 0.58, $phi);
      my @n0 = (sin($phi), $tilt, cos($phi));
      for my $side (-1, 1) {
        my @nn = ($n0[0] + $side * 0.5 * cos($phi), $n0[1] + 0.25, $n0[2] - $side * 0.5 * sin($phi));
        my $cls = shade($toS->(@nn)); $cls = "c5" if $cls eq "c3" && ($u < 0.24 || $u > 0.85);
        $cls = 'c4' if $shr && $cls eq 'c3';
        my $glint = $cls eq "c3"; $cls = "c5" if $glint;
        my @f = $side < 0 ? ($T, $L, $BL, $B) : ($T, $B, $BR, $R);
        poly($cls, @f);
        if ($glint) { my $E = $side < 0 ? $L : $R; my $mx = sub { [($_[0][0] + $_[1][0]) / 2, ($_[0][1] + $_[1][1]) / 2] }; poly("c3", $mx->($T, $E), $E, $mx->($E, $side < 0 ? $BL : $BR), $mx->($T, $B)); }
      }
      # dark spine line running down from the scale tip
      my $M = $S->($u - $du * 0.35, $phi); my $q = max(0.6, $W * 0.012);
      poly('c4', $T, [$M->[0] + $bx * $q, $M->[1] + $by * $q], [$M->[0] - $bx * $q, $M->[1] - $by * $q]);
    }
  }
  return ($P, $r);
}

# Peeled salak: the scaly skin left as a cup around the base and three plump ivory lobes standing above
# it like garlic cloves, split by curved dark seams that meet at the tip.
sub peeled {
  my ($cx, $cy, $ang, $H, $W) = @_;
  my ($ax, $ay) = dir($ang); my ($bx, $by) = (-$ay, $ax);
  my ($tx, $ty) = ($cx + $ax * $H / 2, $cy + $ay * $H / 2);
  my $r = sub { my $u = max(0, min(1, $_[0])); my $up = $u ** 1.5; $W / 2 * sqrt(max(0, 1 - (2 * $up - 1) ** 2)) };
  my $P = sub { my ($u, $s) = @_; [$tx - $ax * $u * $H + $bx * $s, $ty - $ay * $u * $H + $by * $s] };
  my $RIM = 0.6; my $U0 = 0.03; my $U1 = 0.72; my $n = 18;
  my $rf = sub { my $u = shift; 0.94 * $r->($u) * (1 + 0.1 * max(0, 1 - $u / 0.4)) };
  my @us = map { $U0 + ($U1 - $U0) * $_ / $n } 0 .. $n;
  my $tip = $P->($U0 - 0.02, 0);
  # dark under-silhouette, then the ivory flesh
  my @L = map { $P->($_, -$rf->($_) - 1.5) } @us; my @R = map { $P->($_, $rf->($_) + 1.5) } @us;
  poly('c4', $tip, @R, reverse @L);
  my @Li = map { $P->($_, -$rf->($_)) } @us; my @Ri = map { $P->($_, $rf->($_)) } @us;
  poly('c3', $tip, @Ri, reverse @Li);
  # shade crescent along the right flank and a softer one inside the front lobe's right edge
  my @sh = map { my $i = $_; my $u = $us[$i]; $P->($u, $rf->($u) * (1 - 0.2 * sin(pi * min(1, ($i + 1) / ($n - 2))))) } 0 .. $n;
  poly('c5', $tip, @Ri, reverse @sh);
  # curved seams: they bow outward so the front lobe swells
  for my $sg ([-1, 0.34], [1, 0.4]) {
    my ($s, $f) = @$sg; my (@a, @b);
    for my $i (0 .. $n) {
      my $u = $us[$i]; my $t = $i / $n;
      my $x = $s * $rf->($u) * ($f + 0.32 * sin(pi * $t) ** 1.2 * (1 - 0.4 * $t));
      my $w = 0.5 + 1.8 * sin(pi * min(1, $t * 1.1)) ** 0.8;
      push @a, $P->($u, $x - $w); push @b, $P->($u, $x + $w);
    }
    poly('c4', $tip, @a[1 .. $n], reverse @b[1 .. $n]);
  }
  # skin cup: scales from the rim down, plus the pale cut edge of the skin along the front of the rim
  sfruit($cx, $cy, $ang, $H, $W, $RIM);
  my (@e1, @e2);
  for my $i (0 .. 16) {
    my $phi = -pi / 2 + pi * $i / 16; my $sx = $r->($RIM) * sin($phi) * 1.02; my $dip = 0.035 * cos($phi);
    push @e1, $P->($RIM + $dip, $sx); push @e2, $P->($RIM + $dip + 0.028 * cos($phi) ** 0.5 + 0.004, $sx * 0.99);
  }
  poly('c3', @e1, reverse @e2);
}

# Salak seed: a dark glossy rounded wedge with a lit cheek and a pale glint.
sub seed {
  my ($x, $y, $rot, $r, $pale) = @_;
  my $ra = deg2rad($rot); my @o;
  for my $i (0 .. 15) {
    my $th = 2 * pi * $i / 16; my $k = 1 + 0.16 * cos(3 * $th) + 0.08 * cos($th);
    my ($c, $s) = (cos($th) * $r * $k, sin($th) * $r * 0.78 * $k);
    push @o, [$x + $c * cos($ra) - $s * sin($ra), $y + $c * sin($ra) + $s * cos($ra)];
  }
  poly('c4', @o);
  my @in = map { [$x + ($_->[0] - $x) * ($pale ? 0.8 : 0.58) - $r * ($pale ? 0.1 : 0.2), $y + ($_->[1] - $y) * ($pale ? 0.8 : 0.58) - $r * ($pale ? 0.1 : 0.2)] } @o;
  poly('c5', @in);
  my @g = map { [$x - $r * 0.32 + ($_->[0] - $x) * 0.16, $y - $r * 0.34 + ($_->[1] - $y) * 0.16] } @o;
  poly('c3', @g);
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
  open my $fh, '>', "$OUT/$file" or die $!;
  print $fh qq{<?xml version="1.0" encoding="UTF-8"?>\n<svg viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="$label">\n  <style>\n};
  print $fh "    .$_ { fill: var(--$_, $PAL{$_}); }\n" for qw(c1 c2 c3 c4 c5);
  print $fh "  </style>\n  <g transform=\"translate(0 0)\">\n", join("\n", @S), "\n  </g>\n</svg>\n";
  close $fh; @S = ();
}

# Ring of fronds from the clump centre. Each: [angle, len, bend].
sub clump {
  my ($light, $dark, $lf, $wilt, @f) = @_;
  for (sort { $b->[1] <=> $a->[1] } @f) { my ($dx, $dy) = dir($_->[0]); frond(200 + $dx * 5, 200 + $dy * 5, @$_, $light, $dark, $lf, $wilt); }
}

# A tight cluster of fruits at the frond bases: tips point outward from the cluster point.
sub cluster {
  my ($x, $y, $ang, $n, $H, $W, $seed) = @_;
  srand($seed);
  my @f;
  for my $i (0 .. $n - 1) {
    my $a = $ang + ($i - ($n - 1) / 2) * (150 / max(1, $n - 1)) + rand(10) - 5;
    my $d = $H * (0.32 + rand(0.08));
    my ($dx, $dy) = dir($a);
    push @f, [$x + $dx * $d, $y + $dy * $d, $a, $H * (0.92 + rand(0.14)), $W * (0.92 + rand(0.12))];
  }
  # inner ones (pointing back toward the light) first so the outer ring overlaps
  sfruit(@$_) for sort { ($a->[0] + $a->[1]) <=> ($b->[0] + $b->[1]) } @f;
}

# ---------------------------------------------------------------------------------------------
# 1. Planting material, front view: a little heap of dark glossy salak seeds before one whole fruit.
sfruit(214, 150, -96, 176, 122);
{ srand(12); my @sd;
  for my $row ([322, 5], [292, 4], [264, 3]) { my ($y, $c) = @$row;
    for my $k (0 .. $c - 1) { push @sd, [200 + ($k - ($c - 1) / 2) * 46 + rand(10) - 5, $y + rand(8) - 4, rand(360), 22 + rand(4)]; } }
  seed(@$_) for sort { $a->[1] <=> $b->[1] } @sd; }
write_svg('1-seeds-front.svg', 'Salak seeds');

# 2. Just sown, top down: seeds pressed into small soil pockets.
my @sown = ([170, 172, -20], [236, 170, 50], [200, 230, 100]);
for (@sown) { soil($_->[0], $_->[1], 33, 27, int($_->[0] * 7 + $_->[1])); }
for (@sown) { seed($_->[0], $_->[1], $_->[2], 19, 1); }
write_svg('2-sown.svg', 'Salak just sown');

# Young palm leaf: a spiny petiole ending in two broad pleated lobes (the bifid "fishtail" seedling leaf).
sub bifid {
  my ($x, $y, $ang, $plen, $len, $w, $bend, $light, $dark) = @_;
  $light //= 'c2'; $dark //= 'c1';
  my ($ex, $ey, $ea) = walk($x, $y, $ang, $plen, $bend * 0.3);
  for my $s (-1, 1) {
    my $la = $ea + $s * 21; my $n = 10; my (@l, @r);
    my ($px, $py, $a) = ($ex, $ey, $la);
    for my $i (0 .. $n) {
      my $t = $i / $n; my ($dx, $dy) = dir($a);
      my $hw = $i == $n ? 0 : $w / 2 * sin(pi * (0.12 + 0.88 * $t) ** 0.8) ** 0.7 + 0.8;
      push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw];
      $px += $dx * $len / $n; $py += $dy * $len / $n; $a += ($bend * 0.7 + $s * 10) / $n;
    }
    my ($dx, $dy) = dir($la); my $leftLit = lit(-$dy, $dx);
    my @c = $leftLit ? ($light, $dark) : ($dark, $light);
    for my $k (0 .. 4) {   # pleats: strips running along the lobe, alternately lit and shaded
      my ($f0, $f1) = ($k / 5, ($k + 1) / 5);
      my @A = map { [$l[$_][0] + ($r[$_][0] - $l[$_][0]) * $f0, $l[$_][1] + ($r[$_][1] - $l[$_][1]) * $f0] } 0 .. $n;
      my @B = map { [$l[$_][0] + ($r[$_][0] - $l[$_][0]) * $f1, $l[$_][1] + ($r[$_][1] - $l[$_][1]) * $f1] } 0 .. $n;
      poly($c[$k % 2], [$ex, $ey], @A[1 .. $n], reverse @B[1 .. $n]);
    }
  }
  blade($x, $y, $ang, $plen, 4.5, $bend * 0.3, $light, $dark, 0.5);
  spines($x, $y, $ang, $plen, $bend * 0.3, 0.15, 0.9, 3, 6, 1.5, 'c3');
}

# Salak flower spike: a stubby red-brown catkin of packed florets on a short stalk.
sub catkin {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my (@l, @r);
  for my $i (0 .. 10) { my $t = $i / 10; my $hw = $w / 2 * sin(pi * (0.1 + 0.85 * $t)) ** 0.5; push @l, [$x + $dx * $len * $t + $nx * $hw, $y + $dy * $len * $t + $ny * $hw]; push @r, [$x + $dx * $len * $t - $nx * $hw, $y + $dy * $len * $t - $ny * $hw]; }
  poly('c4', @l, reverse @r);
  my $leftLit = lit($nx, $ny);
  for my $i (1 .. 7) {     # florets: little lit knobs in alternating rows
    my $t = $i / 8.5; my $o = ($i % 2 ? 0.28 : -0.28) * $w;
    my ($fx, $fy) = ($x + $dx * $len * $t + $nx * $o * 0.6, $y + $dy * $len * $t + $ny * $o * 0.6);
    my $fr = $w * 0.24;
    poly(($o > 0) == $leftLit ? 'c5' : 'c5', map { my ($ex, $ey) = dir($_ * 60); [$fx + $ex * $fr, $fy + $ey * $fr] } 0 .. 5);
    poly('c3', map { my ($ex, $ey) = dir($_ * 120 + 30); [$fx - $fr * 0.3 + $ex * $fr * 0.3, $fy - $fr * 0.3 + $ey * $fr * 0.3] } 0 .. 2) if ($o > 0) == $leftLit;
  }
}

# 3. First growth, top down: two spiny seedling leaves opening into pleated fishtail lobes.
soil(200, 200, 34, 30, 3);
bifid(200, 200, 155, 26, 62, 36, -12); bifid(200, 200, -45, 30, 68, 38, 10); bifid(200, 200, 62, 16, 42, 28, 8);
write_svg('3-first-growth.svg', 'Salak first growth');

# 4. Second growth, top down: the first pinnate spiny fronds around a young fishtail leaf.
soil(200, 200, 36, 32, 4);
clump('c2', 'c1', 1, 0, [-80, 102, 16], [-8, 96, -14], [64, 104, 18], [140, 98, -16], [212, 102, 14]);
bifid(200, 200, -120, 12, 40, 26, 8);
write_svg('4-second-growth.svg', 'Salak second growth');

# 5. Third growth, top down: a full spiny clump; red flower catkins and a first cluster of young fruit at the base.
soil(200, 200, 38, 32, 5);
clump('c2', 'c1', 1, 0, map { [-86 + $_ * 360 / 8, 122 + ($_ % 3) * 6, ($_ % 2 ? 1 : -1) * 18] } 0 .. 7);
clump('c2', 'c1', 1, 0, map { [-60 + $_ * 360 / 5, 80, ($_ % 2 ? -1 : 1) * 14] } 0 .. 4);
for my $c ([186, 190, [-160, -120, -84]], [218, 216, [10, 50, 90]]) {
  my ($x, $y, $as) = @$c; catkin($x, $y, $_, 30, 12) for @$as;
}
cluster(214, 186, -40, 3, 26, 20, 55);
write_svg('5-third-growth.svg', 'Salak third growth');

# 6. Harvest, top down: a big spiny frond clump with fat clusters of ripe scaly fruit at its base.
soil(200, 200, 40, 34, 6);
clump('c2', 'c1', 1, 0, map { [-90 + $_ * 36, 134 + ($_ % 3) * 6, ($_ % 2 ? 1 : -1) * 18] } 0 .. 9);
clump('c2', 'c1', 1, 0, map { [-72 + $_ * 60, 94, ($_ % 2 ? -1 : 1) * 14] } 0 .. 5);
cluster(184, 182, -130, 5, 54, 40, 61); cluster(230, 196, -15, 4, 54, 40, 62); cluster(190, 234, 105, 4, 52, 39, 63);
write_svg('6-harvest.svg', 'Salak ready to harvest');

# 7. Harvest, front view: two whole snake fruits and one peeled to show its ivory lobes.
sfruit(112, 190, -114, 210, 142);
sfruit(290, 184, -68, 206, 140);
peeled(204, 236, -90, 230, 156);
write_svg('7-harvest-front.svg', 'Harvested salak');

# 8. Dead (never watered), top down: cracked dry soil, dried straw fronds collapsed flat with curled leaflets,
#    and a few shrivelled dark fruits at the base.
soil(200, 200, 66, 58, 8);
cracks(9, 83, 14, 'c3');
clump('c3', 'c4', 0.85, 1, map { [-80 + $_ * 360 / 7 + ($_ * 23 % 17), 100 + ($_ * 31 % 24), ($_ % 2 ? 1 : -1) * (40 + $_ * 7 % 30)] } 0 .. 6);
sfruit(190, 192, -150, 30, 22, 0, 1); sfruit(214, 206, 20, 28, 21, 0, 1); sfruit(196, 218, 120, 26, 20, 0, 1);
write_svg('8-dead.svg', 'Salak died from lack of water');
print "wrote 8 files to $OUT\n";

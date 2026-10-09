# Monstera fruit crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/monstera.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Monstera deliciosa grown as a ground plant: big glossy heart-shaped leaves split by deep slits and pierced
# by rows of holes, an overlapping rosette from above. It flowers with a cream spathe hood around a spadix,
# which ripens into a long green cob of jade hexagonal scale plates over cream kernel-like flesh.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/monstera';
mkdir 'crops'; mkdir $OUT;
# c1 deep leaf green, c2 lit glossy green, c3 cream (spathe, flesh, cut stem, dried leaves), c4 dark soil brown,
# c5 pale jade (fruit scale plates, the inside of the spathe, flesh shade)
my %PAL = (c1 => '#2C6638', c2 => '#5FA64A', c3 => '#F6EDC8', c4 => '#4C3021', c5 => '#A9D3A0');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub light { my ($nx, $ny) = @_; my $l = sqrt($nx * $nx + $ny * $ny) || 1; ($nx * -0.7071 + $ny * -0.7071) / $l }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A tapered blade or stalk (as in wheat.pl). $taper < 1 keeps width at the tip. Returns points [x, y, angle].
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $lightc, $dark, $taper) = @_;
  $taper //= 1;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $t) ** 0.85 + ($i == $n && $taper == 1 ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py, $a];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  my @m = map { [$_->[0], $_->[1]] } @mid;
  poly($leftLit ? $lightc : $dark, @l, reverse @m);
  poly($leftLit ? $dark : $lightc, @r, reverse @m);
  return @mid;
}

# Monstera leaf from above. (x,y) = where the petiole meets the blade, `ang` = toward the tip, length L,
# width Wd. The heart-shaped blade is built from strips between curved side veins ("ribs"); from $fs of
# the way out to the margin the strips separate into slits, and with $holes each inner strip is pierced
# by an oval hole (made by splitting the strip along its centre and biting a half-oval from each piece).
# $bend curves the midrib; $wilt shrivels and tears it (dead stage).
sub mleaf {
  my ($x, $y, $ang, $L, $Wd, $K, $fs, $holes, $bend, $lightc, $dark, $wilt, $seed) = @_;
  $bend //= 0; $wilt //= 0; srand($seed // int($x * 7 + $y * 3));
  my ($ax, $ay) = dir($ang); my ($nx, $ny) = (-$ay, $ax);
  my $M = sub { my $t = shift; my $o = $bend * $t * $t * $L; [$x + $ax * $t * $L + $nx * $o, $y + $ay * $t * $L + $ny * $o] };
  my $T0 = -0.16;
  my $hw = sub { my $t = shift; my $u = max(0, min(1, ($t - $T0) / (1 - $T0))); $Wd / 2 * sin(pi * $u ** 0.78) ** 0.62 };
  my @wf = map { 1 - $wilt * (0.15 + rand(0.5)) } 0 .. 41;
  my $P = sub { my ($t, $f, $s) = @_; my $k = $wilt ? $wf[int(max(0, min(1, ($t - $T0) / (1 - $T0))) * 39) + ($s > 0 ? 1 : 0)] : 1;
                my $m = $M->($t); my $h = $hw->($t) * $f * $k; [$m->[0] + $nx * $s * $h, $m->[1] + $ny * $s * $h] };
  my (@ts, @sl);
  for my $j (0 .. $K) { push @ts, 0.0 + 0.8 * $j / $K; push @sl, -0.15 + 0.3 * $j / $K; }
  push @ts, 1; push @sl, 0; my $KK = $K + 1;     # a degenerate last rib at the tip closes the final strip
  our ($GMAX, $HR, $HT, $FH); my $gmax = ($GMAX // 0.032) * (1 + $wilt); my $m = 8;
  my $area = sub { my $a = 0; for my $i (0 .. $#_) { my ($p, $q) = ($_[$i], $_[($i + 1) % @_]); $a += $p->[0] * $q->[1] - $q->[0] * $p->[1]; } $a };
  for my $s (-1, 1) {
    my $cls = lit($nx * $s, $ny * $s) ? $lightc : $dark;
    my $rib = sub { my ($j, $f, $dt) = @_; $P->($ts[$j] + $sl[$j] * $f ** 0.85 + $dt, $f, $s) };
    my $gap = sub { my ($j, $f) = @_; return 0 if $j == 0 || $j >= $KK - 1 || $f <= $fs; $gmax * (($f - $fs) / (1 - $fs)) ** 1.1 };
    # One polygon per leaf half: out along the first rib, then strip by strip along the margin, dipping
    # into each slit; holes are joined to the margin by zero-width bridges (keyholes) and wound backwards.
    my $build = sub {
      my ($withHoles, $sign) = @_;
      my @p = map { $rib->(0, $_ / $m, 0) } 0 .. $m;
      for my $j (0 .. $KK - 1) {
        my ($tc, $sc) = (($ts[$j] + $ts[$j + 1]) / 2, ($sl[$j] + $sl[$j + 1]) / 2);
        my $t0 = $ts[$j] + $sl[$j] + $gap->($j, 1); my $tce = $tc + $sc; my $t1 = $ts[$j + 1] + $sl[$j + 1] - $gap->($j + 1, 1);
        push @p, map { $P->($t0 + ($tce - $t0) * $_ / 3, 1, $s) } 1 .. 3;
        if ($withHoles && $holes && $j >= 1 && $j <= $KK - ($HR ? 2 : 3)) {
          my $wt = $ts[$j + 1] - $ts[$j];
          my ($fh, $hr, $ht) = $HR ? ($FH + 0.04 * ($j % 2), $HR, $wt * $HT) : (0.27 + 0.05 * ($j % 2), 0.12, $wt * 0.3);
          my $cen = sub { my ($f, $dt) = @_; $P->($tc + $sc * $f ** 0.85 + $dt, $f, $s) };
          my @bridge = map { $cen->(1 - (1 - $fh - $hr) * $_ / 4, 0) } 1 .. 4;
          my @h = map { my $th = 2 * pi * $_ / 14; $cen->($fh + $hr * cos($th), $ht * sin($th)) } 0 .. 14;
          @h = reverse @h if ($area->(@h) > 0) == ($sign > 0);
          push @p, @bridge, @h, reverse(@bridge), $P->($tce, 1, $s);
        }
        push @p, map { $P->($tce + ($t1 - $tce) * $_ / 3, 1, $s) } 1 .. 3;
        last if $j == $KK - 1;
        my $sw = $j + 1;
        if ($gap->($sw, 1) > 0) {   # into the slit along rib j+1 and back out
          push @p, map { $rib->($sw, 1 - (1 - $fs) * $_ / $m, -$gap->($sw, 1 - (1 - $fs) * $_ / $m)) } 0 .. $m;
          push @p, map { $rib->($sw, $fs + (1 - $fs) * $_ / $m, $gap->($sw, $fs + (1 - $fs) * $_ / $m)) } 0 .. $m;
        }
      }
      push @p, map { $M->(1 - $_ / 10) } 0 .. 10;
      return @p;
    };
    my @outer = $build->(0, 0);
    my $sign = $area->(@outer);
    poly($cls, $build->(1, $sign));
  }
  # midrib: a slim raised vein, lit along one edge
  my @l; my @r;
  for my $i (0 .. 10) { my $t = 0.9 * $i / 10; my $p = $M->($t); my $w = 2.4 * (1 - $t) + 0.6; push @l, [$p->[0] + $nx * $w, $p->[1] + $ny * $w]; push @r, [$p->[0] - $nx * $w, $p->[1] - $ny * $w]; }
  my @mid = map { $M->(0.9 * $_ / 10) } 0 .. 10;
  my $lsl = lit($nx, $ny);
  poly($lsl ? $lightc : $dark, @l, reverse @mid); poly($lsl ? $dark : $lightc, @r, reverse @mid);
}

# A leaf on its petiole: stalk from (x,y) heading `ang`, the blade opening at its end.
sub leaf_on {
  my ($x, $y, $ang, $plen, $L, $Wd, $K, $fs, $holes, $bend, $lc, $dc, $wilt, $seed) = @_;
  my @m = blade($x, $y, $ang, $plen, max(4, $L * 0.07), 0, $lc // 'c2', $dc // 'c1', 0.45);
  mleaf($m[-1][0], $m[-1][1], $ang, $L, $Wd, $K, $fs, $holes, $bend, $lc // 'c2', $dc // 'c1', $wilt, $seed);
}

# Hexagon cell in (phi, u) space mapped through a surface function.
sub hexcell {
  my ($Sf, $phi, $u, $dp, $du, $k) = @_;
  map { my $a = deg2rad(30 + 60 * $_); $Sf->($u + sin($a) * $du * $k, $phi + cos($a) * $dp * $k) } 0 .. 5;
}

# Monstera fruit cob: (cx,cy) centre, heading `ang` from stalk end toward tip, length H, width W.
# Jade hexagonal scale plates over the stalk-end part; the last $pf of its length (tip end) has shed its
# plates, showing packed cream kernels, with a row of plates lifting at the edge. $stem = stalk length.
sub mcob {
  my ($cx, $cy, $ang, $H, $W, $pf, $stem, $shr, $cast) = @_;
  $pf //= 0; $stem //= 0; $shr //= 0;
  my ($ax, $ay) = dir($ang); my ($bx, $by) = (-$ay, $ax);
  my ($sx, $sy) = ($cx - $ax * $H / 2, $cy - $ay * $H / 2);            # stalk end
  my $r = sub { my $u = max(0, min(1, $_[0])); $W / 2 * max(0, 1 - abs(2 * $u - 1) ** 3.2) ** 0.42 * (1 - 0.1 * $u) * (1 - $shr * 0.2) };
  my $Sf = sub { my ($u, $phi) = @_; $phi = max(-pi / 2, min(pi / 2, $phi)); my $rr = $r->($u); [$sx + $ax * $u * $H + $bx * $rr * sin($phi), $sy + $ay * $u * $H + $by * $rr * sin($phi)] };
  my $lsL = lit($bx, $by) ? -1 : 1;            # which phi side faces the light
  if ($cast) {                                 # cast shadow on the ground, down-right
    my @co; for my $i (0 .. 30) { push @co, $Sf->($i / 30, pi / 2); } for my $i (reverse 0 .. 30) { push @co, $Sf->($i / 30, -pi / 2); }
    poly("c4", map { [$_->[0] + $W * 0.16, $_->[1] + $W * 0.24] } @co);
  }
  if ($stem) {
    my @st = blade($sx + $ax * 4, $sy + $ay * 4, $ang + 180, $stem, $W * 0.32, 14, $shr ? 'c3' : 'c2', $shr ? 'c4' : 'c1', 0.2);
    my ($ex, $ey, $ea) = @{$st[-1]}; my ($dx, $dy) = dir($ea); my ($px, $py) = (-$dy, $dx); my $cw = $W * 0.14;
    poly('c3', map { my $t = 2 * pi * $_ / 10; [$ex + $px * cos($t) * $cw + $dx * sin($t) * $cw * 0.45, $ey + $py * cos($t) * $cw + $dy * sin($t) * $cw * 0.45] } 0 .. 9);
  }
  my @o; my $n = 30;
  for my $i (0 .. $n) { my $u = $i / $n; push @o, $Sf->($u, pi / 2); }
  for my $i (reverse 0 .. $n) { my $u = $i / $n; push @o, $Sf->($u, -pi / 2); }
  poly($cast ? "c5" : "c4", map { [$_->[0], $_->[1]] } @o);
  my $nc = $W > 70 ? 7 : 5; my $dp = pi / $nc;
  my $du = ($dp * $W / 2) / $H * 1.0;  my $rows = int(1 / $du);  $du = 1 / $rows;
  my $cut = 1 - $pf;
  my $shadeOf = sub {
    my ($phi) = @_; my $b = -$lsL * sin($phi);       # +1 toward the light
    return $b > -0.25 ? "lit" : $b > -0.75 ? "mid" : "dark";
  };
  for my $row (0 .. $rows) {
    my $u = ($row + 0.5) * $du;
    my $kern0 = $u > $cut + $du * 0.5;
    for my $j (-$nc .. $nc) {
      my $phi = ($j + ($row % 2 ? 0.5 : 0)) * $dp;
      next if abs($phi) > pi / 2 + 0.2 || $r->($u) < $W * 0.12;
      my $kern = $kern0 && !($cast && (($row * 7 + $j * 3) % 9 == 0) && $u < $cut + 0.3);
      my $tone = $shadeOf->($phi);
      my @h = hexcell($Sf, $phi, $u, $dp * 0.5, $du * 0.62, $kern ? 0.93 : 0.95);
      if ($kern) {                                  # cream kernel with a jade-shaded lower facet
        my ($top, $low) = $tone eq 'dark' ? ('c5', 'c4') : $tone eq 'mid' ? ('c3', 'c5') : ('c3', 'c3');
        ($top, $low) = ("c4", "c4") if $cast && $tone eq "dark";
        $top = 'c4' if $shr && $top eq 'c3';
        poly($top, @h); poly($low, @h[0, 1, 2, 3]) if $low ne $top;
      } else {                                      # jade plate: lit top facet, darker lower facet, dark rim
        my ($top, $low) = $tone eq 'lit' ? ('c5', 'c2') : $tone eq 'mid' ? ('c2', 'c1') : ('c1', 'c4');
        ($top, $low) = ('c3', 'c4') if $shr && $tone ne 'dark';
        poly($top, @h); poly($low, @h[0, 1, 2, 3]);
      }
    }
    if ($pf && abs($u - $cut) < $du * 0.5) {       # lifting plates at the edge of the peeled part
      for my $j (-$nc .. $nc) {
        my $phi = ($j + ($row % 2 ? 0.5 : 0)) * $dp; next if abs($phi) > pi / 2 - 0.15 || $r->($u) < $W * 0.3;
        my @h = hexcell($Sf, $phi, $u + $du * 0.35, $dp * 0.5, $du * 0.62, 0.95);
        my $lift = $W * 0.1;
        my @lh = map { [$_->[0] + $ax * $lift * 0.6 + $bx * $lift * sin($phi), $_->[1] + $ay * $lift * 0.6 + $by * $lift * sin($phi)] } @h;
        poly('c4', @h[0 .. 3], @lh[reverse 0 .. 3]);
        poly($shadeOf->($phi) eq 'dark' ? 'c1' : 'c5', @lh); poly('c2', @lh[0, 1, 2, 3]);
      }
    }
  }
}

# The spathe from above: a cream boat-shaped hood around the spadix. (x,y) its base, `ang` toward its tip.
sub spathe {
  my ($x, $y, $ang, $L, $W) = @_;
  my ($ax, $ay) = dir($ang); my ($nx, $ny) = (-$ay, $ax);
  my $P = sub { my ($t, $s) = @_; [$x + $ax * $t * $L + $nx * $s, $y + $ay * $t * $L + $ny * $s] };
  my $hw = sub { my $t = shift; $W / 2 * sin(pi * (0.06 + 0.94 * $t) ** 0.85) ** 0.7 };
  my (@l, @r, @il, @ir);
  for my $i (0 .. 16) { my $t = $i / 16; push @l, $P->($t, -$hw->($t)); push @r, $P->($t, $hw->($t));
    my $ti = 0.04 + 0.86 * $t; push @il, $P->($ti, -$hw->($ti) * 0.74); push @ir, $P->($ti, $hw->($ti) * 0.74); }
  my $lsl = lit(-$nx, -$ny);
  poly('c3', @l, reverse @r);                         # outer hood, cream
  my @mid = map { $P->(0.04 + 0.86 * $_ / 16, 0) } 0 .. 16;
  poly('c5', @il, reverse @ir);                       # the jade-tinted hollow inside the hood   # deeper shade on the inner wall away from the light
  # spadix: a fat cream club lying in the hood, casting a shadow, dotted with florets
  my $sl = 0.62; my (@a, @b);
  for my $i (0 .. 10) { my $t = $i / 10; my $w = $W * 0.17 * sin(pi * (0.12 + 0.88 * $t)) ** 0.35; push @a, $P->(0.08 + $sl * $t, -$w); push @b, $P->(0.08 + $sl * $t, $w); }
  poly('c2', map { [$_->[0] + 3, $_->[1] + 3.5] } @a, reverse @b);
  poly('c3', @a, reverse @b);
  for my $i (1 .. 7) { for my $s (-1, 1) {
    my $p = $P->(0.08 + $sl * ($i - ($s > 0 ? 0.5 : 0)) / 7.5, $s * $W * 0.07);
    poly('c5', map { my ($dx, $dy) = dir($_ * 90 + 45); [$p->[0] + $dx * 1.8, $p->[1] + $dy * 1.8] } 0 .. 3); } }
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

# A stem cutting: a thick green stem segment with node rings, an aerial root and a leaf bud.
# (x,y) one end, heading `ang`, length L, width W.
sub cutting {
  my ($x, $y, $ang, $L, $W, $root) = @_;
  my ($ax, $ay) = dir($ang); my ($nx, $ny) = (-$ay, $ax);
  if ($root) {   # aerial root: a long brown cord from the node, curving away
    my $p = [$x + $ax * $L * 0.55 - $nx * $W * 0.3, $y + $ay * $L * 0.55 - $ny * $W * 0.3];
    blade($p->[0], $p->[1], $root, $L * 0.85, $W * 0.24, 26, 'c5', 'c4', 0.6);
  }
  my @st = blade($x, $y, $ang, $L, $W, 0, 'c2', 'c1', 0.08);
  for my $e ([$x, $y], [$x + $ax * $L, $y + $ay * $L]) {   # cut ends, cream
    poly('c3', map { my $t = 2 * pi * $_ / 10; [$e->[0] + $nx * cos($t) * $W * 0.47 + $ax * sin($t) * $W * 0.2, $e->[1] + $ny * cos($t) * $W * 0.47 + $ay * sin($t) * $W * 0.2] } 0 .. 9);
  }
  for my $f (0.3, 0.7) {        # node rings: pale scar bands
    my $c = [$x + $ax * $L * $f, $y + $ay * $L * $f]; my $h = $W * 0.5;
    poly('c5', [$c->[0] - $nx * $h - $ax * 2, $c->[1] - $ny * $h - $ay * 2], [$c->[0] + $nx * $h - $ax * 2, $c->[1] + $ny * $h - $ay * 2],
               [$c->[0] + $nx * $h + $ax * 2.5, $c->[1] + $ny * $h + $ay * 2.5], [$c->[0] - $nx * $h + $ax * 2.5, $c->[1] - $ny * $h + $ay * 2.5]);
  }
}

# ---------------------------------------------------------------------------------------------
# 1. Planting material, front view: a stem cutting with a node, an aerial root and one young split leaf.
{
  cutting(118, 268, -8, 168, 44, 104);
  my @p = blade(232, 262, -72, 92, 9, 18, 'c2', 'c1', 0.3);
  mleaf($p[-1][0], $p[-1][1], -44, 132, 128, 4, 0.5, 0, -0.08, 'c2', 'c1', 0, 11);
  cutting(118, 268, -8, 168, 44, 0) ;
}
write_svg('1-seeds-front.svg', 'Monstera stem cutting');

# 2. Just planted, top down: a stem cutting laid into a soil pocket, its first bud showing.
soil(200, 204, 64, 42, 2);
cutting(150, 206, -6, 100, 30, 0);
blade(206, 198, -110, 22, 9, 30, 'c2', 'c1');
write_svg('2-sown.svg', 'Monstera cutting just planted');

# 3. First growth, top down: young heart-shaped leaves, still whole (juvenile monstera leaves have no splits).
soil(200, 200, 34, 30, 3);
leaf_on(200, 200, -120, 16, 74, 64, 5, 1, 0, 0.05, 'c2', 'c1', 0, 31);
leaf_on(200, 200, 20, 14, 80, 70, 5, 1, 0, -0.05, 'c2', 'c1', 0, 32);
leaf_on(200, 200, 118, 10, 56, 48, 5, 1, 0, 0.05, 'c2', 'c1', 0, 33);
write_svg('3-first-growth.svg', 'Monstera first growth');

# 4. Second growth, top down: bigger leaves with their first deep slits.
soil(200, 200, 34, 30, 4);
{ local $main::GMAX = 0.07;
leaf_on(200, 200, -150, 22, 104, 104, 3, 0.34, 0, 0.06, 'c2', 'c1', 0, 41);
leaf_on(200, 200, -50, 24, 110, 110, 3, 0.34, 0, -0.06, 'c2', 'c1', 0, 42);
leaf_on(200, 200, 50, 22, 102, 102, 3, 0.34, 0, 0.06, 'c2', 'c1', 0, 43);
leaf_on(200, 200, 140, 20, 96, 96, 3, 0.36, 0, -0.06, 'c2', 'c1', 0, 44);
}
leaf_on(200, 200, -100, 6, 58, 52, 5, 1, 0, 0, 'c2', 'c1', 0, 45);
write_svg('4-second-growth.svg', 'Monstera second growth');

# Bold mature leaves: few, broad segments, slits open all the way to the edge, and big round holes, so the
# famous silhouette still reads at sprite size.
our ($GMAX, $HR, $HT, $FH);
sub bold_leaf { my ($a, $pl, $L, $bend, $seed) = @_;
  local ($GMAX, $HR, $HT, $FH) = (0.085, 0.15, 0.3, 0.42);
  leaf_on(200, 200, $a, $pl, $L, $L * 1.12, 3, 0.26, 1, $bend, 'c2', 'c1', 0, $seed); }

# 5. Third growth, top down: an irregular rosette of big split, holed leaves and a cream spathe opening.
soil(200, 200, 34, 30, 5);
bold_leaf(@$_) for [-148, 22, 124, 0.08, 501], [22, 26, 130, -0.06, 502], [-66, 18, 116, -0.1, 503], [112, 20, 120, 0.1, 504];
leaf_on(200, 200, 60, 8, 62, 60, 4, 0.48, 0, 0.05, 'c2', 'c1', 0, 51);
spathe(186, 212, -128, 100, 60);
write_svg('5-third-growth.svg', 'Monstera third growth with spathe');

# 6. Harvest, top down: big holed leaves; two ripening cobs, cream where their jade plates have shed, lying
#    off-centre and pointing different ways, plus a spent spathe.
soil(200, 200, 34, 30, 6);
bold_leaf(@$_) for [-158, 30, 142, 0.08, 601], [-78, 26, 134, -0.1, 602], [8, 32, 146, -0.06, 603], [96, 28, 138, 0.1, 604];
leaf_on(200, 200, 160, 8, 70, 66, 4, 0.48, 0, -0.05, 'c2', 'c1', 0, 61);
spathe(214, 176, -60, 44, 26);
mcob(126, 176, 205, 116, 56, 0.78, 14, 0, 1);
mcob(254, 262, 62, 110, 54, 0.72, 14, 0, 1);
write_svg('6-harvest.svg', 'Monstera ready to harvest');

# 7. Harvest, front view: one monstera fruit, a long jade cob partly shed of its plates, cream kernels below.
mcob(200, 214, 76, 290, 124, 0.34, 34);
write_svg('7-harvest-front.svg', 'Harvested monstera fruit');

# 8. Dead (never watered), top down: cracked dry soil and collapsed, shrivelled straw-brown leaves.
soil(200, 200, 60, 52, 8);
cracks(9, 83, 14, 'c3');
{ local ($main::GMAX, $main::HR, $main::HT, $main::FH) = (0.08, 0.14, 0.3, 0.42);
for my $l ([-150, 20, 104], [-62, 24, 110], [24, 22, 106], [110, 20, 100]) {
  leaf_on(200, 200, $l->[0], $l->[1], $l->[2], $l->[2] * 0.95, 3, 0.28, 1, ($l->[0] % 2 ? 0.28 : -0.28), "c3", "c4", 0.3, $l->[0] + 800);
}
}
mcob(204, 210, 60, 46, 18, 0, 6, 1);
write_svg('8-dead.svg', 'Monstera died from lack of water');
print "wrote 8 files to $OUT\n";

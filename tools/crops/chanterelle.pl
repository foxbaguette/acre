# Chanterelle crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/chanterelle.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Then: perl tools/center.pl crops/chanterelle/1-seeds-front.svg crops/chanterelle/7-harvest-front.svg
# Signature: egg-yolk golden funnels with wavy, upturned, irregular margins and blunt forking false gills
# (ridges) running down the stem, growing from a mossy forest-floor patch.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/chanterelle';
mkdir 'crops'; mkdir $OUT;
# c1 apricot shade, c2 egg-yolk gold, c3 pale butter cream (highlights, mycelium, cracks), c4 forest soil, c5 moss
my %PAL = (c1 => '#C86E1C', c2 => '#F6B52C', c3 => '#FCE7A8', c4 => '#4A3323', c5 => '#6F8C3A');
my @S;
our %MAP;          # class remap (the dead stage dries everything brown)
our $SHR = 0;      # shrivel amount for fshroom

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; $cls = $MAP{$cls} // $cls; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Tapered blade/stalk (as in wheat). $taper < 1 leaves a blunt end.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $taper) = @_; $taper //= 1;
  my $n = 10; my (@mid, @l, @r); my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $t) ** 0.85 + ($i == $n && $taper == 1 ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2); my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# Crescent along the outline run facing direction ($lx,$ly), returning along an inner copy pulled to ($cx,$cy).
sub crescent {
  my ($cls, $o, $x, $y, $lx, $ly, $thr, $cx, $cy, $k) = @_;
  my $n = @$o;
  my @idx = grep { my ($ox, $oy) = ($o->[$_][0] - $x, $o->[$_][1] - $y); ($ox * $lx + $oy * $ly) > $thr * sqrt($ox * $ox + $oy * $oy) } 0 .. $n - 1;
  return if @idx < 3;
  my $st = 0; for my $j (0 .. $#idx) { my $prev = ($idx[$j] - 1) % $n; $st = $j unless grep { $_ == $prev } @idx; }
  my @run = map { $o->[$idx[($st + $_) % @idx]] } 0 .. $#idx;
  my @in = map { [$cx + ($_->[0] - $cx) * $k, $cy + ($_->[1] - $cy) * $k] } @run[1 .. $#run - 1];
  poly($cls, @run, reverse @in);
}

# Wavy lobed radius function for a chanterelle margin: a few big irregular lobes plus a fine ruffle.
sub lobes {
  my ($seed, $amp) = @_; srand($seed);
  my @ph = map { rand(2 * pi) } 0 .. 2; my $nl = 4 + int(rand(3));
  return sub { my $th = shift; 1 + $amp * (0.62 * sin($nl * $th + $ph[0]) + 0.28 * sin(($nl * 2 + 1) * $th + $ph[1]) + 0.18 * sin(3 * $th + $ph[2])); };
}

# ---- Front view -------------------------------------------------------------------------------
# A chanterelle seen from the front: base (bx,by), axis heading $ang (-90 = up), height $h, rim width $W.
# A stout stem flares into a trumpet; blunt forking ridges run down from the rim; the top shows the
# shallow golden funnel with a wavy, irregular, upturned margin. $tilt = how much of the top we see.
sub fshroom {
  my ($bx, $by, $ang, $h, $W, $seed, $tilt) = @_; $tilt //= 0.24;
  my ($ax, $ay) = dir($ang); my ($px, $py) = (-$ay, $ax);
  my $P = sub { my ($u, $v) = @_; [$bx + $ax * $u + $px * $v, $by + $ay * $u + $py * $v] };
  my $R = lobes($seed, 0.12 + 0.12 * $SHR);
  srand($seed + 7);
  my @wph = (rand(2 * pi), rand(2 * pi));
  my $wave = sub { my $th = shift; sin(3 * $th + $wph[0]) * 0.6 + sin(5 * $th + $wph[1]) * 0.4 };   # up/down rim waves
  my $sw = $W * 0.15;
  my $hw = sub { my $t = $_[0]; (1 - 0.3 * $SHR * $t) * ($sw * (0.8 + 0.35 * $t) + ($W / 2 - $sw * 1.15) * $t ** 1.55) };
  my $leftLit = lit(-$px, -$py);
  my ($LC, $DC) = $leftLit ? ('c2', 'c1') : ('c1', 'c2');
  my $split = $leftLit ? 0.15 : -0.15;
  my $ry = $W / 2 * $tilt; my $wa = $ry * 0.26 + $W * 0.03;
  my $n = 18; my (@L, @M, @Rr);
  for my $i (0 .. $n) { my $t = $i / $n; my $u = $h * $t; my $w = $hw->($t);
    my $e = $t > 0.9 ? ($t - 0.9) / 0.1 : 0;
    push @L, $P->($u + $e * $wa * 0.3 * $wave->(pi), -$w * (1 + $e * ($R->(pi) - 1)));
    push @Rr, $P->($u + $e * $wa * 0.3 * $wave->(0), $w * (1 + $e * ($R->(0) - 1)));
    push @M, $P->($u, $w * $split); }
  poly($LC, @L, reverse @M); poly($DC, @M, reverse @Rr);
  # rounded foot
  { my $w0 = $sw * 0.8; my @ft = map { my $th = pi * $_ / 8; [-sin($th) * $sw * 0.4, -cos($th) * $w0] } 0 .. 8;
    poly($DC, $P->(0, $w0 * $split), map { $P->(@$_) } grep { $_->[1] >= $w0 * $split } @ft);
    poly($LC, $P->(0, $w0 * $split), map { $P->(@$_) } grep { $_->[1] <= $w0 * $split } @ft); }
  # forking false gills: blunt ridges running down from the rim; dark grooves on the lit side, pale crests in shade
  my $m = 8;
  for my $j (0 .. $m - 1) {
    my $s = sin(deg2rad(-72 + 144 * ($j + 0.5) / $m + rand(6) - 3));
    my $tEnd = 0.22 + rand(0.2); my $tFork = 0.58 + rand(0.14); my $fork = ($j + $seed) % 4 != 1;
    my $col = ($s < $split) == $leftLit ? 'c1' : 'c2';
    $col = 'c3' if $col eq 'c2' && abs($s) < 0.6;
    my $ridge = sub {
      my ($s0, $s1, $t0, $t1, $w0, $w1) = @_; my (@a, @b);
      for my $k (0 .. 6) { my $q = $k / 6; my $t = $t0 + ($t1 - $t0) * $q; my $s = $s0 + ($s1 - $s0) * $q;
        my $sv = $s + 0.035 * sin($t * 11 + $j * 1.7); $sv = max(-0.9, min(0.9, $sv)); my $v = $sv * $hw->($t) * 0.95; my $ww = ($w0 + ($w1 - $w0) * $q) * sqrt(max(0.2, 1 - $s * $s));
        my $u = $h * $t - $ry * 0.6 * (1 - $s * $s) * max(0, ($t - 0.75) / 0.25) ** 2;
        push @a, $P->($u, $v - $ww); push @b, $P->($u, $v + $ww); }
      poly($col, @a, reverse @b);
    };
    my $wTop = $W * 0.026 + 0.6;
    if ($fork) {
      my $d = 0.07 + rand(0.05);
      $ridge->($s, $s, $tEnd, $tFork, 0.4, $wTop * 0.9);
      $ridge->($s, $s - $d, $tFork, 0.95, $wTop * 0.75, $wTop);
      $ridge->($s, $s + $d, $tFork, 0.95, $wTop * 0.75, $wTop);
    } else { $ridge->($s, $s, $tEnd, 0.95, 0.4, $wTop * 1.2); }
  }
  # the cap top: shallow funnel seen from slightly above, wavy upturned margin
  my $N = 40; my @top;
  for my $i (0 .. $N - 1) { my $th = 2 * pi * $i / $N; my $k = $R->($th);
    push @top, $P->($h + sin($th) * $ry * $k + $wa * $wave->($th) * (sin($th) < 0 ? 1 : 0.3), cos($th) * $W / 2 * $k); }
  { my @fr = grep { sin(2 * pi * $_ / $N) <= 0.05 } 0 .. $N - 1; my @d = map { my $p = $top[$_]; [$p->[0] - $ax * $W * 0.035, $p->[1] - $ay * $W * 0.035] } @fr;
    poly('c1', (map { $top[$_] } @fr), reverse @d); }
  poly('c2', @top);
  my ($cxw, $cyw) = @{$P->($h, 0)};
  # hollow: shaded on the near-left inner wall, golden on the far wall
  my $hc = $P->($h + $ry * 0.25, $W * 0.02); my ($icx, $icy) = @$hc;
  my @in = map { my $th = 2 * pi * $_ / $N; my $k = $R->($th) * 0.66; $P->($h + $ry * 0.25 + sin($th) * $ry * $k * 0.75, cos($th) * $W / 2 * $k + $W * 0.02) } 0 .. $N - 1;
  poly('c1', @in);
  my ($fx, $fy) = $leftLit ? ($ax + $px * 0.5, $ay + $py * 0.5) : ($ax - $px * 0.5, $ay - $py * 0.5);
  crescent('c2', \@in, $icx, $icy, $fx, $fy, -0.1, $icx - $fx * $ry * 1.1, $icy - $fy * $ry * 1.1, 0.75);
  # pale lit lip along the light side of the margin
  my ($lx, $ly) = $leftLit ? (-$px, -$py) : ($px, $py);
  crescent('c3', \@top, $cxw, $cyw, $lx * 0.85 - $ax * 0.5, $ly * 0.85 - $ay * 0.5, 0.3, $cxw - $lx * $W * 0.06 + $ax * $ry * 0.3, $cyw - $ly * $W * 0.06 + $ay * $ry * 0.3, 0.88);
}

# ---- Top-down view ----------------------------------------------------------------------------
# A chanterelle cap from above at (x,y) radius r: lobed wavy golden funnel with a shallow hollow
# (shaded upper-left inner wall), pale lit lip upper left, rolled shaded lip lower right, folds at the dips.
sub cap {
  my ($x, $y, $r, $seed, $young) = @_; $young //= 0;
  my $R = lobes($seed, $young ? 0.06 : 0.15);
  srand($seed + 3); my $rot = rand(2 * pi); my $sq = 0.86 + rand(0.14);
  my $N = 36;
  my @o = map { my $th = 2 * pi * $_ / $N; my $k = $R->($th); my ($c, $s) = (cos($th) * $r * $k, sin($th) * $r * $k * $sq);
    [$x + $c * cos($rot) - $s * sin($rot), $y + $c * sin($rot) + $s * cos($rot)] } 0 .. $N - 1;
  poly('c2', @o);
  crescent('c1', \@o, $x, $y, 0.7071, 0.7071, 0.2, $x - $r * 0.15, $y - $r * 0.15, 0.88);
  crescent('c3', \@o, $x, $y, -0.7071, -0.7071, 0.4, $x + $r * 0.2, $y + $r * 0.2, 0.88) unless $young;
  if ($young) {   # young: still a convex button with an inrolled margin, a soft dimple, lit upper left
    poly('c3', map { [$x - $r * 0.3 + ($_->[0] - $x) * 0.3, $y - $r * 0.3 + ($_->[1] - $y) * 0.3] } @o);
    poly('c1', map { [$x + $r * 0.05 + ($_->[0] - $x) * 0.16, $y + $r * 0.05 + ($_->[1] - $y) * 0.16] } @o);
    return;
  }
  my $hk = 0.56;
  my ($hx, $hy) = ($x + $r * 0.04, $y + $r * 0.04);
  my @h = map { [$hx + ($_->[0] - $x) * $hk, $hy + ($_->[1] - $y) * $hk] } @o;
  poly('c1', @h);
  crescent('c2', \@h, $hx, $hy, 0.7071, 0.7071, -0.35, $hx - $r * 0.22, $hy - $r * 0.22, 0.55);
  return if $young;
  # folds: creases from the dips in the wavy rim toward the hollow
  for my $i (0 .. $N - 1) {
    my $th = 2 * pi * $i / $N; next unless $R->($th) < $R->($th - 2 * pi / $N) && $R->($th) <= $R->($th + 2 * pi / $N);
    my $p = $o[$i]; my $q = $h[$i]; my ($ex, $ey) = ($p->[0] - $x, $p->[1] - $y); my $l = sqrt($ex * $ex + $ey * $ey) || 1;
    my ($qx, $qy) = (-$ey / $l * ($r * 0.05 + 0.6), $ex / $l * ($r * 0.05 + 0.6));
    poly('c1', [$p->[0] + $qx, $p->[1] + $qy], [$p->[0] + ($q->[0] - $p->[0]) * 0.75, $p->[1] + ($q->[1] - $p->[1]) * 0.75], [$p->[0] - $qx, $p->[1] - $qy]);
  }
}

# A pin (baby chanterelle from above): small rounded golden knob with lit and shaded halves.
sub pin {
  my ($x, $y, $r) = @_;
  my @o = map { my $th = 2 * pi * $_ / 12; [$x + cos($th) * $r, $y + sin($th) * $r * 0.94] } 0 .. 11;
  poly('c1', @o);
  poly('c2', map { [$x - $r * 0.12 + ($_->[0] - $x) * 0.8, $y - $r * 0.12 + ($_->[1] - $y) * 0.8] } @o);
  crescent('c3', \@o, $x, $y, -0.7071, -0.7071, 0.5, $x + $r * 0.3, $y + $r * 0.3, 0.7) if $r > 7;
}

# A clump seen from above. Leaners: [angle, base distance, height, rim width, tilt] lie outward from the
# middle so their ridged flare and wavy funnel show; caps: [x, y, r] stand upright in the middle.
sub clump {
  my ($seed, $lean, $caps, $young) = @_;
  my $k = 0;
  for my $m (sort { $a->[3] <=> $b->[3] } @$lean) {
    my ($a, $bd, $h, $W, $tilt) = @$m; my ($dx, $dy) = dir($a);
    srand($seed * 3 + $k); my $tl = $tilt // (0.5 + rand(0.2));
    fshroom(200 + $dx * $bd, 200 + $dy * $bd, $a + rand(10) - 5, $h, $W, $seed + $k++, $tl);
  }
  cap($_->[0], $_->[1], $_->[2], $seed + 50 + $k++, $young) for sort { $a->[2] <=> $b->[2] } @$caps;
}

# ---- Ground -----------------------------------------------------------------------------------
sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o;
  srand($seed);
  for my $i (0 .. 13) { my $th = 2 * pi * $i / 14; my $k = 0.84 + rand(0.26); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
}
# Moss cushion: lumpy green blob with a shaded lower-right crescent and a few lit bumps; $dry = dead straw moss.
sub moss {
  my ($x, $y, $r, $seed, $dry) = @_; srand($seed);
  my @o = map { my $th = 2 * pi * $_ / 14; my $k = ($_ % 2 ? 0.88 : 1.0) * (0.92 + rand(0.14)); [$x + cos($th) * $r * $k, $y + sin($th) * $r * 0.85 * $k] } 0 .. 13;
  poly($dry ? 'c1' : 'c5', @o);
  crescent('c4', \@o, $x, $y, 0.7071, 0.7071, 0.2, $x - $r * 0.3, $y - $r * 0.3, 0.75);
}
# Pale mycelium threads spreading out through the soil.
sub threads {
  my ($n, $len, $seed, $x0, $y0) = @_; $x0 //= 200; $y0 //= 200; srand($seed);
  for my $i (0 .. $n - 1) {
    my $a = $i * 360 / $n + rand(24); my ($x, $y) = ($x0, $y0); my (@l, @r);
    for my $k (0 .. 4) { my ($dx, $dy) = dir($a + rand(50) - 25); my $w = 1.6 - $k * 0.28;
      push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w]; $x += $dx * $len / 5; $y += $dy * $len / 5; }
    poly('c3', @l, [$x, $y], reverse @r);
  }
}
sub cracks {
  my ($n, $seed, $seg) = @_; srand($seed);
  for my $i (0 .. $n - 1) {
    my $a = $i * 360 / $n + rand(20); my ($x, $y) = (200, 200); my (@l, @r);
    for my $k (0 .. 4) { my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.6 - $k * 0.45;
      push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w]; $x += $dx * $seg; $y += $dy * $seg; }
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

# Pale mycelium web on a front face: wandering, branching threads.
sub web {
  my ($x0, $y0, $w, $h, $n, $seed, $clip) = @_; srand($seed);
  for (1 .. $n) {
    my ($x, $y) = ($x0 + rand($w), $y0 + rand($h)); my $a = rand(360);
    for my $k (0 .. 2 + int(rand(3))) {
      my $l = 9 + rand(12); $a += rand(70) - 35; my ($dx, $dy) = dir($a); my $t = 1.5 - $k * 0.2;
      my ($ex, $ey) = ($x + $dx * $l, $y + $dy * $l);
      last unless $clip->($ex, $ey);
      poly('c3', [$x - $dy * $t, $y + $dx * $t], [$ex - $dy * $t * 0.6, $ey + $dx * $t * 0.6], [$ex + $dy * $t * 0.6, $ey - $dx * $t * 0.6], [$x + $dy * $t, $y - $dx * $t]);
      if (rand(1) < 0.4) { my ($bx, $by) = dir($a + (rand(1) < .5 ? 50 : -50)); poly('c3', [$ex, $ey - 1], [$ex + $bx * $l * 0.6, $ey + $by * $l * 0.6], [$ex, $ey + 1]); }
      ($x, $y) = ($ex, $ey);
    }
  }
}

# ===============================================================================================
# 1. Spawn, front: a mossy forest-floor plug laced with cream mycelium, golden pins breaking out of the moss.
{
  my @blk; srand(14);
  for my $i (0 .. 23) { my $th = pi + pi * $i / 23; my $rx = 96; my $k = 0.95 + rand(0.08);
    push @blk, [200 + cos($th) * $rx * $k, 226 - sin($th) * 92 * $k * (sin($th) > 0 ? 1.05 : 1)]; }
  # crumbly block: top edge at y~226, rounded bottom down to ~322
  my @o = ([110, 214], [150, 204], [200, 208], [252, 200], [290, 214]);
  push @o, map { my $th = pi * $_ / 12; my $k = $_ % 2 ? 0.96 : 1.0; [200 + cos($th) * 94 * $k, 228 + sin($th) * 92 * $k] } 0 .. 12;
  poly('c4', @o);
  web(108, 214, 186, 116, 15, 15, sub { my ($x, $y) = @_; (($x - 200) / 92) ** 2 + (($y - 226) / 94) ** 2 < 0.96 && $y > 214 });
  for ([136, 210, 30, 3], [264, 206, 30, 4], [200, 204, 38, 5], [168, 198, 24, 6], [232, 196, 26, 7]) { moss(@$_); }
  fshroom(222, 198, -84, 50, 50, 21, 0.26);
  fshroom(170, 196, -102, 26, 24, 22, 0.24);
  pin(258, 192, 7);
}
write_svg('1-seeds-front.svg', 'Chanterelle spawn plug');

# 2. Just sown, top down: little mossy spawn plugs set into soil pockets, mycelium reaching out.
my @sown = ([168, 170, 1], [238, 166, 2], [204, 230, 3]);
for (@sown) { soil($_->[0], $_->[1], 34, 29, int($_->[0] * 7 + $_->[1])); }
for (@sown) { threads(7, 30, $_->[2] + 30, $_->[0], $_->[1]); moss($_->[0], $_->[1], 17, $_->[2] + 40); pin($_->[0] + 3, $_->[1] - 1, 4); }
write_svg('2-sown.svg', 'Chanterelle just sown');

# 3. First growth: mycelium spreading through a mossy patch, golden pins pushing up.
soil(200, 200, 66, 58, 3);
threads(11, 58, 31);
moss(150, 160, 18, 33); moss(252, 240, 16, 34); moss(244, 152, 13, 35);
pin(200, 196, 15); pin(174, 222, 11); pin(228, 184, 12); pin(216, 228, 9); pin(180, 176, 8);
write_svg('3-first-growth.svg', 'Chanterelle first growth');

# 4. Second growth: young chanterelles, rounded buttons in the middle, small trumpets leaning out.
soil(200, 200, 80, 72, 4);
threads(10, 76, 41);
moss(124, 246, 18, 43); moss(278, 154, 16, 44);
clump(40, [[-150, 16, 58, 50, 0.55], [-48, 18, 54, 46, 0.55], [42, 16, 62, 54, 0.55], [130, 18, 52, 46, 0.55]], [[196, 204, 25], [224, 176, 18], [172, 178, 16]], 1);
pin(254, 240, 9); pin(150, 148, 8);
write_svg('4-second-growth.svg', 'Chanterelle second growth');

# 5. Third growth: a loose clump of golden funnels opening up, wavy margins.
soil(200, 200, 86, 78, 5);
moss(120, 270, 20, 53); moss(292, 134, 18, 54);
clump(50, [[-160, 26, 80, 70], [-104, 32, 66, 60], [-40, 26, 84, 74], [28, 32, 70, 62], [92, 26, 80, 70], [158, 32, 64, 58], [222, 28, 74, 66]],
          [[198, 196, 34], [232, 228, 24], [168, 226, 22], [238, 164, 20]]);
write_svg('5-third-growth.svg', 'Chanterelle third growth');

# 6. Harvest: a generous clump of big wavy golden trumpets and open funnels filling the tile.
soil(200, 200, 92, 84, 6);
moss(104, 296, 20, 63); moss(300, 108, 18, 64);
clump(60, [[-164, 34, 104, 96], [-104, 46, 86, 84], [-44, 34, 108, 100], [22, 46, 90, 86], [84, 34, 104, 96], [148, 46, 88, 84], [212, 38, 100, 92]],
          [[200, 192, 44], [246, 236, 32], [154, 236, 30], [252, 154, 28], [150, 154, 26]]);
write_svg('6-harvest.svg', 'Chanterelle ready to harvest');

# 7. Harvest, front: four picked chanterelles of different sizes, ridges showing, one lying in front.
fshroom(206, 318, -91, 124, 136, 73, 0.4);
fshroom(262, 332, -70, 90, 100, 72, 0.42);
fshroom(148, 338, -110, 82, 94, 71, 0.42);
fshroom(150, 376, -5, 92, 90, 74, 0.42);
write_svg('7-harvest-front.svg', 'Harvested chanterelles');

# 8. Dead (never watered): cracked dry soil, dried moss, shrivelled brown chanterelles collapsed flat.
soil(200, 200, 84, 76, 8);
cracks(9, 83, 17);
moss(140, 258, 16, 85, 1); moss(266, 146, 14, 86, 1);
{
  local %MAP = (c2 => 'c1', c1 => 'c4'); local $SHR = 1;
  srand(88);
  for my $m ([-140, 84, 74], [-70, 92, 80], [-2, 80, 70], [66, 90, 78], [136, 82, 72], [206, 88, 76]) {
    my ($a, $h, $W) = @$m; my ($dx, $dy) = dir($a);
    fshroom(200 + $dx * 18, 200 + $dy * 18, $a + rand(16) - 8, $h, $W, 90 + $a, 0.26);
  }
}
sub deadcap {   # a collapsed, shrivelled cap lying flat: brown, deeply wrinkled, pale dried edge
  my ($x, $y, $r, $ang, $seed) = @_; my $R = lobes($seed, 0.2); srand($seed);
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o; my $n = 26;
  for my $i (0 .. $n - 1) { my $th = 2 * pi * $i / $n; my $k = $R->($th) * ($i % 2 ? 0.93 : 1.0);
    my $u = cos($th) * $r * $k; my $v = sin($th) * $r * 0.8 * $k; push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v]; }
  poly('c3', @o);
  my @lt = map { [$x + $r * 0.05 + ($_->[0] - $x) * 0.86, $y + $r * 0.05 + ($_->[1] - $y) * 0.86] } @o;
  poly('c1', @lt);
  crescent('c4', \@lt, $x, $y, 0.7071, 0.7071, -0.1, $x - $r * 0.35, $y - $r * 0.35, 0.55);
  for my $i (grep { $_ % 3 == 1 } 0 .. $n - 1) {   # deep shrivel wrinkles
    my $p = $lt[$i]; my ($wx, $wy) = ($x + ($p->[0] - $x) * 0.2, $y + ($p->[1] - $y) * 0.2);
    my ($ex, $ey) = ($p->[0] - $wx, $p->[1] - $wy); my $l = sqrt($ex * $ex + $ey * $ey) || 1; ($ex, $ey) = (-$ey / $l * 2.4, $ex / $l * 2.4);
    poly('c4', [$p->[0] + $ex, $p->[1] + $ey], [$wx, $wy], [$p->[0] - $ex, $p->[1] - $ey]);
  }
}
deadcap(194, 194, 34, 30, 99); deadcap(226, 222, 22, 100, 98);
write_svg('8-dead.svg', 'Chanterelle died from lack of water');
print "wrote 8 files to $OUT\n";

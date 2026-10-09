# Bush bean (green bean) crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/beans.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/beans';
mkdir 'crops'; mkdir $OUT;
# c1 deep bean-leaf green, c2 lit leaf green (also the pods' shaded side), c3 warm cream (flowers, seed coat,
# glints, dry leaves), c4 dark soil brown (soil, seed speckles, shade), c5 fresh lime pod green
my %PAL = (c1 => "#2B6233", c2 => "#5FA444", c3 => "#F4EBCB", c4 => "#5A3A22", c5 => "#BCE052");
my @S;
our $WILT = 0;   # the dead plant's leaflets shrivel and curl
our $PODSHADOW = 0;   # offset of a dark cast shadow under each pod
our $SPOTS = 0;
our @PODC = qw(c5 c2 c3 c2 c1);   # pod body, shaded band, glint, beak lit, beak dark
our $PODBAND = 0.4;  # where the shaded band starts (0 = the midrib, 1 = the edge)

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Tapered blade or stalk (as in wheat). $taper < 1 keeps width at the tip. Returns the end point and angle.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $taper) = @_;
  $taper //= 1;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $t) ** 0.85 + ($i == $n && $taper == 1 ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang); my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
  return (@{$mid[-1]}, $a - $bend / $n);
}

# End point of a bent path (same stepping as blade).
sub walk {
  my ($x, $y, $ang, $len, $bend, $upto) = @_; $upto //= 1;
  my $n = 10; my $a = $ang;
  for my $i (1 .. int($n * $upto + 0.5)) { my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  return ($x, $y, $a);
}

# A bean leaflet: broad rounded base, widest at a third, drawn out into a long pointed tip (ovate-acuminate).
# Split along the midrib into a lit and a shaded half; $veins adds two pairs of side-vein facets.
sub leaflet {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $veins) = @_;
  my $n = 16; my (@mid, @l, @r, @hw);
  my ($px, $py, $a) = ($x, $y, $ang);
  my $wilt = $main::WILT;
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my $hw = $w / 2 * sin(pi * $t ** 0.58) ** 0.6;
    $hw *= (1 - 0.3 * $t ** 4);                     # pull the tip into a sharper point
    $hw *= 1 - $wilt * (0.45 + 0.2 * sin($t * 11)) if $wilt;
    $hw = max($hw, 0.8) if $i < $n;
    my ($dx, $dy) = dir($a);
    push @mid, [$px, $py, $a]; push @hw, $hw;
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend * 0.4); my $leftLit = lit(-$dy, $dx);
  my @m = map { [$_->[0], $_->[1]] } @mid;
  poly($leftLit ? $light : $dark, @l, reverse @m);
  poly($leftLit ? $dark : $light, @r, reverse @m);
  return unless $veins;
  # side veins: thin darker wedges on the lit half, lighter ones on the shaded half
  for my $k (0 .. 1) {
    my $i = int($n * (0.22 + 0.2 * $k)); my ($mx, $my, $ma) = @{$mid[$i]};
    for my $side (-1, 1) {
      my $isLeft = $side < 0; my $cls = ($isLeft == !!$leftLit) ? $dark : $light;
      my $va = $ma + $side * 48; my ($vx, $vy) = dir($va); my $vl = $hw[$i] * 1.05;
      my ($ex, $ey) = ($mx + $vx * $vl, $my + $vy * $vl);
      my ($fx, $fy) = dir($ma);
      poly($cls, [$mx - $fx * 1.2, $my - $fy * 1.2], [$ex, $ey], [$mx + $fx * 3.2, $my + $fy * 3.2]);
    }
  }
}

# A trifoliate bean leaf: petiole, a pair of side leaflets and a larger terminal leaflet on a short rachis.
sub trifol {
  my ($x, $y, $ang, $plen, $L, $bend, $light, $dark, $veins, $spread) = @_;
  $light //= 'c2'; $dark //= 'c1'; $spread //= 68;
  my ($ex, $ey, $ea) = walk($x, $y, $ang, $plen, $bend);
  my $wr = $main::WILT ? 1.6 : 1;
  for my $side (-1, 1) {
    leaflet($ex, $ey, $ea + $side * $spread, $L * 0.82, $L * 0.66, -$side * 14 * $wr, $light, $dark, $veins);
  }
  blade($x, $y, $ang, $plen, max(3.5, $L * 0.07), $bend, $light, $dark, 0.5);
  my ($fx, $fy) = dir($ea);
  blade($ex, $ey, $ea, $L * 0.26, max(3, $L * 0.06), 0, $light, $dark, 0.4);
  leaflet($ex + $fx * $L * 0.22, $ey + $fy * $L * 0.22, $ea, $L, $L * 0.74, $bend * 0.3 + ($main::WILT ? 40 : 0), $light, $dark, $veins);
}

# Simple heart-shaped primary leaf (the first true leaves of a bean seedling).
sub primary { my ($x, $y, $ang, $len) = @_;
  blade($x, $y, $ang, $len * 0.3, 5, 0, 'c2', 'c1', 0.5);
  my ($ex, $ey) = walk($x, $y, $ang, $len * 0.3, 0);
  leaflet($ex, $ey, $ang, $len, $len * 0.86, 0, 'c2', 'c1', 1);
}

# Long slim green bean pod: blunt stem end with a little calyx, gently curved, tapering to a thin hooked beak.
# Faint bulges along the seam hint at the beans inside (slim, never plump like peas).
sub pod {
  my ($x, $y, $ang, $len, $w, $bend, $calyx) = @_;
  $calyx //= 1;
  my $n = 22; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my $hw = $w / 2 * min(1, ($t / 0.1)) ** 0.6 * min(1, ((1 - $t) / 0.22)) ** 0.9;
    $hw *= 1 + ($main::WILT ? 0.22 : 0.045) * cos(2 * pi * 5 * $t) if $t > 0.12 && $t < 0.8;
    $hw = max($hw, 0.7) if $i < $n;
    my ($dx, $dy) = dir($a);
    push @mid, [$px, $py, $a];
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2); my $leftLit = lit(-$dy, $dx);
  my @m = map { [$_->[0], $_->[1]] } @mid;
  my $sh = $main::PODSHADOW;
  poly('c1', map { [$_->[0] + $sh, $_->[1] + $sh * 1.3] } @l, reverse @r) if $sh;   # cast shadow
  poly($main::PODC[0], @l, reverse @r);
  my @dk = $leftLit ? @r : @l;   # shaded band along the lower edge
  poly($main::PODC[1], @dk, reverse map { [$m[$_][0] + ($dk[$_][0] - $m[$_][0]) * $main::PODBAND, $m[$_][1] + ($dk[$_][1] - $m[$_][1]) * $main::PODBAND] } 0 .. $#m);
  # glint: a thin cream streak along the lit half
  my $side = $leftLit ? -1 : 1; my (@g1, @g2);
  for my $i (int($n * 0.16) .. int($n * 0.66)) {
    my ($mx, $my, $ma) = @{$mid[$i]}; my ($ex, $ey) = dir($ma);
    my $t = ($i - $n * 0.16) / ($n * 0.5); my $gw = $w * 0.1 * sin(pi * $t) ** 0.6;
    my $o = $w * 0.2;
    push @g1, [$mx - $ey * $side * ($o - $gw) * -1, $my + $ex * $side * ($o - $gw) * -1];
    push @g2, [$mx - $ey * $side * ($o + $gw) * -1, $my + $ex * $side * ($o + $gw) * -1];
  }
  poly($main::PODC[2], @g1, reverse @g2) unless $main::PODC[2] eq $main::PODC[0];
  # beak: thin curved tail at the tip
  my ($tx, $ty, $ta) = @{$mid[-1]};
  blade($tx - cos(deg2rad($ta)) * 2, $ty - sin(deg2rad($ta)) * 2, $ta, $len * 0.09, max(2.2, $w * 0.22), $bend > 0 ? 40 : -40, $main::PODC[3], $main::PODC[4]);
  if ($calyx) {   # small green calyx cap at the stem end
    my ($sx, $sy, $sa) = @{$mid[0]};
    for my $k (-1, 1) { blade($sx, $sy, $sa + $k * 30, $w * 0.6, $w * 0.36, -$k * 14, "c1", "c1"); }
    blade($sx, $sy, $sa + 180, $w * 0.55, $w * 0.3, 0, "c2", "c1", 0.5);
  }
  return @{$mid[0]};
}

# Small bean flower: a broad rounded banner petal with the wings cupped in front, on a green calyx.
sub flower {
  my ($x, $y, $r, $ang) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  blade($x - $dx * $r * 0.4, $y - $dy * $r * 0.4, $ang + 180, $r * 0.7, $r * 0.5, 0, 'c2', 'c1');   # calyx/pedicel
  my @b;    # banner: a wide fan opening away from the calyx
  for my $k (0 .. 12) {
    my $th = deg2rad(-100 + $k * 200 / 12); my $rr = $r * (1 - 0.12 * abs(sin($th * 2)));
    push @b, [$x + ($dx * cos($th) + $nx * sin($th)) * $rr, $y + ($dy * cos($th) + $ny * sin($th)) * $rr];
  }
  my @half = lit($nx, $ny) ? (@b[0 .. 6]) : (@b[6 .. 12]);
  poly('c3', [$x - $dx * $r * 0.2, $y - $dy * $r * 0.2], @b);
  shade_rim($x, $y, $r, 'c5', 0.72, @b);
  # wings: two little cupped petals in front with a notch between them
  for my $s (-1, 1) {
    my $cx = $x + $dx * $r * 0.1 + $nx * $s * $r * 0.26; my $cy = $y + $dy * $r * 0.1 + $ny * $s * $r * 0.26;
    my @w = map { my $th = 2 * pi * $_ / 8; [$cx + ($dx * cos($th) * 0.5 + $nx * sin($th) * 0.32) * $r, $cy + ($dy * cos($th) * 0.5 + $ny * sin($th) * 0.32) * $r] } 0 .. 7;
    poly(lit($nx * $s, $ny * $s) ? 'c3' : 'c5', @w);
  }
  poly('c1', [$x + $dx * $r * 0.08, $y + $dy * $r * 0.08], [$x + $dx * $r * 0.5 + $nx * 1.5, $y + $dy * $r * 0.5 + $ny * 1.5],
             [$x + $dx * $r * 0.5 - $nx * 1.5, $y + $dy * $r * 0.5 - $ny * 1.5]);
}

# Shaded crescent along the lower-right edge of any outline @o around (x,y).
sub shade_rim {
  my ($x, $y, $r, $cls, $kmin, @o) = @_;
  my $n = @o;
  my @d = map { my ($vx, $vy) = ($_->[0] - $x, $_->[1] - $y); my $l = sqrt($vx * $vx + $vy * $vy) || 1; ($vx + $vy) * 0.7071 / $l } @o;
  my $s = 0; for my $i (0 .. $n - 1) { if ($d[$i] > 0.1 && $d[($i - 1) % $n] <= 0.1) { $s = $i; last } }
  my ($cx, $cy) = ($x - $r * 0.3, $y - $r * 0.3);
  my (@out, @in);
  for my $j (0 .. $n - 1) {
    my $i = ($s + $j) % $n; last unless $d[$i] > 0.1;
    my $k = $kmin + (1 - $kmin) * (1 - ($d[$i] - 0.1) / 0.9) ** 1.5;
    push @out, $o[$i]; push @in, [$cx + ($o[$i][0] - $cx) * $k, $cy + ($o[$i][1] - $cy) * $k];
  }
  poly($cls, @out, reverse @in) if @out > 1;
}

# A kidney-shaped seed bean: cream coat with maroon-brown speckles, a shaded rim and a small dark eye
# (hilum) in the middle of the inner, hollow edge.
sub seedbean {
  my ($x, $y, $ang, $len, $w, $seed, $spots) = @_;
  $spots //= 4;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $P = sub { my ($u, $v) = @_; [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v] };
  # kidney: a full oval with a soft dent in the middle of one long side (where the eye sits),
  # the whole bean bowed a little around that dent
  my @o; my $m = 32;
  for my $i (0 .. $m - 1) {
    my $th = 2 * pi * $i / $m;
    my $c = cos($th); my $s = sin($th);
    my $u = $c * $len / 2; my $v = $s * $w / 2 * (1 + 0.06 * (1 - $c * $c));
    my $g = exp(-($u / ($len * 0.2)) ** 2);
    $v += $w * 0.22 * $g if $s < 0;               # the dent on the -n side
    $v += $w * 0.1 * (1 - (2 * $u / $len) ** 2);   # bow
    push @o, $P->($u, $v);
  }
  poly('c3', @o);
  srand($seed);
  if ($spots) {
    for my $k (1 .. $spots) {           # maroon streaks running along the bean
      my $u0 = (rand(1.4) - 0.7) * $len / 2; my $e = max(0.05, 1 - (2 * $u0 / $len) ** 2);
      my $v0 = (rand(1.1) - 0.45) * $w / 2 * sqrt($e) + $w * 0.1 * $e; my $ul = $len * (0.08 + rand(0.12)); my $sw = $w * (0.04 + rand(0.04));
      my $sa = rand(30) - 15; my ($ax, $ay) = dir($ang + $sa);
      my $c = $P->($u0, $v0);
      poly('c4', map { my $th = 2 * pi * $_ / 6; [$c->[0] + $ax * cos($th) * $ul / 2 - $ay * sin($th) * $sw, $c->[1] + $ay * cos($th) * $ul / 2 + $ax * sin($th) * $sw] } 0 .. 5);
    }
  }
  my $c = $P->(0, $w * 0.08);
  shade_rim($c->[0], $c->[1], $len * 0.42, "c4", 0.9, @o);
  # hilum: small dark eye with a pale ring, set in the dent
  my $h = $P->(0, -$w * 0.1);
  poly('c3', map { my $th = 2 * pi * $_ / 8; [$h->[0] + ($dx * cos($th) * 0.15 * $len + $nx * sin($th) * 0.1 * $w), $h->[1] + ($dy * cos($th) * 0.15 * $len + $ny * sin($th) * 0.1 * $w)] } 0 .. 7);
  poly('c4', map { my $th = 2 * pi * $_ / 8; [$h->[0] + ($dx * cos($th) * 0.1 * $len + $nx * sin($th) * 0.055 * $w), $h->[1] + ($dy * cos($th) * 0.1 * $len + $ny * sin($th) * 0.055 * $w)] } 0 .. 7);
}

sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o; srand($seed);
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12; my $k = 0.82 + rand(0.3); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
}

sub cracks {
  my ($n, $seed, $seg, $cls) = @_;
  srand($seed);
  for my $i (0 .. $n - 1) {
    my $a = $i * 360 / $n + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
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

# A bush of trifoliate leaves radiating from the centre; longer ones first so the inner ones lie on top.
sub bush {
  my ($n, $plen, $pvar, $L, $Lvar, $bendMax, $seed, $start, $veins) = @_;
  srand($seed); my @b;
  for my $i (0 .. $n - 1) {
    my $a = $start + $i * 360 / $n + rand(16) - 8;
    push @b, [$a, $plen + rand($pvar), $L + rand($Lvar), (rand(1) < 0.5 ? -1 : 1) * $bendMax * (0.4 + rand(0.6))];
  }
  for (sort { $b->[1] <=> $a->[1] } @b) {
    my ($a, $p, $l, $bend) = @$_; my ($dx, $dy) = dir($a);
    trifol(200 + $dx * 4, 200 + $dy * 4, $a, $p, $l, $bend, 'c2', 'c1', $veins);
  }
}

# A cluster of pods hanging out from under the leaves at angle $a: short green stalk, then 2-3 pods fanning.
sub pods_top {
  my ($a, $from, $len, $w, $seed, $n, $curve) = @_;
  my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
  my ($sx, $sy) = (200 + $dx * $from, 200 + $dy * $from);
  my ($ex, $ey) = blade($sx, $sy, $a, 24, 5, 0, 'c2', 'c1', 0.5);
  srand($seed);
  for my $k (0 .. $n - 1) {     # a hanging bunch: pods side by side, nearly parallel
    my $o = ($k - ($n - 1) / 2);
    pod($ex + $nx * $o * $w * 0.7, $ey + $ny * $o * $w * 0.7, $a + $o * 12 + rand(6) - 3, $len * (0.9 + rand(0.16)), $w, $curve * (0.8 + rand(0.4)));
  }
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a small heap of speckled kidney beans.
for my $s ([118, 300, 12, 1], [204, 318, -4, 2], [288, 296, 170, 3], [160, 244, 28, 4], [248, 240, 150, 5]) {
  seedbean($s->[0], $s->[1], $s->[2], 100, 58, $s->[3], $main::SPOTS);
}
write_svg('1-seeds-front.svg', 'Bean seeds');

# 2. Just sown, top down: big bean seeds pressed into soil pockets.
my @sown = ([164, 170, -24], [240, 166, 30], [202, 236, 96]);
soil($_->[0], $_->[1], 36, 30, int($_->[0] * 7 + $_->[1])) for @sown;
seedbean($_->[0], $_->[1], $_->[2], 44, 28, int($_->[0] + $_->[1]), 0) for @sown;
write_svg('2-sown.svg', 'Beans just sown');

# 3. First growth, top down: the bean seed halves (cotyledons) open, two heart-shaped first leaves.
soil(200, 200, 34, 30, 3);
primary(200, 200, -150, 66);
primary(200, 200, 30, 66);
for my $s (-1, 1) { seedbean(200 + $s * 12, 200 + $s * 14, 70 + ($s < 0 ? 180 : 0), 26, 18, 9, 0); }
trifol(200, 200, -70, 8, 18, 0, 'c2', 'c1', 0, 60);
write_svg('3-first-growth.svg', 'Bean first growth');

# 4. Second growth, top down: young plant: the two first leaves and the first trifoliate leaves.
soil(200, 200, 34, 30, 4);
primary(200, 200, -160, 74); primary(200, 200, 20, 74);
bush(4, 34, 10, 66, 10, 18, 41, -80, 1);
write_svg('4-second-growth.svg', 'Bean second growth');

# 5. Third growth, top down: a leafy bush with small white flowers and the first tiny pods.
soil(200, 200, 34, 30, 5);
bush(8, 52, 14, 80, 10, 22, 51, -90, 1);
my @fl;
for my $f ([-42, 78, 0], [24, 96, 1], [96, 74, 0], [158, 96, 1], [222, 76, 0], [292, 94, 1]) {
  my ($a, $d, $pd) = @$f; my ($dx, $dy) = dir($a);
  push @fl, [blade(200 + $dx * 20, 200 + $dy * 20, $a, $d - 20, 4.5, 10, 'c2', 'c1', 0.5), $pd];
}
bush(4, 18, 8, 62, 8, 16, 52, -45, 1);
for (@fl) {
  my ($ex, $ey, $ea, $pd) = @$_;
  $PODSHADOW = 2;
  if ($pd) { pod($ex, $ey, $ea + 25, 40, 8, 18); }
  $PODSHADOW = 0;
  flower($ex + cos(deg2rad($ea - 40)) * 12, $ey + sin(deg2rad($ea - 40)) * 12, 12, $ea - 40);
  flower($ex + cos(deg2rad($ea + 10)) * 15, $ey + sin(deg2rad($ea + 10)) * 15, 13, $ea + 5);
  flower($ex, $ey, 10, $ea - 5) unless $pd;
}
write_svg('5-third-growth.svg', 'Bean third growth');

# 6. Harvest, top down: a full bush hung with bunches of long slim green pods.
bush(10, 62, 16, 86, 12, 24, 61, -90, 1);
bush(5, 22, 8, 64, 8, 16, 62, -55, 1);
$PODSHADOW = 3;
pods_top(-70, 30, 118, 12, 1, 2, 18);
pods_top(-10, 30, 122, 12, 2, 3, -16);
pods_top(52, 30, 116, 12, 3, 2, 20);
pods_top(112, 30, 120, 12, 4, 3, -18);
pods_top(172, 30, 116, 12, 5, 2, 16);
pods_top(232, 30, 120, 12, 6, 3, -14);
$PODSHADOW = 0;
write_svg('6-harvest.svg', 'Beans ready to harvest');

# 7. Harvest, front view: a loose heap of freshly picked green beans, stem ends left, beaks right.
$PODSHADOW = 4;
pod(78, 214, -22, 268, 23, 14);
pod(66, 200, 4, 278, 23, -12);
pod(84, 250, -10, 272, 24, 10);
pod(70, 236, 16, 262, 23, -18);
pod(104, 278, -4, 262, 24, -8);
$PODSHADOW = 0;
write_svg('7-harvest-front.svg', 'Harvested green beans');

# 8. Dead (never watered), top down: cracked dry soil and a collapsed, shrivelled plant lying flat.
soil(200, 200, 54, 46, 8);
cracks(7, 83, 10, 'c3');
$WILT = 1;
@PODC = qw(c3 c4 c3 c3 c4);
srand(81);
for my $i (0 .. 5) {
  my $a = -100 + $i * 60 + rand(16) - 8;
  trifol(200, 200, $a, 40 + rand(14), 50 + rand(12), ($i % 2 ? -1 : 1) * (24 + rand(30)), 'c3', 'c4', 0, 46);
}
pod(176, 236, 128, 80, 11, 26, 0);              # two shrivelled little pods lying on the soil
pod(236, 178, -40, 74, 11, -24, 0);
for ([-30, 20], [100, 16], [210, 18]) { blade(200, 200, $_->[0], $_->[1], 9, 0, 'c3', 'c4'); }
write_svg('8-dead.svg', 'Bean plant died from lack of water');
print "wrote 8 files to $OUT\n";

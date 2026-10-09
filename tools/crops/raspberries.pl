# Raspberry crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/raspberries.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/raspberries';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#2F6B3A', c2 => '#7FB65A', c3 => '#F7E8D0', c4 => '#4A2826', c5 => '#D63A66');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# End point and heading of a bent path (same stepping as blade).
sub reach {
  my ($x, $y, $ang, $len, $bend) = @_; my $a = $ang;
  for (1 .. 10) { my ($dx, $dy) = dir($a); $x += $dx * $len / 10; $y += $dy * $len / 10; $a += $bend / 10; }
  ($x, $y, $a);
}

# A tapered blade / stalk / sepal from (x,y) heading `ang`, bending `bend` degrees over its length.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark) = @_;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $t) ** 0.85 + ($i == $n ? 0 : 0.6);
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

# A curved stalk along a quadratic curve (x0,y0) -> control (cx,cy) -> (x1,y1), lit and shaded halves.
sub stalk {
  my ($x0, $y0, $cx, $cy, $x1, $y1, $w, $light, $dark) = @_;
  my (@l, @r, @m);
  for my $i (0 .. 14) {
    my $t = $i / 14; my $u = 1 - $t;
    my ($x, $y) = ($u * $u * $x0 + 2 * $u * $t * $cx + $t * $t * $x1, $u * $u * $y0 + 2 * $u * $t * $cy + $t * $t * $y1);
    my ($tx, $ty) = (2 * $u * ($cx - $x0) + 2 * $t * ($x1 - $cx), 2 * $u * ($cy - $y0) + 2 * $t * ($y1 - $cy));
    my $d = sqrt($tx * $tx + $ty * $ty) || 1; ($tx, $ty) = ($tx / $d, $ty / $d);
    my $hw = $w / 2 * (1 - 0.35 * $t);
    push @l, [$x - $ty * $hw, $y + $tx * $hw]; push @r, [$x + $ty * $hw, $y - $tx * $hw]; push @m, [$x, $y];
  }
  my ($tx, $ty) = ($x1 - $x0, $y1 - $y0); my $leftLit = lit(-$ty, $tx);
  poly($leftLit ? $light : $dark, @l, reverse @m);
  poly($leftLit ? $dark : $light, @r, reverse @m);
}

# A serrated leaflet split along its midrib into a lit and a shaded half, with vein grooves.
# p/q shape the outline (q small = broad and round), teeth start at fraction tstart.
sub leaflet {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, %o) = @_;
  my $N = $o{n} // 14; my $p = $o{p} // 0.9; my $q = $o{q} // 0.55; my $ts = $o{ts} // 0.28;
  my $deep = $o{deep} // 0.86;
  my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $N) {
    my $t = $i / $N; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (sin(pi * min(0.999, $t ** $p))) ** $q;
    $hw = $w / 2 * 0.12 if $i == $N;
    my $m = 1; my $fw = 0;
    if ($i > 0 && $i < $N && $t >= $ts) { if ($i % 2) { $fw = $len / $N * 0.4 } else { $m = $deep } }
    $hw *= $m;
    push @l, [$px - $dy * $hw + $dx * $fw, $py + $dx * $hw + $dy * $fw];
    push @r, [$px + $dy * $hw + $dx * $fw, $py - $dx * $hw + $dy * $fw];
    push @mid, [$px, $py, $dx, $dy, $w / 2 * (sin(pi * min(0.999, $t ** $p))) ** $q];
    $px += $dx * $len / $N; $py += $dy * $len / $N; $a += $bend / $N;
  }
  my $tip = [$px, $py];
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  my @m2 = map { [$_->[0], $_->[1]] } @mid;
  poly($leftLit ? $light : $dark, @l, $tip, reverse @m2);
  poly($leftLit ? $dark : $light, @r, $tip, reverse @m2);
  my $nv = $o{veins} // 0; return unless $nv;
  for my $k (1 .. $nv) {
    my $i = int($N * (0.12 + 0.72 * $k / ($nv + 1)));
    my ($mx, $my, $vx, $vy, $hw) = @{$mid[$i]};
    for my $side (-1, 1) {
      my ($sx, $sy) = (-$vy * $side, $vx * $side);              # side normal (side -1 = left)
      my $sideLit = ($side == -1) == ($leftLit ? 1 : 0);
      my $L = $hw * 0.78; my $vw = $o{vw} // 1.3;
      my @e = ($mx + $sx * $L + $vx * $L * 0.55, $my + $sy * $L + $vy * $L * 0.55);
      poly($sideLit ? $dark : $light, [$mx + $vx * $vw, $my + $vy * $vw], [@e], [$mx - $vx * $vw, $my - $vy * $vw]);
    }
  }
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


# Raspberry leaf: petiole, then a pinnate leaf of 5 (or 3) pointed, finely toothed, deeply veined leaflets.
sub rleaf {
  my ($x, $y, $ang, $plen, $llen, $light, $dark, %o) = @_;
  my $bend = $o{bend} // 0; my $curl = $o{curl} // 0; my $wk = $o{wk} // 0.72; my $five = $o{five} // 1;
  my %lo = (p => 0.8, q => 0.68, n => $o{n} // 18, ts => 0.14, deep => $o{deep} // 0.86, veins => $o{veins} // 5, vw => 1.1);
  my $rach = $five ? $llen * 0.42 : 0;
  blade($x, $y, $ang, $plen + $rach + $llen * 0.1, $o{pw} // 4, $bend, $light, $dark);
  my $Lt = $plen + $rach + $llen * 0.1;
  my ($px, $py, $pa) = reach($x, $y, $ang, $plen, $bend * $plen / $Lt);
  my ($ex, $ey, $ea) = reach($x, $y, $ang, $plen + $rach, $bend * ($plen + $rach) / $Lt);
  if ($five) {
    leaflet($px, $py, $pa - 78, $llen * 0.66, $llen * 0.66 * $wk, -$curl, $light, $dark, %lo);
    leaflet($px, $py, $pa + 78, $llen * 0.66, $llen * 0.66 * $wk, $curl, $light, $dark, %lo);
  }
  leaflet($ex, $ey, $ea - 58, $llen * 0.8, $llen * 0.8 * $wk, -$curl, $light, $dark, %lo);
  leaflet($ex, $ey, $ea + 58, $llen * 0.8, $llen * 0.8 * $wk, $curl, $light, $dark, %lo);
  my ($dx, $dy) = dir($ea);
  leaflet($ex + $dx * $llen * 0.1, $ey + $dy * $llen * 0.1, $ea, $llen, $llen * $wk, $curl * 0.4, $light, $dark, %lo);
}

# Ellipse point list.
sub ell { my ($x, $y, $rx, $ry, $n, $rot) = @_; $rot //= 0; map { my ($u, $v) = dir($rot + $_ * 360 / $n); [$x + $u * $rx, $y + $v * $ry] } 0 .. $n - 1 }

# A raspberry: a dark core covered by glossy bumpy drupelets (nearest ones drawn last, lit ones with a highlight).
sub rasp {
  my ($x, $y, $rx, $ry, %o) = @_;
  my $body = $o{body} // 'c5'; my $shade = $o{shade} // 'c4'; my $hi = $o{hi} // 'c3';
  poly($shade, ell($x, $y, $rx * 1.02, $ry * 1.02, 16));
  my $s = $rx * ($o{sp} // 0.44); my @d;
  my $row = 0;
  for (my $gy = -$ry; $gy <= $ry + 0.01; $gy += $s * 0.87) {
    for (my $gx = -$rx - ($row % 2 ? $s / 2 : 0); $gx <= $rx + 0.01; $gx += $s) {
      my $r2 = ($gx / $rx) ** 2 + ($gy / $ry) ** 2; next if $r2 > 0.9;
      push @d, [$gx, $gy, sqrt(1 - $r2)];
    }
    $row++;
  }
  for (sort { $a->[2] <=> $b->[2] } @d) {
    my ($gx, $gy, $z) = @$_;
    my $rd = $s * 0.62 * (0.62 + 0.38 * $z);
    my $shadow = ($gx / $rx + $gy / $ry) > 0.55;
    $rd *= 0.86 if $shadow;
    poly($body, ell($x + $gx, $y + $gy, $rd, $rd, 7, 10));
    next if $shadow || $o{nohi};
    my ($hx, $hy) = ($x + $gx - $rd * 0.36, $y + $gy - $rd * 0.36);
    poly($hi, [$hx - $rd * 0.3, $hy + $rd * 0.05], [$hx + $rd * 0.05, $hy - $rd * 0.3], [$hx + $rd * 0.12, $hy + $rd * 0.12]);
  }
}

# Raspberry sepals: a star of narrow pointed sepals (drawn under a top-down berry).
sub sepals {
  my ($x, $y, $r, $rot, $l, $d) = @_;
  for my $k (0 .. 4) { blade($x, $y, $rot + $k * 72, $r, $r * 0.32, 12, $l // 'c2', $d // 'c1'); }
}

# Hanging raspberry seen from the front: pedicel from (x,y) down to a thimble with reflexed sepals on top.
sub hang {
  my ($x, $y, $ang, $plen, $R, %o) = @_;
  blade($x, $y, $ang, $plen, 3.2, 0, 'c2', 'c1');
  my ($ex, $ey) = reach($x, $y, $ang, $plen, 0);
  for my $a (-160, -120, -60, -20) { blade($ex, $ey + 2, $a, $R * 0.95, $R * 0.32, ($a < -90 ? -24 : 24), 'c2', 'c1'); }
  rasp($ex, $ey + $R * 1.12, $R, $R * 1.2, %o);
}

# Small white raspberry flower: narrow petals, long green sepals between, a big green centre with stamens.
sub rflower {
  my ($x, $y, $r, $rot) = @_; $rot //= 0;
  for my $k (0 .. 4) { my $a = $rot + 36 + $k * 72; blade($x, $y, $a, $r * 1.3, $r * 0.36, 0, 'c2', 'c1'); }
  for my $k (0 .. 4) {
    my $a = $rot + $k * 72; my ($dx, $dy) = dir($a);
    poly('c3', ell($x + $dx * $r * 0.6, $y + $dy * $r * 0.6, $r * 0.48, $r * 0.48, 7, $a));
  }
  for my $k (0 .. 11) { my ($u, $v) = dir($k * 30); poly('c3', ell($x + $u * $r * 0.42, $y + $v * $r * 0.42, 2, 2, 4)); }
  my @c = ell($x, $y, $r * 0.34, $r * 0.34, 8, 22);
  poly('c2', @c); poly('c1', @c[0 .. 4]);
}

# Cut cane end seen from above: bark ring, pale pith, a reddish bud breaking beside it.
sub stub {
  my ($x, $y, $r) = @_;
  poly('c1', ell($x, $y, $r, $r, 10)); poly('c2', (ell($x, $y, $r, $r, 10))[5 .. 9], [$x + $r, $y]);
  poly("c3", ell($x, $y, $r * 0.6, $r * 0.6, 10));
}

# One cane top down from the crown: returns points along it [x, y, heading] for attaching leaves and fruit.
sub cane {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $prick) = @_;
  blade($x, $y, $ang, $len, $w, $bend, $light, $dark);
  my @p; my $a = $ang;
  for my $i (0 .. 10) {
    push @p, [$x, $y, $a];
    my ($dx, $dy) = dir($a); $x += $dx * $len / 10; $y += $dy * $len / 10; $a += $bend / 10;
  }
  if ($prick) {                                   # tiny prickles
    for my $i (2 .. 9) {
      my ($px, $py, $pa) = @{$p[$i]}; my $side = $i % 2 ? 1 : -1; my ($dx, $dy) = dir($pa);
      my ($nx, $ny) = (-$dy * $side, $dx * $side); my $hw = $w / 2 * (1 - $i / 10) ** 0.85;
      poly($prick, [$px + $nx * $hw - $dx * 2, $py + $ny * $hw - $dy * 2], [$px + $nx * ($hw + 4) + $dx * 2, $py + $ny * ($hw + 4) + $dy * 2], [$px + $nx * $hw + $dx * 1.5, $py + $ny * $hw + $dy * 1.5]);
    }
  }
  @p;
}

# A top-down bush: canes radiating from the crown with alternating pinnate leaves. Returns the cane point lists.
sub bush {
  my ($n, $len, $lvar, $llen, $seed, %o) = @_;
  srand($seed); my @c;
  for my $i (0 .. $n - 1) {
    push @c, [($o{start} // -90) + $i * 360 / $n + rand(16) - 8, $len + rand($lvar), (rand(1) < 0.5 ? -1 : 1) * (10 + rand(14))];
  }
  my $L = $o{light} // 'c2'; my $D = $o{dark} // 'c1';
  my @canes = map { [cane(200, 200, $_->[0], $_->[1], $o{cw} // 7, $_->[2], $o{clight} // $L, $o{cdark} // $D, $o{prick})] } @c;
  my @at = @{$o{at} // [0.45, 0.75]};
  for my $p (@canes) {
    my $k = 0;
    for my $f (@at) {
      my ($x, $y, $a) = @{$p->[int($f * 10)]}; my $side = $k++ % 2 ? 1 : -1;
      rleaf($x, $y, $a + $side * 52, $o{plen} // 10, $llen * (0.85 + 0.15 * $f), $L, $D, bend => $side * 8, %o);
    }
    my ($x, $y, $a) = @{$p->[10]};
    rleaf($x, $y, $a, 6, $llen, $L, $D, %o);              # terminal leaf at the cane tip
  }
  @canes;
}

# 1. Planting material, front view: three bare-root cane cuttings (straight woody rods) with reddish buds and roots.
for my $c ([166, -98, 170], [208, -86, 196], [246, -74, 150]) {
  my ($x, $a, $len) = @$c; my $y = 300; my $w = 15;
  for my $r ([90, 52, 14], [70, 44, -10], [112, 48, 12], [80, 34, 26], [100, 60, -6], [124, 36, -20], [60, 30, 16]) {
    blade($x + ($r->[0] - 95) * 0.2, $y - 2, $r->[0] + $a + 90, $r->[1], 4.4, $r->[2], 'c3', 'c4');
  }
  my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx); my ($tx, $ty) = ($x + $dx * $len, $y + $dy * $len);
  my $h = $w / 2;
  my @L = ([$x - $nx * $h, $y - $ny * $h], [$tx - $nx * $h, $ty - $ny * $h]); my @R = ([$x + $nx * $h, $y + $ny * $h], [$tx + $nx * $h, $ty + $ny * $h]);
  my $leftLit = lit(-$nx, -$ny);
  poly($leftLit ? 'c3' : 'c4', @L, [$tx, $ty], [$x, $y]); poly($leftLit ? 'c4' : 'c3', @R, [$tx, $ty], [$x, $y]);
  for my $k (1 .. 4) {                                      # buds alternate up the rod, with a faint node ring
    my $t = $k * 0.21; my $side = $k % 2 ? 1 : -1;
    my ($bx, $by) = ($x + $dx * $len * $t + $nx * $h * $side, $y + $dy * $len * $t + $ny * $h * $side);
    blade($bx, $by, $a + $side * 40, 16, 9, -$side * 8, 'c5', 'c4');
  }
  poly('c1', ell($tx, $ty, $h + 1, 3.6, 12, $a + 90)); poly('c3', ell($tx - $dx * 0.5, $ty - $dy * 0.5, $h * 0.6, 2, 12, $a + 90));
}
write_svg('1-seeds-front.svg', 'Raspberry cane cuttings');

# 2. Just planted, top down: cut cane stubs in soil pockets, buds breaking.
my @sown = ([176, 172], [236, 186], [192, 236]);
for (@sown) { soil($_->[0], $_->[1], 34, 28, int($_->[0] * 7 + $_->[1])); }
for (@sown) {
  my ($x, $y) = @$_;
  my @p = cane($x, $y, -58 + ($x - 200) * 0.8, 30, 15, 0, "c3", "c4");
  for my $b ([4, 1], [7, -1]) { my ($bx, $by, $ba) = @{$p[$b->[0]]}; my ($u, $v) = dir($ba); my $hw = 7.5 * (1 - $b->[0] / 10) ** 0.85 + 0.6;
    blade($bx - $v * $hw * $b->[1], $by + $u * $hw * $b->[1], $ba + $b->[1] * 50, 12, 7, 0, "c5", "c4"); }
  my ($tx, $ty, $ta) = @{$p[10]};
  poly("c1", ell($tx, $ty, 8, 6, 10, $ta)); poly("c3", ell($tx, $ty, 5, 3.6, 10, $ta));
}
write_svg('2-sown.svg', 'Raspberries just planted');

# 3. First growth: young shoots with first three-leaflet leaves around the old stub.
soil(200, 200, 34, 30, 3);
for my $a (-100, 25, 140) { my @p = cane(200, 200, $a, 30, 5, 12, 'c2', 'c1'); my ($x, $y, $h) = @{$p[10]}; rleaf($x, $y, $h, 4, 44, 'c2', 'c1', five => 0, veins => 4); }
stub(200, 200, 9);
write_svg('3-first-growth.svg', 'Raspberry first growth');

# 4. Second growth: young canes with pinnate leaves.
soil(200, 200, 34, 30, 4);
bush(5, 48, 12, 38, 41, start => -80, at => [0.55]);
stub(200, 200, 8);
write_svg('4-second-growth.svg', 'Raspberry second growth');

# 5. Third growth: leafy canes with small white flowers and green unripe berries.
soil(200, 200, 34, 30, 5);
my @c5 = bush(7, 80, 14, 42, 51, start => -86, at => [0.4, 0.7], prick => 'c4');
for my $i (0 .. $#c5) {
  my ($x, $y, $a) = @{$c5[$i][$i % 2 ? 6 : 8]}; my ($dx, $dy) = dir($a + 90);
  if ($i % 2) { rflower($x + $dx * 12, $y + $dy * 12, 14, $i * 20); rflower($x - $dx * 10, $y - $dy * 10, 12, $i * 33); }
  else { sepals($x + $dx * 10, $y + $dy * 10, 15, $i * 17, 'c2', 'c1'); rasp($x + $dx * 10, $y + $dy * 10, 10, 10, body => 'c2', shade => 'c1');
         rflower($x - $dx * 12, $y - $dy * 12, 12, $i * 40); }
}
write_svg('5-third-growth.svg', 'Raspberry third growth, flowering');

# 6. Harvest: a full bush loaded with clusters of ripe raspberries.
soil(200, 200, 34, 30, 6);
my @c6 = bush(8, 96, 16, 46, 61, start => -78, at => [0.38, 0.66], prick => 'c4');
srand(67);
for my $i (0 .. $#c6) {
  for my $f ([6, 1], [9, -1]) {
    my ($x, $y, $a) = @{$c6[$i][$f->[0]]}; my ($dx, $dy) = dir($a + 90 * $f->[1]);
    my @b = ([$x + $dx * 15, $y + $dy * 15, 16], [$x + $dx * 26 + $dy * 18, $y + $dy * 26 - $dx * 18, 14]);
    @b = ($b[0]) if $f->[0] == 6 && $i % 2;
    for (@b) { sepals($_->[0], $_->[1], $_->[2] * 1.4, rand(72), 'c2', 'c1'); }
    for (@b) { rasp(@$_[0, 1], $_->[2], $_->[2]); }
  }
}
write_svg('6-harvest.svg', 'Raspberries ready to harvest');

# 7. Harvested produce, front view (inventory item): three picked raspberries (blunt thimbles, no sepals - those stay
# on the plant) in front of a raspberry leaf.
# A picked raspberry: a blunt thimble packed with round glossy drupelets; dark crevices show between them.
sub rberry {
  my ($x, $y, $rx, $ry, $rot) = @_;
  my ($ax, $ay) = dir($rot); my ($bx, $by) = (-$ay, $ax);             # a = toward tip, b = across
  my $W = sub { my $t = shift; $rx * (max(0, 1 - $t * $t)) ** 0.42 * (1 - 0.1 * $t) };   # t = 1 tip .. -1 base
  my $P = sub { my ($t, $s) = @_; [$x + $ax * $t * $ry + $bx * $s, $y + $ay * $t * $ry + $by * $s] };
  my @out; for my $i (0 .. 35) { my $th = 2 * pi * $i / 36; my $t = cos($th); push @out, $P->($t * 0.96, sin($th) * $W->($t) * 0.96); }
  poly('c4', map { [$_->[0] + 3, $_->[1] + 3] } @out);              # crevice shade, offset to the lower right
  my $s = $rx * 0.34; my @d; my $row = 0;
  for (my $gt = -$ry * 0.84; $gt <= $ry * 0.86; $gt += $s * 0.8) {
    my $t = $gt / $ry; my $w = $W->($t) * 0.86; $row++;
    for (my $sv = -int($w / $s + 1) * $s + ($row % 2) * $s / 2; $sv <= $w + 0.01; $sv += $s) {
      next if abs($sv) > $w + $s * 0.15; my $e = abs($sv) / max($W->($t), 1);
      push @d, [@{$P->($t, $sv)}, sqrt(max(0, 1 - $e * $e)) * sqrt(max(0.1, 1 - $t * $t * 0.7))];
    }
  }
  for (sort { $a->[2] <=> $b->[2] } @d) {
    my ($px, $py, $z) = @$_;
    my $rd = $s * 0.64 * (0.76 + 0.24 * $z);
    my $l = (($px - $x) * -0.7071 + ($py - $y) * -0.7071) / $rx;     # toward the light
    $rd *= 0.9 if $l < -0.35;
    poly('c5', ell($px, $py, $rd, $rd, 9, 8));
    next if $l < -0.3;
    my ($hx, $hy) = ($px - $rd * 0.36, $py - $rd * 0.36); my $h = $rd * ($l > 0.25 ? 0.4 : 0.28);
    poly('c3', [$hx - $h, $hy + $h * 0.25], [$hx + $h * 0.25, $hy - $h], [$hx + $h * 0.3, $hy + $h * 0.3]);
  }
}
rleaf(132, 318, -62, 8, 150, 'c2', 'c1', curl => 12, wk => 0.62, deep => 0.86, veins => 5, five => 0);
rberry(142, 202, 46, 52, -104);
rberry(262, 196, 46, 52, -74);
rberry(202, 262, 50, 56, -90);
write_svg('7-harvest-front.svg', 'Raspberry harvest');

# 8. Dead (never watered): cracked dry soil, brittle brown canes, curled dry leaves, shrivelled berries.
soil(200, 200, 56, 48, 8);
srand(83);
for my $i (0 .. 6) {
  my $a = $i * 360 / 7 + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
  for my $k (0 .. 4) {
    my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.2 - $k * 0.35;
    push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
    $x += $dx * 13; $y += $dy * 13;
  }
  poly('c3', @l, [$x, $y], reverse @r);
}
my @c8 = bush(6, 66, 26, 34, 81, start => -70, at => [0.5], light => 'c3', dark => 'c4', curl => 40, wk => 0.42, deep => 0.8, veins => 0, cw => 6);
for my $i (0, 2, 4) { my ($x, $y, $a) = @{$c8[$i][7]}; my ($dx, $dy) = dir($a + 90); rasp($x + $dx * 10, $y + $dy * 10, 7, 6, body => 'c4', shade => 'c4', hi => 'c3'); }
write_svg('8-dead.svg', 'Raspberry plant died from lack of water');
print "wrote 8 files to $OUT\n";

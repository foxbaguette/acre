# Strawberry crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/strawberries.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/strawberries';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#3C8A3E', c2 => '#9ACB4E', c3 => '#FFF3D2', c4 => '#5A3024', c5 => '#E2343F');
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

# Strawberry leaf: petiole with three broad toothed leaflets meeting at one point.
sub trifol {
  my ($x, $y, $ang, $plen, $llen, $light, $dark, %o) = @_;
  my $bend = $o{bend} // 0; my $curl = $o{curl} // 0; my $wk = $o{wk} // 0.76;
  blade($x, $y, $ang, $plen, $o{pw} // 6, $bend, $light, $dark);
  my ($ex, $ey, $ea) = reach($x, $y, $ang, $plen, $bend);
  my %lo = (veins => $o{veins} // 4, n => $o{n} // 14, deep => $o{deep} // 0.86, q => $o{q} // 0.55);
  my $sp = $o{spread} // 50;
  leaflet($ex, $ey, $ea - $sp, $llen * 0.88, $llen * 0.88 * $wk, -$curl, $light, $dark, %lo);
  leaflet($ex, $ey, $ea + $sp, $llen * 0.88, $llen * 0.88 * $wk, $curl, $light, $dark, %lo);
  leaflet($ex, $ey, $ea, $llen, $llen * $wk, $curl * 0.5, $light, $dark, %lo);
}

# A strawberry lying or hanging: cone from the calyx (x,y) towards `ang`, gloss, shade, seeds, sepal star.
sub berry {
  my ($x, $y, $ang, $L, $W, %o) = @_;
  my $body = $o{body} // 'c5'; my $shade = $o{shade} // 'c4'; my $seed = $o{seed} // 'c3';
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my (@l, @r); my $N = 16;
  my $f = sub { my $t = shift; ((1 - $t ** 1.45) ** 0.72) * (1 - (1 - min($t / 0.3, 1)) ** 2.4) * 1.04 + ($t > 0.95 ? 0.05 : 0) };
  for my $i (0 .. $N) {
    my $t = $i / $N; my $hw = $W / 2 * $f->($t);
    my ($cx, $cy) = ($x + $dx * $L * $t, $y + $dy * $L * $t);
    push @l, [$cx + $nx * $hw, $cy + $ny * $hw]; push @r, [$cx - $nx * $hw, $cy - $ny * $hw];
  }
  my $tip = [$x + $dx * ($L + 2), $y + $dy * ($L + 2)];
  poly($body, @l, $tip, reverse @r);
  my $leftLit = lit($nx, $ny);
  my @dk = $leftLit ? @r : @l; my @lt = $leftLit ? @l : @r; my $s = $leftLit ? -1 : 1;
  # shaded crescent on the side away from the light
  my @inner = map { my $t = $_ / $N; my $hw = $W / 2 * $f->($t) * 0.62;
    [$x + $dx * $L * $t + $nx * $s * $hw, $y + $dy * $L * $t + $ny * $s * $hw] } 0 .. $N;
  poly($shade, @dk[2 .. $N], $tip, reverse @inner[3 .. $N]) unless $o{noshade};
  # gloss facet on the lit shoulder
  unless ($o{nogloss}) {
    my @g = map { my ($t, $k) = @$_; my $hw = $W / 2 * $f->($t) * $k;
      [$x + $dx * $L * $t - $nx * $s * $hw, $y + $dy * $L * $t - $ny * $s * $hw] } ([0.2, 0.5], [0.26, 0.8], [0.46, 0.68], [0.42, 0.48]);
    poly($o{gloss} // 'c3', @g);
  }
  # seeds: small teardrops in staggered rows
  unless ($o{noseeds}) {
    my $sz = $o{sz} // $W * 0.04;
    for my $row (1 .. 5) {
      my $t = 0.16 + $row * 0.14;
      my @cols = $row % 2 ? (-0.62, 0, 0.62) : (-0.32, 0.32);
      @cols = (-0.4, 0.4) if $row == 5; @cols = (0) if $t > 0.85;
      for my $c (@cols) {
        my $hw = $W / 2 * $f->($t) * $c;
        my ($cx, $cy) = ($x + $dx * $L * $t + $nx * $hw, $y + $dy * $L * $t + $ny * $hw);
        my $inShade = ($c * $s) > 0.45;
        my $cls = $inShade && !$o{seedflat} ? $body : $seed;
        $cls = $seed if $o{seedflat};
        poly($cls, [$cx - $dx * $sz * 1.3, $cy - $dy * $sz * 1.3], [$cx + $nx * $sz, $cy + $ny * $sz],
             [$cx + $dx * $sz, $cy + $dy * $sz], [$cx - $nx * $sz, $cy - $ny * $sz]);
      }
    }
  }
  # calyx: a star of green sepals over the shoulder
  return if $o{nocalyx};
  my $cl = $o{clight} // 'c2'; my $cd = $o{cdark} // 'c1'; my $cs = $o{cs} // 1;
  for my $k (0 .. 6) {
    my $sa = $ang + 180 + $k * 360 / 7 + 10;
    blade($x + $dx * 3, $y + $dy * 3, $sa, $W * 0.42 * $cs * ($k % 2 ? 0.85 : 1), $W * 0.17 * $cs, ($k % 2 ? 14 : -14), $cl, $cd);
  }
  poly($cd, map { my ($a, $b) = dir($_ * 60); [$x + $dx * 3 + $a * $W * 0.09, $y + $dy * 3 + $b * $W * 0.09] } 0 .. 5);
}

# White five-petal flower with a yellow-green centre and green sepal tips between the petals.
sub flower {
  my ($x, $y, $r, $rot) = @_; $rot //= 0;
  for my $k (0 .. 4) {                                  # sepal tips peeking between petals
    my $a = $rot + 36 + $k * 72; my ($dx, $dy) = dir($a);
    my ($nx, $ny) = (-$dy, $dx);
    poly(lit($dx, $dy) ? 'c2' : 'c1', [$x + $nx * $r * 0.2, $y + $ny * $r * 0.2], [$x + $dx * $r * 1.25, $y + $dy * $r * 1.25], [$x - $nx * $r * 0.2, $y - $ny * $r * 0.2]);
  }
  for my $k (0 .. 4) {
    my $a = $rot + $k * 72; my ($dx, $dy) = dir($a);
    my ($cx, $cy) = ($x + $dx * $r * 0.55, $y + $dy * $r * 0.55);
    my @p = map { my ($u, $v) = dir($a + $_ * 45); [$cx + $u * $r * 0.52, $cy + $v * $r * 0.52] } 0 .. 7;
    poly('c3', @p);
  }
  my @c = map { my ($u, $v) = dir($_ * 45 + 22); [$x + $u * $r * 0.36, $y + $v * $r * 0.36] } 0 .. 7;
  poly('c2', @c);
  poly('c1', @c[0 .. 4]);                              # lower-right half of the centre in shade
  for my $k (0 .. 9) { my ($u, $v) = dir($k * 36 + 10); my ($sx, $sy) = ($x + $u * $r * 0.42, $y + $v * $r * 0.42);
    poly('c2', [$sx - 1.6, $sy], [$sx, $sy - 1.6], [$sx + 1.6, $sy], [$sx, $sy + 1.6]); }
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

# A rosette of trifoliate leaves around (cx,cy).
sub rosette {
  my ($n, $plen, $pvar, $llen, $seed, $start, %o) = @_;
  srand($seed); my @lv;
  for my $i (0 .. $n - 1) {
    my $a = ($start // -90) + $i * 360 / $n + rand(16) - 8;
    push @lv, [$a, $plen + rand($pvar), (rand(1) < 0.5 ? -1 : 1) * (6 + rand(10))];
  }
  for (sort { $b->[1] <=> $a->[1] } @lv) {
    trifol($o{cx} // 200, $o{cy} // 200, $_->[0], $_->[1], $llen * (0.9 + 0.1 * $_->[1] / ($plen + $pvar)), $o{light} // 'c2', $o{dark} // 'c1',
           bend => $_->[2], curl => ($o{curl} // 0) * ($_->[2] > 0 ? 1 : -1), %o);
  }
}

# 1. Planting material, front view: a mother plantlet with a red runner and a rooted baby plantlet.
sub plantlet {
  my ($x, $y, $k) = @_;
  for my $r ([100, 40, 12], [80, 52, -8], [120, 46, 10], [92, 34, 20], [108, 30, -24]) {   # roots
    blade($x + ($r->[0] - 100) * 0.12 * $k, $y + 4 * $k, $r->[0], $r->[1] * $k, 4 * $k, $r->[2], 'c3', 'c4');
  }
  trifol($x, $y, -130, 44 * $k, 40 * $k, 'c2', 'c1', bend => 18, pw => 6 * $k, veins => 3);
  trifol($x, $y, -50, 44 * $k, 40 * $k, 'c2', 'c1', bend => -18, pw => 6 * $k, veins => 3);
  trifol($x, $y, -92, 58 * $k, 46 * $k, 'c2', 'c1', bend => 6, pw => 6 * $k, veins => 3);
  my @cr = map { my ($u, $v) = dir($_ * 45); [$x + $u * 11 * $k, $y + 2 * $k + $v * 8 * $k] } 0 .. 7;
  poly('c4', @cr); poly('c1', @cr[4 .. 7], [$x + 11 * $k, $y + 2 * $k]);    # brown crown, green lit top
}
{
  # runner arching from the mother crown to the baby
  my ($x, $y, $a) = (148, 262, -52);
  my @p;
  for (0 .. 14) { push @p, [$x, $y]; my ($dx, $dy) = dir($a); $x += $dx * 13; $y += $dy * 13; $a += 104 / 14; }
  my (@u, @d);
  for my $i (0 .. $#p) { push @u, [$p[$i][0], $p[$i][1] - 2.6]; push @d, [$p[$i][0], $p[$i][1] + 2.6]; }
  poly('c5', @u, reverse @d); poly('c4', @d[0 .. $#d], reverse map { [$_->[0], $_->[1] - 0.6] } @d);
  plantlet(150, 268, 1.25);
  plantlet($x - 6, $y + 4, 0.8);
}
write_svg('1-seeds-front.svg', 'Strawberry runner plantlets');

# 2. Just planted, top down: tiny crowns pressed into soil pockets.
my @sown = ([164, 170, -30], [240, 166, 40], [202, 214, 95], [152, 242, 150], [250, 240, -60]);
for (@sown) { soil($_->[0], $_->[1], 28, 23, int($_->[0] * 7 + $_->[1])); }
for (@sown) {
  my ($x, $y, $a) = @$_;
  for my $k (0 .. 2) { trifol($x, $y, $a + $k * 120, 4, 13, 'c2', 'c1', veins => 0, n => 8, pw => 3); }
  poly('c5', map { my ($u, $v) = dir($_ * 60); [$x + $u * 4, $y + $v * 4] } 0 .. 5);
}
write_svg('2-sown.svg', 'Strawberries just planted');

# 3. First growth: a few small trifoliate leaves.
soil(200, 200, 34, 30, 3);
rosette(4, 24, 8, 40, 31, -80, veins => 3);
write_svg('3-first-growth.svg', 'Strawberry first growth');

# 4. Second growth: a dense leafy rosette.
soil(200, 200, 34, 30, 4);
rosette(8, 42, 14, 56, 41, -70, veins => 4);
write_svg('4-second-growth.svg', 'Strawberry second growth');

# 5. Third growth: full rosette with white flowers and small green berries.
soil(200, 200, 34, 30, 5);
rosette(9, 42, 18, 62, 51, -80, veins => 3);
for my $f ([-40, 116, 0], [70, 122, 20], [160, 112, 50], [235, 120, 10], [-125, 104, 30]) {
  my ($dx, $dy) = dir($f->[0]); my ($fx, $fy) = (200 + $dx * $f->[1], 200 + $dy * $f->[1]);
  blade(200 + $dx * 50, 200 + $dy * 50, $f->[0], $f->[1] - 54, 4, 0, 'c2', 'c1');
  flower($fx, $fy, 23, $f->[2]);
}
for my $b ([18, 112], [198, 114], [112, 118]) { my ($dx, $dy) = dir($b->[0]);
  blade(200 + $dx * 50, 200 + $dy * 50, $b->[0], $b->[1] - 50, 4, 0, 'c2', 'c1');
  berry(200 + $dx * $b->[1], 200 + $dy * $b->[1], $b->[0], 28, 25, body => 'c2', shade => 'c1', seed => 'c3', clight => 'c2', cdark => 'c1', sz => 1.3, nogloss => 1); }
write_svg('5-third-growth.svg', 'Strawberry third growth, flowering');

# 6. Harvest: lush rosette with big ripe berries lying all around it.
soil(200, 200, 34, 30, 6);
rosette(9, 40, 16, 66, 61, -72, veins => 3);
srand(66);
for my $i (0 .. 7) {
  my $a = -100 + $i * 45 + rand(14) - 7; my $d = 112 + ($i % 2 ? 0 : 12);
  my ($dx, $dy) = dir($a);
  blade(200 + $dx * 60, 200 + $dy * 60, $a, $d - 60, 4.5, 0, 'c2', 'c1');
  berry(200 + $dx * $d, 200 + $dy * $d, $a + rand(20) - 10, 58, 52);
}
flower(200 + 26, 200 - 58, 18, 12); flower(200 - 62, 200 + 34, 16, 40);
write_svg('6-harvest.svg', 'Strawberries ready to harvest');

# 7. Harvested produce, front view (inventory item): three glossy strawberries, one with a short stem.
berry(132, 190, 114, 126, 110);
berry(270, 186, 66, 126, 110);
berry(202, 132, 90, 152, 130);
blade(202, 136, -78, 62, 10, -26, "c2", "c1");                # short stem on the front berry
write_svg('7-harvest-front.svg', 'Strawberry harvest');

# 8. Dead (never watered): cracked dry soil, withered limp leaves lying flat, shrivelled berries.
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
rosette(7, 52, 22, 56, 81, -60, light => 'c3', dark => 'c4', curl => 34, wk => 0.72, deep => 0.84, n => 10, veins => 0, spread => 50, pw => 5);
for my $b ([28, 112], [160, 104], [262, 96]) { my ($dx, $dy) = dir($b->[0]);
  berry(200 + $dx * $b->[1], 200 + $dy * $b->[1], $b->[0] + 24, 26, 17, body => 'c4', shade => 'c4', seed => 'c3', clight => 'c3', cdark => 'c4', sz => 1, nogloss => 1, seedflat => 1, cs => 0.8); }
write_svg('8-dead.svg', 'Strawberry plant died from lack of water');
print "wrote 8 files to $OUT\n";

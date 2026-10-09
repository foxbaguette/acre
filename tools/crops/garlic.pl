# Garlic crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/garlic.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Garlic grows flat strap leaves in two ranks, so from above the plant is a FAN (not a radial star like
# the spring onions); it is planted from cloves and harvested as papery bulbs with purple streaks.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/garlic';
mkdir 'crops'; mkdir $OUT;
# c1 shaded leaf green, c2 lit leaf green, c3 papery ivory (bulb skin, cloves, dry leaves),
# c4 soil brown / deep shade, c5 mauve purple (bulb streaks, shaded skin)
my %PAL = (c1 => '#4E7A3C', c2 => '#97BE62', c3 => '#F3E5C3', c4 => '#5A3A22', c5 => '#9A5A8C');
my @S;
our $SEGLIT = 0;   # 1: shade each stretch of a curled leaf by its own direction

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Path with left/right outlines; profile gives the half-width factor for t in 0..1.
sub path {
  my ($x, $y, $ang, $len, $w, $bend, $prof, $n) = @_; $n //= 14;
  my (@mid, @l, @r); my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * $prof->($t) + ($i == $n ? 0 : 0.5);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    last if $i == $n;
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  return (\@mid, \@l, \@r, $a - $bend / $n);
}
# Draw a path's two halves (lit / shaded), optionally only the index range i0..i1.
sub halves {
  my ($mid, $l, $r, $light, $dark, $i0, $i1) = @_;
  $i0 //= 0; $i1 //= $#$mid;
  # decide the lit half per segment so a strongly curled leaf flips its shading where it turns
  my $s = $i0;
  while ($s < $i1) {
    my $e = $s; my $ll;
    while ($e < $i1) {
      my ($dx, $dy) = ($mid->[$e + 1][0] - $mid->[$e][0], $mid->[$e + 1][1] - $mid->[$e][1]);
      my $cur = lit(-$dy, $dx);       # left normal of the direction of travel
      if (!$main::SEGLIT) { my ($cx, $cy) = ($mid->[$i1][0] - $mid->[$i0][0], $mid->[$i1][1] - $mid->[$i0][1]); $cur = lit(-$cy, $cx); }
      $ll //= $cur; last if $cur != $ll; $e++;
    }
    $e = $s + 1 if $e == $s;
    my @L = @$l[$s .. $e]; my @R = @$r[$s .. $e]; my @M = @$mid[$s .. $e];
    poly($ll ? $light : $dark, @L, reverse @M);
    poly($ll ? $dark : $light, @R, reverse @M);
    $s = $e;
  }
}
sub blade { my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $tip) = @_; $tip //= 0;
  my ($m, $l, $r, $ea) = path($x, $y, $ang, $len, $w, $bend, sub { 1 - (1 - $tip) * $_[0] }, 10);
  halves($m, $l, $r, $light, $dark); return (@{$m->[-1]}, $ea);
}

# Flat garlic strap leaf: even width, keeled (lit / shaded halves along the fold), a pointed tip.
# $dry: fraction of the leaf (from the tip) dried to straw, as on a ripe plant.
sub strap {
  my ($x, $y, $ang, $len, $w, $bend, $dry, $light, $dark, $nb) = @_;
  $light //= "c2"; $dark //= "c1"; $dry //= 0; $nb //= 0;
  my $n = 18;
  # $nb: length fraction of the narrow upright base (seen end-on from above), so the bulb shows round it
  my ($m, $l, $r) = path($x, $y, $ang, $len, $w, $bend, sub { my $t = shift; (1 - $t ** 3) ** 0.55 * (0.82 + 0.18 * min(1, $t * 6)) * ($nb && $t < $nb ? 0.3 + 0.7 * ($t / $nb) ** 2 : 1) }, $n);
  my $k = int($n * (1 - $dry) + 0.5);
  halves($m, $l, $r, $light, $dark, 0, max(1, $k));
  halves($m, $l, $r, "c3", $light eq "c3" ? "c4" : "c1", $k, $n) if $dry > 0 && $k < $n;
}

# A single garlic clove from the front, pointed tip up: plump crescent, ivory lit side, mauve shaded side.
sub clove {
  my ($x, $y, $ang, $h, $w, $curve) = @_; $curve //= 0;
  my ($m, $l, $r) = path($x, $y, $ang, $h, $w, $curve, sub { my $t = shift; $t < 0.02 ? 0.55 : sin(pi * (0.18 + 0.82 * $t) ** 1.25) ** 0.65 * (1 - 0.2 * $t) }, 14);
  poly('c3', @$l, reverse @$r);
  my ($dx, $dy) = dir($ang + $curve / 2); my $leftLit = lit(-$dy, $dx);
  my $sh = $leftLit ? $r : $l;
  poly('c5', @$sh, reverse map { [$m->[$_][0] + ($sh->[$_][0] - $m->[$_][0]) * 0.35, $m->[$_][1] + ($sh->[$_][1] - $m->[$_][1]) * 0.35] } 0 .. $#$m);
  # flat base (the root end) slightly darker
  my $b = $sh->[0];
  poly('c4', $l->[0], $r->[0], [($l->[1][0] + $r->[1][0]) / 2, ($l->[1][1] + $r->[1][1]) / 2]);
  # a dry papery tip
  my $i = $#$m - 2; poly('c4', $l->[$i], $m->[-1], $r->[$i], [($m->[$i][0] * 3 + $m->[-1][0]) / 4, ($m->[$i][1] * 3 + $m->[-1][1]) / 4]) if $_[6];
}

# A whole garlic bulb from the front: wide round base, clove ribs meeting at a pointed neck,
# mauve streaks along the ribs, a shaded right side, a dry cut stem and a root tuft.
sub bulb {
  my ($x, $y, $r, $tilt) = @_; $tilt //= 0;
  my $ta = deg2rad($tilt);
  my $R = sub { my ($u, $v) = @_; [$x + $u * cos($ta) - $v * sin($ta), $y + $u * sin($ta) + $v * cos($ta)] };
  # outline: u = half-width at height v (v from -1.25r at the neck to +0.8r at the base)
  my $hw = sub { my $v = shift; my $s = min(1, max(0, ($v / $r + 1.25) / 2.05));     # 0 at the neck tip, 1 at the base
    return $r * ($s < 0.5 ? 0.07 + 0.93 * (sin(pi / 2 * $s / 0.5)) ** 1.6 : sqrt(max(0, 1 - (($s - 0.5) / 0.5) ** 3.6))) * 1.05 };
  my $nv = 22; my @vs = map { -1.25 * $r + 2.05 * $r * $_ / $nv } 0 .. $nv;
  # roots first, behind the base
  for my $k (-4 .. 4) {
    my ($bx, $by) = @{$R->($k * $r * 0.09, 0.74 * $r)};
    blade($bx, $by, 90 + $tilt + $k * 13, $r * (0.3 + 0.06 * (4 - abs($k))), 3.6, ($k % 2 ? 22 : -18), 'c3', 'c4');
  }
  # ribs: 5 vertical segments at fractions of the half-width; each segment between two rib lines
  my @f = (-1, -0.62, -0.2, 0.22, 0.62, 1);
  for my $j (0 .. 4) {
    my ($a, $b) = ($f[$j], $f[$j + 1]);
    my @L = map { [$a * $hw->($_), $_] } @vs; my @Rr = map { [$b * $hw->($_), $_] } @vs;
    # bulge each rib a little outward (pillowy cloves)
    my $c = ($a + $b) / 2;
    my $cls = $c > 0.5 ? 'c5' : 'c3';
    poly($cls, map({ $R->(@$_) } @L), reverse map { $R->(@$_) } @Rr);
  }
  # shade crescent on the right side, and a soft mauve streak on each lit rib seam
  poly('c5', map({ $R->($hw->($_) * 0.5, $_) } @vs), reverse map { $R->($hw->($_), $_) } @vs);
  for my $sf ([-0.62, 0.05], [-0.2, 0.06], [0.22, 0.05]) {
    my ($s, $sw) = @$sf;
    my @A = map { [($s - $sw * (1 - abs($_ / $r) * 0.3)) * $hw->($_), $_] } @vs[6 .. 19];
    my @B = map { [($s + $sw * 0.4) * $hw->($_), $_] } @vs[6 .. 19];
    poly('c5', map({ $R->(@$_) } @A), reverse map { $R->(@$_) } @B);
  }
  # a lit gloss facet on the upper left
  poly('c3', map { $R->(@$_) } [-0.85 * $hw->(-0.2 * $r), -0.2 * $r], [-0.62 * $hw->(-0.6 * $r), -0.6 * $r], [-0.45 * $hw->(-0.3 * $r), -0.3 * $r]);
  # root plate
  poly('c4', map { $R->(@$_) } [-0.42 * $r, 0.66 * $r], [0.42 * $r, 0.66 * $r], [0.3 * $r, 0.8 * $r], [-0.3 * $r, 0.8 * $r]);
  # dry cut stem at the neck
  my ($nx, $ny) = @{$R->(0, -1.18 * $r)};
  blade($nx, $ny, -90 + $tilt + 4, $r * 0.42, $r * 0.2, 6, 'c3', 'c4', 0.75);
}

# Bulb seen from above at harvest: a round papery dome pushed up out of the soil, clove segments
# radiating from the neck, mauve streaks, shaded lower-right side.
sub bulb_top {
  my ($x, $y, $r, $dead) = @_;
  my $sc = $dead ? "c4" : "c5";
  my $n = 7; my $m = 8 * $n; my @o;
  for my $i (0 .. $m - 1) { my $th = 2 * pi * $i / $m; my $k = ($dead ? 0.88 + 0.12 * sin($i * 2.3) : 1) - 0.06 * abs(cos($n * $th / 2)) ** 3; push @o, [$x + cos($th) * $r * $k, $y + sin($th) * $r * $k]; }
  poly('c3', @o);
  my $in = sub { my ($p, $k) = @_; [$x + ($p->[0] - $x) * $k, $y + ($p->[1] - $y) * $k] };
  for my $j (0 .. $n - 1) {
    my @arc = map { $o[$_ % $m] } $j * 8 .. $j * 8 + 8;
    my $ca = 2 * pi * ($j + 0.5) / $n; my $b = -(cos($ca) + sin($ca)) * 0.7071;   # >0 faces the light
    if ($b < -0.2) {   # shaded clove: mauve on its outer part
      my $k = $b < -0.7 ? 0.62 : 0.8;
      poly($sc, @arc, reverse map { $in->($_, $k) } @arc);
    }
    # seam streak along the clove boundary
    my $th = 2 * pi * $j / $n; my ($c, $s) = (cos($th), sin($th)); my ($nx, $ny) = (-$s, $c); my $w = $r * 0.035;
    poly($sc, [$x + $c * $r * 0.28 + $nx * $w, $y + $s * $r * 0.28 + $ny * $w], [$x + $c * $r * 0.9, $y + $s * $r * 0.9],
               [$x + $c * $r * 0.28 - $nx * $w, $y + $s * $r * 0.28 - $ny * $w]);
  }
  poly('c4', map { my $th = 2 * pi * $_ / 8; [$x + cos($th) * $r * 0.24 + 2, $y + sin($th) * $r * 0.24 + 2] } 0 .. 7);   # neck
}

# The round green neck (pseudostem) the leaves wrap around, seen from above.
sub neck { my ($x, $y, $r) = @_; my @o = map { my $th = 2 * pi * $_ / 10; [$x + cos($th) * $r, $y + sin($th) * $r] } 0 .. 9;
  poly("c1", @o); poly("c2", [$x, $y], @o[4 .. 9], $o[0]); }

# Garlic scape: a stalk curling into a loop, ending in a long-beaked pale bud.
sub scape {
  my ($x, $y, $ang, $len, $curl) = @_;
  local $SEGLIT = 1;
  my ($sx, $sy, $sa) = blade($x, $y, $ang, $len * 0.38, 11, 6, "c2", "c1", 0.9);
  my ($ex, $ey, $ea) = blade($sx, $sy, $sa, $len * 0.62, 10, $curl, "c2", "c1", 0.8);
  my ($m, $l, $r) = path($ex, $ey, $ea, 58, 20, 0, sub { my $t = shift; $t < 0.55 ? sin(pi / 2 * ($t / 0.55) ** 0.6 + 0.2) : (1 - ($t - 0.55) / 0.45) ** 1.6 * 0.95 + 0.05 }, 12);
  halves($m, $l, $r, 'c3', 'c2');
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

# A garlic fan from above: leaves alternate between two opposite directions along axis `ax`,
# each fanning a little wider and arching over; the oldest (longest, outermost) drawn first.
sub fan {
  my ($nl, $len, $w, $ax, $spread, $arch, $seed, $dry, $nb) = @_;
  srand($seed); my @L;
  for my $i (0 .. $nl - 1) {
    my $side = $i % 2; my $k = int($i / 2); my $m = int(($nl - $side + 1) / 2);   # k-th leaf of m on this side
    my $u = $m > 1 ? -1 + 2 * $k / ($m - 1) : 0;                                    # -1 .. 1 across the fan
    my $age = abs($u);                                                               # outer leaves are older
    my $a = $ax + ($side ? 180 : 0) + $u * $spread + rand(8) - 4;
    my $l = $len * (0.8 + 0.2 * $age) + rand(12) - 6;
    push @L, [$a, $l, ($u >= 0 ? 1 : -1) * $arch * (0.4 + 0.6 * $age) + rand(8) - 4, $age];
  }
  for (sort { $b->[1] <=> $a->[1] } @L) {
    my ($a, $l, $b, $age) = @$_; my ($dx, $dy) = dir($a);
    strap(200 + $dx * 4, 200 + $dy * 4, $a, $l, $w * (0.85 + 0.15 * $age), $b, $dry ? $dry * (0.35 + 0.65 * $age) : 0, undef, undef, $nb);
  }
}

# ---------------------------------------------------------------------------------------------
# 1. Planting material, front view: three plump garlic cloves, pointed tips up.
clove(150, 300, -100, 118, 64, 12);
clove(250, 300, -80, 118, 64, -12);
clove(200, 316, -90, 140, 74, 0);
write_svg('1-seeds-front.svg', 'Garlic cloves for planting');

# 2. Just sown, top down: cloves pushed into soil pockets, tips showing.
my @sown = ([166, 166, -60], [238, 164, -110], [168, 240, -70], [236, 238, -100]);
for (@sown) { soil($_->[0], $_->[1], 30, 26, int($_->[0] * 7 + $_->[1])); }
for (@sown) { clove($_->[0] - 3, $_->[1] + 12, $_->[2], 34, 21, 0); }
write_svg('2-sown.svg', 'Garlic just planted');

# 3. First growth, top down: the first flat leaves, already opening into a fan.
soil(200, 200, 34, 30, 3);
clove(204, 214, -96, 22, 16, 0);
strap(200, 200, -150, 96, 21, 22); strap(200, 200, 30, 84, 20, 18); strap(200, 200, -40, 58, 17, -10);
write_svg('3-first-growth.svg', 'Garlic first growth');

# 4. Second growth, top down: a flat two-ranked fan of strap leaves.
soil(200, 200, 34, 30, 4);
fan(8, 118, 30, -28, 30, 40, 41);
write_svg('4-second-growth.svg', 'Garlic second growth');

# 5. Third growth, top down: a tall full fan with the curling flower scape.
soil(200, 200, 34, 30, 5);
fan(10, 148, 32, -28, 36, 46, 51);
scape(200, 200, -50, 260, 330);
write_svg('5-third-growth.svg', 'Garlic third growth');

# 6. Harvest, top down: leaf tips drying to straw, the papery white bulb pushed up out of the soil.
soil(200, 200, 88, 80, 6);
bulb_top(200, 200, 68);
fan(8, 170, 32, -28, 34, 40, 61, 0.32, 0.4);
neck(200, 200, 15);
write_svg('6-harvest.svg', 'Garlic ready to harvest');

# 7. Harvested produce, front view: two papery garlic bulbs and a loose clove.
bulb(150, 222, 74, -8);
bulb(262, 238, 66, 10);
clove(214, 318, -20, 64, 38, 8);
write_svg('7-harvest-front.svg', 'Harvested garlic');

# 8. Dead (never watered), top down: cracked dry soil, a shrivelled little bulb and dry, flat straps
#    lying collapsed on the ground, broken over (kinked) instead of arching.
soil(200, 200, 62, 54, 8);
cracks(8, 83, 11, 'c3');
bulb_top(200, 200, 24, 1);
srand(81); $SEGLIT = 1;
for my $i (0 .. 6) {
  my $a = -28 + ($i % 2 ? 180 : 0) + ($i - 3) * 9 + rand(20) - 10; my ($dx, $dy) = dir($a);
  my $l1 = 70 + rand(34); my $b1 = rand(30) - 15;
  my ($m) = path(200 + $dx * 8, 200 + $dy * 8, $a, $l1, 20, $b1, sub { 1 }, 18);
  my ($ex, $ey) = @{$m->[-1]}; my ($px, $py) = @{$m->[-2]}; my $ea = rad2deg(atan2($ey - $py, $ex - $px));
  my $kink = (rand(1) < 0.5 ? -1 : 1) * (40 + rand(50));
  strap($ex, $ey, $ea + $kink, 46 + rand(36), 19, $kink * 0.2, 1, 'c3', 'c4');
  strap(200 + $dx * 8, 200 + $dy * 8, $a, $l1 + 4, 21, $b1, 1, 'c3', 'c4');
}
write_svg('8-dead.svg', 'Garlic died from lack of water');
print "wrote 8 files to $OUT\n";

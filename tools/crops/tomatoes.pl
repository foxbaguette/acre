# Tomato crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/tomatoes.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/tomatoes';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#3E7D33', c2 => '#7DBF4A', c3 => '#F5D25A', c4 => '#5A3A22', c5 => '#DE3B26');
my @S;   # current shape list
our ($LW, $CURL) = (0.6, 1);   # leaflet width ratio and curl (the dead plant shrivels)

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A tapered blade or stalk from (x,y) heading `ang`, bending `bend` degrees over its length (as in wheat.pl).
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $taper) = @_;
  $taper //= 1;   # < 1 keeps some width at the tip (a cut stem)
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
  my ($dx, $dy) = dir($ang);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
  return ($px, $py, $a - $bend / $n);
}

# End point of a bent path (same stepping as blade).
sub walk {
  my ($x, $y, $ang, $len, $bend, $upto) = @_; $upto //= 1;
  my $n = 10; my $a = $ang;
  for my $i (1 .. int($n * $upto + 0.5)) { my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  return ($x, $y, $a);
}

# A jagged tomato leaflet: pointed oval with saw-toothed edges, split along the midrib into lit/dark halves.
sub leaflet {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $jag) = @_;
  $jag //= 0.28;
  my $n = 12; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * sin(pi * min(1, $t ** 0.75)) ** 0.8;
    $hw *= ($i % 2 ? 1 + $jag : 1 - $jag * 0.4) if $i > 0 && $i < $n - 1;
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# A compound tomato leaf: a rachis with paired jagged leaflets and a big terminal leaflet.
sub cleaf {
  my ($x, $y, $ang, $len, $sc, $bend, $light, $dark, $pairs, $spread) = @_;
  $pairs //= 3; $spread //= 58;
  my ($ex, $ey, $ea) = walk($x, $y, $ang, $len, $bend);
  # leaflets (drawn before the rachis tip leaflet so it sits on top)
  for my $k (reverse 1 .. $pairs) {
    my $t = $pairs > 1 ? 0.3 + 0.5 * ($k - 1) / ($pairs - 1) : 0.5;
    my ($px, $py, $pa) = walk($x, $y, $ang, $len, $bend, $t);
    my $ll = $len * $sc * (0.7 - 0.15 * $t);
    for my $side (-1, 1) {
      leaflet($px, $py, $pa + $side * $spread, $ll, $ll * $main::LW, $side * 16 * $main::CURL, $light, $dark, 0.24);
    }
    if ($pairs > 1 && $k > 1) {       # tiny in-between leaflets
      my ($qx, $qy, $qa) = walk($x, $y, $ang, $len, $bend, $t - 0.2);
      leaflet($qx, $qy, $qa + $_ * ($spread + 20), $ll * 0.38, $ll * 0.24, 0, $light, $dark, 0.2) for (-1, 1);
    }
  }
  blade($x, $y, $ang, $len, 4.5, $bend, $light, $dark);
  leaflet($ex - cos(deg2rad($ea)) * 3, $ey - sin(deg2rad($ea)) * 3, $ea, $len * $sc * 0.72, $len * $sc * 0.44, $bend * 0.3, $light, $dark, 0.26);
}

# Round faceted fruit: body, shaded crescent at lower right, lit glint at upper left.
sub fruit {
  my ($x, $y, $r, $body, $shade, $glint, $sq) = @_; $sq //= 1;
  my $n = 14; my @o;
  for my $i (0 .. $n - 1) {
    my $th = 2 * pi * $i / $n + 0.11;
    my $rr = $r * (1 + 0.035 * cos(5 * $th));
    push @o, [$x + cos($th) * $rr, $y + sin($th) * $rr * $sq];
  }
  poly($body, @o);
  # shaded crescent: outer arc around 45 degrees (lower right), inner edge pulled toward the lit centre
  my ($cx, $cy) = ($x - $r * 0.25, $y - $r * 0.25 * $sq);
  my (@out, @in);
  my $i0 = int((pi / 4 - 0.11) / (2 * pi) * $n + 0.5);
  for my $j (-int($n / 2) .. int($n / 2)) {
    my $i = ($i0 + $j) % $n;
    my $th = 2 * pi * $i / $n + 0.11; my $d = cos($th - pi / 4);
    next unless $d > 0.05;
    push @out, $o[$i];
    my $k = 0.74 + 0.26 * (1 - ($d - 0.05) / 0.95) ** 1.5;
    push @in, [$cx + ($o[$i][0] - $cx) * $k, $cy + ($o[$i][1] - $cy) * $k];
  }
  poly($shade, @out, reverse @in);
  # glint
  my @g = map { my ($a, $rr) = @$_; [$x + cos(deg2rad($a)) * $r * $rr, $y + sin(deg2rad($a)) * $r * $rr * $sq] }
          ([-168, 0.70], [-140, 0.80], [-108, 0.72], [-122, 0.58], [-150, 0.54]);
  poly($glint, @g);
}

# Tomato calyx seen from above: a green star of sepals.
sub calyx_top {
  my ($x, $y, $r, $rot) = @_;
  for my $i (0 .. 4) { my $a = $rot + $i * 72; blade($x, $y, $a, $r * 0.62, $r * 0.26, 22, 'c2', 'c1'); }
  my @p; for my $i (0 .. 4) { my ($dx, $dy) = dir($rot + 36 + $i * 72); push @p, [$x + $dx * $r * 0.13, $y + $dy * $r * 0.13]; }
  poly('c1', @p);
}

sub tomato_top { my ($x, $y, $r, $rot, $ripe) = @_;
  fruit($x, $y, $r, $ripe ? 'c5' : 'c2', $ripe ? 'c4' : 'c1', 'c3');
  calyx_top($x, $y, $r, $rot);
}

# Small yellow star flower seen from above / front: green sepal star behind, five yellow petals, cone.
sub flower {
  my ($x, $y, $r, $rot) = @_;
  for my $i (0 .. 4) { my $a = $rot + 36 + $i * 72; blade($x, $y, $a, $r * 0.8, $r * 0.32, 0, 'c2', 'c1'); }
  for my $i (0 .. 4) {
    my $a = $rot + $i * 72; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    poly('c3', [$x + $nx * $r * 0.2, $y + $ny * $r * 0.2], [$x + $dx * $r, $y + $dy * $r], [$x - $nx * $r * 0.2, $y - $ny * $r * 0.2]);
  }
  my @p; for my $i (0 .. 4) { my ($dx, $dy) = dir($rot + 36 + $i * 72); push @p, [$x + $dx * $r * 0.26, $y + $dy * $r * 0.26]; }
  poly('c3', @p);
  my @q; for my $i (0 .. 4) { my ($dx, $dy) = dir($rot + 36 + $i * 72); push @q, [$x + $dx * $r * 0.12, $y + $dy * $r * 0.12]; }
  poly('c1', @q);
}

# Small irregular patch of soil.
sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o;
  srand($seed);
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12; my $k = 0.82 + rand(0.3); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
}

# Flat tomato seed: teardrop disc with a thin shaded edge.
sub seed {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 13) {
    my $th = 2 * pi * $i / 14;
    my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 + 0.28 * cos($th));
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly('c3', @o);
  shade_rim($x, $y, $len * 0.5, 'c4', 0.8, @o);
}

# Shaded crescent along the lower-right edge of any convex outline @o around (x,y).
sub shade_rim {
  my ($x, $y, $r, $cls, $kmin, @o) = @_;
  my $n = @o;
  my @d = map { my ($vx, $vy) = ($_->[0] - $x, $_->[1] - $y); my $l = sqrt($vx * $vx + $vy * $vy) || 1; ($vx + $vy) * 0.7071 / $l } @o;
  my $s = 0; for my $i (0 .. $n - 1) { if ($d[$i] > 0.1 && $d[($i - 1) % $n] <= 0.1) { $s = $i; last } }
  my ($cx, $cy) = ($x - $r * 0.3, $y - $r * 0.3);
  my (@out, @in);
  for my $j (0 .. $n - 1) {
    my $i = ($s + $j) % $n; last unless $d[$i] > 0.1;
    push @out, $o[$i];
    my $k = $kmin + (1 - $kmin) * (1 - ($d[$i] - 0.1) / 0.9) ** 1.5;
    push @in, [$cx + ($o[$i][0] - $cx) * $k, $cy + ($o[$i][1] - $cy) * $k];
  }
  poly($cls, @out, reverse @in) if @out > 1;
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

# A bush of compound leaves radiating from the centre.
sub bush {
  my ($n, $len, $lenVar, $sc, $bendMax, $pairs, $seed, $start, $light, $dark) = @_;
  srand($seed); my @b;
  for my $i (0 .. $n - 1) {
    my $a = ($start // -90) + $i * 360 / $n + rand(16) - 8;
    push @b, [$a, $len + rand($lenVar), (rand(1) < 0.5 ? -1 : 1) * $bendMax * (0.4 + rand(0.6))];
  }
  for (sort { $b->[1] <=> $a->[1] } @b) {
    my ($a, $l, $bend) = @$_;
    my ($dx, $dy) = dir($a);
    cleaf(200 + $dx * 6, 200 + $dy * 6, $a, $l, $sc, $bend, $light // 'c2', $dark // 'c1', $pairs);
  }
}

# A truss seen from above: a green stalk from the plant with a cluster of tomatoes at its end.
sub truss_top {
  my ($ang, $from, $len, $fruits, $ripe, $seed) = @_;
  srand($seed);
  my ($dx, $dy) = dir($ang);
  my ($sx, $sy) = (200 + $dx * $from, 200 + $dy * $from);
  my ($ex, $ey) = blade($sx, $sy, $ang, $len, 7, 10, 'c2', 'c1');
  my @f;
  for my $f (@$fruits) {
    my ($off, $side, $r) = @$f; my $g = $ripe ? 1.12 : 1; $side *= $g; $r *= $g;   # along the stalk, sideways, radius
    my $px = $sx + $dx * $len * $off + -$dy * $side; my $py = $sy + $dy * $len * $off + $dx * $side;
    push @f, [$px, $py, $r];
  }
  # small pedicels from the stalk to each fruit
  for (@f) { my ($px, $py) = @$_; my $qx = $sx + $dx * $len * 0.6; my $qy = $sy + $dy * $len * 0.6;
    my $a = rad2deg(atan2($py - $qy, $px - $qx)); my $d = sqrt(($px - $qx) ** 2 + ($py - $qy) ** 2);
    blade($qx, $qy, $a, $d, 4, 0, 'c2', 'c1') if $d > 4; }
  tomato_top($_->[0], $_->[1], $_->[2], rand(72), $ripe) for sort { $a->[1] + $a->[0] <=> $b->[1] + $b->[0] } @f;
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a small heap of flat, pale tomato seeds.
for my $s ([128, 306, 14], [174, 312, -160], [222, 314, 40], [270, 304, 170], [150, 274, 200], [198, 278, -20],
            [246, 272, 120], [176, 244, 60], [224, 242, 190], [200, 212, -110]) { seed($s->[0], $s->[1], $s->[2], 46, 36); }
write_svg('1-seeds-front.svg', 'Tomato seeds');

# 2. Just sown, top down: seeds pressed into small soil pockets.
my @sown = ([170, 172, -20], [236, 170, 50], [200, 228, 100]);
for (@sown) { soil($_->[0], $_->[1], 34, 28, int($_->[0] * 7 + $_->[1])); }
for (@sown) { seed($_->[0] - 11, $_->[1] + 5, $_->[2], 25, 20); seed($_->[0] + 11, $_->[1] - 6, $_->[2] + 140, 24, 19); }
write_svg('2-sown.svg', 'Tomatoes just sown');

# 3. First growth, top down: two narrow seed leaves and the first jagged true leaf.
soil(200, 200, 34, 30, 3);
leaflet(200, 200, 200, 78, 26, -10, 'c2', 'c1', 0);
leaflet(200, 200, 20, 78, 26, -10, 'c2', 'c1', 0);
cleaf(200, 200, -80, 56, 0.7, 10, 'c2', 'c1', 1, 62);
cleaf(200, 200, 100, 42, 0.7, -8, 'c2', 'c1', 1, 62);
write_svg('3-first-growth.svg', 'Tomato first growth');

# 4. Second growth, top down: a young plant of compound jagged leaves.
soil(200, 200, 34, 30, 4);
bush(6, 84, 20, 0.6, 26, 2, 41, -70);
write_svg('4-second-growth.svg', 'Tomato second growth');

# 5. Third growth, top down: bushy plant with yellow star flowers and small green fruit.
soil(200, 200, 34, 30, 5);
bush(9, 98, 22, 0.56, 30, 3, 51, -80);
bush(5, 62, 14, 0.6, 20, 2, 52, -40);
for my $cl ([-45, 0], [45, 1], [135, 2], [225, 3], [0, 4]) {
  my ($a, $k) = @$cl; my ($dx, $dy) = dir($a); my $len = $k == 4 ? 30 : 52; my $from = $k == 4 ? 16 : 30;
  my ($sx, $sy) = (200 + $dx * $from, 200 + $dy * $from);
  my ($ex, $ey, $ea) = blade($sx, $sy, $a, $len, 6, 12, "c2", "c1");
  my @fl = map { my ($o, $d) = @$_; my ($fx, $fy) = dir($ea + $o); [$ex + $fx * $d, $ey + $fy * $d] } ([-50, 18], [40, 20], [0, 30], [-10, 4]);
  for (@fl) { my $an = rad2deg(atan2($_->[1] - $ey, $_->[0] - $ex)); my $dd = sqrt(($_->[0] - $ex) ** 2 + ($_->[1] - $ey) ** 2); blade($ex, $ey, $an, $dd, 3.5, 0, "c2", "c1") if $dd > 6; }
  my $i = 0; flower($_->[0], $_->[1], $i++ == 3 ? 14 : 18, $a + $i * 17) for @fl;
}
write_svg('5-third-growth.svg', 'Tomato third growth');

# 6. Harvest, top down: a full bush with trusses of ripe red tomatoes.
soil(200, 200, 34, 30, 6);
bush(11, 114, 24, 0.54, 30, 3, 61, -85);
bush(6, 70, 16, 0.6, 22, 2, 62, -60);
truss_top(-60, 18, 78, [[1.05, -6, 24], [0.86, 19, 22], [0.70, -14, 20]], 1, 63);
truss_top(30, 18, 86, [[1.05, 4, 25], [0.84, -18, 23], [0.66, 14, 20]], 1, 64);
truss_top(120, 18, 80, [[1.05, -4, 24], [0.86, 17, 22], [0.68, -15, 20]], 1, 65);
truss_top(210, 18, 82, [[1.05, 6, 25], [0.84, -17, 22], [0.66, 15, 19]], 1, 66);
tomato_top(196, 196, 22, 20, 1);
write_svg('6-harvest.svg', 'Tomatoes ready to harvest');

# 7. Harvest, front view: the harvested produce (inventory item): a short cut vine truss with three
#    ripe tomatoes and their green star calyxes. No plant, no soil.
{
  blade(104, 150, -6, 196, 11, 18, "c2", "c1", 0.4);            # cut piece of truss stem
  leaflet(130, 146, -116, 64, 36, -14, 'c2', 'c1', 0.26);                # a small leaf stub
  my @fr = ([150, 228, 56, 0.3], [262, 218, 52, 0.8], [204, 292, 54, 0.5]);
  for my $f (@fr) {                                                      # pedicels from the stem
    my ($fx, $fy, $r, $t) = @$f; my ($sx, $sy) = walk(104, 150, -6, 196, 18, $t);
    my $ty = $fy - $r * 0.86; my $a = rad2deg(atan2($ty - $sy, $fx - $sx)); my $d = sqrt(($fx - $sx) ** 2 + ($ty - $sy) ** 2);
    blade($sx, $sy, $a, $d, 7, 0, "c2", "c1");
  }
  for my $f (sort { $a->[1] <=> $b->[1] } @fr) {
    my ($fx, $fy, $r) = @$f;
    fruit($fx, $fy, $r, 'c5', 'c4', 'c3', 0.9);
    for my $sa (-172, 152, 118, 62, 28, -8) { blade($fx, $fy - $r * 0.84, $sa, $r * 0.5, $r * 0.17, $sa > 90 || $sa < -90 ? -34 : 34, 'c2', 'c1'); }
    my @p = map { my ($dx, $dy) = dir(-90 + $_ * 72); [$fx + $dx * $r * 0.1, $fy - $r * 0.84 + $dy * $r * 0.07] } 0 .. 4;
    poly('c1', @p);
  }
}
write_svg('7-harvest-front.svg', 'Harvested tomatoes');

# 8. Dead (never watered), top down: cracked dry soil and a collapsed, withered plant.
soil(200, 200, 66, 56, 8);
cracks(8, 83, 11, "c3");
srand(81); ($LW, $CURL) = (0.42, 3);
for my $i (0 .. 6) {
  my $a = -80 + $i * 51 + rand(16) - 8; my ($dx, $dy) = dir($a);
  my $l = 70 + rand(36); my $bend = (rand(1) < 0.5 ? -1 : 1) * (60 + rand(50));
  cleaf(200 + $dx * 6, 200 + $dy * 6, $a, $l, 0.42, $bend, "c3", "c4", 2, 30);
}
for ([-20, 20], [150, 16], [250, 18]) { blade(200, 200, $_->[0], $_->[1], 10, 0, 'c3', 'c4'); }  # broken stubs
write_svg('8-dead.svg', 'Tomato plant died from lack of water');
print "wrote 8 files to $OUT\n";

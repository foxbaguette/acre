# Eggplant (aubergine) crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/eggplant.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/eggplant';
mkdir 'crops'; mkdir $OUT;
# c1 shaded grey-green leaf, c2 lit grey-green, c3 cream (gloss, flower eye, seeds, dry leaves),
# c4 dark plum-brown (soil, fruit shade), c5 aubergine purple (fruit, flowers, stems)
my %PAL = (c1 => '#4B6B4E', c2 => '#8BAA86', c3 => '#EED28C', c4 => "#4A2E2B", c5 => '#5B2C74');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Bent shape from (x,y) heading `ang`; $pl/$pr give left/right half-width factors for t in 0..1.
# Split along its midline into a lit and a shaded half. Returns end point, end angle, lit flag and outlines.
sub shape2 {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $pl, $pr, $n) = @_;
  $n //= 14; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hl = $w / 2 * $pl->($t) + ($i == $n ? 0 : 0.5);
    my $hr = $w / 2 * $pr->($t) + ($i == $n ? 0 : 0.5);
    push @l, [$px - $dy * $hl, $py + $dx * $hl];
    push @r, [$px + $dy * $hr, $py - $dx * $hr];
    push @mid, [$px, $py];
    last if $i == $n;
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid) if $light;
  poly($leftLit ? $dark : $light, @r, reverse @mid) if $light;
  return ($px, $py, $a, $leftLit, \@mid, \@l, \@r);
}
sub blade { my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $tip) = @_; $tip //= 0;
  shape2($x, $y, $ang, $len, $w, $bend, $light, $dark, (sub { 1 - (1 - $tip) * $_[0] }) x 2, 10) }

# End point of a bent path (same stepping as shape2 with n steps).
sub walk {
  my ($x, $y, $ang, $len, $bend, $upto, $n) = @_; $n //= 10;
  for my $i (1 .. int($n * $upto + 0.5)) { my ($dx, $dy) = dir($ang); $x += $dx * $len / $n; $y += $dy * $len / $n; $ang += $bend / $n; }
  return ($x, $y, $ang);
}

# Broad eggplant leaf: soft ovate blade with a gently wavy, shallow-lobed edge, on a short stalk.
our $WILT = 0;   # dead plant: narrower, crinkled, curled
sub eleaf {
  my ($x, $y, $ang, $len, $w, $bend, $ph, $light, $dark) = @_;
  $light //= 'c2'; $dark //= 'c1'; $ph //= 0;
  my ($sx, $sy, $sa) = blade($x, $y, $ang, $len * 0.16, max(3, $len * 0.05), $bend * 0.15, $light, $dark, 0.7);
  my $wav = 0.085 + $WILT * 0.2;
  my $prof = sub { my ($t, $p) = @_; return 0.1 if $t <= 0;
    my $b = sin(pi * $t ** 0.72) ** 0.7;
    $b * (1 + $wav * sin(2 * pi * 2.2 * $t + $p) * min(1, $t * 3)) * (1 - $WILT * 0.35) };
  my ($ex, $ey, $ea, $leftLit, $mid, $l, $r) =
    shape2($sx, $sy, $sa, $len * 0.84, $w, $bend * 0.85, $light, $dark, sub { $prof->($_[0], $ph) }, sub { $prof->($_[0], $ph + 2.1) }, 16);
  # two vein facets on the lit half so the big flat leaf has some structure
  return ($ex, $ey, $ea) if $WILT;
  my $side = $leftLit ? $l : $r; my $n = @$mid - 1;
  for my $k ([0.18, 0.42, 0.48], [0.50, 0.72, 0.78]) {   # broad facets: midrib point, edge point, back on the midrib
    my ($a, $b, $c) = map { int($_ * $n + 0.5) } @$k;
    my ($m0, $o, $m1) = ($mid->[$a], $side->[$b], $mid->[$c]);
    poly($dark, $m0, [$m0->[0] + ($o->[0] - $m0->[0]) * 0.8, $m0->[1] + ($o->[1] - $m0->[1]) * 0.8], $m1);
  }
  return ($ex, $ey, $ea);
}

# Glossy aubergine fruit from its calyx end (x,y) heading `ang`: narrow shoulder, fat round bottom,
# deep shade along the dark side, long cream gloss streak on the lit side, spiky green calyx cap and stalk.
sub fruit {
  my ($x, $y, $ang, $len, $w, $bend, %o) = @_;
  my $body = $o{body} // 'c5'; my $shade = $o{shade} // 'c4'; my $gloss = $o{gloss} // 'c3';
  my ($cl, $cd) = ($o{cl} // 'c2', $o{cd} // 'c1');
  my ($dx, $dy) = dir($ang);
  my $st = $o{stalk} // 0.24;
  blade($x + $dx * 6, $y + $dy * 6, $ang + 180 + ($o{sb} // 0), $len * $st + 6, $w * ($o{sw} // 0.2), $o{sbend} // 16, $cl, $cd, 0.8) if $st;
  my $prof = sub { my $t = shift;
    my $b = 0.36 + 0.64 * (3 * $t * $t - 2 * $t ** 3) ** 0.7;          # widening toward the bottom
    my $e = $t < 0.6 ? 1 : sqrt(max(0, 1 - (($t - 0.6) / 0.4) ** 2));   # rounded bottom
    my $s = $t < 0.08 ? sqrt($t / 0.08) : 1;                             # rounded shoulder
    max(0.02, $b * $e * (0.5 + 0.5 * $s)) * ($o{wrinkle} ? 0.84 + 0.16 * sin($t * 19) : 1) };
  my ($ex, $ey, $ea, $leftLit, $mid, $l, $r) = shape2($x, $y, $ang, $len, $w, $bend, undef, undef, $prof, $prof, 20);
  poly($body, @$l, reverse @$r);
  my $sh = $leftLit ? $r : $l; my $li = $leftLit ? $l : $r;
  my $lerp = sub { my ($i, $side, $k) = @_; my ($m, $e) = ($mid->[$i], $side->[$i]); [$m->[0] + ($e->[0] - $m->[0]) * $k, $m->[1] + ($e->[1] - $m->[1]) * $k] };
  # shade band: from the shaded edge in to about 40% of the half-width
  poly($shade, @$sh, reverse map { $lerp->($_, $sh, 0.54 - 0.1 * sin(pi * $_ / $#$mid)) } 0 .. $#$mid);
  unless ($o{dull}) {   # gloss: long streak across the lit half, plus a small spot near the bottom
    my $n = $#$mid; my (@a, @b);
    for my $i (int($n * 0.26 + 0.5) .. int($n * 0.82)) {
      my $u = max(0, min(1, ($i / $n - 0.26) / 0.56)); my $k = 0.48 + 0.05 * sin(pi * $u); my $hw = 0.14 * sin(pi * $u) ** 0.6 + 0.015;
      push @a, $lerp->($i, $li, $k - $hw * 0.6); push @b, $lerp->($i, $li, $k + $hw);
    }
    poly($gloss, @a, reverse @b);
    my $p = $lerp->(int($n * 0.9), $li, 0.42); my $gr = $w * 0.045;
    poly($gloss, map { my ($c, $s) = dir($_ * 72 + 10); [$p->[0] + $c * $gr, $p->[1] + $s * $gr] } 0 .. 4);
  }
  calyx($mid, $l, $r, $leftLit, $cl, $cd, $o{cap} // 0.36);
}

# The calyx cap hugging the fruit's shoulder: slightly flared, with pointed lobes reaching down the fruit.
sub calyx {
  my ($mid, $l, $r, $leftLit, $cl, $cd, $depth) = @_;
  my $n = $#$mid;
  my $at = sub { my ($t, $s) = @_; my $i = min($n, int($t * $n + 0.5)); my $e = $s < 0 ? $l->[$i] : $r->[$i]; my $m = $mid->[$i];
    my $k = abs($s) * 1.14; [$m->[0] + ($e->[0] - $m->[0]) * $k, $m->[1] + ($e->[1] - $m->[1]) * $k] };
  my @tips = ([-0.95, 0.62], [-0.55, 0.92], [0.0, 1.0], [0.55, 0.92], [0.95, 0.62]);   # (across, depth factor)
  my @zig;
  push @zig, $at->(0, -0.55), $at->(0.04, -1.0);
  for my $j (0 .. $#tips) {
    my ($s, $f) = @{$tips[$j]};
    push @zig, $at->($depth * $f, $s);
    push @zig, $at->($depth * 0.42, ($s + $tips[$j + 1][0]) / 2) if $j < $#tips;
  }
  push @zig, $at->(0.04, 1.0), $at->(0, 0.55);
  # split at the centre tip into two halves
  my $c = 6;   # index of the centre tip in @zig
  my @L = (@zig[0 .. $c], $mid->[0]);
  my @R = (@zig[$c .. $#zig], $mid->[0]);
  poly($leftLit ? $cl : $cd, @L);
  poly($leftLit ? $cd : $cl, @R);
}

# Eggplant flower, face up: five broad pointed purple petals in a star, a cream cone of anthers.
sub flower {
  my ($x, $y, $r, $rot) = @_;
  for my $i (0 .. 4) { my $a = $rot + 36 + $i * 72; blade($x, $y, $a, $r * 0.62, $r * 0.24, 0, 'c2', 'c1'); }   # green sepals
  for my $i (0 .. 4) {
    my $a = $rot + $i * 72;
    shape2($x, $y, $a, $r, $r * 0.95, 0, 'c5', 'c4', (sub { my $t = shift; sin(pi * $t ** 0.9) ** 0.6 * (1 - 0.15 * $t) }) x 2, 8);
  }
  my @p; for my $i (0 .. 9) { my ($dx, $dy) = dir($rot + $i * 36); my $k = $i % 2 ? 0.40 : 0.22; push @p, [$x + $dx * $r * $k, $y + $dy * $r * $k]; }
  poly('c3', @p);
  my @q; for my $i (0 .. 4) { my ($dx, $dy) = dir($rot + 36 + $i * 72); push @q, [$x + $dx * $r * 0.1, $y + $dy * $r * 0.1]; }
  poly('c2', @q);
}

# A flat kidney-shaped eggplant seed with a dark shaded rim and a pale lit face.
sub seed {
  my ($x, $y, $rot, $r) = @_; my @o;
  for my $i (0 .. 15) {
    my $th = 2 * pi * $i / 16; my $k = 1 - 0.3 * exp(-((($th - pi / 2) ** 2) / 0.16));
    my ($c, $s) = (cos($th) * $r * $k, sin($th) * $r * 0.68 * $k);
    my $ra = deg2rad($rot);
    push @o, [$x + $c * cos($ra) - $s * sin($ra), $y + $c * sin($ra) + $s * cos($ra)];
  }
  poly('c4', @o);
  poly('c3', map { [$x + ($_->[0] - $x) * 0.84 - $r * 0.07, $y + ($_->[1] - $y) * 0.84 - $r * 0.07] } @o);
  poly('c2', map { [$x + ($_->[0] - $x) * 0.30 - $r * 0.25, $y + ($_->[1] - $y) * 0.30 - $r * 0.25] } @o) if $_[4];
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

# A top-down rosette of broad leaves; longest drawn first so the younger ones sit on top.
sub rosette {
  my ($n, $len, $lenVar, $wf, $bendMax, $seed, $start, $from) = @_;
  srand($seed); my @b;
  for my $i (0 .. $n - 1) {
    my $a = ($start // -90) + $i * 360 / $n + rand(14) - 7;
    push @b, [$a, $len + rand($lenVar), (rand(1) < 0.5 ? -1 : 1) * $bendMax * (0.4 + rand(0.6)), rand(6)];
  }
  for (sort { $b->[1] <=> $a->[1] } @b) {
    my ($a, $l, $bend, $ph) = @$_; my ($dx, $dy) = dir($a); $from //= 6;
    eleaf(200 + $dx * $from, 200 + $dy * $from, $a, $l, $l * $wf, $bend, $ph);
  }
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a thin round slice of eggplant (purple skin, cream flesh dotted with its seeds)
#    with a few loose flat seeds scattered low beside it.
{
  my ($cx, $cy, $rx, $ry) = (178, 196, 104, 96);
  my $ell = sub { my ($x, $y, $a, $b, $n) = @_; map { my $th = 2 * pi * $_ / $n; [$x + cos($th) * $a, $y + sin($th) * $b] } 0 .. $n - 1 };
  poly('c4', $ell->($cx + 9, $cy + 12, $rx, $ry, 24));                 # cut edge / thickness in shadow
  poly('c5', $ell->($cx, $cy, $rx, $ry, 24));                           # skin
  poly('c3', $ell->($cx + 1, $cy + 1, $rx * 0.9, $ry * 0.9, 24));       # flesh
  # flesh shading toward the lower right
  my @o = $ell->($cx + 1, $cy + 1, $rx * 0.9, $ry * 0.9, 24);
  my @arc = @o[22, 23, 0 .. 9];
  poly('c4', @arc, reverse map { [$cx + ($_->[0] - $cx) * 0.9 - 4, $cy + ($_->[1] - $cy) * 0.9 - 4] } @arc) if 0;
  # seed pattern: a loose ring of small dark seeds in the flesh
  srand(11);
  for my $i (0 .. 17) {
    my $th = 2 * pi * $i / 18 + rand(0.2); my $k = 0.5 + rand(0.16);
    my ($sx, $sy) = ($cx + cos($th) * $rx * $k, $cy + sin($th) * $ry * $k);
    my ($dx, $dy) = (cos($th), sin($th)); my ($nx, $ny) = (-$dy, $dx);
    poly('c4', [$sx - $dx * 6, $sy - $dy * 6], [$sx + $nx * 3.2, $sy + $ny * 3.2], [$sx + $dx * 6, $sy + $dy * 6], [$sx - $nx * 3.2, $sy - $ny * 3.2]);
  }
  for my $i (0 .. 6) {
    my $th = 2 * pi * $i / 7 + 0.4; my ($sx, $sy) = ($cx + cos($th) * $rx * 0.24, $cy + sin($th) * $ry * 0.24);
    poly('c4', [$sx - 4, $sy], [$sx, $sy - 2.6], [$sx + 4, $sy], [$sx, $sy + 2.6]);
  }
  # loose seeds scattered low in front, beside the slice
  seed($_->[0], $_->[1], $_->[2], 15) for ([262, 300, 20], [300, 290, -30], [286, 322, 160], [326, 316, 70], [240, 326, -60]);
}
write_svg('1-seeds-front.svg', 'Eggplant seeds');

# 2. Just sown, top down: seeds pressed into small soil pockets.
my @sown = ([170, 172, -20], [236, 170, 50], [200, 228, 100]);
for (@sown) { soil($_->[0], $_->[1], 34, 28, int($_->[0] * 7 + $_->[1])); }
for (@sown) { seed($_->[0] - 9, $_->[1] + 4, $_->[2], 12); seed($_->[0] + 10, $_->[1] - 6, $_->[2] + 140, 11); }
write_svg('2-sown.svg', 'Eggplant just sown');

# 3. First growth, top down: two oval seed leaves and the first broad true leaves.
soil(200, 200, 34, 30, 3);
shape2(200, 200, 200, 66, 30, -8, 'c2', 'c1', (sub { sin(pi * $_[0] ** 0.8) ** 0.6 }) x 2);
shape2(200, 200, 20, 66, 30, -8, 'c2', 'c1', (sub { sin(pi * $_[0] ** 0.8) ** 0.6 }) x 2);
eleaf(200, 200, -76, 88, 56, 10, 1);
eleaf(200, 200, 106, 70, 46, -8, 3);
write_svg('3-first-growth.svg', 'Eggplant first growth');

# 4. Second growth, top down: a young plant of broad, soft grey-green leaves.
soil(200, 200, 34, 30, 4);
rosette(5, 104, 18, 0.62, 20, 41, -80);
rosette(3, 62, 10, 0.64, 14, 42, -20);
write_svg('4-second-growth.svg', 'Eggplant second growth');

# 5. Third growth, top down: a full plant with purple star flowers and a first small fruit.
soil(200, 200, 34, 30, 5);
rosette(7, 128, 20, 0.6, 22, 51, -76);
for my $f ([-30, 70, 20, 0], [96, 64, 19, 30], [210, 72, 20, 12]) {      # flower clusters on short purple stalks
  my ($a, $d, $r, $rot) = @$f; my ($dx, $dy) = dir($a);
  blade(200 + $dx * 10, 200 + $dy * 10, $a, $d - 4, 5, 10, 'c5', 'c4');
  flower(200 + $dx * $d, 200 + $dy * $d, $r, $rot);
  my ($ex, $ey) = (200 + $dx * $d, 200 + $dy * $d); my ($ox, $oy) = dir($a + 55);
  flower($ex - $ox * 22 * -1 - $dx * 10, $ey + $oy * 22 - $dy * 10, $r * 0.8, $rot + 20);
}
fruit(200 - 34, 200 + 30, 140, 44, 24, 8, stalk => 0.8);                                  # young fruit
rosette(3, 58, 10, 0.64, 14, 52, -50, 2);
write_svg('5-third-growth.svg', 'Eggplant third growth');

# 6. Harvest, top down: big leaves and glossy aubergines hanging out between them.
soil(200, 200, 34, 30, 6);
rosette(8, 142, 22, 0.6, 22, 61, -64);
for my $f ([-118, 92, 52, 14], [-20, 100, 54, -12], [68, 94, 52, 10], [160, 98, 54, -14]) {
  my ($a, $len, $w, $bend) = @$f; my ($dx, $dy) = dir($a);
  fruit(200 + $dx * 50, 200 + $dy * 50, $a, $len, $w, $bend, stalk => 0.42);
}
rosette(4, 38, 8, 0.66, 14, 62, -30, 2);
flower(232, 158, 15, 10);
write_svg('6-harvest.svg', 'Eggplants ready to harvest');

# 7. Harvested produce, front view: two glossy eggplants with spiky green calyx caps and thick stalks.
fruit(236, 104, 66, 214, 104, 12, stalk => 0.2, sb => -14, sw => 0.17);
fruit(176, 92, 108, 236, 112, -12, stalk => 0.2, sb => 12, sw => 0.17, sbend => -16);
write_svg('7-harvest-front.svg', 'Harvested eggplants');

# 8. Dead (never watered), top down: cracked dry soil, limp shrivelled leaves, one shrivelled fruit.
soil(200, 200, 58, 50, 8);
cracks(8, 83, 11, "c3");
srand(81); $WILT = 1;
my @dead; for my $i (0 .. 5) { push @dead, [-80 + $i * 60 + rand(18) - 9, 92 + rand(30), (rand(1) < 0.5 ? -1 : 1) * (70 + rand(50)), rand(6)]; }
for (sort { $b->[1] <=> $a->[1] } @dead) { my ($dx, $dy) = dir($_->[0]); eleaf(200 + $dx * 16, 200 + $dy * 16, $_->[0], $_->[1], $_->[1] * 0.44, $_->[2], $_->[3], "c3", "c4"); }
fruit(238, 230, 50, 58, 32, 24, body => "c5", shade => "c4", dull => 1, wrinkle => 1, cl => "c3", cd => "c4", stalk => 0.5, sw => 0.3);
for ([-10, 22], [140, 18], [250, 20]) { blade(200, 200, $_->[0], $_->[1], 9, 0, 'c3', 'c4'); }
write_svg('8-dead.svg', 'Eggplant died from lack of water');
print "wrote 8 files to $OUT\n";

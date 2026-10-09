# Ember Pepper crop art (fantasy fire pepper): 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/ember-pepper.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/ember-pepper';
mkdir 'crops'; mkdir $OUT;
# c1 dark leaf green, c2 lit green, c3 flame-tip yellow / ash, c4 scorched soil + deep ember red, c5 fire orange-red
my %PAL = (c1 => '#2E5A32', c2 => '#5E9A44', c3 => '#FFD86A', c4 => '#5A2620', c5 => '#EE5A22');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 }

# Bent shape from (x,y) heading `ang`. $pl/$pr give left/right half-width factors for t in 0..1.
# Split along its midline into a lit and a shaded half. Returns end point, end angle, and the outlines.
sub shape2 {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $pl, $pr, $n) = @_;
  $n //= 12; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hl = $w / 2 * $pl->($t) + ($i == $n ? 0 : 0.5);
    my $hr = $w / 2 * $pr->($t) + ($i == $n ? 0 : 0.5);
    push @l, [$px - $dy * $hl, $py + $dx * $hl];
    push @r, [$px + $dy * $hr, $py - $dx * $hr];
    push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
  return ($px, $py, $a - $bend / $n, $leftLit, \@mid, \@l, \@r);
}
sub shape { my $p = pop; shape2(@_, $p, $p) }
sub blade { shape(@_[0 .. 7], sub { (1 - $_[0]) ** 0.85 }) }
sub leaf  { shape(@_[0 .. 7], sub { my $t = shift; $t < 0.1 ? 0.12 : sin(pi * $t ** 0.62) ** 0.7 }) }   # broad ovate pepper leaf

# A flame-shaped pepper (or blossom): flickering outline, deep red shade, orange body, yellow inner tongue to the tip.
sub flame {
  my ($x, $y, $ang, $len, $w, $bend, $ph) = @_;
  my $base = sub { my $t = shift; sin(pi * $t ** 0.5) ** 0.9 };
  my $fl = sub { my $t = shift; $base->($t) * (1 + 0.34 * sin(2 * pi * 2.1 * $t + $ph) * $t) };
  my $fr = sub { my $t = shift; $base->($t) * (1 + 0.34 * sin(2 * pi * 2.1 * $t + $ph + 2.4) * $t) };
  my ($ex, $ey, $ea, $leftLit, $mid, $ol, $or) = shape2($x, $y, $ang, $len, $w, $bend, 'c5', 'c4', $fl, $fr, 16);
  my $sh = $leftLit ? $or : $ol;                        # keep only a thin deep-red rim on the shaded side
  poly("c5", @$mid, reverse map { [$mid->[$_][0] + ($sh->[$_][0] - $mid->[$_][0]) * 0.5, $mid->[$_][1] + ($sh->[$_][1] - $mid->[$_][1]) * 0.5] } 0 .. $#$mid);
  # inner yellow tongue riding the lit side, from 40% of the length to the tip
  my (@a, @b); my $n = @$mid - 1; my $side = $leftLit ? 1 : -1;
  for my $i (int($n * 0.4) .. $n) {
    my $t = $i / $n; my ($px, $py) = @{$mid->[$i]};
    my $j = $i < $n ? $i + 1 : $i; my $k = $i < $n ? $i : $i - 1;
    my ($dx, $dy) = ($mid->[$j][0] - $mid->[$k][0], $mid->[$j][1] - $mid->[$k][1]); my $d = sqrt($dx * $dx + $dy * $dy) || 1; $dx /= $d; $dy /= $d;
    my $u = $t < 0.4 ? 0 : ($t - 0.4) / 0.6;
    my $hw = $w * 0.36 * sin(pi * $u ** 0.6) ** 0.8 * $base->($t) * (1 + 0.3 * sin(2 * pi * 2.3 * $t + $ph + 1));
    my $off = $side * $w * 0.1 * (1 - $u);
    my ($cx, $cy) = ($px - $dy * $off, $py + $dx * $off);
    push @a, [$cx - $dy * $hw, $cy + $dx * $hw]; push @b, [$cx + $dy * $hw, $cy - $dx * $hw];
  }
  poly('c3', @a, reverse @b);
}

# A little flame blossom: three flickering flame petals fanned from one point.
sub blossom {
  my ($x, $y, $a, $ph) = @_;
  flame($x, $y, $a - 40, 26, 16, 10, $ph); flame($x, $y, $a + 40, 26, 16, -10, $ph + 2);
  flame($x, $y, $a, 36, 20, 0, $ph + 4);
}

# A pepper hanging from a calyx cap: stem, little green star cap, then the flame body.
sub pepper {
  my ($x, $y, $ang, $len, $w, $bend, $ph) = @_;
  my ($dx, $dy) = dir($ang);
  flame($x + $dx * 4, $y + $dy * 4, $ang, $len, $w, $bend, $ph);
  for my $s (-1, 1) { leaf($x, $y, $ang + $s * 52, $w * 0.42, $w * 0.32, 0, 'c2', 'c1'); }
  leaf($x - $dx * 4, $y - $dy * 4, $ang, $w * 0.36, $w * 0.36, 0, 'c2', 'c1');
}

# An ember seed: flat kidney disc with a lit glow face and a dark shaded rim.
sub seed {
  my ($x, $y, $rot, $r) = @_; my @o;
  for my $i (0 .. 13) {
    my $th = 2 * pi * $i / 14; my $k = 1 - 0.22 * exp(-((($th - pi) ** 2) / 0.25));   # notch = kidney
    my ($c, $s) = (cos($th) * $r * $k, sin($th) * $r * 0.82 * $k);
    my $ra = deg2rad($rot);
    push @o, [$x + $c * cos($ra) - $s * sin($ra), $y + $c * sin($ra) + $s * cos($ra)];
  }
  poly('c4', @o);
  my @in = map { [$x + ($_->[0] - $x) * 0.86 - $r * 0.06, $y + ($_->[1] - $y) * 0.86 - $r * 0.06] } @o;
  poly('c5', @in);
  my @hi = map { [$x + ($_->[0] - $x) * 0.5 - $r * 0.22, $y + ($_->[1] - $y) * 0.5 - $r * 0.22] } @o;
  poly('c3', @hi);
}

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

# A top-down bush: $nb branches, each carrying pairs of ovate leaves; returns branch tips.
sub bush {
  my ($nb, $reach, $lw, $seed, $start) = @_;
  srand($seed); my (@leaves, @tips);
  for my $i (0 .. $nb - 1) {
    my $a = ($start // -90) + $i * 360 / $nb + rand(16) - 8;
    my $r = $reach * (0.85 + rand(0.2));
    my ($dx, $dy) = dir($a);
    for my $k (1 .. 3) {
      my $d = $r * (0.12 + 0.3 * ($k - 1)); my $len = $r * (0.42 + 0.1 * $k) + rand(8);
      for my $s (-1, 1) { push @leaves, [200 + $dx * $d, 200 + $dy * $d, $a + $s * (44 - $k * 9) + rand(10) - 5, $len, $len * 0.5, $s * (10 + rand(10))]; }
    }
    push @leaves, [200 + $dx * $r * 0.62, 200 + $dy * $r * 0.62, $a + rand(10) - 5, $r * 0.46, $r * 0.24, rand(16) - 8];
    push @tips, [200 + $dx * $r * 0.6, 200 + $dy * $r * 0.6, $a];
  }
  leaf(@$_, 'c2', 'c1') for sort { $b->[3] <=> $a->[3] } @leaves;
  return @tips;
}

# 1. Seeds, front view: a little heap of glowing ember seeds.
for ([140, 286, 10, 26], [196, 292, -14, 27], [254, 286, 20, 26], [168, 244, -24, 26], [226, 246, 16, 26], [198, 204, 4, 25],
     [118, 300, -30, 20], [278, 302, 30, 20]) { seed(@$_); }
write_svg('1-seeds-front.svg', 'Ember Pepper seeds');

# 2. Just sown, top down: ember seeds pressed into soil pockets.
my @sown = ([166, 168, 20], [240, 162, -30], [202, 212, 70], [150, 240, -10], [252, 238, 40]);
for (@sown) { soil($_->[0], $_->[1], 28, 23, int($_->[0] * 7 + $_->[1])); }
for (@sown) { seed($_->[0], $_->[1], $_->[2], 17); }
write_svg('2-sown.svg', 'Ember Pepper just sown');

# 3. First growth: two seed leaves and two first true leaves.
soil(200, 200, 34, 30, 3);
leaf(200, 200, -150, 64, 20, -10, 'c2', 'c1'); leaf(200, 200, 30, 64, 20, -10, 'c2', 'c1');
leaf(200, 200, -62, 54, 32, 8, 'c2', 'c1');   leaf(200, 200, 118, 54, 32, 8, 'c2', 'c1');
write_svg('3-first-growth.svg', 'Ember Pepper first growth');

# 4. Second growth: a young bushy pepper plant.
soil(200, 200, 34, 30, 4);
bush(5, 92, 30, 41, -80);
write_svg('4-second-growth.svg', 'Ember Pepper second growth');

# 5. Third growth: full bush with little flame-shaped blossoms.
soil(200, 200, 34, 30, 5);
my @t5 = bush(7, 112, 30, 51, -86);
srand(52);
for my $t (@t5) {
  my ($x, $y, $a) = @$t; my ($dx, $dy) = dir($a);
  blossom($x + $dx * 24, $y + $dy * 24, $a + rand(20) - 10, rand(6));
  leaf($x + $dx * 22, $y + $dy * 22, $a + 180, 10, 10, 0, 'c2', 'c1');
}
blossom(190, 186, -60, 1); blossom(212, 214, 50, 3);
write_svg('5-third-growth.svg', 'Ember Pepper third growth');

# 6. Harvest: lush bush hung with big flame peppers.
soil(200, 200, 34, 30, 6);
my @t6 = bush(8, 124, 30, 61, -70);
srand(62);
for my $t (@t6) {
  my ($x, $y, $a) = @$t; my ($dx, $dy) = dir($a);
  pepper($x - $dx * 6, $y - $dy * 6, $a + rand(16) - 8, 84, 36, (rand(1) < .5 ? -1 : 1) * 18, rand(6));
}
pepper(200, 200, -40, 70, 32, 14, 2); pepper(200, 200, 150, 66, 30, -12, 4);
write_svg('6-harvest.svg', 'Ember Pepper ready to harvest');

# 7. Harvest, front view: the harvested produce, three flame peppers with green caps lying together.
for ([60, 110, 14, 250, 78, -16, 1], [30, 200, 3, 280, 86, 14, 3.5], [74, 292, -8, 250, 78, -12, 5]) {
  my ($x, $y, $a, $len, $w, $bend, $ph) = @$_;
  my ($dx, $dy) = dir($a);
  blade($x, $y, $a + 180 + 20, 24, 8, 10, 'c2', 'c1');              # short cut stem
  pepper($x, $y, $a, $len, $w, $bend, $ph);
}
write_svg('7-harvest-front.svg', 'Ember Pepper harvest');

# 8. Dead (never watered): cracked dry soil, charred ashen leaves lying limp, shrivelled burnt-out peppers.
soil(200, 200, 66, 56, 8);
srand(83);
for my $i (0 .. 6) {
  my $a = $i * 360 / 7 + rand(20); my ($x, $y) = (200, 200); my (@l, @r);
  for my $k (0 .. 4) {
    my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.8 - $k * 0.45;
    push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
    $x += $dx * 16; $y += $dy * 16;
  }
  poly('c3', @l, [$x, $y], reverse @r);
}
srand(81);
my @dead;
for my $i (0 .. 7) { push @dead, [-90 + $i * 45 + rand(16) - 8, 60 + rand(34), (rand(1) < 0.5 ? -1 : 1) * (40 + rand(40))]; }
for (sort { $b->[1] <=> $a->[1] } @dead) {
  my ($ex, $ey, $ea) = blade(200, 200, $_->[0], $_->[1] * 0.6, 6, $_->[2] * 0.3, "c1", "c4");
  shape($ex, $ey, $ea, $_->[1] * 0.7, 26, $_->[2], "c1", "c4", sub { my $t = shift; sin(pi * $t ** 0.6) ** 0.8 * (0.7 + 0.3 * sin($t * 21)) });
}
for ([-30, 40, 60], [150, 46, -70], [70, 36, 50]) {     # shrivelled, burnt-out peppers on bare stalks
  my ($ex, $ey, $ea) = blade(200, 200, $_->[0], $_->[1], 7, $_->[2] * 0.4, "c1", "c4");
  shape($ex, $ey, $ea, 30, 13, $_->[2], 'c1', 'c4', sub { my $t = shift; sin(pi * $t ** 0.5) * (0.75 + 0.25 * sin($t * 18)) });
}
write_svg('8-dead.svg', 'Ember Pepper died from lack of water');
print "wrote 8 files to $OUT\n";

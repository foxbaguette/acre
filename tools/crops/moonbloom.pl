# Moonbloom crop art (fantasy night flower): 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/moonbloom.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/moonbloom';
mkdir 'crops'; mkdir $OUT;
# c1 silvery blue-green leaf, c2 lit silver-mint, c3 moonlight white, c4 night soil, c5 moon blue-violet
my %PAL = (c1 => '#3F7F86', c2 => '#97CFC8', c3 => '#EEF2FF', c4 => '#4A3530', c5 => '#8C93E0');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }

# Generic bent shape from (x,y) heading `ang`; $prof->(t) gives the half-width factor 0..1.
# Split along its midrib into a lit and a shaded half.
sub shape {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $prof) = @_;
  my $n = 12; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * $prof->($t) + ($i == $n ? 0 : 0.5);
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
  return ($px, $py, $a);
}
sub blade { shape(@_[0 .. 7], sub { (1 - $_[0]) ** 0.85 }) }                     # stem / grass-like taper
sub leaf  { shape(@_[0 .. 7], sub { my $t = shift; $t < 0.08 ? 0.25 : sin(pi * $t ** 0.72) ** 0.75 }) } # lance leaf
sub bud   { shape(@_[0 .. 7], sub { my $t = shift; sin(pi * $t ** 0.62) ** 0.55 }) }                     # closed bud

# A crescent-moon seed: outer band lit, inner band shaded.
sub crescent {
  my ($x, $y, $rot, $r, $light, $dark) = @_;
  my $n = 14; my (@out, @in, @mid);
  for my $i (0 .. $n) {
    my $t = $i / $n; my $th = deg2rad($rot - 108 + 216 * $t);
    my $k = 0.8 * sin(pi * $t) ** 0.75;              # thick belly, sharp horns
    my ($c, $s) = (cos($th), sin($th));
    push @out, [$x + $c * $r, $y + $s * $r];
    push @in,  [$x + $c * $r * (1 - $k), $y + $s * $r * (1 - $k)];
    push @mid, [$x + $c * $r * (1 - $k * 0.45), $y + $s * $r * (1 - $k * 0.45)];
  }
  poly($dark, @mid, reverse @in);
  poly($light, @out, reverse @mid);
}

# Four-point sparkle.
sub sparkle {
  my ($x, $y, $s, $rot, $cls) = @_; my @p;
  for my $i (0 .. 7) { my ($dx, $dy) = dir($rot + $i * 45); my $r = $i % 2 ? $s * 0.28 : $s; push @p, [$x + $dx * $r, $y + $dy * $r]; }
  poly($cls, @p);
}

# A star-like open blossom. $sq squashes it vertically (front view tilt).
sub bloom {
  my ($x, $y, $r, $rot, $sq, $spark) = @_;
  $sq //= 1;
  my $tf = sub { my ($u, $v) = @_; [$x + $u, $y + $v * $sq] };
  my $petal = sub {
    my ($a, $len, $hw, $light, $dark) = @_;
    my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    my @b = (0, 0); my @t = ($dx * $len, $dy * $len);
    my @l = ($dx * $len * 0.38 + $nx * $hw, $dy * $len * 0.38 + $ny * $hw);
    my @rr = ($dx * $len * 0.38 - $nx * $hw, $dy * $len * 0.38 - $ny * $hw);
    my $lLit = lit($nx, $ny);
    poly($lLit ? $light : $dark, $tf->(@b), $tf->(@l), $tf->(@t));
    poly($lLit ? $dark : $light, $tf->(@b), $tf->(@rr), $tf->(@t));
    return $tf->(@t);
  };
  my @tips;
  push @tips, $petal->($rot + $_ * 72, $r, $r * 0.3, "c3", "c5") for 0 .. 4;          # outer star
  $petal->($rot + 36 + $_ * 72, $r * 0.6, $r * 0.22, "c2", "c5") for 0 .. 4;          # inner star
  # glowing pale centre
  my @c; for my $i (0 .. 9) { my ($dx, $dy) = dir($rot + 18 + $i * 36); my $rr = $i % 2 ? $r * 0.2 : $r * 0.27; push @c, $tf->($dx * $rr, $dy * $rr); }
  poly('c3', @c);
  my @d; for my $i (0 .. 5) { my ($dx, $dy) = dir($i * 60); push @d, $tf->($dx * $r * 0.09 + $r * 0.03, $dy * $r * 0.09 + $r * 0.03); }
  poly('c2', @d);
  if ($spark) {   # sparkles on fine filaments from each petal tip (attached, never floating)
    for my $i (0, 2, 3) {
      my $a = $rot + $i * 72 + 38; my ($dx, $dy) = dir($a);
      my $t = $tips[$i]; my $L = $r * 0.3;
      my ($ex, $ey) = ($t->[0] + $dx * $L, $t->[1] + $dy * $L * $sq);
      poly('c3', [$t->[0] - $dy * 1.3, $t->[1] + $dx * 1.3], [$ex, $ey], [$t->[0] + $dy * 1.3, $t->[1] - $dx * 1.3]);
      sparkle($ex, $ey, $r * 0.22, 0, "c3");
    }
  }
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

# A leaf rosette: $n lance leaves with seeded jitter.
sub rosette {
  my ($n, $len, $lenVar, $w, $bendMax, $seed, $start) = @_;
  srand($seed); my @b;
  for my $i (0 .. $n - 1) {
    my $a = ($start // -90) + $i * 360 / $n + rand(14) - 7;
    push @b, [$a, $len + rand($lenVar), (rand(1) < 0.5 ? -1 : 1) * $bendMax * (0.4 + rand(0.6))];
  }
  leaf(200, 200, $_->[0], $_->[1], $w, $_->[2], 'c2', 'c1') for sort { $b->[1] <=> $a->[1] } @b;
}

# 1. Seeds, front view: a little heap of pale crescent-moon seeds.
for ([138, 280, 175, 44], [212, 292, 30, 46], [272, 270, 205, 42], [176, 218, 150, 42], [246, 222, 15, 40], [206, 166, 185, 40]) { crescent(@$_, "c3", "c5"); }
write_svg('1-seeds-front.svg', 'Moonbloom seeds');

# 2. Just sown, top down: crescent seeds pressed into soil pockets.
my @sown = ([166, 168, 150], [240, 162, 30], [202, 212, 100], [150, 240, 200], [252, 238, -40]);
for (@sown) { soil($_->[0], $_->[1], 28, 23, int($_->[0] * 7 + $_->[1])); }
for (@sown) { crescent($_->[0], $_->[1], $_->[2], 24, "c3", "c5"); }
write_svg('2-sown.svg', 'Moonbloom just sown');

# 3. First growth: a small silvery seedling.
soil(200, 200, 34, 30, 3);
srand(31);
for my $i (0 .. 4) { my $a = -70 + $i * 72 + rand(10); leaf(200, 200, $a, 62 + rand(20), 22, (rand(1) < .5 ? -1 : 1) * 18, 'c2', 'c1'); }
sparkle(200, 200, 10, 0, "c3");
write_svg('3-first-growth.svg', 'Moonbloom first growth');

# 4. Second growth: a rosette of long silvery lance leaves.
soil(200, 200, 34, 30, 4);
rosette(9, 100, 26, 30, 30, 41);
for my $i (0 .. 3) { leaf(200, 200, -45 + $i * 90, 52, 22, 12, 'c2', 'c1'); }
sparkle(200, 200, 13, 0, "c3");
write_svg('4-second-growth.svg', 'Moonbloom second growth');

# 5. Third growth: bigger rosette and closed luminous buds on stems.
soil(200, 200, 34, 30, 5);
rosette(11, 128, 26, 32, 30, 51, -72);
for my $i (0 .. 4) {
  my $a = -90 + $i * 72 + ($i % 2 ? 8 : -6);
  my ($ex, $ey, $ea) = blade(200, 200, $a, 62, 7, 14, 'c2', 'c1');
  leaf($ex, $ey, $ea - 34, 18, 10, 0, 'c2', 'c1'); leaf($ex, $ey, $ea + 34, 18, 10, 0, 'c2', 'c1');
  bud($ex - 4 * cos(deg2rad($ea)), $ey - 4 * sin(deg2rad($ea)), $ea, 54, 30, 0, "c3", "c5");
}
write_svg('5-third-growth.svg', 'Moonbloom third growth');

# 6. Harvest: rosette crowned by open star blossoms with sparkles.
soil(200, 200, 34, 30, 6);
rosette(12, 138, 22, 32, 28, 61, -75);
for my $i (0 .. 4) {
  my $a = -90 + 36 + $i * 72; my ($dx, $dy) = dir($a);
  blade(200, 200, $a, 96, 7, 0, "c2", "c1");
  bloom(200 + $dx * 102, 200 + $dy * 102, 54, $a + 36, 1, 1);
}
bloom(200, 200, 60, -90, 1, 1);
write_svg('6-harvest.svg', 'Moonbloom ready to harvest');

# 7. Harvest, front view: the harvested produce, a little bouquet of three cut glowing blossoms tied at the stems.
my @bq = ([-118, 196, 12], [-90, 236, 0], [-62, 196, -12]);
for ([-130, 104, -20], [-50, 104, 20]) { leaf(200, 318, $_->[0], $_->[1],  34, $_->[2], 'c2', 'c1'); }
my @tops;
for my $s (@bq) {
  my ($a, $len, $bend) = @$s;
  my ($sx, $sy) = (200 - ($a + 90) * 0.45, 380);                     # cut stem ends below the tie
  my ($ex, $ey) = blade($sx, $sy, $a, $len, 12, $bend, 'c2', 'c1');
  push @tops, [$ex, $ey];
}
poly("c5", [170, 306], [230, 306], [233, 328], [167, 328]);          # ribbon tie
poly("c3", [170, 306], [230, 306], [229, 314], [171, 314]);
poly("c5", [194, 326], [172, 358], [186, 361], [200, 328]); poly("c3", [200, 326], [218, 358], [230, 353], [206, 326]);
bloom($tops[0][0], $tops[0][1], 72, -100, 0.8, 1);
bloom($tops[2][0], $tops[2][1], 72, -80, 0.8, 1);
bloom($tops[1][0], $tops[1][1], 80, -90, 0.8, 1);
write_svg('7-harvest-front.svg', 'Moonbloom harvest');

# 8. Dead (never watered): cracked dry soil, limp pale leaves and drooped shrivelled buds.
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
for my $i (0 .. 8) { push @dead, [-90 + $i * 40 + rand(16) - 8, 96 + rand(40), (rand(1) < 0.5 ? -1 : 1) * (50 + rand(40))]; }
shape(200, 200, $_->[0], $_->[1], 20, $_->[2], "c1", "c4", sub { my $t = shift; sin(pi * $t ** 0.7) ** 0.9 * (0.75 + 0.25 * sin($t * 23)) }) for sort { $b->[1] <=> $a->[1] } @dead;
for ([-20, 60, 70], [140, 54, -80]) {
  my ($ex, $ey, $ea) = blade(200, 200, $_->[0], $_->[1], 6, $_->[2], 'c3', 'c4');
  bud($ex, $ey, $ea, 30, 15, 40, "c5", "c4");
}
write_svg('8-dead.svg', 'Moonbloom died from lack of water');
print "wrote 8 files to $OUT\n";

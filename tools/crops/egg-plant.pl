# Egg Plant (silly fantasy crop: a bush that lays real hen's eggs): 8 stages.
# Run from C:/Claude/Cute Fox:  perl tools/crops/egg-plant.pl
# Then: perl tools/center.pl crops/egg-plant/1-seeds-front.svg crops/egg-plant/7-harvest-front.svg
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/egg-plant';
mkdir 'crops'; mkdir $OUT;
# c1 deep leaf green, c2 lit fresh green, c3 eggshell cream (eggs, hen-flower feathers, dried leaves),
# c4 warm brown (soil, egg shade, speckles, petal folds), c5 cockscomb red (the crinkled crest petals)
my %PAL = (c1 => '#3F7A3A', c2 => '#86C25A', c3 => '#FFF7E6', c4 => '#7A4C2E', c5 => '#E2472F');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Generic bent shape from (x,y) heading `ang`; $prof->(t) gives the half-width factor; split along the midrib.
sub shape {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $prof) = @_;
  my $n = 12; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * $prof->($t) + ($i == $n ? 0 : 0.5);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
  return ($px, $py, $a - $bend / $n);
}
sub blade { shape(@_[0 .. 7], sub { (1 - $_[0]) ** 0.85 }) }
sub stem  { shape(@_[0 .. 7], sub { 1 - 0.45 * $_[0] }) }
# Rounded ovate bush leaf (broad, soft tip).
sub leaf  { shape(@_[0 .. 7], sub { my $t = shift; $t < 0.06 ? 0.3 : sin(pi * $t ** 0.85) ** 0.62 }) }
# Pointed sepal of a nest cup.
sub sepal { shape(@_[0 .. 7], sub { my $t = shift; sin(pi * min(1, $t * 0.5 + 0.5)) ** 0.9 * (0.6 + 0.4 * sin(pi * $t)) }) }

# End point of a bent path.
sub walk {
  my ($x, $y, $ang, $len, $bend, $upto) = @_; $upto //= 1;
  my $n = 12; my $a = $ang;
  for my $i (1 .. int($n * $upto + 0.5)) { my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  return ($x, $y, $a);
}

# Crescent along the outline run facing (lx,ly), inner edge pulled toward (cx,cy).
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

# Egg outline: pointy end toward `ang`.
sub egg_pts {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  map { my $th = 2 * pi * $_ / 22; my $c = cos($th);
        my $u = $c * $len / 2 * ($c > 0 ? 1.07 : 0.95); my $v = sin($th) * $w / 2 * (1 - 0.22 * $c);
        [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v] } 0 .. 21;
}
# A faceted egg: body, soft shaded crescent at lower right, a second deeper sliver, glossy glint upper left.
# kind: 'w' cream-white, 'b' light brown, 'g' unripe green, 'q' speckled quail seed
sub egg {
  my ($x, $y, $ang, $len, $w, $kind, $seed) = @_;
  my %c = (w => ['c3', 'c4', 'c4', ''], g => ['c3', 'c2', 'c2', ''], q => ['c3', 'c4', 'c4', '']);
  my ($body, $sh, $sh2, $gl) = @{ $c{$kind} };
  my @o = egg_pts($x, $y, $ang, $len, $w);
  my $r = ($len + $w) / 4;
  poly($body, @o);
  # broad soft shade, then a narrow deep rim
  crescent($sh, \@o, $x, $y, 0.7071, 0.7071, -0.05, $x - $r * 0.55, $y - $r * 0.55, 0.80) if $kind ne 'w';
  if ($kind eq 'w') {   # white egg: a pale tan core shade, so the shell keeps reading white
    crescent('c4', \@o, $x, $y, 0.7071, 0.7071, 0.12, $x - $r * 0.7, $y - $r * 0.7, 0.9);
  }
  if ($kind eq 'q') {   # speckles on the quail-like seed
    srand($seed // 1);
    for my $s (0 .. 6) {
      my $px = $x + (rand(1) - 0.5) * $len * 0.7; my $py = $y + (rand(1) - 0.5) * $w * 0.7; my $sr = $r * (0.07 + rand(0.07));
      poly('c4', map { my ($ex, $ey) = dir($_ * 72 + $s * 13); [$px + $ex * $sr, $py + $ey * $sr * 0.8] } 0 .. 4);
    }
  }
  # glossy highlight: a small slanted lozenge toward the upper left
  if ($gl) {
    my ($gx, $gy) = ($x - $r * 0.38, $y - $r * 0.38);
    my ($ex, $ey) = dir(-135 + 90);
    poly($gl, [$gx - $ex * $r * 0.30, $gy - $ey * $r * 0.30], [$gx - $r * 0.07, $gy - $r * 0.12], [$gx + $ex * $r * 0.30, $gy + $ey * $r * 0.30], [$gx + $r * 0.06, $gy + $r * 0.07]);
  }
  return @o;
}

# A nest cup of leaves seen from above: pointed sepals radiating around an egg's position.
sub nestcup {
  my ($x, $y, $r, $rot, $n) = @_; $n //= 7;   # $r ~ egg length
  poly("c1", map { my ($dx, $dy) = dir($rot + $_ * 36); [$x + $r * 0.05 + $dx * $r * 0.6, $y + $r * 0.05 + $dy * $r * 0.6] } 0 .. 9);
  for my $i (0 .. $n - 1) { my $a = $rot + $i * 360 / $n; shape($x, $y, $a, $r * 0.78, $r * 0.4, 10, "c2", "c1", sub { my $t = shift; sin(pi * $t ** 0.75) ** 0.7 }); }
}

# Five-petal white blossom with a tan centre.
sub blossom {
  my ($x, $y, $r, $rot) = @_;
  for my $i (0 .. 4) { my $a = $rot + 36 + $i * 72; blade($x, $y, $a, $r * 0.75, $r * 0.3, 0, 'c2', 'c1'); }
  for my $i (0 .. 4) {
    my $a = $rot + $i * 72; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    my @p = map { my $t = $_ / 8; my $hw = $r * 0.42 * sin(pi * min(1, $t ** 0.8)) ** 0.55; } 0 .. 8;
    my (@l, @rr); for my $k (0 .. 8) { my $t = $k / 8; push @l, [$x + $dx * $r * $t + $nx * $p[$k], $y + $dy * $r * $t + $ny * $p[$k]]; push @rr, [$x + $dx * $r * $t - $nx * $p[$k], $y + $dy * $r * $t - $ny * $p[$k]]; }
    poly('c3', @l, reverse @rr);
    poly('c5', [$x + $dx * $r * 0.3, $y + $dy * $r * 0.3], [$x + $dx * $r * 0.62 + $nx * 1.3, $y + $dy * $r * 0.62 + $ny * 1.3], [$x + $dx * $r * 0.62 - $nx * 1.3, $y + $dy * $r * 0.62 - $ny * 1.3]);
  }
  poly('c5', map { my ($dx, $dy) = dir($rot + $_ * 60); [$x + $dx * $r * 0.24, $y + $dy * $r * 0.24] } 0 .. 5);
  poly('c4', map { my ($dx, $dy) = dir($rot + 30 + $_ * 120); [$x + $r * 0.03 + $dx * $r * 0.1, $y + $r * 0.03 + $dy * $r * 0.1] } 0 .. 2);
}

# Hen flower: a cupped, lopsided cream bloom of soft feather-tipped petals, plumper on one side, with a small
# crinkled red celosia-like crest on top and two upturned petals on the other side. It should read as a flower
# first; the hen only shows on a second look. $f = +1: plump side / crest toward the right.
sub feather_petal {
  my ($x, $y, $ang, $len, $w, $bend, $plain) = @_;
  my $prof = sub { my $t = shift; my $b = sin(pi * min(1, $t ** 0.7)) ** 0.6; $t > 0.82 ? $b * (1 - 0.35 * sin(pi * ($t - 0.82) / 0.18 * 2) ** 2) : $b };
  my $n = 12; my (@mid, @l, @r); my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) { my $t = $i / $n; my ($dx, $dy) = dir($a); my $hw = $w / 2 * $prof->($t);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n; }
  poly('c3', @l, reverse @r);
  # soft fold along the midrib, darker on petals facing away from the light
  my ($dx, $dy) = dir($ang); my $away = ($dx + $dy) > 0.3;
  return if $plain || !$away;
  my @c = @mid[2 .. 8]; my $cw = 1.5;
  poly('c4', (map { [$_->[0] - $dy * $cw, $_->[1] + $dx * $cw] } @c), (map { [$_->[0] + $dy * $cw * 0.2, $_->[1] - $dx * $cw * 0.2] } reverse @c));
}
sub henflower {
  my ($x, $y, $s, $f) = @_; $f //= 1;
  my $body = $f > 0 ? 70 : 110;                    # the plump side
  my $tail = $f > 0 ? -150 : -30;                  # two upturned petals on the other side
  my $head = $f > 0 ? -45 : -135;                  # where the crest sits
  for my $k (0 .. 5) { blade($x, $y, $k * 60 + 30, $s * 1.15, $s * 0.42, 8, 'c2', 'c1'); }        # sepals
  # outer ring of petals, longer and fuller toward the plump side
  my @ring;
  for my $k (0 .. 9) {
    my $a = $k * 36 + 9; my $c = cos(deg2rad($a - $body));
    push @ring, [$a, $s * (0.86 + 0.4 * $c), $s * (0.62 + 0.2 * $c)];
  }
  feather_petal($x, $y, $_->[0], $_->[1], $_->[2], 0) for sort { $a->[1] <=> $b->[1] } @ring;
  for my $k (0, 1) {                                # the upturned "tail" petals
    feather_petal($x, $y, $tail + $k * 26 * $f, $s * (1.3 - $k * 0.18), $s * 0.42, $f * 34);
  }
  # inner cup of shorter petals
  for my $k (0 .. 5) { my $a = $k * 60 + 30; my $c = cos(deg2rad($a - $body)); feather_petal($x, $y, $a, $s * (0.55 + 0.15 * $c), $s * 0.5, 0, 1); }
  # green heart
  poly('c1', map { my ($dx, $dy) = dir($_ * 60); [$x + $dx * $s * 0.13, $y + $dy * $s * 0.13] } 0 .. 5);
  poly('c2', map { my ($dx, $dy) = dir($_ * 120 + 200); [$x - $s * 0.03 + $dx * $s * 0.07, $y - $s * 0.03 + $dy * $s * 0.07] } 0 .. 2);
  # small crinkled red crest: a tight frill of lobes rising off-centre toward the top
  my ($hx, $hy) = dir($head);
  my ($cx, $cy) = ($x + $hx * $s * 0.62, $y + $hy * $s * 0.62);
  for my $k (-1 .. 1) {
    my ($ux, $uy) = dir($head + 90); my $lx = $cx + $ux * $k * $s * 0.17 + $hx * (1 - abs($k)) * $s * 0.06; my $ly = $cy + $uy * $k * $s * 0.17 + $hy * (1 - abs($k)) * $s * 0.06;
    my $r = $s * ($k ? 0.17 : 0.22);
    poly('c5', map { my ($ex, $ey) = dir($_ * 40 + $k * 13); my $q = $r * ($_ % 2 ? 0.72 : 1.0); [$lx + $ex * $q, $ly + $ey * $q] } 0 .. 8);
  }
}

# Contact shadow: a thin sliver just outside an egg's upper-left edge, so a white egg separates from a white egg behind it.
sub occlude {
  my ($x, $y, $ang, $len, $w) = @_;
  my @o = egg_pts($x, $y, $ang, $len, $w);
  my @idx = grep { my ($ox, $oy) = ($o[$_][0] - $x, $o[$_][1] - $y); (-0.9 * $ox - 0.2 * $oy) > 0.45 * sqrt($ox * $ox + $oy * $oy) && $o[$_][1] > $y - $len * 0.38 } 0 .. $#o;
  my @run = map { $o[$_] } @idx;
  return if @run < 3;
  my @out = map { [$x + ($_->[0] - $x) * 1.08, $y + ($_->[1] - $y) * 1.08] } @run;
  poly('c4', @out, reverse @run);
}
# A small closed hen bud: a white feathery bud with a red comb tip.
sub henbud {
  my ($x, $y, $s, $ang) = @_;
  my ($dx, $dy) = dir($ang);
  for my $a (-40, 40) { blade($x, $y, $ang + 180 + $a, $s * 0.7, $s * 0.4, 0, 'c2', 'c1'); }
  shape($x, $y, $ang, $s * 1.4, $s * 0.95, 0, 'c3', 'c4', sub { my $t = shift; sin(pi * $t ** 0.75) ** 0.6 * (1 - 0.15 * $t) });
  my ($tx, $ty) = ($x + $dx * $s * 1.25, $y + $dy * $s * 1.25);
  poly('c5', map { my $th = 2 * pi * $_ / 7; [$tx + cos($th) * $s * 0.28, $ty + sin($th) * $s * 0.28] } 0 .. 6);
}
# A wilted comb petal (stage 6 leftovers): a small crumpled red lobe.
sub combpetal {
  my ($x, $y, $s, $rot) = @_;
  poly('c5', map { my ($dx, $dy) = dir($rot + $_ * 51); my $q = $s * ($_ % 2 ? 0.6 : 1.0); [$x + $dx * $q, $y + $dy * $q * 0.7] } 0 .. 6);
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

# A leafy twig seen from above: a stem with alternating rounded leaves and a terminal leaf.
sub twig {
  my ($x, $y, $ang, $len, $lsz, $bend, $pairs, $light, $dark) = @_;
  $light //= 'c2'; $dark //= 'c1';
  my ($ex, $ey, $ea) = walk($x, $y, $ang, $len, $bend);
  for my $k (reverse 1 .. $pairs) {
    my $t = 0.35 + 0.5 * ($k - 1) / max(1, $pairs - 1);
    my ($px, $py, $pa) = walk($x, $y, $ang, $len, $bend, $t);
    my $ll = $lsz * (1.05 - 0.25 * $t);
    for my $side (-1, 1) { leaf($px, $py, $pa + $side * 52, $ll, $ll * 0.62, $side * 12, $light, $dark); }
  }
  stem($x, $y, $ang, $len, 5, $bend, $light, $dark);
  leaf($ex, $ey, $ea, $lsz * 1.1, $lsz * 0.7, $bend * 0.3, $light, $dark);
}
sub bush {
  my ($n, $len, $lenVar, $lsz, $bendMax, $pairs, $seed, $start) = @_;
  srand($seed); my @b;
  for my $i (0 .. $n - 1) {
    my $a = ($start // -90) + $i * 360 / $n + rand(16) - 8;
    push @b, [$a, $len + rand($lenVar), (rand(1) < 0.5 ? -1 : 1) * $bendMax * (0.4 + rand(0.6))];
  }
  for (sort { $b->[1] <=> $a->[1] } @b) { my ($a, $l, $bend) = @$_; my ($dx, $dy) = dir($a); twig(200 + $dx * 4, 200 + $dy * 4, $a, $l, $lsz, $bend, $pairs); }
}

# An egg in its nest cup at the end of a short stalk from the bush centre (top down).
sub egg_on_stalk {
  my ($ang, $dist, $len, $w, $kind, $cupr, $seed) = @_;
  my ($dx, $dy) = dir($ang);
  my ($x, $y) = (200 + $dx * $dist, 200 + $dy * $dist);
  stem(200 + $dx * 10, 200 + $dy * 10, $ang, $dist - 10, 6, 0, 'c2', 'c1');
  nestcup($x, $y, $len, $ang + 25, 7);
  egg($x, $y, $ang + ($seed % 2 ? 18 : -14), $len, $w, $kind, $seed);
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a small heap of tiny speckled quail-egg-like seeds.
{
  my @s = ([136, 290, -100, 0], [200, 296, -84, 0], [264, 290, -70, 0], [168, 240, -108, 0], [232, 240, -76, 0], [200, 190, -92, 0]);
  my $i = 0; egg($_->[0], $_->[1], $_->[2], 66, 52, 'q', 11 + $i++) for @s;
}
write_svg('1-seeds-front.svg', 'Egg Plant seeds');

# 2. Just sown, top down: speckled seeds pressed into soil pockets.
my @sown = ([166, 168, -30], [240, 162, 40], [202, 212, 95], [150, 240, 150], [252, 238, -60]);
for (@sown) { soil($_->[0], $_->[1], 30, 25, int($_->[0] * 7 + $_->[1])); }
{ my $i = 0; for (@sown) { egg($_->[0], $_->[1], $_->[2], 34, 26, 'q', 21 + $i++); } }
write_svg('2-sown.svg', 'Egg Plant just sown');

# 3. First growth: two round seed leaves and a first pair of true leaves.
soil(200, 200, 34, 30, 3);
leaf(200, 200, 200, 66, 44, -8, 'c2', 'c1');
leaf(200, 200, 20, 66, 44, -8, 'c2', 'c1');
leaf(200, 200, -82, 58, 36, 10, 'c2', 'c1');
leaf(200, 200, 100, 50, 32, -10, 'c2', 'c1');
write_svg('3-first-growth.svg', 'Egg Plant first growth');

# 4. Second growth: a young bush of rounded leafy twigs, the first little hen buds peeking out.
soil(200, 200, 34, 30, 4);
bush(7, 76, 18, 48, 20, 2, 41, -70);
bush(4, 36, 8, 44, 10, 1, 42, -25);
for ([-60, 58], [150, 54]) { my ($a, $d) = @$_; my ($dx, $dy) = dir($a); stem(200, 200, $a, $d - 6, 5, 0, "c2", "c1"); henbud(200 + $dx * ($d - 8), 200 + $dy * ($d - 8), 17, $a); }
write_svg("4-second-growth.svg", "Egg Plant second growth");

# 5. Third growth: fuller bush crowned by hen flowers (feathery white cups with a red cockscomb crest).
soil(200, 200, 34, 30, 5);
bush(10, 96, 20, 50, 24, 2, 51, -80);
bush(5, 48, 10, 46, 14, 1, 52, -40);
my @hens = ([-60, 100, 1], [12, 108, -1], [92, 100, 1], [166, 106, -1], [238, 100, 1]);
for (@hens) { my ($a, $d) = @$_; stem(200, 200, $a, $d, 6, 0, "c2", "c1"); }
for (sort { sin(deg2rad($a->[0])) <=> sin(deg2rad($b->[0])) } @hens) { my ($a, $d, $fc) = @$_; my ($dx, $dy) = dir($a); henflower(200 + $dx * $d, 200 + $dy * $d, 34, $fc); }
henbud(200, 196, 14, -100);
write_svg("5-third-growth.svg", "Egg Plant third growth");

# 6. Harvest: the eggs sit where the hen flowers were, in leafy nest cups, a few wilting comb petals left.
soil(200, 200, 34, 30, 6);
bush(12, 112, 24, 54, 26, 2, 61, -85);
bush(6, 58, 12, 48, 16, 1, 62, -60);
for ([-60, 104, 74, 56], [12, 112, 70, 54], [92, 106, 74, 56], [166, 112, 70, 54], [238, 106, 70, 54]) {
  my ($a, $d, $l, $w) = @$_; my ($dx, $dy) = dir($a);
  egg_on_stalk($a, $d, $l, $w, "w", 30, int($a + 400));
  my ($nx, $ny) = (-$dy, $dx);
  combpetal(200 + $dx * ($d + 6) + $nx * 36, 200 + $dy * ($d + 6) + $ny * 36, 7, $a);
}
combpetal(250, 226, 6, 30); combpetal(160, 242, 6, 80);
nestcup(198, 198, 66, 10, 7);
egg(198, 198, -70, 66, 50, "w", 6);
write_svg("6-harvest.svg", "Egg Plant ready to harvest");

# 7. Harvest, front view: three fresh eggs resting in a little leafy nest cup.
{
  # back leaves of the cup rising behind the eggs
  for my $a (-158, -134, -46, -22) { leaf(200, 300, $a, 196, 72, $a < -90 ? -14 : 14, "c2", "c1"); }
  for my $a (-108, -72) { leaf(200, 290, $a, 214, 64, $a < -90 ? -10 : 10, "c2", "c1"); }
  egg(204, 186, -88, 132, 96, "w", 7);
  egg(148, 236, -110, 126, 90, "w", 8);
  occlude(258, 240, -68, 126, 90);   # soft contact shadow where it rests against the back egg
  egg(258, 240, -68, 126, 90, "w", 9);
  # front leaves of the cup, overlapping the egg bottoms
  for my $a (176, 150, 30, 4) { leaf(200, 312, $a, 128, 58, $a > 90 ? 14 : -14, 'c2', 'c1'); }
  for my $a (126, 54) { leaf(200, 318, $a, 82, 54, 0, 'c2', 'c1'); }
  leaf(200, 300, 90, 52, 40, 0, 'c2', 'c1');
  stem(200, 330, 96, 36, 10, 6, 'c2', 'c1');
}
write_svg('7-harvest-front.svg', 'Harvested eggs in a leaf cup');

# 8. Dead (never watered): cracked dry soil, a collapsed bush of curled straw leaves and an empty broken shell.
soil(200, 200, 66, 56, 8);
cracks(8, 83, 12, 'c3');
srand(81);
for my $i (0 .. 7) {
  my $a = -80 + $i * 45 + rand(16) - 8; my ($dx, $dy) = dir($a);
  my $l = 80 + rand(36); my $bend = (rand(1) < 0.5 ? -1 : 1) * (30 + rand(35));
  my ($ex, $ey, $ea) = stem(200 + $dx * 4, 200 + $dy * 4, $a, $l, 6.5, $bend, "c3", "c4");
  for my $t (0.35, 0.7) {
    my ($px, $py, $pa) = walk(200, 200, $a, $l, $bend, $t);
    shape($px, $py, $pa + ($t < 0.6 ? 70 : -70), 54, 26, $bend * 0.6, 'c3', 'c4', sub { my $t = shift; sin(pi * $t ** 0.8) ** 0.8 * (0.7 + 0.3 * sin($t * 19)) });
  }
  shape($ex, $ey, $ea, 50, 24, $bend * 0.5, 'c3', 'c4', sub { my $t = shift; sin(pi * $t ** 0.8) ** 0.8 * (0.7 + 0.3 * sin($t * 17)) });
}
# an empty, broken-open shell lying on the soil (seen from above: thin lit rim, hollow inside) and a fragment
{
  my ($x, $y, $ang, $L, $W) = (246, 246, -40, 64, 48);
  my @o = egg_pts($x, $y, $ang, $L, $W);
  poly('c3', @o);
  crescent('c4', \@o, $x, $y, 0.7071, 0.7071, 0.1, $x - 22, $y - 22, 0.9);
  srand(5);
  my @in = map { my $k = 0.78 + ($_ % 2 ? -0.07 : 0.04) + rand(0.04); [$x - 2 + ($o[$_][0] - $x) * $k, $y - 2 + ($o[$_][1] - $y) * $k] } 0 .. $#o;
  poly('c4', @in);
  my ($fx, $fy) = (292, 222);                          # a loose curved shell fragment
  poly('c3', [$fx - 12, $fy - 6], [$fx + 2, $fy - 12], [$fx + 14, $fy - 4], [$fx + 9, $fy + 2], [$fx + 1, $fy - 3], [$fx - 9, $fy + 3]);
  poly('c4', [$fx + 14, $fy - 4], [$fx + 9, $fy + 2], [$fx + 1, $fy - 3], [$fx + 4, $fy - 6]);
}
write_svg('8-dead.svg', 'Egg Plant died from lack of water');
print "wrote 8 files to $OUT\n";

# Pea crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/peas.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# A climbing pea vine seen from above: stems with paired round leaflets, curling tendrils,
# white pea flowers, then plump bright pods.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/peas';
mkdir 'crops'; mkdir $OUT;
# c1 shaded blue-green (glaucous pea foliage, pod shade), c2 lit blue-green, c3 cream (white flowers,
# gloss, dry leaves), c4 soil brown, c5 bright pea green (pods and peas)
my %PAL = (c1 => '#3D6E4E', c2 => '#82B888', c3 => '#F4E7BE', c4 => '#5A3A22', c5 => '#9CCB3B');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Bent shape from (x,y) heading `ang`; profile gives the half-width factor for t in 0..1.
# Returns end point, end angle, lit flag and the midline / outlines.
sub shape2 {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $pl, $pr, $n) = @_;
  $n //= 14; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hl = $w / 2 * $pl->($t) + ($i == $n ? 0 : 0.4);
    my $hr = $w / 2 * $pr->($t) + ($i == $n ? 0 : 0.4);
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

# Point along a bent path (same stepping as shape2 with n steps).
sub walk {
  my ($x, $y, $ang, $len, $bend, $upto, $n) = @_; $n //= 10; $upto //= 1;
  for my $i (1 .. int($n * $upto + 0.5)) { my ($dx, $dy) = dir($ang); $x += $dx * $len / $n; $y += $dy * $len / $n; $ang += $bend / $n; }
  return ($x, $y, $ang);
}

# Round pea leaflet: a soft oval split along its midrib.
our $DRY = 0;
sub leaflet {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark) = @_;
  shape2($x, $y, $ang, $len, $w * ($DRY ? 0.6 : 1), $bend, $light // 'c2', $dark // 'c1',
    (sub { my $t = shift; my $b = sin(pi * $t ** 0.85) ** 0.6; $DRY ? $b * (0.7 + 0.3 * abs(sin($t * 11))) : $b }) x 2, 12);
}

# A tendril: a thin stalk winding into a tightening spiral.
sub tendril {
  my ($x, $y, $ang, $len, $turn, $cls1, $cls2) = @_;
  my $n = 22; my (@l, @r); my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a); my $hw = 1.6 * (1 - 0.6 * $t) + 0.3;
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $turn * (0.2 + 2.6 * $t ** 1.6) / $n;
  }
  poly($cls1 // 'c1', @l, reverse @r);
}

# A pea leaf from the stem: short petiole, a big leafy stipule pair, $np pairs of round leaflets, tendrils at the tip.
sub pleaf {
  my ($x, $y, $ang, $len, $np, $bend, $light, $dark) = @_;
  $light //= 'c2'; $dark //= 'c1';
  # stipules: two broad leafy ears hugging the stem
  leaflet($x, $y, $ang - 62, $len * 0.4, $len * 0.3, 20, $light, $dark);
  leaflet($x, $y, $ang + 62, $len * 0.4, $len * 0.3, -20, $light, $dark);
  my ($ex, $ey, $ea) = walk($x, $y, $ang, $len, $bend);
  for my $k (reverse 1 .. $np) {
    my $t = 0.3 + 0.55 * ($k - 1) / max(1, $np - 1); $t = 0.55 if $np == 1;
    my ($px, $py, $pa) = walk($x, $y, $ang, $len, $bend, $t);
    my $ll = $len * (0.62 - 0.08 * $t);
    leaflet($px, $py, $pa + $_ * 50, $ll, $ll * 0.74, $_ * 8, $light, $dark) for (-1, 1);
  }
  blade($x, $y, $ang, $len * 0.92, 3.2, $bend, $light, $dark, 0.5);
  unless ($DRY) {
    tendril($ex, $ey, $ea - 20, $len * 0.5, 300, $dark);
    tendril($ex, $ey, $ea + 25, $len * 0.42, -320, $dark);
  }
}

# One vine stem crawling out from the centre, with alternating pea leaves at its nodes and a tendril tip.
sub vine {
  my ($x, $y, $ang, $len, $bend, $nodes, $leaf, $np) = @_;
  my @nodes;
  for my $k (1 .. $nodes) {
    my $t = $k / ($nodes + 0.6);
    my ($px, $py, $pa) = walk($x, $y, $ang, $len, $bend, $t, 20);
    push @nodes, [$px, $py, $pa, ($k % 2 ? 1 : -1)];
  }
  blade($x, $y, $ang, $len, 4.5, $bend, 'c2', 'c1', 0.5) unless $DRY;
  blade($x, $y, $ang, $len, 4, $bend, 'c3', 'c4', 0.5) if $DRY;
  my @ret;
  for my $nd (@nodes) {
    my ($px, $py, $pa, $s) = @$nd;
    pleaf($px, $py, $pa + $s * 48, $leaf * (0.75 + 0.25 * rand(1)), $np, -$s * 14, $DRY ? ('c3', 'c4') : ());
    push @ret, [$px, $py, $pa, $s];
  }
  my ($ex, $ey, $ea) = walk($x, $y, $ang, $len, $bend, 1, 20);
  tendril($ex, $ey, $ea, $leaf * 0.5, ($bend > 0 ? 1 : -1) * 320, 'c1') unless $DRY;
  return @ret;
}

# White pea flower seen from above: a broad round standard petal, two wing petals, a green calyx.
sub flower {
  my ($x, $y, $r, $ang) = @_;
  my ($dx, $dy) = dir($ang);
  blade($x - $dx * $r * 0.5, $y - $dy * $r * 0.5, $ang + 180, $r * 0.7, $r * 0.34, 0, 'c2', 'c1');      # calyx / stalk
  for my $s (-1, 1) { shape2($x, $y, $ang + $s * 38, $r * 0.85, $r * 0.7, -$s * 10, 'c3', 'c2', (sub { sin(pi * $_[0] ** 0.8) ** 0.55 }) x 2, 10); }
  my @p; for my $i (0 .. 12) { my ($cx, $cy) = dir($ang - 100 + $i * 200 / 12); push @p, [$x + $dx * $r * 0.25 + $cx * $r * 0.82, $y + $dy * $r * 0.25 + $cy * $r * 0.82]; }
  poly('c3', [$x - $dx * $r * 0.1, $y - $dy * $r * 0.1], @p);                        # standard petal
  my ($nx, $ny) = (-$dy, $dx);
  poly('c2', [$x - $dx * $r * 0.05, $y - $dy * $r * 0.05], [$x + $dx * $r * 0.55 + $nx * $r * 0.08, $y + $dy * $r * 0.55 + $ny * $r * 0.08],
             [$x + $dx * $r * 0.55 - $nx * $r * 0.08, $y + $dy * $r * 0.55 - $ny * $r * 0.08]);   # fold of the petal
}

# A round pea: bright green ball, shaded lower right, small cream glint.
sub pea {
  my ($x, $y, $r, $dry) = @_; my @o;
  for my $i (0 .. 15) { my $th = 2 * pi * $i / 16 + 0.2; my $k = $dry ? 0.95 + 0.05 * sin($i * 2.7) : 1; push @o, [$x + cos($th) * $r * $k, $y + sin($th) * $r * $k]; }
  poly('c5', @o);
  my ($cx, $cy) = ($x - $r * 0.3, $y - $r * 0.3);
  my @sh = grep { ($_->[0] - $x) + ($_->[1] - $y) > $r * 0.15 } @o;
  # keep the crescent contiguous: rotate so it starts right after a gap
  my @idx = grep { ($o[$_][0] - $x) + ($o[$_][1] - $y) > $r * 0.15 } 0 .. 15;
  my $st = (grep { my $p = ($_ - 1) % 16; !grep { $_ == $p } @idx } @idx)[0] // $idx[0];
  my @arc; for my $j (0 .. 15) { my $i = ($st + $j) % 16; last unless grep { $_ == $i } @idx; push @arc, $o[$i]; }
  poly('c1', @arc, reverse map { [$cx + ($_->[0] - $cx) * 0.76, $cy + ($_->[1] - $cy) * 0.76] } @arc);
  my $g = $r * 0.22;
  poly('c3', map { my ($c, $s) = dir($_ * 72 + 20); [$x - $r * 0.38 + $c * $g, $y - $r * 0.38 + $s * $g] } 0 .. 4) unless $dry;
}

# A pea pod: plump, slightly curved, bumps along the edge where the peas sit, beaked tip, green calyx and stalk.
# $open: split along its seam, the two shell halves spread apart with a row of peas inside.
sub pod {
  my ($x, $y, $ang, $len, $w, $bend, %o) = @_;
  my $np = $o{peas} // 6; my $body = $o{body} // 'c5'; my $shade = $o{shade} // 'c1'; my $hi = $o{hi} // 'c3';
  my $prof = sub { my $t = shift; my $b = $t < 0.15 ? sin(pi / 2 * $t / 0.15) ** 0.7 * 0.85 + 0.12 : $t > 0.76 ? sqrt(max(0, 1 - (($t - 0.76) / 0.24) ** 1.7)) : 1;
    my $bump = ($t > 0.1 && $t < 0.88) ? 1 + ($o{flat} ? 0.03 : 0.09) * abs(sin(pi * $np * ($t - 0.1) / 0.78)) : 1;
    $b * $bump * (1 - 0.15 * $t) };
  my ($dx, $dy) = dir($ang);
  blade($x - $dx * 2, $y - $dy * 2, $ang + 180 + ($o{sb} // 15), $o{stalk} // $len * 0.2, $w * 0.16, $o{sbend} // 20, 'c2', 'c1', 0.7);   # stalk
  if ($o{open}) {
    # split open, seen from above: the shell spread wide, pale lining, a row of peas along the seam
    my ($ex, $ey, $ea, $leftLit, $mid, $l, $r) = shape2($x, $y, $ang, $len, $w * 1.3, $bend, undef, undef, $prof, $prof, 24);
    poly($body, @$l, reverse @$r);
    my $sh = $leftLit ? $r : $l;
    poly($shade, @$sh, reverse map { [$mid->[$_][0] + ($sh->[$_][0] - $mid->[$_][0]) * 0.78, $mid->[$_][1] + ($sh->[$_][1] - $mid->[$_][1]) * 0.78] } 0 .. $#$mid);
    my $in = sub { my ($side, $k) = @_; map { [$mid->[$_][0] + ($side->[$_][0] - $mid->[$_][0]) * $k, $mid->[$_][1] + ($side->[$_][1] - $mid->[$_][1]) * $k] } 0 .. $#$mid };
    my @a = $in->($l, 0.66); my @b = $in->($r, 0.66);
    poly('c2', @a[1 .. $#a - 1], reverse @b[1 .. $#b - 1]);                      # pale inner lining
    my @c = $in->($sh, 0.66);
    poly('c1', @c[1 .. $#c - 1], reverse map { [$_->[0] * 0.55 + $_->[2] * 0.45, $_->[1] * 0.55 + $_->[3] * 0.45] } map { [@{$c[$_]}, @{$mid->[$_]}] } 1 .. $#c - 1);   # lining in shadow
    for my $k (0 .. $np - 1) {
      my $t = 0.18 + 0.64 * $k / max(1, $np - 1);
      my ($px, $py) = walk($x, $y, $ang, $len, $bend, $t, 24);
      pea($px, $py, $w * 0.36 * (1 - 0.25 * abs($t - 0.5) * 2));
    }
  } else {
    my ($ex, $ey, $ea, $leftLit, $mid, $l, $r) = shape2($x, $y, $ang, $len, $w, $bend, undef, undef, $prof, $prof, 24);
    poly($body, @$l, reverse @$r);
    my $sh = $leftLit ? $r : $l; my $li = $leftLit ? $l : $r;
    poly($shade, @$sh, reverse map { [$mid->[$_][0] + ($sh->[$_][0] - $mid->[$_][0]) * 0.45, $mid->[$_][1] + ($sh->[$_][1] - $mid->[$_][1]) * 0.45] } 0 .. $#$mid);
    # seam line along the lit edge, and a glint
    my $n = $#$mid;
    my @ga = map { my $k = 0.5; [$mid->[$_][0] + ($li->[$_][0] - $mid->[$_][0]) * $k, $mid->[$_][1] + ($li->[$_][1] - $mid->[$_][1]) * $k] } int($n * 0.22) .. int($n * 0.7);
    my @gb = map { my $k = 0.72; [$mid->[$_][0] + ($li->[$_][0] - $mid->[$_][0]) * $k, $mid->[$_][1] + ($li->[$_][1] - $mid->[$_][1]) * $k] } int($n * 0.22) .. int($n * 0.7);
    poly($hi, @ga, reverse @gb) unless $o{nohi};
    # pea bumps hint: small shaded dimples between the peas on the shaded half
    for my $k (1 .. $np - 1) {
      my $i = int($n * (0.1 + 0.78 * $k / $np) + 0.5);
      my $p = $sh->[$i]; my $q = $mid->[$i];
      poly($hi, [$p->[0] * 0.5 + $q->[0] * 0.5, $p->[1] * 0.5 + $q->[1] * 0.5], [$p->[0] * 0.75 + $q->[0] * 0.25, $p->[1] * 0.75 + $q->[1] * 0.25], [$sh->[$i + 1][0] * 0.62 + $mid->[$i + 1][0] * 0.38, $sh->[$i + 1][1] * 0.62 + $mid->[$i + 1][1] * 0.38]) if 0;
    }
  }
  # calyx: a small green star where the pod meets its stalk
  for my $s (-1, 0, 1) { blade($x, $y, $ang + $s * 34, $w * 0.62, $w * 0.24, -$s * 10, 'c2', 'c1'); }
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

# A tangle of vines radiating from the centre; returns all node positions.
sub tangle {
  my ($nv, $len, $leaf, $nodes, $np, $seed, $start) = @_;
  srand($seed); my @v;
  for my $i (0 .. $nv - 1) {
    my $a = ($start // -90) + $i * 360 / $nv + rand(20) - 10;
    push @v, [$a, $len * (0.85 + rand(0.2)), (rand(1) < 0.5 ? -1 : 1) * (30 + rand(40))];
  }
  my @all;
  for (@v) { my ($a, $l, $b) = @$_; my ($dx, $dy) = dir($a); push @all, vine(200 + $dx * 4, 200 + $dy * 4, $a, $l, $b, $nodes, $leaf, $np); }
  return @all;
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a little heap of dried, slightly wrinkled seed peas.
for my $s ([128, 302, 23], [176, 308, 24], [226, 308, 24], [274, 300, 23], [152, 262, 24], [202, 266, 25], [250, 260, 24],
           [176, 222, 24], [226, 220, 24], [202, 182, 24]) { pea($s->[0], $s->[1], $s->[2], 1); }
write_svg('1-seeds-front.svg', 'Seed peas');

# 2. Just sown, top down: peas pressed into small soil pockets.
my @sown = ([170, 170], [236, 168], [168, 236], [234, 234]);
for (@sown) { soil($_->[0], $_->[1], 28, 24, int($_->[0] * 7 + $_->[1])); }
for (@sown) { pea($_->[0] - 2, $_->[1] + 2, 11, 1); }
write_svg('2-sown.svg', 'Peas just sown');

# 3. First growth, top down: a young shoot with its first leaflets and a tendril.
soil(200, 200, 34, 30, 3);
srand(31);
vine(200, 200, -60, 92, 30, 2, 56, 1);
vine(200, 200, 130, 66, -24, 1, 50, 1);
write_svg('3-first-growth.svg', 'Peas first growth');

# 4. Second growth, top down: several vines with paired leaflets and curling tendrils.
soil(200, 200, 34, 30, 4);
tangle(4, 118, 64, 2, 1, 41, -70);
write_svg('4-second-growth.svg', 'Peas second growth');

# 5. Third growth, top down: a full tangle of vines with white pea flowers.
soil(200, 200, 34, 30, 5);
my @n5 = tangle(6, 132, 70, 3, 1, 51, -80);
for my $i (0 .. $#n5) {
  next unless $i % 2 == 1;
  my ($x, $y, $a, $s) = @{$n5[$i]}; my ($fx, $fy) = dir($a - $s * 60);
  flower($x + $fx * 20, $y + $fy * 20, 19, $a - $s * 60);
}
write_svg('5-third-growth.svg', 'Peas third growth');

# 6. Harvest, top down: lush vines hung with plump bright pods.
soil(200, 200, 34, 30, 6);
my @n6 = tangle(7, 136, 68, 3, 1, 61, -84);
for my $i (0 .. $#n6) {
  my ($x, $y, $a, $s) = @{$n6[$i]};
  my $v = int($i / 3); my $k = $i % 3;
  next if $k == 0 && $v % 3;
  next if $k == 2 && $v % 2;
  my $pa = $a - $s * 70;
  if ($k == 0) { flower($x + cos(deg2rad($pa)) * 18, $y + sin(deg2rad($pa)) * 18, 18, $pa); next; }
  pod($x, $y, $pa, 82, 27, -$s * 18, stalk => 8);
}
write_svg('6-harvest.svg', 'Peas ready to harvest');

# 7. Harvested produce, front view: two plump pods and one split open showing its row of peas.
pod(96, 132, 16, 214, 50, 10, stalk => 30, sbend => -30, peas => 6);
pod(104, 186, 4, 222, 52, 8, stalk => 32, sbend => -30, peas => 6);
pod(88, 262, -6, 236, 56, 12, stalk => 34, sbend => -30, peas => 6, open => 1);
write_svg('7-harvest-front.svg', 'Harvested pea pods');

# 8. Dead (never watered), top down: cracked dry soil, collapsed straw-dry vines, shrivelled leaflets.
soil(200, 200, 62, 54, 8);
cracks(8, 83, 11, 'c3');
$DRY = 1;
tangle(5, 118, 56, 3, 1, 81, -60);
pod(236, 236, 30, 44, 15, 24, body => 'c3', shade => 'c4', nohi => 1, flat => 1, stalk => 8);
write_svg('8-dead.svg', 'Peas died from lack of water');
print "wrote 8 files to $OUT\n";

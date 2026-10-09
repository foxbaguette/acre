# Cacao (Cocoa Bean) crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/cacao.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Signature: big ribbed rugby-ball pods hanging straight off the trunk and thick branches (cauliflory),
# large drooping glossy leaves with drip tips, bronze young flushes, tiny pink-white trunk flowers.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/cacao';
mkdir 'crops'; mkdir $OUT;
# c1 leaf green, c2 lit green, c3 cream (pulp, flowers, gloss, dried leaves), c4 dark cocoa brown (soil, shade,
# bark, bean), c5 ripe pod orange (pods, bronze flush, lit side of beans and bark)
my %PAL = (c1 => '#2F6A34', c2 => '#6FAE4A', c3 => '#F6E6C8', c4 => '#47231F', c5 => '#B3402E');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub ell { my ($x, $y, $rx, $ry, $n, $rot) = @_; $rot //= 0; map { my ($u, $v) = dir($rot + $_ * 360 / $n); [$x + $u * $rx, $y + $v * $ry] } 0 .. $n - 1 }

# A tapered stalk / branch from (x,y) heading `ang`, bending `bend` degrees. $tipw = width kept at the end (0..1).
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $tipw) = @_;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $t * (1 - ($tipw // 0))) + 0.5;
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py];
    last if $i == $n;
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
  return ($px, $py, $a);
}

# Point and heading at fraction $t along a bent path (same stepping as blade).
sub walk {
  my ($x, $y, $ang, $len, $bend, $t) = @_; my $n = 10;
  for my $i (1 .. int($t * $n + 0.5)) { my ($dx, $dy) = dir($ang); $x += $dx * $len / $n; $y += $dy * $len / $n; $ang += $bend / $n; }
  return ($x, $y, $ang);
}

# Big glossy cacao leaf: long elliptic blade with a narrow drip tip, short petiole, lit and shaded halves,
# a pale midrib and slanted side veins. $wd < 1 withers it (narrow, curled).
sub cleaf {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, %o) = @_;
  my $n = 16; my (@mid, @l, @r, @ang);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $u = $t < 0.07 ? 0 : ($t - 0.07) / 0.93;
    my $hw = $t < 0.07 ? 1.6 : $w / 2 * sin(pi * $u ** 0.8) ** 0.85;
    $hw *= 1 - 0.45 * max(0, ($u - 0.72) / 0.28);                          # pinch toward the drip tip
    my $wav = 1 + ($o{wav} // 0) * sin($t * 19 + ($o{ph} // 0));
    $hw = 0 if $i == $n;
    push @l, [$px - $dy * $hw * $wav, $py + $dx * $hw * $wav];
    push @r, [$px + $dy * $hw / $wav, $py - $dx * $hw / $wav];
    push @mid, [$px, $py]; push @ang, $a;
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  if (my $sk = $o{sk}) { my $D = $leftLit ? \@r : \@l; $D->[$_] = [$mid[$_][0] + ($D->[$_][0] - $mid[$_][0]) * $sk, $mid[$_][1] + ($D->[$_][1] - $mid[$_][1]) * $sk] for 0 .. $n; }
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
  return if $o{noveins};
  # midrib: a thin pale line on the shaded half, along the middle
  my @mr = map { my ($ax, $ay) = dir($ang[$_]); my $h = 1.3 * (1 - $_ / $n) + 0.2; my $s = $leftLit ? -1 : 1;
                 [$mid[$_][0] + $ay * $h * $s * -1, $mid[$_][1] - $ax * $h * $s * -1] } 1 .. $n - 2;
  poly($o{rib} // $light, @mid[1 .. $n - 2], reverse @mr);
  return if $o{nosv};
  # side veins: dark slanted creases on the lit half (glossy leaves are quilted only lightly)
  my $L = $leftLit ? \@l : \@r;
  for my $k (3, 6, 9, 12) {
    my ($mx, $my) = @{$mid[$k]}; my ($ex, $ey) = @{$L->[$k + 2]};
    my ($fx, $fy) = ($mx + ($ex - $mx) * 0.78, $my + ($ey - $my) * 0.78);
    my ($ax, $ay) = dir($ang[$k]); my $d = max(0.8, $w * 0.025);
    poly($dark, [$mx + $ax * $d, $my + $ay * $d], [$fx, $fy], [$mx - $ax * $d, $my - $ay * $d]);
  }
}

# Pod profile: rounded shoulders near the stalk, widest just before the middle, tapering to a point.
sub podf { my ($t) = @_; $t < 0.5 ? sin(pi / 2 * min(1, $t / 0.5 + 0.06)) ** 0.6 : cos(pi / 2 * ($t - 0.5) / 0.5) ** 0.85 }

# Ribbed cacao pod. (x,y) = where its stalk leaves the bark, heading `ang` toward the pointed tip.
# 10 deep furrows: we see five ribbed bands; the band facing the light gets a cream gloss streak.
# $kind: 1 ripe orange, 0 unripe green, -1 shrivelled black (dead).
sub pod {
  my ($x, $y, $ang, $len, $w, $kind, $stem, %o) = @_; $stem //= $len * 0.1;
  my ($body, $shade, $gl) = $kind > 0 ? ('c5', 'c4', 'c3') : $kind == 0 ? ('c2', 'c1', 'c3') : ('c4', 'c5', 'c3');
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  # woody stalk and the swollen flower cushion on the bark
  poly('c4', ell($x, $y, $w * 0.13 + 2, $w * 0.13 + 2, 8)) unless $o{cut};
  my ($sx, $sy) = blade($x, $y, $ang, $stem + $len * 0.03, max(4, $w * 0.14), 0, $kind != 0 ? 'c5' : 'c2', 'c4', 0.8);
  my ($bx, $by) = ($x + $dx * $stem, $y + $dy * $stem);
  my $n = 22;
  my $P = sub { my ($t, $s) = @_;   # t 0..1 base->tip, s -1..1 across
    my $f = podf($t);
    my $bump = 1 + 0.035 * sin($t * 38);                       # warty, lumpy ribs
    $f *= ($kind < 0 ? 0.62 + 0.08 * sin($t * 23) : 1);
    [$bx + $dx * $t * $len + $nx * $s * $f * $w / 2 * $bump, $by + $dy * $t * $len + $ny * $s * $f * $w / 2 * $bump] };
  # 10 ribs around: visible furrow lines at s = sin(phi), phi every 36 degrees offset 18
  my @fs = (-1, map(sin(deg2rad($_)), -54, -18, 18, 54), 1);
  my @mids = (-72, -36, 0, 36, 72);
  my $line = sub { my ($s) = @_; map { $P->($_ / $n, $s) } 0 .. $n };
  if ($o{shadow}) { my $k = $o{shadow}; poly('c4', map { [$_->[0] + $k, $_->[1] + $k * 1.2] } $line->(-1), reverse $line->(1)); }
  poly($body, $line->(-1), reverse $line->(1));
  for my $j (0 .. 4) {
    my $ph = deg2rad($mids[$j]);
    # band facing: screen normal component along +n is sin(phi); light from upper left, a bit from the front
    my $b = sin($ph) * (-$nx * 0.7071 - $ny * 0.7071) + cos($ph) * 0.35;
    my ($s0, $s1) = @fs[$j, $j + 1];
    if ($b < -0.15) { poly($shade, $line->($s0), reverse $line->($s1)); }
    elsif ($b > 0.55 && $kind >= 0) {                         # gloss streak along the most lit rib
      my $sm = ($s0 + $s1) / 2; my $hw = ($s1 - $s0) * 0.28;
      my @a = map { my $t = 0.1 + 0.62 * $_ / 10; $P->($t, $sm - $hw * sin(pi * $_ / 10) ** 0.5) } 0 .. 10;
      my @c = map { my $t = 0.1 + 0.62 * $_ / 10; $P->($t, $sm + $hw * sin(pi * $_ / 10) ** 0.5) } 0 .. 10;
      poly($gl, @a, reverse @c);
    }
  }
  # deep furrows between the ribs
  for my $k (1 .. 4) {
    my $s = $fs[$k]; my $hw = 0.05;
    my @a = map { $P->($_ / $n, $s - $hw * sin(pi * $_ / $n)) } 1 .. $n - 1;
    my @c = map { $P->($_ / $n, $s + $hw * sin(pi * $_ / $n)) } 1 .. $n - 1;
    poly($shade, $P->(0.02, $s), @a, $P->(0.99, $s * 0.3), reverse @c);
  }
  # dark ring where the stalk meets the pod
  poly('c4', map { my ($u, $v) = dir($_ * 45); [$bx + $dx * 3 + $u * $w * 0.1, $by + $dy * 3 + $v * $w * 0.1] } 0 .. 7);
}

# Cocoa bean: plump almond, dark cocoa brown with a warm lit half and a little gloss. $raw = pulp-coated (white).
sub bean {
  my ($x, $y, $ang, $len, $w, $raw) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 17) {
    my $th = 2 * pi * $i / 18;
    my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 - 0.22 * cos($th) ** 2) * (1 + 0.12 * cos($th));
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  my ($base, $lite, $glint) = $raw ? ('c4', 'c3', undef) : ('c4', 'c5', 'c3');
  poly($base, @o);
  my $leftLit = lit($nx, $ny);
  my $sg = $leftLit ? 1 : -1;
  my @half = $leftLit ? @o[0 .. 9] : (@o[9 .. 17], $o[0]);
  my @in = map { my $u = cos(2 * pi * $_ / 18) * $len / 2 * 0.9; my $v = $sg * $w * 0.1 * sin(pi * $_ / 9);
                 [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v] } ($leftLit ? reverse(0 .. 9) : (0 .. 9));
  poly($lite, @half, @in) if !$raw;
  poly($lite, map { [$x + ($_->[0] - $x) * 0.86 - 0.7071 * $w * 0.05, $y + ($_->[1] - $y) * 0.86 - 0.7071 * $w * 0.05] } @o) if $raw;
  if ($glint) {
    my $s = $leftLit ? 1 : -1; my ($gx, $gy) = ($x + $nx * $s * $w * 0.22 - $dx * $len * 0.08, $y + $ny * $s * $w * 0.22 - $dy * $len * 0.08);
    poly($glint, [$gx - $dx * $len * 0.16, $gy - $dy * $len * 0.16], [$gx + $nx * $s * $w * 0.05, $gy + $ny * $s * $w * 0.05],
                 [$gx + $dx * $len * 0.12, $gy + $dy * $len * 0.12], [$gx - $nx * $s * $w * 0.04, $gy - $ny * $s * $w * 0.04]);
  }
}

# Tiny pink-white cacao flower: five pale petals around a warm centre.
sub flower {
  my ($x, $y, $r, $rot) = @_;
  for my $i (0 .. 4) {
    my $a = $rot + $i * 72; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    poly('c3', [$x + $nx * $r * 0.2, $y + $ny * $r * 0.2], [$x + $dx * $r * 0.75 + $nx * $r * 0.38, $y + $dy * $r * 0.75 + $ny * $r * 0.38],
               [$x + $dx * $r, $y + $dy * $r], [$x + $dx * $r * 0.75 - $nx * $r * 0.38, $y + $dy * $r * 0.75 - $ny * $r * 0.38],
               [$x - $nx * $r * 0.2, $y - $ny * $r * 0.2]);
  }
  poly('c5', ell($x + $r * 0.05, $y + $r * 0.05, $r * 0.36, $r * 0.36, 7));
  poly('c4', ell($x + $r * 0.12, $y + $r * 0.12, $r * 0.14, $r * 0.14, 5));
}
# A tuft of flowers sprouting from one cushion on the bark.
sub tuft { my ($x, $y, $r, $seed) = @_; srand($seed); my @f = ([0, 0], [1.3, 0.5], [-0.6, 1.2], [0.4, -1.3]);
  for (@f) { flower($x + $_->[0] * $r, $y + $_->[1] * $r, $r * (0.95 + rand(0.2)), rand(72)); } }

sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o;
  srand($seed);
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12; my $k = 0.82 + rand(0.3); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
}

sub cracks {
  my ($n, $seed, $seg) = @_; srand($seed);
  for my $i (0 .. $n - 1) {
    my $a = $i * 360 / $n + rand(20); my ($x, $y) = (200, 200); my (@l, @r);
    for my $k (0 .. 4) {
      my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.4 - $k * 0.4;
      push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
      $x += $dx * $seg; $y += $dy * $seg;
    }
    poly('c3', @l, [$x, $y], reverse @r);
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

# Trunk top seen from above: the jorquette where the fan branches split.
sub trunk { my ($r) = @_;
  poly('c4', ell(200, 200, $r, $r, 12));
  poly('c5', ell(197, 197, $r * 0.62, $r * 0.62, 10, 15));
  poly('c4', ell(201, 201, $r * 0.3, $r * 0.3, 7)); }

# Top-down cacao tree: branches fan out from the trunk, each ending in a drooping whorl of big leaves.
# Returns the branch paths so pods and flowers can be hung on them.
sub tree {
  my ($seed, $reach, $leaf, $bw, $flush, @br) = @_;
  srand($seed); my @leaves; my @paths;
  for my $b (@br) {
    my ($a, $len, $bend) = @$b; $len *= $reach;
    push @paths, [$a, $len, $bend];
    my ($ex, $ey, $ea) = walk(200, 200, $a, $len, $bend, 1);
    # a fan of 5 drooping leaves at the branch end, plus two along the branch
    for my $k (-2 .. 2) { push @leaves, [$ex, $ey, $ea + $k * 30 + rand(12) - 6, $leaf * (1 - abs($k) * 0.09 + rand(0.1)), (rand(1) < .5 ? -1 : 1) * (6 + rand(14)), 0]; }
    for my $t (0.55, 0.8) { my ($px, $py, $pa) = walk(200, 200, $a, $len, $bend, $t); my $s = rand(1) < .5 ? -1 : 1;
      push @leaves, [$px, $py, $pa + $s * (55 + rand(15)), $leaf * 0.8, $s * 12, 0]; }
    if ($flush) { push @leaves, [$ex, $ey, $ea + rand(20) - 10, $leaf * 0.5, rand(20) - 10, 1], [$ex, $ey, $ea + 35 + rand(10), $leaf * 0.42, 10, 1]; }
  }
  blade(200, 200, $_->[0], $_->[1], $bw, $_->[2], 'c5', 'c4', 0.35) for @paths;
  for my $l (sort { $a->[5] <=> $b->[5] || $b->[3] <=> $a->[3] } @leaves) {
    my ($x, $y, $ang, $len, $bend, $young) = @$l;
    cleaf($x, $y, $ang, $len, $len * ($young ? 0.32 : 0.35), $bend, $young ? ('c5', 'c4') : ('c2', 'c1'));
  }
  return @paths;
}
# Branches drawn again on top of the leaf bases near the trunk, so the woody frame stays visible.
sub frame { my ($bw, @p) = @_; for (@p) { blade(200, 200, $_->[0], $_->[1] * 0.62, $bw, $_->[2] * 0.62, 'c5', 'c4', 0.55); } }

# ---------------------------------------------------------------------------------------------
# 1. Planting material, front view: a little heap of dried purple-brown cocoa beans.
bean(140, 300, -8, 104, 64); bean(262, 300, 190, 104, 64); bean(200, 318, 2, 108, 66);
bean(170, 244, -32, 100, 62); bean(236, 248, 210, 100, 62); bean(204, 192, -84, 98, 60);
write_svg('1-seeds-front.svg', 'Cocoa beans');

# 2. Just sown, top down: beans pressed into small soil pockets.
my @sown = ([164, 168, -30], [242, 166, 35], [200, 222, 95], [150, 246, 160], [254, 244, -55]);
for (@sown) { soil($_->[0], $_->[1], 32, 26, int($_->[0] * 7 + $_->[1])); }
for (@sown) { bean($_->[0], $_->[1], $_->[2], 46, 28); }
write_svg('2-sown.svg', 'Cocoa beans just sown');

# 3. First growth, top down: a seedling, its first big leaves around a bronze young flush.
soil(200, 200, 34, 30, 3);
cleaf(200, 200, -150, 92, 32, 10, 'c2', 'c1'); cleaf(200, 200, 22, 98, 34, 12, 'c2', 'c1'); cleaf(200, 200, 100, 80, 29, -10, 'c2', 'c1');
cleaf(200, 200, -70, 52, 20, 8, 'c5', 'c4'); cleaf(200, 200, -30, 40, 15, -8, 'c5', 'c4');
poly('c4', ell(200, 200, 5, 5, 6)); poly('c5', ell(199, 199, 3, 3, 6));
write_svg('3-first-growth.svg', 'Cacao first growth');

# 4. Second growth, top down: a young single-stemmed sapling, a spiral of big drooping leaves.
soil(200, 200, 34, 30, 4);
{ srand(44); my $ga = 137.5;
  for my $i (0 .. 8) { my $a = -100 + $i * $ga; my $len = 118 - $i * 6 + rand(8); cleaf(200, 200, $a, $len, $len * 0.35, (rand(1) < .5 ? -1 : 1) * (8 + rand(12)), 'c2', 'c1'); }
  cleaf(200, 200, -40, 56, 21, 10, 'c5', 'c4'); cleaf(200, 200, 70, 50, 19, -10, 'c5', 'c4'); cleaf(200, 200, 190, 44, 16, 8, 'c5', 'c4');
  poly('c4', ell(200, 200, 7, 7, 7)); poly('c5', ell(198, 198, 4, 4, 6)); }
write_svg('4-second-growth.svg', 'Cacao second growth');

my @BR = ([-100, 1, 18], [-28, 0.94, -16], [44, 1, 20], [116, 0.92, -14], [188, 0.98, 16]);

# 5. Third growth, top down: the young tree with its fan branches; tiny pink-white flowers on trunk and
#    branches, a few small green pods (cherelles) setting.
soil(200, 200, 34, 30, 5);
my @p5 = tree(51, 66, 86, 14, 1, @BR);
frame(13, @p5);
trunk(17);
for my $i (0 .. $#p5) { my ($a, $len, $bend) = @{$p5[$i]};
  my ($x, $y) = walk(200, 200, $a, $len, $bend, 0.35); tuft($x, $y, 5.5, 50 + $i);
  if ($i % 2 == 0) { my ($px, $py, $pa) = walk(200, 200, $a, $len, $bend, 0.62); pod($px, $py, $pa + 60, 42, 23, 0, 5); }
}
tuft(186, 214, 5, 59); tuft(214, 184, 5, 58);
write_svg('5-third-growth.svg', 'Cacao third growth with flowers');

# 6. Harvest, top down: the full tree, ripe orange pods hanging off the trunk and along the branches.
soil(200, 200, 34, 30, 6);
my @p6 = tree(61, 82, 100, 17, 0, @BR);
frame(16, @p6);
trunk(20);
{ my @pods;
  for my $i (0 .. $#p6) { my ($a, $len, $bend) = @{$p6[$i]};
    my ($x, $y, $pa) = walk(200, 200, $a, $len, $bend, 0.7); push @pods, [$x, $y, $pa + ($i % 2 ? 34 : -34), 66, 44];
  }
  # on the trunk itself, between the branches
  for my $a (-60, 128) { my ($dx, $dy) = dir($a); push @pods, [200 + $dx * 14, 200 + $dy * 14, $a + 14, 64, 42]; }
  pod(@$_, 1, 5, shadow => 5) for sort { $a->[1] <=> $b->[1] } @pods;
  tuft(@$_) for ([224, 222, 4.5, 61], [168, 186, 4.5, 62]);
}
write_svg('6-harvest.svg', 'Cacao ready to harvest');

# 7. Harvest item, front view: a whole ribbed pod, a pod split open on its pulp-coated beans, loose beans.
pod(52, 96, 16, 236, 130, 1, 18, cut => 1);
{ # the split half: orange shell, cream rind, beans in their white pulp packed in rows
  my ($x, $y, $len, $w) = (206, 296, 236, 140); my ($bx, $by) = ($x - $len / 2, $y);
  my $P = sub { my ($t, $s, $k) = @_; my $f = podf($t);
    [$bx + ($t * $len - $len / 2) * $k + $len / 2, $by + $s * $f * $w / 2 * $k] };
  my @shell = (map({ $P->($_ / 24, 1, 1) } 0 .. 24), map({ $P->(1 - $_ / 24, -0.15, 1) } 0 .. 24));
  poly('c5', @shell);
  poly('c4', map({ $P->($_ / 24, 0.75, 1) } 2 .. 22), map({ $P->(1 - $_ / 24, 0.55, 1) } 2 .. 22));     # shadow under the rim
  poly('c3', map({ $P->($_ / 24, 0.72, 0.94) } 0 .. 24), map({ $P->(1 - $_ / 24, -0.86, 0.94) } 0 .. 24)); # cut rind face
  poly('c4', map({ $P->($_ / 24, 0.6, 0.84) } 1 .. 23), map({ $P->(1 - $_ / 24, -0.72, 0.84) } 1 .. 23)); # cavity
  for my $row ([-0.5, 6, 0.84], [0.05, 6, 0.92], [0.55, 5, 0.8]) {
    my ($s, $cnt, $sc) = @$row;
    for my $k (0 .. $cnt - 1) {
      my $t = 0.14 + 0.72 * ($k + ($row->[0] > 0 ? 0.5 : 0.2)) / $cnt;
      my $p = $P->($t, $s * 0.82, 0.84);
      bean($p->[0], $p->[1], 96 + ($k - $cnt / 2) * 5, 34 * $sc, 24 * $sc, 1);
    }
  }
  # shell lip: the lit orange edge and stalk end
  poly('c4', ell($bx + 2, $by - 3, 9, 9, 8));
}
bean(344, 214, -60, 58, 36); bean(352, 280, 20, 60, 37); bean(60, 250, -100, 54, 34);
write_svg('7-harvest-front.svg', 'Harvested cacao pods and cocoa beans');

# 8. Dead (never watered), top down: cracked dry soil, bare branches, dried curled leaves lying flat,
#    one blackened shrivelled pod.
soil(200, 200, 68, 58, 8);
cracks(9, 83, 14);
{ srand(84);
  my @br = ([-96, 100, 26], [-20, 108, -30], [52, 96, 30], [124, 104, -24], [196, 94, 28]);
  my @lv;
  for my $b (@br) { for my $t (0.4, 0.7, 1) { my ($px, $py, $pa) = walk(200, 200, @$b[0 .. 2], $t); my $s = rand(1) < .5 ? -1 : 1;
    push @lv, [$px, $py, $pa + $s * (40 + rand(40)), 70 + rand(18), $s * (50 + rand(50))]; } }
  blade(200, 200, $_->[0], $_->[1], 14, $_->[2], 'c5', 'c4', 0.3) for @br;
  my $q = 0; for (@lv) { my @c = $q++ % 3 == 1 ? ('c5', 'c4', rib => 'c3') : ('c3', 'c4', rib => 'c5', sk => 0.5); cleaf(@$_[0 .. 3], $_->[3] * 0.34, $_->[4] * 0.7, @c, wav => 0.12, ph => $_->[0], nosv => 1); }
  trunk(15);
  pod(232, 236, 50, 58, 34, -1, 5);
}
write_svg('8-dead.svg', 'Cacao died from lack of water');
print "wrote 8 files to $OUT\n";

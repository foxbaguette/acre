# Coffee crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/coffee.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/coffee';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => "#24502C", c2 => "#5C9A46", c3 => '#F5ECD7', c4 => "#4A2C1C", c5 => '#C2362B');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A tapered blade or stalk (as in wheat.pl). Returns the points along it: [x, y, angle].
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $lightc, $dark, $taper) = @_;
  $taper //= 1;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $t) ** 0.85 + ($i == $n && $taper == 1 ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py, $a];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang);
  my $leftLit = lit(-$dy, $dx);
  my @m = map { [$_->[0], $_->[1]] } @mid;
  poly($leftLit ? $lightc : $dark, @l, reverse @m);
  poly($leftLit ? $dark : $lightc, @r, reverse @m);
  return @mid;
}
sub at { my ($pts, $t) = @_; my $i = int($t * $#$pts + 0.5); @{$pts->[$i]} }
# a point along a path without drawing it
sub walk {
  my ($x, $y, $ang, $len, $bend, $t) = @_; my $n = 20;
  for my $i (1 .. int(($t // 1) * $n + 0.5)) { my ($dx, $dy) = dir($ang); $x += $dx * $len / $n; $y += $dy * $len / $n; $ang += $bend / $n; }
  return ($x, $y, $ang);
}

# A glossy coffee leaf: elliptic with a drawn-out tip and a gently wavy edge, split along the midrib into
# a lit and a shaded half, with sunken lateral veins and a pale sheen on the lit half.
sub cleaf {
  my ($x, $y, $ang, $len, $w, $lc, $dc, $gloss, $curl) = @_;
  $curl //= 0;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $n = 12; my (@L, @R, @M);
  for my $i (0 .. $n) {
    my $u = $i / $n;
    my $hw = $w / 2 * sin(pi * min(1, $u * 1.04)) ** 0.75 * (1 - 0.3 * $u) * (1 + 0.05 * sin($u * 25));
    my $c = $curl * $u * $u * $len * 0.3;                    # the tip curls sideways
    my ($cx, $cy) = ($x + $dx * $u * $len + $nx * $c, $y + $dy * $u * $len + $ny * $c);
    push @L, [$cx + $nx * $hw, $cy + $ny * $hw]; push @R, [$cx - $nx * $hw, $cy - $ny * $hw]; push @M, [$cx, $cy];
  }
  my $tip = [$x + $dx * $len * 1.08 + $nx * $curl * $len * 0.33, $y + $dy * $len * 1.08 + $ny * $curl * $len * 0.33];
  my $leftLit = lit($nx, $ny);
  my ($A, $B) = $leftLit ? ($lc, $dc) : ($dc, $lc);
  poly($A, @L, $tip, reverse @M);
  poly($B, @R, $tip, reverse @M);
  # lateral veins: thin darker grooves on the lit half
  my $V = $leftLit ? \@L : \@R; my $s = $leftLit ? 1 : -1;
  for my $i (3, 6, 9) {
    my ($mx, $my) = @{$M[$i - 1]}; my ($ex, $ey) = @{$V->[$i + 1]};
    my ($qx, $qy) = ($mx + ($ex - $mx) * 0.8, $my + ($ey - $my) * 0.8);
    poly($dc, [$mx, $my], [$qx, $qy], [$mx + $dx * 3, $my + $dy * 3]);
  }
  if ($gloss) {        # a pale sheen across the lit half
    my @g = map { my ($u, $v) = @$_; my $i = int($u * $n); my ($mx, $my) = @{$M[$i]}; my ($ex, $ey) = @{$V->[$i]}; [$mx + ($ex - $mx) * $v, $my + ($ey - $my) * $v] }
            ([0.22, 0.42], [0.42, 0.62], [0.62, 0.55], [0.45, 0.4]);
    poly($gloss, @g);
  }
}

# Round fruit (a coffee cherry) seen from above or the front: body, shaded crescent, glint, optional navel.
sub cherry {
  my ($x, $y, $r, $body, $shade, $glint, $navel) = @_;
  my $n = 14; my @o;
  for my $i (0 .. $n - 1) { my $th = 2 * pi * $i / $n + 0.11; my $rr = $r * (1 + 0.04 * cos(3 * $th)); push @o, [$x + cos($th) * $rr, $y + sin($th) * $rr * 0.94]; }
  poly($body, @o);
  my ($cx, $cy) = ($x - $r * 0.28, $y - $r * 0.28);
  my (@out, @in);
  my @d = map { cos(2 * pi * $_ / $n + 0.11 - pi / 4) } 0 .. $n - 1;
  my ($s0) = grep { $d[$_] > 0.05 && $d[($_ - 1) % $n] <= 0.05 } 0 .. $n - 1;
  for my $jj (0 .. $n - 1) {
    my $j = ($s0 + $jj) % $n; my $d = $d[$j];
    last unless $d > 0.05;
    push @out, $o[$j];
    my $k = 0.7 + 0.3 * (1 - ($d - 0.05) / 0.95) ** 1.5;
    push @in, [$cx + ($o[$j][0] - $cx) * $k, $cy + ($o[$j][1] - $cy) * $k];
  }
  poly($shade, @out, reverse @in) if @out > 2;
  if ($glint) {
    poly($glint, map { my ($a, $rr) = @$_; [$x + cos(deg2rad($a)) * $r * $rr, $y + sin(deg2rad($a)) * $r * $rr] } ([-150, 0.62], [-128, 0.7], [-108, 0.6], [-130, 0.46]));
  }
  if ($navel) {        # the dried flower scar at the blossom end
    my ($ax, $ay) = ($x + $navel->[0] * $r, $y + $navel->[1] * $r);
    poly("c4", map { my ($dx, $dy) = dir($_ * 72 + 10); [$ax + $dx * $r * 0.14, $ay + $dy * $r * 0.14] } 0 .. 4);
  }
}

# Crescent along the edge of a convex outline @o around (x,y) on the side facing (ux,uy).
sub rim {
  my ($x, $y, $r, $ux, $uy, $cls, $kmin, @o) = @_;
  my $n = @o;
  my @d = map { my ($vx, $vy) = ($_->[0] - $x, $_->[1] - $y); my $l = sqrt($vx * $vx + $vy * $vy) || 1; ($vx * $ux + $vy * $uy) / $l } @o;
  my ($s) = grep { $d[$_] > 0.1 && $d[($_ - 1) % $n] <= 0.1 } 0 .. $n - 1; $s //= 0;
  my ($cx, $cy) = ($x - $ux * $r * 0.3, $y - $uy * $r * 0.3);
  my (@out, @in);
  for my $j (0 .. $n - 1) {
    my $i = ($s + $j) % $n; last unless $d[$i] > 0.1;
    push @out, $o[$i];
    my $k = $kmin + (1 - $kmin) * (1 - ($d[$i] - 0.1) / 0.9) ** 1.5;
    push @in, [$cx + ($o[$i][0] - $cx) * $k, $cy + ($o[$i][1] - $cy) * $k];
  }
  poly($cls, @out, reverse @in) if @out > 1;
}

# A coffee bean: an oval with a flat face showing its S-shaped centre crease, or seen on its domed back.
# $lit / $shade: classes for an upper-left lit crescent and a lower-right shaded crescent (either may be undef).
sub bean {
  my ($x, $y, $ang, $len, $w, $body, $lit, $shade, $crease, $back, $glint) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $P = sub { my ($u, $v) = @_; [$x + $dx * $u * $len / 2 + $nx * $v * $w / 2, $y + $dy * $u * $len / 2 + $ny * $v * $w / 2] };
  my @o = map { my $th = 2 * pi * $_ / 20; $P->(cos($th), sin($th) * (1 - 0.12 * cos($th) ** 2)) } 0 .. 19;
  poly($body, @o);
  rim($x, $y, $w / 2, -0.7071, -0.7071, $lit, ($body eq "c4" ? 0.88 : 0.45), @o) if $lit;
  rim($x, $y, $w / 2, 0.7071, 0.7071, $shade, 0.84, @o) if $shade;
  if (!$back) {        # the S-shaped crease down the flat face
    my @c = map { my $u = -0.8 + 1.6 * $_ / 12; [$u, 0.14 * sin($u * 3.6)] } 0 .. 12;
    poly($crease, (map { $P->($_->[0], $_->[1] + (0.03 + 0.07 * (1 - abs($_->[0])))) } @c), (map { $P->($_->[0], $_->[1] - (0.03 + 0.07 * (1 - abs($_->[0])))) } reverse @c));
  } else {             # a faint seam along the domed back
    poly($crease, $P->(-0.75, -0.02), $P->(0, 0.05), $P->(0.75, -0.02), $P->(0, 0.01));
  }
  if ($glint) {
    my ($gx, $gy) = ($x - 0.7071 * $w * 0.22, $y - 0.7071 * $w * 0.22);
    poly($glint, [$gx - $dx * $len * 0.1, $gy - $dy * $len * 0.1], [$gx - 0.7071 * 2.5, $gy - 0.7071 * 2.5], [$gx + $dx * $len * 0.06, $gy + $dy * $len * 0.06], [$gx + 0.7071 * 2, $gy + 0.7071 * 2]);
  }
}

# Small white five-petalled coffee blossom seen from above.
sub blossom {
  my ($x, $y, $r, $rot) = @_;
  for my $k (0 .. 4) {
    my $a = $rot + $k * 72; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    my $P = sub { my ($u, $v) = @_; [$x + ($dx * $u + $nx * $v) * $r, $y + ($dy * $u + $ny * $v) * $r] };
    poly('c3', $P->(0, 0.12), $P->(0.55, 0.22), $P->(1.0, 0), $P->(0.55, -0.22), $P->(0, -0.12));
    poly('c2', $P->(0.2, 0), $P->(0.95, 0), $P->(0.55, lit($nx, $ny) ? -0.2 : 0.2)) if !lit($dx, $dy);
  }
  poly('c2', map { my ($dx, $dy) = dir($rot + 36 + $_ * 72); [$x + $dx * $r * 0.2, $y + $dy * $r * 0.2] } 0 .. 4);
}

# Small irregular patch of soil.
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

# A cluster of cherries hugging the branch at a node (top down). $ripe: share of red ones.
sub cluster {
  my ($x, $y, $ba, $n, $r, $ripe, $seed) = @_;
  srand($seed);
  my ($dx, $dy) = dir($ba); my ($nx, $ny) = (-$dy, $dx);
  my @c;
  for my $k (0 .. $n - 1) {        # cherries pressed against the branch on both sides of the node
    my $side = $k % 2 ? 1 : -1; my $along = (int($k / 2) - ($n - 1) / 4) * $r * 1.5 + rand($r * 0.3);
    my $off = $r * (0.8 + rand(0.25));
    push @c, [$x + $nx * $side * $off + $dx * $along, $y + $ny * $side * $off + $dy * $along, rand(1) < $ripe];
  }
  for (sort { ($a->[0] + $a->[1]) <=> ($b->[0] + $b->[1]) } @c) {   # upper-left ones first, lower-right ones on top
    my ($cx, $cy, $red) = @$_;
    cherry($cx, $cy, $r, $red ? 'c5' : 'c2', $red ? 'c4' : 'c1', 'c3', [0.1, 0.12]);
  }
}

# The bush seen from above: branches [angle, length, bend] with paired leaves at each node; returns node
# list [x, y, angle, t] for fruit and flowers. Leaves are drawn outer-first, branches on top of the leaves.
sub bush {
  my ($leafLen, $leafW, $nodes, $seed, $lc, $dc, $gloss, $branches, @br) = @_;
  srand($seed);
  my (@leaves, @nodes);
  for my $b (@br) {
    my ($a, $len, $bend) = @$b;
    for my $k (1 .. $nodes) {
      my $t = $k / $nodes;
      my ($px, $py, $pa) = walk(200, 200, $a, $len, $bend, $t * 0.92);
      my $ll = $leafLen * (1.05 - 0.35 * $t) * (0.9 + rand(0.2));
      my $spread = $k == $nodes ? 32 : 62 + rand(14);
      for my $side (-1, 1) { push @leaves, [$px, $py, $pa + $side * $spread, $ll, $leafW * $ll / $leafLen, $side * 0.25]; }
      push @nodes, [$px, $py, $pa, $t];
    }
  }
  for (sort { (($b->[0] - 200) ** 2 + ($b->[1] - 200) ** 2) <=> (($a->[0] - 200) ** 2 + ($a->[1] - 200) ** 2) } @leaves) {
    cleaf(@$_[0 .. 4], $lc, $dc, $gloss, $_->[5]);
  }
  if ($branches) { blade(200, 200, $_->[0], $_->[1] * 0.92, 6, $_->[2], 'c4', 'c4', 0.5) for @br; }
  return @nodes;
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a small heap of pale, unroasted coffee seed beans, flat faces showing the crease.
for my $b ([166, 206, -60, 0], [244, 204, -116, 1], [122, 282, -80, 1], [200, 292, -94, 0], [278, 280, -108, 0]) {
  bean($b->[0], $b->[1], $b->[2], 104, 76, "c3", undef, "c4", "c4", $b->[3]);
}
write_svg('1-seeds-front.svg', 'Coffee seeds');

# 2. Just sown, top down: seed beans pressed flat-side down into small soil pockets.
my @sown = ([168, 170, -30], [238, 166, 40], [202, 216, 95], [154, 240, 150], [250, 240, -60]);
for (@sown) { soil($_->[0], $_->[1], 30, 25, int($_->[0] * 7 + $_->[1])); }
for (@sown) { bean($_->[0], $_->[1], $_->[2], 46, 33, "c3", undef, "c2", "c4", 0); }
write_svg('2-sown.svg', 'Coffee just sown');

# 3. First growth, top down: the round seed leaves open, the first pointed pair between them.
soil(200, 200, 34, 30, 3);
blade(200, 200, 160, 8, 6, 0, "c2", "c1", 0.3); cleaf(200, 200, 165, 72, 76, "c2", "c1", "c3"); cleaf(200, 200, -15, 72, 76, "c2", "c1", "c3");
cleaf(200, 200, -100, 86, 36, "c2", "c1", "c3", 0.2); cleaf(200, 200, 80, 82, 34, "c2", "c1", "c3", -0.2);
write_svg('3-first-growth.svg', 'Coffee first growth');

# 4. Second growth, top down: a young shrub, pairs of glossy pointed leaves set crosswise.
soil(200, 200, 34, 30, 4);
for my $p ([45, 112, 46, 0.2], [135, 108, 44, -0.2], [0, 92, 40, 0.15], [90, 90, 40, -0.15]) {
  my ($a, $l, $w, $c) = @$p;
  cleaf(200, 200, $a, $l, $w, 'c2', 'c1', 'c3', $c); cleaf(200, 200, $a + 180, $l, $w, 'c2', 'c1', 'c3', -$c);
}
cleaf(200, 200, -60, 50, 24, 'c2', 'c1', 'c3', 0); cleaf(200, 200, 120, 50, 24, 'c2', 'c1', 'c3', 0);
write_svg('4-second-growth.svg', 'Coffee second growth');

# 5. Third growth, top down: spreading branches of paired leaves, white blossom clusters and small green cherries.
soil(200, 200, 34, 30, 5);
{
  my @br = ([-96, 146, 18], [-40, 132, -12], [12, 150, 14], [62, 128, -16], [114, 148, 12], [168, 134, -18], [222, 144, 16]);
  my @n = bush(70, 34, 4, 51, 'c2', 'c1', 'c3', 1, @br);
  cleaf(200, 200, -45, 46, 22, 'c2', 'c1', 'c3', 0); cleaf(200, 200, 135, 46, 22, 'c2', 'c1', 'c3', 0);
  srand(5);
  for my $i (0 .. $#n) {
    my ($x, $y, $a, $t) = @{$n[$i]}; next if $t > 0.9;
    if ($i % 2) { blossom($x + $_->[0], $y + $_->[1], 12, rand(72)) for ([-8, -7], [8, -4], [0, 8], [-10, 6], [10, 8]); }
    else { cluster($x, $y, $a, 4, 8, 0, $i); }
  }
}
write_svg('5-third-growth.svg', 'Coffee third growth with blossoms');

# 6. Harvest, top down: the full shrub with clusters of ripe red cherries along every branch.
soil(200, 200, 34, 30, 6);
{
  my @br = ([-96, 168, 18], [-40, 152, -12], [12, 172, 14], [62, 150, -16], [114, 170, 12], [168, 154, -18], [222, 166, 16]);
  my @n = bush(82, 40, 4, 61, 'c2', 'c1', 'c3', 1, @br);
  cleaf(200, 200, -45, 48, 22, 'c2', 'c1', 'c3', 0); cleaf(200, 200, 135, 48, 22, 'c2', 'c1', 'c3', 0);
  for my $i (0 .. $#n) { my ($x, $y, $a, $t) = @{$n[$i]}; next if $t > 0.9 || $t < 0.3; cluster($x, $y, $a, 4, 12, 0.85, $i + 7); }
}
write_svg('6-harvest.svg', 'Coffee ready to harvest');

# 7. Harvested produce, front view: a small heap of roasted beans and two red coffee cherries.
{
  my @b = ([120, 300, -20, 0], [184, 314, 8, 1], [250, 306, 200, 0], [300, 296, 160, 1], [150, 262, -40, 1], [214, 268, 14, 0],
           [272, 262, 190, 0], [180, 226, -70, 0], [240, 228, 230, 1], [208, 192, -100, 0]);
  bean($_->[0], $_->[1], $_->[2], 74, 54, "c4", "c5", undef, "c3", $_->[3], "c3") for @b;
  my @st = blade(318, 198, -120, 46, 5, -20, 'c2', 'c1', 0.4);
  cherry(296, 222, 30, 'c5', 'c4', 'c3', [0.15, 0.05]);
  cherry(342, 236, 28, 'c5', 'c4', 'c3', [0.1, 0.1]);
  cleaf(320, 206, -40, 70, 32, 'c2', 'c1', 'c3', 0.1);
}
write_svg('7-harvest-front.svg', 'Roasted coffee beans and coffee cherries');

# 8. Dead (never watered), top down: cracked dry soil, bare drooping twigs, brown curled leaves fallen flat
#    and a few shrivelled black cherries.
soil(200, 200, 60, 54, 8);
cracks(8, 83, 13, 'c3');
{
  my @br = ([-84, 118, 34], [-12, 108, -30], [64, 120, 34], [140, 110, -30], [212, 116, 32]);
  srand(88);
  my @lv;
  for my $b (@br) {
    my ($ba, $len, $bend) = @$b;
    for my $k (1 .. 3) {
      my ($px, $py, $pa) = walk(200, 200, $ba, $len, $bend, $k / 3 * 0.85);
      for my $side (-1, 1) {
        next if rand(1) < 0.3;                                  # some leaves have already dropped off
        push @lv, [$px, $py, $pa + $side * (55 + rand(45)), 46 + rand(14), 20 + rand(8), $side * (0.5 + rand(0.4))];
      }
    }
  }
  # fallen leaves lying loose on the soil
  push @lv, [168, 214, 150, 44, 20, 0.8], [236, 186, -20, 42, 18, -0.7], [214, 236, 80, 40, 18, 0.6];
  cleaf(@$_[0 .. 4], 'c3', 'c4', 0, $_->[5]) for @lv;
  blade(200, 200, $_->[0], $_->[1], 6, $_->[2], 'c4', 'c4', 0.5) for @br;
  for my $c ([226, 166], [174, 236], [152, 160], [246, 228], [204, 140]) { cherry($c->[0], $c->[1], 7, 'c4', 'c4', 'c3', 0); }
}
write_svg('8-dead.svg', 'Coffee died from lack of water');
print "wrote 8 files to $OUT\n";

# Pineapple crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/pineapple.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/pineapple';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#3E7A4C', c2 => '#7DB867', c3 => '#F7D262', c4 => '#5A3A22', c5 => '#E0763A');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A long stiff pineapple leaf from (x,y) heading `ang`, bending `bend` degrees; serrated edges when $teeth.
sub leaf {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $teeth) = @_;
  my $n = 16; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $t) ** 0.7 * (0.75 + 0.25 * min(1, $t * 6)) + ($i == $n ? 0 : 0.5);
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py];
    if ($teeth && $i > 1 && $i < $n - 1) {   # small forward-pointing spines on both edges
      my $sx = $px + $dx * $len / $n * 0.6; my $sy = $py + $dy * $len / $n * 0.6; my $o = $hw * 0.82 + 2.2;
      push @l, [$sx - $dy * $o, $sy + $dx * $o];
      push @r, [$sx + $dy * $o, $sy - $dx * $o];
    }
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# Tip point of a leaf (for placing things at the end of a stalk).
sub tip {
  my ($x, $y, $ang, $len, $bend) = @_;
  for (1 .. 16) { my ($dx, $dy) = dir($ang); $x += $dx * $len / 16; $y += $dy * $len / 16; $ang += $bend / 16; }
  return ($x, $y, $ang);
}

# Top-down rosette: rings of leaves around (cx,cy). Each ring: [count, len, lenVar, width, bendMax, startAngle].
sub rosette {
  my ($cx, $cy, $seed, $light, $dark, $teeth, @rings) = @_;
  srand($seed);
  for my $rg (@rings) {
    my ($n, $len, $var, $w, $bmax, $start) = @$rg;
    my @b;
    for my $i (0 .. $n - 1) {
      my $a = $start + $i * 360 / $n + rand(14) - 7;
      push @b, [$a, $len + rand($var), (rand(1) < 0.5 ? -1 : 1) * $bmax * (0.3 + rand(0.7))];
    }
    for (sort { $b->[1] <=> $a->[1] } @b) {
      my ($dx, $dy) = dir($_->[0]);
      leaf($cx + $dx * 4, $cy + $dy * 4, $_->[0], $_->[1], $w, $_->[2], $light, $dark, $teeth);
    }
  }
}

# Shade a facet: n = (x, y-down, z-toward-viewer). Light from the upper left and the front.
sub shade {
  my ($nx, $ny, $nz) = @_; my $l = sqrt($nx * $nx + $ny * $ny + $nz * $nz) || 1;
  my $b = ($nx * -0.55 + $ny * -0.55 + $nz * 0.63) / $l;
  our $FLOWER; if ($FLOWER) { return $b > -0.25 ? 'c5' : 'c4' }
  return $b > 0.42 ? 'c3' : $b > -0.3 ? 'c5' : 'c4';
}

# One diamond scale as a 4-faced pyramid. Corners T R B L (screen), centre C; body normal (bx,by,bz);
# face directions in 3D for the four faces are given as tangent (tx,ty,tz) and up (ux,uy,uz) vectors.
sub scale4 {
  my ($C, $T, $R, $B, $L, $bn, $tan, $up, $k) = @_;
  my @sh = map { [$C->[0] + ($_->[0] - $C->[0]) * $k, $C->[1] + ($_->[1] - $C->[1]) * $k] } ($T, $R, $B, $L);
  my @faces = ([$sh[3], $sh[0], -1, -1], [$sh[0], $sh[1], 1, -1], [$sh[1], $sh[2], 1, 1], [$sh[2], $sh[3], -1, 1]);
  for my $f (@faces) {
    my ($p, $q, $st, $su) = @$f;
    my @n = map { $bn->[$_] + 0.5 * ($st * $tan->[$_] + -$su * $up->[$_]) } 0 .. 2;
    poly(shade(@n), $C, $p, $q);
  }
}

# Pineapple fruit seen from the front: barrel body covered in a lattice of diamond scales.
sub fruit_front {
  my ($cx, $cy, $W, $H) = @_;
  my $hw = sub { my $v = ($_[0] - $cy) / ($H / 2); $v = max(-1, min(1, $v)); $W / 2 * (1 - abs($v) ** 2.6) ** 0.5 };
  my @o;
  for my $i (0 .. 39) { my $th = 2 * pi * $i / 40; my $y = $cy + sin($th) * $H / 2; push @o, [$cx + cos($th) * $hw->($y) * 1.02, $y]; }
  poly('c4', @o);
  my $rows = int($H / 13 + 0.5); my $dyr = $H / $rows; my $cols = 6; my $dphi = pi / $cols;
  for my $r (0 .. $rows) {
    my $yc = $cy - $H / 2 + $dyr * $r;
    for my $j (-$cols .. $cols) {
      my $phi = ($j + ($r % 2 ? 0.5 : 0)) * $dphi;
      next if abs($phi) > pi / 2 - 0.05;
      my $P = sub { my ($ph, $y) = @_; [$cx + $hw->($y) * sin(max(-pi / 2, min(pi / 2, $ph))), $y] };
      my ($T, $Rr, $B, $L) = ($P->($phi, $yc - $dyr * 1.0), $P->($phi + $dphi * 0.5, $yc), $P->($phi, $yc + $dyr * 1.0), $P->($phi - $dphi * 0.5, $yc));
      next if $hw->($yc) < 6;
      my $C = $P->($phi, $yc);
      my $v = ($yc - $cy) / ($H / 2);
      my @bn = (sin($phi), $v * 0.55, cos($phi));
      scale4($C, $T, $Rr, $B, $L, \@bn, [cos($phi), 0, -sin($phi)], [0, -1, 0], 0.86);
      # tiny dark eye at the centre of each scale
      poly('c4', [$C->[0] - 1.6, $C->[1]], [$C->[0], $C->[1] - 1.6], [$C->[0] + 1.6, $C->[1]], [$C->[0], $C->[1] + 1.6]);
    }
  }
}

# Pineapple fruit from straight above: rings of diamond scales on the domed shoulder.
sub fruit_top {
  my ($cx, $cy, $R) = @_;
  my @o; for my $i (0 .. 35) { my $th = 2 * pi * $i / 36; push @o, [$cx + cos($th) * $R * 1.03, $cy + sin($th) * $R * 1.03]; }
  poly('c4', @o);
  my $n = 14; my $q = 0.8; my $dt = pi / $n;
  for my $k (0 .. 6) {
    my $rf = 0.93 * $q ** $k; my $r = $R * $rf;
    for my $i (0 .. $n - 1) {
      my $th = ($i + ($k % 2 ? 0.5 : 0)) * 2 * pi / $n - pi / 2;
      my $P = sub { my ($rr, $t) = @_; [$cx + cos($t) * $rr, $cy + sin($t) * $rr] };
      my $C = $P->($r, $th);
      my ($Out, $Cw, $In, $Ccw) = ($P->(min($R, $r / $q), $th), $P->($r, $th + $dt), $P->($r * $q, $th), $P->($r, $th - $dt));
      my $s = $rf; my @bn = (cos($th) * $s * 1.1, sin($th) * $s * 1.1, sqrt(max(0.05, 1 - $s * $s)));
      # map screen T,R,B,L onto Out,Cw,In,Ccw; tangent = cw direction, up = outward
      scale4($C, $Out, $Cw, $In, $Ccw, \@bn, [-sin($th), cos($th), 0], [cos($th), sin($th), 0], 0.86);
      { our $FLOWER; my $e = $FLOWER ? 1.7 : 1.6; poly($FLOWER && $i % 2 ? 'c3' : 'c4', [$C->[0] - $e, $C->[1]], [$C->[0], $C->[1] - $e], [$C->[0] + $e, $C->[1]], [$C->[0], $C->[1] + $e]); }
    }
  }
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

# Front-view crown: leaves fanning up from (x,y). Each: [angle, len, bend].
sub crown_front {
  my ($x, $y, $sc, @lv) = @_;
  leaf($x + ($_->[0] + 90) * 0.12 * $sc, $y, $_->[0], $_->[1] * $sc, 13 * $sc, $_->[2], 'c2', 'c1', 1) for @lv;
}

# 1. Planting material, front view: a pineapple crown twisted off the fruit, with its stubby fruit base.
{
  my @back = ([-150, 92, -26], [-30, 92, 26], [-128, 128, -16], [-52, 128, 16]);
  my @mid  = ([-112, 150, -8], [-68, 150, 8], [-138, 82, -30], [-42, 82, 30]);
  my @fr   = ([-98, 120, -4], [-82, 124, 4], [-90, 104, 0]);
  crown_front(200, 282, 1.15, @back, @mid);
  fruit_front(200, 300, 104, 50);
  crown_front(200, 282, 1.15, @fr);
}
write_svg('1-seeds-front.svg', 'Pineapple crown for planting');

# 2. Just planted, top down: the crown set into a soil pocket, short stiff leaves.
soil(200, 200, 44, 38, 2);
rosette(200, 200, 21, 'c2', 'c1', 1, [9, 46, 10, 18, 10, -80], [7, 32, 8, 16, 8, -60], [4, 20, 4, 11, 0, -45]);
write_svg('2-sown.svg', 'Pineapple crown just planted');

# 3. First growth, top down: the rooted crown opens into a small rosette.
soil(200, 200, 40, 34, 3);
rosette(200, 200, 31, 'c2', 'c1', 1, [11, 74, 14, 19, 16, -90], [8, 50, 10, 18, 10, -70], [5, 28, 6, 12, 0, -50]);
write_svg('3-first-growth.svg', 'Pineapple first growth');

# 4. Second growth, top down: a spiky rosette of long serrated leaves.
soil(200, 200, 38, 32, 4);
rosette(200, 200, 41, 'c2', 'c1', 1, [13, 108, 18, 21, 20, -90], [11, 80, 14, 20, 14, -75], [7, 48, 10, 17, 8, -60], [5, 26, 4, 12, 0, -40]);
write_svg('4-second-growth.svg', 'Pineapple second growth');

# Flower head from above: red bracts, a cone of reddish fruitlets dotted with pale florets, a baby crown.
sub flower_top {
  my ($cx, $cy, $R) = @_;
  for my $i (0 .. 11) { my $a = $i * 30 - 75; leaf($cx, $cy, $a, $R * ($i % 2 ? 1.55 : 1.8), 20, 10, 'c5', 'c4', 0); }
  our $FLOWER = 1; fruit_top($cx, $cy, $R); $FLOWER = 0;
  for my $i (0 .. 5) { my $a = $i * 60 - 80; leaf($cx, $cy, $a, $R * 0.6, 7, 12, 'c2', 'c1', 0); }
}

# 5. Third growth, top down: full rosette with the flower head appearing in the centre.
soil(200, 200, 38, 32, 5);
rosette(200, 200, 51, 'c2', 'c1', 1, [15, 134, 22, 22, 22, -90], [13, 102, 18, 21, 16, -78], [9, 68, 12, 19, 10, -66]);
flower_top(200, 200, 34);
write_svg('5-third-growth.svg', 'Pineapple third growth with flower');

# 6. Harvest, top down: a golden pineapple with its own crown, framed by the big rosette.
soil(200, 200, 38, 32, 6);
rosette(200, 200, 61, 'c2', 'c1', 1, [16, 150, 26, 23, 24, -90], [14, 120, 20, 22, 18, -78]);
fruit_top(200, 200, 78);
rosette(200, 200, 62, 'c2', 'c1', 1, [9, 56, 10, 16, 14, -90], [7, 40, 8, 14, 10, -70], [4, 22, 4, 11, 0, -45]);
write_svg('6-harvest.svg', 'Pineapple ready to harvest');

# 7. Harvest item, front view: one golden pineapple with its leafy crown (no plant, no soil).
fruit_front(200, 250, 150, 196);
crown_front(200, 158, 1.2, [-152, 62, -18], [-28, 62, 18], [-130, 84, -10], [-50, 84, 10], [-110, 98, -4], [-70, 98, 4], [-90, 88, 0]);
write_svg('7-harvest-front.svg', 'Pineapple harvest');

# 8. Dead (never watered), top down: cracked dry soil and a collapsed rosette of dried, curled leaves.
soil(200, 200, 64, 56, 8);
srand(83);
for my $i (0 .. 6) {
  my $a = $i * 360 / 7 + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
  for my $k (0 .. 4) {
    my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.2 - $k * 0.35;
    push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
    $x += $dx * 15; $y += $dy * 15;
  }
  poly('c3', @l, [$x, $y], reverse @r);
}
srand(81);
my @dead;
for my $i (0 .. 11) { my $a = -90 + $i * 30 + rand(14) - 7; push @dead, [$a, 80 + rand(44), (rand(1) < 0.5 ? -1 : 1) * (60 + rand(60))]; }
leaf(200, 200, $_->[0], $_->[1], 18, $_->[2], 'c3', 'c4', 1) for sort { $b->[1] <=> $a->[1] } @dead;
for ([-60, 26], [60, 24], [180, 28], [120, 20]) { leaf(200, 200, $_->[0], $_->[1], 14, 40, 'c3', 'c4', 0); }
# a small shrivelled brown stub where the crown was
poly('c4', map { my ($dx, $dy) = dir($_ * 45 + 10); [200 + $dx * (9 + ($_ % 2) * 4), 200 + $dy * (9 + ($_ % 2) * 4)] } 0 .. 7);
write_svg('8-dead.svg', 'Pineapple died from lack of water');
print "wrote 8 files to $OUT\n";

# Corn (maize) crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/corn.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/corn';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#3B7B33', c2 => '#8CC652', c3 => '#FAEBAA', c4 => '#5A3A22', c5 => '#F2BE2A');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub ell { my ($x, $y, $rx, $ry, $n, $rot) = @_; $rot //= 0; map { my ($u, $v) = dir($rot + $_ * 360 / $n); [$x + $u * $rx, $y + $v * $ry] } 0 .. $n - 1 }

# A tapered blade / stalk from (x,y) heading `ang`, bending `bend` degrees over its length.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark) = @_;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $t) ** 0.85 + ($i == $n ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# Points [x, y, heading] along a bent path (same stepping as blade).
sub path {
  my ($x, $y, $ang, $len, $bend, $n) = @_; $n //= 10; my @p; my $a = $ang;
  for my $i (0 .. $n) { push @p, [$x, $y, $a]; my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  @p;
}

# One narrow leaf segment (a slim diamond) split into a lit and a shaded half.
# Small irregular patch of soil.
sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o;
  srand($seed);
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12; my $k = 0.82 + rand(0.3); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
}
# Pale cracks running out through dry soil.
sub cracks {
  my ($n, $seed) = @_; srand($seed);
  for my $i (0 .. $n - 1) {
    my $a = $i * 360 / $n + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
    for my $k (0 .. 4) {
      my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.2 - $k * 0.35;
      push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
      $x += $dx * 13; $y += $dy * 13;
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

# A maize leaf: a long broad strap with a pale midrib, slightly wavy edges, arching over at the tip.
sub strap {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, %o) = @_;
  my $N = 16; my (@l, @r, @m);
  my @p = path($x, $y, $ang, $len, $bend, $N);
  for my $i (0 .. $N) {
    my $t = $i / $N; my ($px, $py, $a) = @{$p[$i]}; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * ($t < 0.14 ? 0.5 + 0.5 * $t / 0.14 : 1) * (1 - $t) ** 0.45 * (1 + ($i % 2 ? 0.07 : -0.03) * ($i > 2 && $i < $N - 1));
    $hw = 0 if $i == $N;
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @m, [$px, $py];
  }
  my ($dx, $dy) = dir($ang + $bend / 2); my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @m);
  poly($leftLit ? $dark : $light, @r, reverse @m);
  my $rib = $o{rib} // 'c3'; return unless $rib;
  my $rw = max(1.1, $w * 0.07); my (@a, @b);
  for my $i (0 .. $N - 2) {
    my $t = $i / $N; my ($px, $py, $an) = @{$p[$i]}; my ($ux, $uy) = dir($an); my $h = $rw * (1 - $t) + 0.3;
    push @a, [$px - $uy * $h, $py + $ux * $h]; push @b, [$px + $uy * $h, $py - $ux * $h];
  }
  poly($rib, @a, [@{$p[$N - 1]}[0, 1]], reverse @b);
}

# Tassel seen from above: a golden central spike with thin branches radiating, each dotted with spikelets.
sub tassel {
  my ($x, $y, $r, $n, $rot, $light, $dark) = @_;
  for my $k (0 .. $n - 1) {
    my $a = $rot + $k * 360 / $n; my $len = $r * ($k % 2 ? 0.8 : 1);
    blade($x, $y, $a, $len, 6, 22, $light, $dark);
    for my $p ((path($x, $y, $a, $len, 22, 6))[2 .. 5]) {
      my ($px, $py, $pa) = @$p; my ($ux, $uy) = dir($pa);
      for my $s (-1, 1) { my ($sx, $sy) = dir($pa + $s * 40); poly($s < 0 ? $light : $dark, [$px, $py], [$px + $sx * $r * 0.16 - $uy * $s * 1.5, $py + $sy * $r * 0.16 + $ux * $s * 1.5], [$px + $sx * $r * 0.16, $py + $sy * $r * 0.16]); }
    }
  }
  poly($dark, ell($x, $y, $r * 0.13, $r * 0.13, 8)); poly($light, (ell($x, $y, $r * 0.13, $r * 0.13, 8))[3 .. 7]);
}

# Silk: a tuft of fine strands fanning out from an ear tip.
sub silk {
  my ($x, $y, $ang, $len, $light, $dark, $n) = @_; $n //= 7;
  for my $k (0 .. $n - 1) {
    my $u = $k / ($n - 1) - 0.5; my $cls = $k % 3 == 1 ? $dark : $light;
    blade($x, $y, $ang + $u * 70, $len * (0.75 + 0.25 * (1 - abs($u) * 2)), 3.2, -$u * 40, $cls, $cls eq $light ? $dark : $light);
  }
}

# Kernels on a cylinder: rows across, columns around; draws the visible face of an ear between t0 and t1.
# Front view of a cob: axis from (x,y) toward `ang`, radius R.
sub kernels {
  my ($x, $y, $ang, $len, $R, $t0, $t1, %o) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $prof = sub { my $t = shift; $t > 0.8 ? sqrt(max(0, 1 - (($t - 0.8) / 0.2) ** 2)) * 0.92 + 0.08 : ($t < 0.06 ? 0.86 + 0.14 * $t / 0.06 : 1) };
  my $ls = lit($nx, $ny) ? 1 : -1;                                     # +n side lit when 1
  my $P = sub { my ($t, $s) = @_; my $h = $R * $prof->($t) * $s; [$x + $dx * $len * $t + $nx * $h, $y + $dy * $len * $t + $ny * $h] };
  my @T = map { $t0 + ($t1 - $t0) * $_ / 24 } 0 .. 24;
  poly('c5', (map { $P->($_, 1) } @T), (map { $P->($_, -1) } reverse @T));
  poly('c4', (map { $P->($_, -$ls) } @T[1 .. 23]), (map { $P->($_, -$ls * 0.9) } reverse @T[2 .. 22]));   # shaded rim
  my $rows = $o{rows} // 14; my $cols = $o{cols} // 4; my $step = (pi / 2) / ($cols + 0.55);
  for my $ri (0 .. $rows - 1) {
    my $tA = $t0 + ($t1 - $t0) * ($ri + 0.06) / $rows; my $tB = $t0 + ($t1 - $t0) * ($ri + 0.94) / $rows; my $tm = ($tA + $tB) / 2;
    for my $cj (-$cols .. $cols) {
      my $ph = $cj * $step; my $p0 = $ph - $step * 0.46; my $p1 = $ph + $step * 0.46;
      next if abs($p1) > pi / 2 + 0.01 || abs($p0) > pi / 2 + 0.01;
      my $c = $P->($tm, sin($ph)); my $hw = $R * $prof->($tm) * (sin($p1) - sin($p0)) / 2; my $hl = $len * ($tB - $tA) / 2;
      next if $hw < 1.2;
      my @e = map { my ($u, $v) = dir($_ * 30); [$c->[0] + $dx * $u * $hl + $nx * $v * $hw, $c->[1] + $dy * $u * $hl + $ny * $v * $hw] } 0 .. 11;
      my $side = sin($ph) * $ls;
      poly('c5', @e);
      my $half = sub { my ($k, $sx, $sy, $ox, $oy) = @_;            # half of the cell facing (sx,sy), scaled k, shifted
        my @d = map { ($_->[0] - $c->[0]) * $sx + ($_->[1] - $c->[1]) * $sy } @e; my $st = 0; $st++ while $d[$st % 12] >= 0 || $d[($st + 1) % 12] < 0; 
        my @h; for my $i (1 .. 12) { my $p = $e[($st + $i) % 12]; last if $d[($st + $i) % 12] < -0.01 * $hw && @h > 2; push @h, [$c->[0] + ($p->[0] - $c->[0]) * $k + $ox, $c->[1] + ($p->[1] - $c->[1]) * $k + $oy]; }
        @h };
      if ($side < 0.35) { poly('c4', $half->(1, 0.7071, 0.7071, 0, 0)); poly('c5', $half->(0.9, 0.7071, 0.7071, -$hw * 0.18, -$hw * 0.18)) if $side > -0.45; }
      if ($side > -0.3) { poly('c3', $half->($side > 0.3 ? 0.78 : 0.6, -0.7071, -0.7071, -$hw * 0.08, -$hw * 0.08)); }
    }
  }
}

# A husk-wrapped ear: a plump spindle wrapped in spiralling husk leaves, loose tips and a silk tuft.
sub huskear {
  my ($x, $y, $ang, $len, $R, %o) = @_;
  my $L = $o{light} // 'c2'; my $D = $o{dark} // 'c1';
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $lsgn = lit($nx, $ny) ? 1 : -1;                                  # +n side is lit when 1
  my $H = sub { my $t = shift; $R * ($t < 0.1 ? 0.6 + 0.4 * sqrt($t / 0.1) : sin(pi / 2 * max(0, min(1, (1 - $t) / 0.75))) ** 0.75) };
  my $P = sub { my ($t, $s) = @_; my $h = $H->($t) * $s; [$x + $dx * $len * $t + $nx * $h * $lsgn, $y + $dy * $len * $t + $ny * $h * $lsgn] };
  my @T = map { $_ / 18 } 0 .. 18; my $tip = $P->(1.06, 0);
  unless ($o{nosilk}) {
    my $st = $P->(0.97, 0);
    silk($st->[0], $st->[1], $ang, $o{silk} // $len * 0.3, $o{slight} // 'c3', $o{sdark} // 'c4', $o{sn} // 9);
  }
  poly($D, (map { $P->($_, 1) } @T), $tip, (map { $P->($_, -1) } reverse @T));          # whole ear, shaded
  my $seam = sub { -0.35 + 0.95 * $_[0] };                                                  # spiral seam (-1 lit edge .. 1 dark edge)
  poly($L, (map { $P->($_, 1) } @T), $tip, (map { $P->($_, $seam->($_)) } reverse @T));    # front wrapper, lit
  poly($D, (map { $P->($_, $seam->($_) + 0.02) } @T[2 .. 17]), (map { $P->($_, $seam->($_) - 0.16) } reverse @T[4 .. 16]));   # its edge shadow
  for my $v ([-0.62, 'c3'], [-0.2, 'c3'], [0.62, 'c2'], [0.3, 'c2']) {                    # fine parallel husk veins
    my ($s0, $cls) = @$v; my $w = 0.035;
    my @vt = @T[2 .. 16];
    poly($o{hi} && $cls eq 'c3' ? $o{hi} : ($cls eq 'c2' ? $L : ($o{hi} // 'c3')), (map { $P->($_, $s0 * (1 - 0.3 * $_) + $w) } @vt), (map { $P->($_, $s0 * (1 - 0.3 * $_) - $w) } reverse @vt));
  }
  my $s2 = sub { 0.25 + 0.75 * $_[0] };
  poly($L, (map { $P->($_, $s2->($_)) } @T[6 .. 17]), $P->(0.98, 0.62), (map { $P->($_, $s2->($_) + 0.22) } reverse @T[8 .. 16]));  # back wrapper sliver
  poly($o{hi} // 'c3', (map { $P->($_, 0.86 - 0.05 * $_) } @T[3 .. 13]), (map { $P->($_, 0.7 - 0.12 * $_) } reverse @T[4 .. 12]));  # lit vein
  return if $o{notips};
  for my $s (-1, 1) {                                                                       # loose husk tips past the ear
    my $b = $P->(0.86, 0.5 * $s);
    blade($b->[0], $b->[1], $ang - $s * $lsgn * 12, $len * 0.24, $R * 0.5, $s * $lsgn * 16, $L, $D);
  }
}

# The stalk seen from above with its leaves: two ranks of leaves alternating, slowly twisting.
sub plant {
  my ($n, $len, $var, $w, $seed, %o) = @_; srand($seed);
  my @f; my $rot = $o{start} // -60;
  for my $i (0 .. $n - 1) {
    my $a = $rot + ($i % 2) * 180 + int($i / 2) * ($o{twist} // 47) + rand(12) - 6;
    my $l = $len * (0.62 + 0.38 * $i / max(1, $n - 1)) + rand($var);       # lower (outer) leaves are longer
    $l = $len + rand($var) - $l + $len * 0.62 if $o{outer};
    push @f, [$a, $l, (rand(1) < 0.5 ? -1 : 1) * (14 + rand($o{bend} // 22))];
  }
  @f = sort { $b->[1] <=> $a->[1] } @f;
  for (@f) { my ($dx, $dy) = dir($_->[0]); strap(200 + $dx * 4, 200 + $dy * 4, @$_[0, 1], $w, $_->[2], $o{light} // 'c2', $o{dark} // 'c1', rib => $o{rib}); }
  @f;
}

sub stalktop { my ($r, $L, $D) = @_; my @c = ell(200, 200, $r, $r, 10, 8); poly($D // 'c1', @c); poly($L // 'c2', @c[4 .. 8], [200, 200]); }

# 1. Seeds, front view: a heap of plump dent-corn kernels, each with a pale germ.
sub kernel {
  my ($x, $y, $ang, $s) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);           # d = toward the broad crown
  my @shape = ([-0.5, 0], [-0.42, 0.22], [-0.05, 0.4], [0.38, 0.5], [0.5, 0.36], [0.54, 0], [0.5, -0.36], [0.38, -0.5], [-0.05, -0.4], [-0.42, -0.22]);
  my @o = map { [$x + $dx * $_->[0] * $s + $nx * $_->[1] * $s, $y + $dy * $_->[0] * $s + $ny * $_->[1] * $s] } @shape;
  poly('c4', map { [$_->[0] + $s * 0.05, $_->[1] + $s * 0.06] } @o);   # shadow below right
  poly('c5', @o);
  my $lLit = lit($nx, $ny);
  my @lh = $lLit ? @o[0 .. 5] : (@o[5 .. 9], $o[0]);
  my ($lx, $ly) = $lLit ? ($nx, $ny) : (-$nx, -$ny);
  poly('c3', $lh[1], $lh[2], $lh[3], [$x + $dx * $s * 0.3 + $lx * $s * 0.4, $y + $dy * $s * 0.3 + $ly * $s * 0.4], [$x - $dx * $s * 0.2 + $lx * $s * 0.3, $y - $dy * $s * 0.2 + $ly * $s * 0.3]);
  # germ: pale teardrop on the face plus a little dent at the crown
  my @g = map { [$x + $dx * $_->[0] * $s + $nx * $_->[1] * $s, $y + $dy * $_->[0] * $s + $ny * $_->[1] * $s] } ([-0.36, 0], [-0.1, 0.13], [0.2, 0.12], [0.28, 0], [0.2, -0.12], [-0.1, -0.13]);
  poly('c3', @g);
  poly('c4', [$x + $dx * $s * 0.5 + $nx * $s * 0.12, $y + $dy * $s * 0.5 + $ny * $s * 0.12], [$x + $dx * $s * 0.42, $y + $dy * $s * 0.42], [$x + $dx * $s * 0.5 - $nx * $s * 0.12, $y + $dy * $s * 0.5 - $ny * $s * 0.12]);
}
kernel(146, 278, -100, 66); kernel(204, 286, -80, 68); kernel(258, 276, -64, 64);
kernel(176, 226, -112, 62); kernel(232, 228, -70, 62); kernel(206, 178, -92, 60);
write_svg('1-seeds-front.svg', 'Corn kernels');

# 2. Just sown, top down: kernels pressed into three soil pockets.
my @sown = ([200, 164], [164, 226], [238, 224]);
for (@sown) { soil($_->[0], $_->[1], 30, 25, int($_->[0] * 7 + $_->[1])); }
kernel(198, 166, -60, 34); kernel(166, 228, 200, 34); kernel(240, 224, 20, 34);
write_svg('2-sown.svg', 'Corn just sown');


# A ripe ear seen from above with its husk parted: kernels between pale husk leaves, browned silk at the tip.
sub openear {
  my ($x, $y, $ang, $len, $R, %o) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  for my $s (-1, 1) {                                       # husk leaves parted either side, pale inner faces
    my ($bx, $by) = ($x + $dx * $len * 0.2 + $nx * $s * $R * 0.5, $y + $dy * $len * 0.2 + $ny * $s * $R * 0.5);
    blade($bx, $by, $ang + $s * 24, $len * 0.78, $R * 1.35, -$s * 14, "c3", "c2");
  }
  silk($x + $dx * $len * 0.98, $y + $dy * $len * 0.98, $ang, $len * 0.24, 'c4', 'c5', 7);
  kernels($x, $y, $ang, $len, $R, 0.12, 1, rows => $o{rows} // 9, cols => 2);
  huskear($x, $y, $ang, $len * 0.3, $R * 1.05, nosilk => 1, notips => 1);
}

# 3. First growth: a young spike unrolling its first broad leaves.
soil(200, 200, 34, 30, 3);
plant(4, 72, 8, 28, 31, start => -110, twist => 70, bend => 12);
stalktop(7);
write_svg('3-first-growth.svg', 'Corn first growth');

# 4. Second growth: a leafy young plant, broad arching straps in two ranks.
soil(200, 200, 34, 30, 4);
plant(7, 120, 10, 40, 41, start => -120, twist => 40, bend => 24);
stalktop(9);
write_svg('4-second-growth.svg', 'Corn second growth');

# 5. Third growth: tall plant, a green tassel on top and young ears with fresh pale silk.
soil(200, 200, 36, 32, 5);
plant(9, 146, 10, 44, 51, start => -125, twist => 37, bend => 24);
for my $a (-24, 156) { huskear(200, 200, $a, 64, 12, silk => 30, slight => 'c3', sdark => 'c5', sn => 7); }
tassel(200, 200, 44, 8, 10, 'c2', 'c1');
write_svg('5-third-growth.svg', 'Corn third growth');

# 6. Harvest: full plant, golden tassel, three fat ears with husks parted to show yellow kernels.
soil(200, 200, 38, 34, 6);
plant(11, 168, 10, 46, 61, start => -128, twist => 33, bend => 26);
for my $a (-30, 90, 210) { my ($dx, $dy) = dir($a); openear(200 + $dx * 30, 200 + $dy * 30, $a, 112, 21); }
tassel(200, 200, 50, 9, 4, 'c3', 'c5');
write_svg('6-harvest.svg', 'Corn ready to harvest');

# 7. Harvested produce, front view: two ears, one in its husk with silk, one husked back to the kernels.
blade(222, 372, -76, 40, 20, 0, 'c2', 'c1');                                # shank of the husked ear
huskear(232, 346, -74, 244, 44, silk => 72, slight => 'c3', sdark => 'c5', sn => 13);
my ($ex, $ey, $ea) = (172, 318, -97);
for my $h ([150, 108, 34, 52], [30, 108, -34, 52], [122, 96, 22, 46], [58, 96, -22, 46]) {   # husk leaves folded back down
  strap($ex, $ey, $h->[0], $h->[1], $h->[3], $h->[2], 'c3', 'c2', rib => 0);
}
blade($ex + 2, $ey - 2, 92, 56, 22, 0, 'c2', 'c1');                         # stalk stub
my ($sx, $sy) = ($ex + 0.5, $ey + 54); poly('c3', ell($sx, $sy, 10.5, 3.6, 10, 2)); poly('c2', (ell($sx, $sy, 10.5, 3.6, 10, 2))[0 .. 5]);
for my $h ([104, 80, 12, 50], [76, 80, -12, 50]) { strap($ex, $ey, $h->[0], $h->[1], $h->[3], $h->[2], 'c2', 'c1', rib => 0); }
kernels($ex, $ey + 2, $ea, 236, 36, 0.02, 1, rows => 17, cols => 4);
write_svg('7-harvest-front.svg', 'Two ears of corn');

# 8. Dead (never watered): cracked soil, the stalk slumped, limp straw leaves lying flat, a shrivelled ear.
soil(200, 200, 56, 48, 8);
cracks(7, 83);
plant(8, 122, 26, 32, 81, start => -100, twist => 41, bend => 80, light => 'c3', dark => 'c4', rib => 'c4');
huskear(200, 200, 140, 60, 11, light => 'c3', dark => 'c4', hi => 'c3', silk => 16, slight => 'c4', sdark => 'c4', sn => 5);
stalktop(10, 'c3', 'c4');
write_svg('8-dead.svg', 'Corn died from lack of water');
print "wrote 8 files to $OUT\n";

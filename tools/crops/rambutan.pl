# Rambutan crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/rambutan.pl
# Grown as a compact bush. Top-down stages (2-6, 8) share one fixed scale centred on (200,200).
# Signature: clusters of red fruit covered in long soft hairs (spinterns) with green-yellow tips, glossy oval leaves.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/rambutan';
mkdir 'crops'; mkdir $OUT;
# c1 glossy leaf green, c2 lit green (also hair tips), c3 cream (flesh, flowers, dried leaves), c4 dark soil / shade, c5 rambutan red
my %PAL = (c1 => '#2F6A36', c2 => '#86BC4C', c3 => '#F5EEDB', c4 => '#4E2522', c5 => '#D8322E');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub ell { my ($x, $y, $rx, $ry, $n, $rot) = @_; $rot //= 0; map { my ($u, $v) = dir($rot + $_ * 360 / $n); [$x + $u * $rx, $y + $v * $ry] } 0 .. $n - 1 }

# A tapered blade / stalk / hair from (x,y) heading `ang`, bending `bend` degrees. $taper < 1 leaves a blunt end.
# Returns the end point and heading.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $taper) = @_;
  $taper //= 1;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $t) ** 0.85 + ($i == $n && $taper == 1 ? 0 : 0.5);
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
  my ($x, $y, $ang, $len, $bend, $t) = @_; my $n = 10; my $a = $ang;
  for (1 .. int($t * $n + 0.5)) { my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  ($x, $y, $a);
}

# Glossy elliptic leaf with a pointed (acuminate) tip on a short petiole: lit and shaded halves, a sunk midrib on
# the lit half and a pale glint along the shaded half so it reads shiny.
sub oleaf {
  my ($x, $y, $ang, $len, $w, $bend, $L, $D, %o) = @_;
  my $pf = $o{pf} // 0.1; my $n = 16; my (@mid, @l, @r, @hw, @dir);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a);
    my $u = $t < $pf ? 0 : ($t - $pf) / (1 - $pf);
    my $hw = $t < $pf ? 1.3 : $w / 2 * sin(pi * min(0.999, $u ** ($o{p} // 0.9))) ** ($o{q} // 0.75);
    $hw = 0 if $i == $n;
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py]; push @hw, $hw; push @dir, [$dx, $dy];
    last if $i == $n;
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $L : $D, @l, reverse @mid);
  poly($leftLit ? $D : $L, @r, reverse @mid);
  return if $o{plain};
  my $s = $leftLit ? -1 : 1;              # sign that points into the lit half
  my $i0 = int($n * ($pf + 0.08)); my $i1 = $n - 3;
  # midrib groove on the lit half
  poly($D, (map { my ($mx, $my) = @{$mid[$_]}; my ($ux, $uy) = @{$dir[$_]}; my $k = $o{rib} // 1.4; [$mx - $uy * $s * $k * (1 - ($_ - $i0) / ($i1 - $i0 + 2)), $my + $ux * $s * $k * (1 - ($_ - $i0) / ($i1 - $i0 + 2))] } $i0 .. $i1),
           $mid[$i1 + 1], reverse(@mid[$i0 .. $i1]));
  # side veins as thin grooves on the lit half
  for my $k (1 .. ($o{veins} // 0)) {
    my $i = int($i0 + ($i1 - $i0) * $k / (($o{veins}) + 1)); my ($mx, $my) = @{$mid[$i]}; my ($ux, $uy) = @{$dir[$i]};
    my $h = $hw[$i] * 0.8; my ($ex, $ey) = ($mx - $uy * $s * $h + $ux * $h * 0.7, $my + $ux * $s * $h + $uy * $h * 0.7);
    poly($D, [$mx - $ux * 1.1, $my - $uy * 1.1], [$ex, $ey], [$mx + $ux * 1.1, $my + $uy * 1.1]);
  }
  # glint on the shaded half
  unless ($o{noglint}) {
    my @g1; my @g2; my $ga = int($n * 0.28); my $gb = int($n * 0.72);
    for my $i ($ga .. $gb) {
      my ($mx, $my) = @{$mid[$i]}; my ($ux, $uy) = @{$dir[$i]}; my $v = sin(pi * ($i - $ga) / ($gb - $ga));
      my $c = $hw[$i] * 0.5; my $gw = $hw[$i] * 0.13 * $v + 0.2;
      push @g1, [$mx + $uy * $s * ($c - $gw), $my - $ux * $s * ($c - $gw)];
      push @g2, [$mx + $uy * $s * ($c + $gw), $my - $ux * $s * ($c + $gw)];
    }
    poly($o{glint} // $L, @g1, reverse @g2);
  }
}

# A rambutan: oval red fruit wrapped in long soft curling hairs with green-yellow tips.
# %o: ry, body/shade/tip/tipd colours, hairs (count of rim hairs), hl (hair length factor), seed.
sub rambu {
  my ($x, $y, $r, %o) = @_;
  my $ry = $o{ry} // $r * 1.06; my $rot = $o{rot} // 0;
  my $B = $o{body} // 'c5'; my $SH = $o{shade} // 'c4'; my $T = $o{tip} // 'c2'; my $TD = $o{tipd} // 'c1';
  my $hl = $o{hl} // 1; my $nh = $o{hairs} // 30;
  srand($o{seed} // int($x * 13 + $y * 7));
  my $E = sub { my ($u, $v) = @_; my ($c, $s) = dir($rot); [$x + $u * $c - $v * $s, $y + $u * $s + $v * $c] };
  # rim hairs (behind the body): curl outward, red base, coloured tip
  my $curl = (rand(1) < 0.5 ? -1 : 1);
  for my $k (0 .. $nh - 1) {
    my $th = 360 * $k / $nh + rand(10);
    my ($u, $v) = dir($th); my $b = $E->($u * $r * 0.82, $v * $ry * 0.82);
    my $oa = rad2deg(atan2($v * $r, $u * $ry)) + $rot;      # outward heading on screen
    my $sun = (cos(deg2rad($oa)) * 0.7071 + sin(deg2rad($oa)) * 0.7071) > 0.25;  # facing away from the light
    my $len = $r * 0.58 * $hl * (0.85 + rand(0.3)); my $bend = $curl * (40 + rand(40));
    my ($ex, $ey, $ea) = blade(@$b, $oa - $curl * 18, $len * 0.62, $r * 0.24, $bend * 0.6, $sun ? $SH : $B, $SH, 0.55);
    blade($ex, $ey, $ea, $len * 0.42, $r * 0.12, $bend * 0.6, $sun ? $TD : $T, $TD);
  }
  # body with a shaded crescent toward the lower right
  my @o = map { my ($u, $v) = dir($_ * 15); $E->($u * $r, $v * $ry) } 0 .. 23;
  poly($B, @o);
  my @on = grep { my ($u, $v) = dir($_ * 15 + $rot); ($u * 0.7071 + $v * 0.7071) > 0.12 } 0 .. 23;
  my %on = map { $_ => 1 } @on; my ($st) = grep { $on{$_} && !$on{($_ + 23) % 24} } 0 .. 23; $st //= 0;
  my @shp; for my $j (0 .. 23) { my $i = ($st + $j) % 24; last unless $on{$i}; push @shp, $o[$i]; }
  my $off = $r * 0.14;
  poly($SH, @shp, map { [$x + ($_->[0] - $x) * 0.7 + $off * 0.7071, $y + ($_->[1] - $y) * 0.7 + $off * 0.7071] } reverse @shp);
  # surface hairs: short curling strokes rooted all over the skin (back to front), tips catching the light
  my $s = $r * ($o{sp} // 0.32); my @d; my $row = 0;
  for (my $gy = -$ry; $gy <= $ry; $gy += $s * 0.86) {
    for (my $gx = -$r - ($row % 2 ? $s / 2 : 0); $gx <= $r; $gx += $s) {
      my $r2 = ($gx / $r) ** 2 + ($gy / $ry) ** 2; next if $r2 > 0.62;
      push @d, [$gx + rand($s * 0.3) - $s * 0.15, $gy + rand($s * 0.3) - $s * 0.15, $r2];
    }
    $row++;
  }
  for (sort { $a->[2] <=> $b->[2] } @d) {
    my ($gx, $gy, $r2) = @$_;
    my $p = $E->($gx, $gy);
    my $oa = (abs($gx) + abs($gy) < 0.01 ? rand(360) : rad2deg(atan2($gy * $r / $ry, $gx)) + $rot);
    my $len = $s * (0.55 + 0.75 * sqrt($r2)) * $hl;
    my $shade = ($gx / $r + $gy / $ry) * 0.7071 > 0.45;
    my $bend = $curl * (50 + rand(40));
    my ($ex, $ey, $ea) = blade(@$p, $oa - $curl * 30, $len * 0.6, $s * 0.42, $bend * 0.6, $B, $SH, 0.55);
    blade($ex, $ey, $ea, $len * 0.45, $s * 0.24, $bend * 0.5, $shade ? $TD : $T, $TD) unless $o{notips} && !$shade;
  }
}

# Opened rambutan, front view: the hairy lower shell cup with the translucent white fruit sitting in it.
sub rambu_open {
  my ($x, $y, $r) = @_;
  my $rr = $r * 0.32;                        # rim ellipse half-height (the cut edge seen from slightly above)
  srand(int($x));
  # hairs sticking out of the bowl, behind it
  for my $k (0 .. 16) {
    my $th = -4 + $k * 188 / 16 + rand(6);
    my ($u, $v) = dir($th); my $bx = $x + $u * $r * 0.9; my $by = $y + $v * $r * 0.78;
    my $oa = $th + 8; my $sun = (cos(deg2rad($oa)) * 0.7071 + sin(deg2rad($oa)) * 0.7071) > 0.25;
    my ($ex, $ey, $ea) = blade($bx, $by, $oa - 18, $r * 0.34, $r * 0.24, 34, $sun ? 'c4' : 'c5', 'c4', 0.55);
    blade($ex, $ey, $ea, $r * 0.24, $r * 0.12, 30, $sun ? 'c1' : 'c2', 'c1');
  }
  # the far half of the rim: dark inside of the shell
  poly('c4', ell($x, $y, $r, $rr, 24));
  # the fruit: a translucent white egg standing in the shell
  my ($fx, $fy, $fr, $fry) = ($x + $r * 0.02, $y - $r * 0.36, $r * 0.7, $r * 0.84);
  my @f = ell($fx, $fy, $fr, $fry, 24, 0);
  poly('c3', @f);
  my @sh = @f[20 .. 23, 0 .. 6];
  poly("c2", @sh, map { [$fx + ($_->[0] - $fx) * 0.84 + $fr * 0.04, $fy + ($_->[1] - $fy) * 0.9 + $fr * 0.02] } reverse @sh);
  # front of the shell: between the near rim arc and the bowl bottom
  my @rim = map { my ($u, $v) = dir($_ * 15); [$x + $u * $r, $y + $v * $rr] } 0 .. 12;
  my @bot = map { my ($u, $v) = dir($_ * 15); [$x + $u * $r, $y + $v * $r * 0.82] } reverse 0 .. 12;
  poly('c5', @rim, @bot);
  my @bs = map { my ($u, $v) = dir($_ * 15); [$x + $u * $r, $y + $v * $r * 0.82] } 0 .. 7;
  poly('c4', @bs, map { [$x + ($_->[0] - $x) * 0.74 + $r * 0.1, $y + ($_->[1] - $y) * 0.6 + $r * 0.12] } reverse @bs);
  # the pale cut edge of the inner skin along the near rim
  poly('c3', @rim, map { [$_->[0], $_->[1] + $r * 0.06 * (1 - abs($_->[0] - $x) / $r)] } reverse @rim);
  # surface hairs on the outside wall
  for my $k (0 .. 10) {
    my $u = -0.8 + $k * 0.16; my $v = 0.42 + ($k % 2) * 0.2 - abs($u) * 0.12;
    my $px = $x + $u * $r; my $py = $y + $v * $r;
    my $oa = 90 + $u * 70; my $dark = ($u + $v) > 0.75;
    my ($ex, $ey, $ea) = blade($px, $py, $oa - 30, $r * 0.2, $r * 0.13, 60, 'c5', 'c4', 0.55);
    blade($ex, $ey, $ea, $r * 0.15, $r * 0.07, 50, $dark ? 'c1' : 'c2', 'c1');
  }
}

# Rambutan seed: an oval flattened brown-cream seed with a dark half.
sub seed {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 17) {
    my $th = 2 * pi * $i / 18; my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 - 0.12 * cos($th));
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly("c3", @o);
  my $leftLit = lit($nx, $ny);
  my @half = $leftLit ? @o[10 .. 17] : @o[1 .. 8];
  my $sg = $leftLit ? -1 : 1;
  poly("c4", @half, map { [$x + ($_->[0] - $x) * 0.6 + $nx * $sg * $w * 0.12, $y + ($_->[1] - $y) * 0.55 + $ny * $sg * $w * 0.12] } reverse @half);
  # dark hilum scar at one end
  poly("c4", ell($x - $dx * $len * 0.36, $y - $dy * $len * 0.36, $w * 0.16, $w * 0.16, 8));
}

# Tiny cream flower panicle: a short spray of small round buds.
sub panicle {
  my ($x, $y, $ang, $len) = @_;
  for my $sp (-28, 0, 28) {
    my $l = $len * ($sp ? 0.75 : 1);
    my ($ex, $ey) = blade($x, $y, $ang + $sp, $l, 3, $sp * 0.4, "c2", "c1");
    for my $k (0 .. 4) {
      my ($px, $py, $pa) = walk($x, $y, $ang + $sp, $l, $sp * 0.4, 0.4 + $k * 0.13);
      my $side = $k % 2 ? 1 : -1; my ($dx, $dy) = dir($pa + $side * 70);
      my ($bx, $by) = ($px + $dx * 5, $py + $dy * 5);
      poly("c3", ell($bx, $by, 4.4, 4.4, 7)); poly("c2", ell($bx + 1.2, $by + 1.2, 1.6, 1.6, 5));
    }
    poly("c3", ell($ex, $ey, 4.8, 4.8, 7)); poly("c2", ell($ex + 1.2, $ey + 1.2, 1.7, 1.7, 5));
  }
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

# Top-down bush: woody branches from the crown carrying pairs of glossy leaflets; returns branch paths.
# Leaves are drawn outer-first so the canopy domes up toward the middle.
sub bush {
  my (%o) = @_;
  srand($o{seed});
  my ($L, $D) = ($o{light} // 'c2', $o{dark} // 'c1');
  my (@leaves, @br);
  my $nb = $o{n};
  for my $i (0 .. $nb - 1) {
    my $a = ($o{start} // -90) + $i * 360 / $nb + rand(14) - 7;
    my $len = $o{len} * (0.86 + rand(0.2)); my $bend = (rand(1) < 0.5 ? -1 : 1) * (12 + rand(16));
    push @br, [$a, $len, $bend];
    my $per = $o{per};
    for my $k (1 .. $per) {
      my $t = 0.25 + 0.7 * $k / $per;
      my ($px, $py, $pa) = walk(200, 200, $a, $len, $bend, $t);
      for my $side (-1, 1) {
        my $ll = $o{leaf} * (0.8 + 0.3 * $t + rand(0.12));
        push @leaves, [$px, $py, $pa + $side * (44 + rand(18)), $ll, $ll * ($o{wf} // 0.42), $side * ($o{curl} // 10) * (0.5 + rand(1))];
      }
    }
    my ($px, $py, $pa) = walk(200, 200, $a, $len, $bend, 1);
    my $ll = $o{leaf} * 1.12;
    push @leaves, [$px, $py, $pa + rand(10) - 5, $ll, $ll * ($o{wf} // 0.42), rand(12) - 6];
  }
  push @leaves, @{$o{extra} // []};
  blade(200, 200, $_->[0], $_->[1], $o{bw} // 8, $_->[2], $o{blight} // 'c1', $o{bdark} // 'c4', 0.6) for @br;
  for (sort { (($b->[0] - 200) ** 2 + ($b->[1] - 200) ** 2) <=> (($a->[0] - 200) ** 2 + ($a->[1] - 200) ** 2) } @leaves) {
    oleaf(@$_, $L, $D, %{$o{lo} // {}});
  }
  @br;
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a ripe rambutan behind three oval seeds.
rambu(250, 168, 78, hairs => 30, seed => 3, rot => 10);
seed(112, 292, -34, 80, 50); seed(200, 322, -4, 86, 54); seed(288, 300, 30, 80, 50);
write_svg('1-seeds-front.svg', 'Rambutan seeds');

# 2. Just sown, top down: big seeds pressed into soil pockets.
my @sown = ([168, 172, -30], [238, 178, 40], [196, 236, 100]);
for (@sown) { soil($_->[0], $_->[1], 36, 30, int($_->[0] * 7 + $_->[1])); }
for (@sown) { seed($_->[0], $_->[1], $_->[2], 42, 27); }
write_svg('2-sown.svg', 'Rambutan just sown');

# 3. First growth, top down: a sapling with a few glossy leaves.
soil(200, 200, 34, 30, 3);
blade(200, 200, -120, 18, 6, 0, 'c1', 'c4', 0.5);
oleaf(200, 200, -60, 88, 36, 10, 'c2', 'c1'); oleaf(200, 200, 125, 84, 34, -12, 'c2', 'c1');
oleaf(200, 200, -165, 66, 28, 8, 'c2', 'c1'); oleaf(200, 200, 40, 68, 28, -8, 'c2', 'c1');
write_svg('3-first-growth.svg', 'Rambutan first growth');

# 4. Second growth, top down: young bush.
soil(200, 200, 34, 30, 4);
bush(seed => 41, n => 6, len => 70, per => 2, leaf => 50, start => -80);
write_svg('4-second-growth.svg', 'Rambutan second growth');

# 5. Third growth, top down: full bush with cream flower sprays and small green hairy fruit.
soil(200, 200, 34, 30, 5);
{
  my @br = bush(seed => 51, n => 8, len => 96, per => 3, leaf => 56, start => -84);
  my $j = 0;
  for my $bb (@br) {
    my ($x, $y, $a) = walk(200, 200, @$bb, 0.82); $j++;
    my ($dx, $dy) = dir($a + ($j % 2 ? 60 : -60));
    if ($j % 2) { panicle($x, $y, $a + ($j % 4 ? 40 : -40), 34); }
    else {
      rambu($x + $dx * 14, $y + $dy * 14, 11, body => 'c2', shade => 'c1', tip => "c5", tipd => "c1", hairs => 12, hl => 0.8);
      rambu($x + $dx * 16 + $dy * 16, $y + $dy * 16 - $dx * 16, 10, body => 'c2', shade => 'c1', tip => "c5", tipd => 'c1', hairs => 12, hl => 0.8);
    }
  }
}
write_svg('5-third-growth.svg', 'Rambutan third growth, flowering');

# 6. Harvest, top down: the bush laden with clusters of ripe hairy red rambutans.
soil(200, 200, 34, 30, 6);
{
  my @br = bush(seed => 61, n => 8, len => 116, per => 3, leaf => 58, start => -76);
  srand(66);
  my $j = 0;
  for my $bb (@br) {
    my ($x, $y, $ba) = walk(200, 200, @$bb, 0.66); $j++;
    my @c = ([0, 0], [26, -15], [27, 17]);
    @c = @c[0 .. 1] if $j % 3 == 0;
    my @f;
    for (@c) { my ($dx, $dy) = dir($ba); push @f, [$x + $dx * $_->[0] - $dy * $_->[1], $y + $dy * $_->[0] + $dx * $_->[1]]; }
    blade($x - 12 * cos(deg2rad($ba)), $y - 12 * sin(deg2rad($ba)), $ba, 40, 3.5, 0, 'c2', 'c1');
    rambu(@$_, 19, hairs => 18, seed => int($_->[0] * 3 + $_->[1])) for sort { $a->[1] <=> $b->[1] } @f;
  }
  rambu(196, 192, 15, hairs => 14); rambu(214, 208, 14, hairs => 14);
}
write_svg('6-harvest.svg', 'Rambutans ready to harvest');

# 7. Harvested produce, front view: two hairy red rambutans and one opened to show the white flesh.
rambu(132, 176, 72, hairs => 22, seed => 71, rot => -14);
rambu(272, 168, 70, hairs => 22, seed => 72, rot => 12);
rambu_open(204, 284, 70);
write_svg('7-harvest-front.svg', 'Harvested rambutans');

# 8. Dead (never watered), top down: cracked dry soil, bare brittle branches, curled dry leaves, shrivelled fruit.
soil(200, 200, 66, 56, 8);
cracks(8, 83, 14, 'c3');
{
  srand(84);
  my @br;
  for my $i (0 .. 5) { push @br, [-80 + $i * 60 + rand(14) - 7, 86 + rand(30), (rand(1) < 0.5 ? -1 : 1) * (30 + rand(30))]; }
  blade(200, 200, $_->[0], $_->[1], 7, $_->[2], 'c3', 'c4', 0.7) for @br;
  my $j = 0;
  for my $bb (@br) {
    for my $t (0.35, 0.62, 0.9) {
      my ($px, $py, $pa) = walk(200, 200, @$bb, $t); my $s = ($j++ % 2) ? 1 : -1;
      oleaf($px, $py, $pa + $s * (60 + rand(30)), 44 + rand(10), 13 + rand(4), $s * (40 + rand(40)), 'c3', 'c4', noglint => 1);
    }
  }
  for my $k (1, 4) { my ($px, $py) = walk(200, 200, @{$br[$k]}, 0.95); rambu($px, $py, 9, body => 'c4', shade => 'c4', tip => 'c3', tipd => 'c4', hairs => 10, hl => 0.6, notips => 1); }
}
write_svg('8-dead.svg', 'Rambutan died from lack of water');
print "wrote 8 files to $OUT\n";

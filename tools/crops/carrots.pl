# Carrot crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/carrots.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/carrots';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#3A7A2E', c2 => '#86C44E', c3 => '#FCE6B4', c4 => '#5A3422', c5 => '#F27B1C');
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
sub seg {
  my ($x, $y, $ang, $len, $w, $light, $dark) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @b = ($x, $y); my @t = ($x + $dx * $len, $y + $dy * $len);
  my @m = ($x + $dx * $len * 0.38, $y + $dy * $len * 0.38);
  my $lLit = lit($nx, $ny);
  poly($lLit ? $light : $dark, [@b], [$m[0] + $nx * $w / 2, $m[1] + $ny * $w / 2], [@t]);
  poly($lLit ? $dark : $light, [@b], [$m[0] - $nx * $w / 2, $m[1] - $ny * $w / 2], [@t]);
}

# A lacy pinna: thin rachis with pairs of slim segments and a terminal segment.
sub lpinna {
  my ($x, $y, $ang, $len, $w, $light, $dark, $m, $curl) = @_; $curl //= 0;
  my ($dx, $dy) = dir($ang);
  blade($x, $y, $ang, $len * 0.8, 3.2, 0, $light, $dark);
  for my $k (reverse 1 .. $m) {
    my $t = 0.12 + 0.62 * ($k - 1) / max(1, $m - 1) * ($m > 1 ? 1 : 0) + ($m == 1 ? 0.3 : 0);
    my $sl = $len * 0.5 * (1 - 0.5 * $t);
    for my $side (-1, 1) { seg($x + $dx * $len * $t, $y + $dy * $len * $t, $ang + $side * 46 + $curl, $sl, $w * (1 - 0.4 * $t), $light, $dark); }
  }
  seg($x + $dx * $len * 0.62, $y + $dy * $len * 0.62, $ang + $curl, $len * 0.42, $w * 0.8, $light, $dark);
}

# A feathery carrot frond: long bare petiole, then a broad triangular blade of lacy pinnae.
sub frond {
  my ($x, $y, $ang, $len, $bend, $light, $dark, %o) = @_;
  my $bare = $o{bare} // 0.36; my $pk = $o{pk} // 0.34; my $sw = $o{sweep} // 50; my $np = $o{np} // 4;
  my $wk = $o{wk} // 0.3; my $curl = $o{curl} // 0; my $m = $o{sub} // 3;
  my @p = path($x, $y, $ang, $len, $bend, 40);
  blade($x, $y, $ang, $len * 0.9, $o{rw} // 4.4, $bend, $light, $dark);
  for my $i (reverse 0 .. $np - 1) {
    my $u = $i / $np; my $t = $bare + (0.86 - $bare) * $u; my ($px, $py, $pa) = @{$p[int($t * 40)]};
    my $pl = $len * $pk * (1 - $u) ** 0.7 + $len * 0.06;
    for my $side (-1, 1) {
      lpinna($px, $py, $pa + $side * $sw + $curl, $pl, max(7, $pl * $wk), $light, $dark, max(1, $m - int($u * $m * 0.8 + 0.2)), $curl * 0.5);
    }
  }
  my ($tx, $ty, $ta) = @{$p[34]};
  lpinna($tx, $ty, $ta, $len * 0.16, max(7, $len * 0.05), $light, $dark, 1);
}

# Small irregular patch of soil.
sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o;
  srand($seed);
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12; my $k = 0.82 + rand(0.3); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
}

# Carrot shoulder seen from above: a round orange top with a shadow rim, a lit crescent and a green crown.
sub shoulder {
  my ($x, $y, $r, %o) = @_;
  my $body = $o{body} // 'c5';
  poly('c4', ell($x + $r * 0.12, $y + $r * 0.12, $r * 1.04, $r * 1.04, 16));
  poly($body, ell($x, $y, $r, $r, 16));
  my @a = ell($x, $y, $r * 0.8, $r * 0.8, 16);
  poly($o{hi} // 'c3', @a[8 .. 12], [$x - $r * 0.25, $y - $r * 0.25]);          # lit crescent (upper left)
  my @rg = ell($x, $y, $r * 0.62, $r * 0.62, 16);                                    # faint growth ring
  poly('c4', @rg[0 .. 4], reverse map { [$x + ($_->[0] - $x) * 0.9, $y + ($_->[1] - $y) * 0.9] } @rg[0 .. 4]) unless $o{noring};
  poly($o{crown} // 'c1', ell($x, $y, $r * 0.36, $r * 0.36, 10, 10));
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


# A carrot seed: small flat ridged oval fringed with bristly spines.
sub cseed {
  my ($x, $y, $ang, $len, $w, $bk) = @_; $bk //= 0.34;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 15) {
    my $th = 2 * pi * $i / 16; my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 - 0.25 * cos($th) ** 2);
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  for my $i (2 .. 6, 10 .. 14) {                                           # spines along both ribs
    my ($px, $py) = @{$o[$i]}; my ($ox, $oy) = ($px - $x, $py - $y); my $d = sqrt($ox * $ox + $oy * $oy) || 1;
    ($ox, $oy) = ($ox / $d, $oy / $d); my $bw = max(0.8, $w * 0.05);
    poly('c4', [$px - $oy * $bw, $py + $ox * $bw], [$px + $ox * $w * $bk + $dx * $w * 0.08, $py + $oy * $w * $bk + $dy * $w * 0.08], [$px + $oy * $bw, $py - $ox * $bw]);
  }
  poly('c4', @o);
  my $lLit = lit($nx, $ny);
  my @half = $lLit ? @o[0 .. 8] : @o[8 .. 15, 0];
  poly('c3', @half);
  my $rw = max(0.7, $w * 0.045);
  for my $s ($lLit ? (0.36, 0.7) : (-0.36, -0.7)) {                     # longitudinal ridges on the lit half
    my $off = $s * $w * 0.42; my $sl = $len * 0.38 * (1 - abs($s) * 0.35);
    my $onLit = ($s == 0) ? 0 : (($s > 0) == ($lLit ? 1 : 0));
    my @c = ([$x - $dx * $sl + $nx * $off, $y - $dy * $sl + $ny * $off], [$x + $dx * $sl + $nx * $off, $y + $dy * $sl + $ny * $off]);
    poly('c4', [$c[0][0] + $nx * $rw, $c[0][1] + $ny * $rw], [$c[1][0] + $nx * $rw, $c[1][1] + $ny * $rw], [$c[1][0] - $nx * $rw, $c[1][1] - $ny * $rw], [$c[0][0] - $nx * $rw, $c[0][1] - $ny * $rw]);
  }
}

# The three carrots of one planting sit in a small triangle.
my @P = ([200, 171], [174, 216], [226, 216]);

# 1. Seeds, front view: a small heap of ridged, bristly carrot seeds.
for my $s ([136, 282, -8], [196, 290, 6], [258, 284, 186], [166, 246, -24], [228, 246, 200], [198, 210, -70], [112, 300, 10], [284, 300, 172]) {
  next if $s->[0] < 120 || $s->[0] > 280;
  cseed($s->[0], $s->[1], $s->[2], 66, 38);
}
write_svg('1-seeds-front.svg', 'Carrot seeds');

# 2. Just sown, top down: a pinch of seeds pressed into three soil pockets.
my @sown = ([200, 164], [164, 226], [238, 224]);
for (@sown) { soil($_->[0], $_->[1], 30, 25, int($_->[0] * 7 + $_->[1])); }
for (@sown) { my ($x, $y) = @$_; cseed($x - 8, $y - 5, -30, 22, 13); cseed($x + 9, $y + 1, 50, 22, 13); cseed($x - 2, $y + 10, 170, 21, 12); }
write_svg('2-sown.svg', 'Carrots just sown');

# Leaves for a clump: each frond grows from the crown nearest its direction.
sub clump {
  my ($n, $len, $var, $seed, %o) = @_; srand($seed); my @f;
  for my $i (0 .. $n - 1) {
    my $ang = ($o{start} // -90) + $i * 360 / $n + rand(14) - 7; my ($dx, $dy) = dir($ang);
    my ($c) = sort { ($b->[0] - 200) * $dx + ($b->[1] - 200) * $dy <=> ($a->[0] - 200) * $dx + ($a->[1] - 200) * $dy } @P;
    push @f, [$c->[0], $c->[1], $ang, $len + rand($var), (rand(1) < 0.5 ? -1 : 1) * (6 + rand($o{bend} // 12))];
  }
  frond(@$_, $o{light} // 'c2', $o{dark} // 'c1', %o) for sort { $b->[3] <=> $a->[3] } @f;
}

# Leaf stalks fanning out of a crown (drawn over the shoulder).
sub stalks {
  my ($c, $r, $w, $light, $dark, @ang) = @_;
  for my $a (@ang) { blade(@$c, $a, $r, $w, 0, $light, $dark); }
}
sub outward { my $c = shift; rad2deg(atan2($c->[1] - 200, $c->[0] - 200)) }

# 3. First growth: three seedlings, each with a pair of grassy seed leaves and a first small feathery leaf.
soil(200, 200, 36, 32, 3);
for my $k (0 .. 2) {
  my $c = $P[$k]; my $a = outward($c);
  blade(@$c, $a + 75, 36, 7, 14, 'c2', 'c1'); blade(@$c, $a - 75, 36, 7, -14, 'c2', 'c1');
  frond(@$c, $a + 8, 64, 8, 'c2', 'c1', np => 2, sub => 2, bare => 0.34, pk => 0.42);
}
write_svg('3-first-growth.svg', 'Carrot first growth');

# 4. Second growth: young feathery rosettes on long stalks.
soil(200, 200, 38, 34, 4);
clump(11, 84, 18, 41, np => 3, sub => 2);
write_svg('4-second-growth.svg', 'Carrot second growth');

# 5. Third growth: full lacy tops, orange crowns just showing.
soil(200, 200, 42, 38, 5);
clump(14, 106, 20, 51, np => 4, sub => 3);
for my $c (@P) { shoulder(@$c, 13); my $o = outward($c); stalks($c, 17, 4.4, "c2", "c1", $o - 30, $o, $o + 30); poly('c1', ell(@$c, 4, 4, 8)); }
write_svg('5-third-growth.svg', 'Carrot third growth');

# 6. Harvest: lush tops and fat orange shoulders pushing up out of the soil.
soil(200, 200, 60, 54, 6);
clump(18, 126, 22, 61, np => 4, sub => 2, wk => 0.36);
for my $c (@P) { shoulder(@$c, 25); }
for my $c (@P) { my $o = outward($c); stalks($c, 34, 5.5, "c2", "c1", $o - 36, $o - 12, $o + 12, $o + 36); poly('c1', ell(@$c, 6, 6, 8)); }
write_svg('6-harvest.svg', 'Carrots ready to harvest');

# 7. Harvested produce, front view: a bunch of three carrots with their green tops.
sub carrot {
  my ($x, $y, $ang, $len, $w, $bend) = @_;
  my @p = path($x, $y, $ang, $len, $bend, 24); my (@l, @r);
  for my $i (0 .. 24) {
    my $t = $i / 24; my ($px, $py, $a) = @{$p[$i]}; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * ($t < 0.08 ? sqrt(0.4 + 0.6 * $t / 0.08) : (1 - ($t - 0.08) / 0.92) ** 0.75) + ($i == 24 ? 0 : 0.5);
    push @l, [$px - $dy * $hw, $py + $dx * $hw, $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw, $hw];
  }
  my ($dx, $dy) = dir($ang); my $lLeft = lit($dy, -$dx);
  my @L = $lLeft ? @r : @l; my @D = $lLeft ? @l : @r;
  my $f = sub { my ($E, $i, $k) = @_; [$E->[$i][0] + ($p[$i][0] - $E->[$i][0]) * $k, $E->[$i][1] + ($p[$i][1] - $E->[$i][1]) * $k] };
  poly('c5', (map { [@$_[0, 1]] } @l), reverse map { [@$_[0, 1]] } @r);
  poly('c4', (map { [@$_[0, 1]] } @D[1 .. 23]), reverse map { $f->(\@D, $_, 0.3) } 1 .. 23);      # shaded edge
  poly('c3', (map { $f->(\@L, $_, 0.2) } 2 .. 14), reverse map { $f->(\@L, $_, 0.46) } 3 .. 13);  # lit stripe
  for my $k (0 .. 6) {                                                   # growth-ring grooves and rootlets
    my $j = int(4 + $k * 2.5); my ($px, $py, $a) = @{$p[$j]}; my ($ex, $ey) = dir($a);
    my $side = $k % 2 ? 1 : -1; my $hw = $l[$j][2]; my ($sx, $sy) = (-$ey * $side, $ex * $side);
    my @g = ([$px + $sx * $hw * 0.98, $py + $sy * $hw * 0.98], [$px - $sx * $hw * 0.2, $py - $sy * $hw * 0.2]);
    poly('c4', [$g[0][0] - $ex * 1.8, $g[0][1] - $ey * 1.8], [$g[1][0], $g[1][1]], [$g[0][0] + $ex * 1.8, $g[0][1] + $ey * 1.8]);
    blade($g[0][0], $g[0][1], $a + $side * 64, 8 + $hw * 0.3, 2.4, $side * 14, 'c5', 'c4') if $k % 3 == 1;
  }
  my @top = ell($x, $y, $l[0][2], $w * 0.14, 12, $ang + 90);
  poly('c5', @top); poly('c4', @top[0 .. 6]);
}
my @roots = ([164, 168, 104, 178, 58, 10], [236, 168, 76, 178, 58, -10], [200, 160, 90, 196, 62, 0]);
for my $i (0, 1, 2) {                                                      # fronds rise from each crown
  my ($x, $y) = @{$roots[$i]}[0, 1]; my $sh = ($x - 200) / 36;
  for my $f ([-148, 108, 18], [-116, 132, 8], [-88, 140, 0], [-60, 128, -8], [-30, 104, -18]) {
    frond($x, $y - 4, $f->[0] + $sh * 14, $f->[1], $f->[2] + $sh * 4, 'c2', 'c1', np => 4, sub => 3, bare => 0.38, pk => 0.36);
  }
}
for my $i (0, 1, 2) {
  my ($x, $y, $a, $len, $w, $b) = @{$roots[$i]};
  for my $s (-112, -90, -68) { blade($x, $y + 2, $s + ($x - 200) * 0.3, 26, 7, 0, 'c2', 'c1'); }
  carrot($x, $y, $a, $len, $w, $b);
}
write_svg('7-harvest-front.svg', 'Bunch of harvested carrots');

# 8. Dead (never watered): cracked dry soil, limp brittle fronds lying flat, three shrivelled crowns.
soil(200, 200, 56, 48, 8);
cracks(7, 83);
clump(11, 88, 26, 81, np => 3, sub => 2, light => 'c3', dark => 'c4', bend => 70, curl => 22);
for my $c (@P) { shoulder(@$c, 10, body => 'c4', hi => 'c3', crown => 'c4', noring => 1); my $o = outward($c);
  for my $a ($o - 40, $o + 140) { blade(@$c, $a, 24, 5, 60, 'c3', 'c4'); } }
write_svg('8-dead.svg', 'Carrots died from lack of water');
print "wrote 8 files to $OUT\n";

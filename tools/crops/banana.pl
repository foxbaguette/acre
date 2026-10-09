# Banana plant crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/banana.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Look: fresh green, long slender wind-torn leaves in a swirling star; ripe yellow bunch draped out to one side
# with many hands of slim curved fingers and the maroon bell at its tip. (Blue Java is the broad, whole-leaf,
# silver-blue counterpart with a short fat bunch.)
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/banana';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#3A8A3C', c2 => '#86CB52', c3 => '#FCEDA4', c4 => '#5A3424', c5 => '#F5C431');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub ell { my ($x, $y, $rx, $ry, $n, $rot) = @_; $rot //= 0; map { my ($u, $v) = dir($rot + $_ * 360 / $n); [$x + $u * $rx, $y + $v * $ry] } 0 .. $n - 1 }

# Points [x, y, heading] along a bent path.
sub path {
  my ($x, $y, $ang, $len, $bend, $n) = @_; $n //= 10; my @p; my $a = $ang;
  for my $i (0 .. $n) { push @p, [$x, $y, $a]; my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  @p;
}

# A tapered blade (sword leaf, stalk, root) as in wheat: lit and shaded halves.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $pow) = @_; $pow //= 0.85;
  my $n = 10; my (@l, @r, @m);
  for my $p (path($x, $y, $ang, $len, $bend, $n)) {
    my $i = @m; my $t = $i / $n; my ($dx, $dy) = dir($p->[2]);
    my $hw = $w / 2 * (1 - $t) ** $pow + ($i == $n ? 0 : 0.6);
    push @l, [$p->[0] - $dy * $hw, $p->[1] + $dx * $hw]; push @r, [$p->[0] + $dy * $hw, $p->[1] - $dx * $hw]; push @m, [@$p[0, 1]];
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @m);
  poly($leftLit ? $dark : $light, @r, reverse @m);
}

# A banana leaf from the crown: petiole (fraction $pf of the length), then a long oblong blade with a blunt
# rounded tip, a pale midrib and wind tears (V slits running along the side veins) at the given positions.
# %o: tearsL/tearsR = [u, depth] lists (u = 0..1 along the blade), veins => 1 for side-vein stripes.
sub bleaf {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, %o) = @_;
  my $pf = $o{pf} // 0.2; my $N = 30;
  my @p = path($x, $y, $ang, $len, $bend, $N);
  my $hw = sub {
    my $t = shift; return $w * 0.07 if $t <= $pf;
    my $u = ($t - $pf) / (1 - $pf);
    my $b = $u < 0.18 ? sin(pi / 2 * $u / 0.18) ** 0.8 : 1;              # rounded leaf base
    my $e = $u > 0.72 ? (1 - (($u - 0.72) / 0.28) ** 2.2) ** 0.5 : 1;    # blunt rounded tip
    return max($w * 0.07, $w / 2 * $b * $e * (1 - 0.12 * $u));
  };
  my $at = sub {                                                       # point on the leaf at t, side s, frac f
    my ($t, $s, $f) = @_; my $k = $t * $N; my $i = int($k); $i = $N - 1 if $i >= $N; my $fr = $k - $i;
    my ($a, $b) = ($p[$i], $p[$i + 1]);
    my $mx = $a->[0] + ($b->[0] - $a->[0]) * $fr; my $my = $a->[1] + ($b->[1] - $a->[1]) * $fr;
    my ($dx, $dy) = dir($a->[2]); my $h = $hw->($t) * $f;
    [$mx - $s * $dy * $h, $my + $s * $dx * $h];
  };
  my %tear = (1 => $o{tearsL} // [], -1 => $o{tearsR} // []);
  my ($dx0, $dy0) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy0, $dx0);
  for my $s (1, -1) {
    my @edge; my @tears = sort { $a->[0] <=> $b->[0] } @{ $tear{$s} };
    for my $i (0 .. $N) {
      my $t = $i / $N;
      while (@tears && $pf + $tears[0][0] * (1 - $pf) <= $t) {
        my ($u, $d) = @{ shift @tears }; my $tt = $pf + $u * (1 - $pf);
        push @edge, $at->($tt - 0.012, $s, 1), $at->($tt - 0.05 * $d, $s, 1 - $d), $at->($tt + 0.012, $s, 1);
      }
      push @edge, $at->($t, $s, 1);
    }
    my @mid = map { $at->($_ / $N, 0, 0) } 0 .. $N;
    my $isLit = ($s == 1) == $leftLit;
    poly($isLit ? $light : $dark, @edge, reverse @mid);
    if ($o{veins} && $isLit) {                                          # faint side veins on the lit half
      for (my $u = 0.16; $u < 0.86; $u += 0.11) {
        my $t = $pf + $u * (1 - $pf);
        my ($q0, $q1, $q2) = ($at->($t, $s, 0.12), $at->($t + 0.045, $s, 0.92), $at->($t + 0.05, $s, 0.92));
        poly($dark, $q0, $q1, $q2);
      }
    }
  }
  # pale midrib along the whole leaf
  my $mw = $o{rib} // 1.6; my (@ml, @mr);
  for my $i (0 .. $N - 2) { my $t = $i / $N; my ($dx, $dy) = dir($p[$i][2]); my $h = $mw * (1 - 0.6 * $t);
    push @ml, [$p[$i][0] - $dy * $h, $p[$i][1] + $dx * $h]; push @mr, [$p[$i][0] + $dy * $h, $p[$i][1] - $dx * $h]; }
  poly($o{ribc} // 'c3', @ml, reverse @mr);
}

# One banana finger: stem end at (x,y), heading ang, curving by bend. Slim body with a lit half,
# a green-tinged neck and a dark blunt tip.
sub finger {
  my ($x, $y, $ang, $len, $w, $bend, %o) = @_;
  my $N = 14; my @p = path($x, $y, $ang, $len, $bend, $N); my (@l, @r, @hl, @hr);
  my ($dx0, $dy0) = dir($ang + $bend / 2);
  my $ls = lit(-$dy0, $dx0) ? 1 : -1;                                  # which side faces the light
  for my $i (0 .. $N) {
    my $t = $i / $N; my ($dx, $dy) = dir($p[$i][2]);
    my $hw = $t < 0.14 ? $w * 0.15 : $w / 2 * (1 - ((($t - 0.14) / 0.86) * 2 - 1) ** 4) ** 0.45;
    $hw = max($hw, $w * 0.12);
    push @l, [$p[$i][0] - $dy * $hw, $p[$i][1] + $dx * $hw]; push @r, [$p[$i][0] + $dy * $hw, $p[$i][1] - $dx * $hw];
    if ($t >= 0.2 && $t <= 0.86) {                                     # glossy highlight strip on the lit side
      my ($a, $b) = ($o{hin} // 0.12, $o{hout} // 0.72);
      push @hl, [$p[$i][0] - $ls * $dy * $hw * $a, $p[$i][1] + $ls * $dx * $hw * $a];
      push @hr, [$p[$i][0] - $ls * $dy * $hw * $b, $p[$i][1] + $ls * $dx * $hw * $b];
    }
  }
  poly($o{body} // 'c5', @l, reverse @r);
  poly($o{hi} // 'c3', @hl, reverse @hr);
  poly($o{neck} // 'c1', @l[0 .. 2], reverse @r[0 .. 2]);                      # green stalk end
  my ($ex, $ey) = @{ $p[$N] }[0, 1]; my ($tx, $ty) = dir($p[$N][2]);
  poly('c4', [$l[$N - 1][0], $l[$N - 1][1]], [$ex + $tx * 2, $ey + $ty * 2], [$r[$N - 1][0], $r[$N - 1][1]]);   # dark tip
}

# The maroon banana heart (male bell): a teardrop of overlapping bracts pointing along ang.
sub bell {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o; for my $i (0 .. 15) { my $th = 2 * pi * $i / 16; my $u = (1 - cos($th)) / 2; my $h = $w / 2 * sin(pi * $u) ** 0.6 * (1.15 - 0.5 * $u);
    push @o, [$x + $dx * $len * $u + $nx * $h * (sin($th) < 0 ? -1 : 1), $y + $dy * $len * $u + $ny * $h * (sin($th) < 0 ? -1 : 1)]; }
  poly('c4', @o);
  my $L = lit($nx, $ny) ? 1 : -1;
  for my $k (0 .. 2) {                                                   # lit bract edges
    my $u = 0.2 + $k * 0.22;
    my $cx = $x + $dx * $len * $u; my $cy = $y + $dy * $len * $u; my $h = $w * 0.42 * (1 - 0.6 * $u);
    poly('c5', [$cx + $nx * $L * $h, $cy + $ny * $L * $h], [$cx + $dx * $len * 0.2 + $nx * $L * $h * 0.15, $cy + $dy * $len * 0.2 + $ny * $L * $h * 0.15],
               [$cx + $dx * $len * 0.12 + $nx * $L * $h * 0.6, $cy + $dy * $len * 0.12 + $ny * $L * $h * 0.6]);
  }
}

# A bunch hanging from the crown, laid out along ang: a green stalk, then tiers of hands whose fingers all
# point back towards the crown (as on a real bunch), each tier overlapping the bases of the one before,
# then a bare stalk end and the maroon bell. $nh hands, $nf fingers per hand.
sub bunch {
  my ($x, $y, $ang, $len, $fw, $fl, $nh, $nf, $ripe) = @_;
  my %fo = $ripe ? () : (body => "c2", hi => "c3", neck => "c1");
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  blade($x, $y, $ang, $len + 22, 10, 0, 'c2', 'c1', 0.1);                   # peduncle / rachis
  my $step = $len / $nh;
  for my $h (reverse 0 .. $nh - 1) {                                          # far hands first, upper hands on top
    my $s = ($h % 2) ? 1 : -1; my $k = 1 - 0.08 * $h; my $d = $step * ($h + 0.6);
    my $n = $nf - ($h == $nh - 1 ? 1 : 0);
    for my $j (reverse 0 .. $n - 1) {
      my $m = $j - ($n - 1) / 2;
      my $bx = $x + $dx * ($d + $m * $fw * 0.55) + $nx * $s * 4; my $by = $y + $dy * ($d + $m * $fw * 0.55) + $ny * $s * 4;
      finger($bx, $by, $ang + $s * (96 - $m * 12), $fl * $k * (1 - 0.06 * abs($m)), $fw * $k, $s * 40, %fo);
    }
  }
  bell($x + $dx * ($len + 18), $y + $dy * ($len + 18), $ang, 36, 24) if defined $ripe;
}

# Small irregular patch of soil.
sub soil {
  my ($x, $y, $rx, $ry, $seed) = @_; my @o;
  srand($seed);
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12; my $k = 0.82 + rand(0.3); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
}
# Pale cracks running out through dry soil.
sub cracks {
  my ($n, $seed, $seg) = @_; srand($seed); $seg //= 13;
  for my $i (0 .. $n - 1) {
    my $a = $i * 360 / $n + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
    for my $k (0 .. 4) {
      my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.2 - $k * 0.35;
      push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
      $x += $dx * $seg; $y += $dy * $seg;
    }
    poly('c3', @l, [$x, $y], reverse @r);
  }
}
# Top of the pseudostem / rolled cigar leaf in the crown, seen from above.
sub crown {
  my ($x, $y, $r) = @_;
  poly('c1', ell($x, $y, $r, $r, 12, 15));
  poly('c2', [$x - $r * 0.95, $y + $r * 0.2], ell($x - $r * 0.15, $y - $r * 0.15, $r * 0.8, $r * 0.8, 10, 150), [$x + $r * 0.2, $y - $r * 0.95]);
  poly('c3', ell($x - $r * 0.25, $y - $r * 0.25, $r * 0.32, $r * 0.32, 8, 0));
}
sub write_svg {
  my ($file, $label) = @_;
  open my $fh, '>', "$OUT/$file" or die $!;
  print $fh qq{<?xml version="1.0" encoding="UTF-8"?>\n<svg viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="$label">\n  <style>\n};
  print $fh "    .$_ { fill: var(--$_, $PAL{$_}); }\n" for qw(c1 c2 c3 c4 c5);
  print $fh "  </style>\n  <g transform=\"translate(0 0)\">\n", join("\n", @S), "\n  </g>\n</svg>\n";
  close $fh; @S = ();
}

# A whole plant from above: $n torn leaves swirling around the crown (all bend the same way).
sub plant {
  my ($n, $len, $w, $start, $seed, $tears, %o) = @_;
  srand($seed);
  my @L;
  for my $i (0 .. $n - 1) {
    next if $o{gap} && grep { $_ == $i } @{ $o{gap} };
    my $a = $start + $i * 360 / $n + rand(10) - 5;
    my $l = $len * (0.86 + rand(0.2));
    my (@tl, @tr);
    for (1 .. $tears) { push @tl, [0.12 + rand(0.8), 0.45 + rand(0.5)]; push @tr, [0.12 + rand(0.8), 0.45 + rand(0.5)]; }
    push @L, [$a, $l, \@tl, \@tr];
  }
  for (sort { $b->[1] <=> $a->[1] } @L) {
    my ($dx, $dy) = dir($_->[0]);
    bleaf(200 + $dx * 6, 200 + $dy * 6, $_->[0], $_->[1], $w, $o{bend} // 24, 'c2', 'c1', tearsL => $_->[2], tearsR => $_->[3], veins => 1, pf => $o{pf} // 0.2);
  }
}

# ---------------------------------------------------------------------------------------------
# 1. Planting material, front view: a young banana pup (sucker) cut from the mother plant: corm with roots,
#    a striped pseudostem, two small unfurled paddle leaves and the rolled cigar leaf.
for my $r ([-150, 46], [-122, 58], [-90, 64], [-60, 56], [-32, 44]) {
  my ($a, $l) = @$r;
  blade(200 + ($a + 90) * 0.5, 322, -$a, $l, 4.5, ($a < -90 ? 1 : -1) * 16, 'c3', 'c4');
}
poly('c4', ell(200, 308, 50, 32, 14, 8));                                  # corm
poly('c3', [152, 302], [162, 286], [184, 278], [200, 278], [198, 290], [176, 294], [160, 308]);
for ([174, 312], [220, 316], [232, 298]) { poly('c3', ell($_->[0], $_->[1], 3.5, 2.5, 6)); }
bleaf(196, 232, -150, 108, 46, 34, 'c2', 'c1', pf => 0.12, veins => 1);    # left paddle leaf
bleaf(204, 222, -36, 100, 42, -30, 'c2', 'c1', pf => 0.12, veins => 1);    # right paddle leaf
blade(200, 296, -90, 100, 34, 0, 'c2', 'c1', 0.25);                        # pseudostem
poly('c3', [189, 292], [192, 214], [196, 214], [195, 292]);                # pale sheath stripe
blade(201, 214, -92, 74, 13, 4, 'c3', 'c2', 0.5);                          # cigar leaf
write_svg('1-seeds-front.svg', 'Banana pup for planting');

# 2. Just planted, top down: the pup's cut pseudostem in a soil pocket, cigar leaf and one small leaf showing.
soil(200, 200, 58, 52, 21);
poly('c1', ell(200, 200, 24, 24, 14, 5));
poly('c2', [176, 204], ell(197, 197, 22, 22, 9, 160), [204, 176]);
poly('c3', ell(200, 200, 14, 14, 12));
poly('c1', ell(200, 200, 9, 9, 10));
poly('c3', ell(199, 199, 4.5, 4.5, 8));
bleaf(208, 194, -38, 52, 22, 16, 'c2', 'c1', pf => 0.2);
write_svg('2-sown.svg', 'Banana pup just planted');

# 3. First growth: three young paddle leaves, still whole.
soil(200, 200, 34, 30, 31);
bleaf(204, 196, -48, 86, 30, 18, 'c2', 'c1', pf => 0.22, veins => 1);
bleaf(196, 202, 186, 76, 28, 18, 'c2', 'c1', pf => 0.22, veins => 1);
bleaf(202, 206, 72, 70, 26, 18, 'c2', 'c1', pf => 0.22, veins => 1);
crown(200, 200, 10);
write_svg('3-first-growth.svg', 'Banana first growth');

# 4. Second growth: five young leaves, a few first tears.
soil(200, 200, 34, 30, 41);
plant(5, 122, 42, -70, 42, 2, bend => 22);
crown(200, 200, 12);
write_svg('4-second-growth.svg', 'Banana second growth');

# 5. Third growth: full star of torn leaves; the bunch has come out: small green hands and the maroon bell.
soil(200, 200, 34, 30, 51);
plant(7, 150, 50, -46.3, 52, 4, bend => 22);
crown(200, 200, 14);
bunch(204, 186, -72, 66, 11, 40, 3, 4, 0);
write_svg('5-third-growth.svg', 'Banana third growth with flower bell');

# 6. Harvest: big swirling leaves and a heavy bunch of ripe yellow bananas draped out to the lower right.
soil(200, 200, 34, 30, 61);
plant(7, 176, 54, -46.3, 62, 5, bend => 22);
crown(200, 200, 15);
bunch(206, 184, -72, 116, 18, 74, 4, 4, 1);
write_svg('6-harvest.svg', 'Banana ready to harvest');

# 7. Harvested produce, front view: a hand of ripe bananas on its crown stalk.
for my $k (0 .. 4) {
  my $a = -44 + $k * 13;
  finger(134 + $k * 2, 292 + $k * 6, $a, 210 - abs($k - 2) * 14, 36, -68);
}
poly('c1', [104, 296], [132, 280], [150, 318], [118, 330]);
poly('c2', [104, 296], [132, 280], [140, 296], [110, 310]);
poly('c4', [104, 296], [110, 310], [100, 312], [96, 300]);
write_svg('7-harvest-front.svg', 'Hand of ripe bananas');

# 8. Dead (never watered): cracked soil, a brown stump, shredded straw leaves collapsed flat.
soil(200, 200, 62, 54, 81);
cracks(7, 83, 14);
srand(85);
for my $i (0 .. 5) {
  my $a = -80 + $i * 60 + rand(20) - 10; my $l = 110 + rand(30);
  my (@tl, @tr); for (1 .. 7) { push @tl, [0.05 + rand(0.9), 0.85]; push @tr, [0.05 + rand(0.9), 0.85]; }
  my ($dx, $dy) = dir($a);
  bleaf(200 + $dx * 8, 200 + $dy * 8, $a, $l, 36, (rand(1) < 0.5 ? -1 : 1) * (30 + rand(30)), 'c3', 'c4', tearsL => \@tl, tearsR => \@tr, ribc => 'c3', pf => 0.15);
}
poly('c4', ell(200, 200, 22, 22, 11, 7));
poly('c3', ell(200, 200, 15, 15, 9, 3));
poly('c4', ell(201, 201, 8, 8, 7));
write_svg('8-dead.svg', 'Banana plant died from lack of water');
print "wrote 8 files to $OUT\n";

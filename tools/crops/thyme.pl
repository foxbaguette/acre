# Thyme crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/thyme.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Signature: a low woody cushion of many thin wiry stems densely set with TINY grey-green leaves (a fine, fuzzy
# texture, nothing like mint's big quilted leaves), hazed over with tiny pink-lilac flower clusters in bloom.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/thyme';
mkdir 'crops'; mkdir $OUT;
# c1 olive grey-green (shade), c2 silvery sage (lit leaves), c3 pale cream (highlights, dried leaves, twine),
# c4 dark soil / woody stems, c5 pink-lilac (flowers)
my %PAL = (c1 => '#5B7347', c2 => '#A9BC86', c3 => '#EEE9CC', c4 => '#553624', c5 => '#D68BC0');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub ell { my ($x, $y, $rx, $ry, $n, $rot) = @_; $rot //= 0; map { my ($u, $v) = dir($rot + $_ * 360 / $n); [$x + $u * $rx, $y + $v * $ry] } 0 .. $n - 1 }

# A tapered stem from (x,y) heading `ang`, bending `bend` degrees. Returns end point and heading.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $tipw) = @_;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $t * (1 - ($tipw // 0))) + 0.35;
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
sub walk {
  my ($x, $y, $ang, $len, $bend, $t) = @_; my $n = 10;
  for my $i (1 .. int($t * $n + 0.5)) { my ($dx, $dy) = dir($ang); $x += $dx * $len / $n; $y += $dy * $len / $n; $ang += $bend / $n; }
  return ($x, $y, $ang);
}

# One tiny thyme leaf: a little pointed oval, lit and shaded halves (or one flat tone when $light eq $dark).
sub tleaf {
  my ($x, $y, $ang, $len, $w, $light, $dark) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @L = map { my $t = $_ / 3; my $h = $w / 2 * sin(pi * (0.1 + 0.9 * $t)) ** 0.8; [$x + $dx * $len * $t + $nx * $h, $y + $dy * $len * $t + $ny * $h] } 0 .. 3;
  my @R = map { my $t = $_ / 3; my $h = $w / 2 * sin(pi * (0.1 + 0.9 * $t)) ** 0.8; [$x + $dx * $len * $t - $nx * $h, $y + $dy * $len * $t - $ny * $h] } 0 .. 3;
  my ($a, $b) = ([$x, $y], [$x + $dx * $len, $y + $dy * $len]);
  if ($light eq $dark) { poly($light, @L, reverse @R[1 .. 2]); return; }
  my $pl = lit($nx, $ny);
  poly($pl ? $light : $dark, @L);
  poly($pl ? $dark : $light, @R);
}

# Tone of the mound at a point: the cushion domes up, so its upper-left flank is lit and lower-right shaded.
our ($MR, $FLAT) = (150, 0);
sub tone {
  my ($x, $y) = @_;
  my $m = ((($x - 200) * -0.7071 + ($y - 200) * -0.7071) / $MR) * 0.8 + rand(0.9) - 0.45;
  return ('c3', 'c2') if $m > 0.7 && !$FLAT;
  return ('c2', 'c2') if $m > 0.15;
  return ('c2', 'c1') if $m > -0.35;
  return ('c1', 'c1');
}

# A wiry thyme sprig: thin woody stem with tiny opposite leaves crowded along it, a leafy tip and the odd side
# twig. Returns its tip. $fl adds a flower cluster at the tip; $lc forces leaf colours (dead / front views).
sub sprig {
  my ($x, $y, $ang, $len, $bend, $s, %o) = @_;
  my ($sl, $sd) = @{$o{stem} // ['c4', 'c4']};
  blade($x, $y, $ang, $len, 2.0 * $s, $bend, $sl, $sd, 0.5);
  my $n = int($len / (7 * $s * ($o{dens} // 1))); my @lv;
  for my $k (1 .. $n) {
    my $t = $k / ($n + 0.6);
    my ($px, $py, $pa) = walk($x, $y, $ang, $len, $bend, $t);
    my $sz = $s * (0.75 + 0.45 * sin(pi * min(1, $t * 1.1)));
    for my $sd (-1, 1) {
      next if $o{sparse} && rand(1) < $o{sparse};
      push @lv, [$px, $py, $pa + $sd * (58 + rand(18)) + ($k % 2 ? 0 : 90 * $sd * 0.2), 12 * $sz, 7 * $sz];
      push @lv, [$px, $py, $pa + $sd * (22 + rand(12)), 8 * $sz, 5 * $sz] if $o{dens};
    }
    if ($o{twig} && $k == int($n * 0.45) && $len > 40) {
      my $sd = rand(1) < .5 ? -1 : 1;
      sprig($px, $py, $pa + $sd * 40, $len * 0.38, $sd * 20, $s * 0.9, %o, twig => 0, fl => 0);
    }
  }
  my ($tx, $ty, $ta) = walk($x, $y, $ang, $len, $bend, 1);
  push @lv, map { [$tx, $ty, $ta + $_ + rand(10) - 5, 10 * $s, 6.4 * $s] } (-40, 0, 40);
  for (@lv) {
    my ($l, $d) = $o{lc} ? @{$o{lc}} : tone($_->[0], $_->[1]);
    tleaf(@$_, $l, $d);
  }
  cluster($tx, $ty, $o{fl}) if $o{fl};
  return ($tx, $ty, $ta);
}

# A thyme flower cluster: a tight little head of pink-lilac florets.
sub cluster {
  my ($x, $y, $r) = @_;
  poly('c1', ell($x + 1, $y + 1, $r, $r, 8, 10));
  for my $i (0 .. 5) {
    my ($u, $v) = dir($i * 60 + 15); my $rr = $i == 5 ? 0 : $r * 0.55;
    ($u, $v) = (0, 0) if $i == 5;
    my ($fx, $fy) = ($x + $u * $r * 0.55, $y + $v * $r * 0.55);
    poly('c5', ell($fx, $fy, $r * 0.45, $r * 0.45, 5, $i * 20));
    poly('c3', ell($fx - $r * 0.15, $fy - $r * 0.15, $r * 0.15, $r * 0.15, 4, 45)) if $i % 2;
  }
}

# Flowering haze: little pink-lilac heads spread over the whole top of the cushion, denser in the middle.
sub haze {
  my ($seed, $n, $R, $r) = @_; srand($seed);
  my @c; for my $i (0 .. $n - 1) { my $rr = $R * sqrt(($i + 0.5) / $n); my ($u, $v) = dir($i * 137.508 + rand(14)); push @c, [200 + $u * $rr, 200 + $v * $rr, $r * (0.8 + rand(0.4))]; }
  cluster(@$_) for sort { $a->[1] <=> $b->[1] } @c;
}

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

# Tiny round thyme seed: dark brown with a lit cap.
sub seed {
  my ($x, $y, $r) = @_;
  poly('c4', ell($x, $y, $r, $r * 0.9, 10, 10));
  # a lit crescent along the upper-left rim, so every seed in a heap reads as its own little ball
  my @o = map { my ($u, $v) = dir(135 + $_ * 16); [$x + $u * $r * 0.94, $y + $v * $r * 0.85] } 0 .. 8;
  my @i = map { my ($u, $v) = dir(135 + $_ * 16); [$x + $r * 0.1 + $u * $r * 0.8, $y + $r * 0.1 + $v * $r * 0.7] } reverse 0 .. 8;
  poly('c3', @o, @i);
}

sub write_svg {
  my ($file, $label) = @_;
  open my $fh, '>', "$OUT/$file" or die $!;
  print $fh qq{<?xml version="1.0" encoding="UTF-8"?>\n<svg viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="$label">\n  <style>\n};
  print $fh "    .$_ { fill: var(--$_, $PAL{$_}); }\n" for qw(c1 c2 c3 c4 c5);
  print $fh "  </style>\n  <g transform=\"translate(0 0)\">\n", join("\n", @S), "\n  </g>\n</svg>\n";
  close $fh; @S = ();
}

# The cushion: $n sprigs radiating from the crown with jittered angles; long (low, outer) ones first so the
# short ones in the middle sit on top and the mound domes up.
sub mound {
  my ($seed, $n, $R, $s, $fl) = @_;
  srand($seed); local $MR = $R;
  my @sp;
  for my $i (0 .. $n - 1) {
    my $r0 = $R * 0.5 * sqrt(rand(1)); my $pa = rand(360);
    my ($u, $v) = dir($pa);
    my $a = $pa + rand(60) - 30;
    my $len = max(22, ($R - $r0) * (0.62 + rand(0.38)));
    push @sp, [200 + $u * $r0, 200 + $v * $r0, $a, $len, (rand(1) < .5 ? -1 : 1) * (10 + rand(30)), $r0];
  }
  for my $i (1 .. int($n * 0.22)) {            # short upright shoots crowning the middle of the cushion
    my $r0 = $R * 0.16 * sqrt(rand(1)); my ($u, $v) = dir(rand(360));
    push @sp, [200 + $u * $r0, 200 + $v * $r0, rand(360), $R * (0.22 + rand(0.16)), rand(40) - 20, -1];
  }
  for (sort { $b->[5] <=> $a->[5] } @sp) {
    my ($x, $y, $a, $len, $bend, $r0) = @$_;
    sprig($x, $y, $a, $len, $bend, $s, twig => 1, fl => ($fl && rand(1) < 0.7 ? $fl * (0.85 + rand(0.3)) : 0));
  }
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a little heap of tiny round thyme seeds.
{ srand(11); my @sd;
  for my $row ([306, 9], [282, 8], [258, 7], [235, 6], [213, 4], [193, 3], [176, 1]) {   # a conical little pile
    my ($y, $c) = @$row; my $wd = 30;
    for my $k (0 .. $c - 1) { push @sd, [200 + ($k - ($c - 1) / 2) * $wd + rand(10) - 5, $y + rand(8) - 4, 15 + rand(4)]; }
  }
  push @sd, [96, 318, 14], [306, 320, 15], [330, 312, 12];      # a few that rolled off
  seed(@$_) for sort { $a->[1] <=> $b->[1] } @sd;
}
write_svg('1-seeds-front.svg', 'Thyme seeds');

# 2. Just sown, top down: pinches of tiny seeds pressed into small soil pockets.
{ my @sown = ([168, 170], [238, 168], [202, 226], [150, 244], [254, 240]);
  for (@sown) { soil($_->[0], $_->[1], 26, 22, int($_->[0] * 7 + $_->[1])); }
  srand(22);
  for (@sown) { my ($x, $y) = @$_; for my $k (0 .. 3) { my ($u, $v) = dir($k * 90 + 40 + rand(30)); seed($x + $u * 10, $y + $v * 8, 7.5); } seed($x, $y, 7.5); }
}
write_svg('2-sown.svg', 'Thyme just sown');

# 3. First growth, top down: a tiny tuft of wiry sprigs.
soil(200, 200, 30, 26, 3);
mound(31, 12, 76, 1.0, 0);
write_svg('3-first-growth.svg', 'Thyme first growth');

# 4. Second growth, top down: a small woody cushion.
soil(200, 200, 32, 28, 4);
mound(41, 26, 116, 1.0, 0);
write_svg('4-second-growth.svg', 'Thyme second growth');

# 5. Third growth, top down: the cushion hazed with tiny pink-lilac flower clusters.
soil(200, 200, 32, 28, 5);
mound(51, 46, 146, 1.0, 0);
haze(52, 50, 134, 6.5);
write_svg('5-third-growth.svg', 'Thyme third growth in flower');

# 6. Harvest, top down: a full, dense, silvery cushion, fresh tips all over.
soil(200, 200, 32, 28, 6);
mound(61, 50, 172, 1.02, 0);
write_svg('6-harvest.svg', 'Thyme ready to harvest');

# 7. Harvest item, front view: a small bundle of thyme sprigs tied with twine.
{ my ($bx, $by) = (200, 286);
  srand(71);
  for my $i (0 .. 5) {                                          # woody stems below the tie
    my $ex = $bx + ($i - 2.5) * 7;
    blade($bx + ($i - 2.5) * 2.5, $by, rad2deg(atan2(368 - $by, $ex - $bx - ($i - 2.5) * 2.5)), 82, 5, 0, 'c3', 'c4', 0.9);
  }
  my @sp = ([-124, 150, -16], [-112, 178, -12], [-100, 196, -4], [-90, 206, 4], [-80, 194, 8], [-68, 176, 14], [-56, 150, 18], [-106, 132, 10], [-76, 128, -10]);
  for my $sp (@sp) {
    my ($a, $len, $bend) = @$sp;
    sprig($bx + ($a + 90) * 0.12, $by, $a, $len, $bend, 1.3, stem => [q(c4), q(c4)], twig => 1, dens => 0.7);
  }
  poly('c4', [$bx - 17, $by - 5], [$bx + 17, $by - 8], [$bx + 18, $by + 7], [$bx - 18, $by + 10]);
  poly('c3', [$bx - 17, $by - 5], [$bx + 17, $by - 8], [$bx + 17, $by - 2], [$bx - 17, $by + 1]);
  poly('c3', [$bx + 12, $by + 4], [$bx + 28, $by + 26], [$bx + 22, $by + 28], [$bx + 8, $by + 8]);
}
write_svg('7-harvest-front.svg', 'Harvested thyme bundle');

# 8. Dead (never watered), top down: cracked dry soil, a flattened tangle of grey woody stems, a few dry leaves.
soil(200, 200, 62, 54, 8);
cracks(9, 83, 13);
{ srand(84);
  for my $i (0 .. 15) {
    my $a = $i * 137.5 + rand(20); my $len = 70 + rand(60); my $bend = (rand(1) < .5 ? -1 : 1) * (30 + rand(50));
    sprig(200, 200, $a, $len, $bend, 1.0, stem => ['c3', 'c4'], lc => ['c3', 'c4'], sparse => 0.72);
  }
}
write_svg('8-dead.svg', 'Thyme died from lack of water');
print "wrote 8 files to $OUT\n";

# Rye crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/rye.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Rye vs wheat: taller and slimmer, blue-grey (glaucous) leaves, long thin NODDING ears bristling with very long
# fine awns, ripening to a cool grey-tan instead of wheat's warm gold. Grains are long, slim and grey-green.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/rye';
mkdir 'crops'; mkdir $OUT;
# c1 blue-grey leaf green, c2 silvery lit green, c3 pale grey straw (lit ripe parts, dry leaves, awns),
# c4 dark soil brown, c5 grey-tan ripe rye (shaded ripe parts)
my %PAL = (c1 => '#557D6B', c2 => '#9CBCA8', c3 => '#E6DCB8', c4 => '#5A3A22', c5 => '#9A8453');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A tapered leaf blade or stalk from (x,y) heading `ang`, bending `bend` degrees over its length (as in wheat.pl).
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $taper) = @_;
  $taper //= 1;
  my $n = 10; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $t) ** 0.85 + ($i == $n && $taper == 1 ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
  return ($px, $py, $a - $bend / $n);
}

# Points and headings along a bent path (n steps), used to hang spikelets on a nodding ear.
sub path {
  my ($x, $y, $ang, $len, $bend, $n) = @_;
  my @p; my $a = $ang;
  for my $i (0 .. $n) { push @p, [$x, $y, $a]; my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  return @p;
}

# A long slim rye grain: pointed at the germ end, rounded at the brush end, with a lit half and a fine crease.
sub grain {
  my ($x, $y, $ang, $len, $w, $body, $light) = @_;
  $body //= 'c1'; $light //= 'c2';
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 19) {
    my $th = 2 * pi * $i / 20;
    my $c = cos($th);
    my $u = $c * $len / 2; my $v = sin($th) * $w / 2 * (1 - 0.22 * $c * $c) * ($c < 0 ? 1 - 0.16 * (-$c) ** 3 : 1);
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly($body, @o);
  my $leftLit = lit($nx, $ny);
  my @half = $leftLit ? @o[10 .. 19, 0] : @o[0 .. 10];
  poly($light, @half);
  my $k = $leftLit ? -1 : 1;   # crease sits just inside the shaded half
  my @cr = map { [$x + $dx * $len * $_ + $nx * $k * $w * 0.1, $y + $dy * $len * $_ + $ny * $k * $w * 0.1] } (-0.3, 0.32);
  poly('c4', [$cr[0][0] + $nx * 0.9, $cr[0][1] + $ny * 0.9], [$cr[1][0] + $nx * 0.9, $cr[1][1] + $ny * 0.9],
             [$cr[1][0] - $nx * 0.9, $cr[1][1] - $ny * 0.9], [$cr[0][0] - $nx * 0.9, $cr[0][1] - $ny * 0.9]);
}

# A rye ear: long, slim, of near-even width, nodding along `bend`, packed with small alternating spikelets,
# every spikelet trailing a very long fine awn. $anth adds pale dangling anthers (flowering).
sub ear {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $awn, $alen, $anth) = @_;
  my $n = 16;
  my @p = path($x, $y, $ang, $len, $bend, $n);
  # awns first, so the spikelets sit on top of their bristle halo
  if ($awn) {
    for my $i (1 .. $n) {
      my ($cx, $cy, $a) = @{$p[$i]};
      for my $side (-1, 1) {
        next if ($i + ($side > 0 ? 1 : 0)) % 2 && $i < $n - 2;
        my $aa = $a + $side * (7 + 5 * $i / $n); my ($ax, $ay) = dir($aa); my ($nx, $ny) = (-$ay, $ax);
        my $l = $alen * (0.75 + 0.25 * $i / $n);
        my ($ex, $ey) = dir($a);
        my ($sx, $sy) = ($cx - $ey * $side * $w * 0.22, $cy + $ex * $side * $w * 0.22);
        my $ac = $awn eq 'mix' ? (lit($nx * $side, $ny * $side) ? 'c3' : 'c5') : $awn;   # 'mix': lit-side awns pale
        poly($ac, [$sx - $nx * 0.8, $sy - $ny * 0.8], [$sx + $ax * $l, $sy + $ay * $l], [$sx + $nx * 0.8, $sy + $ny * 0.8]);
      }
    }
  }
  # neck
  my ($bx, $by) = dir($ang);
  blade($x - $bx * 8, $y - $by * 8, $ang, 12, $w * 0.32, 0, $light, $dark, 0);
  # slim even body under the spikelets
  my (@bl, @br);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($cx, $cy, $a) = @{$p[$i]}; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    my $hw = $w * 0.34 * min(1, sin(pi * (0.04 + 0.92 * $t)) * 2.2) ** 0.8;
    push @bl, [$cx + $nx * $hw, $cy + $ny * $hw]; push @br, [$cx - $nx * $hw, $cy - $ny * $hw];
  }
  poly($dark, @bl, reverse @br);
  for my $i (0 .. $n - 1) {
    my ($cx, $cy, $a) = @{$p[$i]}; my ($cx2, $cy2) = @{$p[$i + 1]};
    $cx = ($cx + $cx2) / 2; $cy = ($cy + $cy2) / 2;
    my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    my $t = ($i + 0.5) / $n;
    my $side = $i % 2 ? 1 : -1;
    my $sw = $w * (0.8 + 0.2 * sin(pi * min(1, $t * 1.4)));
    my $sl = $len / $n * 2.4;
    my $ox = $cx + $nx * $side * $sw * 0.16; my $oy = $cy + $ny * $side * $sw * 0.16;
    my @d = ([$ox - $dx * $sl * 0.5, $oy - $dy * $sl * 0.5],
             [$ox + $nx * $side * $sw * 0.46 - $dx * $sl * 0.05, $oy + $ny * $side * $sw * 0.46 - $dy * $sl * 0.05],
             [$ox + $dx * $sl * 0.5, $oy + $dy * $sl * 0.5],
             [$ox - $nx * $side * $sw * 0.14, $oy - $ny * $side * $sw * 0.14]);
    poly(lit($nx * $side, $ny * $side) ? $light : $dark, @d);
    if ($anth && $i % 3 == 1) {           # a pale anther dangling from the spikelet's outer edge
      my ($ex, $ey) = ($ox + $nx * $side * $sw * 0.5, $oy + $ny * $side * $sw * 0.5);
      my ($hx, $hy) = dir($a + $side * 70);
      my ($kx, $ky) = (-$hy, $hx);
      poly($anth, [$ex - $kx * 2.2, $ey - $ky * 2.2], [$ex + $hx * 9 - $kx * 2.4, $ey + $hy * 9 - $ky * 2.4],
                  [$ex + $hx * 10.5, $ey + $hy * 10.5], [$ex + $hx * 9 + $kx * 2.4, $ey + $hy * 9 + $ky * 2.4], [$ex + $kx * 2.2, $ey + $ky * 2.2]);
    }
  }
  # pointed tip spikelet
  my ($tx, $ty, $ta) = @{$p[$n]}; my ($dx, $dy) = dir($ta); my ($nx, $ny) = (-$dy, $dx);
  poly($dark, [$tx - $dx * 8 + $nx * $w * 0.2, $ty - $dy * 8 + $ny * $w * 0.2], [$tx + $dx * 6, $ty + $dy * 6],
              [$tx - $dx * 8 - $nx * $w * 0.2, $ty - $dy * 8 - $ny * $w * 0.2]);
  return ($tx, $ty, $ta);
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

# A slender grass tuft: $n narrow blades with seeded jitter in angle, length and bend (longest drawn first).
sub tuft {
  my ($n, $len, $lenVar, $w, $bendMax, $light, $dark, $seed, $start) = @_;
  srand($seed);
  my @b;
  for my $i (0 .. $n - 1) {
    my $a = ($start // -90) + $i * 360 / $n + rand(18) - 9;
    my $l = $len + rand($lenVar);
    my $bend = (rand(1) < 0.5 ? -1 : 1) * ($bendMax * (0.5 + rand(0.5)));
    push @b, [$a, $l, $bend];
  }
  blade(200, 200, $_->[0], $_->[1], $w, $_->[2], $light, $dark) for sort { $b->[1] <=> $a->[1] } @b;
}

# 1. Seeds, front view: a small heap of long slim grey-green and brownish rye grains.
grain(157, 255, -24, 160, 40, "c5", "c3"); grain(250, 257, 204, 160, 40, "c2", "c3"); grain(205, 210, -62, 155, 38, "c5", "c3");
grain(125, 307, -6, 166, 41, "c2", "c3");  grain(277, 307, 186, 166, 41, "c5", "c3"); grain(201, 325, 2, 171, 42, "c5", "c3");
write_svg('1-seeds-front.svg', 'Rye seeds');

# 2. Just sown, top down: slim grains pressed into small soil pockets.
my @sown = ([164, 166, -40, 'c2', 'c3'], [242, 164, 30, 'c5', 'c3'], [202, 214, 100, 'c5', 'c3'], [148, 242, 150, 'c2', 'c3'], [254, 240, -70, 'c5', 'c3']);
for (@sown) { soil($_->[0], $_->[1], 30, 22, int($_->[0] * 7 + $_->[1])); }
for (@sown) { grain($_->[0], $_->[1], $_->[2], 50, 15, $_->[3], $_->[4]); }
write_svg('2-sown.svg', 'Rye just sown');

# 3. First growth, top down: a few fine blue-green shoots.
soil(200, 200, 34, 30, 3);
tuft(6, 76, 26, 9, 22, 'c2', 'c1', 31, -80);
write_svg('3-first-growth.svg', 'Rye first growth');

# 4. Second growth, top down: a dense fine-leaved blue-green tuft.
soil(200, 200, 34, 30, 4);
tuft(14, 108, 40, 10, 34, 'c2', 'c1', 41);
write_svg('4-second-growth.svg', 'Rye second growth');

# 5. Third growth, top down: tall leaves, upright slim green ears flowering with pale dangling anthers.
soil(200, 200, 34, 30, 5);
tuft(16, 134, 36, 10, 38, 'c2', 'c1', 51);
for my $i (0 .. 6) { my $a = -70 + $i * 360 / 7 + ($i % 2 ? 10 : -6); my ($dx, $dy) = dir($a);
  ear(200 + $dx * 26, 200 + $dy * 26, $a, 86, 14, ($i % 2 ? 8 : -8), 'c2', 'c1', 'c2', 34, 'c3'); }
write_svg('5-third-growth.svg', 'Rye third growth');

# 6. Harvest, top down: grey-tan stalks with long slim nodding ears, each a bristling brush of long awns.
soil(200, 200, 34, 30, 6);
tuft(9, 112, 30, 9, 36, 'c3', 'c5', 61, -70);
srand(66);
for my $i (0 .. 11) { my $a = -90 + $i * 30 + rand(10) - 5; my ($dx, $dy) = dir($a); my $b = ($i % 2 ? 1 : -1) * (18 + rand(14));
  blade(200, 200, $a, 40, 6, 0, 'c3', 'c5', 0);
  ear(200 + $dx * 36, 200 + $dy * 36, $a, 104, 19, $b, 'c3', 'c5', 'mix', 50); }
write_svg('6-harvest.svg', 'Rye ready to harvest');

# 7. Harvested produce, front view: a tall slim bundle of rye tied with twine, the long ears nodding over to one side.
my ($bx, $by) = (190, 262);
my $NS = 7;
for my $i (0 .. $NS - 1) {                          # long lower stalks down to the cut ends
  my $ex = $bx + ($i - 3) * 11; my $ey = 392;
  my $a = rad2deg(atan2($ey - $by, $ex - $bx));
  blade($bx + ($i - 3) * 3, $by, $a, sqrt(($ex - $bx) ** 2 + ($ey - $by) ** 2), 10, 0, 'c3', 'c5');
}
for my $i (0 .. $NS - 1) { my $ex = $bx + ($i - 3) * 11; my @o; for my $k (0 .. 7) { my $th = 2 * pi * $k / 8; push @o, [$ex + cos($th) * 4.6, 392 + sin($th) * 2.6]; } poly('c4', @o); }
my @rs = ([-126, 74, 34], [-113, 104, 46], [-101, 124, 58], [-89, 130, 70], [-78, 118, 82], [-67, 98, 94], [-57, 74, 104]);
my @tips;
for my $i (0 .. $#rs) { my ($a, $len, $b) = @{$rs[$i]}; push @tips, [blade($bx + ($i - 3) * 3, $by, $a, $len, 8, $b * 0.28, 'c3', 'c5'), $b]; }
for my $i (0 .. $#tips) { my ($x, $y, $a, $b) = @{$tips[$i]}; ear($x, $y, $a, 132, 22, $b, 'c3', 'c5', 'mix', 72); }
# twine tie: a dark band with a lit top edge and two dangling ends
poly('c4', [$bx - 24, $by - 7], [$bx + 24, $by - 9], [$bx + 25, $by + 7], [$bx - 25, $by + 9]);
poly('c5', [$bx - 24, $by - 7], [$bx + 24, $by - 9], [$bx + 24, $by - 3], [$bx - 24, $by - 1]);
poly('c4', [$bx + 16, $by + 5], [$bx + 28, $by + 36], [$bx + 21, $by + 37], [$bx + 10, $by + 8]);
poly('c4', [$bx + 14, $by + 5], [$bx + 5, $by + 32], [$bx - 1, $by + 30], [$bx + 7, $by + 5]);
write_svg('7-harvest-front.svg', 'Harvested rye bundle');

# 8. Dead (never watered), top down: cracked dry soil and a limp, withered blue-grey tuft gone to dull straw.
soil(200, 200, 56, 48, 8);
srand(83);
for my $i (0 .. 6) {
  my $a = $i * 360 / 7 + rand(20); my ($x, $y) = (200, 200); my @l; my @r;
  for my $k (0 .. 4) {
    my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.2 - $k * 0.35;
    push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w];
    $x += $dx * 13; $y += $dy * 13;
  }
  poly('c3', @l, [$x, $y], reverse @r);
}
srand(81);
my @dead;
for my $i (0 .. 11) { my $a = -90 + $i * 30 + rand(14) - 7; push @dead, [$a, 80 + rand(42), (rand(1) < 0.5 ? -1 : 1) * (50 + rand(46))]; }
blade(200, 200, $_->[0], $_->[1], 10, $_->[2], 'c3', 'c5') for sort { $b->[1] <=> $a->[1] } @dead;
for ([-40, 20], [80, 17], [190, 21], [250, 15]) { blade(200, 200, $_->[0], $_->[1], 8, 0, 'c3', 'c5'); }
write_svg('8-dead.svg', 'Rye died from lack of water');
print "wrote 8 files to $OUT\n";

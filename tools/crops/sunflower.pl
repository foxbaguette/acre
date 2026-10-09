# Sunflower crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/sunflower.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/sunflower';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#3C7A30', c2 => '#86C04A', c3 => '#FFE58C', c4 => '#4E2E1C', c5 => '#F5B21C');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
our @SQ;   # optional squash [cx, cy, ky]: tilts a flat shape away from the viewer
sub poly { my ($cls, @p) = @_; @p = map { [$_->[0], $SQ[1] + ($_->[1] - $SQ[1]) * $SQ[2]] } @p if @SQ; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
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

# Map local leaf coords (u along the bent midrib, v across, both in px) to the page.
sub along {
  my ($p, $len, $u, $v) = @_; my $n = $#$p;
  my $f = $u / $len * $n; my $i = $f < 0 ? 0 : ($f >= $n ? $n - 1 : int($f)); my $r = $f - $i;
  my ($x0, $y0, $a0) = @{$p->[$i]}; my ($x1, $y1) = @{$p->[$i + 1]};
  my ($dx, $dy) = dir($a0 + 0); my ($bx, $by) = ($x0 + ($x1 - $x0) * $r, $y0 + ($y1 - $y0) * $r);
  [$bx - $dy * $v, $by + $dx * $v];
}

# A broad heart-shaped sunflower leaf on a petiole: cordate base, pointed tip, toothed edge, three main veins.
sub hleaf {
  my ($x, $y, $ang, $plen, $len, $w, $bend, $light, $dark, %o) = @_;
  if ($plen > 0) { blade($x, $y, $ang, $plen + $len * 0.05, $o{pw} // max(3, $w * 0.09), 0, $light, $dark); }
  my ($dx, $dy) = dir($ang); my ($bx, $by) = ($x + $dx * $plen, $y + $dy * $plen);
  my @p = path($bx, $by, $ang, $len, $bend, 16);
  my @sh = ([0, 0], [-0.1, 0.1], [-0.14, 0.22], [-0.12, 0.33], [-0.05, 0.42], [0.05, 0.48], [0.16, 0.52], [0.28, 0.52], [0.4, 0.48], [0.52, 0.41], [0.63, 0.33], [0.73, 0.24], [0.82, 0.16], [0.9, 0.09], [0.96, 0.035]);
  my $wd = $o{wd} // 1;                                                        # 0 = withered (narrow, curled)
  my (@L, @R);
  for my $k (0 .. $#sh) {
    my ($u, $v) = @{$sh[$k]};
    if ($k > 1 && ($o{teeth} // 1)) {                                            # tooth between this and the previous point
      my ($u0, $v0) = @{$sh[$k - 1]}; my ($um, $vm) = (($u + $u0) / 2 + 0.015, ($v + $v0) / 2 * 1.03);
      push @L, along(\@p, $len, $um * $len, $vm * $w * $wd); push @R, along(\@p, $len, $um * $len, -$vm * $w * $wd);
      ($u, $v) = ($u - 0.005, $v * 0.97);
    }
    push @L, along(\@p, $len, $u * $len, $v * $w * $wd); push @R, along(\@p, $len, $u * $len, -$v * $w * $wd);
  }
  my $tip = along(\@p, $len, $len, 0);
  my @mid = map { along(\@p, $len, $_ / 8 * $len, 0) } 0 .. 8;
  my ($mx, $my) = dir($ang + $bend / 2);
  my $vLit = lit(-$my, $mx);                                                    # does +v face the light?
  poly($vLit ? $light : $dark, @L, $tip, reverse @mid);
  poly($vLit ? $dark : $light, @R, $tip, reverse @mid);
  return if $o{noveins};
  my $vw = $o{vw} // max(0.9, $w * 0.018);
  my $vein = sub { my ($cls, @q) = @_; my @a; my @b;
    for my $i (0 .. $#q) { my ($u, $v, $h) = @{$q[$i]}; push @a, along(\@p, $len, $u * $len, $v * $w * $wd + $h); push @b, along(\@p, $len, $u * $len, $v * $w * $wd - $h); }
    poly($cls, @a, reverse @b[0 .. $#b - 1]); };
  $vein->($vLit ? $dark : $light, [0, 0, $vw * 1.4], [0.5, 0, $vw], [0.9, 0, 0]);  # midrib, drawn on the lit half's tone flipped
  for my $s (1, -1) {
    my $cls = (($s > 0) == ($vLit ? 1 : 0)) ? $dark : $light;
    $vein->($cls, [0.01, 0, $vw], [0.2, 0.22 * $s, $vw * 0.8], [0.42, 0.3 * $s, $vw * 0.5], [0.6, 0.27 * $s, 0]);
          }
}

# Leaf pairs, opposite and turning 90 degrees each pair (decussate), lower pairs larger and further out.
sub pairs {
  my ($n, $len0, $len1, $w0, $w1, $seed, %o) = @_; srand($seed);
  my $rot = $o{start} // -45;
  for my $i (0 .. $n - 1) {
    my $f = $n > 1 ? $i / ($n - 1) : 0; my $len = $len0 + ($len1 - $len0) * $f; my $w = $w0 + ($w1 - $w0) * $f;
    my $plen = ($o{p0} // 20) + (($o{p1} // 6) - ($o{p0} // 20)) * $f;
    for my $s (0, 180) {
      my $a = $rot + $i * ($o{turn} // 90) + $s + rand(14) - 7;
      hleaf(200, 200, $a, $plen, $len + rand($o{var} // 8), $w, (rand(1) < 0.5 ? -1 : 1) * (6 + rand($o{bend} // 10)), $o{light} // 'c2', $o{dark} // 'c1', %o);
    }
  }
}

# Leaves in a spiral (golden angle), oldest and largest first, each on a petiole from the stem.
sub spiral {
  my ($n, $len0, $len1, $wk, $seed, %o) = @_; srand($seed);
  my $rot = $o{start} // -40;
  for my $i (0 .. $n - 1) {
    my $f = $n > 1 ? $i / ($n - 1) : 0; my $len = $len0 + ($len1 - $len0) * $f + rand($o{var} // 8);
    my $plen = ($o{p0} // 20) + (($o{p1} // 6) - ($o{p0} // 20)) * $f;
    my $a = $rot + $i * ($o{turn} // 137.5) + rand(10) - 5;
    hleaf(200, 200, $a, $plen, $len, $len * $wk, (rand(1) < 0.5 ? -1 : 1) * (6 + rand($o{bend} // 10)), $o{light} // 'c2', $o{dark} // 'c1', %o);
  }
}

# Sunflower petal (ray floret): pointed oval split along its midrib.
sub petal {
  my ($x, $y, $ang, $len, $w, $light, $dark, $bend) = @_; $bend //= 0;
  my @p = path($x, $y, $ang, $len, $bend, 8);
  my (@L, @R);
  for my $i (0 .. 8) { my $t = $i / 8; my $h = $w / 2 * (sin(pi * min(1, $t * 0.92 + 0.08))) ** 0.7 * (1 - 0.25 * $t); $h = 0 if $i == 8;
    my ($px, $py, $a) = @{$p[$i]}; my ($dx, $dy) = dir($a); push @L, [$px - $dy * $h, $py + $dx * $h]; push @R, [$px + $dy * $h, $py - $dx * $h]; }
  my ($dx, $dy) = dir($ang + $bend / 2); my $lLit = lit(-$dy, $dx);
  my @m = map { [@$_[0, 1]] } @p;
  poly($lLit ? $light : $dark, @L, reverse @m); poly($lLit ? $dark : $light, @R, reverse @m);
}

# Disc of florets in a golden-angle spiral: dark centre, florets as small facets, pollen ring at the rim.
sub disc {
  my ($x, $y, $r, %o) = @_;
  poly($o{base} // 'c4', ell($x, $y, $r, $r, 24));
  my $n = $o{n} // 160; my $ga = 137.508;
  for my $i (1 .. $n) {
    my $rr = $r * 0.94 * sqrt($i / $n); my ($u, $v) = dir($i * $ga); my ($fx, $fy) = ($x + $u * $rr, $y + $v * $rr);
    my $s = $r * 0.07 * (0.6 + 0.4 * sqrt($i / $n));
    my $l = ($u * -0.7071 + $v * -0.7071);                                      # toward the light
    my $cls = $rr > $r * ($o{ring} // 0.74) ? ($o{pollen} // 'c5') : ($l > -0.2 + ($rr / $r) * 0.3 ? ($o{fl} // 'c5') : undef);
    next unless $cls;
    my $ss = $cls eq ($o{pollen} // 'c5') && $rr > $r * ($o{ring} // 0.74) ? $s : $s * 0.6;
    poly($cls, [$fx - $u * $ss * 0.2, $fy - $v * $ss * 0.2 - $ss], [$fx + $ss * 0.8, $fy], [$fx, $fy + $ss * 0.7], [$fx - $ss * 0.8, $fy]);
  }
  my @c = ell($x - $r * 0.08, $y - $r * 0.08, $r * 0.32, $r * 0.32, 12);        # domed centre catches the light a little
  poly($o{dome} // 'c4', @c) if $o{dome};
}

# An open sunflower head from above: two rings of petals around the disc.
sub head {
  my ($x, $y, $R, %o) = @_; my $np = $o{np} // 22; my $rot = $o{rot} // 0;
  my $dr = $R * ($o{dk} // 0.46);
  for my $i (0 .. $np - 1) { my $a = $rot + ($i + 0.5) * 360 / $np; my ($u, $v) = dir($a);
    petal($x + $u * $dr * 0.8, $y + $v * $dr * 0.8, $a + ($i % 2 ? 5 : -5), $R - $dr * 0.8, $R * 0.27, 'c5', 'c5', 0); }
  for my $i (0 .. $np - 1) { my $a = $rot + $i * 360 / $np; my ($u, $v) = dir($a);
    petal($x + $u * $dr * 0.85, $y + $v * $dr * 0.85, $a, ($R - $dr * 0.85) * 0.97, $R * 0.25, 'c3', 'c5', ($i % 3 - 1) * 10); }
  disc($x, $y, $dr, %o);
}

# A closed bud from above: a star of pointed green bracts, a hint of yellow at the tips inside.
sub bud {
  my ($x, $y, $r, $show) = @_;
  for my $i (0 .. 12) { my $a = $i * 360 / 13 + 7; petal($x, $y, $a, $r, $r * 0.42, 'c2', 'c1', 20); }
  if ($show) { for my $i (0 .. 9) { my $a = $i * 36 + 20; petal($x, $y, $a, $r * 0.62, $r * 0.3, 'c3', 'c5', 0); } }
  for my $i (0 .. 7) { my $a = $i * 45 + 25; petal($x, $y, $a, $r * 0.48, $r * 0.36, 'c2', 'c1', 30); }
  poly('c1', ell($x, $y, $r * 0.16, $r * 0.16, 8));
}

# A sunflower seed: a plump teardrop, near-black with pale stripes along it.
sub sseed {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $Wf = sub { my $t = shift; $w / 2 * ($t ** 0.6) * ((1 - $t) ** 0.35) / 0.535 };   # t 0 = pointed end
  my $P = sub { my ($t, $s) = @_; [$x + $dx * $len * ($t - 0.5) + $nx * $Wf->($t) * $s, $y + $dy * $len * ($t - 0.5) + $ny * $Wf->($t) * $s] };
  my @T = map { $_ / 12 } 0 .. 12;
  my $ls = lit($nx, $ny) ? 1 : -1;
  poly('c4', (map { $P->($_, 1) } @T), (map { $P->($_, -1) } reverse @T));
  for my $st ([0.8, 0.62, "c3"], [0.24, 0.12, "c3"], [-0.62, -0.78, "c3"]) {           # stripes (wider on the lit side)
    my ($a, $b, $cls) = @$st; ($a, $b) = map { $_ * $ls } ($a, $b);
    my @tt = @T[1 .. 11];
    poly($cls, (map { $P->($_, $a) } @tt), (map { $P->($_, $b) } reverse @tt));
  }
  poly('c3', (map { $P->($_, 0.97 * $ls) } @T[2 .. 9]), (map { $P->($_, 0.86 * $ls) } reverse @T[3 .. 8]));   # rim light
}

# 1. Seeds, front view: a little heap of striped sunflower seeds.
sseed(146, 280, -10, 84, 64); sseed(254, 282, 190, 84, 64); sseed(200, 292, 2, 88, 64);
sseed(172, 234, -38, 82, 64); sseed(230, 234, 218, 82, 64); sseed(202, 190, -86, 82, 64);
write_svg('1-seeds-front.svg', 'Sunflower seeds');

# 2. Just sown, top down: seeds pressed into three soil pockets.
my @sown = ([200, 166], [164, 226], [238, 224]);
for (@sown) { soil($_->[0], $_->[1], 30, 25, int($_->[0] * 7 + $_->[1])); }
sseed(198, 166, -60, 40, 22); sseed(166, 228, 200, 40, 22); sseed(238, 224, 30, 40, 22);
write_svg('2-sown.svg', 'Sunflower just sown');

# 3. First growth: two oblong seed leaves and the first pair of small heart-shaped leaves.
soil(200, 200, 32, 28, 3);
for my $a (-160, 20) { hleaf(200, 200, $a, 4, 44, 24, 0, 'c2', 'c1', teeth => 0, noveins => 1); }
for my $a (-70, 110) { hleaf(200, 200, $a, 12, 56, 52, 8, 'c2', 'c1'); }
poly('c2', ell(200, 200, 6, 6, 8)); poly('c1', (ell(200, 200, 6, 6, 8))[0 .. 3]);
write_svg('3-first-growth.svg', 'Sunflower first growth');

# 4. Second growth: big heart-shaped leaves on long stalks, spiralling up the young stem.
soil(200, 200, 34, 30, 4);
spiral(5, 78, 58, 0.92, 41, start => -30, p0 => 44, p1 => 16);
poly('c2', ell(200, 200, 8, 8, 8)); poly('c1', (ell(200, 200, 8, 8, 8))[0 .. 3]);
write_svg('4-second-growth.svg', 'Sunflower second growth');

# 5. Third growth: a full leafy plant with a big green flower bud in the middle, yellow just showing.
soil(200, 200, 36, 32, 5);
spiral(7, 90, 64, 0.92, 51, start => -20, p0 => 62, p1 => 28);
bud(200, 200, 42, 1);
write_svg('5-third-growth.svg', 'Sunflower third growth');

# 6. Harvest: the huge open flower head, golden petals around a dark seed disc, big leaves beneath.
soil(200, 200, 38, 34, 6);
spiral(9, 100, 82, 0.9, 61, start => -10, p0 => 74, p1 => 50, turn => 40);
head(200, 200, 116, np => 22, rot => 4);
write_svg('6-harvest.svg', 'Sunflower ready to harvest');

# 7. Harvested produce, front view: a cut sunflower head tilted towards us on a thick stalk, a few seeds in front.
my ($hx, $hy, $HR) = (188, 166, 140);
{ my @st = ([172, 206], [218, 206], [214, 322], [180, 324]);                    # stalk: lit left half, shaded right
  poly('c1', @st); poly("c2", $st[0], [194, 206], [196, 323], $st[3]);
  poly("c2", ell(197, 323, 17, 5.5, 10)); poly("c3", ell(197, 323, 12.5, 3.6, 10)); }
@SQ = ($hx, $hy, 0.74);
poly('c1', ell($hx, $hy + 30, $HR * 0.62, $HR * 0.62, 20));                     # green back of the head
for my $i (0 .. 17) { my $a = $i * 20 + 10; my ($u, $v) = dir($a); next if $v < 0.15;
  petal($hx + $u * $HR * 0.45, $hy + $v * $HR * 0.45 + 24, $a, $HR * 0.66, $HR * 0.2, "c2", "c1", 0); }
head($hx, $hy, $HR, np => 24, rot => 2, n => 220);
@SQ = ();
for my $s ([236, 330, -30], [282, 318, 200], [262, 300, -70], [300, 344, 170], [252, 356, 10]) { sseed($s->[0], $s->[1], $s->[2], 50, 30); }
write_svg('7-harvest-front.svg', 'Cut sunflower head and seeds');

# 8. Dead (never watered): cracked soil, limp brown leaves lying flat, a shrivelled drooping head.
soil(200, 200, 56, 48, 8);
cracks(7, 83);
spiral(6, 84, 64, 0.7, 81, start => -30, p0 => 22, p1 => 8, light => 'c3', dark => 'c4', bend => 50, teeth => 0, wd => 0.75);
for my $i (0 .. 10) { my $a = $i * 33 + 14; petal(218, 218, $a, 34 + ($i % 3) * 8, 12, "c3", "c4", 50); }
poly("c4", ell(218, 218, 30, 27, 12)); poly("c3", (ell(218, 218, 30, 27, 12))[7 .. 9], [212, 212]);
for my $i (1 .. 30) { my $rr = 25 * sqrt($i / 30); my ($u, $v) = dir($i * 137.5); next unless $u + $v < 0.3; poly("c3", ell(218 + $u * $rr, 218 + $v * $rr, 1.5, 1.5, 4)); }
write_svg('8-dead.svg', 'Sunflower died from lack of water');
print "wrote 8 files to $OUT\n";

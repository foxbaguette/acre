# Dragon fruit (pitaya) crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/dragon-fruit.pl
# A climbing cactus trained over a short post: top down, ribbed stems arch out from the post top.
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/dragon-fruit';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#3E7A47', c2 => '#8DC35C', c3 => '#FBF2DC', c4 => '#4B2C26', c5 => '#D9246F');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub light { my ($nx, $ny) = @_; my $l = sqrt($nx * $nx + $ny * $ny) || 1; ($nx * -0.7071 + $ny * -0.7071) / $l }
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

# A three-ribbed cactus stem seen with one rib toward the viewer: a straight ridge down the middle and two
# wing faces whose outer edges are scalloped, with a small areole in every notch. Faces are lit per segment,
# so an arching stem turns from lit to shaded along its length. Returns the ridge points [x, y, angle].
sub cstem {
  my ($x, $y, $ang, $len, $w, $bend, $lc, $dc, $ac, $seg, $wob, $fixed) = @_;
  $seg //= 24; $ac //= 'c4'; $wob //= 0;
  my $n = max(6, int($len / ($seg / 4) + 0.5));
  my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my $s = $len * $t;
    my $ph = ($s / $seg) - int($s / $seg);
    my $sc = 0.72 + 0.28 * sin(pi * $ph) ** 0.6;                       # scallop between notches
    our $FULLBASE; my $tp = min(1, ($FULLBASE ? 0.97 : 0.55) + $t * 6) * ($t > 0.9 ? sqrt(max(0, 1 - (($t - 0.9) / 0.1) ** 2)) * 0.7 + 0.3 : 1);
    our $TAPER; my $hw = $w / 2 * $sc * $tp * (1 - ($TAPER || 0) * $t);
    my ($dx, $dy) = dir($a);
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py, $a, $ph, $hw];
    $px += $dx * $len / $n; $py += $dy * $len / $n;
    $a += $bend / $n + ($wob ? sin($t * 9 + $wob) * $wob : 0);
  }
  # faces: runs of quads with the same lit state merged into one polygon per side
  for my $side (-1, 1) {
    my $E = $side < 0 ? \@l : \@r;
    my @run; my $cur;
    my $flush = sub { poly($cur, @{$E}[$run[0] .. $run[-1] + 1], map { [$mid[$_][0], $mid[$_][1]] } reverse $run[0] .. $run[-1] + 1) if @run; @run = () };
    for my $i (0 .. $n - 1) {
      my ($dx, $dy) = dir($fixed ? $ang : $mid[$i][2]);
      my $cls = lit(-$dy * -$side, $dx * -$side) ? $lc : $dc;
      $flush->() if defined $cur && $cls ne $cur;
      $cur = $cls; push @run, $i;
    }
    $flush->();
  }
  # areoles in the notches
  if ($ac ne 'none') {
    for my $i (1 .. $n - 1) {
      next unless $mid[$i][3] < $mid[$i - 1][3];
      for my $E (\@l, \@r) {
        my ($ex, $ey) = @{$E->[$i]}; my ($mx, $my) = @{$mid[$i]}[0, 1];
        my ($cx, $cy) = ($ex + ($mx - $ex) * 0.16, $ey + ($my - $ey) * 0.16);
        my $q = max(1.6, $w * 0.075);
        poly($ac, [$cx - $q, $cy], [$cx, $cy - $q], [$cx + $q, $cy], [$cx, $cy + $q]);
      }
    }
  }
  return @mid;
}
sub at { my ($pts, $t) = @_; my $i = int($t * $#$pts + 0.5); @{$pts->[$i]} }

# The top of a cutting seen from above: a three-armed star (the stem's cross-section), lit and shaded facets.
sub star3 {
  my ($x, $y, $r, $rot, $lc, $dc) = @_;
  for my $k (0 .. 2) {
    my $a = $rot + $k * 120;
    my ($dx, $dy) = dir($a); my $tip = [$x + $dx * $r, $y + $dy * $r];
    for my $side (-1, 1) {
      my ($sx, $sy) = dir($a + $side * 60); my $v = [$x + $sx * $r * 0.36, $y + $sy * $r * 0.36];
      my ($nx, $ny) = dir($a + $side * 90);
      poly(lit($nx, $ny) ? $lc : $dc, [$x, $y], $tip, $v);
    }
    my $q = $r * 0.12; poly('c4', [$tip->[0] - $q, $tip->[1]], [$tip->[0], $tip->[1] - $q], [$tip->[0] + $q, $tip->[1]], [$tip->[0], $tip->[1] + $q]);
  }
}
# The short support post seen from above: a pale square top with a shaded bevel and a dark centre hole
# (drawn after the stems, so the stems seem to drape over its top edge).
sub post {
  my ($x, $y, $h) = @_;
  poly('c4', [$x - $h, $y - $h], [$x + $h + 5, $y - $h + 4], [$x + $h + 5, $y + $h + 5], [$x - $h + 4, $y + $h + 5]);
  poly('c3', [$x - $h, $y - $h], [$x + $h, $y - $h], [$x + $h, $y + $h], [$x - $h, $y + $h]);
}

# A leafy scale on the fruit: a magenta flap with a green tip and a slim dark slit of shadow on its shaded side.
sub scale {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $P = sub { my ($u, $v) = @_; [$x + $dx * $u * $len + $nx * $v * $w, $y + $dy * $u * $len + $ny * $v * $w] };
  my $sh = lit($nx, $ny) ? -1 : 1;                 # +1: the +v side is shaded
  poly("c4", $P->(0.0, 0.64 * $sh), $P->(0.6, 0.5 * $sh), $P->(1.05, 0.06 * $sh), $P->(0.6, 0.2 * $sh), $P->(0.1, 0.3 * $sh));
  poly('c5', $P->(0, -0.5), $P->(0.55, -0.36), $P->(0.96, 0), $P->(0.55, 0.36), $P->(0, 0.5));
  poly($sh > 0 ? 'c2' : 'c1', $P->(0.5, -0.37), $P->(1.0, 0), $P->(0.56, 0.02));
  poly($sh > 0 ? 'c1' : 'c2', $P->(0.56, 0.02), $P->(1.0, 0), $P->(0.5, 0.37));
}

# Shaded crescent along the lower-right edge of any convex outline @o around (x,y).
sub shade_rim {
  my ($x, $y, $r, $cls, $kmin, @o) = @_;
  my $n = @o;
  my @d = map { my ($vx, $vy) = ($_->[0] - $x, $_->[1] - $y); my $l = sqrt($vx * $vx + $vy * $vy) || 1; ($vx + $vy) * 0.7071 / $l } @o;
  my $s = 0; for my $i (0 .. $n - 1) { if ($d[$i] > 0.1 && $d[($i - 1) % $n] <= 0.1) { $s = $i; last } }
  my ($cx, $cy) = ($x - $r * 0.3, $y - $r * 0.3);
  my (@out, @in);
  for my $j (0 .. $n - 1) {
    my $i = ($s + $j) % $n; last unless $d[$i] > 0.1;
    push @out, $o[$i];
    my $k = $kmin + (1 - $kmin) * (1 - ($d[$i] - 0.1) / 0.9) ** 1.5;
    push @in, [$cx + ($o[$i][0] - $cx) * $k, $cy + ($o[$i][1] - $cy) * $k];
  }
  poly($cls, @out, reverse @in) if @out > 1;
}

sub ellipse { my ($x, $y, $ang, $a, $b, $n, $f) = @_; my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  map { my $th = 2 * pi * $_ / $n; my ($u, $v) = (cos($th) * $a, sin($th) * $b * (1 + ($f // 0) * cos($th))); [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v] } 0 .. $n - 1 }

# A glossy lit facet on the upper-left shoulder of a fruit.
sub glint {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $s = lit($nx, $ny) ? 1 : -1;
  my $P = sub { my ($u, $v) = @_; [$x + $dx * $u * $len / 2 + $nx * $v * $s * $w / 2, $y + $dy * $u * $len / 2 + $ny * $v * $s * $w / 2] };
  my ($gx, $gy) = ($x - 0.7071 * $w * 0.27, $y - 0.7071 * $w * 0.27);
  poly("c3", [$gx - $dx * $len * 0.08, $gy - $dy * $len * 0.08], [$gx - ($dx + $nx * $s) * $w * 0.05, $gy - ($dy + $ny * $s) * $w * 0.05], [$gx + $dx * $len * 0.06, $gy + $dy * $len * 0.06], [$gx + $nx * $s * $w * 0.06, $gy + $ny * $s * $w * 0.06]);
}

# A dragon fruit seen from above lying on its stem, blossom end pointing `ang`.
sub fruit_top {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $P = sub { my ($u, $v) = @_; [$x + $dx * $u * $len / 2 + $nx * $v * $w / 2, $y + $dy * $u * $len / 2 + $ny * $v * $w / 2] };
  for my $s ([-0.3, 1, 55], [-0.3, -1, 55], [0.4, 1, 38], [0.4, -1, 38]) {       # scales curling off the sides
    my ($u, $side, $da) = @$s; my $p = $P->($u, $side * 0.72);
    scale($p->[0], $p->[1], $ang + $side * $da, $w * 0.52, $w * 0.36);
  }
  my @o = ellipse($x, $y, $ang, $len / 2, $w / 2, 20, 0.08);
  poly('c5', @o);
  shade_rim($x, $y, $w / 2, 'c4', 0.8, @o);
  glint($x, $y, $ang, $len, $w);
  for my $s ([-0.38, 0.0, 0], [0.18, 0.42, 16], [0.18, -0.42, -16]) {              # scales lying on the body
    my ($u, $v, $da) = @$s; my $p = $P->($u, $v);
    scale($p->[0], $p->[1], $ang + $da, $w * 0.38, $w * 0.28);
  }
  my $t = $P->(0.78, 0);                                                           # blossom-end tuft
  scale($t->[0], $t->[1], $ang + 32, $w * 0.44, $w * 0.28); scale($t->[0], $t->[1], $ang - 32, $w * 0.44, $w * 0.28);
  scale($t->[0], $t->[1], $ang, $w * 0.5, $w * 0.3);
}

# A huge white night-blooming flower seen from above: long green sepals, broad white petals,
# a green throat ringed with cream stamens and a starry stigma.
sub flower_top {
  my ($x, $y, $r, $rot) = @_;
  for my $k (0 .. 11) {          # outer sepals: long, narrow, yellow-green, between the petals
    my $a = $rot + $k * 30 + 15; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    my $b = [$x + $dx * $r * 0.45, $y + $dy * $r * 0.45]; my $tp = [$x + $dx * $r * 1.1, $y + $dy * $r * 1.1];
    my $L = [$b->[0] + $nx * $r * 0.13, $b->[1] + $ny * $r * 0.13]; my $R = [$b->[0] - $nx * $r * 0.13, $b->[1] - $ny * $r * 0.13];
    my $l = lit($nx, $ny);
    poly($l ? 'c2' : 'c1', $L, $tp, $b); poly($l ? 'c1' : 'c2', $R, $tp, $b);
  }
  my $petal = sub {
    my ($a, $len, $wd, $cls, $ox, $oy) = @_; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    my $P = sub { my ($u, $v) = @_; [$x + $ox + ($dx * $u * $len + $nx * $v * $wd) * $r, $y + $oy + ($dy * $u * $len + $ny * $v * $wd) * $r] };
    poly($cls, $P->(0.1, 0.25), $P->(0.5, 0.5), $P->(0.82, 0.36), $P->(1.0, 0), $P->(0.82, -0.36), $P->(0.5, -0.5), $P->(0.1, -0.25));
  };
  $petal->($rot + $_ * 30, 1.0, 0.5, 'c3', 0, 0) for 0 .. 11;                 # outer ring of broad pointed petals
  $petal->($rot + $_ * 30 + 15, 0.74, 0.46, 'c3', 0, 0) for 0 .. 11;          # inner ring
  poly('c2', map { my ($dx, $dy) = dir($rot + $_ * 30); [$x + $dx * $r * 0.32, $y + $dy * $r * 0.32] } 0 .. 11);   # deep throat
  for my $k (0 .. 23) { my ($dx, $dy) = dir($rot + $k * 15 + 4); my ($nx, $ny) = (-$dy, $dx);   # cream stamens
    poly('c3', [$x + $dx * $r * 0.12, $y + $dy * $r * 0.12], [$x + $dx * $r * 0.3 + $nx * 2.2, $y + $dy * $r * 0.3 + $ny * 2.2], [$x + $dx * $r * 0.3 - $nx * 2.2, $y + $dy * $r * 0.3 - $ny * 2.2]); }
  poly('c1', map { my ($dx, $dy) = dir($rot + $_ * 30 + 15); [$x + $dx * $r * 0.13, $y + $dy * $r * 0.13] } 0 .. 11);
  poly('c3', map { my ($dx, $dy) = dir($rot + $_ * 24); my $k = $_ % 2 ? 0.04 : 0.13; [$x + $dx * $r * $k, $y + $dy * $r * $k] } 0 .. 14);  # starry stigma
}

# A long green flower bud seen from above with pink-tipped scales, on a short stalk from the stem edge.
sub bud_top {
  my ($x, $y, $ang, $len, $w) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $P = sub { my ($u, $v) = @_; [$x + $dx * $u * $len + $nx * $v * $w, $y + $dy * $u * $len + $ny * $v * $w] };
  my $lt = lit($nx, $ny);
  poly($lt ? 'c2' : 'c1', $P->(0, 0.2), $P->(0.35, 0.5), $P->(0.78, 0.4), $P->(1, 0), $P->(0, 0));
  poly($lt ? 'c1' : 'c2', $P->(0, -0.2), $P->(0.35, -0.5), $P->(0.78, -0.4), $P->(1, 0), $P->(0, 0));
  for my $s ([0.22, 0.5], [0.22, -0.5], [0.55, 0.45], [0.55, -0.45]) {
    my $p = $P->(@$s);
    poly('c5', $p, $P->($s->[0] + 0.2, $s->[1] * 0.78), $P->($s->[0] + 0.12, $s->[1] * 1.25));
  }
  poly('c5', $P->(0.84, 0.13), $P->(1.08, 0), $P->(0.84, -0.13));
}

# The cut end of a stem seen end-on: a pale three-winged star with a green rim and core.
sub cutface {
  my ($x, $y, $r, $rot) = @_;
  my @o; my @i;
  for my $k (0 .. 2) {
    my $a = $rot + $k * 120;
    for my $q ([-60, 0.5], [-22, 0.86], [0, 1.0], [22, 0.86]) { my ($dx, $dy) = dir($a + $q->[0]); push @o, [$x + $dx * $r * $q->[1], $y + $dy * $r * $q->[1] * 0.85]; }
  }
  poly('c1', @o);
  poly('c3', map { [$x + ($_->[0] - $x) * 0.84, $y + ($_->[1] - $y) * 0.84] } @o);
  poly('c2', map { my ($dx, $dy) = dir($rot + $_ * 120); [$x + $dx * $r * 0.16, $y + $dy * $r * 0.13] } 0 .. 2);
}

# A dead, shrivelled stem lying flat: straw wings, a dark split along the ridge and wrinkles across the
# shaded wing.
sub dstem {
  # a dead stem: shrunken and limp, withering to a thin tip; straw on its lit wing, dark brown on the
  # collapsed shaded wing
  my ($x, $y, $ang, $len, $w, $bend) = @_;
  our $TAPER = 0.6;
  cstem($x, $y, $ang, $len, $w, $bend, "c3", "c4", "none", 18, 0, 1);
  $TAPER = 0;
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

# A crown of arching stems from the post top: each [angle, length, bend, width]. Longest drawn first.
sub crown {
  my ($w0, $seg, @st) = @_; my %out;
  for my $k (sort { $st[$b][1] <=> $st[$a][1] } 0 .. $#st) {
    my $s = $st[$k]; my ($dx, $dy) = dir($s->[0]);
    $out{$k} = [cstem(200 + $dx * 4, 200 + $dy * 4, $s->[0], $s->[1], $s->[3] // $w0, $s->[2], 'c2', 'c1', 'c4', $seg)];
  }
  map { $out{$_} } 0 .. $#st;
}
# point on the edge of a stem at fraction t, side +-1, pushed out by `off`: (x, y, stem angle, outward angle)
sub edge { my ($st, $t, $side, $off) = @_; my ($x, $y, $a, undef, $hw) = at($st, $t); my ($dx, $dy) = dir($a);
  ($x - $dy * $side * ($hw + $off), $y + $dx * $side * ($hw + $off), $a, $a + $side * 90) }

# ---------------------------------------------------------------------------------------------

# 1. Planting material, front view: two ribbed stem cuttings lying side by side, their pale three-winged
#    cut ends toward the viewer.
{
  our $FULLBASE = 1; my @a = cstem(104, 288, -40, 210, 62, -3, "c2", "c1", "c4", 42); cutface(104, 288, 36, -90);
  my @b = cstem(150, 336, -36, 200, 62, -3, "c2", "c1", "c4", 42);
  cutface(150, 336, 36, -90);
  $FULLBASE = 0;
}
write_svg('1-seeds-front.svg', 'Dragon fruit cuttings');

# 2. Just planted, top down: three cuttings set in soil pockets at the foot of the post.
my @cut = ([-150, 1], [-30, 2], [90, 3]);
for (@cut) { my ($dx, $dy) = dir($_->[0]); soil(200 + $dx * 40, 200 + $dy * 40, 30, 26, 20 + $_->[1]); }
soil(200, 200, 30, 28, 2);
post(200, 200, 18);
for (@cut) { my ($dx, $dy) = dir($_->[0]); star3(200 + $dx * 40, 200 + $dy * 40, 22, $_->[0] + 30 * $_->[1], 'c2', 'c1'); }
write_svg('2-sown.svg', 'Dragon fruit just planted');

# 3. First growth, top down: each cutting sends a young ribbed shoot up the post and out.
soil(200, 200, 50, 46, 3);
for my $c ([-150, 58, 26], [-30, 62, -22], [90, 56, 24]) {
  my ($dx, $dy) = dir($c->[0]);
  cstem(200 + $dx * 32, 200 + $dy * 32, $c->[0] + 14, $c->[1], 24, $c->[2], 'c2', 'c1', 'c4', 20);
}
post(200, 200, 18);
for (@cut) { my ($dx, $dy) = dir($_->[0]); star3(200 + $dx * 32, 200 + $dy * 32, 16, $_->[0] + 30 * $_->[1], 'c2', 'c1'); }
write_svg('3-first-growth.svg', 'Dragon fruit first growth');

# 4. Second growth, top down: the stems have topped the post and arch out over it.
soil(200, 200, 40, 36, 4);
crown(38, 38, [-120, 112, 24], [-20, 120, 24], [70, 108, 24], [160, 116, 24], [-70, 74, 16, 32], [115, 70, 16, 32]);
post(200, 200, 18);
write_svg('4-second-growth.svg', 'Dragon fruit second growth');

# 5. Third growth, top down: a full crown of arching stems, long buds and huge white flowers.
soil(200, 200, 40, 36, 5);
{
  my @st = crown(42, 40, [-100, 148, 24], [-30, 140, 24], [35, 150, 24], [100, 142, 24], [165, 148, 24], [230, 140, 24],
                 [-65, 92, 16, 36], [70, 90, 16, 36], [195, 92, 16, 36]);
  post(200, 200, 18);
  for my $b ([0, 0.62, 1], [2, 0.7, -1], [4, 0.6, 1], [5, 0.72, -1], [3, 0.55, 1]) {
    my ($x, $y, $a, $o) = edge($st[$b->[0]], $b->[1], $b->[2], -3);
    bud_top($x, $y, $a + $b->[2] * 50, 44, 18);
  }
  for my $f ([1, 0.88, 52, -1], [4, 0.9, 50, -1]) { my ($x, $y, $a, $o) = edge($st[$f->[0]], $f->[1], $f->[3], 4); flower_top($x, $y, $f->[2], 7); }
}
write_svg('5-third-growth.svg', 'Dragon fruit third growth with flowers');

# 6. Harvest, top down: magenta fruits with green-tipped scales growing from the stem edges near the tips.
soil(200, 200, 40, 36, 6);
{
  my @st = crown(46, 42, [-100, 170, 24], [-30, 162, 24], [35, 172, 24], [100, 164, 24], [165, 170, 24], [230, 162, 24],
                 [-65, 110, 16, 40], [70, 106, 16, 40], [195, 110, 16, 40]);
  post(200, 200, 18);
  for my $f ([0, 0.72, 1], [1, 0.7, 1], [2, 0.74, 1], [3, 0.7, 1], [4, 0.74, 1], [5, 0.7, 1]) {
    my ($x, $y, $a, $o) = edge($st[$f->[0]], $f->[1], $f->[2], -2);
    my ($dx, $dy) = dir($a + $f->[2] * 70);
    fruit_top($x + $dx * 34, $y + $dy * 34, $a + $f->[2] * 70, 80, 60);
  }
}
write_svg('6-harvest.svg', 'Dragon fruit ready to harvest');

# 7. Harvested produce, front view: a whole dragon fruit and one half cut open.
{
  my ($x, $y, $ang, $L, $W) = (168, 196, -100, 246, 178);
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $P = sub { my ($u, $v) = @_; [$x + $dx * $u * $L / 2 + $nx * $v * $W / 2, $y + $dy * $u * $L / 2 + $ny * $v * $W / 2] };
  for my $s ([-0.55, 1, 58], [-0.55, -1, 58], [0.0, 1, 44], [0.0, -1, 44], [0.5, 1, 30], [0.5, -1, 30]) {
    my ($u, $side, $da) = @$s; my $p = $P->($u, $side * 0.86); scale($p->[0], $p->[1], $ang + $side * $da, 66, 34);
  }
  my @o = ellipse($x, $y, $ang, $L / 2, $W / 2, 28, 0.06);
  poly('c5', @o);
  shade_rim($x, $y, $W / 2, 'c4', 0.86, @o);
  glint($x, $y, $ang, $L, $W);
  for my $s ([-0.7, 0.0, 0], [-0.3, 0.5, 12], [-0.3, -0.5, -12], [0.45, 0.48, 10], [0.45, -0.48, -10]) {
    my ($u, $v, $da) = @$s; my $p = $P->($u, $v); scale($p->[0], $p->[1], $ang + $da, 52, 34);
  }
  my $t = $P->(0.86, 0);
  scale($t->[0], $t->[1], $ang + 34, 60, 34); scale($t->[0], $t->[1], $ang - 34, 60, 34); scale($t->[0], $t->[1], $ang, 68, 38);
  my $b = $P->(-1.0, 0); blade($b->[0], $b->[1], $ang + 180, 14, 20, 0, 'c2', 'c1', 0.3);   # stem stub
  # half, cut face toward the viewer, resting in front on the right
  my ($hx, $hy) = (264, 292);
  scale($hx + 86, $hy - 16, 0, 46, 30); scale($hx + 52, $hy + 58, 50, 46, 30);
  my @skin = ellipse($hx + 9, $hy + 7, -8, 94, 70, 24); poly('c5', @skin); shade_rim($hx + 9, $hy + 7, 70, 'c4', 0.84, @skin);
  my @rind = ellipse($hx, $hy, -8, 90, 66, 24); poly('c5', @rind);
  my @fl = ellipse($hx, $hy, -8, 81, 58, 24); poly('c3', @fl);
  srand(7);
  for (1 .. 48) {
    my $th = rand(2 * pi); my $k = sqrt(rand(1)) * 0.86;
    my ($sx, $sy) = (cos($th) * 81 * $k, sin($th) * 58 * $k); my ($c, $s) = (cos(deg2rad(-8)), sin(deg2rad(-8)));
    my ($px, $py) = ($hx + $sx * $c - $sy * $s, $hy + $sx * $s + $sy * $c);
    my $a = rand(180); my ($ex, $ey) = dir($a);
    poly('c4', [$px - $ex * 2.8, $py - $ey * 2.8], [$px - $ey * 1.7, $py + $ex * 1.7], [$px + $ex * 2.8, $py + $ey * 2.8], [$px + $ey * 1.7, $py - $ex * 1.7]);
  }
}
write_svg('7-harvest-front.svg', 'Harvested dragon fruit');


# 8. Dead (never watered), top down: cracked dry soil and shrivelled, collapsed straw-coloured stems
#    lying limp around the post, withering to thin tips.
soil(200, 200, 60, 54, 8);
cracks(8, 83, 13, "c3");
for my $s ([-110, 124, 30], [-50, 84, 44], [5, 132, 26], [75, 100, 40], [130, 122, 30], [195, 90, 46], [250, 112, 34]) {
  my ($dx, $dy) = dir($s->[0]);
  dstem(200 + $dx * 8, 200 + $dy * 8, $s->[0], $s->[1], 34, $s->[2]);
}
post(200, 200, 18);
write_svg('8-dead.svg', 'Dragon fruit died from lack of water');
print "wrote 8 files to $OUT\n";

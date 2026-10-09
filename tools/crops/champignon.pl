# Button mushroom (champignon) crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/champignon.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# Then: perl tools/center.pl crops/champignon/1-seeds-front.svg crops/champignon/7-harvest-front.svg
# Signature: smooth round white domes on short thick stems, crowding out of a dark straw-and-compost bed;
# cut open they show pinkish-brown gills and the stem ring.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/champignon';
mkdir 'crops'; mkdir $OUT;
# c1 warm grey-beige shade, c2 light beige mid tone (straw, cap rims), c3 cream white lit faces,
# c4 dark compost brown, c5 pinkish-brown gills (and the dried dead caps)
my %PAL = (c1 => '#AE9A80', c2 => '#DCCBAD', c3 => '#FAF4E6', c4 => '#3D2B21', c5 => '#9C6455');
my @S;
our %MAP;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; $cls = $MAP{$cls} // $cls; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Tapered blade/stalk (as in wheat). $taper < 1 leaves a blunt end.
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $taper) = @_; $taper //= 1;
  my $n = 10; my (@mid, @l, @r); my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $t) ** 0.85 + ($i == $n && $taper == 1 ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2); my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
}

# Crescent along the outline run facing direction ($lx,$ly), returning along an inner copy pulled to ($cx,$cy).
sub crescent {
  my ($cls, $o, $x, $y, $lx, $ly, $thr, $cx, $cy, $k) = @_;
  my $n = @$o;
  my @idx = grep { my ($ox, $oy) = ($o->[$_][0] - $x, $o->[$_][1] - $y); ($ox * $lx + $oy * $ly) > $thr * sqrt($ox * $ox + $oy * $oy) } 0 .. $n - 1;
  return if @idx < 3;
  my $st = 0; for my $j (0 .. $#idx) { my $prev = ($idx[$j] - 1) % $n; $st = $j unless grep { $_ == $prev } @idx; }
  my @run = map { $o->[$idx[($st + $_) % @idx]] } 0 .. $#idx;
  my @in = map { [$cx + ($_->[0] - $cx) * $k, $cy + ($_->[1] - $cy) * $k] } @run[1 .. $#run - 1];
  poly($cls, @run, reverse @in);
}

# ---- Top-down button cap ----------------------------------------------------------------------
# A smooth white dome from above: beige rim, grey-beige shaded crescent lower right, faceted cream
# highlight upper left. $open > 0 = an older cap whose edge has lifted: a gill ring shows on the shaded side.
sub dome {
  my ($x, $y, $r, $seed, $open, $shr) = @_; $open //= 0; $shr //= 0; srand($seed);
  my $n = 18; my $rot = rand(20);
  my @o = map { my ($dx, $dy) = dir($rot + $_ * 360 / $n); my $k = (0.98 + rand(0.04)) * (1 - $shr * ($_ % 3 == 1 ? 0.14 + rand(0.08) : rand(0.06)));
    [$x + $dx * $r * $k, $y + $dy * $r * $k] } 0 .. $n - 1;
  if ($open) {   # gills peeking out under a lifted rim, on the side away from the light
    my @g = map { [$x + $r * 0.12 + ($_->[0] - $x) * 1.04, $y + $r * 0.12 + ($_->[1] - $y) * 1.04] } @o;
    poly('c5', @g);
  }
  poly('c2', @o);
  crescent('c1', \@o, $x, $y, 0.7071, 0.7071, -0.05, $x - $r * 0.3, $y - $r * 0.3, 0.7);
  # faceted highlight on the lit upper left of the dome
  my @h = map { my ($dx, $dy) = dir($rot + 10 + $_ * 360 / 9); [$x - $r * 0.16 + $dx * $r * 0.66, $y - $r * 0.16 + $dy * $r * 0.66] } 0 .. 8;
  @h = map { [$x - $r * 0.16 + ($_->[0] - $x) * 0.6, $y - $r * 0.16 + ($_->[1] - $y) * 0.6] } @o if $shr;
  poly('c3', @h);
  if ($shr) {   # deep wrinkles from the shrunken rim toward the middle
    for my $i (grep { $_ % 6 == 1 } 0 .. $n - 1) {
      my $p = $o[$i]; my $kk = 0.15 + rand(0.4); my ($wx, $wy) = ($x + ($p->[0] - $x) * $kk, $y + ($p->[1] - $y) * $kk);
      my ($ex, $ey) = ($p->[0] - $wx, $p->[1] - $wy); my $l = sqrt($ex * $ex + $ey * $ey) || 1; ($ex, $ey) = (-$ey / $l * 1.8, $ex / $l * 1.8);
      poly('c4', [$p->[0] + $ex, $p->[1] + $ey], [$wx, $wy], [$p->[0] - $ex, $p->[1] - $ey]);
    }
  }
}

# ---- Front view mushroom ----------------------------------------------------------------------
# Whole button mushroom seen from the side: base (bx,by), axis heading $ang (-90 = up), stem height $H, cap width $W.
# $open shows the pinkish gills under the cap (an older mushroom), otherwise the closed veil.
sub fbutton {
  my ($bx, $by, $ang, $H, $W, $seed, $open, $tilt, $shr) = @_; $open //= 0; $tilt //= 0.18; $shr //= 0;
  srand($seed);
  my ($ax, $ay) = dir($ang); my ($px, $py) = (-$ay, $ax);
  my $P = sub { my ($u, $v) = @_; [$bx + $ax * $u + $px * $v, $by + $ay * $u + $py * $v] };
  my $leftLit = lit(-$px, -$py); my $sg = $leftLit ? 1 : -1;   # $sg: +1 = light comes from the -v side
  my $sw = $W * 0.19;
  my $cw = $W / 2; my $ch = $W * 0.46 * (1 - 0.3 * $shr); my $cb = $H; my $ry = $cw * $tilt;
  # stem: thick, slightly swollen base, lit half cream, mid band beige, shaded half grey-beige
  my (@L, @R, @M, @M2);
  for my $i (0 .. 8) { my $t = $i / 8; my $w = $sw * (1.08 - 0.12 * $t + 0.12 * (1 - $t) ** 3);
    push @L, $P->(($H + 2) * $t, -$w); push @R, $P->(($H + 2) * $t, $w); push @M, $P->(($H + 2) * $t, $sg * $w * 0.05); push @M2, $P->(($H + 2) * $t, $sg * $w * 0.55); }
  my @foot = map { my $th = pi * $_ / 8; $P->(-sin($th) * $sw * 0.32, -cos($th) * $sw * 1.2) } 0 .. 8;
  my ($SL, $SD) = $leftLit ? ('c3', 'c1') : ('c1', 'c3');
  poly($SL, @L, reverse(@M), @foot[4, 3, 2, 1, 0]);
  poly($SD, @M, reverse(@R), @foot[8, 7, 6, 5, 4]);
  poly('c2', @M, reverse(@M2), $sg > 0 ? @foot[6, 5, 4] : @foot[2, 3, 4]);
  # under the cap: pinkish gills (open) or the pale closed veil, as a band between the rim and the stem
  my @under = map { my $th = pi * $_ / 12; $P->($cb - sin($th) * $ry * 0.55, -cos($th) * $cw * 0.9) } 0 .. 12;
  poly($open ? 'c5' : 'c2', $P->($cb + 4, -$cw * 0.9), @under, $P->($cb + 4, $cw * 0.9));
  if ($open) { for my $g (-6 .. 6) { my $q = $g / 7; my $v = $q * $cw * 0.86; my $d = $ry * 0.55 * sqrt(1 - $q * $q);
      poly('c4', $P->($cb + 2, $v * 0.7 - 0.6), $P->($cb - $d * 0.9, $v - 0.8), $P->($cb - $d * 0.9, $v + 0.8), $P->($cb + 2, $v * 0.7 + 0.6)); }
    # the torn ring hanging on the stem
    poly('c2', $P->($cb - $ry * 0.2, -$sw * 1.05), $P->($cb - $ry * 0.55 - 6, -$sw * 1.3), $P->($cb - $ry * 0.6 - 9, 0), $P->($cb - $ry * 0.55 - 6, $sw * 1.3), $P->($cb - $ry * 0.2, $sw * 1.05));
    poly('c1', $P->($cb - $ry * 0.6 - 9, 0), $P->($cb - $ry * 0.55 - 6, $sg * $sw * 1.3), $P->($cb - $ry * 0.2, $sg * $sw * 1.05), $P->($cb - $ry * 0.4, 0));
  }
  # cap: smooth dome outline (top arc + gently dipping inrolled rim), layered shading toward the light
  my @dome;
  for my $i (0 .. 14) { my $th = pi * $i / 14; my $k = 1 - $shr * (0.06 + rand(0.1)) * ($i % 2);
    push @dome, $P->($cb + sin($th) ** 0.7 * $ch * $k, -cos($th) * $cw * (1 + 0.025 * sin(2 * $th)) * ($i % 2 ? $k : 1)); }
  for my $i (1 .. 7) { my $th = pi * $i / 8; push @dome, $P->($cb - sin($th) * $ry * 0.9, cos($th) * $cw * 0.995); }   # front rim, right to left
  poly('c1', @dome);
  my $A = $P->($cb + $ch * 0.78, -$sg * $cw * 0.5);
  my @l2 = map { [$A->[0] + ($_->[0] - $A->[0]) * 0.86, $A->[1] + ($_->[1] - $A->[1]) * 0.86] } @dome;
  poly('c2', @l2);
  my $B = $P->($cb + $ch * 0.62, -$sg * $cw * 0.42);
  my @l3 = map { [$B->[0] + ($_->[0] - $B->[0]) * 0.6, $B->[1] + ($_->[1] - $B->[1]) * 0.6] } @dome;
  poly('c3', @l3);
  # rolled rim lip: a slim lit edge along the front rim on the light side
  my @lip = map { my $th = pi * $_ / 8; my $v = cos($th) * $cw * 0.97; $P->($cb - sin($th) * $ry * 0.9 + 3, $v) } ($sg > 0 ? (5 .. 8) : (0 .. 3));
  poly('c3', @lip, map { my $p = $_; [$p->[0] + $ax * 4, $p->[1] + $ay * 4] } reverse @lip) unless $shr;
  if ($shr) {   # shrivel wrinkles running up the dome
    for my $k (1 .. 3) { my $v = (-1 + 2 * $k / 4 + rand(0.2) - 0.1) * $cw * 0.8; my $u0 = $cb - $ry * 0.7 * sqrt(max(0, 1 - ($v / $cw) ** 2)) + 2;
      poly('c4', $P->($u0 + 3, $v - 2.6), $P->($u0 + $ch * (0.3 + rand(0.25)), $v * 0.8 + rand(6) - 3), $P->($u0 + 3, $v + 2.6)); }
  }
}

# The cut half: a lengthwise slice lying face up, showing white flesh, pinkish gills and the ring.
sub fhalf {
  my ($bx, $by, $ang, $H, $W) = @_;
  my ($ax, $ay) = dir($ang); my ($px, $py) = (-$ay, $ax);
  my $P = sub { my ($u, $v) = @_; [$bx + $ax * $u + $px * $v, $by + $ay * $u + $py * $v] };
  my $sw = $W * 0.19; my $cw = $W / 2; my $ch = $W * 0.46; my $cb = $H; my $gh = $W * 0.11;   # gill depth
  my $sk = $W * 0.028;                                                                         # skin thickness
  my $stw = sub { my $t = $_[0]; $sw * (1.08 - 0.12 * $t + 0.12 * (1 - $t) ** 3) };
  # skin: the whole silhouette in grey-beige (cap dome, inrolled margin, stem)
  my @top = map { my $th = pi * $_ / 16; $P->($cb + sin($th) ** 0.7 * $ch, -cos($th) * $cw) } 0 .. 16;
  my @foot = map { my $th = pi * $_ / 8; $P->(-sin($th) * $sw * 0.32, -cos($th) * $sw * 1.2) } 0 .. 8;
  my @sL = map { my $t = $_ / 6; $P->($cb * $t, -$stw->($t)) } 0 .. 6;
  my @sR = map { my $t = $_ / 6; $P->($cb * $t, $stw->($t)) } 0 .. 6;
  my @mR = ($P->($cb - $gh, $sw * 1.25), $P->($cb - $gh - 2, $cw * 0.8), $P->($cb - $gh * 0.6, $cw * 0.97));
  my @mL = map { my $q = $P->(0, 0); my $p = $_; my ($u, $v) = (($p->[0] - $q->[0]) * $ax + ($p->[1] - $q->[1]) * $ay, ($p->[0] - $q->[0]) * $px + ($p->[1] - $q->[1]) * $py); $P->($u, -$v) } reverse @mR;
  poly('c1', @foot[0 .. 8], @sR[1 .. 6], @mR, reverse(@top), @mL, reverse @sL[1 .. 6]);
  # flesh: cream cut face, inset from the skin, cap and stem as one piece
  my @ft = map { my $th = pi * $_ / 16; $P->($cb + sin($th) ** 0.7 * ($ch - $sk), -cos($th) * ($cw - $sk)) } 0 .. 16;
  my @fL = map { my $t = $_ / 6; $P->($sk * 0.6 + ($cb - $sk * 0.6) * $t, -($stw->($t) - $sk)) } 0 .. 6;
  my @fR = map { my $t = $_ / 6; $P->($sk * 0.6 + ($cb - $sk * 0.6) * $t, $stw->($t) - $sk) } 0 .. 6;
  my @inR = ($P->($cb, $sw * 1.05), $P->($cb + 1, $cw * 0.8), $P->($cb - $gh * 0.5, $cw - $sk));
  my @inL = map { my $q = $P->(0, 0); my $p = $_; my ($u, $v) = (($p->[0] - $q->[0]) * $ax + ($p->[1] - $q->[1]) * $ay, ($p->[0] - $q->[0]) * $px + ($p->[1] - $q->[1]) * $py); $P->($u, -$v) } reverse @inR;
  poly('c3', @fR, @inR, reverse(@ft), @inL, reverse @fL);
  # gills: pinkish-brown band under the cap flesh on each side of the stem, fine dark gill lines
  for my $s (-1, 1) {
    my @g = ($P->($cb + 1, $s * $sw * 1.02), $P->($cb + 2, $s * $cw * 0.8), $P->($cb - $gh * 0.45, $s * ($cw - $sk * 1.2)),
             $P->($cb - $gh + 1, $s * $cw * 0.78), $P->($cb - $gh + 1, $s * $sw * 1.02));
    poly('c5', @g);
    for my $k (1 .. 5) { my $v = $s * ($sw * 1.02 + ($cw * 0.8 - $sw * 1.02) * $k / 6);
      poly('c4', $P->($cb + 1, $v - 0.8), $P->($cb - $gh + 2, $v - 0.5), $P->($cb - $gh + 2, $v + 0.5), $P->($cb + 1, $v + 0.8)); }
    # the ring (partial veil): a thin pale skirt from the margin to the stem below the gills
    poly('c2', $P->($cb - $gh + 1, $s * $sw * 1.0), $P->($cb - $gh + 1, $s * $cw * 0.8), $P->($cb - $gh - 2, $s * $cw * 0.8), $P->($cb - $gh - 6, $s * $sw * 1.15), $P->($cb - $gh - 9, $s * $sw * 1.0));
  }
  # stem pith: a faint beige core running up into the cap
  poly('c2', $P->($cb * 0.15, -$sw * 0.12), $P->($cb * 0.9, -$sw * 0.22), $P->($cb + $ch * 0.22, -$sw * 0.12), $P->($cb + $ch * 0.26, 0), $P->($cb + $ch * 0.22, $sw * 0.12), $P->($cb * 0.9, $sw * 0.22), $P->($cb * 0.15, $sw * 0.12));
}

# ---- Ground -----------------------------------------------------------------------------------
sub bed {
  my ($x, $y, $rx, $ry, $seed, $straws) = @_; $straws //= 0; my @o;
  srand($seed);
  for my $i (0 .. 15) { my $th = 2 * pi * $i / 16; my $k = 0.88 + rand(0.18); push @o, [$x + cos($th) * $rx * $k, $y + sin($th) * $ry * $k]; }
  poly('c4', @o);
  for (1 .. $straws) {   # straw bits in the compost
    my $th = rand(2 * pi); my $d = sqrt(rand(1)) * 0.8;
    my ($sx, $sy) = ($x + cos($th) * $rx * $d, $y + sin($th) * $ry * $d);
    blade($sx, $sy, rand(360), 10 + rand(12), 3.2, rand(30) - 15, 'c2', 'c1', 0.3);
  }
}
# Pale mycelium threads spreading out through the compost.
sub threads {
  my ($n, $len, $seed, $x0, $y0) = @_; $x0 //= 200; $y0 //= 200; srand($seed);
  for my $i (0 .. $n - 1) {
    my $a = $i * 360 / $n + rand(24); my ($x, $y) = ($x0, $y0); my (@l, @r);
    for my $k (0 .. 4) { my ($dx, $dy) = dir($a + rand(50) - 25); my $w = 1.7 - $k * 0.3;
      push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w]; $x += $dx * $len / 5; $y += $dy * $len / 5; }
    poly('c3', @l, [$x, $y], reverse @r);
  }
}
# A fuzzy white mycelium patch: soft star blob.
sub fuzz {
  my ($x, $y, $r, $seed) = @_; srand($seed);
  poly('c3', map { my $th = 2 * pi * $_ / 18; my $k = ($_ % 3 ? 1.0 : 0.82) * (0.88 + rand(0.2)); [$x + cos($th) * $r * $k, $y + sin($th) * $r * $k * 0.86] } 0 .. 17);
}
sub cracks {
  my ($n, $seed, $seg) = @_; srand($seed);
  for my $i (0 .. $n - 1) {
    my $a = $i * 360 / $n + rand(20); my ($x, $y) = (200, 200); my (@l, @r);
    for my $k (0 .. 4) { my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.6 - $k * 0.45;
      push @l, [$x - $dy * $w, $y + $dx * $w]; push @r, [$x + $dy * $w, $y - $dx * $w]; $x += $dx * $seg; $y += $dy * $seg; }
    poly('c2', @l, [$x, $y], reverse @r);
  }
}

# A rye grain of spawn: plump kernel, tan with a shaded half, wrapped in white mycelium fuzz.
sub sgrain {   # $myc: 2 = fully colonised (white grain), 1 = brown rye grain with a white fuzz patch, 0 = bare
  my ($x, $y, $ang, $len, $w, $myc, $seed) = @_; srand($seed // int($x * 3 + $y));
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o = map { my $th = 2 * pi * $_ / 16; my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 - 0.15 * cos($th) ** 2);
    [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v] } 0 .. 15;
  my ($body, $lt) = $myc >= 2 ? ('c1', 'c3') : ('c5', 'c1');
  poly($body, @o);
  my @half = lit($nx, $ny) ? @o[8 .. 15, 0] : @o[0 .. 8];
  poly($lt, @half);
  poly('c2', map { [$x + ($_->[0] - $x) * 0.5, $y + ($_->[1] - $y) * 0.5] } @half) if $myc >= 2 && 0;
  if ($myc == 1) {   # a soft white fuzz patch over one end
    my $k = 0.3 + rand(0.4); my ($cx, $cy) = ($x + $dx * $len * ($k - 0.5) * 0.8, $y + $dy * $len * ($k - 0.5) * 0.8);
    my $r = $w * (0.5 + rand(0.12));
    poly('c3', map { my $th = 2 * pi * $_ / 12; my $q = ($_ % 3 ? 1.0 : 0.8); [$cx + cos($th) * $r * $q, $cy + sin($th) * $r * $q * 0.85] } 0 .. 11);
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

# A clump seen from above: leaners [angle, base distance, stem, cap width] tip outward showing stem and dome;
# domes [x, y, r, open] stand upright, drawn smallest first.
sub clump {
  my ($seed, $lean, $domes) = @_; my $k = 0;
  for my $m (sort { $a->[3] <=> $b->[3] } @$lean) {
    my ($a, $bd, $h, $W) = @$m; my ($dx, $dy) = dir($a);
    fbutton(200 + $dx * $bd, 200 + $dy * $bd, $a, $h, $W, $seed + $k++, 0, 0.4);
  }
  dome($_->[0], $_->[1], $_->[2], $seed + 40 + $k++, $_->[3]) for sort { $a->[2] <=> $b->[2] } @$domes;
}

# ===============================================================================================
# 1. Spawn, front: a little heap of rye-grain spawn, most grains already wrapped white in mycelium.
{
  poly('c4', map { my $th = 2 * pi * $_ / 16; [200 + cos($th) * 108, 316 + sin($th) * 10] } 0 .. 15);   # soft dark shadow
  poly('c1', [104, 314], [126, 268], [156, 226], [186, 196], [214, 192], [246, 218], [276, 260], [296, 314]);   # heap body in shade
  srand(11); my @g;
  for my $row ([300, 7], [276, 6], [252, 5], [230, 4], [210, 3], [192, 1]) { my ($y, $c) = @$row;
    for my $k (0 .. $c - 1) { push @g, [200 + ($k - ($c - 1) / 2) * 27 + rand(8) - 4, $y + rand(6) - 3, rand(150) + 15, 32, 18]; } }
  my $i = 0;
  for my $g (@g) { my $m = ($i * 7 + 3) % 5 < 2 ? 1 : 2; $i++; sgrain(@$g, $m, int($g->[0] + $g->[1])); }
  # white mycelium tufts knitting the grains together
  fuzz(156, 262, 15, 3); fuzz(198, 214, 14, 4); fuzz(236, 272, 12, 5); fuzz(188, 296, 13, 6); fuzz(132, 302, 10, 7); fuzz(214, 248, 11, 8); fuzz(176, 240, 10, 9); fuzz(262, 304, 8, 10);
}
write_svg('1-seeds-front.svg', 'Button mushroom grain spawn');

# 2. Just sown, top down: white spawn grains scattered over a dark compost bed.
bed(200, 200, 66, 58, 2, 6);
{ srand(21); for my $i (0 .. 10) { my $th = $i * 360 / 11 + rand(20); my ($dx, $dy) = dir($th); my $d = $i % 3 ? 38 : 14;
    sgrain(200 + $dx * $d + rand(6), 200 + $dy * $d * 0.9 + rand(6), rand(180), 22, 12, $i % 3 ? 2 : 1, 200 + $i); } }
write_svg('2-sown.svg', 'Button mushroom just sown');

# 3. First growth: white mycelium running through the bed, a cluster of tiny white pinheads.
bed(200, 200, 74, 66, 3, 7);
threads(12, 62, 31);
fuzz(200, 200, 26, 32); fuzz(170, 226, 14, 33); fuzz(232, 178, 15, 34);
dome(196, 196, 10, 35); dome(214, 210, 8, 36); dome(184, 214, 7, 37); dome(212, 186, 6, 38); dome(228, 222, 6, 39); dome(176, 184, 5, 40);
write_svg('3-first-growth.svg', 'Button mushroom first growth');

# 4. Second growth: a tight cluster of small round buttons.
bed(200, 200, 86, 78, 4, 9);
threads(10, 72, 41);
clump(40, [[-150, 20, 24, 34], [-30, 22, 22, 32], [90, 20, 24, 34]],
          [[200, 200, 22], [230, 186, 16], [178, 222, 15], [214, 228, 13], [180, 180, 12], [240, 214, 9], [158, 200, 8]]);
write_svg('4-second-growth.svg', 'Button mushroom second growth');

# 5. Third growth: the cluster thickens, buttons swelling to different sizes.
bed(200, 200, 96, 88, 5, 12);
clump(50, [[-160, 30, 34, 48], [-100, 34, 30, 42], [-30, 30, 36, 50], [40, 34, 30, 44], [110, 30, 34, 48], [180, 34, 30, 42], [250, 30, 32, 46]],
          [[198, 198, 32], [236, 176, 22], [166, 222, 22], [222, 236, 20], [170, 170, 18], [250, 218, 14], [146, 196, 12], [208, 160, 13]]);
write_svg('5-third-growth.svg', 'Button mushroom third growth');

# 6. Harvest: a crowded flush of big white domes of all sizes filling the bed.
bed(200, 200, 112, 104, 6, 16);
clump(60, [[-166, 44, 44, 62], [-118, 50, 38, 56], [-66, 44, 46, 64], [-14, 50, 38, 56], [38, 44, 46, 64], [92, 50, 40, 58], [146, 44, 44, 62], [200, 50, 38, 56], [252, 46, 42, 60]],
          [[196, 194, 42], [246, 166, 30, 1], [150, 234, 30], [240, 240, 28, 1], [156, 160, 26], [200, 250, 20], [268, 206, 18], [136, 198, 18], [204, 142, 20]]);
write_svg('6-harvest.svg', 'Button mushroom ready to harvest');

# 7. Harvest, front: three button mushrooms, one cut in half to show the pinkish gills and the stem ring.
poly('c4', map { my $th = 2 * pi * $_ / 16; [214 + cos($th) * 138, 356 + sin($th) * 12] } 0 .. 15);   # soft dark shadow
fbutton(150, 318, -95, 64, 136, 71);
fbutton(282, 322, -84, 50, 110, 72, 1);
fhalf(214, 368, -90, 56, 124);
write_svg('7-harvest-front.svg', 'Harvested button mushrooms');

# 8. Dead (never watered): cracked dry compost, shrivelled brown caps collapsed and tipped over.
bed(200, 200, 96, 88, 8, 10);
cracks(9, 83, 18);
{
  local %MAP = (c3 => 'c1', c2 => 'c5', c1 => 'c4');
  srand(84);
  for my $m ([-150, 34, 34, 50], [-70, 36, 30, 44], [10, 34, 36, 50], [90, 36, 30, 44], [170, 34, 34, 48], [250, 30, 28, 42]) {
    my ($a, $bd, $h, $W) = @$m; my ($dx, $dy) = dir($a);
    fbutton(200 + $dx * $bd, 200 + $dy * $bd, $a + rand(20) - 10, $h * 0.8, $W * 0.82, 80 + $a, 0, 0.5, 1);
  }
  dome(200, 200, 30, 91, 1, 1); dome(232, 226, 18, 92, 1, 1);
}
write_svg('8-dead.svg', 'Button mushroom died from lack of water');
print "wrote 8 files to $OUT\n";

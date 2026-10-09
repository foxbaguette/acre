# Milkweed Pouch (silly fantasy crop: a plant that grows plump milk pouches): 8 stages.
# Run from C:/Claude/Cute Fox:  perl tools/crops/milk-pouch.pl
# Then: perl tools/center.pl crops/milk-pouch/1-seeds-front.svg crops/milk-pouch/7-harvest-front.svg
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/milk-pouch';
mkdir 'crops'; mkdir $OUT;
# c1 soft leaf green, c2 lit green, c3 milk white (pouches, seeds, bleached dead leaves), c4 soil brown,
# c5 milk blue (pouch shade, printed band, drop motif)
my %PAL = (c1 => '#4A8A4E', c2 => '#97CB6E', c3 => '#FFF8EA', c4 => '#5A3A22', c5 => '#86ACDD');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# Generic bent shape split along its midrib into a lit and a shaded half.
sub shape {
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark, $prof) = @_;
  my $n = 12; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * $prof->($t) + ($i == $n ? 0 : 0.5);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? $light : $dark, @l, reverse @mid);
  poly($leftLit ? $dark : $light, @r, reverse @mid);
  return ($px, $py, $a - $bend / $n);
}
sub blade { shape(@_[0 .. 7], sub { (1 - $_[0]) ** 0.85 }) }
sub stem  { shape(@_[0 .. 7], sub { 1 - 0.4 * $_[0] }) }
# Broad soft "cow-ear" leaf: wide, rounded, a short blunt tip.
sub leaf  { shape(@_[0 .. 7], sub { my $t = shift; $t < 0.05 ? 0.22 : sin(pi * $t ** 0.9) ** 0.5 }) }

sub walk {
  my ($x, $y, $ang, $len, $bend, $upto) = @_; $upto //= 1;
  my $n = 12; my $a = $ang;
  for my $i (1 .. int($n * $upto + 0.5)) { my ($dx, $dy) = dir($a); $x += $dx * $len / $n; $y += $dy * $len / $n; $a += $bend / $n; }
  return ($x, $y, $a);
}

# Crescent along the outline run facing (lx,ly), inner edge pulled toward (cx,cy).
sub crescent {
  my ($cls, $o, $x, $y, $lx, $ly, $thr, $cx, $cy, $k) = @_;
  my $n = @$o;
  my @idx = grep { my ($ox, $oy) = ($o->[$_][0] - $x, $o->[$_][1] - $y); ($ox * $lx + $oy * $ly) > $thr * sqrt($ox * $ox + $oy * $oy) } 0 .. $n - 1;
  return if @idx < 3;
  my $st = 0; for my $j (0 .. $#idx) { my $prev = ($idx[$j] - 1) % $n; $st = $j unless grep { $_ == $prev } @idx; }
  my @run = map { $o->[$idx[($st + $_) % @idx]] } 0 .. $#idx;
  my @in = map { [$cx + ($_->[0] - $cx) * $k, $cy + ($_->[1] - $cy) * $k] } @run[1 .. $#run - 1];
  poly($cls, @run, reverse @in);
  return @run;
}

# Half-width profile of a filled pouch (water-balloon): t = 0 at the tied neck, 1 at the round bottom.
sub pouch_hw {
  my ($t) = @_;
  my $b = sqrt(max(0, 1 - (($t - 0.58) / 0.42) ** 2));
  return 0.15 + (0.5 - 0.15) * ($t / 0.21) ** 2 if $t < 0.21;
  return $b;
}
# A milk pouch: tied neck at (x,y), hanging toward `ang`. kind: 'm' full milk, 'b' green bud.
sub pouch {
  my ($x, $y, $ang, $len, $w, $kind) = @_;
  $kind //= 'm';
  my ($body, $shade) = $kind eq 'b' ? ('c3', 'c2') : ('c3', 'c5');
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $P = sub { my ($t, $s) = @_; [$x + $dx * $len * $t + $nx * $s * $w / 2, $y + $dy * $len * $t + $ny * $s * $w / 2] };
  my $n = 28; my (@L, @R);
  for my $i (0 .. $n) { my $t = 1 - (1 - $i / $n) ** 1.0; my $h = pouch_hw($t); push @L, $P->($t, $h); push @R, $P->($t, -$h); }
  my @o = (@L, reverse @R[0 .. $n - 1]);
  my ($cx, $cy) = @{ $P->(0.6, 0) };
  my $r = $w / 2;
  poly($body, @o);
  if ($kind eq 'm') {
    # milk-drop motif below the band (on the lit side of centre)
    my ($mx, $my) = @{ $P->(0.6, 0) }; $mx -= $r * 0.2; $my -= $r * 0.2; my $dr = $w * 0.12;
    poly('c5', map { my $th = 2 * pi * $_ / 12; my $c = cos($th); my $u = $c > 0 ? $c * $dr * 1.7 : $c * $dr; my $v = sin($th) * $dr * ($c > 0 ? (1 - $c) ** 0.6 : 1);
      [$mx - $dx * $u + $nx * $v, $my - $dy * $u + $ny * $v] } 0 .. 11);
  }
  # shaded side: broad crescent facing lower right, plus a deeper core where the bag curves away
  crescent($shade, \@o, $cx, $cy, 0.7071, 0.7071, -0.1, $cx - $r * 0.55, $cy - $r * 0.55, 0.74);
  if ($kind eq 'm') {   # glossy rim reflection: a thin pale sliver running inside the shaded side
    my $no = @o; my @f = map { my ($ox, $oy) = ($o[$_][0] - $cx, $o[$_][1] - $cy); ($ox + $oy) * 0.7071 > 0.5 * sqrt($ox * $ox + $oy * $oy) ? 1 : 0 } 0 .. $no - 1;
    my ($st) = grep { $f[$_] && !$f[($_ - 1) % $no] } 0 .. $no - 1; my @g; if (defined $st) { for (my $i = $st; $f[$i % $no] && @g < $no; $i++) { push @g, $o[$i % $no]; } }
    if (@g >= 3) {
      my @a = map { [$cx + ($_->[0] - $cx) * 0.94, $cy + ($_->[1] - $cy) * 0.94] } @g;
      my @b = map { my $i = $_; my $q = 0.94 - 0.09 * sin(pi * $i / $#g); [$cx + ($g[$i][0] - $cx) * $q, $cy + ($g[$i][1] - $cy) * $q] } 0 .. $#g;
      poly('c3', @a, reverse @b);
    }
  }
  # glossy highlight: a clean lozenge on the lit shoulder (shade-coloured edge makes it read as gloss)
  my ($hx, $hy) = ($cx - $r * 0.42, $cy - $r * 0.42);
  my ($ux, $uy) = dir(-45);
  if ($kind eq 'b') {
    poly('c3', [$hx - $ux * $r * 0.22, $hy - $uy * $r * 0.22], [$hx - $r * 0.05, $hy - $r * 0.05], [$hx + $ux * $r * 0.22, $hy + $uy * $r * 0.22], [$hx + $r * 0.07, $hy + $r * 0.07]);
  }
  # pinched, gathered frill above the tie
  my $fl = $len * 0.11; my $fw = $w * 0.12;
  for my $s (-1, 1, 0) {
    my ($bx, $by) = ($x - $dx * 4 + $nx * $s * $fw * 0.5, $y - $dy * 4 + $ny * $s * $fw * 0.5);
    my ($ex, $ey) = ($bx - $dx * $fl * ($s ? 0.85 : 1) + $nx * $s * $fw * 0.9, $by - $dy * $fl * ($s ? 0.85 : 1) + $ny * $s * $fw * 0.9);
    my $cl = $s == 0 ? $body : (lit($nx * $s, $ny * $s) ? $body : $shade);
    poly($cl, [$bx + $nx * $fw * 0.55, $by + $ny * $fw * 0.55], [$ex + $nx * $fw * 0.25, $ey + $ny * $fw * 0.25], [$ex - $nx * $fw * 0.25, $ey - $ny * $fw * 0.25], [$bx - $nx * $fw * 0.55, $by - $ny * $fw * 0.55]);
  }
  # green twist tie at the neck
  my $tw = $w * 0.13;
  my @tie = ([$x + $nx * $tw - $dx * 5, $y + $ny * $tw - $dy * 5], [$x - $nx * $tw - $dx * 5, $y - $ny * $tw - $dy * 5],
             [$x - $nx * $tw + $dx * 4, $y - $ny * $tw + $dy * 4], [$x + $nx * $tw + $dx * 4, $y + $ny * $tw + $dy * 4]);
  poly('c1', @tie);
  my $ls = lit($nx, $ny) ? 1 : -1;
  poly('c2', [$x + $nx * $ls * $tw - $dx * 5, $y + $ny * $ls * $tw - $dy * 5], [$x - $dx * 5, $y - $dy * 5], [$x + $dx * 4, $y + $dy * 4], [$x + $nx * $ls * $tw + $dx * 4, $y + $ny * $ls * $tw + $dy * 4]);
  return @o;
}


# A flat, crumpled, emptied pouch (dead stage): wrinkled outline, blue creases.
sub deflated {
  my ($x, $y, $ang, $len, $w, $seed) = @_;
  srand($seed);
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $P = sub { my ($t, $s) = @_; [$x + $dx * $len * $t + $nx * $s * $w / 2, $y + $dy * $len * $t + $ny * $s * $w / 2] };
  my $n = 12; my (@L, @R);
  for my $i (0 .. $n) { my $t = $i / $n; my $h = (0.25 + 0.75 * sin(pi * min(1, $t * 0.85 + 0.12)) ** 0.8) * ($i % 2 ? 0.8 : 1.0) * (0.9 + rand(0.15));
    push @L, $P->($t, $h); push @R, $P->($t, -$h * (0.85 + rand(0.2))); }
  my @o = (@L, reverse @R[0 .. $n - 1]);
  poly('c3', @o);
  my ($cx, $cy) = @{ $P->(0.5, 0) };
  crescent('c5', \@o, $cx, $cy, 0.7071, 0.7071, 0.1, $cx - $w * 0.25, $cy - $w * 0.25, 0.8);
  for my $k (1 .. 3) {      # crease folds: short wedges running in from the crumpled edge
    my $t = 0.25 + $k * 0.18; my $s = ($k % 2 ? 1 : -1);
    poly('c5', $P->($t - 0.05, $s * 0.75), $P->($t + 0.1, $s * 0.05), $P->($t + 0.05, $s * 0.75));
  }
  poly('c4', [$x + $nx * 4 - $dx * 2, $y + $ny * 4 - $dy * 2], [$x - $nx * 4 - $dx * 2, $y - $ny * 4 - $dy * 2], [$x - $nx * 4 + $dx * 5, $y - $ny * 4 + $dy * 5], [$x + $nx * 4 + $dx * 5, $y + $ny * 4 + $dy * 5]);
}

# Droplet seed (point up / toward ang): white with a blue shade.
sub droplet {
  my ($x, $y, $ang, $r) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my @o;
  for my $i (0 .. 17) {
    my $th = 2 * pi * $i / 18; my $c = cos($th);
    my $u = $c > 0 ? $c * $r * 1.55 : $c * $r; my $v = sin($th) * $r * ($c > 0 ? (1 - $c) ** 0.9 * 1.0 + 0.0 : 1);
    $v = sin($th) * $r * (1 - $c ** 1 * 0.0) if $c <= 0;
    if ($c > 0) { $v = sin($th) * $r * (1 - $c) ** 0.6; }
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly('c3', @o);
  crescent('c5', \@o, $x, $y, 0.7071, 0.7071, -0.1, $x - $r * 0.6, $y - $r * 0.6, 0.78);
  poly('c3', map { my ($ex, $ey) = dir($_ * 90 + 20); [$x - $r * 0.35 + $ex * $r * 0.14, $y - $r * 0.32 + $ey * $r * 0.22] } 0 .. 3);
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
      my ($dx, $dy) = dir($a + rand(40) - 20); my $w = 2.6 - $k * 0.45;
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

our $SPOTS = 0;
# Leaf with an optional hint of cow patches on it.
sub cowleaf {
  my ($x, $y, $ang, $len, $w, $bend, $seed) = @_;
  shape($x, $y, $ang, $len, $w, $bend, 'c2', 'c1', sub { my $t = shift; $t < 0.05 ? 0.22 : sin(pi * $t ** 0.9) ** 0.5 });
  return unless $SPOTS && $len > 50;
  srand($seed);
  for my $k (0 .. 1) {
    my $t = 0.38 + $k * 0.28 + rand(0.06); my $s = ($k ? -1 : 1) * (0.18 + rand(0.12));
    my ($px, $py, $pa) = walk($x, $y, $ang, $len, $bend, $t); my ($dx, $dy) = dir($pa);
    my $cx = $px - $dy * $s * $w; my $cy = $py + $dx * $s * $w; my $rr = $w * (0.09 + rand(0.04));
    poly('c4', map { my ($ex, $ey) = dir($_ * 51 + $k * 20); my $q = $rr * ($_ % 2 ? 0.75 : 1.1); [$cx + $ex * $q, $cy + $ey * $q] } 0 .. 6);
  }
}
sub rosette {
  my ($n, $len, $lenVar, $w, $bendMax, $seed, $start) = @_;
  srand($seed); my @b;
  for my $i (0 .. $n - 1) {
    my $a = ($start // -90) + $i * 360 / $n + rand(14) - 7;
    push @b, [$a, $len + rand($lenVar), (rand(1) < 0.5 ? -1 : 1) * $bendMax * (0.4 + rand(0.6))];
  }
  my $k = 0;
  cowleaf(200, 200, $_->[0], $_->[1], $w * $_->[1] / $len, $_->[2], $seed * 10 + $k++) for sort { $b->[1] <=> $a->[1] } @b;
}
# A curving stalk from the plant centre with a pouch hanging at its tip (top down: pouch lies out on the ground).
sub pouch_on_stalk {
  my ($ang, $slen, $bend, $plen, $pw, $kind) = @_;
  my ($ex, $ey, $ea) = stem(200, 200, $ang, $slen, 7, $bend, 'c2', 'c1');
  pouch($ex, $ey, $ea, $plen, $pw, $kind);
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: a little heap of milk-white droplet seeds.
for ([140, 292, -100, 24], [200, 298, -86, 25], [260, 292, -74, 24], [170, 246, -104, 23], [230, 246, -78, 23], [200, 200, -90, 22]) { droplet(@$_); }
write_svg('1-seeds-front.svg', 'Milkweed Pouch seeds');

# 2. Just sown, top down: droplet seeds pressed into soil pockets.
my @sown = ([166, 168, -60], [240, 162, -110], [202, 212, -80], [150, 240, -40], [252, 238, -130]);
for (@sown) { soil($_->[0], $_->[1], 30, 25, int($_->[0] * 7 + $_->[1])); }
for (@sown) { droplet($_->[0], $_->[1] + 3, $_->[2], 11); }
write_svg('2-sown.svg', 'Milkweed Pouch just sown');

# 3. First growth: two broad round seed leaves and a small first leaf.
soil(200, 200, 34, 30, 3);
cowleaf(200, 200, 195, 64, 46, -10, 1);
cowleaf(200, 200, 15, 64, 46, -10, 2);
cowleaf(200, 200, -80, 46, 34, 8, 3);
write_svg('3-first-growth.svg', 'Milkweed Pouch first growth');

# 4. Second growth: a rosette of broad soft cow-ear leaves.
soil(200, 200, 34, 30, 4);
rosette(7, 104, 22, 64, 18, 41, -70);
rosette(4, 60, 10, 46, 10, 42, -25);
write_svg('4-second-growth.svg', 'Milkweed Pouch second growth');

# 5. Third growth: bigger rosette and small pale-green pouches budding on arching stalks.
soil(200, 200, 34, 30, 5);
rosette(8, 128, 22, 72, 18, 51, -80);
for ([-40, 70, 16], [60, 66, -14], [150, 70, 18], [235, 64, -16]) { pouch_on_stalk($_->[0], $_->[1], $_->[2], 46, 34, 'b'); }
rosette(4, 66, 10, 48, 10, 52, -10);
write_svg('5-third-growth.svg', 'Milkweed Pouch third growth');

# 6. Harvest: full white milk pouches lying out between the leaves on curving stalks.
soil(200, 200, 34, 30, 6);
rosette(9, 140, 22, 76, 18, 61, -70);
for ([-90, 64, 18], [-18, 70, -16], [54, 66, 16], [126, 70, -16], [198, 66, 18]) { pouch_on_stalk($_->[0], $_->[1], $_->[2], 92, 70, 'm'); }
rosette(5, 70, 10, 50, 10, 62, -54);
write_svg('6-harvest.svg', 'Milkweed Pouch ready to harvest');

# 7. Harvest, front view: three plump milk pouches with pinched tops and leaf stubs.
{
  my @p = ([200, 92, 90, 150, 118], [134, 152, 98, 138, 110], [268, 156, 84, 138, 110]);
  for my $q (@p) {
    my ($x, $y, $a) = @$q;
    my ($dx, $dy) = dir($a);
    stem($x - $dx * 34, $y - $dy * 34, $a, 30, 9, 0, 'c2', 'c1');                     # cut stalk stub
    cowleaf($x - $dx * 22, $y - $dy * 22, $a + ($x < 200 ? 120 : -120) + 180, 44, 30, 0, 9);
  }
  for my $q (@p) { pouch(@$q, 'm'); }
}
write_svg('7-harvest-front.svg', 'Harvested milk pouches');

# 8. Dead (never watered): cracked dry soil, bleached straw leaves and crumpled, emptied pouches.
soil(200, 200, 66, 56, 8);
cracks(8, 83, 12, 'c3');
{
  local $SPOTS = 0;
  srand(81);
  for my $i (0 .. 8) {
    my $a = -80 + $i * 40 + rand(16) - 8; my $l = 92 + rand(36); my $bend = (rand(1) < 0.5 ? -1 : 1) * (40 + rand(40));
    shape(200, 200, $a, $l, 26, $bend, "c3", "c4", sub { my $t = shift; ($t < 0.05 ? 0.22 : sin(pi * $t ** 0.8) ** 0.7) * (0.62 + 0.38 * abs(sin($t * 17))) });
  }
}
for ([-40, 58, 30, 70, 50, 1], [100, 62, -30, 66, 48, 2], [210, 56, 24, 64, 46, 3]) {
  my ($a, $sl, $bend, $pl, $pw, $sd) = @$_;
  my ($ex, $ey, $ea) = stem(200, 200, $a, $sl, 6, $bend, 'c3', 'c4');
  deflated($ex, $ey, $ea, $pl, $pw, $sd);
}
write_svg('8-dead.svg', 'Milkweed Pouch died from lack of water');
print "wrote 8 files to $OUT\n";

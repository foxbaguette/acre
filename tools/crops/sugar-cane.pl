# Sugar cane crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/sugar-cane.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/sugar-cane';
mkdir 'crops'; mkdir $OUT;
my %PAL = (c1 => '#3B7A3C', c2 => '#8DC25A', c3 => '#F2E3B3', c4 => '#4E2E26', c5 => '#94405E');
my @S;   # current shape list

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A tapered leaf blade (as in wheat.pl), with an optional pale midrib down its middle - the white midrib
# is what makes a cane leaf. Returns the points along it: [x, y, angle].
sub blade {
  my ($x, $y, $ang, $len, $w, $bend, $lightc, $dark, $rib, $taper) = @_;
  $taper //= 1;
  my $n = 12; my (@mid, @l, @r);
  my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n;
    my ($dx, $dy) = dir($a);
    my $hw = $w / 2 * (1 - $taper * $t ** 1.3) ** 0.8 * min(1, 0.75 + $t * 2) + ($i == $n && $taper == 1 ? 0 : 0.6);
    push @l, [$px - $dy * $hw, $py + $dx * $hw];
    push @r, [$px + $dy * $hw, $py - $dx * $hw];
    push @mid, [$px, $py, $a, $hw];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang);
  my $leftLit = lit(-$dy, $dx);
  my @m = map { [$_->[0], $_->[1]] } @mid;
  poly($leftLit ? $lightc : $dark, @l, reverse @m);
  poly($leftLit ? $dark : $lightc, @r, reverse @m);
  if ($rib) {
    my (@a, @b);
    for my $i (0 .. $n - 2) { my ($qx, $qy, $qa, $hw) = @{$mid[$i]}; my ($ex, $ey) = dir($qa); my $rw = max(0.8, $hw * 0.22) * (1 - $i / $n);
      push @a, [$qx - $ey * $rw, $qy + $ex * $rw]; push @b, [$qx + $ey * $rw, $qy - $ex * $rw]; }
    poly($rib, @a, [$mid[$n - 1][0], $mid[$n - 1][1]], reverse @b);
  }
  return @mid;
}

# A jointed cane stalk from (x,y) heading `ang`: a round stem lit on one side, shaded on the other, with a
# pale waxy band and a dark ring at every node, the nodes slightly swollen, and a bud on alternate nodes.
sub cane {
  my ($x, $y, $ang, $len, $w, $seg, $body, $lightc, $shade, $band, $buds) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $ls = lit($nx, $ny) ? 1 : -1;           # +1: the +normal side is lit
  my $P = sub { my ($u, $v) = @_; [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v] };
  my $hw = $w / 2;
  my $nseg = max(1, int($len / $seg + 0.5)); my $sl = $len / $nseg;
  for my $k (0 .. $nseg - 1) {               # barrel-shaped internodes
    my ($u0, $u1) = ($k * $sl, ($k + 1) * $sl); my $um = ($u0 + $u1) / 2;
    my @e = ([$u0, 0.9], [$u0 + $sl * 0.25, 0.98], [$um, 1.0], [$u1 - $sl * 0.25, 0.98], [$u1, 0.9]);
    poly($body, (map { $P->($_->[0], $hw * $_->[1]) } @e), (map { $P->($_->[0], -$hw * $_->[1]) } reverse @e));
    poly($shade, (map { $P->($_->[0], -$ls * $hw * $_->[1]) } @e), (map { $P->($_->[0], -$ls * $hw * $_->[1] * 0.42) } reverse @e));
    poly($lightc, $P->($u0 + $sl * 0.12, $ls * $hw * 0.42), $P->($u0 + $sl * 0.3, $ls * $hw * 0.58), $P->($u1 - $sl * 0.2, $ls * $hw * 0.58), $P->($u1 - $sl * 0.12, $ls * $hw * 0.46), $P->($um, $ls * $hw * 0.4)) if $lightc;
  }
  for my $k (1 .. $nseg - 1) {                # node: a dark growth ring with a thin pale wax band just below it
    my $u = $k * $sl; my $rw = max(1.6, $w * 0.06);
    poly($shade, $P->($u - $rw, $hw * 0.96), $P->($u + $rw, $hw * 0.96), $P->($u + $rw, -$hw * 0.96), $P->($u - $rw, -$hw * 0.96));
    poly($band, $P->($u - $rw - $w * 0.14, $hw * 0.93), $P->($u - $rw, $hw * 0.95), $P->($u - $rw, -$hw * 0.95), $P->($u - $rw - $w * 0.14, -$hw * 0.93));
    if ($buds && $k % 2) {                    # a small pointed bud just above the node, alternating sides
      my $s = (($k - 1) / 2) % 2 ? 1 : -1;
      poly('c2', $P->($u + $rw, $s * $hw * 0.05), $P->($u + $rw + $w * 0.5, $s * $hw * 0.3), $P->($u + $rw, $s * $hw * 0.62));
      poly('c1', $P->($u + $rw, $s * $hw * 0.05), $P->($u + $rw + $w * 0.5, $s * $hw * 0.3), $P->($u + $rw + $w * 0.1, $s * $hw * 0.22));
    }
  }
}

# The cut face at the end of a cane: pale fibrous flesh inside the rind.
sub cutend {
  my ($x, $y, $ang, $w, $squash) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  my $E = sub { my ($k) = @_; map { my $th = 2 * pi * $_ / 14; [$x + $dx * cos($th) * $w / 2 * $squash * $k + $nx * sin($th) * $w / 2 * $k, $y + $dy * cos($th) * $w / 2 * $squash * $k + $ny * sin($th) * $w / 2 * $k] } 0 .. 13 };
  poly('c5', $E->(1.0));
  poly('c3', $E->(0.8));
  # a few fibre dots
  my @d = ([0.2, 0.1], [-0.25, 0.3], [0.05, -0.35], [-0.1, -0.05], [0.3, -0.2]);
  for (@d) { my ($a, $b) = @$_; my $px = $x + $dx * $a * $w / 2 * $squash + $nx * $b * $w / 2; my $py = $y + $dy * $a * $w / 2 * $squash + $ny * $b * $w / 2;
    poly('c4', [$px - 1.2, $py], [$px, $py - 1.2], [$px + 1.2, $py], [$px, $py + 1.2]); }
}

# A cane seen from straight above: its round top, with a whorl of young leaves unfolding from it.
sub canetop {
  my ($x, $y, $r) = @_;
  my @o = map { my $th = 2 * pi * $_ / 12; [$x + cos($th) * $r, $y + sin($th) * $r] } 0 .. 11;
  poly('c5', @o);
  poly('c4', @o[0 .. 6], [$x + $r * 0.2, $y + $r * 0.2]);
  poly('c3', map { my $th = 2 * pi * $_ / 12; [$x - $r * 0.15 + cos($th) * $r * 0.5, $y - $r * 0.15 + sin($th) * $r * 0.5] } 0 .. 11);
}

# Small irregular patch of soil.
sub soil {
  my ($x, $y, $rx, $ry, $seed, $rot) = @_; my @o;
  srand($seed); my ($c, $s) = (cos(deg2rad($rot // 0)), sin(deg2rad($rot // 0)));
  for my $i (0 .. 11) { my $th = 2 * pi * $i / 12; my $k = 0.82 + rand(0.3); my ($u, $v) = (cos($th) * $rx * $k, sin($th) * $ry * $k); push @o, [$x + $u * $c - $v * $s, $y + $u * $s + $v * $c]; }
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

# A fan of arching strap leaves around (x,y): $n leaves, lengths len..len+var, longest drawn first.
sub fan {
  my ($x, $y, $n, $len, $var, $w, $bend, $seed, $start, $lc, $dc, $rib) = @_;
  srand($seed); my @b;
  for my $i (0 .. $n - 1) {
    our $SPREAD; my $a = $SPREAD ? $start - $SPREAD / 2 + $i * $SPREAD / ($n - 1) + rand(14) - 7 : ($start // -90) + $i * 360 / $n + rand(20) - 10;
    push @b, [$a, $len + rand($var), (rand(1) < 0.5 ? -1 : 1) * $bend * (0.5 + rand(0.5))];
  }
  blade($x, $y, $_->[0], $_->[1], $w, $_->[2], $lc // 'c2', $dc // 'c1', $rib // 'c3') for sort { $b->[1] <=> $a->[1] } @b;
}

# ---------------------------------------------------------------------------------------------
# 1. Planting material, front view: two cane setts - short cut pieces of stalk, each with buds on its nodes.
cane(96, 248, -12, 196, 46, 64, 'c5', 'c3', 'c4', 'c3', 1); cutend(96, 248, -12, 46, 0.42); cutend(96 + 196 * cos(deg2rad(-12)), 248 + 196 * sin(deg2rad(-12)), -12, 46, 0.42);
cane(128, 318, 6, 186, 46, 62, 'c5', 'c3', 'c4', 'c3', 1); cutend(128, 318, 6, 46, 0.42); cutend(128 + 186 * cos(deg2rad(6)), 318 + 186 * sin(deg2rad(6)), 6, 46, 0.42);
write_svg('1-seeds-front.svg', 'Sugar cane setts');

# 2. Just planted, top down: two setts laid in a shallow furrow, their ends pressed under small clods.
soil(200, 200, 84, 40, 2, -20);
cane(132, 202, -20, 124, 28, 41, "c5", "c3", "c4", "c3", 1);
cane(170, 242, -20, 108, 28, 36, 'c5', 'c3', 'c4', 'c3', 1);
soil(250, 160, 9, 8, 22); soil(168, 242, 9, 8, 24);
write_svg('2-sown.svg', 'Sugar cane just planted');

# A young cane shoot from above: a fan of white-ribbed leaves around its little purple top.
sub shoot {
  my ($x, $y, $n, $len, $var, $w, $bend, $seed, $start, $r) = @_;
  fan($x, $y, $n, $len, $var, $w, $bend, $seed, $start);
  canetop($x, $y, $r);
}

# 3. First growth, top down: shoots spring up from the buds of the setts, each a little fan of leaves.
soil(200, 200, 66, 36, 3, -20);
cane(136, 200, -20, 116, 24, 39, 'c5', 'c3', 'c4', 'c3', 0);
shoot(176, 186, 4, 58, 16, 14, 26, 31, -70, 6);
shoot(240, 164, 4, 60, 14, 14, 26, 32, -120, 6);
shoot(214, 236, 4, 52, 16, 14, 26, 33, 20, 6);
write_svg('3-first-growth.svg', 'Sugar cane first growth');

# 4. Second growth, top down: a leafy clump of broad arching leaves with white midribs, three shoot tops.
soil(200, 200, 42, 36, 4);
shoot(186, 188, 6, 104, 26, 24, 44, 41, -110, 8);
shoot(220, 194, 6, 100, 24, 24, 44, 42, -20, 8);
shoot(200, 222, 5, 96, 22, 24, 40, 43, 70, 8);
write_svg('4-second-growth.svg', 'Sugar cane second growth');

# 5. Third growth, top down: a dense clump; the first jointed canes lean out between the arching leaves.
soil(200, 200, 42, 36, 5);
fan(200, 200, 10, 124, 24, 24, 46, 51, -60);
for my $c ([-120, 76], [-20, 80], [80, 74], [170, 78]) {
  my ($dx, $dy) = dir($c->[0]);
  cane(200, 200, $c->[0], $c->[1], 20, 20, 'c5', 'c3', 'c4', 'c3', 0);
  our $SPREAD = 220;
  shoot(200 + $dx * $c->[1], 200 + $dy * $c->[1], 6, 66, 20, 20, 36, 52 + $c->[0], $c->[0], 8);
  $SPREAD = 0;
}
shoot(200, 200, 5, 62, 16, 18, 30, 53, -30, 8);
write_svg('5-third-growth.svg', 'Sugar cane third growth');

# 6. Harvest, top down: tall ripe canes lean out of the clump, their jointed purple stalks on show, leaf fans
#    at the tops and dry straw leaves at the base.
soil(200, 200, 40, 34, 6);
fan(200, 200, 10, 120, 30, 18, 50, 61, -70, 'c3', 'c4', 0);      # dry lower leaves
{
  my @c = ([-120, 112], [-50, 106], [20, 116], [95, 108], [165, 112], [235, 102]);
  for (@c) { my ($a, $l) = @$_; cane(200, 200, $a, $l, 22, 22, 'c5', 'c3', 'c4', 'c3', 0); }
  for (@c) { my ($a, $l) = @$_; my ($dx, $dy) = dir($a); our $SPREAD = 230; fan(200 + $dx * $l, 200 + $dy * $l, 6, 60, 20, 17, 28, 62 + $a, $a); $SPREAD = 0; }
}
fan(200, 200, 6, 56, 14, 14, 30, 63, -20);
write_svg('6-harvest.svg', 'Sugar cane ready to harvest');

# 7. Harvested produce, front view: a bundle of three cut cane stalks, crossed a little like a sheaf and
#    tied round the middle with a twisted strip of cane leaf.
{
  my @st = ([174, 372, -100, 300], [234, 370, -80, 296], [204, 380, -91, 318]);   # left, right, then the front one
  for (@st) { my ($x, $y, $a, $l) = @$_; cane($x, $y, $a, $l, 46, 54, 'c5', 'c3', 'c4', 'c3', 0); my ($dx, $dy) = dir($a); cutend($x + $dx * $l, $y + $dy * $l, $a, 46, 0.4); }
  my @top = ([124, 244], [164, 238], [204, 236], [244, 238], [286, 244]);
  my @bot = map { [$_->[0], $_->[1] + 26] } reverse @top;
  poly('c1', @top, @bot);
  poly('c2', @top, map { [$_->[0], $_->[1] + 11] } reverse @top);
  poly('c4', [200, 236], [212, 236], [206, 262], [196, 262]);           # the twist where the strip crosses itself
  blade(276, 256, 62, 66, 16, 28, 'c2', 'c1', 'c3');                      # loose leaf ends from the knot
  blade(280, 252, 22, 52, 14, 34, 'c2', 'c1', 'c3');
}
write_svg('7-harvest-front.svg', 'Harvested sugar cane');

# 8. Dead (never watered), top down: cracked dry soil, dried straw leaves lying flat, a toppled dead cane
#    and a few withered stubs.
soil(200, 200, 60, 54, 8);
cracks(8, 83, 13, 'c3');
fan(200, 200, 11, 112, 34, 20, 84, 81, -80, 'c3', 'c4', 0);
cane(206, 210, 28, 128, 20, 26, 'c3', 0, 'c4', 'c4', 0);
for my $c ([-100, 30], [10, 26], [150, 28]) { cane(200, 200, $c->[0], $c->[1], 18, 14, 'c4', 'c3', 'c4', 'c3', 0); }
canetop(200, 200, 9);
write_svg('8-dead.svg', 'Sugar cane died from lack of water');
print "wrote 8 files to $OUT\n";

# Ground tiles for the top-down game, in the same polished flat style as the crops.
# Run from C:/Claude/Cute Fox:  perl tools/tiles/tiles.pl
# Every tile is 100x100 and seamless against every other tile of its family in any order:
# each family has one flat base colour that runs to the edges, and every detail (patches, tufts,
# stones, ripples) is placed only where it fits completely inside the tile, never across an edge.
# Soil is the exception: its furrows run edge to edge and repeat exactly every tile.
use strict; use warnings; use List::Util ();
my $OUT = 'tiles'; mkdir $OUT;
my $PI = 3.14159265;

# ---- HOUSE STYLE: every palette below is graded into the "modern strategy" look when the tile is written ----
my $STYLE = 'anno';
sub rgb2hsl { my ($r, $g, $bl) = map { $_ / 255 } @_; my ($mx, $mn) = (List::Util::max($r, $g, $bl), List::Util::min($r, $g, $bl)); my $b = $bl;
  my $l = ($mx + $mn) / 2; return (0, 0, $l) if $mx == $mn; my $d = $mx - $mn; my $s = $l > 0.5 ? $d / (2 - $mx - $mn) : $d / ($mx + $mn);
  my $h = $mx == $r ? ($g - $b) / $d + ($g < $b ? 6 : 0) : $mx == $g ? ($b - $r) / $d + 2 : ($r - $g) / $d + 4; ($h * 60, $s, $l) }
sub hsl2rgb { my ($h, $s, $l) = @_; $h = ($h % 360 + 360) % 360 + ($h - int($h)); return map { int($l * 255 + 0.5) } 1 .. 3 if $s <= 0;
  my $q = $l < 0.5 ? $l * (1 + $s) : $l + $s - $l * $s; my $p = 2 * $l - $q;
  my $f = sub { my $t = shift; $t += 1 if $t < 0; $t -= 1 if $t > 1; $t < 1 / 6 ? $p + ($q - $p) * 6 * $t : $t < 1 / 2 ? $q : $t < 2 / 3 ? $p + ($q - $p) * (2 / 3 - $t) * 6 : $p };
  map { my $v = int(255 * $f->($h / 360 + $_) + 0.5); $v < 0 ? 0 : $v > 255 ? 255 : $v } 1 / 3, 0, -1 / 3 }
my $cl = sub { my $v = shift; $v < 0 ? 0 : $v > 1 ? 1 : $v };
my %STYLES = (
  # modern strategy game: natural, slightly muted greens toward olive, deeper teal sea, pale sand, more contrast
  anno  => sub { my ($h, $s, $l) = @_;
    if ($h > 60 && $h < 170) { $h -= 10; $s *= 0.72; $l = 0.5 + ($l - 0.5) * 1.18 - 0.03 }
    elsif ($h >= 170 && $h < 260) { $h -= 12; $s *= 0.85; $l = 0.5 + ($l - 0.5) * 1.15 - 0.04 }
    else { $s *= 0.8; $l = 0.5 + ($l - 0.5) * 1.1 } ($h, $s, $l) },
);
sub restyle { my $c = shift; return $c unless $STYLE && $c =~ /^#([0-9A-Fa-f]{6})(.*)$/; my ($hex, $rest) = ($1, $2);
  my ($h, $s, $l) = $STYLES{$STYLE}->(rgb2hsl(map { hex } $hex =~ /(..)(..)(..)/)); sprintf('#%02X%02X%02X', hsl2rgb($h, $cl->($s), $cl->($l))) . $rest }

sub rnd { $_[0] = ($_[0] * 1103515245 + 12345) % 2147483648; $_[0] / 2147483648 }
sub dir { my $a = $_[0] * $PI / 180; (cos($a), sin($a)) }
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

my (@SH, @BUF); our $LAYER = 1;                      # tile shapes, a buffer for one detail, drawing layer
sub poly { my ($c, @p) = @_; push @BUF, [$c, \@p, $LAYER] }
sub fits { my $m = shift; for (@BUF) { for (@{$_->[1]}) { return 0 if $_->[0] < $m || $_->[0] > 100 - $m || $_->[1] < $m || $_->[1] > 100 - $m } } 1 }
sub keep { push @SH, @BUF; @BUF = () }
sub drop { @BUF = () }
# Try to place a detail: $draw->($x, $y) fills the buffer; keep it only if it lies fully inside.
sub place {
  my (undef, $draw, $m, $lo, $hi) = @_; $lo //= 2; $hi //= 98;
  for (1 .. 60) { my ($x, $y) = ($lo + rnd($_[0]) * ($hi - $lo), $lo + rnd($_[0]) * ($hi - $lo)); $draw->($x, $y); if (fits($m // 1)) { keep(); return ($x, $y) } drop() }
  return;
}
sub fmt { my $v = sprintf("%.1f", $_[0]); $v =~ s/.0$//; $v = "0" if $v eq "-0"; $v }
sub write_tile {
  my ($file, $label, %pal) = @_;
  keep(); my %used = map { $_->[0] => 1 } @SH;
  %pal = map { $_ => restyle($pal{$_}) } keys %pal;                   # grade every colour into the house style
  open my $fh, '>', "$OUT/$file" or die $!;
  print $fh qq{<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" role="img" aria-label="$label"><style>};
  print $fh ".$_\{fill:$pal{$_}}" for grep { $used{$_} } sort keys %pal;
  print $fh "</style>"; print $fh qq{<rect width="100" height="100" fill="$pal{base}"/>} if $pal{base} ne "none";   # overlays such as fences have no ground
  my (@order, %d);                                   # merge each class of each layer into one path
  for (sort { $a->[2] <=> $b->[2] } @SH) {
    my $k = "$_->[2] $_->[0]"; push @order, $k unless exists $d{$k};
    my $q = $k =~ /^0 / ? 1 : 10;                    # texture in whole units, details in tenths
    my @p = map { [map { int($_ * $q + ($_ < 0 ? -0.5 : 0.5)) } @$_] } @{$_->[1]};
    my $num = sub { my $v = $_[0] / $q; my $t = $q == 1 ? "$v" : sprintf('%.1f', $v); $t =~ s/\.0$//; $t =~ s/^(-?)0\./$1./; $t };
    my $pair = sub { my ($x, $y) = @_; my $sy = $num->($y); $num->($x) . ($sy =~ /^-/ ? '' : ' ') . $sy };
    $d{$k} .= 'M' . $pair->(@{$p[0]}) . 'l' . join('', map { my ($x, $y) = ($p[$_][0] - $p[$_ - 1][0], $p[$_][1] - $p[$_ - 1][1]); my $s = $pair->($x, $y); ($_ > 1 && $s !~ /^-/ ? ' ' : '') . $s } 1 .. $#p) . 'z';
  }
  for (@order) { my (undef, $c) = split ' '; print $fh qq{<path class="$c" d="$d{$_}"/>} }
  print $fh "</svg>\n"; close $fh; @SH = ();
}

# ---- shape helpers (same language as the crop generators) ----
sub blob {                                           # soft organic closed shape
  my ($x, $y, $rx, $ry, $s, $n) = @_; $n //= 22;
  my ($p1, $p2) = (rnd($s) * 6.28, rnd($s) * 6.28); my ($k1, $k2) = (0.1 + rnd($s) * 0.1, 0.05 + rnd($s) * 0.07);
  map { my $t = 6.2832 * $_ / $n; my $r = 1 + $k1 * sin(2 * $t + $p1) + $k2 * sin(3 * $t + $p2); [$x + cos($t) * $rx * $r, $y + sin($t) * $ry * $r] } 0 .. $n - 1;
}
sub blade {                                          # tapered curved blade, lit and shaded halves
  my ($x, $y, $ang, $len, $w, $bend, $light, $dark) = @_;
  my $n = 3; my (@mid, @l, @r); my ($px, $py, $a) = ($x, $y, $ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a); my $hw = $w / 2 * (1 - $t) ** 0.8;
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
    $px += $dx * $len / $n; $py += $dy * $len / $n; $a += $bend / $n;
  }
  my ($dx, $dy) = dir($ang); my $ll = lit(-$dy, $dx);
  poly($ll ? $light : $dark, @l, reverse @mid); poly($ll ? $dark : $light, @r, reverse @mid);
}
sub tuft {                                           # a small clump of blades, standing up-screen
  my ($x, $y, $sz, $s, $light, $dark) = @_;
  my $k = 3 + int(rnd($s) * 2);
  for my $i (0 .. $k - 1) {
    my $a = -90 + ($i - ($k - 1) / 2) * 24 + (rnd($s) - 0.5) * 12;
    blade($x + ($i - ($k - 1) / 2) * 1.2, $y, $a, $sz * (0.7 + rnd($s) * 0.4) * ($i == int($k / 2) ? 1.15 : 1), 2.4, ($a < -90 ? -22 : 22), $light, $dark);
  }
}
sub mound {                                          # soft patch: shaded rim lower right, lit body
  my ($x, $y, $rx, $ry, $s, $dark, $light) = @_;
  my $s2 = $s; poly($dark, blob($x + $rx * 0.04, $y + $ry * 0.07, $rx, $ry, $s2));
  $s2 = $s; poly($light, blob($x - $rx * 0.04, $y - $ry * 0.05, $rx * 0.94, $ry * 0.9, $s2));
}
sub pebble {                                         # smooth pebble: cast shadow, body, shaded half, lit cap
  my ($x, $y, $r, $s, $shadow, $body, $lightc, $shade) = @_;
  my @b = blob($x, $y, $r, $r * 0.74, $s, 14);
  poly($shadow, map { [$_->[0] + $r * 0.28, $_->[1] + $r * 0.34] } @b);
  poly($body, @b);
  poly($shade, @b[0 .. 7], [$x + $r * 0.05, $y + $r * 0.12]);
  poly($lightc, map { [$x - $r * 0.18 + ($_->[0] - $x) * 0.55, $y - $r * 0.2 + ($_->[1] - $y) * 0.5] } @b[8 .. 13], $b[0]);
}
sub flower {
  my ($x, $y, $r, $petal, $mid, $rot) = @_; $rot //= 0;
  for my $k (0 .. 4) { my ($dx, $dy) = dir($rot + $k * 72 - 90); my $s = $k * 7 + 1; poly($petal, blob($x + $dx * $r * 0.58, $y + $dy * $r * 0.58, $r * 0.46, $r * 0.46, $s, 8)); }
  my $s = 3; poly($mid, blob($x, $y, $r * 0.34, $r * 0.34, $s, 8));
}

# Scatter a texture over a GxG jittered grid. Cells in the outer ring come from one shared seed and
# are wrapped across the edges, so they are identical in every variant; inner cells differ per tile.
sub scatter {
  my ($tile, $fam, $G, $layer, $draw) = @_; my $C = 100 / $G; local $LAYER = $layer;
  for my $i (0 .. $G - 1) { for my $j (0 .. $G - 1) {
    my $edge = ($i == 0 || $j == 0 || $i == $G - 1 || $j == $G - 1);
    my $s = $edge ? $fam + $i * 101 + $j * 7 : $fam * 3 + 1000 + $tile * 7919 + $i * 101 + $j * 7; rnd($s) for 1 .. 2;
    $draw->($i * $C, $j * $C, $C, $s);
    my @one = @BUF; @BUF = ();
    for my $dx (-100, 0, 100) { for my $dy (-100, 0, 100) {
      my @m = map { [$_->[0], [map { [$_->[0] + $dx, $_->[1] + $dy] } @{$_->[1]}], $layer] } @one;
      next unless grep { grep { $_->[0] > -1 && $_->[0] < 101 && $_->[1] > -1 && $_->[1] < 101 } @{$_->[1]} } @m;
      push @SH, @m;
    } }
  } }
}

# ---- GRASS: 20 variants ----
# A dense field of small blade clumps on an 8x8 jittered grid. Clumps in the outer ring of cells come
# from one shared seed and are wrapped across the edges, so they are identical in every variant;
# the inner clumps differ per tile.
sub grassfield {
  my ($tile) = @_;
  scatter($tile, 31337, 8, 0, sub { my ($cx, $cy, $C, $s) = @_;
    for my $k (1 .. 1 + (rnd($s) < 0.3)) {
      my ($x, $y) = ($cx + (0.15 + rnd($s) * 0.7) * $C, $cy + (0.3 + rnd($s) * 0.65) * $C);
      my ($l, $d) = rnd($s) < 0.5 ? ('c', 'e') : ('b', 'a'); my $sz = 5.5 + rnd($s) * 3.5;
      for my $b (-1, 0, 1) {                         # three light blades: each a lit and a shaded quad
        my $a = -90 + $b * 26 + (rnd($s) - 0.5) * 14; my $len = $sz * ($b ? 0.75 + rnd($s) * 0.25 : 1);
        my ($ux, $uy) = dir($a); my ($bx, $by) = ($x + $b * 1.3, $y); my $w = 1.25; my $bend = $b * 1.6;
        my @tip = ($bx + $ux * $len + $bend, $by + $uy * $len);
        poly($l, [$bx - $uy * -$w, $by + $ux * -$w], [@tip], [$bx, $by]);
        poly($d, [$bx + $uy * -$w, $by - $ux * -$w], [@tip], [$bx, $by]);
      }
    }
  });
}
my %GP = (base => '#6EA547', a => '#5F9541', b => '#7AAF4F', c => '#89BF59', e => '#6A9F45', f => '#5A8F3C', g => '#97C963',
          s => '#A9A699', t => '#D3D0C2', u => '#858276', w => '#FAF6E8', y => '#F3C94B', o => '#E0823C', r => '#8B5B34', l => '#B7DD7E');
my @grass = (
  [], [], [], ['tuft'], ['tuft', 'tuft'], ['stone'], ['pebbles'], ['tuft', 'pebble'], ['clover', 'clover'], ['wflower', 'wflower', 'wflower'],
  ['yflower', 'yflower'], ['tuft', 'tuft', 'tuft'], [], ['bigstone'], ['clover', 'tuft'], ['wflower', 'yflower', 'tuft'], ['twig'], ['leaf'], ['tuft', 'pebbles'], ['patchy'],
);
for my $n (0 .. $#grass) {
  my $s = 5000 + $n * 977; rnd($s) for 1 .. 2;
  grassfield($n);
  for my $d (@{$grass[$n]}) {
    my $ss = $s + 701;
    if ($d eq 'tuft') { my $q = $ss; place($s, sub { tuft($_[0], $_[1], 10, $q, 'g', 'f') }, 2, 10, 90) }
    elsif ($d eq 'stone') { place($s, sub { pebble($_[0], $_[1], 5.5, $ss, 'f', 's', 't', 'u') }, 2, 12, 88) }
    elsif ($d eq 'bigstone') { place($s, sub { pebble($_[0], $_[1], 9, $ss, 'f', 's', 't', 'u') }, 2, 16, 84) }
    elsif ($d eq 'pebble') { place($s, sub { pebble($_[0], $_[1], 3.6, $ss, 'f', 's', 't', 'u') }, 2, 10, 90) }
    elsif ($d eq 'pebbles') { place($s, sub { pebble($_[0], $_[1], 3.4, $ss, 'f', 's', 't', 'u'); pebble($_[0] + 6, $_[1] + 3, 2.4, $ss + 5, 'f', 's', 't', 'u') }, 2, 10, 86) }
    elsif ($d eq 'clover') { place($s, sub { my ($x, $y) = @_; for my $k (0 .. 2) { my ($dx, $dy) = dir($k * 120 - 90); my $q = $ss + $k;
        my @l = blob($x + $dx * 3.2, $y + $dy * 3.2, 3.2, 3.2, $q, 10); poly('f', map { [$_->[0] + 0.6, $_->[1] + 0.8] } @l); poly('g', @l); poly('l', @l[5 .. 9], [$x + $dx * 3.2, $y + $dy * 3.2]); } }, 2, 10, 90) }
    elsif ($d eq 'wflower') { place($s, sub { flower($_[0] + 0.6, $_[1] + 0.8, 4, 'a', 'a'); flower($_[0], $_[1], 4, 'w', 'y', 20) }, 2, 8, 92) }
    elsif ($d eq 'yflower') { place($s, sub { flower($_[0] + 0.6, $_[1] + 0.8, 4, 'a', 'a'); flower($_[0], $_[1], 4, 'y', 'o', 40) }, 2, 8, 92) }
    elsif ($d eq 'twig') { place($s, sub { my ($x, $y) = @_;
        blade($x - 11, $y + 6, -22, 24, 2.8, 6, 'f', 'f'); blade($x - 11, $y + 5, -22, 24, 2.2, 6, 'r', 'r'); blade($x + 1, $y + 0.5, 30, 7, 1.6, 0, 'r', 'r') }, 2, 16, 84) }
    elsif ($d eq 'leaf') { place($s, sub { my ($x, $y) = @_; my $q = $ss;
        poly('a', map { [$_->[0] + 1, $_->[1] + 1.2] } blob($x, $y, 6.5, 3.4, $q, 14));
        my @L = blob($x, $y, 6.5, 3.6, $q, 14); poly('o', @L); poly('y', @L[7 .. 13]); poly('r', [$x - 9, $y + 0.6], [$x + 5.5, $y - 0.4], [$x + 5.5, $y + 0.2], [$x - 9, $y + 1.4]) }, 2, 12, 88) }
  }
  write_tile(sprintf('grass-%02d.svg', $n + 1), 'Grass tile ' . ($n + 1), %GP);
}

# ---- PREPARED SOIL: three soft furrows per tile, repeating exactly at the edges ----
my %SP = (base => '#6E4930', a => '#563720', b => '#835A3B', c => '#9A7049', d => '#47301C');
{ my $s = 4242; rnd($s);
  my $wave = sub { my ($x, $y0, $amp, $ph) = @_; $y0 + $amp * sin(6.2832 * $x / 100 * 2 + $ph) + $amp * 0.5 * sin(6.2832 * $x / 100 * 3 + $ph * 1.7) };
  for my $r (0 .. 2) {
    my $y0 = $r * 100 / 3; my $ph = $r * 1.9; my @xs = map { $_ * 5 } 0 .. 20;
    my @top   = map { [$_, $wave->($_, $y0 + 1.5, 0.7, $ph)] } @xs;
    my @crest = map { [$_, $wave->($_, $y0 + 9, 0.9, $ph + 0.6)] } @xs;
    my @mid   = map { [$_, $wave->($_, $y0 + 17, 0.9, $ph + 1.1)] } @xs;
    my @foot  = map { [$_, $wave->($_, $y0 + 25.5, 0.8, $ph + 1.5)] } @xs;
    my @bot   = map { [$_, $wave->($_, $y0 + 100 / 3 + 1.5, 0.7, $ph + 1.9)] } @xs;
    poly('b', @top, reverse @mid);                   # lit upper slope of the ridge
    poly('c', @top, reverse @crest);                 # brightest band along the crest
    poly('a', @foot, reverse @bot);                  # shaded furrow floor
    poly('d', @foot, map { [$_->[0], $_->[1] + 2.4] } reverse @foot);   # deepest line at the foot
  }
  my @c = grep { grep { $_->[1] > 100 } @{$_->[1]} } @BUF;          # the last furrow floor crosses y=100:
  push @BUF, map { my $p = $_; [$p->[0], [map { [$_->[0], $_->[1] - 100] } @{$p->[1]}], $p->[2]] } @c;   # repeat it at the top
  keep();
  for (1 .. 9) { my $r = 1.8 + rnd($s) * 2; my $ss = $s + $_ * 19; place($s, sub { my ($x, $y) = @_; my $q = $ss;
      my @b = blob($x, $y, $r, $r * 0.7, $q, 10); poly('a', map { [$_->[0] + 0.7, $_->[1] + 0.9] } @b); poly('b', @b); poly('c', @b[5 .. 9], [$x, $y]) }, 2) }
}
write_tile('soil.svg', 'Prepared soil tile', %SP);

sub ripple {                                         # a soft curved highlight: thin lens along an arc
  my ($x, $y, $len, $th, $bend, $cls) = @_; my (@u, @d);
  for my $i (0 .. 8) { my $t = $i / 8 - 0.5; my $px = $x + $t * $len; my $py = $y - $bend * (1 - 4 * $t * $t); my $w = $th * (1 - 4 * $t * $t);
    push @u, [$px, $py - $w / 2]; push @d, [$px, $py + $w / 2]; }
  poly($cls, @u, reverse @d);
}

# ---- shared helpers for path and water ----
sub ngon { my ($x, $y, $r, $n, $rot, $s, $jit, $sq) = @_; $sq //= 1;
  map { my ($u, $v) = dir($rot + $_ * 360 / $n + (rnd($s) - 0.5) * $jit); my $k = 0.82 + rnd($s) * 0.3; [$x + $u * $r * $k, $y + $v * $r * $k * $sq] } 0 .. $n - 1 }
sub litpart { my ($x, $y, $r, @p) = @_; my @l = grep { ($_->[0] - $x) + ($_->[1] - $y) < 0.2 * $r } @p; @l >= 2 ? (@l, [$x + $r * 0.12, $y + $r * 0.12]) : () }

# ---- SAND: beach, 4 variants (fine grains and ripples; a shell or pebble on some) ----
my %SA = (base => '#E9D4A0', a => '#D9BF86', b => '#F2E2B6', c => '#FAF0D3', d => '#CDAE74', s => '#B9AFA2', t => '#E4DDD2', u => '#968C80', p => '#F3C9C0', q => '#E2A79C');
for my $sv (1 .. 4) {
  scatter($sv, 1717, 9, 0.5, sub { my ($cx, $cy, $C, $s) = @_;
    if (rnd($s) < 0.45) {                                   # a soft wind ripple: shaded crescent with a lit lip
      my ($x, $y) = ($cx + (0.2 + rnd($s) * 0.6) * $C, $cy + (0.3 + rnd($s) * 0.5) * $C); my $l = 3 + rnd($s) * 3;
      poly('a', [$x - $l, $y], [$x, $y + 1.1], [$x + $l, $y], [$x, $y + 0.3]);
      poly('b', [$x - $l * 0.8, $y - 0.2], [$x, $y - 0.9], [$x + $l * 0.8, $y - 0.2], [$x, $y - 0.1]);
    }
    for (1 .. 1 + (rnd($s) < 0.5)) {                        # grains
      my ($x, $y) = ($cx + rnd($s) * $C, $cy + rnd($s) * $C); my $r = 0.5 + rnd($s) * 0.7;
      poly(rnd($s) < 0.5 ? 'd' : 'c', [$x - $r, $y], [$x, $y - $r * 0.8], [$x + $r, $y], [$x, $y + $r * 0.8]);
    }
  });
  my $s = 1900 + $sv * 31; rnd($s);
  if ($sv == 2) { place($s, sub { my ($x, $y) = @_;            # a scallop shell
      poly('a', map { [$_->[0] + 0.7, $_->[1] + 0.8] } ngon($x, $y, 3.4, 9, 0, 5, 0, 0.9));
      my @fan = map { my ($u, $v) = dir(200 + $_ * 17.5); [$x + $u * 3.4, $y + $v * 3.4] } 0 .. 8;
      poly('p', [$x, $y + 1.6], @fan); poly('q', [$x, $y + 1.6], @fan[5 .. 8]);
      for my $k (1, 3, 5, 7) { poly('q', [$x, $y + 1.6], $fan[$k], [($fan[$k][0] + $fan[$k + 1][0]) / 2, ($fan[$k][1] + $fan[$k + 1][1]) / 2]) } }, 2, 12, 88) }
  if ($sv == 4) { for my $r (2.6, 1.8) { place($s, sub { pebble($_[0], $_[1], $r, $s + $r * 10, 'a', 's', 't', 'u') }, 2, 10, 90) } }
  write_tile("sand-0$sv.svg", "Sand tile $sv", %SA);
}

# ---- PATH: cobblestones, 4 variants ----

my %PD = (base => '#8A7A66', a => '#6F6252', b => '#B7AC9B', c => '#D2C9BA', d => '#A39885', e => '#C4A97F');
for my $pv (1 .. 4) {
  scatter($pv, 6161, 4, 0.5, sub { my ($cx, $cy, $C, $s) = @_;
    my ($x, $y) = ($cx + (0.42 + rnd($s) * 0.16) * $C, $cy + (0.42 + rnd($s) * 0.16) * $C); my $r = $C * 0.47;
    my @p = ngon($x, $y, $r, 8, rnd($s) * 45, $s, 14, 0.92);
    poly('a', map { [$_->[0] + 1, $_->[1] + 1.2] } @p); poly(rnd($s) < 0.25 ? 'd' : 'b', @p);
    my @l = litpart($x, $y, $r, @p); poly('c', @l) if @l; });
  write_tile("path-0$pv.svg", "Cobblestone path tile $pv", %PD);
}

my %WO = (base => '#4A9AD2', a => '#3F8CC6', b => '#5BA9DC', x => '#93D0F0', w => '#EAF8FE', g => '#4F9A45', h => '#77BF5E', f => '#3D7F38', p => '#F4B9C8', y => '#F3C94B');
sub lily { my ($x, $y, $r, $s, $flower) = @_; my @p = blob($x, $y, $r, $r * 0.88, $s, 20);
  poly('a', map { [$_->[0] + 1.4, $_->[1] + 1.7] } @p); poly('g', @p[0 .. 17], [$x, $y]); poly('h', @p[9 .. 17], [$x, $y]);
  flower($x - $r * 0.2, $y - $r * 0.15, $r * 0.42, 'p', 'y', 18) if $flower; }
# ---- WATER: ripple dashes, 6 variants (short curved light strokes evenly scattered) ----
for my $wv (1 .. 6) {
  scatter($wv, 7171, 6, 0.5, sub { my ($cx, $cy, $C, $s) = @_;
    for (1 .. 1 + (rnd($s) < 0.35)) { my ($x, $y) = ($cx + (0.2 + rnd($s) * 0.6) * $C, $cy + (0.2 + rnd($s) * 0.6) * $C); my $len = 5 + rnd($s) * 6;
      if (rnd($s) < 0.25) { ripple($x, $y + 1, $len * 1.1, 1.4, 1.2, 'a') } else { ripple($x, $y, $len, 1.5, 1.3, 'x'); ripple($x - $len * 0.12, $y - 0.4, $len * 0.45, 0.7, 0.8, 'w') if rnd($s) < 0.5 } } });
  my $s = 300 + $wv; rnd($s);
  if ($wv == 6) { place($s, sub { lily($_[0], $_[1], 9, 5, 0) }, 2, 14, 86); place($s, sub { lily($_[0], $_[1], 6.5, 9, 1) }, 2, 10, 90) }
  write_tile("water-0$wv.svg", "Water tile $wv", %WO);
}
# ---- FENCES: transparent overlays for grass tiles, in a slight 3/4 view like the crops ----
# Every fence tile has a post in the middle and an arm towards each neighbouring fence tile.
# fence-NESW.svg: each letter is 1 when that side connects (fence-0000 is a lone post), so the
# 16 files cover every shape of enclosure. The arms meet exactly at the tile edges.
my %FP = (base => 'none', h => '#152E0E;fill-opacity:.26', t => '#D7AB72', l => '#B07A45', f => '#93622F', d => '#6E4524', k => '#55341B');
sub rail_h {                                         # two horizontal rails from x0 to x1: top faces, front faces, shadow
  my ($x0, $x1) = @_;
  poly('h', [$x0, 62], [$x1, 62], [$x1, 69], [$x0, 69]);
  for my $y (43, 53) {
    poly('t', [$x0, $y], [$x1, $y], [$x1, $y + 2.2], [$x0, $y + 2.2]);
    poly('f', [$x0, $y + 2.2], [$x1, $y + 2.2], [$x1, $y + 7], [$x0, $y + 7]);
    poly('d', [$x0, $y + 5.8], [$x1, $y + 5.8], [$x1, $y + 7], [$x0, $y + 7]);
  }
}
sub rail_v {                                         # rails running up/down the screen, seen mostly from above
  my ($y0, $y1) = @_;
  poly('h', [54.5, $y0], [62, $y0], [62, $y1], [54.5, $y1]);
  poly('t', [45, $y0], [52, $y0], [52, $y1], [45, $y1]);
  poly('f', [52, $y0], [55, $y0], [55, $y1], [52, $y1]);
  poly('l', [45, $y0], [46.6, $y0], [46.6, $y1], [45, $y1]);
}
sub post {
  poly('h', [53, 62], [64, 62], [66, 70], [55, 70]);                 # shadow
  poly('f', [42.5, 40], [57.5, 40], [57.5, 65], [42.5, 65]);         # front
  poly('l', [42.5, 40], [46, 40], [46, 65], [42.5, 65]);             # lit left edge
  poly('d', [54, 40], [57.5, 40], [57.5, 65], [54, 65]);             # shaded right edge
  poly('k', [42.5, 63], [57.5, 63], [57.5, 65], [42.5, 65]);         # dark foot where it meets the ground
  poly('t', [42.5, 40], [45.5, 34.5], [54.5, 34.5], [57.5, 40]);     # bevelled top
  poly('l', [45.5, 34.5], [54.5, 34.5], [53, 36.8], [47, 36.8]);
  poly('k', [42.5, 49.5], [57.5, 49.5], [57.5, 50.6], [42.5, 50.6]); # a little groove
}
for my $m (0 .. 15) {
  my ($n, $e, $s, $w) = map { ($m >> (3 - $_)) & 1 } 0 .. 3;
  { local $LAYER = 1; rail_v(0, 38) if $n; }       # layers keep the drawing order: back rail, side rails, front rail, post
  { local $LAYER = 2; rail_h(0, 43) if $w; rail_h(57, 100) if $e; }
  { local $LAYER = 3; rail_v(50, 100) if $s; }
  { local $LAYER = 4; post(); }
  write_tile("fence-$n$e$s$w.svg", "Fence tile, connected" . join('', map { $_->[0] ? " $_->[1]" : '' } [$n, 'north'], [$e, 'east'], [$s, 'south'], [$w, 'west']), %FP);
}
# ---- SEA: open ocean, 6 variants (deeper blue, rolling wave crests instead of calm ripples) ----
my %SE = (base => '#235C8F', a => '#1C4E7B', b => '#2A69A0', x => '#5C9BCB', w => '#C6E2F2');
for my $sv (1 .. 6) {
  scatter($sv, 7373, 5, 0.5, sub { my ($cx, $cy, $C, $s) = @_;
    for (1 .. 1 + (rnd($s) < 0.6)) {
      my ($x, $y) = ($cx + (0.2 + rnd($s) * 0.6) * $C, $cy + (0.25 + rnd($s) * 0.55) * $C); my $len = 7 + rnd($s) * 8;
      ripple($x + 0.6, $y + 1.6, $len * 1.05, 2.2, 1.8, 'a');                 # trough in front of the crest
      ripple($x, $y, $len, 1.7, 1.8, 'x');                                   # the crest
      ripple($x - $len * 0.15, $y - 0.5, $len * 0.4, 0.8, 1.1, 'w') if rnd($s) < 0.45;   # foam on top
    }
    if (rnd($s) < 0.3) { my ($x, $y) = ($cx + rnd($s) * $C, $cy + rnd($s) * $C); my $l = 4 + rnd($s) * 4; ripple($x, $y, $l, 1.2, 0.6, 'b') }   # a lighter swell
  });
  write_tile("sea-0$sv.svg", "Sea tile $sv", %SE);
}

# ---- ROCK: mountain ground, 4 variants (scree of angular stones on grey rock) ----
my %RK = (base => '#958E84', a => '#7F786F', b => '#A9A298', c => '#C2BBB0', d => '#6A645C', g => '#6E9A47');
for my $rv (1 .. 4) {
  scatter($rv, 2929, 6, 0.5, sub { my ($cx, $cy, $C, $s) = @_;
    for (1 .. 1 + (rnd($s) < 0.55)) {
      my ($x, $y) = ($cx + (0.15 + rnd($s) * 0.7) * $C, $cy + (0.15 + rnd($s) * 0.7) * $C); my $r = 1.6 + rnd($s) ** 1.5 * 4.2;
      my @p = ngon($x, $y, $r, 5 + int(rnd($s) * 3), rnd($s) * 60, $s, 34, 0.8);
      poly('d', map { [$_->[0] + $r * 0.25, $_->[1] + $r * 0.3] } @p); poly(rnd($s) < 0.3 ? 'a' : 'b', @p);
      my @l = litpart($x, $y, $r, @p); poly('c', @l) if @l;
    }
    if (rnd($s) < 0.15) { my ($x, $y) = ($cx + rnd($s) * $C, $cy + rnd($s) * $C);    # a hardy tuft between the stones
      for my $k (-1, 0, 1) { my ($u, $v) = dir(-90 + $k * 28); poly('g', [$x - 0.7, $y], [$x + $u * 4, $y + $v * 4], [$x + 0.7, $y]); } }
  });
  write_tile("rock-0$rv.svg", "Mountain rock tile $rv", %RK);
}

# ---- PEAKS: transparent mountain overlays drawn standing on rock tiles (taller than a tile) ----
my %PK = (base => 'none', h => '#1E2A16;fill-opacity:.25', l => '#B4ADA2', m => '#9C958A', d => '#776F66', k => '#5E5850', w => '#F4F7FA', v => '#C6D0DC');
sub jag { my ($p, $q, $n, $amp, $s) = @_; my @o;            # points from p to q with a ragged, rocky edge
  for my $i (1 .. $n - 1) { my $t = $i / $n; my ($dx, $dy) = ($q->[0] - $p->[0], $q->[1] - $p->[1]); my $l = sqrt($dx * $dx + $dy * $dy) || 1;
    my $o = (rnd($s) - 0.35) * $amp; push @o, [$p->[0] + $dx * $t - $dy / $l * $o, $p->[1] + $dy * $t + $dx / $l * $o]; } @o }
for my $pv (1 .. 6) {
  my $s = 3100 + $pv * 71; rnd($s);
  my $snow = $pv <= 3; my $A = [42 + rnd($s) * 16, $snow ? 6 + rnd($s) * 8 : 24 + rnd($s) * 14];
  my ($BL, $BR, $F) = ([2 + rnd($s) * 6, 96], [94 + rnd($s) * 4, 96], [$A->[0] + 6 + rnd($s) * 8, 96]);
  my @left = jag($BL, $A, 5, 7, $s); my @right = jag($A, $BR, 5, 7, $s); my @ridge = jag($A, $F, 4, 5, $s);
  poly('h', [$F->[0] - 6, 95], [$BR->[0] + 6, 95], [$BR->[0] + 10, 100], [$F->[0] + 2, 100]);
  poly('l', $BL, @left, $A, @ridge, $F);                                                # sunlit west face
  poly('d', $A, @right, $BR, $F, reverse @ridge);                                       # shaded east face
  for my $g (0 .. 1) {                                                                  # gullies running down each face
    my $i = 1 + $g * 2; my $top = $left[$i]; poly('m', $top, [$top->[0] + 3, $top->[1] + 2], [$top->[0] + 2 + rnd($s) * 6, 96], [$top->[0] - 4 + rnd($s) * 4, 96]);
    my $r = $right[$i]; poly('k', $r, [$r->[0] - 3, $r->[1] + 3], [$r->[0] - 6 + rnd($s) * 4, 96], [$r->[0] + 2, 96]);
  }
  if ($snow) {                                                                          # snow cap with a ragged lower edge
    my $f = 0.32 + rnd($s) * 0.12; my $ip = sub { my ($p) = @_; [$A->[0] + ($p->[0] - $A->[0]) * $f, $A->[1] + ($p->[1] - $A->[1]) * $f] };
    my ($L, $M, $R) = ($ip->($BL), $ip->($F), $ip->($BR));
    poly('w', $A, (grep { $_->[1] < $L->[1] } @left), jag($L, $M, 4, 6, $s), $M, reverse(grep { $_->[1] < $M->[1] } @ridge));
    poly('v', $A, @ridge[0 .. 0], $M, jag($M, $R, 4, 6, $s), $R, reverse(grep { $_->[1] < $R->[1] } @right));
  }
  write_tile("peak-0$pv.svg", 'Mountain peak overlay', %PK);
}

# ---- TREES: transparent overlays for forests (drawn a bit taller than a tile); 1-3 broadleaf, 4-6 conifer ----
my %TR = (base => 'none', h => '#1E3214;fill-opacity:.3', t => '#7A5132', u => '#55361F',
          a => '#2C6630', b => '#3C8538', c => '#58A548', e => '#86C55E', p => '#245A3A', q => '#327349', r => '#4C9358', s => '#6FB070');
for my $tv (1 .. 6) {
  my $s = 5100 + $tv * 53; rnd($s);
  if ($tv <= 3) {                                                       # broadleaf: a round, lumpy crown of faceted clumps
    poly('h', map { [$_->[0] + 9, $_->[1] + 6] } ngon(50, 80, 30, 10, 0, $s, 10, 0.45));
    poly('t', [45, 70], [55, 70], [57, 92], [43, 92]); poly('u', [51, 70], [55, 70], [57, 92], [52, 92]);
    my @cl = ([50, 46, 30], map { my ($u, $v) = dir(-150 + $_ * 75 + rnd($s) * 25); [50 + $u * 18, 50 + $v * 14, 15 + rnd($s) * 6] } 0 .. 4);
    for my $cc (sort { $a->[1] <=> $b->[1] } @cl) { my ($x, $y, $r) = @$cc;
      my @p = ngon($x, $y, $r, 9, rnd($s) * 40, $s, 14, 0.92);
      poly('a', map { [$_->[0] + $r * 0.12, $_->[1] + $r * 0.14] } @p); poly('b', @p);
      my @l = litpart($x, $y, $r, @p); poly('c', @l) if @l;
      poly('e', map { [$x - $r * 0.3 + ($_->[0] - $x) * 0.3, $y - $r * 0.32 + ($_->[1] - $y) * 0.3] } @p) if rnd($s) < 0.7; }
  } else {                                                              # conifer: stacked tiers, lit west, shaded east
    poly('h', map { [$_->[0] + 9, $_->[1] + 4] } ngon(50, 86, 20, 9, 0, $s, 8, 0.45));
    poly('t', [46, 78], [54, 78], [55, 94], [45, 94]); poly('u', [51, 78], [54, 78], [55, 94], [52, 94]);
    my $top = 6 + rnd($s) * 6;
    for my $k (0 .. 3) { my ($y0, $w) = ($top + $k * 17, 15 + $k * 7); my $yb = $y0 + 30;
      my $mid = 50 + (rnd($s) - 0.5) * 3;
      poly('q', [$mid, $y0], [50 - $w, $yb], [50 - $w * 0.3, $yb - 3], [$mid, $yb + 1]);
      poly('p', [$mid, $y0], [$mid, $yb + 1], [50 + $w * 0.4, $yb - 2], [50 + $w, $yb]);
      poly('r', [$mid, $y0], [50 - $w * 0.75, $yb - 6], [50 - $w * 0.35, $yb - 7]);
      poly('s', [$mid, $y0], [$mid - 2, $y0 + 8], [$mid - 6, $y0 + 14]) if $k == 0; }
  }
  write_tile("tree-0$tv.svg", $tv <= 3 ? 'Broadleaf tree overlay' : 'Conifer tree overlay', %TR);
}

# ---- DECOR: small transparent details scattered over the ground (drawn into the cached ground) ----
my %DC = (base => 'none', h => '#1E3214;fill-opacity:.28', a => '#3E7F35', b => '#58A045', c => '#7CC05A', s => '#9C978C', t => '#CFCAC0', u => '#706B62',
          w => '#8A6038', v => '#B48A5C', k => '#5C3E22', y => '#F3C94B', p => '#F2A0C0', q => '#FFFFFF', r => '#B8A27A', o => '#D9783A', l => '#5FA65A', m => '#83C46E');
my %DECOR = (
  'bush-1' => sub { my $s = shift; poly('h', ngon(56, 66, 22, 9, 0, $s, 10, 0.45));
    for my $c ([40, 56, 14], [60, 52, 16], [50, 44, 15]) { my @p = ngon(@$c, 9, rnd($s) * 40, $s, 16, 0.9); poly('a', map { [$_->[0] + 2, $_->[1] + 2] } @p); poly('b', @p); my @l = litpart(@$c[0, 1], $c->[2], @p); poly('c', @l) if @l; } },
  'bush-2' => sub { my $s = shift; poly('h', ngon(56, 64, 18, 9, 0, $s, 10, 0.45));
    for my $c ([44, 54, 12], [58, 52, 13]) { my @p = ngon(@$c, 8, rnd($s) * 40, $s, 16, 0.9); poly('a', map { [$_->[0] + 2, $_->[1] + 2] } @p); poly('b', @p); my @l = litpart(@$c[0, 1], $c->[2], @p); poly('c', @l) if @l; }
    for my $f ([42, 48], [55, 46], [62, 55], [48, 58]) { flower(@$f, 3.2, 'p', 'y', rnd($s) * 60) } },
  'flowers-1' => sub { my $s = shift; for (1 .. 5) { my ($x, $y) = (36 + rnd($s) * 28, 44 + rnd($s) * 20); blade($x, $y + 6, -90 + (rnd($s) - 0.5) * 30, 8, 2, 0, 'l', 'a'); flower($x, $y, 4, 'y', 'o', rnd($s) * 60) } },
  'flowers-2' => sub { my $s = shift; for (1 .. 6) { my ($x, $y) = (34 + rnd($s) * 32, 44 + rnd($s) * 20); blade($x, $y + 6, -90 + (rnd($s) - 0.5) * 30, 8, 2, 0, 'l', 'a'); flower($x, $y, 3.6, rnd($s) < 0.5 ? 'q' : 'p', 'y', rnd($s) * 60) } },
  'stone-1' => sub { my $s = shift; pebble(50, 56, 13, $s, 'h', 's', 't', 'u') },
  'stone-2' => sub { my $s = shift; pebble(44, 58, 10, $s, 'h', 's', 't', 'u'); pebble(60, 52, 7, $s + 9, 'h', 's', 't', 'u') },
  'stump' => sub { my $s = shift; poly('h', ngon(56, 64, 15, 9, 0, $s, 8, 0.5));
    poly('k', [38, 50], [62, 50], [64, 64], [36, 64]); poly('w', [38, 50], [50, 50], [50, 64], [36, 64]);
    poly('v', ngon(50, 49, 12, 10, 0, $s, 6, 0.42)); poly('w', ngon(50, 49, 6, 8, 0, $s, 6, 0.42)); poly('l', [34, 62], [40, 56], [42, 63]) },
  'driftwood' => sub { my $s = shift; poly('h', [24, 62], [76, 56], [78, 62], [26, 68]);
    poly('r', [22, 56], [74, 48], [78, 53], [26, 62]); poly('t', [22, 56], [74, 48], [75, 50], [23, 58]); poly('r', [52, 52], [62, 40], [65, 42], [56, 53]) },
  'reeds-1' => sub { my $s = shift; for my $k (0 .. 6) { my $x = 38 + $k * 4 + (rnd($s) - 0.5) * 3; blade($x, 70, -90 + (rnd($s) - 0.5) * 22, 26 + rnd($s) * 14, 3, (rnd($s) - 0.5) * 20, 'l', 'a') }
    for my $k (1, 3, 5) { my $x = 38 + $k * 4; poly('k', [$x - 1.6, 40 - $k], [$x + 1.6, 40 - $k], [$x + 1.4, 50 - $k], [$x - 1.4, 50 - $k]) } },
  'reeds-2' => sub { my $s = shift; for my $k (0 .. 4) { my $x = 42 + $k * 4 + (rnd($s) - 0.5) * 3; blade($x, 70, -90 + (rnd($s) - 0.5) * 30, 20 + rnd($s) * 12, 3, (rnd($s) - 0.5) * 30, 'm', 'l') } },
  'lily' => sub { my $s = shift; for my $L ([44, 54, 12], [64, 62, 8]) { my ($x, $y, $r) = @$L; my @p = blob($x, $y, $r, $r * 0.85, $s + $x, 18);
      poly('a', @p[0 .. 15], [$x, $y]); poly('m', @p[8 .. 15], [$x, $y]); } flower(46, 52, 4.5, 'p', 'y', 18) },
);
for my $name (sort keys %DECOR) { my $s = 6100 + length($name) * 37 + ord(substr($name, -1)); rnd($s); $DECOR{$name}->($s); write_tile("decor-$name.svg", "Decoration $name", %DC); }

# ---- MEADOWS and OUTCROPS: more transparent details, also baked into the ground ----
my %MD = (base => 'none', h => '#1E3214;fill-opacity:.25', a => '#3E7F35', b => '#58A045', c => '#7CC05A', l => '#4F8F3F', m => '#9AD06E',
          y => '#F3C94B', o => '#E0823C', q => '#FAF6E8', p => '#C58AE0', r => '#E88AAE', d => '#A3814F', e => '#C4A066', g => '#B9B36A',
          s => '#9C978C', t => '#CFCAC0', u => '#706B62', v => '#6E9A47');
my %MEAD = (
  'meadow-yellow' => sub { my $s = shift; for (1 .. 9) { my ($x, $y) = (12 + rnd($s) * 76, 12 + rnd($s) * 76); flower($x, $y, 2.6 + rnd($s), rnd($s) < 0.75 ? 'y' : 'q', 'o', rnd($s) * 70) } },
  'meadow-white'  => sub { my $s = shift; for (1 .. 10) { my ($x, $y) = (12 + rnd($s) * 76, 12 + rnd($s) * 76); flower($x, $y, 2.4 + rnd($s), 'q', 'y', rnd($s) * 70) } },
  'meadow-purple' => sub { my $s = shift; for (1 .. 9) { my ($x, $y) = (12 + rnd($s) * 76, 12 + rnd($s) * 76); flower($x, $y, 2.4 + rnd($s), rnd($s) < 0.6 ? 'p' : 'r', 'y', rnd($s) * 70) } },
  'meadow-tall'   => sub { my $s = shift; for (1 .. 7) { my ($x, $y) = (14 + rnd($s) * 72, 20 + rnd($s) * 66);
      for my $k (-2 .. 2) { blade($x + $k * 1.4, $y, -90 + $k * 14 + (rnd($s) - 0.5) * 12, 11 + rnd($s) * 6, 2.2, $k * 7, 'c', 'l') } } },
  'meadow-clover' => sub { my $s = shift; for (1 .. 6) { my ($x, $y) = (14 + rnd($s) * 72, 14 + rnd($s) * 72);
      for my $k (0 .. 2) { my ($dx, $dy) = dir($k * 120 - 90 + rnd($s) * 20); my @l = blob($x + $dx * 2.6, $y + $dy * 2.6, 2.7, 2.7, $s + $k, 9); poly('b', @l); poly('m', @l[4 .. 8], [$x + $dx * 2.6, $y + $dy * 2.6]); }
      flower($x + 3, $y - 4, 1.8, 'q', 'r', 0) if rnd($s) < 0.4 } },
);
for my $name (sort keys %MEAD) { my $s = 7300 + length($name) * 41 + ord(substr($name, -1)); rnd($s); $MEAD{$name}->($s); write_tile("decor-$name.svg", "Decoration $name", %MD); }

# ---- BRIDGES: wooden plank bridges laid over water tiles where a path crosses ----
# bridge-h-WE.svg runs east-west, bridge-v-NS.svg north-south; a digit is 1 when the bridge
# continues on that side, 0 where it meets the bank (that end gets its posts).
my %BP = (base => 'none', h => '#0E2A44;fill-opacity:.35', t => '#C99863', p => '#B5834F', l => '#DDB27A', f => '#8E5E31', d => '#6A4322', k => '#4E311A');
sub planks_h {                                       # deck running east-west: boards across it, front edge, shadow on the water
  poly('h', [0, 82], [100, 82], [100, 92], [0, 92]);
  poly('d', [0, 78], [100, 78], [100, 84], [0, 84]);
  for my $i (0 .. 7) { my $x = $i * 12.5; poly($i % 2 ? 'p' : 't', [$x, 14], [$x + 12.5, 14], [$x + 12.5, 78], [$x, 78]); poly('k', [$x + 11.7, 14], [$x + 12.5, 14], [$x + 12.5, 78], [$x + 11.7, 78]); }
}
sub planks_v {                                       # deck running north-south: boards across it, side edge, shadow
  poly('h', [82, 0], [92, 0], [92, 100], [82, 100]);
  poly('d', [78, 0], [84, 0], [84, 100], [78, 100]);
  for my $i (0 .. 7) { my $y = $i * 12.5; poly($i % 2 ? 'p' : 't', [14, $y], [78, $y], [78, $y + 12.5], [14, $y + 12.5]); poly('k', [14, $y + 11.7], [78, $y + 11.7], [78, $y + 12.5], [14, $y + 12.5]); }
}
sub bpost { my ($x, $y) = @_; poly('h', [$x + 3, $y + 8], [$x + 10, $y + 8], [$x + 11, $y + 13], [$x + 4, $y + 13]);
  poly('f', [$x, $y], [$x + 7, $y], [$x + 7, $y + 10], [$x, $y + 10]); poly('l', [$x, $y - 3], [$x + 7, $y - 3], [$x + 7, $y], [$x, $y]); poly('k', [$x + 5.5, $y], [$x + 7, $y], [$x + 7, $y + 10], [$x + 5.5, $y + 10]); }
for my $m (0 .. 3) {
  my ($a, $b) = (($m >> 1) & 1, $m & 1);
  { local $LAYER = 1; planks_h(); }
  { local $LAYER = 2;                                # railings along both sides, posts at the banks and mid-span
    for my $ry (10, 74) { poly('l', [0, $ry], [100, $ry], [100, $ry + 2], [0, $ry + 2]); poly('f', [0, $ry + 2], [100, $ry + 2], [100, $ry + 5], [0, $ry + 5]); }
    for my $ry (6, 70) { bpost(46.5, $ry); bpost(2, $ry) unless $a; bpost(91, $ry) unless $b; } }
  write_tile("bridge-h-$a$b.svg", 'Bridge running east-west', %BP);
  { local $LAYER = 1; planks_v(); }
  { local $LAYER = 2;
    for my $rx (10, 74) { poly('l', [$rx, 0], [$rx + 2, 0], [$rx + 2, 100], [$rx, 100]); poly('f', [$rx + 2, 0], [$rx + 5, 0], [$rx + 5, 100], [$rx + 2, 100]); }
    for my $rx (8, 72) { bpost($rx, 46); bpost($rx, 4) unless $a; bpost($rx, 88) unless $b; } }
  write_tile("bridge-v-$a$b.svg", 'Bridge running north-south', %BP);
}
print "tiles written\n";

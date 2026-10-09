# Kiwano (horned melon) crop art: 8 stages. Run from C:/Claude/Cute Fox:  perl tools/crops/kiwano.pl
# Top-down stages (2-6, 8) share one fixed scale centred on (200,200) so growth reads in-game.
# The signature: an oval bright orange fruit, mottled yellow, studded all over with stout pointed horns,
# full of lime-green jelly with pale seeds. The plant is a sprawling vine with deep three-lobed toothed
# leaves, curly tendrils and small yellow star flowers.
use strict; use warnings; use Math::Trig;

my $OUT = 'crops/kiwano';
mkdir 'crops'; mkdir $OUT;
# c1 leaf green, c2 lime green (lit leaves, jelly), c3 pale yellow (mottling, horn lights, flowers, seeds,
# dried leaves), c4 dark soil brown (soil, shade), c5 kiwano orange
my %PAL = (c1 => '#3A7533', c2 => '#8DC548', c3 => '#FCE48C', c4 => '#5A3420', c5 => '#F28A1E');
my @S;

sub pt { sprintf '%.1f,%.1f', @_ }
sub poly { my ($cls, @p) = @_; push @S, sprintf '  <polygon class="%s" points="%s"/>', $cls, join ' ', map { pt(@$_) } @p; }
sub dir { my $a = deg2rad($_[0]); (cos($a), sin($a)) }        # angle in degrees, 0 = right, -90 = up
sub lit { my ($nx, $ny) = @_; ($nx * -0.7071 + $ny * -0.7071) > 0 } # faces the upper-left light?
sub light { my ($nx, $ny) = @_; my $l = sqrt($nx * $nx + $ny * $ny) || 1; ($nx * -0.7071 + $ny * -0.7071) / $l }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

# A tapered blade or stalk (as in wheat.pl). $taper < 1 keeps width at the tip. Returns points [x, y, angle].
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
  my ($dx, $dy) = dir($ang + $bend / 2);
  my $leftLit = lit(-$dy, $dx);
  my @m = map { [$_->[0], $_->[1]] } @mid;
  poly($leftLit ? $lightc : $dark, @l, reverse @m);
  poly($leftLit ? $dark : $lightc, @r, reverse @m);
  return @mid;
}

# A curly tendril: a thin strip whose curvature tightens toward the tip.
sub tendril {
  my ($x, $y, $ang, $len, $turn, $w, $cls) = @_;
  my $n = 30; my (@l, @r); my $a = $ang; my $step = $len / $n * 1.6;
  for my $i (0 .. $n) {
    my $t = $i / $n; my ($dx, $dy) = dir($a); my $hw = $w / 2 * (1 - 0.6 * $t);
    push @l, [$x - $dy * $hw, $y + $dx * $hw]; push @r, [$x + $dy * $hw, $y - $dx * $hw];
    $x += $dx * $step * (1 - 0.7 * $t); $y += $dy * $step * (1 - 0.7 * $t); $a += $turn * (0.15 + 1.7 * $t ** 1.6);
  }
  poly($cls // 'c2', @l, reverse @r);
}

# Kiwano leaf from above: three deep pointed lobes (the middle one longest) plus two small basal lobes,
# toothed edges; each lobe split along its vein into lit and shaded facets fanning from the leaf base.
sub kleaf {
  my ($x, $y, $ang, $r, $lightc, $dark, $wilt, $seed) = @_;
  $wilt //= 0; srand($seed // int($x * 13 + $y * 7));
  my @lobes = ([-122, 0.56], [-60, 0.9], [0, 1.0], [60, 0.9], [122, 0.56]);
  my @o;
  push @o, [-164, 0.3];
  for my $k (0 .. $#lobes) {
    my ($la, $lr) = @{$lobes[$k]};
    my $prevS = $k == 0 ? -164 : ($lobes[$k - 1][0] + $la) / 2;
    my $nextS = $k == $#lobes ? 164 : ($lobes[$k + 1][0] + $la) / 2;
    my $sr = $k == $#lobes ? 0.3 : ($k == 0 || $k == 3 ? 0.5 : 0.6);
    my $ps = $k == 0 ? 0.3 : ($k == 1 || $k == 4 ? 0.5 : 0.6);
    # toothed edge: small teeth on the way out to the lobe tip and back to the next sinus
    for my $f (0.35, 0.5, 0.68, 0.84) { my $rr = $ps + ($lr - $ps) * $f ** 0.8; push @o, [$la + ($prevS - $la) * (1 - $f) * 0.95, $rr * ($f == 0.5 || $f == 0.84 ? 1.04 : 0.98)]; }
    push @o, [$la, $lr];
    for my $f (0.84, 0.68, 0.5, 0.35) { my $rr = $sr + ($lr - $sr) * $f ** 0.8; push @o, [$la + ($nextS - $la) * (1 - $f) * 0.95, $rr * ($f == 0.5 || $f == 0.84 ? 1.04 : 0.98)]; }
    push @o, [$nextS, $sr];
  }
  my @p;
  for my $q (@o) {
    my ($oa, $or) = @$q;
    my $rr = $r * $or * (1 - $wilt * (0.2 + rand(0.45)));
    my $aa = $ang + $oa * (1 - $wilt * 0.35) + $wilt * (rand(30) - 15);
    my ($dx, $dy) = dir($aa);
    push @p, [$x + $dx * $rr, $y + $dy * $rr];
  }
  # fan facets from the base: each coloured by the side of its lobe's vein
  for my $i (0 .. $#p - 1) {
    my $mid = ($o[$i][0] + $o[$i + 1][0]) / 2;
    my ($best, $bd) = (0, 1e9); for my $k (0 .. $#lobes) { my $d = abs($mid - $lobes[$k][0]); ($best, $bd) = ($k, $d) if $d < $bd; }
    my $side = $mid < $lobes[$best][0] ? -1 : 1;
    my ($nx, $ny) = dir($ang + $lobes[$best][0] + $side * 90);
    poly(lit($nx, $ny) ? $lightc : $dark, [$x, $y], $p[$i], $p[$i + 1]);
  }
  return @p;
}

# Small yellow five-petal star flower from above, with an orange heart.
sub kflower {
  my ($x, $y, $r, $rot) = @_;
  for my $k (0 .. 4) {
    my $a = $rot + $k * 72; my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx);
    my @t = ([$x + $dx * $r, $y + $dy * $r]);
    my $L = [$x + $dx * $r * 0.45 + $nx * $r * 0.3, $y + $dy * $r * 0.45 + $ny * $r * 0.3];
    my $R = [$x + $dx * $r * 0.45 - $nx * $r * 0.3, $y + $dy * $r * 0.45 - $ny * $r * 0.3];
    my $leftLit = lit($nx, $ny);
    poly($leftLit ? 'c3' : 'c5', [$x, $y], $L, @t);
    poly($leftLit ? 'c5' : 'c3', [$x, $y], @t, $R);
  }
  poly('c5', map { my ($dx, $dy) = dir($rot + 36 + $_ * 72); [$x + $dx * $r * 0.24, $y + $dy * $r * 0.24] } 0 .. 4);
  poly('c4', map { my ($dx, $dy) = dir($rot + 36 + $_ * 72); [$x + $dx * $r * 0.1, $y + $dy * $r * 0.1] } 0 .. 4);
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

# Kiwano fruit: an oval body (length H along heading `ang`, width W) mottled with yellow blotches and
# studded with stout conical horns. Horns are placed on the ellipsoid surface and projected: on the face
# they read as little lit/shaded pyramids, at the rim as long spikes. $ripe 1 orange, 0 green; $shr dried.
sub kfruit {
  my ($cx, $cy, $ang, $H, $W, $ripe, $seed, $shr) = @_;
  $ripe //= 1; $shr //= 0; srand($seed // int($cx * 3 + $cy));
  my ($ax, $ay) = dir($ang); my ($bx, $by) = (-$ay, $ax);
  my ($body, $mott, $dark, $hl, $hd) = $ripe ? ('c5', 'c3', 'c4', 'c3', 'c4') : ('c2', 'c3', 'c1', 'c3', 'c1');
  ($body, $mott, $dark, $hl, $hd) = ('c4', 'c5', 'c4', 'c3', 'c4') if $shr;
  my $S = sub { my ($u, $v) = @_; [$cx + $ax * $u * $H / 2 + $bx * $v * $W / 2, $cy + $ay * $u * $H / 2 + $by * $v * $W / 2] };
  # horns: [screen base, screen normal, nz]
  my @horns;
  my $rows = $W > 90 ? 5 : $W > 40 ? 4 : 3;
  for my $i (0 .. $rows - 1) {
    my $th = pi * (0.1 + 0.8 * ($i + 0.5) / $rows);
    my $nph = max(2, int(($W > 90 ? 5 : $W > 40 ? 4 : 3) * sin($th) ** 0.6 + 0.5));
    for my $j (0 .. $nph - 1) {
      my $ph = pi * ($j + ($i % 2 ? 0.75 : 0.25)) / $nph;
      my ($u, $v, $z) = (cos($th), sin($th) * cos($ph), sin($th) * sin($ph));
      my ($nu, $nv, $nz) = ($u / ($H / 2), $v / ($W / 2), $z / ($W / 2)); my $l = sqrt($nu * $nu + $nv * $nv + $nz * $nz);
      ($nu, $nv, $nz) = ($nu / $l, $nv / $l, $nz / $l);
      push @horns, [$S->($u * 0.97, $v * 0.97), [$ax * $nu + $bx * $nv, $ay * $nu + $by * $nv], $nz];
    }
    for my $end (-1, 1) {   # rim horns on the far half too, so the silhouette bristles all round
      my $ph = $end < 0 ? pi + pi * 0.5 / $nph : -pi * 0.5 / $nph;
    }
  }
  my $hlen = $W * 0.13 * (1 - 0.35 * $shr); my $hw = $W * 0.085;
  my @rim = grep { $_->[2] < 0.5 } @horns;
  my @face = grep { $_->[2] >= 0.5 } @horns;
  my $horn = sub {
    my ($B, $N, $nz) = @{$_[0]};
    my ($nx, $ny) = @$N; my $pl = sqrt($nx * $nx + $ny * $ny) || 1;
    my ($ux, $uy) = ($nx / $pl, $ny / $pl); my ($px, $py) = (-$uy, $ux);
    my $len = $hlen * sqrt(max(0, 1 - $nz * $nz)) + $hw * 0.35;
    my $T = [$B->[0] + $ux * $len, $B->[1] + $uy * $len];
    my $w = $hw * (0.75 + 0.25 * $nz);
    my $L = [$B->[0] + $px * $w - $ux * $w * 0.5, $B->[1] + $py * $w - $uy * $w * 0.5];
    my $R = [$B->[0] - $px * $w - $ux * $w * 0.5, $B->[1] - $py * $w - $uy * $w * 0.5];
    my $Bk = [$B->[0] - $ux * $w * 0.9, $B->[1] - $uy * $w * 0.9];
    if ($nz > 0.35 && !$_[1]) { my $sh = $hw * 1.7; poly($hd eq "c1" ? "c1" : "c4", $L, $R, [$B->[0] + 0.55 * $sh + $ux * $len * 0.3, $B->[1] + 0.8 * $sh + $uy * $len * 0.3]); }
    my $lsL = lit($px, $py); my $lg = light($ux, $uy) * sqrt(max(0, 1 - $nz * $nz)) + 0.3 * $nz;
    my ($cl, $cd) = ($lg > -0.45 ? $hl : $body, $lg > 0.25 ? $body : $hd);
    poly($lsL ? $cl : $cd, $Bk, $L, $T); poly($lsL ? $cd : $cl, $Bk, $T, $R);
  };
  # far-rim horns behind the body
  for my $k (0 .. 11) {
    my $t = 2 * pi * ($k + 0.5) / 12; my ($u, $v) = (cos($t) * 0.98, sin($t) * 0.98);
    my ($nu, $nv) = ($u / ($H / 2), $v / ($W / 2)); my $l = sqrt($nu * $nu + $nv * $nv);
    $horn->([$S->($u, $v), [($ax * $nu + $bx * $nv) / $l, ($ay * $nu + $by * $nv) / $l], 0.05]);
  }
  my @o = map { my $t = 2 * pi * $_ / 36; $S->(cos($t), sin($t)) } 0 .. 35;
  poly($body, @o);
  # yellow mottling: irregular blotches, thicker on the lit side, none in the shade
  for my $k (0 .. ($W > 90 ? 26 : $W > 40 ? 12 : 6)) {
    my $u = rand(1.7) - 0.85; my $v = rand(1.7) - 0.85; next if $u * $u + $v * $v > 0.7;
    my $C = $S->($u, $v); my $lt = light($C->[0] - $cx, $C->[1] - $cy) * sqrt($u * $u + $v * $v);
    next if $lt < -0.2;
    my $rr = $W * (0.045 + rand(0.05));
    poly($mott, map { my ($dx, $dy) = dir($_ * 45 + rand(20)); [$C->[0] + $dx * $rr * (0.75 + rand(0.4)), $C->[1] + $dy * $rr * (0.75 + rand(0.4))] } 0 .. 7);
  }
  shade_rim($cx, $cy, ($H + $W) / 4, $dark, 0.8, @o);
  # glossy lit cheek
  unless ($shr) {
    my @g = map { my $t = deg2rad(200 + $_ * 12); $S->(-0.35 + 0.4 * cos($t) * 0.9, -0.42 + 0.3 * sin($t)) } 0 .. 7;
    my $cG = $S->(-0.35, -0.42);
  }
  $horn->($_) for sort { $a->[2] <=> $b->[2] } @horns;
  return $S;
}

# Halved kiwano seen from the front: the horned shell peeks out behind the cut face, which shows a pale
# rind ring and lime-green jelly packed with seed sacs, each holding a pale flat seed.
sub khalf {
  my ($cx, $cy, $ang, $H, $W, $seed) = @_;
  srand($seed);
  my ($ax, $ay) = dir($ang); my ($bx, $by) = (-$ay, $ax);
  kfruit($cx + $W * 0.07, $cy + $W * 0.1, $ang, $H, $W, 1, $seed);
  my $S = sub { my ($u, $v, $k) = @_; $k //= 1; [$cx + $ax * $u * $H / 2 * $k + $bx * $v * $W / 2 * $k, $cy + $ay * $u * $H / 2 * $k + $by * $v * $W / 2 * $k] };
  my $ell = sub { my ($k) = @_; map { my $t = 2 * pi * $_ / 40; $S->(cos($t), sin($t), $k) } 0 .. 39 };
  poly('c5', $ell->(1.0));
  poly('c3', $ell->(0.92));
  poly('c1', $ell->(0.8));
  # seed sacs on a jittered grid inside the jelly
  my @sacs;
  for my $i (-5 .. 5) { for my $j (-3 .. 3) {
    my $u = $i * 0.15 + ($j % 2 ? 0.075 : 0) + rand(0.03); my $v = $j * 0.23 + rand(0.04);
    next if ($u / 0.72) ** 2 + ($v / 0.68) ** 2 > 1;
    push @sacs, [$u, $v];
  } }
  for my $s (@sacs) {
    my ($u, $v) = @$s; my $C = $S->($u, $v);
    my $rr = $W * 0.07;
    my @o = map { my ($dx, $dy) = dir($_ * 51.4 + 10); [$C->[0] + $dx * $rr * (0.95 + 0.15 * ($_ % 2)), $C->[1] + $dy * $rr * (0.95 + 0.15 * ($_ % 2))] } 0 .. 6;
    poly('c2', @o);
  }
  for my $s (@sacs) {   # flat seed in each sac, pointing out from the core
    my ($u, $v) = @$s; my $C = $S->($u, $v);
    my $a = rad2deg(atan2($by * $v + $ay * $u * 0.3, $bx * $v + $ax * $u * 0.3));
    my ($dx, $dy) = dir($a); my ($nx, $ny) = (-$dy, $dx); my $L = $W * 0.042; my $w = $W * 0.02;
    poly('c3', [$C->[0] - $dx * $L, $C->[1] - $dy * $L], [$C->[0] + $nx * $w, $C->[1] + $ny * $w], [$C->[0] + $dx * $L, $C->[1] + $dy * $L], [$C->[0] - $nx * $w, $C->[1] - $ny * $w]);
  }
  # glossy streak on the jelly
  my @g; my @h;
  for my $i (0 .. 8) { my $t = deg2rad(195 + $i * 9); push @g, $S->(cos($t) * 0.72, sin($t) * 0.66); push @h, $S->(cos($t) * 0.64, sin($t) * 0.58); }
}

# Flat kiwano seed: a pale pointed oval with a shaded rim; $jelly wraps it in a lime-green sac.
sub kseed {
  my ($x, $y, $ang, $len, $w, $jelly) = @_;
  my ($dx, $dy) = dir($ang); my ($nx, $ny) = (-$dy, $dx);
  if ($jelly) {
    my @j = map { my $t = 2 * pi * $_ / 14; my ($u, $v) = (cos($t) * $len * 0.8, sin($t) * $w * 1.15); [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v] } 0 .. 13;
    poly('c2', @j);
    shade_rim($x, $y, $len * 0.6, 'c1', 0.75, @j);
  }
  my @o;
  for my $i (0 .. 15) {
    my $th = 2 * pi * $i / 16;
    my $u = cos($th) * $len / 2; my $v = sin($th) * $w / 2 * (1 - 0.25 * cos($th));
    push @o, [$x + $dx * $u + $nx * $v, $y + $dy * $u + $ny * $v];
  }
  poly('c3', @o);
  shade_rim($x, $y, $len * 0.5, $jelly ? 'c1' : 'c4', 0.8, @o);
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

# A leaf on its petiole.
sub leaf_on {
  my ($x, $y, $ang, $plen, $r, $lc, $dc, $wilt, $seed) = @_;
  my @m = blade($x, $y, $ang, $plen, 4, 0, $lc // 'c2', $dc // 'c1', 0.4);
  kleaf($m[-1][0], $m[-1][1], $ang, $r, $lc // 'c2', $dc // 'c1', $wilt, $seed);
}
sub vine {
  my ($ang, $len, $bend, $w, $lc, $dc) = @_;
  my ($dx, $dy) = dir($ang);
  return blade(200 + $dx * 4, 200 + $dy * 4, $ang, $len, $w, $bend, $lc // 'c2', $dc // 'c1', 0.55);
}
sub at { my ($pts, $t) = @_; my $i = int($t * $#$pts + 0.5); @{$pts->[$i]} }

# Smooth seed leaf (cotyledon), split along its midrib.
sub seedleaf {
  my ($x, $y, $ang, $len, $w) = @_;
  my $n = 10; my (@mid, @l, @r); my ($dx, $dy) = dir($ang);
  for my $i (0 .. $n) {
    my $t = $i / $n; my $hw = $w / 2 * sin(pi * (0.08 + 0.92 * $t)) ** 0.55;
    my ($px, $py) = ($x + $dx * $len * $t, $y + $dy * $len * $t);
    push @l, [$px - $dy * $hw, $py + $dx * $hw]; push @r, [$px + $dy * $hw, $py - $dx * $hw]; push @mid, [$px, $py];
  }
  my $leftLit = lit(-$dy, $dx);
  poly($leftLit ? 'c2' : 'c1', @l, reverse @mid);
  poly($leftLit ? 'c1' : 'c2', @r, reverse @mid);
}

# ---------------------------------------------------------------------------------------------
# 1. Seeds, front view: pale flat seeds, a few still in their green jelly sacs, before a small horned fruit.
kfruit(212, 150, -62, 170, 116, 1, 11);
{ srand(12); my @sd;
  for my $row ([322, 5], [290, 4], [260, 3]) { my ($y, $c) = @$row;
    for my $k (0 .. $c - 1) { push @sd, [200 + ($k - ($c - 1) / 2) * 50 + rand(10) - 5, $y + rand(8) - 4, rand(360), 46, 26, ($k + $c) % 3 == 0]; } }
  kseed(@$_) for sort { $a->[1] <=> $b->[1] } @sd; }
write_svg('1-seeds-front.svg', 'Kiwano seeds');

# 2. Just sown, top down: seeds pressed into small soil pockets.
my @sown = ([170, 172, -20], [236, 170, 50], [200, 230, 100]);
for (@sown) { soil($_->[0], $_->[1], 32, 27, int($_->[0] * 7 + $_->[1])); }
for (@sown) { kseed($_->[0] - 8, $_->[1] + 3, $_->[2], 30, 17); kseed($_->[0] + 9, $_->[1] - 4, $_->[2] + 150, 28, 16); }
write_svg('2-sown.svg', 'Kiwano just sown');

# 3. First growth, top down: two seed leaves and the first small lobed leaf.
soil(200, 200, 34, 30, 3);
seedleaf(200, 200, 160, 74, 34); seedleaf(200, 200, -20, 74, 34);
leaf_on(200, 200, -100, 20, 46, "c2", "c1", 0, 31);
leaf_on(200, 200, 78, 14, 34, "c2", "c1", 0, 32);
write_svg('3-first-growth.svg', 'Kiwano first growth');

# 4. Second growth, top down: a young vine with deep three-lobed leaves and a first curly runner.
soil(200, 200, 34, 30, 4);
{
  my @v = vine(28, 136, 40, 7);
  tendril((at(\@v, 0.95))[0], (at(\@v, 0.95))[1], 110, 34, 26, 3);
  tendril((at(\@v, 0.5))[0], (at(\@v, 0.5))[1], -40, 30, -24, 3);
  my ($x, $y, $a) = at(\@v, 1.0); leaf_on($x, $y, $a - 10, 6, 32, 'c2', 'c1', 0, 42);
  ($x, $y, $a) = at(\@v, 0.6); leaf_on($x, $y, $a + 70, 12, 34, 'c2', 'c1', 0, 47);
  leaf_on(200, 200, 148, 50, 56, 'c2', 'c1', 0, 43);
  leaf_on(200, 200, -150, 48, 54, 'c2', 'c1', 0, 44);
  leaf_on(200, 200, 92, 44, 52, 'c2', 'c1', 0, 45);
  leaf_on(200, 200, -82, 50, 58, 'c2', 'c1', 0, 46);
  leaf_on(200, 200, -24, 36, 48, 'c2', 'c1', 0, 48);
}
write_svg('4-second-growth.svg', 'Kiwano second growth');

# 5. Third growth, top down: sprawling vines, tendrils, small yellow star flowers and young green horned fruit.
soil(200, 200, 34, 30, 5);
{
  my @v1 = vine(-35, 146, 44, 8); my @v2 = vine(95, 140, -40, 8); my @v3 = vine(200, 140, 34, 8);
  for my $v (\@v1, \@v2, \@v3) {
    my ($x, $y, $a) = at($v, 0.5); tendril($x, $y, $a + 70, 38, 22, 3);
    ($x, $y, $a) = at($v, 0.92); tendril($x, $y, $a - 80, 34, -22, 3);
  }
  for my $v (\@v1, \@v2, \@v3) {
    my ($x, $y, $a) = at($v, 1.0); leaf_on($x, $y, $a, 6, 34, 'c2', 'c1', 0, int($x));
    ($x, $y, $a) = at($v, 0.7); leaf_on($x, $y, $a + 62, 18, 40, 'c2', 'c1', 0, int($y));
    ($x, $y, $a) = at($v, 0.35); leaf_on($x, $y, $a - 66, 16, 38, 'c2', 'c1', 0, int($y + $x));
  }
  for my $l ([-110, 34, 50], [12, 30, 46], [150, 32, 48], [250, 28, 46]) { leaf_on(200, 200, $l->[0], $l->[1], $l->[2], 'c2', 'c1', 0, $l->[0] + 500); }
  for my $fl ([\@v1, 0.45, -60, 15], [\@v2, 0.55, 60, 14], [\@v3, 0.6, -60, 15], [\@v1, 0.85, 60, 13]) {
    my ($v, $t, $da, $r) = @$fl; my ($x, $y, $a) = at($v, $t);
    my @s = blade($x, $y, $a + $da, 14, 3, 0, 'c2', 'c1', 0.4);
    kflower($s[-1][0], $s[-1][1], $r, $a + $da);
  }
  for my $fr ([\@v2, 0.82, -50], [\@v3, 0.3, 50]) {
    my ($v, $t, $da) = @$fr; my ($x, $y, $a) = at($v, $t); my ($dx, $dy) = dir($a + $da);
    blade($x, $y, $a + $da, 12, 3, 0, 'c2', 'c1', 0.4);
    kfruit($x + $dx * 26, $y + $dy * 26, $a + $da, 34, 24, 0, int($x));
  }
}
write_svg('5-third-growth.svg', 'Kiwano third growth');

# 6. Harvest, top down: ripe orange horned melons among the leaves of the sprawling vine.
soil(200, 200, 34, 30, 6);
{
  my @v1 = vine(-40, 166, 34, 9); my @v2 = vine(120, 150, -24, 9); my @v3 = vine(215, 150, 26, 8); my @v4 = vine(40, 150, -30, 8);
  for my $v (\@v1, \@v2, \@v3, \@v4) {
    my ($x, $y, $a) = at($v, 0.6); tendril($x, $y, $a - 70, 40, -22, 3);
    ($x, $y, $a) = at($v, 0.95); tendril($x, $y, $a + 80, 34, 22, 3);
  }
  for my $l ([\@v1, 1.0, 0, 6, 38], [\@v1, 0.5, -70, 18, 44], [\@v2, 1.0, 0, 6, 40], [\@v3, 1.0, 0, 6, 38], [\@v3, 0.5, 70, 20, 44],
             [\@v4, 1.0, 0, 6, 40], [\@v4, 0.55, 64, 16, 42], [\@v2, 0.45, 66, 16, 42]) {
    my ($v, $t, $da, $pl, $r) = @$l; my ($x, $y, $a) = at($v, $t); leaf_on($x, $y, $a + $da, $pl, $r, 'c2', 'c1', 0, int($x + $y));
  }
  for my $l ([-110, 36, 50], [-10, 32, 48], [180, 36, 50], [70, 28, 46]) { leaf_on(200, 200, $l->[0], $l->[1], $l->[2], 'c2', 'c1', 0, $l->[0] + 600); }
  kflower((at(\@v1, 0.8))[0] + 12, (at(\@v1, 0.8))[1] - 14, 13, 10);
  for my $fr ([\@v1, 0.42, 58, 84, 58], [\@v2, 0.7, -52, 88, 62], [\@v3, 0.68, 56, 84, 60], [\@v4, 0.72, -60, 74, 52]) {
    my ($v, $t, $da, $H, $W) = @$fr; my ($x, $y, $a) = at($v, $t); my ($dx, $dy) = dir($a + $da);
    blade($x, $y, $a + $da, 14, 4, 0, 'c2', 'c1', 0.4);
    kfruit($x + $dx * ($H / 2 + 8), $y + $dy * ($H / 2 + 8), $a + $da, $H, $W, 1, int($x + $y));
  }
}
write_svg('6-harvest.svg', 'Kiwano ready to harvest');

# 7. Harvest, front view: one whole horned melon and one halved to show the green jelly and pale seeds.
kfruit(150, 168, -28, 236, 158, 1, 71);
khalf(252, 248, 22, 220, 150, 72);
write_svg('7-harvest-front.svg', 'Harvested kiwano');

# 8. Dead (never watered), top down: cracked dry soil, a dried-out vine and shrivelled curled leaves,
#    one small withered fruit.
soil(200, 200, 54, 46, 8);
cracks(8, 83, 12, 'c3');
{
  my @v1 = vine(-25, 120, 70, 6, 'c3', 'c4'); my @v2 = vine(150, 110, -60, 6, 'c3', 'c4');
  for my $v (\@v1, \@v2) { my ($x, $y, $a) = at($v, 0.8); tendril($x, $y, $a + 60, 30, 30, 3, 'c3'); }
  for my $l ([-100, 26, 42], [20, 24, 44], [100, 30, 42], [200, 24, 44], [-160, 30, 38]) {
    leaf_on(200, 200, $l->[0], $l->[1] + 20, $l->[2] + 14, 'c3', 'c4', 0.55, $l->[0] + 800);
  }
  my ($x, $y, $a) = at(\@v1, 0.7); kfruit($x + 16, $y + 20, $a + 60, 40, 28, 1, 88, 1);
}
write_svg('8-dead.svg', 'Kiwano died from lack of water');
print "wrote 8 files to $OUT\n";

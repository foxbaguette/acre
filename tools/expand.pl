#!/usr/bin/perl
# Expands a creature source file (.tpl) into a finished SVG made of plain polygons.
# Usage: perl tools/expand.pl tools/src-flyers/pegasus.tpl flyers/pegasus.svg
#
# Shorthand tags inside a source file:
#   <palette name="Pegasus" c1=".." c2=".." c3=".." c4=".." c5=".." [mirror="1"]/>   -> svg header + style block (mirror flips the whole drawing left/right)
#   <fan b="x,y x,y" t="x,y x,y" n="6" cls="c1 c2" shape="tri|quad"/>                -> feathers between a base edge and a tip edge
#   <ribbon pts="x,y,w x,y,w ..." cls="c1" top="c2" under="c3"/>                     -> tapering body (tail to head, left of travel = top)
#   <part name="headSide|headFront" at="x,y" s="1" rot="0" flip="0" tuft="1" ruff="1" fang="1|2" closed="1"/>  -> reusable cat head
use strict;
use warnings;

my ($in, $out) = @ARGV;
open my $fh, '<', $in or die "cannot read $in: $!";
local $/;
my $s = <$fh>;
close $fh;

sub attrs { my %a = $_[0] =~ /(\w+)="([^"]*)"/g; return %a; }
sub lerp  { my ($a, $b, $t) = @_; return [ $a->[0] + ($b->[0] - $a->[0]) * $t, $a->[1] + ($b->[1] - $a->[1]) * $t ]; }
sub pt    { return [ split /,/, $_[0] ]; }
sub r     { my $v = shift; return int($v + ($v < 0 ? -0.5 : 0.5)); }
sub fmt   { return join ' ', map { r($_->[0]) . ',' . r($_->[1]) } @_; }
sub poly  { my $c = shift; return sprintf('  <polygon class="%s" points="%s"/>', $c, fmt(@_)); }

my %PART = (
  headSide => sub {
    my %o = @_;
    my @p = (
      ['c1', '-6,-30 20,-42 52,-32 68,-8 62,20 36,30 6,26 -10,6'],
      ['c2', '-6,-30 20,-42 52,-32 68,-8 36,-20 8,-14'],
      ['c3', '68,-8 62,20 36,30 30,16 54,10 60,0'],
      ['c1', '4,-36 -2,-68 26,-42'], ['c4', '6,-42 2,-58 18,-44'],
      ['c1', '28,-42 44,-68 52,-36'], ['c4', '32,-44 42,-58 46,-40'],
    );
    push @p, ['c4', '-2,-68 -6,-88 8,-62'], ['c4', '44,-68 50,-88 56,-62'] if $o{tuft};
    push @p, ['c3', '-10,6 -26,22 -6,32 8,26'], ['c3', '8,26 -6,32 20,42 36,30'] if $o{ruff};
    if ($o{closed}) { push @p, ['pupil', '28,-8 46,-10 46,-6 28,-4']; }
    else { push @p, ['eye', '28,-14 46,-16 48,-4 30,-2'], ['pupil', '37,-16 41,-10 37,-4 33,-10']; }
    push @p, ['c4', '64,-8 72,-8 68,-2'];
    push @p, ['c3', '52,18 57,18 54,36'] if ($o{fang} // 0) == 1;
    push @p, ['c3', '52,18 59,18 55,62'], ['c3', '40,24 46,24 43,56'] if ($o{fang} // 0) == 2;
    return @p;
  },
  headFront => sub {
    my %o = @_;
    my @p = (
      ['c1', '-32,-26 -26,-48 -10,-36 0,-40 10,-36 26,-48 32,-26 40,0 26,28 0,38 -26,28 -40,0'],
      ['c2', '-32,-26 -26,-48 -10,-36 0,-40 10,-36 26,-48 32,-26 0,-14'],
      ['c4', '-24,-42 -14,-34 -26,-26'], ['c4', '24,-42 14,-34 26,-26'],
      ['c3', '-14,10 14,10 20,28 0,38 -20,28'],
    );
    push @p, ['c4', '-26,-48 -36,-84 -12,-38'], ['c4', '26,-48 36,-84 12,-38'] if $o{tuft};
    push @p, ['c3', '-40,0 -58,16 -44,34 -26,28'], ['c3', '40,0 58,16 44,34 26,28'] if $o{ruff};
    push @p,
      ['eye', '-26,-10 -8,-12 -8,2 -26,4'], ['pupil', '-18,-12 -14,-4 -18,2 -22,-4'],
      ['eye', '26,-10 8,-12 8,2 26,4'], ['pupil', '18,-12 22,-4 18,2 14,-4'],
      ['c4', '-6,10 6,10 0,18'];
    return @p;
  },
  serpentHead => sub {
    my %o = @_;
    my @p = (
      ['c1', '-14,-12 14,-14 34,0 30,12 -8,14'], ['c2', '-14,-12 14,-14 34,0 4,-6'],
      ['c3', '34,0 30,12 -8,14 10,6'], ['c5', '-14,-12 -26,-26 -6,-14'],
      ['eye', '6,-8 16,-8 16,2 6,2'], ['pupil', '11,-8 14,-3 11,2 8,-3'], ['c4', '30,-2 36,0 32,4'],
    );
    unshift @p, ['c5', '-14,-12 -34,-22 -30,-4 -36,14 -8,14'] if $o{frill};
    push @p, ['c3', '-8,-12 -4,-36 4,-12'], ['c3', '6,-14 14,-36 16,-14'] if $o{horns};
    push @p, ['c5', '-14,-12 -24,-38 -4,-14'], ['c5', '0,-14 4,-42 12,-14'], ['c3', '-24,-38 -18,-22 -22,-22'] if $o{crystal};
    return @p;
  },
);

sub part {
  my %a = attrs($_[0]);
  my ($ax, $ay) = split /,/, $a{at};
  my $s = $a{s} // 1;
  my $rot = ($a{rot} // 0) * 3.14159265 / 180;
  my $flip = $a{flip} ? -1 : 1;
  my @o;
  for my $it ($PART{ $a{name} }->(%a)) {
    my ($cls, $pts) = @$it;
    my @tp = map {
      my ($x, $y) = split /,/;
      $x *= $flip * $s;
      $y *= $s;
      [ $ax + $x * cos($rot) - $y * sin($rot), $ay + $x * sin($rot) + $y * cos($rot) ]
    } split ' ', $pts;
    push @o, poly($cls, @tp);
  }
  return join "\n", @o;
}

sub fan {
  my %a = attrs($_[0]);
  my ($b0, $b1) = map { pt($_) } split ' ', $a{b};
  my ($t0, $t1) = map { pt($_) } split ' ', $a{t};
  my $n = $a{n};
  my @c = split ' ', $a{cls};
  my $tri = ($a{shape} // 'tri') eq 'tri';
  my @o;
  for my $i (0 .. $n - 1) {
    my ($u, $v) = ($i / $n, ($i + 1) / $n);
    my $bu = lerp($b0, $b1, $u);
    my $bv = lerp($b0, $b1, $v);
    if ($tri) {
      push @o, poly($c[$i % @c], $bu, $bv, lerp($t0, $t1, ($i + 0.5) / $n));
    } else {
      push @o, poly($c[$i % @c], $bu, $bv, lerp($t0, $t1, $v), lerp($t0, $t1, $u));
    }
  }
  return join "\n", @o;
}

sub ribbon {
  my %a = attrs($_[0]);
  my @p = map { [ split /,/ ] } split ' ', $a{pts};
  my (@A, @B);
  for my $i (0 .. $#p) {
    my $pr = $p[ $i > 0 ? $i - 1 : 0 ];
    my $nx = $p[ $i < $#p ? $i + 1 : $#p ];
    my ($dx, $dy) = ($nx->[0] - $pr->[0], $nx->[1] - $pr->[1]);
    my $l = sqrt($dx * $dx + $dy * $dy) || 1;
    my ($nxv, $nyv) = ($dy / $l, -$dx / $l);
    my $h = $p[$i][2] / 2;
    push @A, [ $p[$i][0] + $nxv * $h, $p[$i][1] + $nyv * $h ];
    push @B, [ $p[$i][0] - $nxv * $h, $p[$i][1] - $nyv * $h ];
  }
  my @o;
  for my $i (0 .. $#p - 1) {
    push @o, poly($a{cls}, $A[$i], $A[$i + 1], $B[$i + 1], $B[$i]);
    if ($a{top}) {
      my $f = $i % 2 ? 0.28 : 0.42;
      push @o, poly($a{top}, $A[$i], $A[$i + 1], lerp($A[$i + 1], $B[$i + 1], $f), lerp($A[$i], $B[$i], $f));
    }
    if ($a{under}) {
      my $f = $i % 2 ? 0.42 : 0.3;
      push @o, poly($a{under}, $B[$i], $B[$i + 1], lerp($B[$i + 1], $A[$i + 1], $f), lerp($B[$i], $A[$i], $f));
    }
  }
  return join "\n", @o;
}

sub flipx {
  my $t = shift;
  $t =~ s{points="([^"]+)"}{
    'points="' . join(' ', map { my ($x, $y) = split /,/; (400 - $x) . ",$y" } split(' ', $1)) . '"'
  }ge;
  $t =~ s{cx="([\d.-]+)"}{ 'cx="' . (400 - $1) . '"' }ge;
  return $t;
}

# <legs pts="x,y,w ..." n="8" len="26" cls="c4" thick="3" sweep="0.5"/>
# Two-jointed legs on both sides of a path, perpendicular to it.
sub legs {
  my %a = attrs($_[0]);
  my @p = map { [ split /,/ ] } split ' ', $a{pts};
  my ($n, $len, $cls) = ($a{n}, $a{len}, $a{cls});
  my $th = $a{thick} // 3;
  my $sw = $a{sweep} // 0.5;
  my @cum = (0);
  for my $i (1 .. $#p) {
    push @cum, $cum[-1] + sqrt(($p[$i][0] - $p[$i-1][0])**2 + ($p[$i][1] - $p[$i-1][1])**2);
  }
  my $total = $cum[-1];
  my @o;
  for my $k (0 .. $n - 1) {
    my $d = $total * ($k + 0.5) / $n;
    my $i = 1;
    $i++ while $i < $#p && $cum[$i] < $d;
    my $f = ($d - $cum[$i-1]) / (($cum[$i] - $cum[$i-1]) || 1);
    my @pos = ($p[$i-1][0] + ($p[$i][0] - $p[$i-1][0]) * $f, $p[$i-1][1] + ($p[$i][1] - $p[$i-1][1]) * $f);
    my $w = $p[$i-1][2] + ($p[$i][2] - $p[$i-1][2]) * $f;
    my ($dx, $dy) = ($p[$i][0] - $p[$i-1][0], $p[$i][1] - $p[$i-1][1]);
    my $l = sqrt($dx * $dx + $dy * $dy) || 1;
    ($dx, $dy) = ($dx / $l, $dy / $l);
    for my $side (1, -1) {
      my ($nx, $ny) = ($side * $dy, -$side * $dx);
      my @base = ($pos[0] + $nx * $w / 2, $pos[1] + $ny * $w / 2);
      my @knee = ($base[0] + $nx * $len * 0.55 - $dx * $len * $sw * 0.5, $base[1] + $ny * $len * 0.55 - $dy * $len * $sw * 0.5);
      my @foot = ($knee[0] + $nx * $len * 0.45 - $dx * $len * $sw, $knee[1] + $ny * $len * 0.45 - $dy * $len * $sw);
      for my $seg ([\@base, \@knee, $th, $th * 0.8], [\@knee, \@foot, $th * 0.8, $th * 0.4]) {
        my ($s0, $s1, $w0, $w1) = @$seg;
        my ($sx, $sy) = ($s1->[0] - $s0->[0], $s1->[1] - $s0->[1]);
        my $sl = sqrt($sx * $sx + $sy * $sy) || 1;
        my ($px, $py) = (-$sy / $sl, $sx / $sl);
        push @o, poly($cls,
          [ $s0->[0] + $px * $w0 / 2, $s0->[1] + $py * $w0 / 2 ], [ $s1->[0] + $px * $w1 / 2, $s1->[1] + $py * $w1 / 2 ],
          [ $s1->[0] - $px * $w1 / 2, $s1->[1] - $py * $w1 / 2 ], [ $s0->[0] - $px * $w0 / 2, $s0->[1] - $py * $w0 / 2 ]);
      }
    }
  }
  return join "\n", @o;
}

my $mirror = ($s =~ /<palette[^>]*mirror="1"/) ? 1 : 0;

$s =~ s{<palette\s+([^>]*?)/>}{
  my %a = attrs($1);
  qq{<?xml version="1.0" encoding="UTF-8"?>\n<svg viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="$a{name}">\n  <style>\n}
  . join('', map { "    .$_ { fill: var(--$_, $a{$_}); }\n" } qw(c1 c2 c3 c4 c5))
  . qq{    .eye { fill: #fff; }\n    .pupil { fill: #000; }\n  </style>}
}ge;
$s =~ s{<fan\s+([^>]*?)/>}{ fan($1) }ge;
$s =~ s{<ribbon\s+([^>]*?)/>}{ ribbon($1) }ge;
$s =~ s{<part\s+([^>]*?)/>}{ part($1) }ge;
$s =~ s{<legs\s+([^>]*?)/>}{ legs($1) }ge;
# <sym> ... </sym> draws its content as written and again mirrored about x=200
$s =~ s{<sym>\n?(.*?)</sym>\n?}{ my $c = $1; $c . flipx($c) }gse;

$s = flipx($s) if $mirror;

open my $o, '>', $out or die "cannot write $out: $!";
print $o $s;
close $o;
print "$out\n";

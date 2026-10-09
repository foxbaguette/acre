#!/usr/bin/perl
# Fits each drawing inside its 400x400 viewBox: centers it and, when it is larger than the
# safe area, scales it down so nothing is cut off.
# Usage (Git Bash):  perl tools/center.pl animals/*.svg
# It wraps everything after </style> in one <g transform="..."> group,
# replacing any wrapper from a previous run, so it is safe to re-run.
use strict;
use warnings;

my $SAFE = 380;    # largest allowed width or height (10px margin on every side)

for my $file (@ARGV) {
  open my $in, '<', $file or die "cannot read $file: $!";
  local $/;
  my $svg = <$in>;
  close $in;

  # remove a previous wrapper
  $svg =~ s/  <g transform="[^"]*">\n//;
  $svg =~ s/  <\/g>\n(<\/svg>)/$1/;

  my ($minx, $miny, $maxx, $maxy) = (1e9, 1e9, -1e9, -1e9);
  while ($svg =~ /points="([^"]+)"/g) {
    for my $pair (split /\s+/, $1) {
      my ($x, $y) = split /,/, $pair;
      next unless defined $y;
      $minx = $x if $x < $minx; $maxx = $x if $x > $maxx;
      $miny = $y if $y < $miny; $maxy = $y if $y > $maxy;
    }
  }
  while ($svg =~ /<circle[^>]*cx="([\d.-]+)"[^>]*cy="([\d.-]+)"[^>]*r="([\d.]+)"/g) {
    my ($x, $y, $r) = ($1, $2, $3);
    $minx = $x - $r if $x - $r < $minx; $maxx = $x + $r if $x + $r > $maxx;
    $miny = $y - $r if $y - $r < $miny; $maxy = $y + $r if $y + $r > $maxy;
  }

  my ($w, $h) = ($maxx - $minx, $maxy - $miny);
  my $s = 1;
  $s = $SAFE / $w if $w * $s > $SAFE;
  $s = $SAFE / $h if $h * $s > $SAFE;
  my ($cx, $cy) = (($minx + $maxx) / 2, ($miny + $maxy) / 2);

  my $transform;
  if ($s >= 0.9999) {
    my $dx = sprintf('%.1f', 200 - $cx);
    my $dy = sprintf('%.1f', 200 - $cy);
    $dx =~ s/\.0$//; $dy =~ s/\.0$//;
    $transform = "translate($dx $dy)";
  } else {
    $transform = sprintf('translate(200 200) scale(%.4f) translate(%.1f %.1f)', $s, -$cx, -$cy);
  }

  $svg =~ s/(  <\/style>\n)/$1  <g transform="$transform">\n/;
  $svg =~ s/(<\/svg>)/  <\/g>\n$1/;

  open my $out, '>', $file or die "cannot write $file: $!";
  print $out $svg;
  close $out;
  printf "%-40s %3dx%3d scale %.3f\n", $file, $w, $h, $s;
}

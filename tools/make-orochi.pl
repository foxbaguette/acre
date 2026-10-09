#!/usr/bin/perl
# Generates Yamata-no-Orochi variants as .tpl sources in tools/src-orochi/.
# Usage: perl tools/make-orochi.pl   (then build each with tools/expand.pl and center with tools/center.pl)
# Each variant changes: palette, how far the eight necks spread (k) and how tall they rise (m),
# which options every head gets (horns / frill / crystal) and the decoration on the coiled body.
use strict;
use warnings;

# the eight necks, each as 4 points x,y,width (same layout as the original yokai/yamata-orochi)
my @NECKS = (
  [[205,282,34],[220,200,28],[224,130,24],[218,52,18]],
  [[215,284,34],[260,210,28],[276,140,24],[270,70,18]],
  [[190,282,34],[170,200,28],[164,130,24],[164,58,18]],
  [[225,288,34],[290,230,28],[330,170,24],[340,110,18]],
  [[180,285,34],[140,210,28],[120,140,24],[112,72,18]],
  [[240,296,34],[320,260,28],[372,226,22],[392,176,16]],
  [[170,290,34],[120,230,28],[70,170,24],[52,110,18]],
  [[150,300,34],[90,280,28],[50,250,22],[30,200,16]],
);

my $MOUND = <<'END';
  <polygon class="c1" points="70,352 110,290 200,258 290,290 330,352 280,382 120,382"/>
  <polygon class="c2" points="110,290 200,258 290,290 200,290"/>
  <polygon class="c3" points="120,382 280,382 330,352 200,364"/>
  <polygon class="c4" points="130,310 142,304 150,314 138,322"/>
  <polygon class="c4" points="250,312 262,306 270,316 258,324"/>
  <polygon class="c4" points="190,336 202,330 210,340 198,348"/>
END

my %V = (
  'frost-orochi' => {
    name => 'Frost Orochi', pal => ['#4A7AA8', '#8AB8E0', '#E8F4FF', '#1A2E4A', '#8AF0FF'],
    k => 1.0, m => 1.0, opts => 'crystal="1"',
    back => '',
    decor => <<'E',
  <polygon class="c5" points="150,300 140,262 170,290"/>
  <polygon class="c5" points="240,296 262,262 264,300"/>
  <polygon class="c3" points="130,300 200,262 270,300 200,284"/>
  <polygon class="c5" points="140,380 148,380 144,404"/>
  <polygon class="c5" points="196,382 206,382 201,410"/>
  <polygon class="c5" points="252,380 260,380 256,404"/>
E
  },
  'magma-orochi' => {
    name => 'Magma Orochi', pal => ['#7A2A1A', '#B8502A', '#F0C080', '#2A0E08', '#FF8A2A'],
    k => 1.15, m => 0.9, wave => 14, opts => 'horns="1"',
    back => '',
    decor => <<'E',
  <polygon class="c5" points="150,300 158,296 170,350 160,356"/>
  <polygon class="c5" points="240,300 250,298 246,350 236,352"/>
  <polygon class="c5" points="196,296 204,296 206,340 194,340"/>
  <polygon class="c5" points="96,330 104,320 112,330 104,340"/>
  <polygon class="c5" points="300,326 308,316 316,326 308,336"/>
E
  },
  'blossom-orochi' => {
    name => 'Blossom Orochi', pal => ['#7AA880', '#B0D4A0', '#F8E8EC', '#3A5A3A', '#F8A8C8'],
    k => 0.9, m => 1.1, arch => 46, wave => 6, opts => 'frill="1"',
    back => '',
    decor => <<'E',
  <polygon class="c5" points="160,300 170,292 180,300 170,310"/>
  <polygon class="c5" points="196,320 206,312 216,320 206,330"/>
  <polygon class="c5" points="240,304 250,296 260,304 250,314"/>
  <polygon class="c5" points="130,338 138,330 146,338 138,346"/>
  <polygon class="c5" points="268,338 276,330 284,338 276,346"/>
  <polygon class="c3" points="180,336 188,330 192,340 184,344"/>
  <polygon class="c3" points="226,350 234,344 238,354 230,358"/>
E
  },
  'storm-orochi' => {
    name => 'Storm Orochi', pal => ['#3A4A6A', '#6A7AA0', '#D0D8F0', '#12182A', '#FFE45A'],
    k => 1.0, m => 1.05, wave => -12, opts => 'horns="1"',
    back => <<'E',
  <polygon class="c3" points="40,350 56,300 110,290 130,330 90,360"/>
  <polygon class="c3" points="270,330 290,290 346,296 362,346 310,366"/>
  <polygon class="c5" points="140,150 152,150 146,176 158,176 130,224 138,184 128,184"/>
  <polygon class="c5" points="268,150 280,150 274,176 286,176 258,224 266,184 256,184"/>
E
    decor => <<'E',
  <polygon class="c3" points="80,352 100,316 150,312 160,350"/>
  <polygon class="c3" points="250,352 262,312 312,316 330,352"/>
E
  },
  'gold-orochi' => {
    name => 'Gold Orochi', pal => ['#C89A30', '#F0D060', '#FFF0B8', '#5A3A10', '#D8352F'],
    k => 0.85, m => 0.95, opts => 'horns="1" crystal="1"',
    back => '',
    decor => <<'E',
  <polygon class="c3" points="150,330 160,320 170,330 160,340"/>
  <polygon class="c3" points="240,334 250,324 260,334 250,344"/>
  <polygon class="c3" points="196,352 206,342 216,352 206,362"/>
  <polygon class="c5" points="190,300 200,290 210,300 200,312"/>
  <polygon class="c5" points="130,330 138,322 146,330 138,338"/>
  <polygon class="c5" points="262,330 270,322 278,330 270,338"/>
E
  },
  'shadow-orochi' => {
    name => 'Shadow Orochi', pal => ['#3A2A5A', '#5E4A8A', '#B8A8E0', '#0E0818', '#78F0D8'],
    k => 1.1, m => 1.0, wave => 22, opts => 'frill="1"',
    back => '',
    decor => <<'E',
  <polygon class="c5" points="140,300 130,268 160,296"/>
  <polygon class="c5" points="200,290 196,252 224,290"/>
  <polygon class="c5" points="256,300 270,268 280,306"/>
  <polygon class="c5" points="100,330 96,308 116,326"/>
  <polygon class="c5" points="304,330 310,308 318,328"/>
E
  },
  'jade-orochi' => {
    name => 'Jade Orochi', pal => ['#2A8A6A', '#5AC8A0', '#E0F8E8', '#0E3A2A', '#E8D040'],
    k => 1.0, m => 1.15, opts => 'horns="1"',
    back => '',
    decor => <<'E',
  <polygon class="c3" points="170,310 180,300 190,310 180,322"/>
  <polygon class="c3" points="224,306 234,296 244,306 234,318"/>
  <polygon class="c5" points="196,334 206,324 216,334 206,346"/>
  <polygon class="c5" points="140,330 148,322 156,330 148,338"/>
  <polygon class="c5" points="252,336 260,328 268,336 260,344"/>
E
  },
  'sleeping-orochi' => {
    name => 'Sleeping Orochi', pal => ['#4A8A9A', '#7AB8C0', '#E8F4F0', '#1A3A44', '#F0C870'],
    k => 1.1, m => 0.5, arch => 70, wave => 10, opts => 'frill="1"',
    back => '',
    decor => <<'E',
  <polygon class="c5" points="150,300 160,292 170,300 160,310"/>
  <polygon class="c5" points="240,304 250,296 260,304 250,314"/>
  <polygon class="c3" points="196,330 204,324 212,330 204,338"/>
E
  },
  'crystal-orochi' => {
    name => 'Crystal Orochi', pal => ['#6A5AA8', '#9A8AD8', '#E4DCFA', '#241A48', '#F070E0'],
    k => 1.2, m => 0.95, opts => 'crystal="1"',
    back => '',
    decor => <<'E',
  <polygon class="c5" points="130,300 116,250 154,292"/>
  <polygon class="c5" points="190,292 198,236 220,290"/>
  <polygon class="c5" points="250,300 276,256 280,306"/>
  <polygon class="c3" points="116,250 124,272 112,270"/>
  <polygon class="c3" points="198,236 206,260 194,258"/>
  <polygon class="c3" points="276,256 278,280 268,276"/>
E
  },
);

mkdir 'tools/src-orochi' unless -d 'tools/src-orochi';

for my $key (sort keys %V) {
  my $v = $V{$key};
  my ($k, $m) = ($v->{k}, $v->{m});
  my ($wave, $arch) = ($v->{wave} // 0, $v->{arch} // 0);
  my $ni = 0;
  my @p = @{ $v->{pal} };
  my $out = qq{<palette name="$v->{name}" c1="$p[0]" c2="$p[1]" c3="$p[2]" c4="$p[3]" c5="$p[4]"/>\n};
  $out .= $v->{back};
  for my $n (@NECKS) {
    my @pts;
    for my $i (0 .. 3) {
      my ($x, $y, $w) = @{ $n->[$i] };
      my $xx = $i == 0 ? 200 + ($x - 200) * (1 + ($k - 1) * 0.3) : 200 + ($x - 200) * $k;
      my $yy = $i == 0 ? $y : 290 - (290 - $y) * $m;
      if ($i == 1 || $i == 2) { $xx += $wave * (($ni % 2) ? 1 : -1) * ($i == 1 ? 1 : 0.7); }
      $yy += $arch if $i == 3;
      push @pts, sprintf('%d,%d,%d', $xx, $yy, $w);
    }
    $out .= qq{  <ribbon pts="@pts" cls="c1" top="c2" under="c3"/>\n};
    $ni++;
    my ($ax, $ay) = split /,/, $pts[2];
    my ($bx, $by) = split /,/, $pts[3];
    my $rot = sprintf('%d', atan2($by - $ay, $bx - $ax) * 180 / 3.14159265);
    $out .= qq{  <part name="serpentHead" at="$bx,$by" s="1.9" rot="$rot" $v->{opts}/>\n};
  }
  $out .= $MOUND . $v->{decor} . "</svg>\n";
  open my $fh, '>', "tools/src-orochi/$key.tpl" or die; print $fh $out; close $fh;
  print "$key\n";
}

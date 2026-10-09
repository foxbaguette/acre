# fx.pl - build a fantasy variant from an existing tpl: fx.pl base out palette-attrs before after
use strict; use Math::Trig;
sub halo { my($cx,$cy,$rx,$ry,$w,$c)=@_; my $o=''; my $n=16;
  for my $i (0..$n-1){ my @p; my ($a,$b)=(2*pi*$i/$n, 2*pi*($i+1)/$n);
    push @p, sprintf("%.0f,%.0f", $cx+$rx*cos($a), $cy+$ry*sin($a)), sprintf("%.0f,%.0f", $cx+$rx*cos($b), $cy+$ry*sin($b)),
             sprintf("%.0f,%.0f", $cx+($rx-$w)*cos($b), $cy+($ry-$w*0.5)*sin($b)), sprintf("%.0f,%.0f", $cx+($rx-$w)*cos($a), $cy+($ry-$w*0.5)*sin($a));
    $o .= "  <polygon class=\"$c\" points=\"".join(' ',@p)."\"/>\n"; } $o }
sub star { my($cx,$cy,$r,$c)=@_; my $q=$r*0.28; my @p=([$cx,$cy-$r],[$cx+$q,$cy-$q],[$cx+$r,$cy],[$cx+$q,$cy+$q],[$cx,$cy+$r],[$cx-$q,$cy+$q],[$cx-$r,$cy],[$cx-$q,$cy-$q]);
  "  <polygon class=\"$c\" points=\"".join(' ',map{sprintf("%.0f,%.0f",@$_)}@p)."\"/>\n" }
sub sun { my($cx,$cy,$r1,$r2,$n,$c)=@_; my $o=''; for my $i (0..$n-1){ my $a=2*pi*$i/$n; my $d=pi/$n*0.6;
  $o .= sprintf("  <polygon class=\"$c\" points=\"%.0f,%.0f %.0f,%.0f %.0f,%.0f\"/>\n", $cx+$r1*cos($a-$d),$cy+$r1*sin($a-$d), $cx+$r2*cos($a),$cy+$r2*sin($a), $cx+$r1*cos($a+$d),$cy+$r1*sin($a+$d)); } $o }
sub disc { my($cx,$cy,$r,$c)=@_; my @p; for my $i (0..15){ my $a=2*pi*$i/16; push @p, sprintf("%.0f,%.0f",$cx+$r*cos($a),$cy+$r*sin($a)); } "  <polygon class=\"$c\" points=\"".join(' ',@p)."\"/>\n" }
sub cloud { my($cx,$cy,$r,$c)=@_; disc($cx,$cy,$r,$c).disc($cx-$r*0.9,$cy+$r*0.25,$r*0.7,$c).disc($cx+$r*0.9,$cy+$r*0.25,$r*0.7,$c) }
sub wings { my($b1,$b2,$t1,$t2,$n,$c)=@_; "  <fan b=\"$b1 $b2\" t=\"$t1 $t2\" n=\"$n\" cls=\"$c\" shape=\"quad\"/>\n" }
sub crescent { my($cx,$cy,$R,$c)=@_; my (@o,@i); for (my $t=-90;$t<=90;$t+=22.5){ my $a=$t*pi/180; push @o,sprintf("%.0f,%.0f",$cx+$R*cos($a),$cy+$R*sin($a)); }
  for (my $t=90;$t>=-90;$t-=22.5){ my $a=$t*pi/180; push @i,sprintf("%.0f,%.0f",$cx+$R*0.42+$R*0.5*cos($a),$cy+$R*0.95*sin($a)); } "  <polygon class=\"$c\" points=\"".join(' ',@o,@i)."\"/>\n" }
sub build { my($base,$out,$pal,$before,$after)=@_;
  open I,"<$base" or die "$base"; my @l=<I>; close I; shift @l; my $end=pop @l; 
  open O,">$out"; print O "<palette $pal/>\n$before".join('',@l)."$after</svg>\n"; close O; }
1;

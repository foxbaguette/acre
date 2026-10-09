require "./tools/fx.pl";
my $o="tools/src-scifi";
sub P { my($n,@c)=@_; "name=\"$n\" c1=\"$c[0]\" c2=\"$c[1]\" c3=\"$c[2]\" c4=\"$c[3]\" c5=\"$c[4]\"" }
sub flames { my($x,$y,$n,$sp,$h,$w,$c)=@_; my $s=''; for my $i (0..$n-1){ my $bx=$x+$i*$sp; $s.=sprintf("  <polygon class=\"$c\" points=\"%d,%d %d,%d %d,%d\"/>\n",$bx-$w/2,$y,$bx+($i%2?4:-4),$y-$h*(0.8+0.2*($i%3)),$bx+$w/2,$y);} $s }
sub bar { my($x1,$y1,$x2,$y2,$c)=@_; "  <polygon class=\"$c\" points=\"$x1,$y1 $x2,$y1 $x2,$y2 $x1,$y2\"/>\n" }
build("tools/src-bone/grave-beetle.tpl","$o/mecha-beetle.tpl",P("Mecha beetle","#5A6A78","#8AA0B0","#D0E0E8","#14202A","#FF8A2A"),"",
  disc(168,252,5,"c5").disc(232,252,5,"c5").disc(200,330,6,"c5").bar(150,280,250,284,"c4"));
build("tools/src-carnivores/wolf.tpl","$o/cyber-wolf.tpl",P("Cyber wolf","#5A6672","#8896A4","#D8E4EC","#12181E","#40E0FF"),"",
  "  <polygon class=\"c5\" points=\"322,66 358,64 360,78 326,84\"/>\n".bar(190,236,250,244,"c5").disc(282,332,6,"c5").disc(124,332,6,"c5").disc(200,260,5,"c3"));
build("tools/src-scaly/orca.tpl","$o/space-whale.tpl",P("Space whale","#2A2E6A","#4A56A8","#E8E0FF","#0A0C28","#FF90E0"),"",
  halo(200,230,196,54,6,"c3").star(120,120,10,"c3").star(300,100,8,"c3").star(60,60,7,"c5").star(350,320,9,"c3").star(240,230,10,"c5").star(140,250,7,"c5"));
build("tools/src-carnivores/coyote.tpl","$o/glitch-fox.tpl",P("Glitch fox","#5A5A6A","#8A8AA0","#F0F0FF","#1A1A28","#FF3AD0"),"",
  bar(110,204,230,216,"c5").bar(220,246,310,256,"c3").bar(150,284,260,292,"c5").bar(60,262,110,270,"c3").bar(280,170,330,178,"c5"));
build("tools/src-carnivores/lynx.tpl","$o/robot-hound.tpl",P("Robot hound","#7A8896","#A8B8C8","#E8F0F8","#161C22","#FF8A2A"),"",
  "  <polygon class=\"c5\" points=\"262,146 288,148 288,164 264,166\"/>\n".disc(150,300,6,"c5").disc(220,330,6,"c5").bar(170,230,230,238,"c4"));
build("tools/src-birds/falcon.tpl","$o/drone-falcon.tpl",P("Drone falcon","#6A7A88","#94A8B8","#E8F0F4","#181E24","#FF5A3A"),
  "  <ribbon pts=\"190,92,3 170,50,4 150,20,3\" cls=\"c4\" top=\"c4\" under=\"c4\"/>\n  <ribbon pts=\"210,92,3 230,50,4 250,20,3\" cls=\"c4\" top=\"c4\" under=\"c4\"/>\n".flames(186,380,2,28,40,16,"c5"),"".disc(150,20,6,"c5").disc(250,20,6,"c5"));
build("tools/src-carnivores/jaguar.tpl","$o/void-cat.tpl",P("Void cat","#1A1A2E","#2E2E54","#D0D0FF","#08081A","#7A6AFF"),"",
  star(180,250,9,"c3").star(220,236,6,"c3").star(260,248,8,"c3").star(140,270,6,"c3").star(210,276,7,"c5").star(300,290,8,"c3").star(60,280,6,"c5"));
build("tools/src-scaly/monarch.tpl","$o/plasma-moth.tpl",P("Plasma moth","#3A2A8A","#6A5AD8","#F0F0FF","#10083A","#40F0FF"),"",
  bar(70,100,160,106,"c5").bar(60,140,130,146,"c5").bar(250,100,340,106,"c5").bar(270,140,340,146,"c5").disc(160,103,6,"c5").disc(240,103,6,"c5").bar(80,236,140,242,"c5").bar(260,236,320,242,"c5"));
build("tools/src-scaly/octopus.tpl","$o/quantum-squid.tpl",P("Quantum squid","#3A8A9A","#70C8D8","#E0FCFF","#0E3A44","#FF70C0"),
  halo(200,170,190,58,6,"c5").halo(200,170,140,40,5,"c3"),star(60,60,9,"c5").star(340,80,8,"c3"));
build("tools/src-scaly/manta-ray.tpl","$o/gravity-manta.tpl",P("Gravity manta","#3A3A5A","#5A5A8A","#E8E8FF","#12122A","#FFB040"),
  halo(200,230,196,52,5,"c5"), disc(40,200,10,"c5").disc(360,262,8,"c3"));
build("tools/src-scaly/mantis.tpl","$o/solar-mantis.tpl",P("Solar mantis","#B8902A","#E0C060","#FFF4C0","#3A2A08","#3A8AF0"),
  "  <polygon class=\"c5\" points=\"110,170 170,130 240,200 160,270\"/>\n  <polygon class=\"c4\" points=\"140,150 148,146 218,214 210,220\"/>\n  <polygon class=\"c4\" points=\"122,200 130,194 186,244 178,250\"/>\n","");
build("tools/src-bone/skull-raven.tpl","$o/cyborg-raven.tpl",P("Cyborg raven","#38404C","#5A6A7C","#B8C8D8","#0A0E14","#40FFB0"),"",
  bar(262,170,330,176,"c5"));
build("tools/src-carnivores/cougar.tpl","$o/rift-hound.tpl",P("Rift cougar","#C8B8E8","#E8DCFF","#FFFFFF","#3A2A5A","#FF60C0"),
  halo(250,240,76,150,10,"c5"),"");
build("tools/src-scaly/tortoise.tpl","$o/star-turtle.tpl",P("Star turtle","#3A3A7A","#6060B0","#D8D8FF","#12123A","#FFD060"),"",
  disc(150,230,14,"c5").disc(262,214,10,"c3").star(200,196,12,"c5").halo(200,240,100,22,4,"c3").star(130,180,7,"c3"));
build("tools/src-scaly/chameleon.tpl","$o/dune-chameleon.tpl",P("Dune chameleon","#D8A858","#F0CC88","#FFF0C8","#6A4A18","#E8582A"),"",
  flames(150,198,6,20,28,10,"c4"));

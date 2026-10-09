require "./tools/fx.pl";
my $o="tools/src-story";
sub P { my($n,@c)=@_; "name=\"$n\" c1=\"$c[0]\" c2=\"$c[1]\" c3=\"$c[2]\" c4=\"$c[3]\" c5=\"$c[4]\"" }
sub flames { my($x,$y,$n,$sp,$h,$w,$c)=@_; my $s=''; for my $i (0..$n-1){ my $bx=$x+$i*$sp; $s.=sprintf("  <polygon class=\"$c\" points=\"%d,%d %d,%d %d,%d\"/>\n",$bx-$w/2,$y,$bx+($i%2?4:-4),$y-$h*(0.8+0.2*($i%3)),$bx+$w/2,$y);} $s }
sub bar { my($x1,$y1,$x2,$y2,$c)=@_; "  <polygon class=\"$c\" points=\"$x1,$y1 $x2,$y1 $x2,$y2 $x1,$y2\"/>\n" }
sub shroom { my($x,$y,$w,$h)=@_; my $s=bar($x-$w/8,$y-$h*0.55,$x+$w/8,$y,"c3"); $s.=sprintf("  <polygon class=\"c5\" points=\"%d,%d %d,%d %d,%d %d,%d %d,%d\"/>\n",$x-$w/2,$y-$h*0.5,$x-$w/3,$y-$h,$x+$w/3,$y-$h,$x+$w/2,$y-$h*0.5,$x,$y-$h*0.42); $s.=disc($x-$w/5,$y-$h*0.75,$w/12,"c3").disc($x+$w/5,$y-$h*0.7,$w/14,"c3"); $s }
sub gear { my($cx,$cy,$r,$c)=@_; sun($cx,$cy,$r,$r+9,10,$c).disc($cx,$cy,$r,$c).disc($cx,$cy,$r*0.4,"c4") }
sub leaf { my($x,$y,$dx,$dy,$c)=@_; sprintf("  <polygon class=\"$c\" points=\"%d,%d %d,%d %d,%d %d,%d\"/>\n",$x,$y,$x+$dx*0.4-$dy*0.25,$y+$dy*0.4+$dx*0.25,$x+$dx,$y+$dy,$x+$dx*0.4+$dy*0.25,$y+$dy*0.4-$dx*0.25) }
build("tools/src-hoofed/elk.tpl","$o/mushroom-stag.tpl",P("Mushroom stag","#8A6A4A","#B08A62","#F0E4C8","#4A3420","#D8483A"),"",
  shroom(190,210,40,44).shroom(150,214,26,30).shroom(232,206,30,34).shroom(268,150,18,22));
build("tools/src-critters/../src-carnivores/brown-bear.tpl","$o/golem-bear.tpl",P("Golem bear","#7A8A80","#9AAA9E","#C8D4C8","#2A342E","#6AD890"),"",
  "  <polygon class=\"c5\" points=\"120,210 160,190 190,210 150,236\"/>\n  <polygon class=\"c5\" points=\"214,190 250,180 270,204 236,214\"/>\n".flames(130,200,5,28,30,12,"c4"));
build("tools/src-hoofed/yak.tpl","$o/storm-yak.tpl",P("Storm yak","#3A4468","#5A6694","#C8D0E8","#12162A","#FFE070"),"",
  cloud(160,170,26,"c3").cloud(240,160,24,"c3").cloud(210,196,20,"c2").bar(150,200,154,230,"c5").bar(236,196,240,224,"c5"));
build("tools/src-critters/sloth.tpl","$o/plant-sloth.tpl",P("Plant sloth","#6A8A5A","#8AAA70","#D8E8B8","#2A3A22","#F06AA0"),"",
  leaf(260,150,20,-50,"c2").leaf(280,130,30,-40,"c1").leaf(240,170,-30,-40,"c2").disc(300,90,8,"c5").disc(290,100,6,"c5").leaf(180,220,-34,-30,"c1").disc(150,184,7,"c5"));
build("tools/src-critters/armadillo.tpl","$o/crystal-armadillo.tpl",P("Crystal armadillo","#6A5AA8","#9A88D8","#E8E0FF","#241A50","#60F0F0"),"",
  flames(120,214,8,24,44,16,"c5"));
build("tools/src-critters/hare.tpl","$o/wind-hare.tpl",P("Wind hare","#C8E0F0","#E8F4FF","#FFFFFF","#5A7A9A","#80D0F0"),
  "  <ribbon pts=\"20,150,3 80,130,10 140,160,12 200,130,3\" cls=\"c5\" top=\"c5\" under=\"c5\"/>\n  <ribbon pts=\"40,330,3 110,300,10 190,330,12 270,296,3\" cls=\"c5\" top=\"c5\" under=\"c5\"/>\n","");
build("tools/src-hoofed/elephant.tpl","$o/glacier-elephant.tpl",P("Glacier elephant","#8AB0D0","#B8D8F0","#F0FAFF","#2A4A6A","#60C8F0"),"",
  flames(120,170,6,28,46,18,"c5")."  <polygon class=\"c2\" points=\"340,214 366,250 396,300 380,310 350,262 330,230\"/>\n");
build("tools/src-scaly/frog.tpl","$o/moss-toad.tpl",P("Moss toad","#5A7A3A","#7AA04E","#D8E8A0","#1E2E12","#E8683A"),"",
  shroom(170,240,36,40).shroom(214,238,22,26).leaf(120,270,-30,-24,"c2").leaf(260,250,30,-30,"c2"));
build("tools/src-hoofed/elk.tpl","$o/coral-stag.tpl",P("Coral stag","#D07A6A","#F0A090","#FFD0C0","#7A3A30","#40C8C0"),"",
  disc(190,230,10,"c5").disc(160,260,8,"c5").disc(240,240,9,"c5").disc(220,270,7,"c5").star(300,40,9,"c5"));
build("tools/src-birds/falcon.tpl","$o/storm-hawk.tpl",P("Storm hawk","#4A5470","#6E7A9C","#E0E4F0","#141828","#FFE070"),
  cloud(60,300,30,"c3").cloud(340,300,28,"c3"), "");
build("tools/src-carnivores/badger.tpl","$o/honey-badger.tpl",P("Honey badger","#8A6A2A","#C8A040","#FFF4C8","#2A1E08","#FFD030"),"",
  "  <polygon class=\"c5\" points=\"160,300 184,288 208,300 208,328 184,340 160,328\"/>\n  <polygon class=\"c5\" points=\"214,300 238,288 262,300 262,328 238,340 214,328\"/>\n  <polygon class=\"c4\" points=\"176,310 184,306 192,310 192,320 184,324 176,320\"/>\n");
build("tools/src-hoofed/tapir.tpl","$o/dream-tapir.tpl",P("Dream tapir","#6A5AA0","#9A8ADA","#F0E8FF","#241A50","#FFE080"),
  crescent(80,120,70,"c5"),star(180,250,8,"c5").star(240,270,6,"c5").star(300,230,7,"c5").star(130,300,6,"c3"));
build("tools/src-carnivores/cougar.tpl","$o/patchwork-cat.tpl",P("Patchwork cat","#C8A878","#E8D0A0","#F4EAD8","#4A3A28","#E85A5A"),"",
  "  <polygon class=\"c5\" points=\"150,250 190,240 196,274 156,282\"/>\n  <polygon class=\"c3\" points=\"220,236 262,240 258,276 224,272\"/>\n".bar(150,250,196,252,"c4").bar(190,238,194,276,"c4").bar(222,236,260,238,"c4").bar(256,238,260,276,"c4"));
build("tools/src-carnivores/lion.tpl","$o/tide-lion.tpl",P("Tide lion","#4AA8C0","#80D0E0","#F0FCFF","#1A5A78","#F0A0C0"),"",
  "  <polygon class=\"c5\" points=\"270,120 286,96 302,124\"/>\n  <polygon class=\"c5\" points=\"380,150 396,126 394,162\"/>\n  <polygon class=\"c5\" points=\"270,236 290,236 280,260\"/>\n".star(200,240,10,"c3"));
build("tools/src-scaly/python.tpl","$o/feather-snake.tpl",P("Feather snake","#2A9A6A","#58D090","#F0FFE0","#0E3A24","#F0504A"),
  wings("286,150","300,190","330,40","396,70",6,"c5 c1")."","");
build("tools/src-hoofed/gazelle.tpl","$o/petal-gazelle.tpl",P("Petal gazelle","#F0A8B8","#F8C8D0","#FFF0F2","#A05068","#FFD870"),"",
  disc(190,230,9,"c5").disc(150,260,7,"c5").disc(236,240,8,"c5").disc(318,100,6,"c5").disc(300,60,7,"c5").disc(330,70,5,"c5"));
build("tools/src-critters/bat.tpl","$o/spore-bat.tpl",P("Spore bat","#6A5A7A","#9A88AA","#E8DCF0","#241A30","#80F0A0"),"",
  disc(60,200,8,"c5").disc(340,200,8,"c5").disc(100,300,6,"c5").disc(300,310,7,"c5").disc(200,60,6,"c5"));
build("tools/src-birds/../src-bone/revenant-owl.tpl","$o/clockwork-owl.tpl",P("Clockwork owl","#B8902A","#E0C060","#FFF0B8","#3A2A08","#C85A2A"),"",
  gear(200,270,26,"c5").gear(150,230,14,"c2").gear(250,230,14,"c2"));
build("tools/src-scaly/scorpion.tpl","$o/glass-scorpion.tpl",P("Glass scorpion","#60C8D8","#A0F0F8","#F0FFFF","#1A5868","#FF6AB0"),"",
  disc(200,246,9,"c5").disc(200,276,7,"c5"));
build("tools/src-wild/wyvern.tpl","$o/frost-wyvern.tpl",P("Frost wyvern","#7AB0D8","#B0DCF4","#F0FAFF","#1E3A58","#60F0FF"),"",
  flames(150,106,5,22,34,12,"c5"));

require "./tools/fx.pl";
my $o="tools/src-infernal";
sub P { my($n,@c)=@_; "name=\"$n\" c1=\"$c[0]\" c2=\"$c[1]\" c3=\"$c[2]\" c4=\"$c[3]\" c5=\"$c[4]\"" }
sub flames { my($x,$y,$n,$sp,$h,$w,$c)=@_; my $s=''; for my $i (0..$n-1){ my $bx=$x+$i*$sp; $s.=sprintf("  <polygon class=\"$c\" points=\"%d,%d %d,%d %d,%d\"/>\n",$bx-$w/2,$y,$bx+($i%2?4:-4),$y-$h*(0.8+0.2*($i%3)),$bx+$w/2,$y);} $s }
sub skull { my($x,$y,$c1,$c2)=@_; sprintf("  <polygon class=\"$c1\" points=\"%d,%d %d,%d %d,%d %d,%d %d,%d %d,%d\"/>\n  <polygon class=\"$c2\" points=\"%d,%d %d,%d %d,%d %d,%d\"/>\n  <polygon class=\"$c2\" points=\"%d,%d %d,%d %d,%d %d,%d\"/>\n",
  $x-14,$y-18,$x+14,$y-18,$x+18,$y+4,$x+6,$y+16,$x-6,$y+16,$x-18,$y+4, $x-10,$y-6,$x-3,$y-6,$x-3,$y+3,$x-10,$y+3, $x+3,$y-6,$x+10,$y-6,$x+10,$y+3,$x+3,$y+3) }
build("tools/src-carnivores/wolf.tpl","$o/cinder-wolf.tpl",P("Cinder wolf","#3A3032","#5C4A4C","#C8B8A8","#140E10","#FF6A20"),"",
  flames(170,214,6,18,44,14,"c5").flames(34,300,3,8,30,12,"c5"));
build("tools/src-hoofed/rhino.tpl","$o/brimstone-rhino.tpl",P("Brimstone rhino","#4A3A38","#6E5A56","#C8B8A8","#1A1210","#FF6A20"),"",
  flames(120,190,8,24,40,14,"c5")."  <polygon class=\"c5\" points=\"150,230 170,226 180,262 160,266\"/>\n  <polygon class=\"c5\" points=\"220,236 240,230 250,270 230,274\"/>\n");
build("tools/src-birds/vulture.tpl","$o/ash-vulture.tpl",P("Ash vulture","#3A3836","#5A5654","#D0C8C0","#141210","#FF7A2A"),"",
  flames(76,392,4,18,36,12,"c5"));
build("tools/src-scaly/tortoise.tpl","$o/magma-tortoise.tpl",P("Magma tortoise","#4A3A32","#6E5848","#C8A888","#181210","#FF5A1A"),"",
  "  <polygon class=\"c1\" points=\"140,176 200,80 262,176\"/>\n  <polygon class=\"c2\" points=\"200,80 262,176 220,176\"/>\n  <polygon class=\"c5\" points=\"188,92 212,92 218,108 182,108\"/>\n  <polygon class=\"c5\" points=\"196,108 206,108 214,176 192,176\"/>\n".flames(186,92,3,14,34,12,"c5"));
build("tools/src-hoofed/bison.tpl","$o/inferno-bull.tpl",P("Inferno bull","#6A2A22","#92402E","#E8B890","#1A0C08","#FF7A1A"),"",
  flames(170,168,6,20,44,16,"c5"));
build("tools/src-scaly/scorpion.tpl","$o/tormentor-scorpion.tpl",P("Tormentor scorpion","#8A2A2A","#B84A3A","#F0C8A0","#2A0E0E","#FFB020"),
  "  <ribbon pts=\"200,260,28 180,320,22 150,360,16 100,372,12 70,340,8 66,300,6\" cls=\"c1\" top=\"c2\" under=\"c4\"/>\n  <polygon class=\"c5\" points=\"66,300 44,276 76,282\"/>\n  <polygon class=\"c4\" points=\"66,300 58,330 78,318\"/>\n","");
build("tools/src-scaly/monarch.tpl","$o/hell-moth.tpl",P("Hell moth","#3A1A28","#6A2A3A","#F8E8D0","#0E0608","#FF6A2A"),"",
  skull(84,132,"c3","c4").skull(316,132,"c3","c4").skull(70,232,"c3","c4").skull(330,232,"c3","c4"));
build("tools/src-critters/porcupine.tpl","$o/plague-porcupine.tpl",P("Plague porcupine","#5A6A3A","#7E9050","#E8E4A0","#1E2410","#D8E840"),"",
  disc(150,262,9,"c5").disc(204,232,8,"c5").disc(246,264,10,"c5").disc(112,296,7,"c5").disc(272,246,6,"c5"));
build("tools/src-carnivores/lynx.tpl","$o/cursed-cat.tpl",P("Cursed cat","#2A2430","#483E54","#D8D0E0","#0E0A12","#A050F0"),
  "  <ribbon pts=\"146,350,12 100,376,16 56,360,10 46,320,5\" cls=\"c1\" top=\"c2\" under=\"c4\"/>\n  <ribbon pts=\"140,346,10 110,392,14 76,396,8\" cls=\"c1\" top=\"c2\" under=\"c4\"/>\n",
  flames(46,326,3,10,28,10,"c5"));
build("tools/src-carnivores/leopard.tpl","$o/shadow-panther.tpl",P("Shadow panther","#2A2A44","#444466","#8A8AC0","#0C0C18","#7A5AF0"),"",
  "  <polygon class=\"c5\" points=\"322,206 332,170 342,204\"/>\n  <polygon class=\"c5\" points=\"346,198 360,164 366,202\"/>\n".flames(110,226,6,26,34,12,"c5"));
build("tools/src-scaly/clownfish.tpl","$o/abyss-angler.tpl",P("Abyss angler","#1E3A5A","#3A648A","#8AB8D8","#0A1428","#FFE060"),
  "  <ribbon pts=\"250,120,7 290,50,7 346,34,6 372,76,3\" cls=\"c4\" top=\"c4\" under=\"c4\"/>\n".disc(372,92,18,"c3").disc(372,92,11,"c5"),"");
build("tools/src-bone/femur-spider.tpl","$o/void-spider.tpl",P("Void spider","#2A1A44","#4A2E70","#8A5AC0","#0A0614","#FF50A0"),"",
  star(120,60,12,"c5").star(290,70,9,"c5").star(60,330,8,"c5"));
build("tools/src-birds/heron.tpl","$o/nightmare-heron.tpl",P("Nightmare heron","#4A3A68","#6E5A90","#D8D0E8","#140E20","#FF6A50"),"",
  flames(282,86,4,10,34,9,"c5"));
build("tools/src-hoofed/boar.tpl","$o/blood-boar.tpl",P("Blood boar","#6A2428","#922E34","#E8D0B0","#1E0A0C","#FF4A3A"),"",
  flames(120,214,8,18,36,12,"c4"));
build("tools/src-scaly/../src-heaven/../src-hoofed/../src-scaly/../../tools/src-heaven/halo-stag.tpl","$o/_tmp.tpl",P("x","#000","#000","#000","#000","#000"),"","") if 0;
build("tools/src-scaly/../src-hoofed/../src-carnivores/../../tools/src-heaven/solar-lizard.tpl","$o/_tmp.tpl",P("x","#000","#000","#000","#000","#000"),"","") if 0;
build("tools/src-hoofed/yak.tpl","$o/pit-yak.tpl",P("Pit yak","#3A1A1A","#5A2A2A","#C8A890","#120808","#FF4A2A"),"",flames(120,214,8,22,38,13,"c5"));
build("tools/src-hoofed/elk.tpl","$o/thorn-elk.tpl",P("Thorn elk","#3A3A2A","#5A5A3E","#C8C0A0","#14140C","#E04A4A"),"",
  flames(130,204,6,22,30,10,"c5"));
build("tools/src-hoofed/gazelle.tpl","$o/obsidian-gazelle.tpl",P("Obsidian gazelle","#1E1E2A","#3A3A52","#8A8AB0","#08080E","#FF3A5A"),"",
  flames(130,200,6,22,36,12,"c5"));
build("tools/src-critters/gorilla.tpl","$o/ember-gorilla.tpl",P("Ember gorilla","#4A3A38","#6E5854","#B8A090","#181010","#FF6A20"),"",
  flames(312,120,4,14,38,10,"c5")."  <polygon class=\"c5\" points=\"180,260 192,254 200,290 188,296\"/>\n  <polygon class=\"c5\" points=\"228,240 240,236 246,268 234,272\"/>\n");
build("tools/src-carnivores/hyena.tpl","$o/cinder-hyena.tpl",P("Cinder hyena","#3A3030","#5C4A48","#C8B0A0","#140E0E","#FF7A2A"),"",
  flames(240,196,4,16,44,14,"c5").flames(44,278,3,8,26,10,"c5"));

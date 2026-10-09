require "./tools/fx.pl";
my $o="tools/src-heaven";
sub P { my($n,@c)=@_; "name=\"$n\" c1=\"$c[0]\" c2=\"$c[1]\" c3=\"$c[2]\" c4=\"$c[3]\" c5=\"$c[4]\"" }
build("tools/src-carnivores/lion.tpl","$o/seraph-lion.tpl",P("Seraph lion","#F4E4B0","#FFF6D8","#FFFFFF","#C89A3A","#FFD84A"),
  wings("160,196","240,190","70,30","330,10",8,"c3 c2"), halo(336,82,46,13,7,"c5"));
build("tools/src-hoofed/elk.tpl","$o/halo-stag.tpl",P("Halo stag","#E8F0FA","#FFFFFF","#FFFFFF","#7A9AC8","#FFE08A"),
  "", halo(334,64,44,15,7,"c5").star(260,200,8,"c5").star(180,230,6,"c5"));
build("tools/src-scaly/orca.tpl","$o/cloud-whale.tpl",P("Cloud whale","#F0F4FA","#FFFFFF","#D8E4F4","#8AA8D0","#FFD870"),
  cloud(110,170,26,"c3").cloud(300,330,24,"c3"), cloud(170,176,24,"c2").cloud(250,170,26,"c2").star(210,250,10,"c5").star(120,250,7,"c5"));
build("tools/src-carnivores/fennec-fox.tpl","$o/star-fox.tpl",P("Star fox","#4A5AA8","#7A8ADC","#F0F0FF","#1A2050","#FFE060"),
  star(60,300,34,"c5"), star(210,300,12,"c5").star(260,330,9,"c5").star(176,392,8,"c5").star(238,100,10,"c5"));
build("tools/src-carnivores/wolf.tpl","$o/aurora-wolf.tpl",P("Aurora wolf","#6AC8C0","#A0F0E0","#F0FFFA","#2A5A78","#B07AF0"),
  "  <ribbon pts=\"20,40,3 70,100,18 130,80,20 190,140,16 250,170,4\" cls=\"c5\" top=\"c5\" under=\"c5\"/>\n", star(380,40,10,"c3").star(30,300,9,"c3"));
build("tools/src-carnivores/coyote.tpl","$o/angel-hound.tpl",P("Angel hound","#F4EAD8","#FFFFFF","#FFFFFF","#C8A878","#FFD870"),
  wings("170,206","230,208","50,60","300,50",7,"c3 c2"), halo(322,122,34,11,6,"c5"));
build("tools/src-hoofed/horse.tpl","$o/comet-horse.tpl",P("Comet horse","#E8F0FF","#FFFFFF","#FFFFFF","#5A6AD0","#FFD060"),
  "", "  <polygon class=\"c5\" points=\"338,74 354,14 362,80\"/>\n".star(300,60,10,"c5").star(60,100,12,"c5"));
build("tools/src-birds/peacock.tpl","$o/aurora-peacock.tpl",P("Aurora peacock","#3AC8C0","#8AF0E0","#F8FFF8","#5A2A9A","#7A5AF0"),
  "", halo(200,56,36,11,5,"c2"));
build("tools/src-birds/swan.tpl","$o/choir-swan.tpl",P("Choir swan","#FFFFFF","#FFF6E0","#E8E0F0","#8A7AA8","#FFD050"),
  wings("140,230","200,240","40,60","230,30",6,"c1 c3"), halo(340,38,34,10,5,"c5"));
build("tools/src-birds/bald-eagle.tpl","$o/sun-eagle.tpl",P("Sun eagle","#C8782A","#F0A848","#FFF4D0","#6A3A10","#FFE060"),
  sun(200,150,110,200,16,"c5").disc(200,150,104,"c2"), "");
build("tools/src-hoofed/bighorn-sheep.tpl","$o/golden-ram.tpl",P("Golden ram","#E8C050","#FFE080","#FFF4C8","#8A5A18","#FFFFFF"),
  "", halo(332,92,40,12,6,"c5").star(200,262,14,"c5").star(150,246,9,"c5"));
build("tools/src-critters/hare.tpl","$o/moon-hare.tpl",P("Moon hare","#D8DCF0","#F0F2FF","#FFFFFF","#5A62A0","#FFE890"),
  crescent(190,200,190,"c5"), star(380,60,10,"c5").star(40,70,8,"c5"));
build("tools/src-birds/cardinal.tpl","$o/pearl-dove.tpl",P("Pearl dove","#F8F8FF","#FFFFFF","#E8E8F8","#9AA8C8","#FFD880"),
  "", halo(284,82,30,9,5,"c5"));
build("tools/src-scaly/clownfish.tpl","$o/radiant-koi.tpl",P("Radiant koi","#F8F0E8","#FFFFFF","#F07848","#E84A38","#FFD860"),
  "", star(200,60,12,"c5").star(100,100,8,"c5").star(300,360,9,"c5"));
build("tools/src-hoofed/elephant.tpl","$o/nimbus-elephant.tpl",P("Nimbus elephant","#E8F0FA","#FFFFFF","#FFF4D0","#8AA8CC","#F8D0D8"),
  cloud(110,376,26,"c2").cloud(250,380,28,"c2").cloud(340,376,24,"c2"), halo(350,96,38,12,6,"c3"));
build("tools/src-carnivores/tiger.tpl","$o/gilded-tiger.tpl",P("Gilded tiger","#F0C850","#FFE890","#FFF8E0","#8A5A10","#FFFFFF"),
  "", halo(342,196,36,11,6,"c5"));
build("tools/src-carnivores/brown-bear.tpl","$o/cherub-bear.tpl",P("Cherub bear","#F0D0B0","#FFE8D0","#FFF8F0","#B88A60","#FFD870"),
  wings("150,172","220,166","90,50","260,40",5,"c3 c2"), halo(340,152,34,10,6,"c5"));
build("tools/src-scaly/komodo-dragon.tpl","$o/solar-lizard.tpl",P("Solar lizard","#E89A30","#FFC860","#FFF2C0","#8A4A10","#FF6A30"),
  sun(250,270,70,150,18,"c5").disc(250,270,64,"c2"), "");
build("tools/src-bone/femur-spider.tpl","$o/light-spider.tpl",P("Light spider","#F0F4FF","#FFFFFF","#C8D4F0","#5A6AA8","#FFE060"),
  "", halo(200,150,36,10,5,"c5"));
build("tools/src-scaly/python.tpl","$o/celestial-serpent.tpl",P("Celestial serpent","#3A3A8A","#6A6ADA","#E8E8FF","#14143A","#FFE060"),
  "", star(90,380,9,"c5").star(190,380,9,"c5").star(290,364,9,"c5").star(330,314,9,"c5").star(280,264,9,"c5").star(172,258,9,"c5").star(122,208,9,"c5").star(176,164,9,"c5"));

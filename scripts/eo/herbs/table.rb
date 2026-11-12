# frozen_string_literal: true

module EO
  # Herbs and the healing done with them: what each herb cures and where it
  # is sold, which herb a wound wants, the herb sack, the doses left in each
  # item, buying and stocking. From eherbs 2.3.0; line numbers in comments
  # refer to it.
  module Herbs
    # Every herb the scripts know: where it is sold (as the map names the
    # location; "Do Not Buy" for the bulk forms, "Forageable", "Skinnable"
    # and "Alchemical" for what no shop sells), its name as the game says
    # it, the wound type it cures, the short name a shop menu uses, and the
    # doses a shop-bought one holds. eherbs known_herbs.
    module Table
      module_function

      KNOWN = [
        # Wehnimer's Landing 325/1028
        # Solhaven 5722/4740011
        # Northern Caravanasary 9276/4746124
        # Ta'Illistim 640/13104200
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'some acantha leaf', type: 'blood', short_name: 'some acantha leaf', store_doses: 10 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'some wolifrew lichen', type: 'minor nerve wound', short_name: 'some wolifrew lichen',  store_doses: 4 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'bolmara potion',       type: 'major nerve wound', short_name: 'bolmara potion',        store_doses: 4 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'some woth flower',     type: 'major nerve scar',  short_name: 'some woth flower',      store_doses: 2 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'some torban leaf',     type: 'minor nerve scar',  short_name: 'some torban leaf',      store_doses: 3 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'some ambrominas leaf', type: 'minor limb wound',  short_name: 'some ambrominas leaf',  store_doses: 4 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'some ephlox moss',     type: 'major limb wound',  short_name: 'some ephlox moss',      store_doses: 4 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'some cactacae spine',  type: 'minor limb scar',   short_name: 'some cactacae spine',   store_doses: 4 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'some calamia fruit',   type: 'major limb scar',   short_name: 'some calamia fruit',    store_doses: 2 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim"],                             name: 'rose-marrow potion',   type: 'minor head wound',  short_name: 'rose-marrow potion',    store_doses: 4 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'some aloeas stem',     type: 'major head wound',  short_name: 'some aloeas stem',      store_doses: 2 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'some haphip root',     type: 'minor head scar',   short_name: 'some haphip root',      store_doses: 4 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'brostheras potion',    type: 'major head scar',   short_name: 'brostheras potion',     store_doses: 2 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'some basal moss',      type: 'minor organ wound', short_name: 'some basal moss',       store_doses: 4 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'some pothinir grass',  type: 'major organ wound', short_name: 'some pothinir grass',   store_doses: 2 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'talneo potion',        type: 'minor organ scar',  short_name: 'talneo potion',         store_doses: 4 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'wingstem potion',      type: 'major organ scar',  short_name: 'wingstem potion',       store_doses: 2 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'bur-clover potion',    type: 'missing eye',       short_name: 'bur-clover potion',     store_doses: 1 },
        { location: ["the town of Wehnimer's Landing", 'the free port of Solhaven', 'the Northern Caravansary', "Ta'Illistim", "the town of River's Rest"], name: 'some sovyn clove',     type: 'severed limb',      short_name: 'some sovyn clove',      store_doses: 1 },

        # Solhaven 5722/474011
        { location: ['Do Not Buy'], name: 'bunch of acantha leaf',    type: 'blood',             short_name: 'bunch of acantha leaf',     store_doses: 50 },
        { location: ['Do Not Buy'], name: 'bunch of wolifrew lichen', type: 'minor nerve wound', short_name: 'bunch of wolifrew lichen',  store_doses: 50 },
        { location: ['Do Not Buy'], name: 'large bolmara potion',     type: 'major nerve wound', short_name: 'large bolmara potion',      store_doses: 7 },
        { location: ['Do Not Buy'], name: 'bunch of woth flower',     type: 'major nerve scar',  short_name: 'bunch of woth flower',      store_doses: 50 },
        { location: ['Do Not Buy'], name: 'bunch of torban leaf',     type: 'minor nerve scar',  short_name: 'bunch of torban leaf',      store_doses: 50 },
        { location: ['Do Not Buy'], name: 'bunch of ambrominas leaf', type: 'minor limb wound',  short_name: 'bunch of ambrominas leaf',  store_doses: 50 },
        { location: ['Do Not Buy'], name: 'bunch of ephlox moss',     type: 'major limb wound',  short_name: 'bunch of ephlox moss',      store_doses: 50 },
        { location: ['Do Not Buy'], name: 'bunch of cactacae spine',  type: 'minor limb scar',   short_name: 'bunch of cactacae spine',   store_doses: 50 },
        { location: ['Do Not Buy'], name: 'bunch of calamia fruit',   type: 'major limb scar',   short_name: 'bunch of calamia fruit',    store_doses: 50 },
        { location: ['Do Not Buy'], name: 'large rose-marrow potion', type: 'minor head wound',  short_name: 'large rose-marrow potion',  store_doses: 7 },
        { location: ['Do Not Buy'], name: 'bunch of aloeas stem',     type: 'major head wound',  short_name: 'bunch of aloeas stem',      store_doses: 50 },
        { location: ['Do Not Buy'], name: 'bunch of haphip root',     type: 'minor head scar',   short_name: 'bunch of haphip root',      store_doses: 50 },
        { location: ['Do Not Buy'], name: 'large brostheras potion',  type: 'major head scar',   short_name: 'large brostheras potion',   store_doses: 7 },
        { location: ['Do Not Buy'], name: 'bunch of basal moss',      type: 'minor organ wound', short_name: 'bunch of basal moss',       store_doses: 50 },
        { location: ['Do Not Buy'], name: 'bunch of pothinir grass',  type: 'major organ wound', short_name: 'bunch of pothinir grass',   store_doses: 50 },
        { location: ['Do Not Buy'], name: 'large talneo potion',      type: 'minor organ scar',  short_name: 'large large talneo potion', store_doses: 7 },
        { location: ['Do Not Buy'], name: 'large wingstem potion',    type: 'major organ scar',  short_name: 'large wingstem potion',     store_doses: 7 },
        { location: ['Do Not Buy'], name: 'large bur-clover potion',  type: 'missing eye',       short_name: 'large bur-clover potion',   store_doses: 7 },
        { location: ['Do Not Buy'], name: 'bunch of sovyn clove',     type: 'severed limb',      short_name: 'bunch of sovyn clove',      store_doses: 50 },

        # Ta'Vaalor 10396/14103400
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of acantha',     type: 'blood',              short_name: 'tincture of acantha',     store_doses: 10 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of ambrominas',  type: 'minor limb wound',   short_name: 'tincture of ambrominas',  store_doses: 4 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of wolifrew',    type: 'minor nerve wound',  short_name: 'tincture of wolifrew',    store_doses: 4 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of rose-marrow', type: 'minor head wound',   short_name: 'tincture of rose-marrow', store_doses: 4 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of basal',       type: 'minor organ wound',  short_name: 'tincture of basal',       store_doses: 4 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of ephlox',      type: 'major limb wound',   short_name: 'tincture of ephlox',      store_doses: 4 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of bolmara',     type: 'major nerve wound',  short_name: 'tincture of bolmara',     store_doses: 4 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of aloeas',      type: 'major head wound',   short_name: 'tincture of aloeas',      store_doses: 2 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of pothinir',    type: 'major organ wound',  short_name: 'tincture of pothinir',    store_doses: 2 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of cactacae',    type: 'minor limb scar',    short_name: 'tincture of cactacae',    store_doses: 4 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of torban',      type: 'minor nerve scar',   short_name: 'tincture of torban',      store_doses: 3 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of haphip',      type: 'minor head scar',    short_name: 'tincture of haphip',      store_doses: 4 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of talneo',      type: 'minor organ scar',   short_name: 'tincture of talneo',      store_doses: 4 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of calamia',     type: 'major limb scar',    short_name: 'tincture of calamia',     store_doses: 2 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of woth',        type: 'major nerve scar',   short_name: 'tincture of woth',        store_doses: 2 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of brostheras',  type: 'major head scar',    short_name: 'tincture of brostheras',  store_doses: 2 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of wingstem',    type: 'major organ scar',   short_name: 'tincture of wingstem',    store_doses: 2 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of bur-clover',  type: 'missing eye',        short_name: 'tincture of bur-clover',  store_doses: 1 },
        { location: ["the city of Ta'Vaalor"],   name: 'tincture of sovyn',       type: 'severed limb',       short_name: 'tincture of sovyn',       store_doses: 1 },

        # Zul Logoth 9505/13010004
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'grey mushroom potion',    type: 'blood',              short_name: 'grey mushroom potion',     store_doses: 7 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'green mushroom potion',   type: 'blood',              short_name: 'green mushroom potion',    store_doses: 5 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'bubbling brown ale',      type: 'minor limb wound',   short_name: 'bubbling brown ale',       store_doses: 3 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'thick foggy ale',         type: 'minor nerve wound',  short_name: 'thick foggy ale',          store_doses: 3 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'rusty red ale',           type: 'minor head wound',   short_name: 'rusty red ale',            store_doses: 3 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'chunky black ale',        type: 'minor organ wound',  short_name: 'chunky black ale',         store_doses: 3 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'crushed cavegrass tea',   type: 'major limb wound',   short_name: 'crushed cavegrass tea',    store_doses: 2 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'glowing mold tea',        type: 'major nerve wound',  short_name: 'glowing mold tea',         store_doses: 2 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'sticky lichen tea',       type: 'major head wound',   short_name: 'sticky lichen tea',        store_doses: 2 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'roasted ratweed tea',     type: 'major organ wound',  short_name: 'roasted ratweed tea',      store_doses: 2 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'spotted toadstool ale',   type: 'minor limb scar',    short_name: 'spotted toadstool ale',    store_doses: 2 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'dark frothing ale',       type: 'minor nerve scar',   short_name: 'dark frothing ale',        store_doses: 2 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'dull crimson ale',        type: 'minor head scar',    short_name: 'dull crimson ale',         store_doses: 2 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'brown weedroot ale',      type: 'minor organ scar',   short_name: 'brown weedroot ale',       store_doses: 2 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'stalactite brew',         type: 'major limb scar',    short_name: 'stalactite brew',          store_doses: 2 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'stalagmite brew',         type: 'major nerve scar',   short_name: 'stalagmite brew',          store_doses: 2 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'stone soot brew',         type: 'major head scar',    short_name: 'stone soot brew',          store_doses: 2 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'dirty crevice brew',      type: 'major organ scar',   short_name: 'dirty crevice brew',       store_doses: 2 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'dirty rat fur potion',    type: 'missing eye',        short_name: 'dirty rat fur potion',     store_doses: 1 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'grainy black potion',     type: 'severed limb',       short_name: 'grainy black potion',      store_doses: 1 },
        { location: ['Zul Logoth', 'the tunnels and caverns of Zul Logoth'],     name: 'milky white potion',      type: 'lifekeep',           short_name: 'milky white potion',       store_doses: 3 },

        # Cysaegir 4647/14051034
        # Ravelin 13943/14201010
        # Sylvarraend 13137/13051014 NOTE-  the Lich location for Sylvarraend is "Ta'Illistim", but the tincture values match Cesaegir values, not the ones from Herablist2 in TI.
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of acantha',      type: 'blood',             short_name: 'tincture of acantha',           store_doses: 10 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of ambrominas',   type: 'minor limb wound',  short_name: 'tincture of ambrominas',        store_doses: 4 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of wolifrew',     type: 'minor nerve wound', short_name: 'tincture of wolifrew',          store_doses: 4 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of rose-marrow',  type: 'minor head wound',  short_name: 'tincture of rose-marrow',       store_doses: 4 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of basal',        type: 'minor organ wound', short_name: 'tincture of basal',             store_doses: 4 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of ephlox',       type: 'major limb wound',  short_name: 'tincture of ephlox',            store_doses: 4 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of bolmara',      type: 'major nerve wound', short_name: 'tincture of bolmara',           store_doses: 4 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of aloeas',       type: 'major head wound',  short_name: 'tincture of aloeas',            store_doses: 2 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of pothinir',     type: 'major organ wound', short_name: 'tincture of pothinir',          store_doses: 2 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of cactacae',     type: 'minor limb scar',   short_name: 'tincture of cactacae',          store_doses: 4 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of torban',       type: 'minor nerve scar',  short_name: 'tincture of torban',            store_doses: 3 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of haphip',       type: 'minor head scar',   short_name: 'tincture of haphip',            store_doses: 4 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of talneo',       type: 'minor organ scar',  short_name: 'tincture of talneo',            store_doses: 4 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of calamia',      type: 'major limb scar',   short_name: 'tincture of calamia',           store_doses: 2 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of woth',         type: 'major nerve scar',  short_name: 'tincture of woth',              store_doses: 2 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of brostheras',   type: 'major head scar',   short_name: 'tincture of brostheras',        store_doses: 2 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of wingstem',     type: 'major organ scar',  short_name: 'tincture of wingstem',          store_doses: 2 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of bur-clover',   type: 'missing eye',       short_name: 'tincture of bur-clover',        store_doses: 1 },
        { location: ['Cysaegir', 'the village of Cysaegir', 'the hamlet of Ravelin'],   name: 'tincture of sovyn',        type: 'severed limb',      short_name: 'tincture of sovyn',             store_doses: 1 },

        # Ta'Illistim 2 19282/13204008
        { location: ["Ta'Illistim"],   name: 'tincture of acantha',     type: 'blood',              short_name: 'tincture of acantha',     store_doses: 20 },
        { location: ["Ta'Illistim"],   name: 'tincture of wolifrew',    type: 'minor nerve wound',  short_name: 'tincture of wolifrew',    store_doses: 20 },
        { location: ["Ta'Illistim"],   name: 'tincture of torban',      type: 'minor nerve scar',   short_name: 'tincture of torban',      store_doses: 10 },
        { location: ["Ta'Illistim"],   name: 'tincture of woth',        type: 'major nerve scar',   short_name: 'tincture of woth',        store_doses: 10 },
        { location: ["Ta'Illistim"],   name: 'tincture of ambrominas',  type: 'minor limb wound',   short_name: 'tincture of ambrominas',  store_doses: 20 },
        { location: ["Ta'Illistim"],   name: 'tincture of basal',       type: 'minor organ wound',  short_name: 'tincture of basal',       store_doses: 20 },
        { location: ["Ta'Illistim"],   name: 'tincture of ephlox',      type: 'major limb wound',   short_name: 'tincture of ephlox',      store_doses: 20 },
        { location: ["Ta'Illistim"],   name: 'tincture of pothinir',    type: 'major organ wound',  short_name: 'tincture of pothinir',    store_doses: 10 },
        { location: ["Ta'Illistim"],   name: 'tincture of aloeas',      type: 'major head wound',   short_name: 'tincture of aloeas',      store_doses: 10 },
        { location: ["Ta'Illistim"],   name: 'tincture of rose-marrow', type: 'minor head wound',   short_name: 'tincture of rose-marrow', store_doses: 20 },
        { location: ["Ta'Illistim"],   name: 'tincture of cactacae',    type: 'minor limb scar',    short_name: 'tincture of cactacae',    store_doses: 10 },
        { location: ["Ta'Illistim"],   name: 'tincture of calamia',     type: 'major limb scar',    short_name: 'tincture of calamia',     store_doses: 10 },
        { location: ["Ta'Illistim"],   name: 'tincture of haphip',      type: 'minor head scar',    short_name: 'tincture of haphip',      store_doses: 10 },
        { location: ["Ta'Illistim"],   name: 'tincture of brostheras',  type: 'major head scar',    short_name: 'tincture of brostheras',  store_doses: 10 },
        { location: ["Ta'Illistim"],   name: 'tincture of bolmara',     type: 'major nerve wound',  short_name: 'tincture of bolmara',     store_doses: 20 },
        { location: ["Ta'Illistim"],   name: 'tincture of talneo',      type: 'minor organ scar',   short_name: 'tincture of talneo',      store_doses: 10 },
        { location: ["Ta'Illistim"],   name: 'tincture of bur-clover',  type: 'missing eye',        short_name: 'tincture of bur-clover',  store_doses: 10 },
        { location: ["Ta'Illistim"],   name: 'tincture of wingstem',    type: 'major organ scar',   short_name: 'tincture of wingstem',    store_doses: 10 },
        { location: ["Ta'Illistim"],   name: 'tincture of sovyn',       type: 'severed limb',       short_name: 'tincture of sovyn',       store_doses: 10 },

        # Teras 1851/3003056
        { location: ['the town of Kharam-Dzu'],  name: "flagon of Olak's Ol'style ale",    type: 'blood',              short_name: "Olak's Ol'style ale",        store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: "barrel of Olak's Ol'style ale",    type: 'blood',              short_name: "Olak's Ol'style ale",        store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: 'flagon of Lost Dogwater ale',      type: 'minor limb wound',   short_name: 'Lost Dogwater ale',          store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: 'barrel of Lost Dogwater ale',      type: 'minor limb wound',   short_name: 'Lost Dogwater ale',          store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: "flagon of Orc's Head ale",         type: 'minor nerve wound',  short_name: "Orc's Head ale",             store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: "barrel of Orc's Head ale",         type: 'minor nerve wound',  short_name: "Orc's Head ale",             store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: "flagon of Semak's Smooth ale",     type: 'minor head wound',   short_name: "Semak's Smooth ale",         store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: "barrel of Semak's Smooth ale",     type: 'minor head wound',   short_name: "Semak's Smooth ale",         store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: "flagon of Mama Dwarf's ale",       type: 'minor organ wound',  short_name: "Mama Dwarf's ale",           store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: "barrel of Mama Dwarf's ale",       type: 'minor organ wound',  short_name: "Mama Dwarf's ale",           store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: 'flagon of Bloody Krolvin ale',     type: 'blood',              short_name: 'Bloody Krolvin ale',         store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: 'barrel of Bloody Krolvin ale',     type: 'blood',              short_name: 'Bloody Krolvin ale',         store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: 'flagon of Golden Goose ale',       type: 'major limb wound',   short_name: 'Golden Goose ale',           store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: 'barrel of Golden Goose ale',       type: 'major limb wound',   short_name: 'Golden Goose ale',           store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: "flagon of Kenar's Dropjaw ale",    type: 'major nerve wound',  short_name: "Kenar's Dropjaw ale",        store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: "barrel of Kenar's Dropjaw ale",    type: 'major nerve wound',  short_name: "Kenar's Dropjaw ale",        store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: 'flagon of Dark Swampwater ale',    type: 'major head wound',   short_name: 'Dark Swampwater ale',        store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: 'barrel of Dark Swampwater ale',    type: 'major head wound',   short_name: 'Dark Swampwater ale',        store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: 'flagon of Aged Schooner ale',      type: 'major organ wound',  short_name: 'Aged Schooner ale',          store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: 'barrel of Aged Schooner ale',      type: 'major organ wound',  short_name: 'Aged Schooner ale',          store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: "flagon of Bearded Ladies' ale",    type: 'minor limb scar',    short_name: "Bearded Ladies' ale",        store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: "barrel of Bearded Ladies' ale",    type: 'minor limb scar',    short_name: "Bearded Ladies' ale",        store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: "flagon of Miner's Muddy ale",      type: 'minor nerve scar',   short_name: "Miner's Muddy ale",          store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: "barrel of Miner's Muddy ale",      type: 'minor nerve scar',   short_name: "Miner's Muddy ale",          store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: "flagon of Agrak's Amber ale",      type: 'minor head scar',    short_name: "Agrak's Amber ale",          store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: "barrel of Agrak's Amber ale",      type: 'minor head scar',    short_name: "Agrak's Amber ale",          store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: "flagon of Gert's Homemade ale",    type: 'minor organ scar',   short_name: "Gert's Homemade ale",        store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: "barrel of Gert's Homemade ale",    type: 'minor organ scar',   short_name: "Gert's Homemade ale",        store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: 'flagon of Mad Mutt Frothy ale',    type: 'major limb scar',    short_name: 'Mad Mutt Frothy ale',        store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: 'barrel of Mad Mutt Frothy ale',    type: 'major limb scar',    short_name: 'Mad Mutt Frothy ale',        store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: "flagon of Dacra's Dream ale",      type: 'major nerve scar',   short_name: "Dacra's Dream ale",          store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: "barrel of Dacra's Dream ale",      type: 'major nerve scar',   short_name: "Dacra's Dream ale",          store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: "flagon of Reaper's Red ale",       type: 'major head scar',    short_name: "Reaper's Red ale",           store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: "barrel of Reaper's Red ale",       type: 'major head scar',    short_name: "Reaper's Red ale",           store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: "barrel of Reaper's Red ale",       type: 'major head scar',    short_name: "Reaper's Red ale",           store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: "flagon of Wort's Winter ale",      type: 'major organ scar',   short_name: "Wort's Winter ale",          store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: "barrel of Wort's Winter ale",      type: 'major organ scar',   short_name: "Wort's Winter ale",          store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: 'flagon of Volcano Vision ale',     type: 'missing eye',        short_name: 'Volcano Vision ale',         store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: 'barrel of Volcano Vision ale',     type: 'missing eye',        short_name: 'Volcano Vision ale',         store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: "flagon of Captn' Pegleg's ale",    type: 'severed limb',       short_name: "Captn' Pegleg's ale",        store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: "barrel of Captn' Pegleg's ale",    type: 'severed limb',       short_name: "Captn' Pegleg's ale",        store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: "flagon of Dead Man's Pale ale",    type: 'lifekeep',           short_name: "Dead Man's Pale ale",        store_doses: 3 },
        { location: ['the town of Kharam-Dzu'],  name: "barrel of Dead Man's Pale ale",    type: 'lifekeep',           short_name: "Dead Man's Pale ale",        store_doses: 10 },
        { location: ['the town of Kharam-Dzu'],  name: "flagon of Dragon's Blood porter",  type: 'raisedead',          short_name: "Dragon's Blood porter",      store_doses: 1 },

        # Icemule 3363/4043866
        # Hinterwilds 31061/7503257
        { location: ['Icemule Trace', 'the Hinterwilds'], name: 'Dabbings Family special tart',      type: 'minor limb wound',    short_name: 'Family special tart',       store_doses: 10 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: "Leaftoe's lichen tart",             type: 'minor nerve wound',   short_name: 'lichen tart',               store_doses: 10 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: 'candied ptarmigan feather',         type: 'severed limb',        short_name: 'ptarmigan feather',         store_doses: 1 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: 'earthworm potion',                  type: 'major organ scar',    short_name: 'earthworm potion',          store_doses: 2 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: 'elk horn potion',                   type: 'minor head wound',    short_name: 'elk horn potion',           store_doses: 4 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: 'gelatinous elk fat tart',           type: 'minor limb scar',     short_name: 'elk fat tart',              store_doses: 10 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: 'iceberry tart',                     type: 'blood',               short_name: 'iceberry tart',             store_doses: 10 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: 'rock lizard potion',                type: 'minor organ scar',    short_name: 'rock lizard potion',        store_doses: 4 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: "slice of Ma Leaftoe's Special",     type: 'minor nerve scar',    short_name: "Ma Leaftoe's Special",      store_doses: 5 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: 'slice of pickled walrus blubber',   type: 'major limb scar',     short_name: 'pickled walrus blubber',    store_doses: 2 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: 'slice of sparrowhawk pie',          type: 'minor head scar',     short_name: 'sparrowhawk pie',           store_doses: 5 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: 'small egg and tundra grass tart',   type: 'minor organ wound',   short_name: 'tundra grass tart',         store_doses: 5 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: 'snowflake elixir',                  type: 'major nerve wound',   short_name: 'snowflake elixir',          store_doses: 4 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: "some frog's bone porridge",         type: 'major limb wound',    short_name: "frog's bone porridge",      store_doses: 4 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: 'starfish potion',                   type: 'missing eye',         short_name: 'starfish potion',           store_doses: 1 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: 'tiny cup of polar bear fat soup',   type: 'major head scar',     short_name: 'polar bear fat soup',       store_doses: 2 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: 'tiny flower-shaped tart',           type: 'major nerve scar',    short_name: 'flower-shaped tart',        store_doses: 2 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: 'tiny musk ox tart',                 type: 'major organ wound',   short_name: 'musk ox tart',              store_doses: 2 },
        { location: ['Icemule Trace', 'the Hinterwilds'], name: "tiny ram's bladder tart",           type: 'major head wound',    short_name: "ram's bladder tart",        store_doses: 2 },

        # Pinefar 2782/4564010
        { location: ['the Pinefar Trading Post'], name: 'some acantha leaf tea',    type: 'blood',              short_name: 'acantha leaf tea',        store_doses: 10 },
        { location: ['the Pinefar Trading Post'], name: 'some sweetfern tea',       type: 'minor limb wound',   short_name: 'sweetfern tea',           store_doses: 4 },
        { location: ['the Pinefar Trading Post'], name: 'some red lichen tea',      type: 'minor nerve wound',  short_name: 'red lichen tea',          store_doses: 4 },
        { location: ['the Pinefar Trading Post'], name: 'some feverfew tea',        type: 'minor head wound',   short_name: 'feverfew tea',            store_doses: 4 },
        { location: ['the Pinefar Trading Post'], name: 'some ginkgo nut tea',      type: 'minor organ wound',  short_name: 'ginkgo nut tea',          store_doses: 4 },
        { location: ['the Pinefar Trading Post'], name: 'some sassafras tea',       type: 'blood',              short_name: 'sassafras tea',           store_doses: 2 },
        { location: ['the Pinefar Trading Post'], name: 'sweetfern potion',         type: 'major limb wound',   short_name: 'sweetfern potion',        store_doses: 4 },
        { location: ['the Pinefar Trading Post'], name: 'red lichen potion',        type: 'major nerve wound',  short_name: 'red lichen potion',       store_doses: 4 },
        { location: ['the Pinefar Trading Post'], name: 'feverfew potion',          type: 'major head wound',   short_name: 'feverfew potion',         store_doses: 4 },
        { location: ['the Pinefar Trading Post'], name: 'ginkgo nut potion',        type: 'major organ wound',  short_name: 'ginkgo nut potion',       store_doses: 4 },
        { location: ['the Pinefar Trading Post'], name: 'manroot tea',              type: 'minor limb scar',    short_name: 'manroot tea',             store_doses: 2 },
        { location: ['the Pinefar Trading Post'], name: 'valerian root tea',        type: 'minor nerve scar',   short_name: 'valerian root tea',       store_doses: 2 },
        { location: ['the Pinefar Trading Post'], name: 'pennyroyal tea',           type: 'minor head scar',    short_name: 'pennyroyal tea',          store_doses: 2 },
        { location: ['the Pinefar Trading Post'], name: 'wyrmwood root tea',        type: 'minor organ scar',   short_name: 'wyrmwood root tea',       store_doses: 2 },
        { location: ['the Pinefar Trading Post'], name: 'manroot potion',           type: 'major limb scar',    short_name: 'manroot potion',          store_doses: 2 },
        { location: ['the Pinefar Trading Post'], name: 'valerian root potion',     type: 'major nerve scar',   short_name: 'valerian root potion',    store_doses: 2 },
        { location: ['the Pinefar Trading Post'], name: 'pennyroyal potion',        type: 'major head scar',    short_name: 'pennyroyal potion',       store_doses: 2 },
        { location: ['the Pinefar Trading Post'], name: 'wyrmwood root potion',     type: 'major organ scar',   short_name: 'wyrmwood root potion',    store_doses: 2 },
        { location: ['the Pinefar Trading Post'], name: 'daggit root potion',       type: 'missing eye',        short_name: 'daggit root potion',      store_doses: 1 },
        { location: ['the Pinefar Trading Post'], name: 'angelica root potion',     type: 'severed limb',       short_name: 'angelica root potion',    store_doses: 1 },
        { location: ['the Pinefar Trading Post'], name: 'earwort potion',           type: 'disease',            short_name: 'earwort potion',          store_doses: 1 },

        # Kraken's Fall 28938/7118357
        { location: ["Kraken's Fall"], name: 'some acantha leaf',            type: 'blood',               short_name: 'acantha leaf',       store_doses: 10 },
        { location: ["Kraken's Fall"], name: 'some wolifrew lichen',         type: 'minor nerve wound',   short_name: 'wolifrew lichen',    store_doses: 4 },
        { location: ["Kraken's Fall"], name: 'some torban leaf',             type: 'minor nerve scar',    short_name: 'torban leaf',        store_doses: 4 },
        { location: ["Kraken's Fall"], name: 'bolmara elixir',               type: 'major nerve wound',   short_name: 'bolmara elixir',     store_doses: 4 },
        { location: ["Kraken's Fall"], name: 'some woth flower',             type: 'major nerve scar',    short_name: 'woth flower',        store_doses: 3 },
        { location: ["Kraken's Fall"], name: 'rose-marrow elixir',           type: 'minor head wound',    short_name: 'rose-marrow elixir', store_doses: 4 },
        { location: ["Kraken's Fall"], name: 'some haphip root',             type: 'minor head scar',     short_name: 'haphip root',        store_doses: 4 },
        { location: ["Kraken's Fall"], name: 'some aloeas stem',             type: 'major head wound',    short_name: 'aloeas stem',        store_doses: 2 },
        { location: ["Kraken's Fall"], name: 'brostheras elixir',            type: 'major head scar',     short_name: 'brostheras elixir',  store_doses: 2 },
        { location: ["Kraken's Fall"], name: 'ball of basal moss',           type: 'minor organ wound',   short_name: 'basal moss',         store_doses: 7 },
        { location: ["Kraken's Fall"], name: 'talneo elixir',                type: 'minor organ scar',    short_name: 'talneo elixir',      store_doses: 4 },
        { location: ["Kraken's Fall"], name: 'some pothinir grass',          type: 'major organ wound',   short_name: 'pothinir grass',     store_doses: 2 },
        { location: ["Kraken's Fall"], name: 'wingstem elixir',              type: 'major organ scar',    short_name: 'wingstem elixir',    store_doses: 2 },
        { location: ["Kraken's Fall"], name: 'some ambrominas leaf',         type: 'minor limb wound',    short_name: 'ambrominas leaf',    store_doses: 4 },
        { location: ["Kraken's Fall"], name: 'some cactacae spine',          type: 'minor limb scar',     short_name: 'cactacae spine',     store_doses: 4 },
        { location: ["Kraken's Fall"], name: 'ball of ephlox moss',          type: 'major limb wound',    short_name: 'ephlox moss',        store_doses: 4 },
        { location: ["Kraken's Fall"], name: 'some calamia fruit',           type: 'major limb scar',     short_name: 'calamia fruit',      store_doses: 2 },
        { location: ["Kraken's Fall"], name: 'cumin-rubbed sovyn clove',     type: 'severed limb',        short_name: 'sovyn clove',        store_doses: 1 },
        { location: ["Kraken's Fall"], name: 'bur-clover elixir',            type: 'missing eye',         short_name: 'bur-clover elixir',  store_doses: 1 },

        # Mist Harbor 3363/4043866
        { location: ['the Isle of Four Winds'], name: 'some fragrant woth flower',        type: 'major nerve scar',   short_name: 'fragrant woth flower',             store_doses: 3 },
        { location: ['the Isle of Four Winds'], name: 'some dirty haphip root',           type: 'minor head scar',    short_name: 'dirty haphip root',                store_doses: 4 },
        { location: ['the Isle of Four Winds'], name: 'sticky ball of basal moss',        type: 'minor organ wound',  short_name: 'ball of basal moss',               store_doses: 7 },
        { location: ['the Isle of Four Winds'], name: 'gooey ball of ephlox moss',        type: 'major limb wound',   short_name: 'ball of ephlox moss',              store_doses: 4 },
        { location: ['the Isle of Four Winds'], name: 'some sugary ambrominas leaf',      type: 'minor limb wound',   short_name: 'sugary ambrominas leaf',           store_doses: 4 },
        { location: ['the Isle of Four Winds'], name: 'some fresh torban leaf',           type: 'minor nerve scar',   short_name: 'fresh torban leaf',                store_doses: 4 },
        { location: ['the Isle of Four Winds'], name: 'some spicy acantha leaf',          type: 'blood',              short_name: 'spicy acantha leaf',               store_doses: 10 },
        { location: ['the Isle of Four Winds'], name: 'small sovyn clove',                type: 'severed limb',       short_name: 'small sovyn clove',                store_doses: 1 },
        { location: ['the Isle of Four Winds'], name: 'some bright green pothinir grass', type: 'major organ wound',  short_name: 'some bright pothinir grass',       store_doses: 2 },
        { location: ['the Isle of Four Winds'], name: 'some withered aloeas stem',        type: 'major head wound',   short_name: 'withered aloeas stem',             store_doses: 2 },
        { location: ['the Isle of Four Winds'], name: 'some ripe calamia fruit',          type: 'major limb scar',    short_name: 'ripe calamia fruit',               store_doses: 2 },
        { location: ['the Isle of Four Winds'], name: 'some prickly cactacae spine',      type: 'minor limb scar',    short_name: 'prickly cactacae spine',           store_doses: 4 },
        { location: ['the Isle of Four Winds'], name: 'some dry wolifrew lichen',         type: 'minor nerve wound',  short_name: 'dry wolifrew lichen',              store_doses: 4 },
        { location: ['the Isle of Four Winds'], name: 'crystalline rose-marrow elixir',   type: 'minor head wound',   short_name: 'rose-marrow elixir',               store_doses: 4 },
        { location: ['the Isle of Four Winds'], name: 'crystalline talneo elixir',        type: 'minor organ scar',   short_name: 'talneo elixir',                    store_doses: 4 },
        { location: ['the Isle of Four Winds'], name: 'crystalline brostheras elixir',    type: 'major head scar',    short_name: 'brostheras elixir',                store_doses: 2 },
        { location: ['the Isle of Four Winds'], name: 'crystalline bolmara elixir',       type: 'major nerve wound',  short_name: 'bolmara elixir',                   store_doses: 4 },
        { location: ['the Isle of Four Winds'], name: 'crystalline wingstem elixir',      type: 'major organ scar',   short_name: 'wingstem elixir',                  store_doses: 2 },
        { location: ['the Isle of Four Winds'], name: 'crystalline bur-clover elixir',    type: 'missing eye',        short_name: 'bur-clover elixir',                store_doses: 1 },

        # River's Rest 10863/2101012
        { location: ["River's Rest"], name: 'beaker of malted winterberry brew', type: 'minor head wound',   short_name: 'beaker of winterberry brew',  store_doses: 4 },
        { location: ["River's Rest"], name: 'beaker of winterberry brew',        type: 'minor head wound',   short_name: 'winterberry brew',            store_doses: 4 },

        # I don't have a location or details for the following
        # foragable only?
        { location: ['Forageable'], name: 'yabathilium fruit',              type: 'blood',   short_name: 'yabathilium fruit',         store_doses: 1 },
        { location: ['Forageable'], name: 'ochre-colored fungus',           type: 'poison',  short_name: 'ochre-colored fungus',      store_doses: 1 },
        { location: ['Forageable'], name: 'red nettle berry',               type: 'poison',  short_name: 'red nettle berry',          store_doses: 1 },

        # weird skins only?
        { location: ['Skinnable'],  name: 'pulsating firethorn shoot',      type: 'poison',  short_name: 'pulsating firethorn shoot', store_doses: 1 },

        # alchemical only?
        { location: ['Alchemical'], name: 'tincture of yabathilium',        type: 'blood',   short_name: 'tincture of yabathilium',   store_doses: 1 },
        { location: ['Alchemical'], name: 'dimly glowing sky-blue potion',  type: 'disease', short_name: 'sky-blue potion',           store_doses: 4 },
        { location: ['Alchemical'], name: 'dimly glowing sea-green potion', type: 'poison',  short_name: 'sea-green potion',          store_doses: 4 }
      ].freeze

      # Short names of the "major blood" (yabathilium-class) restoratives.
      # Every one still has type 'blood'; the list only splits counting and
      # stocking when a driver asks for it.
      MAJOR_BLOOD = ['yabathilium fruit', 'tincture of yabathilium', 'Bloody Krolvin ale', "Olak's Ol'style ale",
                     'green mushroom potion', 'sassafras tea'].freeze

      # An herb that is drunk rather than eaten, by its name.
      DRINKABLE = /\b(?:potion|tea|elixir|brew|tincture|ale|soup|porter)\b/i

      # What cannot be bundled or poured together.
      CANT_BUNDLE = /tart|feather|special|blubber|pie|porridge|soup|fruit/i

      # The wound types, in the order a sack is filled.
      TYPES = ['blood', 'major head wound', 'minor head wound', 'major head scar', 'minor head scar', 'major organ wound',
               'minor organ wound', 'major organ scar', 'minor organ scar', 'missing eye', 'major limb wound',
               'minor limb wound', 'major limb scar', 'minor limb scar', 'severed limb', 'major nerve wound',
               'minor nerve wound', 'major nerve scar', 'minor nerve scar'].freeze

      # Types the eaten herbs cover and the ones only potions do, for stocking.
      HERB_TYPES = ['major head wound', 'minor head scar', 'major organ wound', 'minor organ wound', 'major limb wound',
                    'minor limb wound', 'major limb scar', 'minor limb scar', 'severed limb', 'minor nerve wound',
                    'major nerve scar', 'minor nerve scar'].freeze
      POTION_TYPES = ['major head scar', 'minor head wound', 'major nerve wound', 'minor organ scar', 'major organ scar',
                      'missing eye'].freeze

      # Doses to keep of each type when stocking a sack.
      DEFAULT_DOSES = {
        'major head scar' => 6, 'minor head wound' => 4, 'major nerve wound' => 4, 'minor organ scar' => 4,
        'major organ scar' => 6, 'missing eye' => 7, 'blood' => 50, 'minor blood' => 50, 'major blood' => 20,
        'major head wound' => 25, 'minor head scar' => 25, 'major organ wound' => 25, 'minor organ wound' => 25,
        'major limb wound' => 25, 'minor limb wound' => 25, 'major limb scar' => 25, 'minor limb scar' => 25,
        'severed limb' => 25, 'minor nerve wound' => 25, 'major nerve scar' => 25, 'minor nerve scar' => 25,
      }.freeze

      # The wound areas Lich reports, to the word the herb types use.
      AREAS = { 'head' => 'head', 'neck' => 'head', 'torso' => 'organ', 'limbs' => 'limb', 'nerves' => 'nerve' }.freeze

      # @param herb [Hash] a KNOWN entry
      # @return [Boolean]
      def major_blood?(herb)
        herb[:type] == 'blood' && MAJOR_BLOOD.include?(herb[:short_name])
      end

      # @param herb [Hash]
      # @return [String] 'major blood' or 'minor blood' for a blood herb, else its type
      def blood_tier(herb)
        return herb[:type] unless herb[:type] == 'blood'
        major_blood?(herb) ? 'major blood' : 'minor blood'
      end

      # The bucket an herb is counted and stocked under.
      #
      # @param herb [Hash]
      # @param split [Boolean] count major and minor blood apart
      # @return [String]
      def blood_bucket(herb, split: false)
        return herb[:type] unless herb[:type] == 'blood'
        split ? blood_tier(herb) : 'blood'
      end

      # @param herb [Hash]
      # @param category [String] a type, or 'blood' / 'minor blood' / 'major blood'
      # @return [Boolean]
      def in_category?(herb, category)
        case category
        when 'blood' then herb[:type] == 'blood'
        when 'minor blood', 'major blood' then blood_tier(herb) == category
        else herb[:type] == category
        end
      end

      # @param name [String] an item's name as the game shows it
      # @return [Boolean] whether it is drunk
      def drinkable?(name)
        name.to_s =~ DRINKABLE ? true : false
      end

      # @param item_name [String]
      # @return [Hash, nil] the entry whose name or short name the item carries
      def entry_for(item_name)
        return nil if item_name.to_s.empty?
        KNOWN.find { |h| h[:name] =~ /#{Regexp.escape(item_name)}/ || h[:short_name] =~ /#{Regexp.escape(item_name)}/ }
      end

      # @param item_name [String]
      # @param type [String] a wound type
      # @return [Boolean] whether the item cures it
      def cures?(item_name, type)
        return false if item_name.to_s.empty?
        KNOWN.any? { |h| h[:type] == type && (h[:name] =~ /#{Regexp.escape(item_name)}/ || h[:short_name] =~ /#{Regexp.escape(item_name)}/) }
      end

      # @param item_name [String]
      # @return [Boolean] whether any known herb matches
      def herb?(item_name)
        !entry_for(item_name).nil?
      end

      # @param type [String]
      # @return [Array<Hash>]
      def entries(type)
        KNOWN.select { |h| h[:type] == type }
      end

      # @param location [String] a map location
      # @return [Boolean] whether any known herb is sold there
      def sold_at?(location)
        return false if location.to_s.empty?
        KNOWN.any? { |h| h[:location].any? { |place| place.include?(location) } }
      end

      # The herb sold at +location+ for a category, by form.
      #
      # @param category [String]
      # @param location [String]
      # @param form [Symbol, nil] :drinkable, :edible, or nil for either
      # @return [Hash, nil]
      def sold(category, location, form: nil)
        KNOWN.find do |h|
          next false unless in_category?(h, category) && h[:location].any? { |place| place =~ /#{Regexp.escape(location)}/ }
          case form
          when :drinkable then drinkable?(h[:name])
          when :edible then !drinkable?(h[:name])
          else true
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module EO
  module Guild
    module Escort
      # The edges of the escort roads that the map's own wayto cannot walk
      # with a client in tow, and how to take each. escortgo2 1.0.5
      # better_miniscript (454-1393), one entry per "from,to" pair.
      #
      # Each entry is [kind, argument]; Walk#take_route runs it:
      #   :climb      a climb or go, hiding again after
      #   :careful    protect, check the room, haste, then the move (hands emptied for :careful_hands)
      #   :sneak      the Darkstone caves: stand, hide, sneak +dir+ until the room changes
      #   :search     search up to N times for a hidden way, then go through it
      #   :cart       the Zul Logoth mining cart: buy a ticket, ride, wait for the client
      #   :ferry      the Ta'Illistim ferry: gangplank, wait for the crew, out
      #   :steps      a list of moves with a wait for the client after each
      #   :ladder     the Zul Logoth rope ladder, hands emptied
      #   :misty      the misty trail: climb down, look where the trail goes, follow
      #   :crack      a crack to search through twice
      #   :loop       repeat a two-move pattern while a path stays open
      ROUTES = {
        '2524,2523'   => [:climb, 'climb rockslide'],
        '2510,2509'   => [:climb, 'climb bank'],
        '2509,2510'   => [:climb, 'climb bank'],
        '2502,2503'   => [:climb, 'climb branch'],
        '2505,2504'   => [:climb, 'climb tree'],
        '75,74'       => [:climb, 'climb wall'],
        '74,75'       => [:climb, 'climb wall'],
        '884,883'     => [:climb, 'climb boulders'],
        '883,884'     => [:climb, 'climb boulders'],
        '964,963'     => [:climb, 'climb boulders'],
        '963,964'     => [:climb, 'climb boulders'],
        '1018,1017'   => [:climb, 'climb precipice'],
        '1017,1018'   => [:climb, 'climb cliff'],
        '1030,1029'   => [:climb, 'climb cliff'],
        '1029,1030'   => [:climb, 'climb cliff'],
        '1020,1019'   => [:climb, 'climb crevice'],
        '1019,1020'   => [:climb, 'climb crevice'],
        '1074,1075'   => [:climb, 'southeast'],
        '991,990'     => [:careful_hands, 'climb trail'],
        '990,991'     => [:careful_hands, 'climb trail'],
        '990,989'     => [:careful_hands, 'climb path'],
        '989,990'     => [:careful_hands, 'climb path'],
        '989,988'     => [:careful_hands, 'climb mountainside'],
        '988,989'     => [:careful_hands, 'climb mountainside'],
        '1224,1223'   => [:careful_hands, 'climb boulder'],
        '1223,1224'   => [:careful_hands, 'climb boulder'],
        '971,970'     => [:careful_hide, 'go fissure'],
        '970,971'     => [:careful_hide, 'go fissure'],
        '902,901'     => [:careful_hide, 'go crevasse'],
        '1024,1025'   => [:careful, 'climb ledge'],
        '1025,1024'   => [:careful, 'climb cliff'],
        '1156,1155'   => [:careful, 'north'],
        '1153,1154'   => [:careful, 'south'],
        '1236,1237'   => [:careful, 'go stream'],
        '1239,1238'   => [:careful, 'go stream'],
        '1219,1220'   => [:search, [3, /discover a northwest path/, /^don't find anything|discover a northwest path|Round\s?time/, 'go path']],
        '1242,1241'   => [:search, [5, /discover a/, /discover a|don't find anything|Round\s?time/, 'go path']],
        '1216,1217'   => [:search, [5, /discover a small footpath/, /don't find anything|discover a small footpath|^Round\s?time/, 'go footpath']],
        '10117,10119' => [:ferry, 10117],
        '10119,10117' => [:ferry, 10119],
        '2547,2546'   => [:sneak, 'northeast'],
        '2547,2548'   => [:sneak, 'southwest'],
        '2545,2544'   => [:sneak, 'north'],
        '2545,2546'   => [:sneak, 'southwest'],
        '2536,2535'   => [:sneak, 'east'],
        '2536,2537'   => [:sneak, 'west'],
        '2535,2534'   => [:sneak, 'southeast'],
        '2535,2536'   => [:sneak, 'west'],
        '2534,2533'   => [:sneak, 'southeast'],
        '2534,2535'   => [:sneak, 'northwest'],
        '2526,2525'   => [:sneak, 'east'],
        '2526,2527'   => [:sneak, 'west'],
        '2525,2524'   => [:sneak, 'northeast'],
        '2525,2526'   => [:sneak, 'west'],
        '2524,2525'   => [:sneak, 'southwest'],
        '2522,2521'   => [:sneak, 'northeast'],
        '2522,2523'   => [:sneak, 'west'],
        '2521,2520'   => [:sneak, 'northeast'],
        '2521,2522'   => [:sneak, 'southwest'],
        '2518,2519'   => [:sneak, 'west'],
        '2518,2517'   => [:sneak, 'northeast'],
        '2516,2515'   => [:sneak, 'north'],
        '2516,2517'   => [:sneak, 'south'],
        '2513,2512'   => [:sneak, 'northwest'],
        '2513,2514'   => [:sneak, 'south'],
        '2507,2508'   => [:sneak, 'southwest'],
        '2506,2505'   => [:sneak, 'north'],
        '2502,2501'   => [:sneak, 'north'],
        '2500,2499'   => [:sneak, 'northeast'],
        '2500,2501'   => [:sneak, 'south'],
        '2497,2498'   => [:sneak, 'southwest'],
        '2497,2496'   => [:sneak, 'west'],
        '1012,1013'   => [:cart, nil],
        '1260,1261'   => [:cart, nil],
        '1266,1267'   => [:cart, nil],
        '992,993'     => [:cart, nil],
        '1230,1231'   => [:crack, nil],
        '1232,1231'   => [:crack, nil],
        '784,786'     => [:steps, %w[south south west]],
        '786,784'     => [:steps, %w[east east north east north]],
        '1808,1811'   => [:steps, %w[southwest southwest southwest northwest northwest]],
        '1811,1808'   => [:steps, %w[southeast southeast northeast northeast northeast]],
        '1042,1041'   => [:misty, nil],
        '1074,1073'   => [:ladder, %w[climb\ ladder climb\ down climb\ down climb\ down]],
        '1070,1071'   => [:ladder, %w[climb\ ladder climb\ up climb\ up climb\ up]],
        '785,786'     => [:loop, ['s', %w[south west]]],
        '785,784'     => [:loop, ['n', %w[east north]]],
      }.freeze
    end
  end
end

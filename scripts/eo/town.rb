# frozen_string_literal: true

module EO
  # Towns and their shops: which shop to walk to and whether to go at all,
  # the region a bounty's town shares with the character, Four Winds Isle,
  # the trash can and the locksmith pool's worker. eloot 2.15.0: Region
  # (2682), fwi? (3359), shop_unavailable_in_town? (3372), nearest_shop
  # (3395), fwi_return (3401), find_trash (3268), find_worker (3328).
  module Town
    module_function

    # Coldriver Village in the Hinterwilds has a gemshop, a furrier and the
    # locksmith pool and nothing else; the nearest pawnshop on the map is
    # Icemule's, a continent away.
    HINTERWILDS_UID = 7503205
    HINTERWILDS_ONLY = /collect|pawnshop|consignment|chronomage/

    # Crossing one of these means leaving the region: the ferry, the mine
    # carts, the River's Rest boot, the Hinterwilds transports, the portmasters.
    REGION_EDGE_UIDS = [
      14001002, # Ta'Vaalor Ferry
      13002021, # Western Spine Mine Cart
      13003019, # Eastern Spine Mine Cart
      373014,   # River's Rest Boot
      7503001,  # Hinterwilds Caravan Dropoff
      13205202, # EN Hinterwilds Transport
      4132054,  # IMT Hinterwilds Transport
      7111,     # Portmaster - Wehnimer's Landing
      3002033,  # Portmaster - Teras Isle
      2101030,  # Portmaster - River's Rest
      4744014,  # Portmaster - Solhaven
      7118259,  # Portmaster - Kraken's Fall
      7136032,  # Portmaster - Ta'Vaalor
      7133026,  # Portmaster - Icemule Trace
    ].freeze

    POOL_WORKERS = %w[worker trickster Jahck woman attendant gnome merchant dwarf].freeze

    # @param room [Room, nil]
    # @return [Boolean] on Four Winds Isle
    def fwi?(room)
      return false if room.nil?
      room.location.to_s =~ /Four Winds|Mist Harbor|Western Harbor/ ? true : false
    end

    # @return [Room, nil] the nearest town square
    def square(from: Room.current)
      id = from&.find_nearest_by_tag('town')
      id && Room[id]
    end

    # @param shop [String] a shop tag
    # @param from [Room]
    # @return [Boolean] whether this town lacks the shop and a trip would leave the area
    def shop_elsewhere?(shop, from: Room.current)
      return false unless shop.to_s =~ HINTERWILDS_ONLY
      town = square(from: from)
      !town.nil? && town.uid.first == HINTERWILDS_UID
    end

    # The room to sell at, or nil when the shop is not in this town and
    # going would mean a trip out of the area. Every shop walk should come
    # through here: find_nearest_by_tag alone searches the whole map.
    #
    # @param shop [String] a shop tag ("pawnshop")
    # @param from [Room]
    # @param far_is_fine [Boolean] the character means to travel to sell
    # @return [Integer, nil]
    def nearest_shop(shop, from: Room.current, far_is_fine: false)
      return nil if !far_is_fine && shop_elsewhere?(shop, from: from)
      from.find_nearest_by_tag(shop)
    end

    # The room with +tag+ in a given town.
    #
    # @param tag [String]
    # @param town [String] a town name, matched loosely against the map's location
    # @return [Room, nil]
    def in_town(tag, town)
      towns = Map.list.select { |r| r.tags.include?('town') }
      match = towns.find { |t| t.location.to_s.downcase.include?(town.to_s.downcase) }
      return nil if match.nil?
      id = match.find_nearest_by_tag(tag)
      id && Room[id]
    end

    # A shop in a bounty's town, when it can be reached without leaving the
    # region: the path crosses none of the REGION_EDGE rooms.
    #
    # @param tag [String] the shop
    # @param town [String] the task's town ("Cold River" is the Hinterwilds)
    # @param from [Room]
    # @return [Integer, nil] the room id, nil when out of region or unknown
    def in_region(tag, town, from: Room.current)
      town = 'Hinterwilds' if town == 'Cold River'
      destination = in_town(tag, town) or return nil
      return destination.id if from.id == destination.id
      path = from.path_to(destination) or return nil
      edges = REGION_EDGE_UIDS.map { |uid| Map.ids_from_uid(uid).first }.compact
      (path & edges).empty? ? destination.id : nil
    end

    # Leave Four Winds Isle the way the go2 settings say: the return room,
    # or the trinket turned at the dock.
    #
    # @param trinket [String, nil] UserVars.mapdb_fwi_trinket
    # @param return_room [Integer, String, nil] UserVars.mapdb_fwi_return_room
    # @return [Symbol] :left, :not_here, or :no_trinket
    def fwi_return(trinket:, return_room:)
      return :not_here unless Room.current.find_nearest_by_tag('town') == 3668
      return :no_trinket if trinket.nil? && return_room.nil?
      EO.go2(3669)
      if return_room.nil?
        worn = !GameObj[trinket].nil?
        fput "get my #{trinket}" unless worn
        fput "turn ##{GameObj[trinket].id}"
        fput "stow my #{trinket}" unless worn
      else
        EO.go2(return_room)
      end
      :left
    end

    # @return [GameObj, nil] the trash receptacle here
    def trash_can
      lines = EO.command('trash', /You could discard items|You do not notice/, silent: true, quiet: true)
      return nil if lines.any? { |l| l =~ /You do not notice a trash receptacle here/ }
      lines.each do |line|
        m = line.match(/You could discard items in (?:an?|the) <a exist="(?<exist>-?\d+)" noun="(?<noun>.*?)">(?<name>.*?)<\/a>/)
        return GameObj.new(m[:exist], m[:noun], m[:name]) if m
      end
      nil
    end

    # The locksmith pool's worker, named by the room's meta:boxpool:npc tag
    # or one of the usual nouns, waiting a little for the room to fill in.
    #
    # @return [GameObj, nil]
    def pool_worker
      tag = Room.current.tags.find { |t| t =~ /meta:boxpool:npc:(.*)/ }
      names = tag ? [Regexp.last_match(1)] : POOL_WORKERS
      20.times do
        worker = GameObj.npcs.to_a.find { |n| n.name =~ Regexp.union(names) }
        return worker if worker
        EO.command('look', /<resource picture/, silent: true, quiet: true)
        sleep 0.1
      end
      nil
    end
  end
end

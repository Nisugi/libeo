# frozen_string_literal: true

module EO
  # The Adventurer's Guild: the task logic that came out of ebounty. Line
  # numbers in comments refer to ebounty 1.13.0 (scripts/ebounty.lic on
  # nisugi/feat/ebounty-webui), the source of every rule here.
  module Guild
    # Raised where ebounty used to exit the script: the driver decides what
    # to do (rest and stop, retry, report).
    class Error < StandardError; end

    # Game facts: where the guild's people are and what they say. From
    # ebounty Data.
    module Tables
      module_function

      # Lich's Bounty task type to ebounty's bounty_types setting name.
      CROSSWALK = {
        bandit_assignment: 'kill_bandits',
        bandit: 'kill_bandits',
        creature_assignment: 'kill_creatures',
        cull: 'culling',
        dangerous: 'boss_culling',
        escort: 'escort',
        gem_assignment: 'gem_collecting',
        gem: 'gem_collecting',
        heirloom_assignment: 'heirloom_both',
        heirloom: 'heirloom_both',
        herb_assignment: 'foraging',
        herb: 'foraging',
        rescue_assignment: 'rescue',
        rescue: 'rescue',
        skin_assignment: 'skinning',
        skin: 'skinning',
      }.freeze

      # Every bounty_types name a settings file may list.
      BOUNTY_TYPES = %w[boss_culling culling heirloom_loot skinning heirloom_search foraging rescue escort kill_bandits gem_collecting].freeze

      # What the taskmaster says to ASK ABOUT BOUNTY.
      TASKMASTER_RESPONSES = Regexp.union(
        /The local gem dealer, .*, has an order to fill and wants our help./,
        /The local furrier .* has an order to fill and wants our help./,
        /It appears they have a .* problem they'd like you to solve./,
        /It appears that a local resident urgently needs our help in some matter.  Go report to .* to find out more./,
        /The local (healer|herbalist), .*, has asked for our aid./,
        /You have already been assigned a task, \w+./,
        /It appears they need your help in tracking down some kind of lost heirloom.  Go report to .* to find out more./,
        /Come back in about .* (?:minute|minutes) if you want another task./,
        /I have removed you from your current assignment/,
        /Who are you trying to ask/
      ).freeze

      # What a guard says to ASK ABOUT BOUNTY.
      GUARD_RESPONSES = Regexp.union(
        /suppress bandit activity|bandits you encounter/,
        /particularly dangerous|cull their numbers|(?!.*bandit)suppress .* activity/,
        /SEARCH the area|do a thorough SEARCH/,
        /LOOT the item from its corpse/,
        /I don't have any tasks for you right now/,
        /Try bugging me later/,
        /Ah, so you have returned/,
        /You have completed your task/
      ).freeze

      # A guard's "nothing for you" answers, which send the asker to the next guard room.
      GUARD_NOTHING = /I don't have any tasks for you right now|Try bugging me later|Who are you trying to ask\?/.freeze

      # Who counts as a guard in an advguard room. River's Rest asks the purser.
      GUARD_NAMES = /(?:guard|sergeant|guardsman|sentry|tavernkeeper|alchemist|Malovor)/i.freeze

      FURRIER_NAMES = Regexp.union(/Bramblefist/i, /Delosa/i, /dwarven clerk/i, /furrier/i, /patchwork flesh merchant/i).freeze

      JEWELER_NAMES = Regexp.union(/areacne/i, /Brindlestoat/i, /dwarven clerk/i, /gem dealer/i, /jeweler/i,
                                   /plump purple-robed trader/i, /Zirconia/i).freeze

      HERBALIST_NAMES = Regexp.union(/Akrash/i, /alchemist/i, /brother Barnstel/i, /famed baker Leaftoe/i, /healer/i,
                                     /herbalist/i, /Libram Greenleaf/i, /Maraene/i, /merchant Kelph/i,
                                     /old Mistress Lomara/i, /scarred Agarnil kris/i, /Sparkfinger/i,
                                     /spectral quartermaster/i).freeze

      # The herbalist's room in each town, as uids. No map tag marks them.
      HERBALIST_ROOM_UIDS = %w[
        u4043601 u1015 u3003056 u14103400 u13104200 u4740011
        u2101052 u13010004 u7118358 u7503253 u3201291 u7150621
      ].freeze

      # The town square uid for each town name a task can carry.
      # Contempt (Sailor's Grief) differs between GS4 and GSF, see .town_uid.
      TOWN_UIDS = {
        'Icemule Trace'      => 'u4042150',
        'Kharam-Dzu'         => 'u3001025',
        "Kraken's Fall"      => 'u7118221',
        'Mist Harbor'        => 'u3201029',
        "River's Rest"       => 'u2101008',
        'Solhaven'           => 'u4209030',
        'Vornavis'           => 'u4209030',
        "Ta'Illistim"        => 'u13100042',
        "Ta'Vaalor"          => 'u14100047',
        "Wehnimer's Landing" => 'u7120',
        'Zul Logoth'         => 'u13006016',
        'Cold River'         => 'u7503205',
      }.freeze

      # Sailor's Grief: the taskmaster is First Mate Seldit, who wanders these rooms.
      SAILORS_GRIEF_UIDS = [
        7150601, 7150602, 7150603, 7150604, 7150605, 7150606, 7150607, 7150608, 7150609, 7150610,
        7150611, 7150612, 7150613, 7150614, 7150615, 7150616, 7150617, 7150621, 7150622,
      ].freeze

      # Hinterwilds: the guild's taskmaster is Halfwhistle.
      HINTERWILDS_GUILD_UID = 7503207

      # Hinterwilds: the tavernkeeper guard moves, so ask the alchemist instead.
      HINTERWILDS_MOVING_GUARD_UIDS = %w[7503252 7503251].freeze
      HINTERWILDS_GUARD_ROOM = 'u7503253'

      # Escort tasks: the pickup wording and the destination town, to a trip name
      # such as "landing_to_icemule" that the escort_types setting lists.
      ESCORT_PICKUPS = {
        'the area just inside the Sapphire Gate'                   => 'illy',
        'the area just inside the North Gate'                      => 'landing',
        'the south end of North Market'                            => 'solhaven',
        'the area just north of the South Gate, past the barbican' => 'icemule',
        "the Kresh'ar Deep monument"                               => 'zul',
        'the area just inside the Amaranth Gate'                   => 'vaalor',
      }.freeze

      ESCORT_DROPOFFS = {
        "Wehnimer's Landing" => 'landing',
        'Icemule Trace'      => 'icemule',
        'Zul Logoth'         => 'zul',
        'Solhaven'           => 'solhaven',
        "Ta'Vaalor"          => 'vaalor',
        "Ta'Illistim"        => 'illy',
      }.freeze

      # What FORAGE answers.
      FORAGE_RESULT = Regexp.union(
        /^You begin to forage around when suddenly you feel a burning sensation in your hand\.$/,
        /^You begin to forage around when your hand comes into contact with something that stabs you in the finger\.$/,
        /^You forage/,
        /^You fumble about so badly in your search that you can only hope no one was watching you\.$/,
        /^You make so much noise that only the dead would not notice you thrashing about in your unsuccessful search\.$/,
        /^You stumble about in a fruitless attempt at foraging\.$/,
        /you are unable to find anything useful/,
        /^As you carefully forage around you (?:can find no (?:hint|trace)|see no evidence) of what you are looking for(?: right now, though you are fairly certain this is where it can be found)?\.(?:  You briefly wonder if it could even thrive in this place\.)?/,
        /^As you forage around you suddenly feel a sharp pain/
      ).freeze

      # A forage that hurt.
      FORAGE_INJURY = Regexp.union(
        /^You begin to forage around when your hand comes into contact with something that stabs you in the finger./,
        /^As you forage around you suddenly feel a sharp pain in your/,
        /suddenly you feel a burning sensation in your hand/
      ).freeze

      # Picking something up worked, or could not.
      GET_RESULT = /^You (?:shield the opening of .*? from view as you |discreetly |carefully |deftly )?(?:remove|draw|grab|reach|slip|tuck|retrieve|already have|unsheathe|detach|swap)|^Get what\?$|^Why don't you leave some for others\?$|^You need a free hand|^You already have that/.freeze

      # Putting something away worked, or could not.
      PUT_RESULT = /^You (?:put|(?:discreetly )?tuck|attach|toss|attempt to shield your|place|.* place|slip|wipe off the blade and sheathe|absent-mindedly drop|carefully add|find an incomplete bundle|untie your drawstring pouch)|^The .+ is already a bundle|^Your bundle would be too large if you if you tried to add that|^The .+ is too large to be bundled\.|^As you place your .+ inside your .+, you notice another .+ inside the .+ and carefully arrange the two .+ into a neat bundle\.|If you wish to continue, throw the item away again within fifteen seconds|you feel pleased with yourself at having cleaned up the surrounding area|over your shoulder|two items in that location|wear three functional items|^Your .*? won't fit in .*?\.$/.freeze

      # @param town [String] a town name as the Bounty parser reports it
      # @return [String, nil] the town square's uid
      def town_uid(town)
        return (XMLData.game == 'GSF' ? 'u7150607' : 'u7150608') if town == 'Contempt'
        TOWN_UIDS[town]
      end

      # @param town [String]
      # @return [Room, nil] the town square
      def town_room(town)
        uid = town_uid(town)
        uid && Room[uid]
      end

      # @return [Array<Integer>] the herbalist rooms the map knows, as ids
      def herbalist_rooms
        HERBALIST_ROOM_UIDS.map { |uid| Room[uid]&.id.to_i }.select(&:positive?)
      end
    end
  end
end

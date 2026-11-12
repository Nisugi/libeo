# frozen_string_literal: true

module EO
  module Guild
    # Finding the guild's people: an NPC in the room, the taskmaster, the
    # guards of a town. ebounty find_npc (2670), find_taskmaster (2629),
    # guard_list (2698).
    module NPCs
      module_function

      # The first NPC in the room whose name matches, trying five times with a
      # settle between, since the room's objects can lag a move.
      #
      # @param names [Regexp]
      # @return [GameObj]
      # @raise [Error] when nobody matched after five tries
      def find(names)
        5.times do |attempt|
          npc = (GameObj.room_desc.to_a + GameObj.npcs.to_a).find { |t| t.name =~ names }
          return npc if npc
          Lich::Messaging.msg('warn', "NPC #{names.source} not here yet (attempt #{attempt + 1})") if attempt.positive?
          EO.settle
        end
        raise Error, "NPC #{names.source} not found after 5 attempts"
      end

      # Walk to the guild if not already there and name the taskmaster to ask:
      # Taskmaster, Halfwhistle in the Hinterwilds, or First Mate Seldit on
      # Sailor's Grief, who wanders the boat and has to be found.
      #
      # @return [String] the name to ASK
      # @raise [Error] when Seldit is nowhere on the boat after three sweeps
      def taskmaster
        here = Room.current.uid.first
        unless Room.current.tags.include?('advguild') || Tables::SAILORS_GRIEF_UIDS.include?(here)
          EO.go2('advguild')
          EO.settle
          here = Room.current.uid.first
        end
        return 'Halfwhistle' if here == Tables::HINTERWILDS_GUILD_UID
        return 'Taskmaster' unless Tables::SAILORS_GRIEF_UIDS.include?(here)
        return 'Seldit' if seldit_here?

        3.times do
          Tables::SAILORS_GRIEF_UIDS.each do |uid|
            EO.go2("u#{uid}")
            return 'Seldit' if seldit_here?
            echo "Looking for the lousy First Mate Seldit in #{uid}"
          end
        end
        raise Error, "searched the boat 3 times and could not find Seldit (rooms #{Tables::SAILORS_GRIEF_UIDS.join(', ')})"
      end

      # @return [Boolean]
      def seldit_here?
        GameObj.npcs.any? { |npc| npc.name =~ /Seldit/i }
      end

      # The advguard rooms that belong to a town and can be walked to from its
      # square. Two tasks name their guard by a phrase the Bounty parser does
      # not turn into a town yet; they are mapped here (2701).
      #
      # @param town [String] the task's town
      # @param bounty_text [String] the task text, for the two unparsed guards
      # @return [Array<Integer>] room ids
      def guard_rooms(town, bounty_text = '')
        town = "Kraken's Fall" if bounty_text =~ /the sentry just outside town\.$/
        town = 'Cold River' if bounty_text =~ /the tavernkeeper at Rawknuckle's Common House\.$/
        square = Tables.town_room(town)
        return [] if square.nil?
        Room.list.select do |r|
          r.tags.any? { |tag| tag =~ /advguard/ } && Room[r.find_nearest_by_tag('town')] == square && !square.path_to(r).nil?
        end.map(&:id)
      end
    end
  end
end

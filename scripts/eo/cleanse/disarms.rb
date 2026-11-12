# frozen_string_literal: true

require 'securerandom'

module EO
  module Cleanse
    # A weapon knocked away, webbed, floated off or turned into a creature,
    # and getting it back. The disarms not yet recovered are kept in
    # UserVars.last_disarm, so a death or a restart does not lose one.
    # ecleanse recover, recover_weapon_webbing,
    # telekinetic_recover, sanctum_recover, recovered?,
    # the disarm list.
    module Disarms
      module_function

      # The game's own recovery list holds 20 and drops the oldest for good.
      MAX = 20
      # The list is changed from Lich's event thread and the driver's.
      LOCK ||= Mutex.new
      RECOVER_ANSWERS = /<dialogData|You spy|You continue to intently search the area|In order to recover something|You find nothing recoverable|You're not in any condition to be searching around/
      SEARCHES = 10

      # Disarms not yet recovered, oldest first: { id:, item:, room:, title:, at: }.
      # Before ecleanse 2.3.7 the variable held a bare room number, which reads as none.
      #
      # @return [Array<Hash>]
      def list
        saved = UserVars.last_disarm
        saved.is_a?(Array) ? saved : []
      end

      def tracked?(id) = list.any? { |entry| entry[:id] == id }

      # Remember a disarm, here unless the room is given.
      #
      # @param noun [String]
      # @param room_id [Integer, nil]
      # @param title [String, nil]
      # @return [String] its id
      def add(noun, room_id: :here, title: nil)
        if room_id == :here
          room = Room.current
          room_id = room&.id
          title = Array(room&.title).first
        end
        entry = { id: SecureRandom.hex(4), item: noun, room: room_id, title: title.to_s, at: Time.now.to_i }
        LOCK.synchronize { UserVars.last_disarm = (list + [entry]).last(MAX) }
        entry[:id]
      end

      def remove(id)
        LOCK.synchronize { UserVars.last_disarm = list.reject { |entry| entry[:id] == id } }
      end

      # The game says the room holds nothing to recover, so nothing else
      # saved there can be found either. Unmapped rooms all save nil.
      def remove_room(room_id, id)
        LOCK.synchronize { UserVars.last_disarm = list.reject { |entry| entry[:id] == id || (!room_id.nil? && entry[:room] == room_id) } }
      end

      # A search turned up an earlier disarm instead of the one looked for.
      def remove_found(found, room_id)
        entry = list.reverse.find { |e| e[:room] == room_id && same_item?(found, e[:item]) }
        remove(entry[:id]) unless entry.nil?
      end

      # What RECOVER ITEM says was picked up, or nil.
      #
      # @param lines [Array<String>]
      # @return [String, nil] the noun when the line carries it, else its words
      def spied_item(lines)
        line = lines.find { |l| l =~ /You spy .+ and recover it!/ }
        return nil if line.nil?

        line[/You spy .*?noun="([^"]+)"/, 1] || line.gsub(/<[^>]+>/, '')[/You spy (.+?) and recover it!/, 1]
      end

      def same_item?(found, noun) = found.to_s.match?(/\b#{Regexp.escape(noun.to_s)}\b/i)

      # The ids in hand now, to tell a recovered weapon from one never lost.
      #
      # @return [Array<String>]
      def hands = [GameObj.right_hand.id, GameObj.left_hand.id].compact.map(&:to_s).reject(&:empty?)

      # A hand holds an item that was not there at the disarm, with the
      # disarmed noun when known. Two weapons of the same noun, or one that
      # comes back under a new id, are both told apart this way.
      #
      # @param known_ids [Array<String>] from .hands at the disarm
      # @param noun [String, nil]
      # @return [Boolean]
      def recovered?(known_ids, noun = nil)
        [GameObj.right_hand, GameObj.left_hand].any? do |hand|
          next false if hand.name == 'Empty' || hand.id.nil? || known_ids.include?(hand.id.to_s)

          noun.nil? || hand.noun.to_s.casecmp?(noun.to_s)
        end
      end

      # A bonded weapon comes back by itself: weapon bonding at rank five,
      # or 1625.
      #
      # @return [Boolean]
      def bonded?
        Lich::Gemstone::Feat.known?('weapon_bonding', min_rank: 5) || Spell[1625].known?
      rescue StandardError
        Spell[1625].known?
      end

      # 213 and 1011 up before searching, as the policy allows.
      #
      # @param policy [Policy]
      # @return [Array<Integer>] the spells to stop afterwards (.stop)
      def prepare(policy)
        EO.settle
        return [] unless Cleanse.able_to_cast?(determination: policy.determination)

        cast = [[213, policy.use_213], [1011, policy.use_1011]].filter_map do |num, wanted|
          next unless wanted && Spell[num].known?

          Lich::Gemstone::Mana.pulse(num)
          Spell[num].cast if Spell[num].affordable?
          num
        end
        EO.settle
        cast
      end

      def stop(spells) = spells.each { |num| fput "stop #{num}" }

      # With 218 up, the spirit servant recovers it.
      #
      # @return [Boolean] whether the servant did
      def servant
        return false unless Spell[218].active?

        15.times do
          break if GameObj.npcs.to_a.any? { |npc| npc.noun =~ /spirit/i }

          sleep 0.1
        end
        dothistimeout('tell servant recover', 5, /flickers for a moment and manifests|has no personal recollection/).to_s =~ /flickers for a moment and manifests/ ? true : false
      end

      # Wait up to ten seconds for a bonded weapon to come back by itself.
      #
      # @return [Boolean] whether it is back
      def await_bonded(known_ids, noun)
        return false unless bonded?

        deadline = Time.now + 10
        EO.settle until recovered?(known_ids, noun) || Time.now > deadline
        recovered?(known_ids, noun)
      end

      # What came of a search: outcome :recovered, :cannot_search (too hurt
      # to search), :nothing_here (the game says the room is empty) or
      # :not_found; stashes, how many times the hands were emptied to search.
      Search = Struct.new(:outcome, :stashes, keyword_init: true)

      # Kneel and RECOVER ITEM in the disarm room, ten times at most. Finding
      # an earlier disarm instead keeps the search going. The saved list is
      # kept up to date as it goes.
      #
      # @param item [String] the noun lost
      # @param known_ids [Array<String>]
      # @param room_id [Integer, nil]
      # @param id [String, nil] its entry in the list
      # @yield [event, found] :other with what was picked up instead of the
      #   item, or :inferred when no message named it but a hand now holds it
      # @return [Search]
      def search(item, known_ids:, room_id:, id:)
        empty_hands
        stashes = 1
        SEARCHES.times do
          EO.go2(room_id) if room_id && Room.current.id != room_id
          dothistimeout('kneel', 2, /You kneel|You are already/i) until kneeling?
          EO.settle
          lines = Cleanse.command('recover item', RECOVER_ANSWERS)
          found = spied_item(lines)
          if found && same_item?(found, item)
            remove(id)
            return Search.new(outcome: :recovered, stashes: stashes)
          elsif found
            yield :other, found if block_given?
            remove_found(found, room_id)
          elsif recovered?(known_ids, item)
            yield :inferred, nil if block_given?
            remove(id)
            return Search.new(outcome: :recovered, stashes: stashes)
          end
          return Search.new(outcome: :cannot_search, stashes: stashes) if lines.any? { |l| l =~ /You're not in any condition to be searching around/ }
          if lines.any? { |l| l =~ /You find nothing recoverable/ } && Room.current.id == room_id
            remove_room(room_id, id)
            return Search.new(outcome: :nothing_here, stashes: stashes)
          end
          if lines.any? { |l| l =~ /In order to recover something/ }
            empty_hands
            stashes += 1
          end
        end
        Search.new(outcome: :not_found, stashes: stashes)
      end

      # Stand and put back what each emptying of the hands put away, oldest
      # first, so the weapon held before the search gets the free hand
      # ahead of anything the search turned up.
      #
      # @param stashes [Integer]
      # @return [void]
      def restore_hands(stashes)
        EO.stand
        EO.settle
        $fill_hands_actions.push(*$fill_hands_actions.pop(stashes).reverse) if stashes > 1
        stashes.times { fill_hands }
        ReadyList.check(silent: true, quiet: true) unless ReadyList.valid?
      end

      # PRY a webbed weapon free, ten tries.
      #
      # @param noun [String]
      # @return [Symbol] :pried or :still_webbed
      def pry(noun)
        10.times do
          lines = Cleanse.command("pry my #{noun}", /^Pry what|^You try to pry your|^You pry your.*free from the webbing/)
          return :pried if lines.any? { |l| l =~ /You pry your|Pry what/i }
        end
        :still_webbed
      end

      # A weapon floated off by Telekinetic Disarm (Moonsedge): the dispel
      # at it, else GET, until a hand holds it or it is seen with us.
      #
      # @param noun [String]
      # @param known_ids [Array<String>]
      # @return [Symbol] :recovered or :not_recovered
      def telekinetic(noun, known_ids)
        dispel = Cleanse.spell(:dispel)
        10.times do
          return :recovered if recovered?(known_ids, noun)

          if dispel
            Lich::Gemstone::Mana.pulse(dispel)
            dispel.cast("at #{noun}") if dispel.affordable?
          else
            fput "get #{noun}"
          end
          return :recovered if Cleanse.command('glance', /You glance/, silent: true, quiet: true).any? { |l| l =~ /#{noun}/ }

          EO.settle
        end
        recovered?(known_ids, noun) ? :recovered : :not_recovered
      end

      # A weapon a Lithe Veiled Sentinel made into a creature (Unholy
      # Quickening, the Sanctum): CLENCH it back.
      #
      # @param creature [String] its noun
      # @return [Symbol] :clenched or :not_clenched
      def clench(creature)
        10.times do
          line = EO.result("clench #{creature}", /You reach up and grab|I could not find what you were referring to\./)
          EO.settle
          return :clenched if line
        end
        :not_clenched
      end
    end
  end
end

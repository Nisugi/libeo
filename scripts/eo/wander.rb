# frozen_string_literal: true

module EO
  # Wandering a hunting area: one step anywhere, the Elemental Confluence
  # (whose exits the map does not know), choosing a creature to stop for,
  # and learning which creatures TARGET accepts. The plain step is
  # EO.wander in travel.rb. ewander 2.0.1: Targeting (120), Movement
  # (179), the target-random loop (473).
  module Wander
    module_function

    # Body parts that come as their own NPC; a named kraken tentacle is a
    # creature in its own right.
    APPENDAGE = /^(?:arm|appendage|claw|limb|pincer|tentacle)s?$|^(?:palpus|palpi)$/i
    KRAKEN_TENTACLE = /(?:amaranthine|ghostly|grizzled|ancient) kraken tentacle/i

    # A step from wherever the character is: the Confluence its own way,
    # anywhere else by EO.wander.
    #
    # @param visited [Array] room ids, most recent last; updated (the
    #   Confluence keeps its own in the same list)
    # @param avoid [Array<String>] room ids not to step into
    # @return [Boolean] whether a step was taken
    def step(visited, avoid: [])
      if checkroom == '[Elemental Confluence]'
        XMLData.game == 'GSIV' ? Confluence.mapped_step(visited) : Confluence.turning_step
        true
      else
        EO.wander(visited, avoid: avoid)
      end
    end

    # The first live creature here matching one of +names+, in priority
    # order: not dead or gone, not a pet animate (animated slush excepted),
    # not a body part (a named kraken tentacle excepted). It need not be
    # hostile; see .hostile?.
    #
    # @param names [Array<String>] name patterns
    # @return [GameObj, nil]
    def find(names)
      names.each do |name|
        found = GameObj.npcs.to_a.find do |npc|
          next false if npc.status.to_s =~ /dead|gone/i
          next false if npc.name =~ /^animated\b/i && npc.name !~ /^animated slush/i
          next false if npc.noun =~ APPENDAGE && npc.name !~ KRAKEN_TENTACLE
          npc.name =~ /#{name}/i
        end
        return found if found
      end
      nil
    end

    # @param npc [GameObj]
    # @return [Boolean] whether it is something to fight (in GameObj.targets)
    def hostile?(npc)
      GameObj.targets.to_a.map(&:id).include?(npc.id)
    end

    # TARGET a creature, if hostile.
    #
    # @param npc [GameObj]
    # @return [Boolean] whether TARGET was sent
    def target!(npc)
      return false unless hostile?(npc)
      fput "target ##{npc.id}"
      waitrt?
      true
    end

    # TARGET RANDOM, learning names. A name that is targeted goes on
    # +targetable+; when nothing could be targeted and the room has not
    # changed meanwhile, every candidate goes on +untargetable+.
    #
    # @param candidates [Array<GameObj>] the creatures here that might do
    # @param targetable [Array<String>] grown here
    # @param untargetable [Array<String>] grown here
    # @return [Boolean] whether something is targeted now
    def target_random!(candidates, targetable:, untargetable:)
      before = GameObj.targets.to_a
      clear
      result = dothistimeout('target random', 5, /^Could not find a valid target\.$|^You are now targeting/)
      if result =~ /^You are now targeting \w+ (.*)\.$/
        targetable.push(Regexp.last_match(1)) unless targetable.include?(Regexp.last_match(1))
        return true
      end
      if result == 'Could not find a valid target.' && GameObj.targets.to_a == before
        candidates.each { |npc| untargetable.push(npc.name) unless untargetable.include?(npc.name) }
      end
      false
    end

    # The Elemental Confluence: a maze whose exits shift and that the map
    # database does not route. In GSIV its rooms are learned as they are
    # walked; elsewhere the walk turns to the next exit clockwise from the
    # way it came. The tranquility points and bottomless pits are noted as
    # they are seen, for go2.
    module Confluence
      module_function

      DIRS = %w[north northeast east southeast south southwest west northwest].freeze
      REVERSE = {
        'north' => 'south', 'northeast' => 'southwest', 'east' => 'west', 'southeast' => 'northwest',
        'south' => 'north', 'southwest' => 'northeast', 'west' => 'east', 'northwest' => 'southeast'
      }.freeze
      # fixme: Prime room numbers only
      HOT_ROOMS = [23282, 23283, 23284, 23285, 23286, 23287, 23288, 23289, 23290, 23291, 23292, 23293, 23294,
                   23295, 23296, 23297, 23298, 23299, 23300, 23301, 23302, 23303, 23329, 23330, 23331, 23332,
                   23333, 23334].freeze

      # The learned exits, kept in $mapdb_confluence_wayto as go2 expects:
      # room id => { direction => room id it led to, or nil untried }.
      #
      # @param visited [Array]
      # @return [void]
      def mapped_step(visited)
        $mapdb_confluence_wayto ||= {}
        begin
          start = Room.current
          wayto = ($mapdb_confluence_wayto[start.id] ||= {})
          raise 'Restarting' if Room.current != start
          XMLData.room_exits.each { |d| wayto[d] = nil unless wayto.key?(d) }
          if wayto.keys != XMLData.room_exits
            # the exits changed under us: what was learned is stale
            $mapdb_confluence_wayto = {}
            raise 'Restarting'
          end
          # untried, then not yet visited, then least recently visited
          dir = wayto.keys.find { |d| wayto[d].nil? }
          dir ||= wayto.keys.find { |d| !visited.include?(wayto[d]) }
          if dir.nil?
            next_id = visited.find { |i| wayto.values.include?(i) }
            dir = wayto.keys.find { |d| wayto[d] == next_id }
          end
          dir ||= XMLData.room_exits.sample
          if move(dir.dup) == false
            move(exits_now.sample)
          else
            arrived = Room.current
            visited.delete(arrived.id)
            visited.push(arrived.id)
            wayto[dir] = arrived.id
            note_landmarks(arrived)
          end
        rescue StandardError
          retry
        end
      end

      # Turn to the next exit clockwise from the way we came, so the walk
      # does not double straight back.
      #
      # @return [void]
      def turning_step
        if $mapdb_confluence_last_dir.nil?
          $mapdb_confluence_last_dir = XMLData.room_exits.sample
        else
          idx = DIRS.index(REVERSE[$mapdb_confluence_last_dir])
          8.times do
            idx = (idx + 1) % 8
            next unless XMLData.room_exits.include?(DIRS[idx])
            $mapdb_confluence_last_dir = DIRS[idx]
            break
          end
        end
        result = move($mapdb_confluence_last_dir)
        waitrt?
        return unless result == false
        # stale exits: look, and take one of the real ones
        $mapdb_confluence_last_dir = exits_now.sample
        move($mapdb_confluence_last_dir)
      end

      # @return [Array<String>] the exits LOOK shows now
      def exits_now
        status_tags
        look = dothistimeout('look', 5, /<compass>/)
        status_tags
        look.to_s.scan(/<dir value="(.*?)"/).flatten
      end

      # Note a tranquility point or pit in this room, or clear one that is gone.
      #
      # @param room [Room]
      # @return [void]
      def note_landmarks(room)
        tranquil = GameObj.loot.to_a.any? { |o| o.name == 'point of elemental tranquility' }
        pit = GameObj.loot.to_a.any? { |o| o.name == 'gaping bottomless pit' }
        if HOT_ROOMS.include?(room.id)
          $mapdb_confluence_hot_tranquility = landmark($mapdb_confluence_hot_tranquility, room.id, tranquil)
          $mapdb_confluence_hot_pit = landmark($mapdb_confluence_hot_pit, room.id, pit)
        else
          $mapdb_confluence_cold_tranquility = landmark($mapdb_confluence_cold_tranquility, room.id, tranquil)
          $mapdb_confluence_cold_pit = landmark($mapdb_confluence_cold_pit, room.id, pit)
        end
      end

      # The landmark's room after seeing this one: here if it is here, gone
      # if it was here and is not, unchanged otherwise.
      def landmark(known, here, seen)
        return here if seen
        known == here ? nil : known
      end
    end
  end
end

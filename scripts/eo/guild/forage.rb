# frozen_string_literal: true

module EO
  module Guild
    # Herb tasks: where an herb grows, what it is called once picked, the
    # gathering loop, and giving the herbs to the herbalist. ebounty
    # forage_find (3044 in 1.13.0), find_herb_stow_list (3092),
    # forage_bounty (3103), forage_turnin (3282), forage_return (3329).
    module Forage
      module_function

      # The forage_options setting: helper spells, hiding, gambits, running
      # from creatures. skip_healing says a hurt forager keeps going.
      Policy = Struct.new(:options, :skip_healing, keyword_init: true) do
        def initialize(options: [], skip_healing: false)
          super(options: Array(options).map(&:to_s), skip_healing: skip_healing)
        end

        def use?(key) = options.include?(key.to_s)
      end

      # The task names some herbs by a form that FORAGE does not (3050).
      TASK_NAMES = {
        /ayana (weed|lichen|berry|root)/    => 'ayana leaf',
        /ayana'al (weed|lichen|berry|root)/ => "ayana'al leaf",
      }.freeze

      # The task shortens some mushroom names; the item in the sack is the full one (3093).
      STOW_NAMES = {
        'white mushroom'    => 'white hook mushroom',
        'trafel mushroom'   => 'black trafel mushroom',
        'withered mushroom' => 'withered black mushroom',
        'soft mushroom'     => 'soft white mushroom',
        'red mushroom'      => 'red trafel mushroom',
        'black mushroom'    => 'black hook mushroom',
      }.freeze

      FOUND = /^You forage briefly and manage to find/
      NOTHING_HERE = /^As you carefully forage around you (?:can find no (?:hint|trace)|see no evidence) of what you are looking for(?: right now, though you are fairly certain this is where it can be found)?\.(?:  You briefly wonder if it could even thrive in this place\.)?/
      PICKED_OVER = /^As you forage around, you notice that someone has been foraging here recently and you are unable to find anything useful\./
      GIVE_RESULT = /This looks perfect|That looks like it has been partially used up/

      # @param herb [String] as the task names it
      # @return [String] as FORAGE wants it
      def forage_name(herb)
        TASK_NAMES.each { |pattern, name| return name if herb =~ pattern }
        herb
      end

      # @param herb [String] as the task names it
      # @return [String] as the item reads in a container
      def stow_name(herb)
        STOW_NAMES.fetch(herb, herb)
      end

      # Does a container item answer to the herb? Ayana items are named by
      # their part, so the herb name may only start with the item's.
      #
      # @param item_name [String]
      # @param herb [String] the task's name for it
      # @return [Boolean]
      def match?(item_name, herb)
        full = stow_name(herb)
        (item_name =~ /#{Regexp.escape(full)}/ || (full.start_with?(item_name) && full =~ /ayana/)) ? true : false
      end

      # The items in +container+ that answer to the herb.
      #
      # @param container [GameObj]
      # @param herb [String]
      # @return [Array<GameObj>]
      def in_container(container, herb)
        container.contents.to_a.select { |item| match?(item.name, herb) }
      end

      # Rooms tagged with the herb, nearest first. With a location, only
      # rooms there; with "nearest", the ten closest within 90 steps.
      #
      # @param herb [String] as the task names it
      # @param forage_item [String] what the task's FORAGE link names (may differ)
      # @param location [String] a location name, or "nearest"
      # @param from [Room]
      # @return [Array<Integer>] room ids
      def rooms(herb, forage_item, location = 'nearest', from: Room.current)
        herb = forage_name(herb)
        herb_alt = herb.sub(/^some /, '')
        pattern = /#{Regexp.escape(herb)}|#{Regexp.escape(herb_alt)}|#{Regexp.escape(forage_item.to_s)}/

        ids = Room.list.select do |r|
          r.tags.any? { |tag| tag.end_with?(herb) || (herb.start_with?(tag) && herb =~ /ayana/) || herb.end_with?(tag) }
        end.map(&:id)
        ids.select! { |id| Room[id].tags.any? { |tag| tag =~ pattern } }

        nearest = location.eql?('nearest')
        unless nearest
          where = /#{Regexp.escape(location.strip)}/
          ids.select! { |id| Room[id].location.to_s =~ where }
        end

        _previous, distance = from.dijkstra
        ids = ids.select { |id| distance[id] && (!nearest || distance[id] <= 90) }.sort_by { |id| distance[id] }
        nearest ? ids.first(10) : ids
      end

      # What the task's FORAGE link names, from BOUNTY, when it differs from
      # the herb in the text.
      #
      # @param herb [String] the fallback
      # @return [String]
      def forage_item(herb)
        lines = EO.command('bounty', /<a exist=".*?" noun="#{Char.name}"/, silent: true, quiet: true)
        line = lines.find { |l| l =~ /concoction that requires <d cmd="(.*?)">/ }
        line ? Regexp.last_match(1).sub(/^forage /, '').strip : herb
      end

      # Forage in each room until the sack holds enough. Returns early when
      # creatures arrive and the policy says to run.
      #
      # @param item [String] what to FORAGE for
      # @param count [Proc] how many are held now
      # @param needed [Integer]
      # @param rooms [Array<Integer>]
      # @param policy [Policy]
      # @param sack [GameObj] where to put what is found
      # @param gambit [Boolean] a Rogue with the stealth put gambit
      # @param hurt [Proc] called when wounded enough to stop; returns after healing
      # @return [void]
      def gather(item:, count:, needed:, rooms:, policy:, sack:, gambit: false, hurt: nil)
        creatures = []
        EO.settle
        Lich::Gemstone::Stance.change('defensive')

        rooms.each do |room|
          EO.go2(room)
          next if (GameObj.targets.count.positive? && policy.use?(:run)) || !Claim.mine? || GameObj.loot.any? { |i| i.name =~ /black void/ }

          empty_hands
          loop do
            Heirloom::Spells.helpers(policy, creatures) unless Map.current.tags.include?('meta:nomagic')
            until kneeling?
              fput 'kneel'
              EO.settle
            end
            yierka(policy)
            if !Map.current.tags.include?('meta:nomagic') && policy.use?(:use_608) && Spell[608].known? && !hidden?
              Lich::Gemstone::Mana.pulse(608)
              Spell[608].cast if Spell[608].affordable?
            end
            fput 'hide' if (policy.use?(:use_gambit) || policy.use?(:hiding)) && !hidden?

            result = EO.result("forage for #{item}", Tables::FORAGE_RESULT)
            EO.settle
            if result =~ FOUND
              stow_found(sack, gambit: gambit && checkhidden)
              held = count.call
              Lich::Messaging.msg('info', " #{held} of #{needed} #{held > 1 ? "#{item}s" : item} foraged")
              break if held >= needed
            elsif result =~ Tables::FORAGE_INJURY
              EO.settle
              Spell[114].cast if Spell[114].known? && Spell[114].affordable? && !Map.current.tags.include?('meta:nomagic')
            elsif result.nil? || result =~ NOTHING_HERE
              break
            elsif result =~ PICKED_OVER
              break unless evoke_bounty?(policy)
              next
            end

            if hurt && !policy.skip_healing && (XMLData.injuries.any? { |_a, h| h['wound'] > 1 || h['scar'] > 1 } || Char.percent_health < 70)
              back = Room.current.id
              hurt.call
              EO.go2(back)
            end
            break if !GameObj.targets.empty? && policy.use?(:run)
          end

          fput 'stand' until standing?
          fill_hands
          Heirloom::Spells.stop_sanctuary(policy)
          break if count.call >= needed
        end

        Heirloom::Spells.stop_peace(policy)
      end

      # Put what was foraged in the sack, up to five tries, by gambit when hidden.
      #
      # @param sack [GameObj]
      # @param gambit [Boolean]
      # @return [void]
      def stow_found(sack, gambit: false)
        item = [GameObj.right_hand, GameObj.left_hand].find { |i| !i.noun.nil? }
        return if item.nil?
        5.times do
          fput "#{gambit ? 'rgambit stealth ' : ''}put my #{item.noun} in my #{sack}"
          EO.settle
          held = [GameObj.right_hand, GameObj.left_hand].map(&:id).compact
          break if !held.include?(item.id) && sack.contents.to_a.map(&:id).include?(item.id)
        end
      end

      # Assume the yierka form for 650 when the policy wants it (3179).
      def yierka(policy)
        return unless policy.use?(:use_650) && !Map.current.tags.include?('meta:nomagic')
        if Spell[650].known? && Spell[650].affordable? && !Spell[650].active? && !Spell[9039].active?
          multifput('prep 650', 'assume yierka')
        elsif Spell[650].active? && !Spell[9039].active? && Char.mana >= 25
          waitcastrt?
          fput 'assume yierka'
        end
      end

      # A picked-over room can be renewed by evoking 604 (3235).
      #
      # @return [Boolean] whether it was evoked
      def evoke_bounty?(policy)
        return false if Effects::Cooldowns.active?("Nature's Bounty Foraging") || Skills.slblessings < 15
        return false unless policy.use?(:use_604evoke) && Spell[604].known? && Spell[604].affordable?
        return false if Map.current.tags.include?('meta:nomagic')
        Spell[604].force_evoke
        true
      end

      # @param town [String] the task's town
      # @return [Integer, nil] the herbalist's room there
      def herbalist_room(town)
        square = Tables.town_room(town)
        square&.find_nearest(Tables.herbalist_rooms)
      end

      # @param town [String]
      # @return [Boolean] within two rooms of the herbalist, close enough to turn in on the way
      def near_herbalist?(town)
        room = herbalist_room(town) or return false
        _previous, distance = Room.current.dijkstra
        distance[room].to_i <= 2
      end

      # Give the herbs to the herbalist until one is refused or the task
      # changes.
      #
      # @param herbs [Array<GameObj>] the items
      # @param town [String]
      # @return [Boolean] whether the task text changed
      def give(herbs, town)
        return false if herbs.empty?
        EO.go2(herbalist_room(town))
        EO.settle
        herbalist = NPCs.find(Tables::HERBALIST_NAMES)
        empty_hands
        before = checkbounty
        herbs.each do |h|
          before = checkbounty
          EO.result("_drag ##{h.id} right", Tables::GET_RESULT)
          res = EO.result("give ##{h.id} to ##{herbalist.id}", GIVE_RESULT)
          next if res =~ /perfect/
          EO.result("stow ##{h.id}", Tables::PUT_RESULT) if checkleft || checkright
          break
        end
        fill_hands
        Taskmaster.changed?(before)
      end
    end
  end
end

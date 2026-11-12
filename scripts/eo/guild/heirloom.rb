# frozen_string_literal: true

module EO
  module Guild
    # Heirloom search tasks: wander the task's area, SEARCH every room, stow
    # the heirloom when it turns up. ebounty heirloom_search.
    module Heirloom
      module_function

      # The heirloom_options setting: which helper spells to cast, whether
      # to run from creatures, whether to pick up with the right hand.
      Policy = Struct.new(:options, keyword_init: true) do
        def initialize(options: [])
          super(options: Array(options).map(&:to_s))
        end

        def use?(key) = options.include?(key.to_s)
      end

      # What the task text says once the item is found.
      LOCATED = /You have located/

      # Search the area until the task says the heirloom is located.
      #
      # @param item [String] the heirloom as the task names it
      # @param start [Integer, String] the first room
      # @param boundaries [Array<String>] room ids not to cross
      # @param policy [Policy]
      # @param loot [Proc] run the loot script when the room has loot
      # @return [void]
      def search(item:, start:, boundaries:, policy:, loot:)
        creatures = []
        visited = []
        boundaries = boundaries.map { |r| EO.room_id(r).to_s }

        if policy.use?(:use_right)
          EO.result('flag righthand on', /You will attempt to pick up treasure using your right hand/)
        end
        EO.go2(start)
        Lich::Gemstone::Stance.change('defensive')

        loop do
          unless (GameObj.targets.count.positive? && policy.use?(:run)) || !Claim.mine? || GameObj.loot.any? { |i| i.name =~ /black void/ }
            Spells.helpers(policy, creatures) unless Map.current.tags.include?('meta:nomagic')
            until kneeling?
              fput 'kneel'
              sleep 0.2
            end
            empty_hands if checkleft || checkright
            fput 'search'
            EO.settle
            EO.stand
            EO.settle

            if checkright
              EO.result("stow ##{GameObj.right_hand.id}", Tables::PUT_RESULT)
            elsif (found = GameObj.loot.find { |obj| obj.name =~ /#{Regexp.escape(item)}/ })
              EO.result("_drag ##{found.id} right", Tables::GET_RESULT)
              EO.result("stow ##{found.id}", Tables::PUT_RESULT)
            end
            loot.call if GameObj.loot.length.positive?
            fill_hands
          end
          Spells.stop_sanctuary(policy)
          break if checkbounty =~ LOCATED
          wander(boundaries, visited)
        end

        Spells.stop_peace(policy)
        fput 'flag righthand off' if policy.use?(:use_right)
      end

      # One step to a room not yet visited, inside the boundaries, else the
      # least recently visited neighbour.
      #
      # @param boundaries [Array<String>]
      # @param visited [Array<String>] most recent last; updated
      # @return [void]
      def wander(boundaries, visited)
        EO.wander(visited, avoid: boundaries)
      end

      # The helper spells foraging and heirloom searching share, each behind
      # an option. From ebounty forage_bounty and heirloom_search.
      module Spells
        module_function

        # @param policy [#use?]
        # @param creatures [Array<GameObj>] already hit with 619, added to
        # @return [void]
        def helpers(policy, creatures)
          if Stats.prof =~ /Cleric|Empath/i && policy.use?(:use_213)
            lines = EO.command('sense', /You open your soul to the lesser/, silent: true, quiet: true)
            Spell[213].cast if Spell[213].known? && Spell[213].affordable? && lines.none? { |l| l =~ /An obvious presence of peace saturates the area/ }
          end
          if policy.use?(:use_1011)
            lines = EO.command('spell active', /<dialogData id='Active Spells'/, silent: true, quiet: true)
            Spell[1011].cast if Spell[1011].known? && Spell[1011].affordable? && lines.grep(/Song of Peace/).none?
          end
          if policy.use?(:use_709) && !GameObj.targets.empty? && GameObj.targets.none? { |c| c.name =~ /arm/ }
            Spell[709].cast if Spell[709].known? && Spell[709].affordable?
          end
          cast(402, policy, :use_402) { !Effects::Buffs.active?('Presence') }
          cast(604, policy, :use_604) { !Effects::Spells.active?("Nature's Bounty") }
          cast(506, policy, :use_506) { !Effects::Buffs.active?('Celerity') && !Effects::Cooldowns.active?('Celerity') }
          cast(919, policy, :use_919) { !Effects::Buffs.active?("Wizard's Shield") && !Effects::Cooldowns.active?("Wizard's Shield") }
          cast(140, policy, :use_140) { !Effects::Buffs.active?('Wall of Force') && !Effects::Cooldowns.active?('Wall of Force') }
          cast(1035, policy, :use_1035) { !Effects::Buffs.active?('Song of Tonis') }
          cast(9704, policy, :use_resolve) { !Effects::Buffs.active?('Sigil of Resolve') }
          return unless !GameObj.targets.empty? && policy.use?(:use_619)
          targets = GameObj.targets.reject { |w| creatures.any? { |c| c.id == w.id } }
          Spell[619].cast if Spell[619].known? && Spell[619].affordable? && targets.length.positive?
          creatures.concat(targets)
          sleep 0.5
          waitcastrt?
        end

        # @param num [Integer] the spell
        # @param policy [#use?]
        # @param option [Symbol] the option that turns it on
        # @yieldreturn [Boolean] whether it is wanted now (not already up)
        def cast(num, policy, option)
          return unless policy.use?(option) && Spell[num].known? && Spell[num].affordable? && yield
          Spell[num].cast
        end

        # Stop 213 after, so it does not hold the party in place.
        def stop_sanctuary(policy)
          return unless Stats.prof =~ /Cleric|Empath/i && policy.use?(:use_213)
          lines = EO.command('sense', /You open your soul to the lesser/, silent: true, quiet: true)
          fput 'stop 213' if lines.grep(/An obvious presence of peace saturates the area/).any?
        end

        # Stop Song of Peace after.
        def stop_peace(policy)
          return unless policy.use?(:use_1011)
          lines = EO.command('spell active', /<dialogData id='Active Spells'/, silent: true, quiet: true)
          fput 'stop 1011' if lines.grep(/Song of Peace/).any?
        end
      end
    end
  end
end

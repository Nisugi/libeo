# frozen_string_literal: true

module EO
  module Guild
    # Choosing and casting a disabling spell on whatever is in the room,
    # while something that cannot fight (a rescued child, an escort client)
    # is being walked somewhere. echild 1.20.4: DISABLERS (187),
    # echild_can_cast (155), check_justice (134), find_best_disabler (208),
    # the target-and-cast step of the walk (374).
    module Disablers
      module_function

      # The spells, whether each is allowed under town justice, and whether
      # it hits one target or every one. 504 reaches every target with
      # enough Elemental Lore, Air; see .multi_target?.
      TABLE = [
        { num: 135,  town_safe: false, single_target: false },
        { num: 201,  town_safe: true,  single_target: true },
        { num: 213,  town_safe: true,  single_target: false },
        { num: 316,  town_safe: false, single_target: false },
        { num: 410,  town_safe: false, single_target: false },
        { num: 501,  town_safe: true,  single_target: true },
        { num: 504,  town_safe: true,  single_target: :air_lore },
        { num: 505,  town_safe: true,  single_target: true },
        { num: 519,  town_safe: true,  single_target: true },
        { num: 619,  town_safe: false, single_target: false },
        { num: 706,  town_safe: true,  single_target: true },
        { num: 709,  town_safe: false, single_target: false },
        { num: 912,  town_safe: true,  single_target: false },
        { num: 1005, town_safe: true,  single_target: true },
        { num: 1011, town_safe: true,  single_target: false },
        { num: 1207, town_safe: true,  single_target: true },
        { num: 1219, town_safe: false, single_target: false },
        { num: 1608, town_safe: false, single_target: false },
      ].freeze

      # The two sanctuaries work on everything and are taken over any cheaper
      # spell when there is more than one target.
      PREFERRED_MULTI = [213, 1011].freeze

      # Spells a creature shrugs off, by name; the spell is dropped for it.
      SINGLE_TARGET_EXCLUSIONS = {
        501 => /\b(?:glacei|corpse|wraith|elemental|ghost)\b/,
        505 => /\b(?:glacei|elemental|wraith)\b/,
        410 => /\b(?:glacei|griffin|grifflet|elemental)\b/,
        709 => /\b(?:glacei|griffin|grifflet|elemental)\b/,
        706 => /\b(?:glacei|construct|elemental|brawler|protector|psionicist|fanatic)\b/,
        201 => /\b(?:grimswarm|construct)\b/,
      }.freeze
      MULTI_TARGET_EXCLUSIONS = { 410 => /\b(?:glacei|wraith|elemental|cold guardian)\b/ }.freeze

      # A creature already out of the fight needs no disabling.
      DISABLED = /dead|prone|lying down|stunned|sleeping|webbed|calm|sitting|frozen/

      # Debuffs under which a cast is not attempted.
      BLOCKING_DEBUFFS = ['Bind', 'Corrupt Essence', 'Calm', 'Mind Jolt', 'Net', 'Silenced', 'Sleep', 'Web'].freeze

      # enabled: cast disablers at all. min_mana: never spend below this.
      # forced: a spell number to use instead of choosing, or nil.
      # untargetable: creature names TARGET refused; the list is the
      # driver's and grows as the walk learns more.
      Policy = Struct.new(:enabled, :min_mana, :forced, :untargetable, keyword_init: true) do
        def initialize(enabled: true, min_mana: 0, forced: nil, untargetable: [])
          super(enabled: enabled, min_mana: min_mana.to_i, forced: forced.is_a?(Integer) && forced.positive? ? forced : nil,
                untargetable: untargetable)
        end
      end

      # @param num [Integer]
      # @return [Boolean] whether the spell can reach every target
      def multi_target?(entry)
        case entry[:single_target]
        when :air_lore then Skills.elair >= 20
        else !entry[:single_target]
        end
      end

      # Whether a cast is worth attempting: not stunned or dead, no wound
      # that blocks casting (head, eyes and nerves; the arms and hands
      # unless Sigil of Power holds), none of the blocking debuffs.
      #
      # @return [Boolean]
      def can_cast?
        return false if stunned? || dead?
        head = [Wounds.head, Scars.head, Wounds.leftEye, Scars.leftEye, Wounds.rightEye, Scars.rightEye, Wounds.nsys, Scars.nsys].max
        blocked = if Spell[9716].active?
                    head > 2
                  else
                    head > 1 ||
                      [Wounds.leftArm, Wounds.leftHand, Wounds.rightArm, Wounds.rightHand, Scars.leftArm, Scars.leftHand, Scars.rightArm, Scars.rightHand].max > 2 ||
                      [Wounds.leftArm, Wounds.leftHand, Scars.leftArm, Scars.leftHand].max > 1 ||
                      [Wounds.rightArm, Wounds.rightHand, Scars.rightArm, Scars.rightHand].max > 1
                  end
        return false if blocked
        (Effects::Debuffs.to_h.keys & BLOCKING_DEBUFFS).empty?
      end

      # Whether town justice watches this room, from JUSTICE STATUS. The
      # answer is caught by a hook so it never reaches the client.
      #
      # @return [Boolean]
      def justice?
        answer = nil
        hook = "#{Script.current.name}_justice"
        DownstreamHook.add(hook, proc { |line|
          if line =~ /^You sense that your surroundings are calm|^There is no justice/
            answer = line =~ /surroundings are calm/ ? true : false
            nil
          else
            line
          end
        })
        put 'justice status'
        sleep 0.01 while answer.nil?
        answer
      ensure
        DownstreamHook.remove(hook)
      end

      # The spells the character could cast now within the policy's mana.
      #
      # @param policy [Policy]
      # @return [Array<Hash>] TABLE entries
      def affordable(policy)
        TABLE.select do |entry|
          spell = Spell[entry[:num]]
          spell.known? && spell.affordable? && (mana - spell.mana_cost) >= policy.min_mana
        end
      end

      # @param policy [Policy]
      # @return [Boolean] whether any disabler could be cast, wounds aside
      def any?(policy)
        !affordable(policy).empty?
      end

      # The targets that still need disabling.
      #
      # @param policy [Policy]
      # @return [Array<GameObj>]
      def live_targets(policy)
        GameObj.targets.to_a.reject { |npc| policy.untargetable.include?(npc.name) || npc.status.to_s =~ DISABLED }
      end

      # The spell to cast now, or nil: the forced one if set and castable,
      # else the cheapest that is allowed here (town justice), reaches
      # every target when there are several, and that the target does not
      # shrug off. The justice check is skipped when nothing is castable.
      #
      # @param policy [Policy]
      # @param targets [Array<GameObj>] from .live_targets
      # @param wounds [Boolean] check .can_cast? first
      # @return [Integer, nil] the spell number
      def best(policy, targets: live_targets(policy), wounds: true)
        return nil if wounds && !can_cast?
        candidates = affordable(policy)
        return nil if candidates.empty?
        if policy.forced && Spell[policy.forced].known? && Spell[policy.forced].affordable?
          return policy.forced
        end
        candidates = candidates.select { |e| e[:town_safe] } if justice?

        if targets.size > 1
          candidates = candidates.select { |e| multi_target?(e) }
          MULTI_TARGET_EXCLUSIONS.each do |num, names|
            candidates = candidates.reject { |e| e[:num] == num } if GameObj.npcs.to_a.any? { |n| n.name =~ names }
          end
          preferred = candidates.find { |e| PREFERRED_MULTI.include?(e[:num]) }
          return preferred[:num] if preferred
        elsif (npc = targets.first)
          SINGLE_TARGET_EXCLUSIONS.each do |num, names|
            candidates = candidates.reject { |e| e[:num] == num } if npc.name =~ names
          end
        end
        candidates.min_by { |e| Spell[e[:num]].mana_cost }&.fetch(:num)
      end

      # TARGET RANDOM, learning the names the game refuses so they are not
      # tried again.
      #
      # @param policy [Policy] its untargetable list grows
      # @return [Boolean] whether something was targeted
      def target!(policy)
        put 'target random'
        while (line = get)
          if line =~ /Could not find a valid target\./
            policy.untargetable.push(*GameObj.npcs.to_a.map(&:name))
            policy.untargetable.uniq!
            return false
          elsif line =~ /You are now targeting/
            return true
          end
        end
        false
      end

      # Cast the spell; a Bard's Song of Peace is renewed when already up.
      #
      # @param num [Integer]
      # @return [void]
      def cast!(num)
        spell = Spell[num]
        if num == 1011
          fput 'spell active'
          spell.active? ? fput('renew 1011') : spell.cast
        else
          spell.cast
        end
      end
    end
  end
end

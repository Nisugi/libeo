# frozen_string_literal: true

module EO
  module Herbs
    # Healing with herbs: the character's own wounds from the sack, a dead
    # player's by pouring potions, an escort client's by handing herbs
    # over. eherbs use_herbs (1874), find_herb (1830), cast_spells (1239),
    # track_missing (1855), deader (1433), escort (1507).
    module Heal
      module_function

      # The choices the driver's settings make. use_yaba: yabathilium first
      # for blood. use_potions: potions before plants. no_get: eat from the
      # sack without taking the herb out. blood_only: only health.
      # spellcast_only / ranged_only: only what stops casting or shooting.
      # buy_missing: go and buy a type the sack lacks (needs a buy proc).
      Policy = Struct.new(:use_mending, :use1035, :use650, :use_yaba, :use_potions, :skip_scars, :blood_only,
                          :no_get, :spellcast_only, :ranged_only, :buy_missing, keyword_init: true) do
        def initialize(**opts)
          defaults = members.to_h { |m| [m, false] }
          super(**defaults.merge(opts))
        end
      end

      USE_RESULT = /^You (?:manage to )?take a (?:bite|drink)|You eat your|You must pick the|Why don't you leave some for others|Using your/

      # What came of a healing run: :healed (nothing left to do that the
      # sack can do), :enough (the game refused more from here),
      # :must_take (no_get but the herb has to be picked up).
      Result = Struct.new(:outcome, :missing, keyword_init: true)

      # The herb in the sack for a type, by the policy's preferences. (1830)
      #
      # @param contents [Hash{Symbol => Array<GameObj>}] from Sack#contents
      # @param type [String]
      # @param policy [Policy]
      # @return [GameObj, nil]
      def find(contents, type, policy)
        if type == 'blood' && policy.use_yaba
          yaba = contents[:all].find { |i| i.name =~ /yabathilium/ }
          return yaba if yaba
        end
        form = policy.use_potions ? :drinkable : :edible
        contents[form].find { |i| Table.cures?(i.name, type) } || contents[:all].find { |i| Table.cures?(i.name, type) }
      end

      # The spells that make herbs work better: Sigil of Mending, Song of
      # Tonis, the yierka aspect. (1239)
      #
      # @param policy [Policy]
      # @return [void]
      def cast_spells(policy)
        if policy.use_mending && Spell[9713].known? && Spell[9713].affordable? && !Effects::Buffs.active?('Sigil of Mending')
          waitcastrt?
          Spell[9713].cast
        end
        if policy.use1035 && Spell[1035].known? && Spell[1035].affordable? && !Effects::Buffs.active?('Song of Tonis') && Injuries.can_cast?
          waitcastrt?
          Spell[1035].cast
        end
        return unless policy.use650 && Injuries.can_cast?
        if Spell[650].known? && Spell[650].affordable? && !Spell[650].active? && !Effects::Buffs.active?('Aspect of the Yierka') && !Spell[9039].active?
          waitcastrt?
          multifput('prep 650', 'assume yierka')
        elsif Spell[650].active? && !Effects::Buffs.active?('Aspect of the Yierka') && !Spell[9039].active? && checkmana > 25
          waitcastrt?
          fput 'assume yierka'
        end
      end

      # The areas a missing herb type covers, so the next type is asked for. (1855)
      #
      # @param type [String]
      # @return [Array<String>]
      def skip_for(type)
        case type
        when /head/ then %w[head neck]
        when /organ|missing eye/ then ['torso']
        when /limb/ then ['limbs']
        when /nerve/ then ['nerves']
        else [type]
        end
      end

      # Heal the character from the sack until nothing it holds helps.
      #
      # @param sack [Sack]
      # @param policy [Policy]
      # @param used [Array<String>] ids of herbs taken out, for the driver to put back; grown here
      # @param buy [Proc, nil] given a type, buys it and returns the item in hand, or nil
      # @param before_sack [Proc, nil] run before the sack is reached for (a walk back to it)
      # @return [Result]
      def use(sack:, policy:, used: [], buy: nil, before_sack: nil)
        skip = []
        missing = []
        loop do
          type = policy.blood_only ? 'blood' : Injuries.next_type(skip: skip, skip_scars: policy.skip_scars,
                                                                  spellcast_only: policy.spellcast_only, ranged_only: policy.ranged_only)
          break if type.nil?
          break if policy.blood_only && (Char.health + 7) >= Char.max_health

          drinkable = false
          herb = [GameObj.right_hand, GameObj.left_hand].find { |i| Table.cures?(i.name, type) }
          if herb.nil? && [Wounds.leftArm, Wounds.rightArm].min < 3
            before_sack&.call
            herb = find(sack.contents, type, policy)
            if herb
              drinkable = sack.take(herb) unless policy.no_get && !Table.drinkable?(herb.name)
            end
          end
          if herb.nil? && buy && policy.buy_missing && !policy.blood_only && type !~ /poison|disease/
            herb = buy.call(type)
            drinkable = herb && Table.drinkable?(herb.name)
          end

          if herb.nil?
            missing << type
            skip.concat(skip_for(type))
            Lich::Messaging.msg('warn', "Missing herb for #{type}: #{Table.entries(type).map { |h| h[:name] }.join(', ')}")
            next
          end

          cast_spells(policy)
          used << herb.id unless used.include?(herb.id)
          command = if policy.no_get
                      "eat #{herb.noun}"
                    else
                      drinkable || Table.drinkable?(herb.name) ? "drink my #{herb.noun}" : "eat my #{herb.noun}"
                    end
          result = EO.result(command, USE_RESULT)
          EO.settle
          case result
          when /You must pick the/ then return Result.new(outcome: :must_take, missing: missing)
          when /Why don't you leave some for others?/ then return Result.new(outcome: :enough, missing: missing)
          when nil then raise Guild::Error, 'no result for eating herbs'
          end
        end
        Result.new(outcome: :healed, missing: missing)
      end

      # Heal a dead player by pouring potions on them, APPRAISE between. (1433)
      #
      # @param character [GameObj] the player
      # @param sack [Sack]
      # @param full [Boolean] the non-bleeding wounds and scars too
      # @param used [Array<String>] ids taken out, grown here
      # @return [Symbol] :done, :not_found, or :missing (a potion the sack lacks)
      def deader(character, sack:, full: false, used: [])
        return :done unless character.status =~ /dead/i
        empty_right_hand
        loop do
          lines = EO.command("appraise #{character}", /Usage|^\s*You take a quick appraisal|^You also notice that|^You glance at/, silent: true, quiet: true)
          return :not_found if lines.any? { |l| l =~ /Appraise what|Usage/ }
          injuries = Injuries.appraise(lines, full: full)
          return :done if injuries.empty?

          short = false
          injuries.each do |type|
            herb = [GameObj.right_hand, GameObj.left_hand].find { |i| Table.cures?(i.name, type) && Table.drinkable?(i.name) }
            if herb.nil?
              herb = sack.contents[:drinkable].find { |i| Table.cures?(i.name, type) }
              if herb
                used << herb.id unless used.include?(herb.id)
                result = dothistimeout("get ##{herb.id}", 5, Sack::GET)
                raise Guild::Error, "timeout while trying to get herb (#{herb.name}, #{herb.id})" if result.nil? || result =~ /^Get what\?/
                raise Guild::Error, 'no free hand to get the potion' if result =~ /^You need a free hand for that\./
              end
            end
            if herb
              item = [GameObj.right_hand, GameObj.left_hand].find { |i| i.noun == herb.noun }
              dothistimeout("pour ##{item.id} in #{character}", 2, /you pour|and pour in a small amount/) if item
            else
              short = true
            end
          end
          return :missing if short
        end
      end

      # Hand an escort client the herbs for what LOOK shows. (1507)
      #
      # @param npc [GameObj] the client
      # @param sack [Sack]
      # @param used [Array<String>]
      # @return [Symbol] :done, :fine (nothing wrong), :not_seen, or :timeout
      def escort(npc, sack:, used: [])
        sack.open
        look = dothistimeout("look ##{npc.id}", 10, /^(?:She|He) appears to be in good shape\.|^(?:She|He) has|^I could not find what you were referring to\./)
        return :timeout if look.nil?
        return :not_seen if look =~ /^I could not find what you were referring to\./
        return :fine if look =~ /^(?:She|He) appears to be in good shape\./

        empty_right_hand
        Injuries.escort_injuries(look).each do |type|
          herb = [GameObj.right_hand, GameObj.left_hand].find { |i| Table.cures?(i.name, type) }
          if herb.nil?
            herb = sack.contents[:all].find { |i| Table::KNOWN.any? { |h| h[:name] == i.name && h[:type] == type } }
            next if herb.nil?
            used << herb.id unless used.include?(herb.id)
            result = dothistimeout("get ##{herb.id}", 5, Sack::GET)
            raise Guild::Error, "timeout while trying to get herb (#{herb.name}, #{herb.id})" if result.nil? || result =~ /^Get what\?/
            raise Guild::Error, 'no free hand to get the herb' if result =~ /^You need a free hand for that\./
          end
          dothistimeout("give ##{npc.id}", 10, /accepts your .* hands it back to you|ignores your offer/)
        end
        :done
      end
    end
  end
end

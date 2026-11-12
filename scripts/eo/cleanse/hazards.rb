# frozen_string_literal: true

module EO
  module Cleanse
    # What creatures leave in a room: clouds, magic globes, webs and
    # Onslaught runestones, found in the loot and cleared by spell, by Spell
    # Cleave or Spell Thieve, or by breaking. ecleanse avoid_webs,
    # avoid_globe, avoid_runestone, dispel_cloud, and the
    # main loop's finders.
    module Hazards
      module_function

      # The hazard of a kind in a list of loot, skipping refused ids: a
      # cloud (not the invalid ones nor a gem; the acidic mist only with a
      # breeze known), a magic globe, a runestone, or a web.
      #
      # @param kind [Symbol] :cloud, :globe, :runestone or :web
      # @param loot [Array<GameObj>]
      # @param bad [#include?] refused ids
      # @param breeze [Boolean] a breeze spell is known
      # @return [GameObj, nil]
      def find(kind, loot, bad, breeze: false)
        ok = ->(l) { !bad.include?(l.id) }
        case kind
        when :cloud
          loot.find { |l| l.name.to_s =~ /cloud/i && !INVALID_CLOUDS.include?(l.name.to_s) && l.type.to_s !~ /\bgem\b/i && ok.call(l) } ||
            (breeze ? loot.find { |l| l.name.to_s == ACID_MIST && ok.call(l) } : nil)
        when :globe then loot.find { |l| l.name.to_s =~ MAGIC_GLOBES && ok.call(l) }
        when :runestone then loot.find { |l| l.name.to_s =~ RUNESTONES && ok.call(l) }
        when :web then loot.find { |l| l.noun.to_s =~ /web/i && ok.call(l) }
        end
      end

      def cloud(bad) = find(:cloud, GameObj.loot.to_a, bad, breeze: !Cleanse.spell(:breeze).nil?)

      def globe(bad) = find(:globe, GameObj.loot.to_a, bad)

      def runestone(bad) = find(:runestone, GameObj.loot.to_a, bad)

      def web(bad) = find(:web, GameObj.loot.to_a, bad)

      # @return [Boolean] Spell Cleave or Spell Thieve can be used now
      def cleave? = Lich::Gemstone::CMan.available?('Spell Cleave') || Lich::Gemstone::CMan.available?('Spell Thieve')

      # Whether there is a way to clear this hazard right now.
      #
      # @param obj [GameObj]
      # @param kind [Symbol] :cloud, :globe or :web
      # @param determination [Boolean] see Cleanse.able_to_cast?
      # @return [Boolean]
      def clearable?(obj, kind, determination: false)
        return Cleanse.spell(:breeze) && Cleanse.able_to_cast?(determination: determination) ? true : false if obj.name == ACID_MIST

        spell = Cleanse.spell(kind == :web ? :webs : :dispel)
        (spell && Cleanse.able_to_cast?(determination: determination)) || cleave? ? true : false
      end

      # TARGET a hazard. Only the game's "turn your attention" answer means
      # it can be cast at; a player's own hazard is refused.
      #
      # @param obj [GameObj]
      # @return [Boolean]
      def target(obj)
        dothistimeout("target ##{obj.id}", 2, TARGET_ANSWERS).to_s =~ TARGET_OK ? true : false
      end

      # TARGET a hazard that needs it: not the acidic mist nor the two
      # globes that cannot be targeted.
      #
      # @param obj [GameObj]
      # @return [Boolean] whether it can be cast at
      def aim(obj) = obj.name == ACID_MIST || obj.name =~ UNTARGETABLE_GLOBES || target(obj) ? true : false

      # Clear a cloud, globe or web: aim first, then the breeze at the mist,
      # the spell at the hazard, or Spell Cleave, else Spell Thieve.
      #
      # @param obj [GameObj]
      # @param kind [Symbol] :cloud, :globe or :web
      # @param determination [Boolean]
      # @param aimed [Boolean] already aimed at
      # @return [Symbol] :breeze, :dispelled, :cleaved, :thieved, or
      #   :untargetable (add it to the bad targets), :unaffordable, :no_means
      def clear(obj, kind, determination: false, aimed: false)
        acid = obj.name == ACID_MIST
        return :untargetable unless aimed || aim(obj)

        able = Cleanse.able_to_cast?(determination: determination)
        if acid
          breeze = Cleanse.spell(:breeze)
          return :no_means unless breeze && able
          return :unaffordable unless breeze.affordable?

          breeze.num == 912 ? breeze.force_incant : breeze.cast("at ##{obj.id}")
          return :breeze
        end
        spell = Cleanse.spell(kind == :web ? :webs : :dispel)
        if spell && able
          Lich::Gemstone::Mana.pulse(spell)
          return :unaffordable unless spell.affordable?

          spell.cast("at ##{obj.id}")
          :dispelled
        elsif Lich::Gemstone::CMan.available?('Spell Cleave')
          fput "cman scleave ##{obj.id}"
          :cleaved
        elsif Lich::Gemstone::CMan.available?('Spell Thieve')
          fput "cman sthieve ##{obj.id}"
          :thieved
        else
          :no_means
        end
      end

      # TARGET an Onslaught runestone and ATTACK it until it shatters or
      # goes, five swings at most.
      #
      # @param obj [GameObj]
      # @param aimed [Boolean] already targeted
      # @return [Symbol] :shattered, :gone, :untargetable or :standing
      def break_runestone(obj, aimed: false)
        return :untargetable unless aimed || target(obj)

        5.times do
          waitrt?
          lines = Lich::Util.issue_command("attack ##{obj.id}", /You bash/, /Roundtime: /, timeout: 2, usexml: false)
          return :shattered if lines.any? { |line| line =~ /It crashes to the ground and shatters into pale dust/ }
          return :gone unless GameObj.loot.to_a.any? { |l| l.id == obj.id }
        end
        :standing
      end
    end
  end
end

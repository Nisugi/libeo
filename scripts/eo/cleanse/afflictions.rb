# frozen_string_literal: true

module EO
  module Cleanse
    # What is wrong with the character, and the cure: poison and disease
    # cast away, magical debuffs dispelled, a root or press retreated from,
    # a stun or a web broken. Each answers what it did. ecleanse
    # remove_poison (1511), remove_disease (1448), remove_magical (1487),
    # remove_grounded (1464), remove_stun (1540), remove_web_bound (1594),
    # stunman_perform (1666), settle_room (1645).
    module Afflictions
      module_function

      ESCAPE_ROOMS = ['The Belly of the Beast', 'Ooze, Innards'].freeze

      # @return [Boolean] poisoned, Wall of Thorns included
      def poisoned? = checkpoison || Status.thorned? ? true : false

      # @return [Boolean] a root or a press
      def grounded? = Effects::Debuffs.to_h.keys.any? { |k| k.to_s =~ /Rooted|Pressed/ }

      # @return [Boolean] a debuff a dispel clears
      def magical? = Effects::Debuffs.to_h.keys.any? { |k| k.to_s =~ DEBUFFS }

      # Whether a cast for +job+ can go out now: the spell known, the wounds
      # allowing, and mana enough after a pulse.
      #
      # @param job [Symbol] :poison, :disease or :dispel
      # @param determination [Boolean] see Cleanse.able_to_cast?
      # @return [Boolean]
      def curable?(job, determination: false)
        spell = Cleanse.spell(job)
        return false unless spell && Cleanse.able_to_cast?(determination: determination)

        Lich::Gemstone::Mana.pulse(spell)
        spell.affordable?
      end

      # Cast 114 or 113 until the poison or disease is gone or the spell is
      # unaffordable.
      #
      # @param kind [Symbol] :poison or :disease
      # @param determination [Boolean] see Cleanse.able_to_cast?
      # @return [Symbol] :cured, :still (out of mana with it still there),
      #   :unaffordable, :cannot_cast or :no_spell
      def cure(kind, determination: false)
        spell = Cleanse.spell(kind)
        return :no_spell if spell.nil?
        return :cannot_cast unless Cleanse.able_to_cast?(determination: determination)

        Lich::Gemstone::Mana.pulse(spell)
        return :unaffordable unless spell.affordable?

        afflicted = kind == :poison ? -> { poisoned? } : -> { checkdisease }
        while afflicted.call && spell.affordable?
          spell.cast
          EO.settle
          # the thorns poison leaves the debuff list only once it is read again
          Lich::Util.issue_command('spell active debuff', /<dialogData id='Debuffs'/, silent: true, quiet: true) if kind == :poison && Status.thorned?
        end
        afflicted.call ? :still : :cured
      end

      # Channel the dispel open at oneself, once for each debuff it clears.
      #
      # @param determination [Boolean]
      # @return [Symbol] :dispelled, :unaffordable, :cannot_cast or :no_spell
      def dispel(determination: false)
        spell = Cleanse.spell(:dispel)
        return :no_spell if spell.nil?
        return :cannot_cast unless Cleanse.able_to_cast?(determination: determination)

        cast = false
        DISPELLABLE.each do |debuff|
          next unless Effects::Debuffs.active?(debuff)

          Lich::Gemstone::Mana.pulse(spell)
          fput 'stand' until standing?
          EO.settle
          next unless spell.affordable?

          spell.force_incant('channel open')
          cast = true
        end
        cast ? :dispelled : :unaffordable
      end

      # @return [Boolean] Retreat with the stamina, or Escape Artist for a root
      def ungroundable?
        return Char.stamina >= 11 if Lich::Gemstone::CMan.known?('Retreat')

        Effects::Debuffs.active?('Rooted') && Lich::Gemstone::Feat.available?('escapeartist', min_rank: 5) && Char.stamina >= 15
      end

      # CMAN RETREAT out of a root or press, the target cleared and put
      # back; else Escape Artist out of a root.
      #
      # @return [Symbol] :retreat, :escape or :no_means
      def unground
        if Lich::Gemstone::CMan.known?('Retreat')
          done = false
          %w[Rooted Pressed].each do |debuff|
            next unless Effects::Debuffs.active?(debuff) && Char.stamina >= 11

            EO.settle
            fput 'stand' until standing?
            EO.settle
            target = XMLData.current_target_id
            fput 'target clear'
            fput 'cman retreat'
            fput "target ##{target}" if target
            done = true
          end
          return done ? :retreat : :no_means
        end
        return :no_means unless ungroundable?

        Lich::Gemstone::Feat.use('escapeartist')
        :escape
      end

      # The first way out of a stun the policy allows and the character has,
      # in ecleanse's order. Berserk and the Stun Maneuvers are no use in the
      # rooms that are a creature's insides.
      #
      # @param policy [Policy]
      # @return [Symbol, nil] :barkskin, :berserk, :shout_1040, :beseech,
      #   :stance1, :stance2, :flee, :hide; nil for none
      def stun_means(policy)
        if policy.use_stunned_barkskin && Spell[605].known? && !Effects::Cooldowns.active?('Barkskin: Commune') &&
           !Effects::Cooldowns.active?('Barkskin') && !Spell[605].active? && Skills.slblessings >= 15
          Lich::Gemstone::Mana.pulse(605)
          return :barkskin if Spell[605].available?
        end
        escape_room = ESCAPE_ROOMS.any? { |title| checkroom(title) }
        return :berserk if !escape_room && policy.use_berserk_stunned && Lich::Gemstone::CMan.available?('Berserk')
        if policy.use_stunned1040 && Spell[1040].known?
          Lich::Gemstone::Mana.pulse(1040)
          return :shout_1040 if Spell[1040].available?
        end
        if policy.use_1635 && Spell[1635].known?
          Lich::Gemstone::Mana.pulse(1635)
          return :beseech if Spell[1635].available?
        end
        return nil if escape_room

        stunman = ->(rank) { Lich::Gemstone::CMan.available?('Stun Maneuvers', min_rank: rank) }
        return :stance1 if policy.use_stance1 && stunman.call(3)
        return :stance2 if policy.use_stance2 && stunman.call(4)
        return :flee if policy.use_flee && stunman.call(5)
        return :hide if policy.use_hide && stunman.call(5) && !checkhidden

        nil
      end

      # Break a stun the way stun_means picked, and wait it out.
      #
      # @param means [Symbol] from stun_means
      # @return [Symbol] the means used
      def unstun(means)
        case means
        when :barkskin
          EO.settle
          fput 'commune barkskin' if checkstunned
          sleep 0.1 while checkstunned
        when :berserk
          Spell[9607].cast
          sleep 1
          sleep 0.2 while Spell[9607].active?
        when :shout_1040 then fput 'shout 1040'
        when :beseech then fput 'beseech'
        else stunman(means.to_s)
        end
        means
      end

      # A Stun Maneuver: stand first, then the stance, or flee the room, or
      # hide, until it takes or the stun is over (stunman_perform 1666).
      #
      # @param type [String] stance1, stance2, flee or hide
      # @return [void]
      def stunman(type)
        stunman_stand
        case type
        when 'stance1', 'stance2' then Lich::Gemstone::CMan.use('stunman', type)
        when 'flee'
          room = Room.current.id
          until Room.current.id != room || !checkstunned
            stunman_stand
            Lich::Gemstone::CMan.use('stunman', 'flee')
            sleep 0.5
          end
          Lich::Gemstone::CMan.use('stunman', 'stance2')
        when 'hide'
          until checkhidden || !checkstunned
            stunman_stand
            Lich::Gemstone::CMan.use('stunman', 'hide')
            EO.settle
          end
        end
        sleep 0.1 while checkstunned
      end

      # @api private
      def stunman_stand
        until standing? || !checkstunned
          Lich::Gemstone::CMan.use('stunman', 'stand')
          EO.settle
        end
      end

      # The first way out of a web or bind the character has: 1040, berserk
      # (when the policy allows), 1635, Escape Artist.
      #
      # @param policy [Policy]
      # @return [Symbol, nil] :shout_1040, :berserk, :beseech, :escape; nil for none
      def web_means(policy)
        Lich::Gemstone::Mana.pulse(1040) if Spell[1040].known?
        return :shout_1040 if Spell[1040].known? && Spell[1040].affordable?
        return :berserk if policy.use_berserk_webbed && Lich::Gemstone::CMan.known?('Berserk') && Char.stamina >= 21
        return :beseech if policy.use_1635 && Spell[1635].known? && Spell[1635].affordable?
        return :escape if Lich::Gemstone::Feat.available?('escapeartist', min_rank: 5) && Char.stamina >= 15

        nil
      end

      # Break a web or bind the way web_means picked.
      #
      # @param means [Symbol] from web_means
      # @return [Symbol] the means used
      def unweb(means)
        case means
        when :shout_1040 then fput 'shout 1040'
        when :berserk
          Spell[9607].cast
          sleep 1
          sleep 0.2 while Spell[9607].active?
        when :beseech then fput 'beseech'
        when :escape then Lich::Gemstone::Feat.use('escapeartist')
        end
        means
      end

      # One spell to make a room with creatures in it safer before a
      # recovery, the first the policy allows: Wall of Force (140), 619,
      # 709 (not with tentacles about), Wizard's Shield (919), 9811.
      #
      # @param policy [Policy]
      # @return [Symbol] :settled, :quiet (nothing to fight), :cannot_cast or :no_means
      def settle_room(policy)
        return :quiet if GameObj.targets.to_a.empty?
        return :cannot_cast unless Cleanse.able_to_cast?(determination: policy.determination)

        num = if policy.use_140 && Spell[140].known? && !Effects::Buffs.active?('Wall of Force') && !Effects::Cooldowns.active?('Wall of Force') then 140
              elsif policy.use_619 && Spell[619].known? then 619
              elsif policy.use_709 && Spell[709].known? && GameObj.npcs.to_a.none? { |c| c.noun =~ EO::Wander::APPENDAGE } then 709
              elsif policy.use_919 && Spell[919].known? && !Effects::Buffs.active?("Wizard's Shield") && !Effects::Cooldowns.active?("Wizard's Shield") then 919
              elsif policy.use_9811 && Spell[9811].known? then 9811
              end
        return :no_means if num.nil?

        Lich::Gemstone::Mana.pulse(num) unless num == 9811
        Spell[num].cast if Spell[num].affordable?
        :settled
      end
    end
  end
end

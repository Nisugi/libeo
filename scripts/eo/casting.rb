# frozen_string_literal: true

module EO
  # Casting: how many casts at once a character's lore allows, casting at
  # a target and what the game said, waiting for the mana or stamina a
  # cast needs (and the society abilities that make it), reading the
  # spells active on another character, and manna bread. ewaggle 2.2.0
  # Casting: cast_spell, check_mana, check_mana_col,
  # safe_to_wrack, check_mana_gos, check_mana_voln,
  # check_stamina, max_multicast; Ewaggle: summon_bread,
  # eat_bread, get_target_info.
  module Casting
    module_function

    REFUSED_HERE = /^Be at peace my child, there is no need for spells of war in here\.$|Spells of War cannot be cast/
    HINDERED = /^\[Spell Hindrance for/
    # Casts tried while hindrance stops them, before giving up (bigshot's cast_spell max_attempts).
    MAX_HINDERED = 3
    WRACK_SIGN = /^You (?:touch|scratch|rub|tap|point to) your (?:right|left) (?:eyebrow|nostril|earlobe|shoulder|cheek) with your (?:right|left) (?:pinky|forefinger|thumb|index finger)/

    # How many casts of +spell+ one CAST may carry, by the character's lore
    # ranks in the circles that spell draws on: one more per 25 ranks.
    #
    # @param spell [Spell]
    # @return [Integer]
    def max_multicast(spell)
      circle = spell.circle.to_i
      ranks = case Stats.prof
              when 'Wizard' then Skills.emc
              when /^Cleric$|^Ranger$|^Paladin$/ then Skills.smc
              when /^Empath$|^Monk$|^Bard$/
                case circle
                when 1, 2 then Skills.smc + (Skills.mmc / 2)
                when 11 then [Skills.mmc, Skills.smc].max + ([Skills.mmc, Skills.smc].min / 2)
                when 12 then Skills.mmc + (Skills.smc / 2)
                when 4 then Skills.emc + (Skills.mmc / 2)
                else 0
                end
              when /^Sorcerer$|^Warrior$|^Rogue$/
                case circle
                when 4 then Skills.emc + (Skills.smc / 2)
                when 1 then Skills.smc + (Skills.emc / 2)
                when 7 then [Skills.emc, Skills.smc].max + ([Skills.emc, Skills.smc].min / 2)
                else 0
                end
              else 0
              end
      (ranks / 25) + 1
    end

    # Cast a spell, at a target or at oneself, retrying through spell
    # hindrance.
    #
    # @param spell [Spell]
    # @param target [String, nil] a name, or nil for oneself
    # @param multicast [Integer]
    # @param argument [String, nil] what a self-cast takes (a sonic item's name)
    # @return [Symbol] :success, :refused_here (sanctuary or a no-war room),
    #   :bad_target, or :hindered (hindrance stopped every one of MAX_HINDERED tries)
    def cast(spell, target: nil, multicast: 1, argument: nil)
      MAX_HINDERED.times do
        result = if target.nil?
                   if argument then spell.cast(argument)
                   elsif multicast > 1 then spell.cast(multicast.to_s)
                   else spell.cast
                   end
                 else
                   spell.cast(multicast > 1 ? "at #{target} #{multicast}" : "at #{target}")
                 end
        return :refused_here if result.to_s =~ REFUSED_HERE
        return :bad_target if result.to_s == 'Cast at what?'
        next if result.to_s =~ HINDERED
        return :success
      end
      :hindered
    end

    # How a character makes mana when short. reserve: mana never spent.
    # source: :wracking (Sign of Wracking, Council of Light), :power (Sigil
    # of Power, Guardians of Sunfist), :voln (Symbol of Mana), or nil to wait.
    # bail: give up instead of waiting. wander_to_wrack: walk until no
    # stranger is watching before wracking.
    Resources = Struct.new(:reserve, :source, :bail, :wander_to_wrack, keyword_init: true) do
      def initialize(reserve: 0, source: nil, bail: false, wander_to_wrack: false)
        super(reserve: reserve.to_i, source: source, bail: bail, wander_to_wrack: wander_to_wrack)
      end
    end

    # @return [Boolean] mana enough for +spell+ times +n+, keeping the reserve
    def mana_for?(spell, n, resources)
      cost = spell.mana_cost(multicast: n) + resources.reserve
      spell.affordable?(multicast: n) && (spell.mana_cost.zero? || Char.mana >= cost)
    end

    # @return [Boolean] stamina enough, for a character casting from stamina (mental acuity)
    def stamina_for?(spell, n, resources)
      spell.affordable?(multicast: n) && (spell.mana_cost.zero? || Char.stamina >= (spell.mana_cost(multicast: n) * 2) + resources.reserve)
    end

    # Wait until +spell+ times +n+ can be cast, making mana the way the
    # resources say. Releases a prepared spell before waiting.
    #
    # @param spell [Spell]
    # @param n [Integer]
    # @param resources [Resources]
    # @return [Symbol] :ready, :bail (out and told to give up), or
    #   :no_favor (Symbol of Mana refused for lack of favor; the caller
    #   should stop using it)
    def ready(spell, n, resources)
      if Object.const_defined?(:Feat) && Feat.known?(:mental_acuity)
        return :ready if stamina_for?(spell, n, resources)
        return :bail if resources.bail
        Lich::Messaging.msg('info', 'waiting for stamina...')
        wait_until { stamina_for?(spell, n, resources) }
        return :ready
      end
      return :ready if mana_for?(spell, n, resources) || !spell.mana_cost.positive?

      case resources.source
      when :wracking then wrack(spell, n, resources)
      when :power then sigil_of_power(spell, n, resources)
      when :voln then symbol_of_mana(spell, n, resources)
      else
        fput 'release' unless checkprep == 'None'
        return :bail if resources.bail
        Lich::Messaging.msg('info', 'waiting for mana...')
        wait_until { mana_for?(spell, n, resources) }
        :ready
      end
    end

    # @api private
    def wrack(spell, n, resources)
      wracking = Spell[9918]
      punishment = Spell[9012]
      until mana_for?(spell, n, resources)
        waitrt?
        waitcastrt?
        if wracking.affordable? && !punishment.active?
          if (invisible? || hidden? || !checkpcs || safe_to_wrack?) && !Room.current.tags.include?('no-magic')
            wracking.cast
          elsif resources.wander_to_wrack
            start = Room.current
            visited = []
            20.times do
              break if safe_to_wrack? && !Room.current.tags.include?('no-magic')
              EO.wander(visited)
            end
            wracking.cast if wracking.affordable? && !punishment.active?
            EO.go2(start.id) unless start.id == Room.current.id
          else
            # someone who might not like it is watching; wait for mana instead
            return :bail if resources.bail
            wait_until { mana_for?(spell, n, resources) }
          end
        else
          fput 'release' unless checkprep == 'None'
          return :bail if resources.bail
          Lich::Messaging.msg('info', 'waiting for mana or spirit...')
          wait_until { mana_for?(spell, n, resources) || wracking.affordable? }
        end
      end
      :ready
    end

    # @api private
    def sigil_of_power(spell, n, resources)
      power = Spell[9718]
      until mana_for?(spell, n, resources)
        if power.affordable?
          power.cast
          sleep 0.2
        else
          fput 'release' unless checkprep == 'None'
          return :bail if resources.bail
          Lich::Messaging.msg('info', 'waiting for mana...')
          wait_until { mana_for?(spell, n, resources) || power.affordable? }
        end
      end
      :ready
    end

    # @api private
    def symbol_of_mana(spell, n, resources)
      until mana_for?(spell, n, resources)
        waitrt?
        waitcastrt?
        if !Effects::Cooldowns.active?('Symbol of Mana')
          return :no_favor if Spell[9813].cast.to_s =~ /^You strain to perform the symbol/
          sleep 0.2
        else
          fput 'release' unless checkprep == 'None'
          return :bail if resources.bail
          Lich::Messaging.msg('info', 'waiting for mana or mana cooldown...')
          wait_until { mana_for?(spell, n, resources) || !Effects::Cooldowns.active?('Symbol of Mana') }
        end
      end
      :ready
    end

    # Whether every player here is Council of Light and acknowledges the
    # sign, so Sign of Wracking will not be seen by the uninitiated.
    #
    # @return [Boolean]
    def safe_to_wrack?
      lines = Lich::Util.issue_command('sign of recognition', WRACK_SIGN, usexml: true, silent: true, quiet: true)
      knowing = lines.filter_map { |line| line[/noun="(.*?)">.*?acknowledges your sign/, 1] }
      (checkpcs.to_a - knowing).empty?
    end

    # The spells active on a character and the minutes left on each, from
    # SPELL ACTIVE. Indefinite reads as 599.
    #
    # @param target [String]
    # @return [Hash] spell number (as a string) => minutes, plus 'sharing'
    #   => false when the character keeps spell information private
    def active_on(target)
      lines = Lich::Util.quiet_command_xml("spell active #{target}", /currently has the following active effects|has spell sharing disabled\./)
      return { 'sharing' => false } if lines.any? { |l| l =~ /has spell sharing disabled/ }

      found = { 'sharing' => true }
      lines.each do |line|
        next unless line =~ /\s+([A-z0-9\s'()\-]+) \.* (([0-9]+):([0-9]+):([0-9]+)|Indefinite)$/
        name = Regexp.last_match(1).strip
        minutes = Regexp.last_match(2) == 'Indefinite' ? 599.0 : (Regexp.last_match(3).to_i * 60) + Regexp.last_match(4).to_i + (Regexp.last_match(5).to_i / 60.0)
        name = 'Raise Dead Cooldown' if name == 'Raise Dead Recovery'
        name = 'Mage Armor' if name =~ /Mage Armor - /
        name = 'Cloak of Shadows' if name =~ /Cloak of Shadows - /
        spell = Spell.list.find { |s| s.name == name || s.num.to_s == name }
        found[spell.num.to_s] = minutes if spell
      end
      found
    end

    # Cast 203 and return the bread: whatever new item lands in hand, so a
    # custom food noun just works.
    #
    # @param resources [Resources]
    # @return [GameObj, nil]
    def summon_bread(resources = Resources.new)
      before = [GameObj.right_hand, GameObj.left_hand].map(&:id)
      ready(Spell[203], 1, resources)
      cast(Spell[203])
      20.times do
        bread = [GameObj.right_hand, GameObj.left_hand].find { |obj| obj.id && !before.include?(obj.id) }
        return bread if bread
        sleep 0.1
      end
      nil
    end

    # Eat manna bread unless Manna has more than ten seconds to run.
    #
    # @param resources [Resources]
    # @return [Boolean] whether bread was eaten
    def eat_bread(resources = Resources.new)
      return false if Effects::Spells.time_left('Manna') > 10
      empty_hand
      bread = summon_bread(resources)
      if bread
        3.times do
          break unless Hands.holding?(bread)
          fput "gobble ##{bread.id}"
          sleep 0.2
        end
      end
      20.times do
        break if Effects::Spells.time_left('Manna').positive?
        sleep 0.1
      end
      fill_hand
      !bread.nil?
    end

    # Summon bread and leave it on the ground for someone else.
    #
    # @param resources [Resources]
    # @return [void]
    def drop_bread(resources = Resources.new)
      empty_hand
      bread = summon_bread(resources)
      if bread
        3.times do
          break unless Hands.holding?(bread)
          fput "drop ##{bread.id}"
          sleep 0.2
        end
      end
      fill_hand
    end
  end
end

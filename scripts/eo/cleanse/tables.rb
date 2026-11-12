# frozen_string_literal: true

module EO
  # Clearing what the game does to a character: poison, disease, stuns,
  # webs and binds, roots, magical debuffs, the hazards creatures leave in
  # a room, a disarmed weapon, hive traps, the itchy curse and the infected
  # wound. From ecleanse 2.3.7.
  module Cleanse
    module_function

    # The debuffs a dispel channelled at oneself clears (remove_magical 1337).
    DISPELLABLE = ['Confusion', 'Vertigo', 'Sounds', 'Thought Lash', 'Mindwipe', 'Pious Trial', 'Powersink'].freeze
    DEBUFFS = Regexp.union(DISPELLABLE)
    # The loot names that are a magic globe to dispel; the first two cannot
    # be targeted and are cast at as they are (avoid_globe 734).
    MAGIC_GLOBES = /silvery blue globe|spiraling ghostly rift|chaotic spatial anomaly/i
    UNTARGETABLE_GLOBES = /silvery blue globe|spiraling ghostly rift/
    RUNESTONES = /pale hovering runestone/i
    # Clouds a dispel does not answer. The acidic mist takes a breeze (912, 612).
    INVALID_CLOUDS = ['cloud of acidic mist', 'cloud of thick ethereal fog'].freeze
    ACID_MIST = 'cloud of acidic mist'
    # The wounds the Sigil of Determination is worth casting for.
    INJURY_LOCATIONS = %w[leftHand rightHand leftArm rightArm leftEye rightEye nsys head].freeze
    # Every answer TARGET gives to a hazard, and the one that means it took.
    TARGET_ANSWERS = Regexp.union(
      /^You can only target creatures, players, and creature-created hazards\.$/,
      /^Usage:  TARGET \{player\|creature\|hazard\}$/,
      /^You are now targeting .+\.$/,
      /^You are unable to discern the origin of .+\.$/,
      /^You discern that you are the origin of .+ and decide against targeting yourself\.$/,
      /^Suspecting that .+ is the origin of .+, you turn your attention towards \w+!$/
    )
    TARGET_OK = /^Suspecting that .+ is the origin of .+, you turn your attention towards \w+!$/

    # The choices a driver's settings make, under ecleanse's setting names.
    # Stuns: barkskin, berserk, 1040, 1635 (beseech), the Stun Maneuvers
    # (stance1, stance2, flee, hide). Webs: berserk. Settling a room before
    # a recovery: 140, 619, 709, 919, 9811. Recovering: 213, 1011.
    # determination: cast the Sigil of Determination to cast through wounds.
    Policy = Struct.new(:use_stunned_barkskin, :use_berserk_stunned, :use_stunned1040, :use_1635,
                        :use_stance1, :use_stance2, :use_flee, :use_hide, :use_berserk_webbed, :avoid_webs,
                        :use_140, :use_619, :use_709, :use_919, :use_9811, :use_213, :use_1011,
                        :determination, keyword_init: true) do
      def initialize(**opts)
        defaults = members.to_h { |m| [m, false] }
        super(**defaults.merge(opts.slice(*members)))
      end
    end

    # The spell this character has for a job, the first known in
    # preference order (Data 224-228), or nil.
    SPELLS = { poison: [114], disease: [113], dispel: [417, 1218, 119], webs: [209, 417, 1218, 119], breeze: [912, 612] }.freeze

    # @param job [Symbol] a SPELLS key
    # @return [Spell, nil]
    def spell(job)
      SPELLS.fetch(job).map { |n| Spell[n] }.compact.find(&:known?)
    end

    # Whether the wounds allow a cast (Lich's Injured). With +determination+
    # the Sigil of Determination is cast when it would lift the block.
    #
    # @param determination [Boolean]
    # @return [Boolean]
    def able_to_cast?(determination: false)
      return true if Lich::Gemstone::Injured.able_to_cast?
      return false unless determination && sigil?

      cast_sigil
      Lich::Gemstone::Injured.able_to_cast?
    end

    # @return [Boolean] a wound at rank two or worse where the sigil helps
    def sigil_wounds?
      INJURY_LOCATIONS.any? { |limb| XMLData.injuries.dig(limb, 'wound').to_i > 1 }
    end

    # @return [Boolean] the sigil is known, affordable and not up
    def sigil?
      s = Spell['Sigil of Determination']
      s&.known? && s.affordable? && !Effects::Buffs.active?('Sigil of Determination') ? true : false
    end

    # @return [Boolean] whether the sigil was cast
    def cast_sigil
      return false unless sigil?

      Spell['Sigil of Determination'].cast
      true
    end

    # "...wait N seconds": the command did not run.
    WAIT = /\.\.\.wait (\d+) [Ss]ec(?:onds)?\./i

    # A command's answer, sent again after a "...wait". Unlike EO.command a
    # Roundtime in the answer is part of it, not a refusal (ecleanse
    # get_command 1706).
    #
    # @param command [String]
    # @param regex [Regexp] what starts the answer
    # @return [Array<String>]
    def command(command, regex, silent: nil, quiet: false)
      loop do
        lines = Lich::Util.issue_command(command, Regexp.union(regex, WAIT), silent: silent, quiet: quiet)
        return lines unless lines.any? { |line| line.match?(WAIT) }

        EO.settle
      end
    end

    # Ids the game refused to TARGET, so a hazard is not tried again; the
    # oldest go past +max+ (CappedCollection 198).
    class BadTargets
      def initialize(max = 200)
        @max = max
        @ids = []
      end

      def <<(id)
        @ids << id.to_s
        @ids.shift while @ids.size > @max
        self
      end

      def include?(id) = @ids.include?(id.to_s)
    end
  end
end

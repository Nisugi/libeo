# frozen_string_literal: true

module EO
  module Herbs
    # What the character's wounds want: the next herb type to use and
    # whether there is anything to heal; and what another character's
    # wounds look like from outside. Whether spells can still be cast is
    # Lich's Injured.able_to_cast?. eherbs next_herb_type, status_check,
    # the start-up check, appraise_character, escort.
    module Injuries
      module_function

      AREAS = %w[head neck torso limbs nerves].freeze

      # @return [Boolean] wounded, scarred or short of health enough to heal (3537)
      def hurt?
        AREAS.any? { |a| Wounds.send(a).positive? || Scars.send(a).positive? } || (Char.health + 7) < Char.max_health
      end

      # The herb type to use next, by the worst thing wrong, or nil when
      # nothing is. skip lists areas (and 'blood', 'poison', 'disease') with
      # no herb for them, so they are not asked again.
      #
      # @param skip [Array<String>]
      # @param skip_scars [Boolean] leave level-one scars alone
      # @param spellcast_only [Boolean] only what stops casting: head, eyes, nerves, arms
      # @param ranged_only [Boolean] only what stops a bow: arms
      # @return [String, nil]
      def next_type(skip: [], skip_scars: false, spellcast_only: false, ranged_only: false)
        return 'blood' if Char.percent_health < 50 && !skip.include?('blood')
        return 'poison' if checkpoison && !skip.include?('poison')
        return 'disease' if checkdisease && !skip.include?('disease')

        type = if spellcast_only || ranged_only
                 casting_type(skip, spellcast_only)
               else
                 general_type(skip, skip_scars)
               end
        return type if type
        return 'blood' if (Char.health + 7) < Char.max_health && !skip.include?('blood')
        nil
      end

      # @api private
      def general_type(skip, skip_scars)
        areas = AREAS - skip
        areas.each { |a| return "major #{Table::AREAS[a]} wound" if Wounds.send(a) > 1 }
        areas.each { |a| return "minor #{Table::AREAS[a]} wound" if Wounds.send(a) == 1 }
        return 'severed limb' if Scars.limbs == 3 && !skip.include?('limbs')
        return 'missing eye' if (Scars.reye == 3 || Scars.leye == 3) && !skip.include?('torso')
        areas.each { |a| return "major #{Table::AREAS[a]} scar" if Scars.send(a) > 1 }
        areas.each { |a| return "minor #{Table::AREAS[a]} scar" if Scars.send(a) == 1 && !skip_scars } unless skip_scars
        nil
      end

      # @api private
      def casting_type(skip, spellcast)
        arms = %w[leftArm leftHand rightArm rightHand]
        checks = { 'limbs' => arms }
        checks.merge!('head' => ['head'], 'torso' => %w[leftEye rightEye], 'nerves' => ['nsys']) if spellcast
        (%w[limbs head nerves torso] - skip).each do |area|
          parts = checks[area] or next
          worst = parts.map { |p| Wounds.send(p) }.max
          return "major #{Table::AREAS[area]} wound" if worst > 1
          return "minor #{Table::AREAS[area]} wound" if worst == 1
        end
        return 'severed limb' if arms.map { |p| Scars.send(p) }.max == 3 && !skip.include?('limbs')
        return 'missing eye' if spellcast && [Scars.rightEye, Scars.leftEye].max == 3 && !skip.include?('torso')
        (%w[limbs head nerves torso] - skip).each do |area|
          parts = checks[area] or next
          return "major #{Table::AREAS[area]} scar" if parts.map { |p| Scars.send(p) }.max > 1
        end
        nil
      end

      # Which wound types the character has, by name (3355).
      #
      # @return [Hash{String => Boolean}]
      def status
        limbs_w = [Wounds.rhand, Wounds.rarm, Wounds.rleg, Wounds.lhand, Wounds.larm, Wounds.lleg]
        limbs_s = [Scars.rhand, Scars.rarm, Scars.rleg, Scars.lhand, Scars.larm, Scars.lleg]
        {
          'poison'            => checkpoison,
          'disease'           => checkdisease,
          'blood'             => (Char.health + 7) < Char.max_health,
          'minor head wound'  => [Wounds.head, Wounds.neck].include?(1),
          'major head wound'  => [Wounds.head, Wounds.neck].max > 1,
          'minor head scar'   => [Scars.head, Scars.neck].include?(1),
          'major head scar'   => [Scars.head, Scars.neck].max > 1,
          'minor nerve wound' => Wounds.nerves == 1,
          'major nerve wound' => Wounds.nerves > 1,
          'minor nerve scar'  => Scars.nerves == 1 && Wounds.nerves.zero?,
          'major nerve scar'  => Scars.nerves > 1 && Wounds.nerves.zero?,
          'minor organ wound' => [Wounds.chest, Wounds.torso, Wounds.back].include?(1),
          'major organ wound' => [Wounds.chest, Wounds.torso, Wounds.back].max > 1,
          'minor organ scar'  => [Scars.chest, Scars.torso, Scars.back].include?(1),
          'major organ scar'  => [Scars.chest, Scars.torso, Scars.back].max > 1,
          'missing eye'       => [Scars.reye, Scars.leye].max > 2,
          'minor limb wound'  => limbs_w.include?(1),
          'major limb wound'  => limbs_w.max > 1,
          'minor limb scar'   => limbs_s.include?(1),
          'major limb scar'   => limbs_s.include?(2),
          'severed limb'      => limbs_s.include?(3),
          'raisedead'         => checkdead,
          'lifekeep'          => checkdead,
        }
      end

      # Another character's wounds from APPRAISE, as herb types to pour on
      # them. The bleeding wounds first; with +full+, the rest (1397).
      #
      # @param lines [Array<String>] the APPRAISE answer
      # @param full [Boolean]
      # @return [Array<String>]
      def appraise(lines, full: false)
        found = []
        add = ->(type, pattern) { found << type if lines.any? { |l| l =~ pattern } }
        add.call('major head wound', /minor lacerations about the head|bleeding from the head|moderate bleeding from (?:his|her) neck|severe head trauma and bleeding from the ears|snapped bones and serious bleeding from the neck/)
        add.call('major organ wound', /deep lacerations|deep gashes and serious bleeding/)
        add.call('major limb wound', /a completely severed|a fractured and bleeding/)
        return found unless full

        add.call('major organ wound', /a (blinded|swollen) (right|left) eye/)
        add.call('major nerve wound', /a case of (uncontrollable|sporadic) convulsions/)
        add.call('minor head wound', /minor bruises about the head|minor bruises on (?:his|her) neck/)
        add.call('minor organ wound', /minor cuts and bruises on (?:his|her) (chest|abdomen|back)|a bruised (right|left) eye/)
        add.call('minor limb wound', /some minor cuts and bruises on (?:his|her) (right|left)/)
        add.call('minor nerve wound', /a strange case of muscle twitching/)
        return found unless found.empty?

        add.call('major head scar', /several facial scars|old mutilation wounds about (?:his|her) head|some old neck wounds|terrible scars from some serious neck injury/)
        add.call('major nerve scar', /constant muscle spasms|a very difficult time with muscle control/)
        add.call('major organ scar', /several painful-looking scars across|terrible, permanent mutilation of|severe bruises and swelling around/)
        add.call('missing eye', /a missing (right|left) eye/)
        add.call('major limb scar', /a mangled (right|left) (leg|arm|hand)/)
        add.call('severed limb', /a missing (right|left) (leg|arm|hand)/)
        add.call('minor head scar', /a scar across (?:his|her) (face|neck)/)
        add.call('minor nerve scar', /developed slurred speech/)
        add.call('minor organ scar', /an old battle scar across (?:his|her) (chest|abdominal area|back)|a black-and-blue (right|left) eye/)
        add.call('minor limb scar', /old battle scars on (?:his|her) (right|left) (leg|arm|hand)/)
        found
      end

      # An escort client's wounds from LOOK, as the herbs to hand over, in
      # order (1529).
      ESCORT_INJURIES = {
        /severe head trauma and bleeding from the ears/                        => ['major head wound', 'major head wound', 'minor head wound'],
        /minor lacerations about the head and a possible mild concussion/      => ['major head wound', 'minor head wound'],
        /snapped bones and serious bleeding from the neck/                     => ['major head wound', 'major head wound', 'minor head wound'],
        /moderate bleeding from (?:his|her) neck/                              => ['major head wound', 'minor head wound'],
        /deep gashes and serious bleeding from (?:his|her) chest/              => ['major organ wound', 'major organ wound', 'minor organ wound'],
        /deep lacerations across (?:his|her) chest/                            => ['major organ wound', 'minor organ wound'],
        /deep gashes and serious bleeding from (?:his|her) abdomen/            => ['major organ wound', 'major organ wound', 'minor organ wound'],
        /deep lacerations across (?:his|her) abdomen/                          => ['major organ wound', 'minor organ wound'],
        /deep gashes and serious bleeding from (?:his|her) back/               => ['major organ wound', 'major organ wound', 'minor organ wound'],
        /deep lacerations across (?:his|her) back/                             => ['major organ wound', 'minor organ wound'],
        /a blinded (right|left) eye/                                           => ['major organ wound', 'major organ wound', 'minor organ wound'],
        /a swollen (right|left) eye/                                           => ['major organ wound', 'minor organ wound'],
        /a completely severed (right|left) leg|arm|hand/                       => ['major limb wound', 'major limb wound', 'minor limb wound'],
        /a fractured and bleeding (right|left) leg|arm|hand/                   => ['major limb wound', 'minor limb wound'],
        /a case of uncontrollable convulsions|a case of sporadic convulsions/  => ['major nerve wound', 'minor nerve wound'],
        /minor bruises about the head/                                         => ['minor head wound'],
        /minor bruises on (?:his|her) neck/                                    => ['minor head wound'],
        /minor cuts and bruises on (?:his|her) chest/                          => ['minor organ wound'],
        /minor cuts and bruises on (?:his|her) abdomen/                        => ['minor organ wound'],
        /minor cuts and bruises on (?:his|her) back/                           => ['minor organ wound'],
        /a bruised (right|left) eye/                                           => ['minor organ wound'],
        /some minor cuts and bruises on (?:his|her) (right|left) leg|arm|hand/ => ['minor limb wound'],
        /a strange case of muscle twitching/                                   => ['minor nerve wound'],
      }.freeze

      # @param look [String] the LOOK answer for the client
      # @return [Array<String>] herb types, in the order to hand them over
      def escort_injuries(look)
        ESCORT_INJURIES.flat_map { |pattern, types| look =~ pattern ? types : [] }
      end
    end
  end
end

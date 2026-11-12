# frozen_string_literal: true

module EO
  # Skinning the dead: which need a blunt tool, getting ready to skin,
  # and the skinning itself with what the game answers. eloot 2.15.0 Loot
  # skin_obj_types and skin.
  module Skinning
    module_function

    # Creatures whose hide gives only to a blunt weapon.
    BLUNT = /krynch|stone mastiff|krag dweller|cavern urchin|massive boulder/i

    # What never skins, whoever tries.
    NEVER = /(?:ethereal|ghostly|unwordly|Grimswarm|child)/

    RESULT = Regexp.union(
      /You skinned/i, /You botched/i, /already been/i, /cannot skin/i, /must be a member/i, /can only skin/i,
      /You are unable to break through/i, /You break through the crust of the/i, /You crack open a portion/i,
      /Because your account is free/i, /it's not possible to get a worthwhile/i
    )
    BROKE_OPEN = Regexp.union(/You break through the crust of the .+ and withdraw (.+)!/i, /You crack open a portion of the .+ and uncover (.+)!/i)
    # e.g. OSA ship captains: the skin has been ruined with alchemical components
    UNSKINNABLE = /You cannot skin|ruined with alchemical components/

    # @param obj [GameObj]
    # @return [Boolean]
    def blunt?(obj)
      obj.name =~ BLUNT ? true : false
    end

    # The dead that are worth a try: not bandits, not the never-skinned,
    # not on the given lists.
    #
    # @param objs [Array<GameObj>]
    # @param unskinnable [Array<String>] names learned to fail
    # @param exclude [Regexp, nil] the driver's skin and critter exclusions
    # @return [Array<GameObj>]
    def candidates(objs, unskinnable: [], exclude: nil)
      objs.reject do |obj|
        unskinnable.include?(obj.name) || obj.type =~ /bandit/ || obj.name =~ NEVER || (exclude && obj.name.match?(exclude))
      end
    end

    # Kneel when nothing hostile is about, and the skinning buffs.
    #
    # @param kneel [Boolean]
    # @param resolve [Boolean] Sigil of Resolve
    # @param nature [Boolean] 604, kept up with time to spare
    # @return [void]
    def prepare(kneel: false, resolve: false, nature: false)
      while kneel && GameObj.targets.empty? && !kneeling?
        dothistimeout('kneel', 3, /You kneel down\.$|You move to|You are already kneeling\.$/)
      end
      if resolve && Spell['Sigil of Resolve'].affordable? && !Spell['Sigil of Resolve'].active?
        Spell['Sigil of Resolve'].cast
      end
      return unless nature && Spell[604].affordable? && (!Spell[604].active? || (Spell[604].timeleft * 60).truncate <= 10)
      until Spell[604].active? && (Spell[604].timeleft * 60).truncate > 5
        Spell[604].cast
        sleep 0.1
      end
    end

    # Skin each corpse with the tool in +hand+, stowing a gem that breaks
    # out of a boulder.
    #
    # @param objs [Array<GameObj>]
    # @param hand [String] 'right' or 'left', where the tool is
    # @return [Array<String>] the names the game said cannot be skinned
    def skin(objs, hand:)
      learned = []
      objs.each do |obj|
        result = dothistimeout("skin ##{obj.id} #{hand}", 2, RESULT)
        if result =~ UNSKINNABLE
          learned << obj.name
        elsif result =~ BROKE_OPEN
          fput "stow gem ##{GameObj.left_hand.id}"
        end
      end
      waitrt?
      learned.uniq
    end
  end
end

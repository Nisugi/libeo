# frozen_string_literal: true

module EO
  # Skinning the dead: which need a blunt tool, getting ready to skin,
  # and the skinning itself with what the game answers. eloot 2.15.0 Loot
  # skin_obj_types, skin and occassional_skinner.
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
      3.times do
        break unless kneel && GameObj.targets.empty? && !kneeling?

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

    # A creature that skins only some of the time, tried even when learned
    # unskinnable: the rotting chimera with a scorpion tail. eloot
    # occassional_skinner.
    #
    # @param obj [GameObj]
    # @return [Boolean]
    def occasional?(obj)
      return false unless obj.name =~ /rotting chimera/

      lines = EO.command('describe chimera', /The twisted and confused form/, silent: true, quiet: true)
      lines.any? { |line| line =~ /A huge scorpion tail rises high from the rear/ }
    end

    # The dead to skin, split by the tool they want: the candidates, the
    # occasional skinner tried even when learned unskinnable, and with a
    # bounty creature only that creature.
    #
    # @param objs [Array<GameObj>]
    # @param unskinnable [Array<String>]
    # @param exclude [Regexp, nil]
    # @param creature [String, nil] skin only this (a skinning bounty's creature)
    # @return [Array(Array<GameObj>, Array<GameObj>)] the edged and the blunt
    def choose(objs, unskinnable: [], exclude: nil, creature: nil)
      unskinnable = unskinnable.reject { |name| objs.any? { |obj| obj.name == name && occasional?(obj) } }
      objs = candidates(objs, unskinnable: unskinnable, exclude: exclude)
      objs = objs.select { |obj| obj.name.to_s.downcase.include?(creature.downcase) } if creature
      blunt, edged = objs.partition { |obj| blunt?(obj) }
      [edged, blunt]
    end

    # The skinning tool in hand for the block, then put away: both hands
    # freed for a blunt tool, one for an edged; a tool already in hand is
    # used where it is and left there. eloot skin_obj_types.
    #
    # @param tool [GameObj]
    # @param blunt [Boolean]
    # @param free [Proc] given :both or :one, frees the hands
    # @param draw [Proc] given the tool, puts it in a hand
    # @param put_away [Proc] given the tool, puts it back
    # @yieldparam hand [String] 'right' or 'left'
    # @return [Object, nil] the block's value, nil when the tool could not be drawn
    def with_tool(tool, blunt:, free:, draw:, put_away:)
      waitrt?
      held = !blunt && Hands.holding?(tool)
      free.call(blunt ? :both : :one) unless held
      unless Hands.holding?(tool)
        waitrt?
        draw.call(tool)
      end
      return nil unless Hands.holding?(tool)

      result = yield(tool.id == GameObj.left_hand.id ? 'left' : 'right')
      put_away.call(tool) unless held
      result
    end

    # Up again after skinning, a few tries at most, in offensive stance when
    # nothing is about and back to the stance it was in.
    #
    # @return [Boolean] whether standing
    def stand_up
      return true if standing?

      # a frenzy holds the stance
      change = ->(stance) { Lich::Gemstone::Stance.change(stance) unless Effects::Debuffs.active?('Frenzy') }
      before = Lich::Gemstone::Stance.current
      change.call('offensive') if GameObj.targets.empty?
      5.times do
        break if standing?

        dothistimeout('stand', 3, /You stand|You quickly roll|You are already standing/)
      end
      change.call(before)
      standing?
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

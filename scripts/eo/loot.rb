# frozen_string_literal: true

module EO
  # What on the ground is loot, and which loot a character wants. eloot
  # 2.15.0: the reject lists in Data, Loot reject_invalid_loot,
  # should_grab_item?.
  module Loot
    module_function

    # Things in the room that look like loot and are not: spell effects,
    # ranger vines, room features.
    REJECT_NAMES = [
      # 335 Deity
      'golden light', 'jet black scimitar', 'midnight black flames', 'reddish haze', 'sourceless shadow',
      'swirling blue-green pillar of water',
      # Ranger vines
      'bramble', 'briar', 'clutch of twisted branches', 'creeper', 'ivy', 'smilax', 'swallowwort', 'tumbleweed',
      'vine', 'widgeonweed',
      # Misc
      'child', 'jagged crater', 'massive icicle', 'point of elemental instability', 'rolton droppings',
      'rotting tree stump', 'sealed fissure', 'severed', 'slender silvery thread', 'slippery wooden chute',
      'small puddle', 'vathor club'
    ].freeze

    REJECT_NOUNS = %w[cloud cyclone door gangplank kitten maw mist muck puppy space staircase].freeze

    # Someone's floating disk, by its many nouns ("Ann disk", "Bob coffer").
    DISK_NOUNS = /\b(?:bassinet|cassone|chest|coffer|coffin|coffret|disk|hamper|saucer|sphere|trunk|tureen)\b/

    # The loot categories a character can choose among.
    CATEGORIES = %w[alchemy armor box clothing collectible cursed food gem herb jewelry junk lockpick lm\ trap magic
                    reagent scroll skin uncommon valuable wand weapon].freeze

    # The choices a driver's settings make. types: the categories wanted.
    # exclude / keep: names never taken, and taken whatever their type.
    # unlootable: names learned not to pick up (honoured when log_unlootables).
    # crumbly: names that crumble when stowed. heirloom: the bounty's
    # heirloom item, always taken. level: the character's level (oblivion
    # quartz is only safe at 100).
    Policy = Struct.new(:types, :exclude, :keep, :unlootable, :log_unlootables, :crumbly, :heirloom, :level,
                        keyword_init: true) do
      def initialize(types: [], exclude: nil, keep: nil, unlootable: [], log_unlootables: false, crumbly: [],
                     heirloom: nil, level: 0)
        super
      end

      # @return [Regexp, nil]
      def heirloom_pattern
        heirloom.to_s.empty? ? nil : /#{Regexp.escape(heirloom.to_s)}/i
      end
    end

    # Whether a room object is not loot at all: a feature, a spell effect,
    # a disk, an object with a negative id, weapons and armor (left to the
    # specials), or a name learned to fail. A kept name or the bounty's
    # heirloom is never rejected.
    #
    # @param obj [GameObj]
    # @param policy [Policy]
    # @return [Boolean]
    def junk?(obj, policy)
      return false if policy.keep && obj.name =~ policy.keep
      return false if policy.heirloom_pattern && obj.name =~ policy.heirloom_pattern
      return true if obj.name =~ /\b#{Regexp.union(REJECT_NAMES)}\b/i
      return true if obj.name =~ /[A-Z][a-z]+ #{DISK_NOUNS}\b/
      return true if obj.noun =~ /\b#{Regexp.union(REJECT_NOUNS)}\b/i
      return true if obj.id.to_i.negative?
      return true if obj.type =~ /weapon|armor/i && obj.type !~ /uncommon|clothing/i
      return true if policy.log_unlootables && policy.unlootable.include?(obj.name)
      policy.crumbly.include?(obj.name)
    end

    # @param objs [Array<GameObj>]
    # @param policy [Policy]
    # @return [Array<GameObj>] the objects that are loot
    def loot(objs, policy)
      objs.reject { |obj| junk?(obj, policy) }
    end

    # Whether the character wants a piece of loot. The order matters: an
    # exclusion wins, oblivion quartz is wanted only at level 100, a cursed
    # item only when cursed is chosen, then the chosen types, the heirloom,
    # and what is left over unless its type is one not chosen.
    #
    # @param thing [GameObj]
    # @param policy [Policy]
    # @return [Boolean]
    def wanted?(thing, policy)
      return false if policy.exclude && thing.name.match?(policy.exclude)
      return true if thing.name == 'shard of oblivion quartz' && policy.level == 100 && policy.types.include?('gem')
      return false if thing.type =~ /cursed/i && !policy.types.include?('cursed')
      return true if !policy.types.empty? && thing.type =~ Regexp.union(policy.types)
      return true if policy.heirloom_pattern && thing.name =~ policy.heirloom_pattern
      not_wanted = CATEGORIES - policy.types
      return false if !not_wanted.empty? && thing.type =~ Regexp.union(not_wanted)
      true
    end
  end
end

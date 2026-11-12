# frozen_string_literal: true

module EO
  module Guild
    # What a character will take from the guild: the task types and the
    # exclusions, plus the boost and voucher choices. Built by the driver
    # from its own settings; the library reads nothing else. ebounty
    # check_removal is `reject?`.
    TaskPolicy = Struct.new(:types, :creature_exclude, :herb_exclude, :gem_exclude, :location_exclude,
                            :remove_heirloom, :use_boosts, :boost_type, :use_vouchers, :extra_skin,
                            keyword_init: true) do
      def initialize(types: Tables::BOUNTY_TYPES, creature_exclude: [], herb_exclude: [], gem_exclude: [],
                     location_exclude: [], remove_heirloom: false, use_boosts: false, boost_type: nil,
                     use_vouchers: false, extra_skin: 0)
        super
      end

      # @return [Array<String>] the bounty_types names this policy turns down
      def rejected_types
        Tables::BOUNTY_TYPES - Array(types)
      end

      # Why a task should be handed back, or nil to keep it.
      #
      # @param task [Lich::Gemstone::Bounty::Task] with type, requirements and action
      # @return [String, nil] a sentence for the player, nil when the task is wanted
      def reject?(task)
        return nil if task.nil? || task.type == :none
        need = task.requirements || {}

        if excluded?(creature_exclude, need[:creature])
          "#{need[:creature].to_s.capitalize} is in the excluded list"
        elsif excluded?(herb_exclude, need[:herb])
          "#{need[:herb].to_s.capitalize} is in the excluded list"
        elsif excluded?(gem_exclude, need[:gem])
          "#{need[:gem].to_s.capitalize} is in the excluded list"
        elsif excluded?(location_exclude, need[:area])
          "#{need[:area]} is in the excluded list"
        elsif Tables::CROSSWALK[task.type] == 'kill_creatures' && Array(types).grep(/culling/).none?
          'creature tasks are not wanted'
        elsif task.type == :heirloom && task.action == 'search' && !Array(types).include?('heirloom_search')
          'heirloom search tasks are not wanted'
        elsif task.type == :heirloom && task.action == 'loot' && !Array(types).include?('heirloom_loot')
          'heirloom loot tasks are not wanted'
        elsif rejected_types.include?(Tables::CROSSWALK[task.type])
          "#{Tables::CROSSWALK[task.type]} tasks are not wanted"
        end
      end

      # @return [String, nil] the type to ask the taskmaster for while a boost
      #   runs, nil for any
      def boost_choice
        return nil if boost_type.to_s.empty? || boost_type.to_s == 'Any'
        boost_type.to_s
      end

      private

      def excluded?(list, value)
        list = Array(list).map { |w| w.to_s.downcase }.reject(&:empty?)
        return false if list.empty? || value.to_s.empty?
        value.to_s.downcase.match?(Regexp.union(list))
      end
    end
  end
end

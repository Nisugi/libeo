# frozen_string_literal: true

module EO
  module Guild
    # When a task is done enough to stop hunting and go to town. ebounty
    # set_eval built this as a Ruby string for bigshot to
    # eval each tick; here it is a Rule the driver evaluates with what the
    # game says now, and a driver that still needs a string wraps the call.
    # Also the skin and gem counting that skin_bounty and gem_bounty
    # shared with it.
    module Completion
      module_function

      # The task text when it is over, one way or another.
      DONE = /^You.*?(succeeded|located|failed )|your task is failed/

      # No task held.
      NO_TASK = /^You are not currently assigned /

      # A rescue task once the child has been found.
      CHILD_CONTACT = /^You have made contact with the child/

      # What the task calls a skin, as the item in a container is named:
      # singular, and the few plurals that are not an s.
      #
      # @param skin [String]
      # @return [String]
      def skin_name(skin)
        skin.to_s.strip.downcase.sub(/s$/, '').gsub(/teeth/, 'tooth').gsub(/hooves?/, 'hoof').gsub(/ruffs?/, 'ruff')
      end

      # The last two words of the skin name, which is how a bundle of them reads.
      #
      # @param skin [String]
      # @return [String, nil]
      def bundle_name(skin)
        m = skin.to_s.match(/(\w+)\s+(\w+)\s*\Z/)
        m && m[0].strip
      end

      # Skins held: loose ones by name, plus the contents of a bundle of
      # them, counted with MEASURE. A bundle is not measured while hidden,
      # since MEASURE would break the hiding.
      #
      # @param containers [Array<GameObj>]
      # @param skin [String] as the task names it
      # @param hidden [Boolean]
      # @return [Integer]
      def skins_held(containers, skin, hidden: false)
        single = skin_name(skin)
        bundle = bundle_name(skin)
        containers.sum do |container|
          container.contents.to_a.sum do |item|
            if bundle && item.name =~ /bundle of #{Regexp.escape(bundle)}/
              hidden ? 0 : measure(item)
            elsif !single.empty? && item.name =~ /#{Regexp.escape(single)}/i
              1
            else
              0
            end
          end
        end
      end

      # @param item [GameObj] a bundle
      # @return [Integer] how many it holds, from MEASURE
      def measure(item)
        lines = Lich::Util.quiet_command_xml("measure ##{item.id}", /You glance through/)
        lines.sum { |l| l.scan(/count a total of (\d+) <a exist/).flatten.map(&:to_i).sum }
      end

      # Gems held whose name ends with the task's gem.
      #
      # @param containers [Array<GameObj>]
      # @param gem [String] as the task names it ("an uncut diamond")
      # @return [Integer]
      def gems_held(containers, gem)
        name = gem.to_s.sub(/^an? /, '').strip
        return 0 if name.empty?
        containers.sum { |c| c.contents.to_a.count { |item| item.name =~ /#{Regexp.escape(name)}$/i } }
      end

      # The rule for one task. Built once when the hunt starts; asked each
      # tick with the game's current state.
      #
      # mind_needed: the mind percent the task text must be matched with for
      # an ordinary task (100, or the fried setting under exp_pause). A
      # bandit task ignores mind. count_mind: the mind percent a skin or gem
      # count must be matched with (the fried setting capped at 100).
      # keep_hunting: an ordinary task is not done while the mind is saturated.
      class Rule
        attr_reader :type, :number, :skin, :gem

        # @param task [Lich::Gemstone::Bounty::Task, nil] the task held, or nil
        # @param mind_needed [Integer]
        # @param count_mind [Integer]
        # @param extra_skin [Integer] skins to gather beyond the task's number
        # @param keep_hunting [Boolean]
        def initialize(task:, mind_needed: 100, count_mind: 100, extra_skin: 0, keep_hunting: false)
          @type = task&.type
          need = task&.requirements || {}
          @number = need[:number].to_i
          @skin = need[:skin]
          @gem = need[:gem]
          @mind_needed = mind_needed
          @count_mind = count_mind
          @extra_skin = extra_skin.to_i
          @keep_hunting = keep_hunting
        end

        # @param bounty_text [String] what BOUNTY says now
        # @param mind_percent [Numeric] the hunter's mind
        # @param bandit [Boolean] hunting bandits (the task text alone ends it)
        # @param saturated [Boolean] the mind is saturated
        # @param cooldown [Boolean] the Next Bounty cooldown is running
        # @param containers [Array<GameObj>] where skins and gems are kept
        # @param npcs [Array<GameObj>] who is in the room (the rescued child)
        # @param hidden [Boolean]
        # @return [Boolean]
        def complete?(bounty_text:, mind_percent:, bandit: false, saturated: false, cooldown: false,
                      containers: [], npcs: [], hidden: false)
          text = bounty_text.to_s
          return true if text =~ NO_TASK && !cooldown
          if text =~ DONE
            return true if bandit
            return true if mind_percent >= @mind_needed && !(@keep_hunting && saturated)
          end
          case @type
          when :rescue
            text =~ CHILD_CONTACT && npcs.any? { |npc| npc.name.to_s =~ /\bchild\b/ } ? true : false
          when :skin
            mind_percent >= @count_mind && Completion.skins_held(containers, @skin, hidden: hidden) >= @number + @extra_skin
          when :gem
            mind_percent >= @count_mind && Completion.gems_held(containers, @gem) >= @number
          else
            false
          end
        end
      end
    end
  end
end

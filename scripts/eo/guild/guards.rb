# frozen_string_literal: true

module EO
  module Guild
    # The guards: who set bandit, culling, dangerous-creature, heirloom and
    # rescue tasks, and take a found heirloom back. ebounty ask_guard (2718
    # in 1.13.0).
    module Guards
      module_function

      # What a visit came to.
      #
      # outcome: :changed (the task moved on), :unchanged (every guard had
      # nothing for us), or :heirloom_missing (the task wants a found
      # heirloom handed over and no container holds it; the driver decides
      # whether to hand the task back, hunt for it, or stop).
      # opened: ids of containers this visit opened, for the driver to close.
      Visit = Struct.new(:outcome, :opened, keyword_init: true)

      # A found heirloom in the task text; the name without its article.
      LOCATED = /You have located (?:an? |some )?(.*?) and should bring (?:it back|your find)/i

      # Visit the town's guards in turn until one answers. When the task says
      # an heirloom was located, carry it in the right hand first.
      #
      # @param town [String] the task's town
      # @param bounty_text [String] the task text (for the two unparsed guard phrases)
      # @param containers [Array<GameObj>] where a found heirloom may be
      # @return [Visit]
      def ask(town:, bounty_text:, containers: [])
        before = checkbounty
        opened = []
        carrying = false
        answered = false

        NPCs.guard_rooms(town, bounty_text).each do |room|
          room = Tables::HINTERWILDS_GUARD_ROOM if Tables::HINTERWILDS_MOVING_GUARD_UIDS.include?(Room[room].uid.first.to_s)
          EO.go2(room)
          guards = guards_here
          next if guards.empty?

          if !carrying && bounty_text =~ LOCATED
            item = find_heirloom(Regexp.last_match(1), containers, opened)
            return Visit.new(outcome: :heirloom_missing, opened: opened) if item.nil?
            empty_hands
            carrying = true
            EO.result("_drag ##{item.id} right", Tables::GET_RESULT)
          end

          guards.each do |guard|
            result = EO.result("ask #{guard} about bounty", Tables::GUARD_RESPONSES)
            next if result =~ Tables::GUARD_NOTHING
            answered = true
            break
          end
          break if answered
          fput 'stow right' if checkright
        end

        fill_hands if carrying
        Visit.new(outcome: Taskmaster.changed?(before) ? :changed : :unchanged, opened: opened)
      end

      # The guards in this room, waiting up to five seconds for the room to
      # fill in. River's Rest has the purser instead.
      #
      # @return [Array<String, GameObj>]
      def guards_here
        return ['purser'] if Room.current.location =~ /the town of River's Rest/
        deadline = Time.now + 5
        loop do
          found = (GameObj.room_desc.to_a + GameObj.npcs.to_a).select { |npc| npc.name =~ Tables::GUARD_NAMES }
          return found if found.any? || Time.now > deadline
          Lich::Messaging.msg('warn', "Waiting for a guard to appear (#{Tables::GUARD_NAMES.source})")
          sleep 1
        end
      end

      # @param name [String] the heirloom as the task names it
      # @param containers [Array<GameObj>]
      # @param opened [Array<String>] container ids this visit opened, added to
      # @return [GameObj, nil]
      def find_heirloom(name, containers, opened)
        containers.each do |container|
          opened << container.id if Containers.open(container)
          # Lich knows a container's contents only once it has been looked in
          item = Containers.fresh_contents(container).find { |i| i.name.match?(/#{Regexp.escape(name)}/i) }
          return item if item
        end
        nil
      end
    end
  end
end

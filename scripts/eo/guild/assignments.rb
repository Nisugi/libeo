# frozen_string_literal: true

module EO
  module Guild
    # The people an assignment sends you to before the task is set: the
    # furrier, the herbalist, the gem dealer. ebounty ask_assignment (2517
    # in 1.13.0), forage_ask, gem_ask, skin_ask.
    module Assignments
      module_function

      ATTEMPTS = 5

      # Who to see and where, by assignment kind.
      KINDS = {
        furrier: { names: Tables::FURRIER_NAMES, room: ->(town) { town.find_nearest_by_tag('furrier') } },
        herbalist: { names: Tables::HERBALIST_NAMES, room: ->(town) { town.find_nearest(Tables.herbalist_rooms) } },
        jeweler: { names: Tables::JEWELER_NAMES, room: ->(town) { town.find_nearest_by_tag('gemshop') } },
      }.freeze

      # Walk to the NPC in the task's town and ask about the bounty until the
      # task text changes.
      #
      # @param kind [Symbol] :furrier, :herbalist or :jeweler
      # @param town [String] the task's town, as the Bounty parser names it
      # @return [true]
      # @raise [Error] when the town is unknown, the NPC is missing, or five
      #   asks changed nothing
      def ask(kind, town:)
        spec = KINDS.fetch(kind)
        square = Tables.town_room(town) or raise Error, "no town square known for #{town.inspect}"
        EO.go2(spec[:room].call(square))
        EO.settle
        before = checkbounty
        attempts = 0
        begin
          attempts += 1
          npc = NPCs.find(spec[:names])
          fput "ask ##{npc.id} about bounty"
          raise Error, 'the bounty did not change' unless Taskmaster.changed?(before)
          true
        rescue Error => e
          raise Error, "#{e.message} after #{ATTEMPTS} attempts asking the #{kind}" if attempts >= ATTEMPTS
          Lich::Messaging.msg('warn', "Bounty type did not change, retrying (attempt #{attempts})...")
          EO.settle
          retry
        end
      end
    end
  end
end

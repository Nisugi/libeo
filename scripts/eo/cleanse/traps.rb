# frozen_string_literal: true

module EO
  module Cleanse
    # Things done to a character that are fixed somewhere: a hive trap
    # searched out and disarmed where it went off, the itchy curse waited
    # out in a safe room, the Sanctum's infected wound cleaned at the vat.
    # ecleanse hive_search (930), hive_traps_apparatus (964),
    # hive_traps_ground (997), itchy_curse (1010), use_vat (1737).
    module Traps
      module_function

      ATTEMPTS = 3
      DEADLINE = 20
      # Every answer to SEARCH and to DISARM APPARATUS, so a result that is
      # not rolled still ends the wait.
      SEARCH = /d100: |You don't find anything of interest here|You can't see well enough to search around/
      DISARM = /d100: |You want to disarm what\?|You can't see well enough/
      RASH_GONE = /You no longer feel so defenseless and the rash seems to disappear\./
      VAT_UID = 4216054

      # SEARCH for a hive trap in the room it went off in, until it is found
      # or there is nothing to find. Three tries, twenty seconds.
      #
      # @param room_id [Integer, nil] where it went off
      # @return [Symbol] :found, :clear, :blind, :moved, :muckled, :exhausted or :timeout
      def search(room_id)
        deadline = Time.now + DEADLINE
        ATTEMPTS.times do
          return :moved unless here?(room_id)
          return :muckled if dead? || muckled?
          return :timeout if Time.now > deadline

          EO.settle
          lines = Cleanse.command('search', SEARCH)
          return :blind if lines.any? { |line| line =~ /You can't see well enough to search around/ }
          return :clear if lines.any? { |line| line =~ /You don't find anything of interest here/ }
          return :found if lines.any? { |line| line =~ /Success!/ }
        end
        :exhausted
      end

      # DISARM APPARATUS once one is found. Three tries, twenty seconds.
      #
      # @param room_id [Integer, nil]
      # @return [Symbol] :disarmed or :armed
      def disarm(room_id)
        deadline = Time.now + DEADLINE
        ATTEMPTS.times do
          break if !here?(room_id) || dead? || muckled? || Time.now > deadline

          EO.settle
          lines = Cleanse.command('disarm apparatus', DISARM)
          return :disarmed if lines.any? { |line| line =~ /Success!|You want to disarm what\?/ }
        end
        :armed
      end

      # Whether a search outcome leaves the trap to try again later: one
      # that clears up by itself, and the trap announces itself again.
      def retry?(outcome) = %i[moved muckled].include?(outcome)

      # @api private
      def here?(room_id) = !room_id.nil? && Room.current.id == room_id

      # Where to wait out the itchy curse: the room the settings name, else
      # the nearer of the nearest town and sanctuary.
      #
      # @param named [String, Integer, nil] a room id or tag, blank for the nearest
      # @return [Integer, String, nil]
      def safe_room(named = nil)
        return named.to_i if named.to_s =~ /\A\d+\z/
        return named unless named.to_s.empty?

        distances = Room.current.dijkstra.last
        [Room.current.find_nearest_by_tag('town'), Room.current.find_nearest_by_tag('sanctuary')].compact.min_by { |id| distances[id] }
      end

      # Wait out the rash with empty hands, three minutes at most. The trip
      # to the safe room and back is the driver's.
      #
      # @return [Symbol] :gone or :still_itchy
      def wait_out_rash
        empty_hands
        deadline = Time.now + 180
        gone = false
        until gone || Time.now > deadline
          gone = reget(50).any? { |line| line =~ RASH_GONE }
          sleep 1 unless gone
        end
        fill_hands
        gone ? :gone : :still_itchy
      end

      # @return [Integer, nil] the Sanctum vat room on this map
      def vat_room = Room.ids_from_uid(VAT_UID).first

      # CLEAN VAT, there.
      #
      # @return [void]
      def clean_vat
        EO.result('clean vat', /.*/)
        EO.settle
      end
    end
  end
end

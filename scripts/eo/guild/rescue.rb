# frozen_string_literal: true

module EO
  module Guild
    # Rescue tasks: finding the child, where it lives, walking it to a guard
    # with a disabler ready for whatever shows up, and the two things that
    # go wrong when another script does the walk. ebounty child_found (2923
    # in 1.13.0) and child_bounty (2940); echild 1.20.4 (the walk: 280-519).
    module Rescue
      module_function

      # Who takes the child at a dropoff.
      REPORTEE = /sergeant|guard|purser|Belle|Luthrek/i

      # Where the child says it lives, to that town's square. River's Rest
      # and Solhaven answer with their county and barony.
      HOMES = {
        'Icemule Trace'        => 'u4042150',
        'Kharam Dzu'           => 'u3001025',
        'Kharam-Dzu'           => 'u3001025',
        "Kraken's Fall"        => 'u7118221',
        'Mist Harbor'          => 'u3201029',
        'the County of Torre'  => 'u2101008',
        'Vornavis'             => 'u4209030',
        "Ta'Illistim"          => 'u13100042',
        "Ta'Vaalor"            => 'u14100047',
        "Wehnimer's Landing"   => 'u7120',
        "Kharag 'doth Dzulthu" => 'u13006016',
      }.freeze

      # Ta'Vaalor's guards carry no advguard tag; these rooms are them.
      VAALOR_DROPOFF_UIDS = [4564003, 4564004, 4564010, 4564005, 4564011, 4564008, 4564006, 4564007, 4564013, 4564014, 4564009].freeze

      CHILD_ANSWER = /The child says, "Please, take me home to ([^!]+?)!"/
      TASK_FAILED = /^\[You have failed your current Adventurer's Guild task\.\]/

      # Maaghara Labyrinth: a child found inside has to be climbed out by a
      # root; when a root will not take us, the next exit room is tried.
      MAAGHARA_EXITS = {
        13022005 => 13022015, 13022025 => 13022015, 13022015 => 13022035,
        13022035 => 13022045, 13022045 => 13022005,
      }.freeze
      MAAGHARA_OUT_UID = 13021008
      ROOT_UP = /rootlike tendrils as thick as your thumb snake out and encircle/
      ROOT_REFUSED = /seem to be any way to do that at the moment/
      ROOT_SLIPPED = /You step into the root, but can see no way to climb the slippery tendrils inside\.  After a moment, you step back out\./

      # @return [Boolean] whether a child is in the room
      def child_here?
        GameObj.npcs.any? { |n| n.name =~ /child/i }
      end

      # @param bounty_text [String]
      # @return [Boolean] whether the task says the child has been contacted
      def contact?(bounty_text)
        bounty_text.to_s =~ /^You have made contact with the child you are to rescue/ ? true : false
      end

      # The child in the room, waiting a little for it to appear.
      #
      # @param noun [String] what to look for ("child"; a test can name a familiar)
      # @param timeout [Numeric] seconds
      # @return [String, nil] the child's id
      def find_child(noun: 'child', timeout: 5)
        deadline = Time.now + timeout
        loop do
          npc = GameObj.npcs.to_a.find { |n| n.noun =~ /#{noun}/i }
          return npc.id if npc
          return nil if Time.now > deadline
          sleep 0.1
        end
      end

      # The rooms a child can be handed over in, nearest first from +from+:
      # every advguard and advguard2 room plus Ta'Vaalor's.
      #
      # @param from [Room]
      # @return [Array<Integer>]
      def dropoffs(from: Map.current)
        tagged = from.find_all_nearest_by_tag('advguard') | from.find_all_nearest_by_tag('advguard2')
        (tagged | VAALOR_DROPOFF_UIDS.map { |uid| Map.ids_from_uid(uid).first }).compact
      end

      # Ask the child where home is.
      #
      # @return [Room, nil] that town's square, nil when it did not say or the
      #   place is unknown (a message says to report it)
      def home
        line = dothistimeout('ask child about destination', 5, CHILD_ANSWER)
        return nil unless line =~ CHILD_ANSWER
        uid = HOMES[Regexp.last_match(1)]
        if uid.nil?
          Lich::Messaging.msg('error', "missing child home entry for [#{Regexp.last_match(1)}], please report to elanthia-online.")
          return nil
        end
        Room[uid]
      end

      # The dropoff to walk to: the one nearest the child's home, or the
      # one nearest a room the caller names, or the nearest from here.
      #
      # @param near [Integer, String, nil] a room id or uid the caller chose
      # @param points [Array<Integer>] from .dropoffs
      # @return [Integer]
      def destination(points, near: nil)
        from = near ? Room[near] : home
        (from || Map.current).find_nearest(points)
      end

      # The walk: one step at a time, waiting for the child to follow, with
      # a disabler on anything hostile met on the way; at a dropoff with no
      # one to report to, on to the next.
      class Walk
        # @param child [String] the child's GameObj id
        # @param to [Integer] the first dropoff
        # @param points [Array<Integer>] every dropoff, the chosen one included
        # @param disablers [Disablers::Policy]
        # @param step [String] the step script ("move2")
        def initialize(child:, to:, points:, disablers:, step: 'move2')
          @child = child
          @place = to
          @original = to
          @points = points - [to]
          @policy = disablers
          @step = step
          @can_disable = disablers.enabled && Disablers.any?(disablers)
          Lich::Messaging.msg('info', 'Note: No disablers known') if disablers.enabled && !@can_disable
          @stop_1011 = false
          @failed = false
        end

        # @return [Symbol] :delivered, or :failed when the task failed on the way
        #   (the walk goes back to where it was headed)
        def run
          $child_last_seen = Map.current.id
          watch = Watchfor.new(TASK_FAILED) { @failed = true }
          loop do
            walk_to_place
            return fail! if @failed
            npc = reportee
            if npc.nil?
              @place = Map.current.find_nearest(@points)
              @points.delete(@place)
              next
            end
            fput "ask ##{npc.id} about bounty"
            $child_last_seen = nil
            return :delivered
          end
        ensure
          watch&.delete
          if @stop_1011
            waitrt?
            fput 'stop 1011'
          end
        end

        private

        def fail!
          EO.go2(@original)
          :failed
        end

        # @return [GameObj, nil] someone to hand the child to, here
        def reportee
          GameObj.npcs.to_a.find { |n| n.name =~ REPORTEE } || GameObj.room_desc.to_a.find { |n| n.name =~ REPORTEE }
        end

        # Step toward the place until there, the child along each time.
        def walk_to_place
          until Map.current.id == @place || @failed
            climb_root if MAAGHARA_EXITS.key?(Map.current.uid.to_a.first.to_i)
            from = Map.current.id
            waitrt?
            Script.run(@step, @place.to_s)
            wait_while { running?(@step) }
            wait_until { from != Map.current.id || @failed }
            waitrt?
            disable_hostiles
            wait_for_child
          end
        end

        # A disabler on hostile creatures, unless players or a reportee are
        # here, or only the child is.
        def disable_hostiles
          return unless @can_disable
          return if checkpcs
          return if GameObj.npcs.to_a.any? { |n| n.name =~ REPORTEE } || GameObj.room_desc.to_a.any? { |n| n.name =~ /purser/ }
          return unless GameObj.targets.to_a.any? { |npc| !@policy.untargetable.include?(npc.name) }
          return if GameObj.npcs.to_a.size == 1 && GameObj.npcs.to_a.first.id == @child
          return unless Disablers.target!(@policy)
          num = Disablers.best(@policy)
          return if num.nil?
          @stop_1011 = true if num == 1011
          Disablers.cast!(num)
        end

        # The child follows a step behind; wait for it here. A room where it
        # was never seen stops holding after five seconds.
        def wait_for_child
          here = Map.current.id
          deadline = Time.now + 5
          wait_until { child_here? || Time.now > deadline || here != Room.current.id || @failed }
          $child_last_seen = Map.current.id if child_here?
        end

        def child_here?
          GameObj.npcs.to_a.any? { |n| n.id == @child }
        end

        # GO ROOT, up to three tries; when a root refuses, head for the next
        # exit room instead; when it takes us, the original place is back on.
        def climb_root
          3.times do
            result = dothistimeout('go root', 3, Regexp.union(ROOT_UP, ROOT_REFUSED, ROOT_SLIPPED))
            case result
            when ROOT_UP
              @place = @original
              wait_while { Map.current.uid.to_a.first.to_i != MAAGHARA_OUT_UID }
              until standing?
                fput 'stand'
                waitrt?
              end
              return
            when ROOT_REFUSED
              here = Map.current.uid.to_a.first.to_i
              @place = Map.ids_from_uid(MAAGHARA_EXITS[here]).first if MAAGHARA_EXITS.key?(here)
              return
            when ROOT_SLIPPED
              sleep 1
              redo
            else
              Lich::Messaging.msg('warn', 'climbing the root failed')
            end
          end
        end
      end

      # Walk the child to a guard. See Walk.
      #
      # @return [Symbol] :delivered or :failed
      def escort(child:, to:, points:, disablers:, step: 'move2')
        Walk.new(child: child, to: to, points: points, disablers: disablers, step: step).run
      end

      # Run a rescue script from the child's room. A garrote during the walk
      # leaves the child behind: heal, come back, run it again. A Bard's Song
      # of Peace is stopped after, since it blocks the walk.
      #
      # @param script [String] the rescue script ("echild")
      # @param heal [Proc] what to do about a cutthroat before returning
      # @return [void]
      def run(script, heal:)
        Script.run(script)
        sleep 2
        kill_script('go2') if running?('go2')

        if child_here? && cutthroat?
          room = Room.current.id
          heal.call
          EO.go2(room)
          Script.run(script)
          sleep 2
        end

        return unless Stats.prof == 'Bard'
        lines = EO.command('spell active', /<dialogData id='Active Spells'/, silent: true, quiet: true)
        fput 'stop 1011' if lines.any? { |l| l =~ /Song of Peace/ }
      end
    end
  end
end

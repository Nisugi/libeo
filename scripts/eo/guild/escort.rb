# frozen_string_literal: true

module EO
  module Guild
    # Escort tasks: which trip the task is, and the escort itself: fetch
    # the client, walk the road with hiding, haste and an attack script
    # for what ambushes the pair, and hand the client over. ebounty escort
    # (2989 in 1.13.0); escortgo2 1.0.5 (the whole script).
    module Escort
      module_function

      # Where each task's pickup wording leads, and the town the road starts
      # in (escortgo2 escort_pickup, 177). The task text says "the area ...";
      # lookups strip that.
      PICKUPS = {
        'area just inside the Sapphire Gate'                   => ["Ta'Illistim", 34],
        'area just inside the North Gate'                      => ["Wehnimer's Landing", 223],
        'south end of North Market'                            => ['Solhaven', 1472],
        'area just north of the South Gate, past the barbican' => ['Icemule Trace', 2412],
        "Kresh'ar Deep monument"                               => ['Zul Logoth', 1005],
        'area just inside the Amaranth Gate'                   => ["Ta'Vaalor", 3483],
      }.freeze

      # Where the client is handed over in each destination town.
      DROPOFFS = {
        "Wehnimer's Landing" => [223],
        'Icemule Trace'      => [2412],
        'Zul Logoth'         => [992, 1266],
        'Solhaven'           => [3902],
        "Ta'Vaalor"          => [5907],
        "Ta'Illistim"        => [37],
      }.freeze

      # The escort_types setting names a trip by short town names.
      SHORT = {
        "Wehnimer's Landing" => 'landing', 'Icemule Trace' => 'icemule', 'Zul Logoth' => 'zul',
        'Solhaven' => 'solhaven', "Ta'Vaalor" => 'vaalor', "Ta'Illistim" => 'illy',
      }.freeze

      # Silver to carry for the carts and ferries on the way back to the
      # start town. A driver that knows where it goes next can pass
      # its own.
      TRAVEL_COST = {
        "Wehnimer's Landing" => { 'Icemule Trace' => 0, 'Zul Logoth' => 20, 'Solhaven' => 0, "Ta'Vaalor" => 4020, "Ta'Illistim" => 4020 },
        'Icemule Trace'      => { "Wehnimer's Landing" => 0, 'Zul Logoth' => 20, 'Solhaven' => 0, "Ta'Vaalor" => 4020, "Ta'Illistim" => 4020 },
        'Zul Logoth'         => { "Wehnimer's Landing" => 2020, 'Icemule Trace' => 2020, 'Solhaven' => 2020, "Ta'Vaalor" => 2000, "Ta'Illistim" => 2000 },
        'Solhaven'           => { "Wehnimer's Landing" => 0, 'Icemule Trace' => 0, 'Zul Logoth' => 20, "Ta'Vaalor" => 4020, "Ta'Illistim" => 4020 },
        "Ta'Vaalor"          => { "Wehnimer's Landing" => 4020, 'Icemule Trace' => 4020, 'Zul Logoth' => 2000, 'Solhaven' => 4020, "Ta'Illistim" => 0 },
        "Ta'Illistim"        => { "Wehnimer's Landing" => 4020, 'Icemule Trace' => 4020, 'Zul Logoth' => 2000, 'Solhaven' => 4020, "Ta'Vaalor" => 0 },
      }.freeze

      TASK = /client has hired us to provide a protective escort .* Go to (?:the )?(.*?) and WAIT .* guarantee .*? safety to (.*?) as soon as you can/
      CLIENT_NOUN = /^(?:traveller|magistrate|merchant|scribe|dignitary|official)$/
      IGNORABLE = /^(?:kobold|rolton|urgh|ridge orc|hobgoblin|velnalin|fire ant)$/
      DISABLED = /dead|sleeping|calm|stunned|lying down|prone|sitting|frozen/
      FOLLOWS = /nods and says to you|says to you, "But I already am!"/
      FOLLOW_ANSWERS = /nods and says to you|says to you, "But I already am!"|says to you, "The guild didn't hire you to guide me\."|^The merchant gives you a strange look\.$/
      NO_HIDE_ROOMS = [1156, 1155, 1154, 1153].freeze
      NO_HASTE_ROOMS = [1191].freeze
      SNEAK_RESULT = /^Trying to sneak over|^Obvious|^Running heedlessly/
      AMBUSH = /fearfully exclaims, "It's an ambush!"|<compass>.*?(?:quickly approaches|suddenly leaps from|leaps out of|suddenly jumps out of the shadows)|carefully concealed metal jaws|nearly invisible length of razor wire|length of nearly invisible razor wire|carefully concealed inflated pouch|carefully concealed looped rope|a carefully concealed net|carefully concealed pit|Suddenly, the ground gives out from under you as you fall into a shallow pit filled with tiny spikes!/
      STAGGERED = /<compass>.*?(?:quickly approaches|suddenly leaps from|leaps out of|suddenly jumps out of the shadows)/

      # @param pickup [String] the task's pickup place, with or without "the "
      # @return [String] the table key
      def pickup_key(pickup)
        pickup.to_s.sub(/\Athe /, '')
      end

      # The trip a task describes, named the way the escort_types setting
      # lists them ("landing_to_icemule"), or nil for a pickup or destination
      # the tables do not know.
      #
      # @param pickup [String] the task's "Go to ..." place
      # @param destination [String] the task's destination town
      # @return [String, nil]
      def trip(pickup, destination)
        from = PICKUPS[pickup_key(pickup)]&.first
        to = DROPOFFS.key?(destination) ? destination : nil
        from && to ? "#{SHORT[from]}_to_#{SHORT[to]}" : nil
      end

      # Run an escort script with map portals off (an escort walks), putting
      # the portal setting back after, even when the script dies.
      #
      # @param script [String] the escort script ("escortgo2")
      # @return [void]
      def run(script)
        portals = UserVars.mapdb_use_portals
        UserVars.mapdb_use_portals = 'no'
        begin
          Script.run(script)
          sleep 2
        ensure
          UserVars.mapdb_use_portals = portals
        end
      end

      # attack_script: started with the hostile ids when something must be
      # fought, nil to pause for the player instead. poach: fight even with
      # other players present. hide, haste: before each move. useherbs: run
      # eherbs when hurt and nothing is about. travel_cost: silver to carry,
      # nil for the table's. targetable, untargetable: creature names learned
      # by TARGET; the driver's lists, grown here and saved by it.
      Policy = Struct.new(:attack_script, :poach, :hide, :haste, :useherbs, :travel_cost, :targetable, :untargetable,
                          keyword_init: true) do
        def initialize(attack_script: nil, poach: false, hide: false, haste: false, useherbs: false, travel_cost: nil,
                       targetable: [], untargetable: [])
          super
        end
      end

      # The task's road, from the bounty text.
      Trip = Struct.new(:pickup_room, :start_town, :destination, keyword_init: true) do
        # @return [Integer] silver for the way back, from the table
        def travel_cost = TRAVEL_COST.dig(start_town, destination).to_i
      end

      # @param bounty_text [String]
      # @return [Trip]
      # @raise [Error] for no escort task, or a place the tables do not know
      def trip_from(bounty_text)
        raise Error, 'no escort task' unless bounty_text =~ TASK
        pickup = PICKUPS[pickup_key(Regexp.last_match(1))]
        destination = Regexp.last_match(2)
        raise Error, "unmatched pickup location: #{Regexp.last_match(1)}" if pickup.nil?
        raise Error, "unmatched destination town: #{destination}" unless DROPOFFS.key?(destination)
        Trip.new(pickup_room: pickup.last, start_town: pickup.first, destination: destination)
      end

      # Hearing an ambush: the client's cry, a creature leaping out, a trap
      # springing. Ours until the next room, so another party's bandits
      # are not poached. escortgo2's exec script.
      class Ambush
        attr_reader :mine, :staggered

        def initialize(client_id)
          @client = client_id
          @mine = false
          @staggered = false
          @name = "#{Script.current.name}_ambush"
        end

        def install
          DownstreamHook.add(@name, proc { |line|
            if line =~ /<pushStream id='room'/
              @mine = false
              @staggered = false
            elsif line =~ AMBUSH && (line !~ /fearfully exclaims/ || line =~ /#{@client}/)
              @mine = true
              @staggered = true if line =~ STAGGERED
            end
            line
          })
          self
        end

        def remove
          DownstreamHook.remove(@name)
        end
      end

      # The escort, from fetching the client to the hand-over.
      class Walk
        attr_reader :client

        # @param trip [Trip]
        # @param policy [Policy]
        def initialize(trip:, policy:)
          @trip = trip
          @policy = policy
          @path = []
          @client = nil
          @justice = true
          @justice_count = 0
          @sanct_count = -1
          @lost = 0
          @wait_num = 45
          @useherbs = policy.useherbs
        end

        # @return [Symbol] :delivered, :lost (the client fell behind for good),
        #   or :no_task (the task ended on the way)
        # @raise [Error] when the client or the road cannot be found
        def run
          @client = client_here || fetch_client
          raise Error, 'failed to find escort' if @client.nil?
          @destination = nearest(DROPOFFS[@trip.destination]) or raise Error, 'failed to find destination room'
          @ambush = Ambush.new(@client).install
          stand_up = Thread.new do
            loop do
              wait_while { standing? || stunned? || checkrt.positive? }
              put 'stand'
              sleep 0.5
            end
          end
          started = Time.now
          result = travel
          Lich::Messaging.msg('info', "travel time: #{((Time.now - started) / 60.0).as_time}")
          result
        ensure
          stand_up&.kill
          @ambush&.remove
          restore_map
          fput 'unhide' if hidden?
        end

        # --- the client ---------------------------------------------------

        # @return [String, nil] a client here who agrees to follow
        def client_here(checked = [])
          GameObj.npcs.to_a.each do |npc|
            next unless npc.noun =~ CLIENT_NOUN && !checked.include?(npc.id)
            checked << npc.id
            fput 'unhide' if hidden? || invisible?
            result = dothistimeout("tell ##{npc.id} to follow", 8, FOLLOW_ANSWERS)
            return npc.id if result =~ FOLLOWS
          end
          nil
        end

        # Carry silver for the road, walk to the pickup, WAIT, and ask whoever
        # arrives to follow.
        def fetch_client
          cost = @policy.travel_cost || @trip.travel_cost
          silvers = Lich::Util.silver_count
          if silvers < cost
            bank = Room[@trip.pickup_room].find_nearest_by_tag('bank')
            go2(bank)
            fput 'unhide' if hidden? || invisible?
            fput "withdraw #{cost - silvers}"
          end
          go2(@trip.pickup_room)
          dothistimeout('wait', 20, /^Time drags on by\.\.\.$/)
          checked = []
          130.times do
            sleep 0.1
            id = client_here(checked)
            return id if id
          end
          nil
        end

        def client_present?
          GameObj.npcs.to_a.any? { |npc| npc.id == @client }
        end

        # --- the road -----------------------------------------------------

        def travel
          loop do
            haste
            check_room
            use_herbs
            check_room
            hide
            check_room
            use_herbs
            check_room
            hide
            step
            10.times do
              sleep 0.1
              check_room
              sleep 0.1
              check_room
              break if client_present?
            end

            # the task text drops the escort once the client is handed over
            return :delivered if bounty? !~ /client has hired us to provide a protective escort/
            if client_present?
              @lost = 0
              deadline = Time.now + 1
              until Time.now > deadline
                sleep 0.1
                check_room
              end
              @wait_num = 45
            elsif (@lost += 1) > 10
              Lich::Messaging.msg('error', 'lost escort')
              return :lost
            elsif checkpcs
              backtrack
              @lost = 0 if client_present?
              (@wait_num += 5).times do
                check_room
                sleep 0.2
              end
            else
              backtrack
              @lost = 0 if client_present?
              check_room
            end
          end
        end

        # The map's shortest path with the shortcuts an escort cannot take
        # switched off: Ta'Vaalor's, seeking, portals.
        def find_path
          here = Room.current or raise Error, 'current room is not in the map database'
          @saved ||= { shortcut: $go2_use_vaalor_shortcut, seeking: $go2_use_seeking, portals: $go2_use_portals,
                       vaalor: [Room[16745].timeto['16746'], Room[16746].timeto['16745']] }
          $go2_use_vaalor_shortcut = false
          Room[16745].timeto['16746'] = 15000
          Room[16746].timeto['16745'] = 15000
          $go2_use_seeking = false
          $go2_use_portals = false
          previous, distance = Map.dijkstra(here.id, @destination.id)
          raise Error, "you can't get there (#{@destination.id}) from here (#{here.id})" unless previous[@destination.id]
          path = [@destination.id]
          path.push(previous[path[-1]]) until previous[path[-1]].nil?
          @path = path.reverse
          eta = ((distance[@destination.id] + (1.8 * @path.length)) / 60.0).as_time
          Lich::Messaging.msg('info', "ETA: #{eta} (#{@path.length} rooms to move through).")
        end

        def restore_map
          return if @saved.nil?
          $go2_use_vaalor_shortcut = @saved[:shortcut]
          $go2_use_seeking = @saved[:seeking]
          $go2_use_portals = @saved[:portals]
          Room[16745].timeto['16746'], Room[16746].timeto['16745'] = @saved[:vaalor]
        end

        # One room along the path, by the special route for this edge when
        # there is one, else the map's way.
        def step
          here = Room.current or raise Error, 'current room is not in the map database'
          find_path unless @path.include?(here.id)
          next_id = @path[@path.index(here.id) + 1].to_s
          if (route = ROUTES["#{here.id},#{next_id}"])
            take_route(*route)
          else
            way = here.wayto[next_id]
            case way
            when Proc then way.call
            when String
              tries = 0
              loop do
                break unless move(way) == false && !muckled?
                break if Room.current.id != here.id
                if (tries += 1) > 5
                  Lich::Messaging.msg('warn', "fixing map database: deleting #{here.id} -> #{way} -> #{next_id}")
                  here.wayto.delete(next_id)
                  break
                end
                sleep 0.2
              end
            else
              @path = []
            end
          end
          sleep 0.1
        end

        # One room back along the path, to where the client was last.
        def backtrack
          here = Room.current or raise Error, 'current room is not in the map database'
          index = @path.index(here.id)
          next_id = index ? @path[index - 1].to_s : nil
          way = next_id && here.wayto[next_id]
          case way
          when Proc then way.call
          when String
            if move(way) == false && !muckled?
              Lich::Messaging.msg('warn', "fixing map database: deleting #{here.id} -> #{way} -> #{next_id}")
              here.wayto.delete(next_id)
              here.timeto.delete(next_id)
            end
          else
            if next_id
              start_script('go2', [next_id, 'typeahead=0', 'shortcut=off'])
              wait_while { running?('go2') }
            else
              Lich::Messaging.msg('error', 'unable to backtrack')
              sleep 3
            end
          end
          sleep 0.1
        end

        def go2(room)
          start_script('go2', [room.to_s])
          wait_while { running?('go2') }
        end

        def nearest(ids)
          here = Room.current or return nil
          return Room[here.id] if ids.include?(here.id)
          _, distance = Map.dijkstra(here.id, ids)
          best = ids.select { |id| distance[id] }.min_by { |id| distance[id] }
          best && Room[best]
        end

        # --- the room -----------------------------------------------------

        # Learn what can be targeted, then deal with what must be fought:
        # by the attack script, or by pausing for the player. Other players'
        # bandits are left alone unless the ambush was ours or poaching is on.
        def check_room
          Spell.unlock_cast if @policy.hide
          loop do
            learn_targets
            npcs = GameObj.npcs.to_a.select do |npc|
              @policy.targetable.include?(npc.name) && npc.name !~ IGNORABLE && npc.noun !~ CLIENT_NOUN &&
                ((@ambush&.mine && npc.type =~ /bandit/) || npc.status !~ DISABLED) && npc.status !~ /dead/
            end
            all_pcs = GameObj.pcs.to_a
            pcs = all_pcs.select { |pc| pc.status.nil? || pc.status =~ /hiding|hidden/ }
            disks = GameObj.loot.to_a.select do |loot|
              loot.noun == 'disk' && loot.name !~ /#{Char.name}/ &&
                (all_pcs.empty? || loot.name !~ /#{all_pcs.map(&:noun).join('|')}/)
            end
            jerks = all_pcs.select { |pc| UserVars.attacked_me.to_a.include?(pc.noun) && pc.status !~ /dead/ }
            unless jerks.empty?
              if @justice_count != XMLData.room_count
                result = dothistimeout('justice status', 1, /^There is no justice other than your own out here\.$|^You sense that your surroundings are calm enough/)
                @justice = result !~ /^There is no justice other than your own out here\.$/
                @justice_count = XMLData.room_count
              end
              jerks.clear if @justice
            end
            break if @sanct_count == XMLData.room_count
            fight = (@policy.poach && npcs.any?) || (npcs.any? && (@ambush&.mine || (pcs.empty? && disks.empty?))) ||
                    (@policy.attack_script && jerks.any?)
            break unless fight
            if @policy.attack_script
              if checkrt.positive?
                waitrt?
                next
              elsif checkcastrt.positive?
                waitcastrt?
                next
              end
              start_script(@policy.attack_script, (jerks + npcs).map(&:id), { quiet: true })
              wait_while { running?(@policy.attack_script) }
              @sanct_count = XMLData.room_count if clear.any? { |line| line =~ /^Be at peace my child|^Spells of War cannot be cast/ }
            else
              puts "\n#{monsterbold_start}Kill!#{monsterbold_end} \n\n"
              pause_script
            end
            sleep 0.1
          end
        end

        def learn_targets
          while (npc = GameObj.npcs.to_a.find { |n| !@policy.targetable.include?(n.name) && !@policy.untargetable.include?(n.name) })
            result = dothistimeout("target ##{npc.id}", 10, /^You are now targeting|^You can't target|^Usage:  TARGET/)
            if result =~ /^You are now targeting/
              @policy.targetable.push(npc.name)
            elsif result =~ /^You can't target/
              @policy.untargetable.push(npc.name)
            else
              break
            end
          end
        end

        def hide
          return unless @policy.hide
          Spell.lock_cast
          return if hidden? || invisible? || NO_HIDE_ROOMS.include?(Room.current.id)
          waitrt?
          fput 'hide'
          sleep 0.5
          waitrt?
        end

        def haste
          return unless @policy.haste
          spell = Spell[506]
          spell.cast if !spell.active? && spell.known? && spell.affordable? && !NO_HASTE_ROOMS.include?(Room.current.id)
        end

        # Before a move that breaks hiding, a shield if there is mana to spare.
        def protect
          return unless @policy.hide
          shield = Spell[919]
          shield.cast if shield.known? && !shield.active? && mana > 150
        end

        def hurt?
          [Wounds.head, Wounds.neck, Wounds.torso, Wounds.limbs, Wounds.nerves,
           Scars.head, Scars.neck, Scars.torso, Scars.limbs, Scars.nerves].max.positive? || (checkhealth + 50) < maxhealth
        end

        def use_herbs
          return unless @useherbs
          unless Script.exists?('eherbs')
            Lich::Messaging.msg('error', 'useherbs is on but eherbs.lic is not installed (;repository download eherbs)')
            @useherbs = false
            return
          end
          return unless hurt?
          Script.run('eherbs', '--buy=off')
          @useherbs = false if hurt?
        end

        def wait_for_client(checks = 10)
          checks.times do
            check_room
            sleep 0.2
            break if client_present?
          end
          10.times do
            check_room
            sleep 0.1
          end
        end

        # --- the special edges (ROUTES) -----------------------------------

        def take_route(kind, arg)
          case kind
          when :climb
            move arg
            hide
          when :careful, :careful_hands, :careful_hide
            protect
            check_room
            haste
            empty_hands if kind == :careful_hands
            move arg
            waitrt?
            fill_hands if kind == :careful_hands
            hide if kind == :careful_hide
          when :sneak
            count = XMLData.room_count
            while count == XMLData.room_count
              check_room
              haste
              fput 'stand' unless standing?
              check_room
              hide
              dothistimeout(arg, 3, SNEAK_RESULT)
            end
          when :search
            tries, found, answers, go = arg
            haste
            tries.times do
              result = dothistimeout('search', 5, answers)
              waitrt?
              check_room
              break if result =~ found
            end
            haste
            check_room
            hide
            check_room
            hide
            check_room
            move go
          when :ferry then ferry(arg)
          when :cart then mining_cart
          when :crack then crack
          when :steps
            arg.each_with_index do |dir, i|
              haste
              hide
              move dir
              wait_for_client if i < arg.size - 1
            end
          when :ladder
            empty_hands
            haste
            arg.each do |cmd|
              move cmd
              waitrt?
            end
            fill_hands
          when :misty then misty_trail
          when :loop
            open, moves = arg
            while checkpaths.include?(open)
              moves.each do |dir|
                move dir
                wait_for_client
                haste
                hide
              end
            end
          end
        end

        def ferry(boat_room)
          lowered = 'An elven crewmember scrambles back onto the boat and lowers the gangplank.'
          move 'go gangplank'
          if Room.current.id == boat_room
            Lich::Messaging.msg('info', 'Waiting for ferry...')
            loop do
              break if clear.include?(lowered)
              check_room
              sleep 0.1
            end
            move 'go gangplank'
          end
          loop do
            break if clear.include?(lowered)
            check_room
            sleep 0.1
          end
          haste
          check_room
          hide
          check_room
          hide
          check_room
          move 'out'
        end

        def mining_cart
          dothistimeout('buy ticket', 10, /^You already bought a ticket.$|^The dwarf .*You now have passage/)
          boarded = false
          300.times do
            sleep 0.1
            if clear.any? { |line| line =~ /^You hastily enter the mining cart./ }
              boarded = true
              break
            end
          end
          if boarded
            3600.times do
              sleep 0.1
              break if clear.any? { |line| line =~ /^You hastily exit the cart/ }
              check_room
            end
          end
          100.times do
            check_room
            sleep 0.2
            break if client_present?
          end
        end

        def crack
          haste
          dothistimeout('search', 5, /You search/)
          waitrt?
          check_room
          haste
          check_room
          hide
          move 'go crack'
          haste
          dothistimeout('search', 5, /You search/)
          waitrt?
          15.times do
            sleep 0.1
            break if client_present?
          end
          haste
          hide
          move 'go opening'
        end

        def misty_trail
          move 'climb boulder'
          check_room
          hide
          wait_for_client
          look = dothistimeout('look trail', 5, /^You peer into the mist and see that the trail heads off to the/)
          dir = look.to_s[/trail heads off to the (\w+)/, 1]
          haste
          hide
          move 'down'
          wait_for_client
          haste
          hide
          move dir if dir
        end
      end

      # Escort the task's client from pickup to the destination town.
      #
      # @param policy [Policy]
      # @param bounty_text [String]
      # @return [Symbol] as Walk#run
      def escort(policy:, bounty_text: bounty?)
        Walk.new(trip: trip_from(bounty_text), policy: policy).run
      end
    end
  end
end

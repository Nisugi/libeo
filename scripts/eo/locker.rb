# frozen_string_literal: true

module EO
  # The locker: which rooms hold the character's, getting into one (a
  # booth may be taken, the locker may be in another town, a debt may
  # bar the door), opening it to a container, and leaving. eloot 2.15.0
  # Hoard: che_locker_rooms, town_name, che_town_id_for,
  # locker_info_town, lines_since, nearest_first,
  # locker_way_in, in_locker_room?, booth_room?,
  # approach_step, take_step, enter_locker,
  # enter_any_locker, open_locker, leave_locker.
  module Locker
    module_function

    MAX_PASSES = 6
    PASS_WAIT = 10
    ELSEWHERE = /your locker isn't here/i
    INFO = /Your locker is currently located in (.+?)\./i
    DEBT = /pay off (your|that) debt/i
    OWED = /In the back of your mind you remember you owe a debt of ([\d,]+) silver/
    WAY = /^(?:opening|curtain|tapestry)$/

    # Names for the same place: "the town of Kraken's Fall" and "Kraken's
    # Fall". The map calls Teras Isle "Kharam-Dzu", puts the Isle of Four
    # Winds lockers in "Mist Harbor", and the house lounge lockers reached
    # from Ta'Illistim in "the Lost Home".
    #
    # @param name [String]
    # @return [String]
    def town_name(name)
      plain = name.to_s.strip.sub(/\Athe (?:town|city|village|free port|tunnels and caverns|isle) of /i, '').downcase
      { 'teras isle' => 'kharam-dzu', 'four winds' => 'mist harbor', 'the lost home' => "ta'illistim" }.fetch(plain, plain)
    end

    # The character's own CHE lockers in a town: the locker rooms
    # themselves, or if none are mapped, the entrances to them. Empty for
    # a character with no CHE.
    #
    # @param rooms [Array<Room>] the map
    # @param che [String] Char.che
    # @param town_id [Integer] the town square
    # @return [Array<Room>]
    def che_rooms(rooms, che, town_id)
      return [] if che.to_s.empty? || che.to_s == 'none'
      %w[locker entrance_locker].each do |tier|
        found = rooms.select { |room| room.tags.include?("meta:che:#{che}:#{tier}") }
                     .select { |room| room.find_nearest_by_tag('town') == town_id }
        return found unless found.empty?
      end
      []
    end

    # The town square of the house's lockers in the named town, as LOCKER
    # INFO names it, or nil when the house has no mapped lockers there.
    #
    # @return [Integer, nil]
    def che_town_id(rooms, che, town)
      return nil if che.to_s.empty? || che.to_s == 'none' || town.to_s.strip.empty?
      wanted = town_name(town)
      found = rooms.find do |room|
        room.tags.any? { |tag| tag =~ /\Ameta:che:#{Regexp.escape(che.to_s)}:(?:locker|entrance_locker)\z/ } && town_name(room.location) == wanted
      end
      found&.find_nearest_by_tag('town')
    end

    # Where a non-premium member's single locker is, from LOCKER INFO.
    #
    # @return [String, nil] the town as the game names it
    def info_town
      lines = EO.command('locker info', /Your locker is currently located in .+?\.|<prompt time=".*?">&gt;<\/prompt>/, silent: true, quiet: true)
      lines.join(' ')[INFO, 1]
    end

    # Reachable rooms only, nearest first. Room#dijkstra is called without
    # a destination: given a list it stops at the first one reached.
    #
    # @param rooms [Array<Room>]
    # @return [Array<Room>]
    def nearest_first(rooms)
      return rooms if rooms.empty?
      _previous, distances = Room.current.dijkstra
      distances ||= {}
      rooms.select { |room| distances[room.id] }.sort_by { |room| distances[room.id] }
    end

    # The lines that arrived after +before+ was taken; reget returns the
    # last N lines, so the new ones follow the longest run of before's
    # tail that after starts with.
    def lines_since(before, after)
      overlap = [before.length, after.length].min.downto(0).find { |n| before.last(n) == after.first(n) }
      after[overlap..]
    end

    # @return [String, nil] the move into a locker from this room: the
    #   opening, curtain or tapestry here, else nil
    def way_in_here
      obj = (GameObj.loot.to_a + GameObj.room_desc.to_a).find { |o| o.noun =~ WAY }
      return nil if obj.nil?
      "go #{obj.noun == 'tapestry' ? 'opening' : obj.noun}"
    end

    # @return [Boolean] whether this room is a locker booth
    def inside?
      (GameObj.room_desc.to_a + GameObj.loot.to_a).any? { |obj| obj.name =~ /locker|counter/ }
    end

    # @param place [Room]
    # @return [Boolean] a booth room itself, from the map tags
    def booth?(place)
      place.tags.any? { |tag| tag =~ /\Ameta:che:[^:]+:locker\z/ }
    end

    # [the room before the booth on our route, the map's move into it], or
    # nil when the route's last step is not one we can take ourselves.
    def approach_step(place)
      previous, _distances = Room.current.dijkstra(place.id)
      before = previous && previous[place.id]
      return nil if before.nil? || before == place.id
      way = Room[before]&.wayto&.[](place.id.to_s)
      way && [before, way]
    end

    # Take a mapped move (a command, or a proc for a scripted move).
    #
    # @return [Boolean, nil] true once in the room; nil or false when refused
    def take_step(way, place)
      return move(way) if way.is_a?(String)
      way.call
      20.times do
        break if Room.current.id == place.id
        sleep 0.05
      end
      Room.current.id == place.id
    end

    # What a try at a locker came to.
    Entry = Struct.new(:outcome, :debt, keyword_init: true)

    # Get into a locker. For a booth room, go2 only as far as the room
    # outside and take the last step here: go2 treats a refused step as a
    # broken route, retries, disables the edge and gives up.
    #
    # @param place [Room]
    # @param way_in [String, nil] the house's typed entry verb, else the room's opening
    # @return [Entry] outcome :entered, :in_use, :elsewhere (the locker is in
    #   another town), :debt (with the silver owed), :no_way (nothing to go
    #   through), :unreachable, or :refused
    def enter(place, way_in: nil)
      step = booth?(place) ? approach_step(place) : nil
      if step
        outside, way = step
        EO.go2(outside)
        EO.settle
        return Entry.new(outcome: :entered) if Room.current.id == place.id
        return Entry.new(outcome: :unreachable) unless Room.current.id == outside
        before = reget(30)
        result = take_step(way, place)
      else
        EO.go2(place.id)
        EO.settle
        return Entry.new(outcome: :entered) if inside?
        way = way_in.to_s.strip.empty? ? way_in_here : way_in
        return Entry.new(outcome: :no_way) if way.nil?
        before = reget(30)
        result = move(way)
      end
      return Entry.new(outcome: :entered) if result == true

      fresh = lines_since(before, reget(30))
      if fresh.reverse.any? { |line| line =~ DEBT }
        wealth = EO.command('wealth quiet', /^You have (no|[,\d]+|but one) silver with you/, silent: true, quiet: true).join(' ')
        owed = wealth =~ OWED ? Regexp.last_match(1).delete(',').to_i : 0
        return Entry.new(outcome: :debt, debt: owed) if owed.positive?
      end
      return Entry.new(outcome: :elsewhere) if fresh.any? { |line| line =~ ELSEWHERE }
      # move returns nil (not false) for "You'll have to wait, X is presently using that locker booth"
      Entry.new(outcome: result.nil? ? :in_use : :refused)
    end

    # OPEN LOCKER and find the hoard container in it, or on the counter.
    #
    # @param cache [String, Regexp] the container's name
    # @param tries [Integer]
    # @param already_open [Boolean] skip the OPEN LOCKER (a second look at a stash)
    # @return [GameObj, nil]
    def open(cache, tries: 3, already_open: false)
      EO.settle
      tries.times do |attempt|
        EO.command('open locker', /exist=".*?" noun="(?:locker|chest)"|That is already open.|<prompt time=".*?">&gt;<\/prompt>/) if attempt.zero? && !already_open
        EO.settle
        stash = GameObj.loot.to_a.find { |item| item.name =~ /#{cache}/ }
        if stash.nil? && (counter = GameObj.room_desc.to_a.find { |item| item.name =~ /counter/ })
          EO.command("look on ##{counter.id}", /<container id='.*?' title=/, silent: true, quiet: true)
          stash = counter.contents.to_a.find { |item| item.name =~ /#{cache}/ }
        end
        if stash
          EO.command("look in ##{stash.id}", /<container id='.*?' title=/, silent: true, quiet: true)
          return stash
        end
        sleep 1
      end
      nil
    end

    # CLOSE LOCKER and step out, by the house's typed exit verb or the
    # room's opening. A mapped house locker with neither is left to the
    # next go2.
    #
    # @param way_out [String, nil]
    # @return [Boolean] whether a move out was made
    def leave(way_out: nil)
      locker = GameObj.loot.to_a.find { |item| item.name =~ /dark stained antique oak trunk|counter|locker/ }
      return false if locker.nil? || Room.current.tags.include?('locksmith')
      EO.result('close locker', /^You/)
      way = way_out.to_s.strip.empty? ? nil : way_out
      if way.nil?
        obj = (GameObj.loot.to_a + GameObj.room_desc.to_a).find { |o| o.noun =~ WAY }
        return false if obj.nil?
        way = "go #{obj.noun == 'tapestry' ? 'opening' : obj.noun}"
      end
      move way
      EO.settle
      true
    end
  end
end

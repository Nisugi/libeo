# frozen_string_literal: true

module EO
  module Guild
    # A task's location name to the rooms a hunt may use: a start room and
    # the boundary around them. ebounty find_location (2791),
    # limit_crawl_area (2836).
    module Location
      module_function

      # Larger locations are capped to a contiguous region of this size,
      # seeded from the room nearest the character; location rooms beyond the
      # cap become boundaries so the crawler does not wander past them.
      MAX_ROOMS = 100

      Area = Struct.new(:rooms, :start, :boundaries, keyword_init: true)

      # @param name [String] the location as the task names it ("Old Logging Road")
      # @param avoid [Array<Integer>] room ids never to hunt (the driver's bad rooms)
      # @param from [Room] where the character is, to seed the start room
      # @param max_rooms [Integer]
      # @return [Area] rooms (ids), start (id), boundaries (ids as strings, for a profile)
      # @raise [Error] when no mapped room carries that location
      def resolve(name, avoid: [], from: Room.current, max_rooms: MAX_ROOMS)
        rooms = Room.list.select do |r|
          next false if r.location.to_s.empty?
          (name.to_s =~ /#{Regexp.escape(r.location)}/i || r.location.to_s =~ /#{Regexp.escape(name.to_s)}/i) && !avoid.include?(r.id)
        end.map(&:id)
        raise Error, "no mapped room for location #{name.inspect}" if rooms.empty?

        start = from.find_nearest(rooms)
        rooms = contiguous(start, rooms, max_rooms) if rooms.size > max_rooms

        boundaries = rooms.flat_map do |id|
          Room[id].wayto.keys.map(&:to_s).reject { |room| rooms.include?(room.to_i) }
        end
        Area.new(rooms: rooms, start: start.to_i, boundaries: boundaries.uniq)
      end

      # Breadth-first from +start+, restricted to +rooms+, at most +max_rooms+
      # of them: a connected region around where the character came in.
      #
      # @param start [Integer, String]
      # @param rooms [Array<Integer>]
      # @param max_rooms [Integer]
      # @return [Array<Integer>]
      def contiguous(start, rooms, max_rooms = MAX_ROOMS)
        selected = []
        queued = [start.to_i]
        until queued.empty? || selected.size >= max_rooms
          current = queued.shift
          next if selected.include?(current)
          selected.push(current)
          Room[current].wayto.keys.each do |room|
            neighbor = room.to_i
            next if selected.include?(neighbor) || queued.include?(neighbor)
            next unless rooms.include?(neighbor)
            queued.push(neighbor)
          end
        end
        selected
      end
    end
  end
end

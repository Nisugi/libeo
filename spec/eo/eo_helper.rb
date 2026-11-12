# frozen_string_literal: true

require_relative '../spec_helper'

# The libeo files are loaded by libeo.lic inside Lich. Specs load the one
# file under test and stand in for the Lich globals it touches with
# stub_const, so nothing here needs a running Lich.
module EOSpec
  # A room as the files see it: id, uid, tags, location, and exits (wayto)
  # keyed by neighbour id as a string.
  FakeRoom = Struct.new(:id, :uid, :tags, :location, :wayto, keyword_init: true) do
    def initialize(id:, uid: [], tags: [], location: nil, wayto: {})
      super(id: id, uid: uid, tags: tags, location: location, wayto: wayto)
    end

    def timeto = wayto.transform_values { 1 }
  end

  # A map of FakeRooms answering Room.list, Room[id], Room.current and the
  # two searches the files use.
  class FakeMap
    attr_accessor :current

    def initialize(rooms)
      @rooms = rooms.to_h { |r| [r.id, r] }
      @current = rooms.first
    end

    def list = @rooms.values

    def [](key)
      return @rooms[key] if key.is_a?(Integer)
      return @rooms[key.to_i] if key.to_s =~ /\A\d+\z/
      uid = key.to_s.sub(/\Au/i, '').to_i
      @rooms.values.find { |r| r.uid.include?(uid) }
    end

    # Unweighted breadth-first distances from +from+.
    def distances(from)
      dist = { from.id => 0 }
      queue = [from.id]
      until queue.empty?
        here = queue.shift
        @rooms[here].wayto.each_key do |n|
          n = n.to_i
          next if dist.key?(n)
          dist[n] = dist[here] + 1
          queue.push(n)
        end
      end
      dist
    end
  end
end

RSpec.shared_context 'a fake map' do
  let(:rooms) { [] }
  let(:map) { EOSpec::FakeMap.new(rooms) }

  before do
    fake = map
    room_class = Class.new do
      define_singleton_method(:list) { fake.list }
      define_singleton_method(:[]) { |key| fake[key] }
      define_singleton_method(:current) { fake.current }
    end
    fake.list.each do |room|
      room.define_singleton_method(:find_nearest) do |ids|
        dist = fake.distances(self)
        ids.select { |id| dist.key?(id) }.min_by { |id| dist[id] }
      end
      room.define_singleton_method(:dijkstra) { [nil, fake.distances(self)] }
    end
    stub_const('Room', room_class)
  end
end

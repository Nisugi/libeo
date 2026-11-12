# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/guild/tables'
require_relative '../../scripts/eo/guild/location'

RSpec.describe EO::Guild::Location do
  include_context 'a fake map'

  # A road of five rooms (1..5) in "Old Logging Road", a side room 6 off
  # room 3 in the same location, and town rooms 10 and 11 attached at each end.
  let(:rooms) do
    road = (1..5).map do |id|
      exits = {}
      exits[(id - 1).to_s] = 'w' if id > 1
      exits[(id + 1).to_s] = 'e' if id < 5
      exits['10'] = 'n' if id == 1
      exits['11'] = 's' if id == 5
      exits['6'] = 'path' if id == 3
      EOSpec::FakeRoom.new(id: id, location: 'Old Logging Road', wayto: exits)
    end
    road + [
      EOSpec::FakeRoom.new(id: 6, location: 'Old Logging Road', wayto: { '3' => 'out' }),
      EOSpec::FakeRoom.new(id: 10, location: "Wehnimer's Landing", wayto: { '1' => 's' }),
      EOSpec::FakeRoom.new(id: 11, location: 'Danjirland', wayto: { '5' => 'n' }),
    ]
  end

  before { map.current = map[10] }

  it 'resolves a location to its rooms, the nearest as the start, and the exits out of it as boundaries' do
    area = described_class.resolve('Old Logging Road')
    expect(area.rooms).to contain_exactly(1, 2, 3, 4, 5, 6)
    expect(area.start).to eq(1)
    expect(area.boundaries).to contain_exactly('10', '11')
  end

  it 'matches the task wording against the map location either way round' do
    expect(described_class.resolve('on Old Logging Road near Wehnimer').rooms).to include(1)
    expect(described_class.resolve('Logging').rooms).to include(1)
  end

  it 'leaves out rooms the driver says to avoid, which then become boundaries' do
    area = described_class.resolve('Old Logging Road', avoid: [6])
    expect(area.rooms).not_to include(6)
    expect(area.boundaries).to include('6')
  end

  it 'caps a large location to a connected region around the start' do
    area = described_class.resolve('Old Logging Road', max_rooms: 3)
    expect(area.rooms.size).to eq(3)
    expect(area.rooms).to include(1)
    expect(area.rooms.each_cons(2).all? { |a, b| map[a].wayto.key?(b.to_s) || map[b].wayto.key?(a.to_s) }).to be(true)
    expect(area.boundaries).to include('10')
  end

  it 'raises for a location the map does not know, instead of exiting the script' do
    expect { described_class.resolve('Nowhere Road') }.to raise_error(EO::Guild::Error, /Nowhere Road/)
  end

  it 'crawls breadth-first and ignores rooms outside the location' do
    expect(described_class.contiguous(3, [1, 2, 3, 4, 5, 6], 4)).to contain_exactly(3, 2, 4, 6)
    expect(described_class.contiguous(1, [1, 2], 10)).to eq([1, 2])
  end
end

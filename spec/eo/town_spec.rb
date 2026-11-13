# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/travel'
require_relative '../../scripts/eo/command'
require_relative '../../scripts/eo/containers'
require_relative '../../scripts/eo/hands'
require_relative '../../scripts/eo/town'

RSpec.describe EO::Town do
  include_context 'a fake map'

  # Coldriver Village (Hinterwilds) at 1, its gemshop at 2; Icemule's square
  # at 10 with a pawnshop at 11, reachable only through the transport at 5.
  let(:rooms) do
    [EOSpec::FakeRoom.new(id: 1, uid: [7503205], tags: %w[town], location: 'the Hinterwilds', wayto: { '2' => 'e', '5' => 'n' }),
     EOSpec::FakeRoom.new(id: 2, tags: %w[gemshop], location: 'the Hinterwilds', wayto: { '1' => 'w' }),
     EOSpec::FakeRoom.new(id: 5, uid: [4132054], location: 'the Hinterwilds', wayto: { '1' => 's', '10' => 'n' }),
     EOSpec::FakeRoom.new(id: 10, uid: [4042150], tags: %w[town], location: 'Icemule Trace', wayto: { '5' => 's', '11' => 'e' }),
     EOSpec::FakeRoom.new(id: 11, tags: %w[pawnshop], location: 'Icemule Trace', wayto: { '10' => 'w' }),
     EOSpec::FakeRoom.new(id: 20, location: 'Mist Harbor, Four Winds Isle', wayto: {})]
  end

  before do
    fake = map
    fake.list.each do |room|
      room.define_singleton_method(:find_nearest_by_tag) do |tag|
        dist = fake.distances(self)
        fake.list.select { |r| r.tags.include?(tag) && dist.key?(r.id) }.min_by { |r| dist[r.id] }&.id
      end
      room.define_singleton_method(:path_to) do |other|
        # the rooms on the way, by walking the parents back
        dist = fake.distances(self)
        return nil unless dist.key?(other.id)
        path = []
        here = other.id
        until here == id
          path.unshift(here)
          here = fake.list.find { |r| dist[r.id] == dist[here] - 1 && r.wayto.key?(here.to_s) }.id
        end
        path
      end
    end
    stub_const('Map', Class.new do
      define_singleton_method(:list) { fake.list }
      define_singleton_method(:ids_from_uid) { |uid| fake.list.select { |r| r.uid.include?(uid) }.map(&:id) }
    end)
  end

  it 'knows Four Winds Isle by the room location' do
    expect(described_class.fwi?(map[20])).to be(true)
    expect(described_class.fwi?(map[1])).to be(false)
    expect(described_class.fwi?(nil)).to be(false)
  end

  it 'refuses a trip out of the Hinterwilds for the shops it lacks, unless travelling is fine' do
    map.current = map[1]
    expect(described_class.shop_elsewhere?('pawnshop')).to be(true)
    expect(described_class.shop_elsewhere?('gemshop')).to be(false)
    expect(described_class.nearest_shop('pawnshop')).to be_nil
    expect(described_class.nearest_shop('pawnshop', far_is_fine: true)).to eq(11)
    expect(described_class.nearest_shop('gemshop')).to eq(2)
    map.current = map[10]
    expect(described_class.nearest_shop('pawnshop')).to eq(11)
  end

  it 'finds a shop in a named town and says whether it is in the region' do
    map.current = map[1]
    expect(described_class.in_town('pawnshop', 'icemule').id).to eq(11)
    expect(described_class.in_town('pawnshop', 'atlantis')).to be_nil
    expect(described_class.in_region('gemshop', 'Cold River')).to eq(2)
    expect(described_class.in_region('pawnshop', 'Icemule Trace')).to be_nil
    map.current = map[10]
    expect(described_class.in_region('pawnshop', 'Icemule Trace')).to eq(11)
  end
end

RSpec.describe EO::Town, '.keep_silver' do
  let(:walks) { [] }
  let(:bank) { double('bank', deposit: 500, withdraw: 100, f2p?: false, pinefar?: false) }

  def carrying(silver)
    stub_const('Lich::Gemstone::Currency', Module.new { define_singleton_method(:silver) { |**| silver } })
    stub_const('Lich::Gemstone::Bank', bank)
  end

  it 'stays away from the bank when the silver is already right' do
    carrying(100)
    expect(described_class.keep_silver(keep: 100, go: -> { walks << :bank })).to eq(:none)
    expect(walks).to be_empty
  end

  it 'deposits everything and takes the keeper silvers back' do
    carrying(600)
    expect(described_class.keep_silver(keep: 100, go: -> { walks << :bank })).to eq(:done)
    expect(walks).to eq([:bank])
    expect(bank).to have_received(:withdraw).with(100)
  end

  it 'goes anyway when forced, and says when there is no bank to take it' do
    carrying(0)
    allow(bank).to receive_messages(deposit: nil, f2p?: true)
    expect(described_class.keep_silver(go: -> { walks << :bank }, force: true)).to eq(:no_bank)
    expect(walks).to eq([:bank])
  end
end

RSpec.describe EO::Hands do
  it 'names READY list keys the way READY and STORE want them' do
    expect(described_class.ready_word(:secondary_weapon)).to eq('2weapon')
    expect(described_class.ready_word('ranged_weapon')).to eq('ranged')
    expect(described_class.ready_word(:weapon)).to eq('weapon')
  end
end

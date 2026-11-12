# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/guild/tables'
require_relative '../../scripts/eo/guild/escort_routes'
require_relative '../../scripts/eo/guild/escort'

RSpec.describe EO::Guild::Escort do
  let(:task) do
    "I've got a special mission for you.  A certain client has hired us to provide a protective escort on his upcoming journey.  " \
      'Go to the area just inside the North Gate and WAIT for him to meet you there.  You must guarantee his safety to Icemule Trace ' \
      'as soon as you can, being ready for any dangers that the two of you may face.  Good luck!'
  end

  it 'names a trip from the pickup wording and the destination town, with or without "the"' do
    expect(described_class.trip('the area just inside the North Gate', 'Icemule Trace')).to eq('landing_to_icemule')
    expect(described_class.trip('area just inside the North Gate', 'Icemule Trace')).to eq('landing_to_icemule')
    expect(described_class.trip('the area just inside the Sapphire Gate', "Ta'Vaalor")).to eq('illy_to_vaalor')
    expect(described_class.trip('somewhere new', 'Icemule Trace')).to be_nil
    expect(described_class.trip('the area just inside the North Gate', 'Atlantis')).to be_nil
  end

  it 'reads the trip from the task text: pickup room, start town, destination, silver to carry' do
    trip = described_class.trip_from(task)
    expect(trip.pickup_room).to eq(223)
    expect(trip.start_town).to eq("Wehnimer's Landing")
    expect(trip.destination).to eq('Icemule Trace')
    expect(trip.travel_cost).to eq(0)
    expect(described_class.trip_from(task.sub('Icemule Trace', 'Zul Logoth')).travel_cost).to eq(20)
  end

  it 'raises for no task or a place the tables do not know' do
    expect { described_class.trip_from('You are not currently assigned a task.') }.to raise_error(EO::Guild::Error, /no escort task/)
    expect { described_class.trip_from(task.sub('North Gate', 'West Gate')) }.to raise_error(EO::Guild::Error, /unmatched pickup/)
    expect { described_class.trip_from(task.sub('Icemule Trace', 'Atlantis')) }.to raise_error(EO::Guild::Error, /unmatched destination/)
  end

  it 'has the same pickups and dropoffs as ebounty did, by short name' do
    described_class::PICKUPS.each_value { |(town, _)| expect(described_class::SHORT).to have_key(town) }
    described_class::DROPOFFS.each_key { |town| expect(described_class::SHORT).to have_key(town) }
    expect(EO::Guild::Tables::ESCORT_PICKUPS.keys.map { |k| described_class.pickup_key(k) }).to match_array(described_class::PICKUPS.keys)
    expect(EO::Guild::Tables::ESCORT_DROPOFFS.keys).to match_array(described_class::DROPOFFS.keys)
  end

  it 'carries the travel cost table both ways between every pair of towns' do
    towns = described_class::DROPOFFS.keys
    towns.each do |from|
      (towns - [from]).each { |to| expect(described_class::TRAVEL_COST.dig(from, to)).to be_a(Integer), "#{from} -> #{to}" }
    end
  end

  it 'has a route of a known kind for every special edge, each between two different rooms' do
    kinds = %i[climb careful careful_hands careful_hide sneak search ferry cart crack steps ladder misty loop]
    expect(described_class::ROUTES.size).to eq(87) # every edge escortgo2 1.0.5 had
    described_class::ROUTES.each do |edge, (kind, _)|
      from, to = edge.split(',')
      expect(from).not_to eq(to)
      expect(kinds).to include(kind), "#{edge} is #{kind}"
    end
  end

  it 'hears an ambush as ours only until the next room, and the client cry only from our client' do
    walk_client = '12345'
    stub_const('Script', Class.new { def self.current = Struct.new(:name).new('escortgo2') })
    hooks = {}
    stub_const('DownstreamHook', Class.new do
      define_singleton_method(:add) { |name, action| hooks[name] = action }
      define_singleton_method(:remove) { |name| hooks.delete(name) }
    end)
    ambush = described_class::Ambush.new(walk_client).install
    feed = ->(line) { hooks.values.first.call(line) }

    feed.call(%(A human traveller #{walk_client} fearfully exclaims, "It's an ambush!"))
    expect(ambush.mine).to be(true)
    expect(ambush.staggered).to be(false)
    feed.call("<pushStream id='room'/>")
    expect(ambush.mine).to be(false)
    feed.call(%(A human traveller 99 fearfully exclaims, "It's an ambush!"))
    expect(ambush.mine).to be(false)
    feed.call('<compass></compass>A bandit suddenly leaps from the shadows!')
    expect(ambush.mine).to be(true)
    expect(ambush.staggered).to be(true)
    ambush.remove
    expect(hooks).to be_empty
  end

  it 'has policy defaults that mean pause, no hiding, no haste, no herbs' do
    policy = described_class::Policy.new
    expect(policy.attack_script).to be_nil
    expect([policy.poach, policy.hide, policy.haste, policy.useherbs]).to eq([false, false, false, false])
    expect(policy.targetable).to eq([])
  end
end

# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/travel'
require_relative '../../scripts/eo/guild/tables'
require_relative '../../scripts/eo/guild/escort'
require_relative '../../scripts/eo/guild/heirloom'
require_relative '../../scripts/eo/guild/forage'
require_relative '../../scripts/eo/guild/rescue'

RSpec.describe EO::Guild::Escort do
  it 'names a trip from the pickup wording and the destination town' do
    expect(described_class.trip('the area just inside the North Gate', 'Icemule Trace')).to eq('landing_to_icemule')
    expect(described_class.trip('the area just inside the Sapphire Gate', "Ta'Vaalor")).to eq('illy_to_vaalor')
  end

  it 'has no name for a pickup or destination the tables do not know' do
    expect(described_class.trip('somewhere new', 'Icemule Trace')).to be_nil
    expect(described_class.trip('the area just inside the North Gate', 'Atlantis')).to be_nil
  end
end

RSpec.describe EO::Guild::Heirloom::Policy do
  it 'reads its options as strings or symbols' do
    policy = described_class.new(options: %w[use_right run])
    expect(policy.use?(:use_right)).to be(true)
    expect(policy.use?('run')).to be(true)
    expect(policy.use?(:use_213)).to be(false)
    expect(described_class.new.use?(:run)).to be(false)
  end
end

RSpec.describe EO::Guild::Forage::Policy do
  it 'carries the options and the healing choice' do
    policy = described_class.new(options: [:hiding], skip_healing: true)
    expect(policy.use?(:hiding)).to be(true)
    expect(policy.skip_healing).to be(true)
  end
end

RSpec.describe 'EO::Guild::Heirloom.wander' do
  include_context 'a fake map'

  # 1 - 2 - 3 in a row, with 9 off room 2 as a boundary
  let(:rooms) do
    [EOSpec::FakeRoom.new(id: 1, wayto: { '2' => 'e' }),
     EOSpec::FakeRoom.new(id: 2, wayto: { '1' => 'w', '3' => 'e', '9' => 'n' }),
     EOSpec::FakeRoom.new(id: 3, wayto: { '2' => 'w' }),
     EOSpec::FakeRoom.new(id: 9, wayto: { '2' => 's' })]
  end
  let(:moves) { [] }

  before do
    m = moves
    EO.define_singleton_method(:move) { |way| m << way }
    map.current = map[2]
  end

  after { EO.singleton_class.remove_method(:move) }

  it 'steps to a room not yet visited, never across a boundary' do
    visited = ['1']
    EO::Guild::Heirloom.wander(['9'], visited)
    expect(moves).to eq(['e'])
    expect(visited).to eq(%w[1 3])
  end

  it 'falls back to the least recently visited neighbour when every exit is known' do
    visited = %w[3 1]
    EO::Guild::Heirloom.wander(['9'], visited)
    expect(moves).to eq(['e'])
    expect(visited).to eq(%w[1 3])
  end
end

RSpec.describe EO::Guild::Rescue do
  it 'knows the contact text' do
    expect(described_class.contact?('You have made contact with the child you are to rescue and you must get him back alive.')).to be(true)
    expect(described_class.contact?('You have been tasked to rescue the young runaway son of a local citizen.')).to be(false)
  end
end

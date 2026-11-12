# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/travel'
require_relative '../../scripts/eo/guild/tables'
require_relative '../../scripts/eo/guild/disablers'
require_relative '../../scripts/eo/guild/rescue'

RSpec.describe EO::Guild::Disablers do
  let(:npc) { Struct.new(:id, :name, :status, keyword_init: true) }
  let(:fake_spell) { Struct.new(:known?, :affordable?, :mana_cost, :active?, keyword_init: true) }
  let(:spells) { {} }

  # A known, affordable spell at a mana cost; the table's entry is in play.
  def know(num, cost:, active: false)
    spells[num] = fake_spell.new(known?: true, affordable?: true, mana_cost: cost, active?: active)
  end

  before do
    table = spells
    unknown = fake_spell.new(known?: false, affordable?: false, mana_cost: 0, active?: false)
    stub_const('Spell', Class.new { define_singleton_method(:[]) { |n| table[n] || unknown } })
    stub_const('Skills', Class.new { def self.elair = 0 })
    stub_const('GameObj', Class.new { def self.npcs = []; def self.targets = [] })
    described_class.define_singleton_method(:mana) { 100 }
    allow(described_class).to receive(:justice?).and_return(false)
  end

  after { described_class.singleton_class.remove_method(:mana) }

  it 'picks the cheapest spell the character knows and can afford' do
    know(201, cost: 1)
    know(501, cost: 5)
    know(1207, cost: 7)
    policy = described_class::Policy.new
    expect(described_class.best(policy, targets: [npc.new(id: 1, name: 'a kobold', status: '')], wounds: false)).to eq(201)
  end

  it 'keeps the mana the policy reserves' do
    know(201, cost: 1)
    know(501, cost: 5)
    policy = described_class::Policy.new(min_mana: 97)
    expect(described_class.best(policy, targets: [npc.new(id: 1, name: 'a kobold', status: '')], wounds: false)).to eq(201)
    expect(described_class.any?(described_class::Policy.new(min_mana: 100))).to be(false)
  end

  it 'takes the forced spell when it is castable' do
    know(201, cost: 1)
    know(617, cost: 17)
    policy = described_class::Policy.new(forced: 617)
    expect(described_class.best(policy, targets: [npc.new(id: 1, name: 'a kobold', status: '')], wounds: false)).to eq(617)
    expect(described_class::Policy.new(forced: 0).forced).to be_nil
    expect(described_class::Policy.new(forced: false).forced).to be_nil
  end

  it 'drops a spell the target shrugs off' do
    know(501, cost: 5)
    know(1207, cost: 7)
    policy = described_class::Policy.new
    ghost = [npc.new(id: 1, name: 'a ghost', status: '')]
    expect(described_class.best(policy, targets: ghost, wounds: false)).to eq(1207)
  end

  it 'under justice uses only the town-safe spells' do
    allow(described_class).to receive(:justice?).and_return(true)
    know(135, cost: 1)
    know(201, cost: 2)
    policy = described_class::Policy.new
    expect(described_class.best(policy, targets: [npc.new(id: 1, name: 'a kobold', status: '')], wounds: false)).to eq(201)
  end

  it 'with several targets prefers a sanctuary over any cheaper multi-target spell' do
    know(135, cost: 1)
    know(201, cost: 1)
    know(213, cost: 13)
    policy = described_class::Policy.new
    two = [npc.new(id: 1, name: 'a kobold', status: ''), npc.new(id: 2, name: 'a kobold', status: '')]
    expect(described_class.best(policy, targets: two, wounds: false)).to eq(213)
  end

  it 'with several targets and no sanctuary takes the cheapest multi-target spell' do
    know(135, cost: 1)
    know(201, cost: 1)
    know(504, cost: 4)
    policy = described_class::Policy.new
    two = [npc.new(id: 1, name: 'a kobold', status: ''), npc.new(id: 2, name: 'a kobold', status: '')]
    expect(described_class.best(policy, targets: two, wounds: false)).to eq(135)
    stub_const('Skills', Class.new { def self.elair = 20 })
    know(135, cost: 10)
    expect(described_class.best(policy, targets: two, wounds: false)).to eq(504)
  end

  it 'returns nothing when no disabler is known' do
    expect(described_class.best(described_class::Policy.new, targets: [], wounds: false)).to be_nil
  end

  it 'leaves out creatures already disabled or known untargetable' do
    policy = described_class::Policy.new(untargetable: ['a statue'])
    stub_const('GameObj', Class.new do
      define_singleton_method(:targets) do
        [Struct.new(:name, :status).new('a kobold', ''), Struct.new(:name, :status).new('a kobold', 'stunned'),
         Struct.new(:name, :status).new('a statue', '')]
      end
    end)
    expect(described_class.live_targets(policy).map(&:name)).to eq(['a kobold'])
  end
end

RSpec.describe EO::Guild::Rescue do
  it 'knows every home a child names, by the town square' do
    expect(described_class::HOMES["Wehnimer's Landing"]).to eq('u7120')
    expect(described_class::HOMES['the County of Torre']).to eq(EO::Guild::Tables::TOWN_UIDS["River's Rest"])
    expect(described_class::HOMES['Vornavis']).to eq(EO::Guild::Tables::TOWN_UIDS['Solhaven'])
    expect(described_class::HOMES['Kharam-Dzu']).to eq(described_class::HOMES['Kharam Dzu'])
  end

  it 'recognises the child answer and the contact text' do
    expect('The child says, "Please, take me home to Icemule Trace!"').to match(described_class::CHILD_ANSWER)
    expect(described_class.contact?('You have made contact with the child you are to rescue and you must get him back alive.')).to be(true)
    expect(described_class.contact?('You have been tasked to rescue the young runaway son of a local citizen.')).to be(false)
  end

  it 'finds the child in the room, or gives up after the wait' do
    child = Struct.new(:id, :noun).new('123', 'child')
    stub_const('GameObj', Class.new { define_singleton_method(:npcs) { [child] } })
    expect(described_class.find_child).to eq('123')
    stub_const('GameObj', Class.new { def self.npcs = [] })
    expect(described_class.find_child(timeout: 0)).to be_nil
  end
end

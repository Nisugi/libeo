# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/command'
require_relative '../../scripts/eo/guild/tables'
require_relative '../../scripts/eo/herbs/table'
require_relative '../../scripts/eo/herbs/injuries'
require_relative '../../scripts/eo/herbs/heal'

RSpec.describe EO::Herbs::Heal do
  let(:item) { Struct.new(:id, :name, :noun) }
  let(:empty) { item.new(nil, 'Empty', nil) }
  let(:acantha) { item.new('7', 'some acantha leaf', 'leaf') }
  let(:sack) { double('sack', contents: { all: [] }) }
  let(:policy) { described_class::Policy.new }
  let(:wounds) { [] }

  before do
    hands = empty
    stub_const('GameObj', Module.new do
      define_singleton_method(:right_hand) { hands }
      define_singleton_method(:left_hand) { hands }
    end)
    stub_const('Wounds', Module.new do
      define_singleton_method(:leftArm) { 0 }
      define_singleton_method(:rightArm) { 0 }
    end)
    allow(EO::Herbs::Injuries).to receive(:next_type) { |skip:, **| wounds.find { |w| skip.none? { |area| w.include?(area) } } }
    allow(described_class).to receive(:cast_spells)
    allow(EO).to receive(:settle)
    described_class.define_singleton_method(:waitrt?) { nil }
    described_class.define_singleton_method(:sleep) { |*| nil }
    stub_const('Lich::Messaging', Module.new { define_singleton_method(:msg) { |*| nil } })
  end

  describe '.dose' do
    it 'is done when there is nothing to treat' do
      expect(described_class.dose(sack: sack, policy: policy)).to eq([:done, nil])
    end

    it 'takes the herb from the sack and eats it' do
      wounds << 'blood'
      allow(described_class).to receive(:find).and_return(acantha)
      allow(sack).to receive(:take).and_return(false)
      allow(EO).to receive(:result).and_return('You take a bite of your acantha leaf.')
      used = []

      expect(described_class.dose(sack: sack, policy: policy, used: used)).to eq([:dosed, 'blood'])
      expect(EO).to have_received(:result).with('eat my leaf', anything)
      expect(used).to eq(['7'])
    end

    it 'skips a type the sack lacks from then on' do
      wounds.push('minor head wound', 'blood')
      allow(described_class).to receive(:find).and_return(nil)
      skip = []

      expect(described_class.dose(sack: sack, policy: policy, skip: skip)).to eq([:missing, 'minor head wound'])
      expect(skip).to eq(%w[head neck])
    end

    it 'tells the game refusing more apart from a dose' do
      wounds << 'blood'
      allow(described_class).to receive(:find).and_return(acantha)
      allow(sack).to receive(:take).and_return(false)
      allow(EO).to receive(:result).and_return("Why don't you leave some for others?")
      expect(described_class.dose(sack: sack, policy: policy).first).to eq(:enough)
    end
  end

  describe '.use' do
    it 'doses until nothing is left, gathering what was missing' do
      wounds.push('minor head wound', 'blood')
      allow(described_class).to receive(:find) { |_contents, type, _policy| type == 'blood' ? acantha : nil }
      allow(sack).to receive(:take).and_return(false)
      allow(EO).to receive(:result) { wounds.delete('blood') && 'You take a bite of your acantha leaf.' }

      result = described_class.use(sack: sack, policy: policy)
      expect(result.outcome).to eq(:healed)
      expect(result.missing).to eq(['minor head wound'])
    end
  end
end

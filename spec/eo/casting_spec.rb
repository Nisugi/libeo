# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/casting'

RSpec.describe EO::Casting do
  let(:spell) { Struct.new(:circle, :results) }

  def skills(emc: 0, smc: 0, mmc: 0)
    stub_const('Skills', Class.new do
      define_singleton_method(:emc) { emc }
      define_singleton_method(:smc) { smc }
      define_singleton_method(:mmc) { mmc }
    end)
  end

  def prof(name) = stub_const('Stats', Class.new { define_singleton_method(:prof) { name } })

  it 'allows one more cast per 25 lore ranks in the circles the spell draws on' do
    prof('Wizard')
    skills(emc: 74)
    expect(described_class.max_multicast(spell.new(4))).to eq(3)
    prof('Empath')
    skills(smc: 50, mmc: 50)
    expect(described_class.max_multicast(spell.new(11))).to eq(4)
    expect(described_class.max_multicast(spell.new(1))).to eq(4)
    expect(described_class.max_multicast(spell.new(7))).to eq(1)
    prof('Warrior')
    skills(emc: 30, smc: 10)
    expect(described_class.max_multicast(spell.new(4))).to eq(2)
  end

  it 'casts at a target or at oneself and reads the answer' do
    caster = Class.new do
      attr_reader :sent

      def initialize(answers) = (@answers = answers) && (@sent = [])

      def cast(arg = nil)
        @sent << arg
        @answers.shift
      end
    end
    spell = caster.new(['[Spell Hindrance for Mage Armor]', 'You cast'])
    expect(described_class.cast(spell, target: 'Ann', multicast: 3)).to eq(:success)
    expect(spell.sent).to eq(['at Ann 3', 'at Ann 3'])
    expect(described_class.cast(caster.new(['Cast at what?']), target: 'Bob')).to eq(:bad_target)
    expect(described_class.cast(caster.new(['Spells of War cannot be cast here.']))).to eq(:refused_here)
    self_cast = caster.new(['You cast'])
    described_class.cast(self_cast, argument: 'shield')
    expect(self_cast.sent).to eq(['shield'])

    stuck = caster.new(['[Spell Hindrance for Mage Armor]'] * 5)
    expect(described_class.cast(stuck)).to eq(:hindered)
    expect(stuck.sent.size).to eq(described_class::MAX_HINDERED)
  end

  it 'gives the resources sensible defaults' do
    r = described_class::Resources.new(reserve: '20')
    expect([r.reserve, r.source, r.bail, r.wander_to_wrack]).to eq([20, nil, false, false])
  end
end

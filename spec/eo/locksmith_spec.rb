# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/locksmith'

RSpec.describe EO::Locksmith do
  let(:box) { Struct.new(:id, :name, :noun, :type, keyword_init: true) }

  it 'knows the boxes the town locksmith will not open' do
    expect(described_class.town_openable?(box.new(name: 'a steel case', noun: 'case'))).to be(false)
    expect(described_class.town_openable?(box.new(name: 'an iron coffer', noun: 'coffer'))).to be(true)
    expect(described_class.town_openable?(box.new(name: 'an iron coffer', noun: 'coffer'), refused: ['an iron coffer'])).to be(false)
  end

  describe 'Pool' do
    let(:pool) { described_class::Pool }

    it 'puts a box in hand first and drops repeats' do
      held = [box.new(id: '1', type: 'box'), box.new(id: '9', type: 'weapon')]
      found = [box.new(id: '2', type: 'box'), box.new(id: '1', type: 'box')]
      expect(pool.order(held: held, found: found, passed: [box.new(id: '3', type: 'box')]).map(&:id)).to eq(%w[1 2 3])
    end

    it 'tips from base at an empty pool towards max at a full one' do
      expect(pool.tip(0, base: 100, max: 1000, alpha: 1)).to eq(100)
      expect(pool.tip(50, base: 100, max: 1000, alpha: 1)).to eq(550)
      expect(pool.tip(100, base: 100, max: 1000, alpha: 2)).to eq(1000)
      expect(pool.tip_for(0, 2, base: 100, max: 1000, alpha: 1)).to eq(109 + 118)
      expect(pool.tip_for(99, 5, base: 100, max: 1000, alpha: 1)).to eq(1000)
    end

    it 'counts the boxes and the ones ready in the last list' do
      lines = ['old list', "here's the list of boxes we have for you.",
               '  1. A steel case', '     It is ready to be RETURNED.', '  2. An iron coffer', '<prompt>']
      expect(pool.list_counts(lines)).to eq([2, 1])
      expect(pool.list_counts(["You haven't given us any boxes to be worked on."])).to eq([0, 0])
      expect(pool.list_counts(['nothing'])).to eq([0, 0])
    end
  end
end

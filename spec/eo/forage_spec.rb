# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/guild/tables'
require_relative '../../scripts/eo/guild/forage'

RSpec.describe EO::Guild::Forage do
  describe 'names' do
    it 'turns the task wording for ayana into what FORAGE wants' do
      expect(described_class.forage_name('ayana berry')).to eq('ayana leaf')
      expect(described_class.forage_name("ayana'al root")).to eq("ayana'al leaf")
      expect(described_class.forage_name('acantha leaf')).to eq('acantha leaf')
    end

    it 'expands the mushroom names the task shortens' do
      expect(described_class.stow_name('white mushroom')).to eq('white hook mushroom')
      expect(described_class.stow_name('trafel mushroom')).to eq('black trafel mushroom')
      expect(described_class.stow_name('acantha leaf')).to eq('acantha leaf')
    end

    it 'matches a container item to the herb, including an ayana part' do
      expect(described_class.match?('some white hook mushroom', 'white mushroom')).to be(true)
      expect(described_class.match?('ayana', 'ayana leaf')).to be(true)
      expect(described_class.match?('acantha', 'acantha leaf')).to be(false)
      expect(described_class.match?('some acantha leaf', 'acantha leaf')).to be(true)
    end
  end

  describe '.rooms' do
    include_context 'a fake map'

    let(:rooms) do
      chain = (1..12).map do |id|
        exits = {}
        exits[(id - 1).to_s] = 'w' if id > 1
        exits[(id + 1).to_s] = 'e' if id < 12
        tags = id.even? ? ['herb:acantha leaf'] : []
        tags << 'herb:wolifrew lichen' if id == 3
        EOSpec::FakeRoom.new(id: id, location: id > 6 ? 'Far Field' : 'Near Field', tags: tags, wayto: exits)
      end
      chain
    end

    before { map.current = map[1] }

    it 'lists rooms tagged with the herb, nearest first, at most ten' do
      ids = described_class.rooms('acantha leaf', 'acantha leaf')
      expect(ids).to eq([2, 4, 6, 8, 10, 12])
    end

    it 'keeps only the named location when one is given' do
      expect(described_class.rooms('acantha leaf', 'acantha leaf', 'Far Field')).to eq([8, 10, 12])
    end

    it 'finds nothing for an herb no room carries' do
      expect(described_class.rooms('rose-marrow potion', 'rose-marrow potion')).to eq([])
    end
  end
end

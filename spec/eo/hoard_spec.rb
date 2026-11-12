# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/hoard'

RSpec.describe EO::Hoard do
  it 'names an item the way a jar label does' do
    expect(described_class.normalize('some uncut diamonds')).to eq('uncut diamond')
    expect(described_class.normalize('a tiny blue sapphire')).to eq('blue sapphire')
    expect(described_class.normalize('several pieces of polished onyxes')).to eq('onyx')
    expect(described_class.normalize('some rubies')).to eq('ruby')
    expect(described_class.normalize('essences of fire')).to eq('essence of fire')
    expect(described_class.normalize('a handful of golden seeds')).to eq('tiny golden seed')
    expect(described_class.normalize(nil)).to be_nil
  end

  it 'reads the manifest for a premium locker container' do
    lines = ['Thinking back, you recall the contents of your locker:', 'In a deep chest:',
             '  an empty jar', '  a glass jar containing uncut diamonds (12/50)', '  a glass jar containing rubies (50/50) (sealed)',
             '', 'In a weapon rack:', '  a jar containing emeralds (3/50)']
    allow(described_class).to receive(:kind?).and_return(true)
    found = described_class.parse_manifest(lines, 'deep chest', 'gem')
    expect(found).to eq([{ item: described_class::EMPTY_JARS, count: 1, full: '  -' },
                         { item: 'uncut diamond', count: 12, full: false },
                         { item: 'ruby', count: 50, full: true }])
    expect(described_class.parse_manifest(lines, 'clothing wardrobe', 'gem')).to be_nil
  end

  it 'names the manifest town, and a trunk lives in the Family Vault' do
    expect(described_class.manifest_town('Kharam-Dzu', 'deep chest')).to eq('Teras Isle')
    expect(described_class.manifest_town('Solhaven', 'iron trunk')).to eq('Family Vault')
    expect(described_class.manifest_town('Atlantis', 'deep chest')).to be_nil
  end

  it 'filters inventory by a phrase' do
    entries = [{ item: 'uncut diamond' }, { item: 'blue diamond' }, { item: 'ruby' }]
    expect(described_class.filter(entries, 'diamond').size).to eq(2)
    expect(described_class.filter(entries, 'Uncut  Diamond')).to eq([{ item: 'uncut diamond' }])
    expect(described_class.filter(entries, '')).to eq(entries)
  end
end

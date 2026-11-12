# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/command'
require_relative '../../scripts/eo/containers'
require_relative '../../scripts/eo/guild/tables'
require_relative '../../scripts/eo/guild/npcs'
require_relative '../../scripts/eo/guild/taskmaster'
require_relative '../../scripts/eo/guild/guards'

RSpec.describe EO::Guild::Guards do
  describe '.find_heirloom' do
    let(:earrings) { Struct.new(:id, :name).new('193716741', 'bejewelled platinum earrings') }
    let(:cloak) { Struct.new(:id, :name).new('179653339', 'plumille cloak') }

    before do
      allow(EO::Containers).to receive(:open).and_return(false)
      allow(EO::Containers).to receive(:fresh_contents).with(cloak).and_return([earrings])
    end

    it 'looks in each container for the item the task names' do
      expect(described_class.find_heirloom('bejewelled platinum earrings', [cloak], [])).to eq(earrings)
    end

    it 'matches whatever the case, and takes the name as text, not a pattern' do
      expect(described_class.find_heirloom('Bejewelled Platinum Earrings', [cloak], [])).to eq(earrings)
      expect(described_class.find_heirloom('bejewelled (platinum) earrings', [cloak], [])).to be_nil
    end
  end

  it 'reads the found heirloom without its article, "some" included' do
    text = 'You have located some bejewelled platinum earrings and should bring your find to the sentry just outside town.'
    expect(text[described_class::LOCATED, 1]).to eq('bejewelled platinum earrings')
  end
end

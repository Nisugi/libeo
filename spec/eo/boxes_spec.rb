# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/command'
require_relative '../../scripts/eo/containers'
require_relative '../../scripts/eo/boxes'

RSpec.describe EO::Boxes do
  let(:obj) { Struct.new(:id, :name, :contents, keyword_init: true) }
  let(:coins) { obj.new(id: '50', name: 'some silver coins') }

  def purse(*amounts)
    stub_const('Lich::Gemstone::Currency', Module.new { define_singleton_method(:silver) { |**| amounts.size > 1 ? amounts.shift : amounts.first } })
  end

  before { allow(EO).to receive(:settle) }

  describe '.open' do
    let(:box) { obj.new(id: '1', name: 'iron coffer') }

    it 'says when the box is locked' do
      allow(EO).to receive(:result).and_return('It appears to be locked.')
      expect(described_class.open(box)).to eq(:locked)
    end

    it 'looks in an opened box and waits for its contents' do
      allow(EO).to receive(:result).and_return('You open the iron coffer.')
      allow(EO).to receive(:command)
      allow(EO::Containers).to receive(:contents_ready?).and_return(true)
      expect(described_class.open(box)).to eq(:open)
      expect(EO).to have_received(:command).with('look in #1', anything, silent: true, quiet: true)
    end
  end

  describe '.coins' do
    it 'gathers the coins and counts them' do
      box = obj.new(id: '1', contents: [coins])
      purse(100, 350)
      allow(EO).to receive(:result).and_return('You gather the remaining 250 coins.')
      expect(described_class.coins(box)).to eq([:done, 250])
    end

    it 'asks to go on when the character can hold no more, and stops when told not to' do
      box = obj.new(id: '1', contents: [coins])
      purse(0, 1000)
      allow(EO).to receive(:result).and_return('You cannot hold any more silvers.')
      asked = 0
      expect(described_class.coins(box, full: -> { (asked += 1) && false })).to eq([:full, 1000])
      expect(asked).to eq(1)
    end

    it 'gives a charm five tries' do
      box = obj.new(id: '1', contents: [coins])
      purse(0)
      allow(EO).to receive(:result)
      expect(described_class.coins(box, charm: obj.new(id: '9')).first).to eq(:unknown)
      expect(EO).to have_received(:result).exactly(5).times
    end
  end

  describe '.keep?' do
    it 'keeps an empty valuable box when boxes sell, and a reliquary always' do
      expect(described_class.keep?(obj.new(name: 'gold strongbox', contents: []), sell: true)).to be(true)
      expect(described_class.keep?(obj.new(name: 'gold strongbox', contents: [coins]), sell: true)).to be(false)
      expect(described_class.keep?(obj.new(name: 'gold strongbox', contents: []), sell: false)).to be(false)
      expect(described_class.keep?(obj.new(name: 'ancient reliquary', contents: [coins]), sell: false)).to be(true)
    end
  end

  describe '.to_disk' do
    let(:disk) { Struct.new(:id, :name) }
    let(:box) { obj.new(id: '1', name: 'iron coffer') }

    before do
      disks = [disk.new('20', 'Friend'), disk.new('10', 'Me')]
      stub_const('Group', Module.new { define_singleton_method(:disks) { disks } })
      stub_const('Char', Module.new { define_singleton_method(:name) { 'Me' } })
      stub_const('Disk', Module.new { define_singleton_method(:find_by_name) { |_| true } })
      stub_const('GameObj', Module.new { define_singleton_method(:[]) { |id| id } })
    end

    it 'tries its own disk first, then the group, marking a refusal full' do
      tried = []
      full = {}
      put = ->(id, _box) { (tried << id) && id == '20' }
      expect(described_class.to_disk(box, full: full, put: put, group: true)).to eq('Friend')
      expect(tried).to eq(%w[10 20])
      expect(full).to eq('Me' => true)
    end

    it 'keeps to its own disk unless the group is allowed' do
      expect(described_class.to_disk(box, full: {}, put: ->(_id, _box) { false })).to be_nil
    end
  end
end

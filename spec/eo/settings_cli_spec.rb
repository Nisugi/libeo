# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/settings'

RSpec.describe 'EO::Settings from the command line' do
  describe '.coerce' do
    it 'reads each kind of setting from what was typed' do
      expect(EO::Settings.coerce(:a, true, %w[off])).to be(false)
      expect(EO::Settings.coerce(:a, false, %w[yes])).to be(true)
      expect(EO::Settings.coerce(:a, 3, %w[-12])).to eq(-12)
      expect(EO::Settings.coerce(:a, 0.5, %w[2.25])).to eq(2.25)
      expect(EO::Settings.coerce(:a, 0.5, %w[2])).to eq(2.0)
      expect(EO::Settings.coerce(:a, '', %w[my seller])).to eq('my seller')
      expect(EO::Settings.coerce(:a, [], %w[ogre troll])).to eq(%w[ogre troll])
    end

    it 'refuses what does not fit, saying why' do
      expect { EO::Settings.coerce(:quiet, true, %w[maybe]) }.to raise_error(ArgumentError, /boolean .* for quiet but got "maybe"/)
      expect { EO::Settings.coerce(:max, 3, %w[lots]) }.to raise_error(ArgumentError, /integer value for max/)
      expect { EO::Settings.coerce(:rate, 0.5, %w[1.2.3]) }.to raise_error(ArgumentError, /decimal value for rate/)
      expect { EO::Settings.coerce(:odd, {}, %w[x]) }.to raise_error(ArgumentError, /don't know how to change a Hash/)
    end
  end

  describe '.update_from_words' do
    let(:said) { [] }
    let(:say) { ->(type, text) { said << [type, text] } }
    let(:settings) { { sell_gold: true, debug: false } }

    it 'changes the named setting and yields to save it' do
      saved = nil
      expect(EO::Settings.update_from_words(%w[sell-gold off], settings, say: say) { |s| saved = s.dup }).to eq(:sell_gold)
      expect(settings[:sell_gold]).to be(false)
      expect(saved).to eq(settings)
      expect(said).to include(['info', ' Updated sell_gold to false'])
    end

    it 'lists the settings for a name it does not know, changing nothing' do
      expect(EO::Settings.update_from_words(%w[nope 1], settings, say: say) { raise 'saved' }).to be_nil
      expect(said.map(&:first)).to include('error')
      expect(settings).to eq(sell_gold: true, debug: false)
    end

    it 'keeps quiet in debug while debug itself is changed' do
      EO::Settings.update_from_words(%w[debug on], settings, say: say)
      expect(said).to eq([['info', ' Updated debug to true']])
    end
  end
end

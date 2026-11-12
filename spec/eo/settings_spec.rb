# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/settings'

RSpec.describe EO::Settings do
  let(:setup) do
    Class.new do
      extend EO::Settings::Registry
      include EO::Settings::Controls

      # A script's Setup writes these in its class body; a block would bind them
      # to the top level instead, so they are set on the class.
      const_set(:SPINS, { tip: [100, 5, 0], rate: [1, 0.1, 1] }.freeze)
      class_variable_set(:@@categories, {
        general: { tip: { default: 0 }, quiet: { default: false }, names: { default: [] } },
        internal: { debug: { default: false }, rate: { default: 0.5 } }
      })

      def initialize(settings) = @settings = settings
    end
  end

  describe '.available?' do
    it 'is false outside Lich' do
      hide_const('Lich')
      expect(described_class.available?).to be(false)
    end

    it 'needs the WebUI on and the named form' do
      webui = Module.new { def self.presentation_enabled? = true }
      stub_const('Lich::WebUI', webui)
      stub_const('Lich::WebUI::SettingsForm', Class.new)
      expect(described_class.available?(:SettingsForm)).to be(true)
      expect(described_class.available?(:ListSettingsForm)).to be(false)
    end
  end

  describe EO::Settings::Registry do
    it 'finds a key in its category' do
      expect(setup.get_category(:debug)).to eq(:internal)
      expect(setup.get_setting(:tip)).to eq(default: 0)
      expect(setup.get_category(:gone)).to be_nil
      expect(setup.get_setting(:gone)).to be_nil
    end

    it 'fills missing settings with copies of the defaults' do
      settings = setup.fill_defaults({ tip: 20 })
      expect(settings).to include(tip: 20, quiet: false, names: [], debug: false)
      settings[:names] << 'x'
      expect(setup.fill_defaults({})[:names]).to eq([])
    end

    it 'replaces blank values only when asked' do
      expect(setup.fill_defaults({ names: [] }, blank: false)[:names]).to eq([])
      expect(setup.fill_defaults({ tip: '' }, blank: true)[:tip]).to eq(0)
      expect(setup.fill_defaults({ tip: '' })[:tip]).to eq('')
    end

    it 'prunes settings no category knows' do
      expect(setup.prune({ tip: 1, gone: 2 })).to eq(tip: 1)
    end
  end

  describe EO::Settings::Controls do
    it 'shows a saved number clamped and on its step' do
      expect(setup.new({ tip: 37 }).spin_value(:tip)).to eq(35)
      expect(setup.new({ tip: 500 }).spin_value(:tip)).to eq(100)
      expect(setup.new({ rate: '0.46' }).spin_value(:rate)).to eq(0.5)
    end

    it 'keeps the saved number when the spin box was left alone' do
      form = setup.new({ tip: 37 })
      expect(form.number_setting(:tip, 35)).to eq(37)
      expect(form.number_setting(:tip, 140.4)).to eq(100)
      expect { form.number_setting(:tip, 'x') }.to raise_error(ArgumentError, /tip must be a number/)
    end

    it 'knows a checkbox by its default' do
      expect(setup.new({}).boolean?(:quiet)).to be(true)
      expect(setup.new({}).boolean?(:tip)).to be(false)
    end

    it 'builds optional control props' do
      form = setup.new({})
      expect(form.place(nil)).to eq({})
      expect(form.place('1')).to eq(slot: '1')
      expect(form.tip_for('t')).to eq(tooltip: 't')
      expect(form.hint_for('h')).to eq(placeholder: 'h')
    end
  end
end

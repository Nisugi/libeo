# frozen_string_literal: true

require_relative 'eo_helper'
require 'tmpdir'
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

  describe 'profiles' do
    around do |example|
      Dir.mktmpdir { |dir| (@dir = dir) && example.run }
    end

    before do
      stub_const('DATA_DIR', @dir)
      stub_const('XMLData', Struct.new(:game).new('GSIV'))
      stub_const('Char', Struct.new(:name).new('Nisugi'))
    end

    it 'lives in the character directory' do
      expect(described_class.profile_path('eloot')).to eq(File.join(@dir, 'GSIV', 'Nisugi', 'eloot.yaml'))
      expect(described_class.profile_path('eloot', name: 'Alt')).to eq(File.join(@dir, 'GSIV', 'Alt', 'eloot.yaml'))
    end

    it 'saves, making the directory, and loads back' do
      expect(described_class.load_profile('eloot')).to be_nil
      path = described_class.save_profile('eloot', { tip: 5 })
      expect(File.exist?(path)).to be(true)
      expect(described_class.load_profile('eloot')).to eq(tip: 5)
    end

    it "saves what a CharSettings proxy wraps, at any depth, so the file loads back" do
      proxy = Class.new do
        attr_reader :target

        def initialize(target) = @target = target
        def self.name = 'Lich::Common::SettingsProxy'
      end
      described_class.save_profile('eherbs', { prices: proxy.new({ 28_938 => { blood: proxy.new({ cost: 200 }) } }), list: proxy.new([1]) })
      expect(described_class.load_profile('eherbs')).to eq(prices: { 28_938 => { blood: { cost: 200 } } }, list: [1])
    end

    describe '.store' do
      let(:dying) { [] }

      before do
        hooks = dying
        described_class.define_singleton_method(:before_dying) { |&block| hooks << block }
        stub_const('CharSettings', { 'delay' => 2.5, 'boundary' => ['10'] })
      end

      after { described_class.singleton_class.remove_method(:before_dying) }

      it 'copies the listed CharSettings once, then keeps to the profile' do
        store = described_class.store('ewander', migrate: %w[delay boundary])
        expect(store['delay']).to eq(2.5)
        expect(described_class.load_profile('ewander')).to eq('delay' => 2.5, 'boundary' => ['10'])

        CharSettings['delay'] = 9.0
        expect(described_class.store('ewander', migrate: %w[delay])['delay']).to eq(2.5)
      end

      it 'saves on a write, and a list changed in place when the script exits' do
        store = described_class.store('ewander', migrate: %w[boundary])
        store['delay'] = 1.0
        expect(described_class.read(:ewander)['delay']).to eq(1.0)

        store['boundary'].push('20')
        dying.each(&:call)
        expect(described_class.load_profile('ewander')['boundary']).to eq(%w[10 20])
      end
    end

    describe '.read' do
      before { described_class.instance_variable_set(:@held, {}) }

      it 'serves what was preloaded, frozen, without touching the file again' do
        described_class.save_profile('eloot', { skin: true, unskinnable: ['rat'] })
        described_class.instance_variable_set(:@held, {})
        described_class.preload(%w[eloot])
        File.delete(described_class.profile_path('eloot'))

        held = described_class.read(:eloot)
        expect(held).to eq(skin: true, unskinnable: ['rat'])
        expect(held).to be_frozen
        expect(held[:unskinnable]).to be_frozen
      end

      it 'takes the new values on save, apart from the caller' do
        settings = { skin: true }
        described_class.save_profile('eloot', settings)
        settings[:skin] = false
        expect(described_class.read(:eloot)).to eq(skin: true)
      end

      it 'is nil for a script without a profile, and ignores another character' do
        expect(described_class.read(:ewaggle)).to be_nil
        FileUtils.mkdir_p(File.join(@dir, 'GSIV', 'Alt'))
        File.write(File.join(@dir, 'GSIV', 'Alt', 'eloot.yaml'), { skin: false }.to_yaml)
        described_class.load_profile('eloot', name: 'Alt')
        expect(described_class.read(:eloot)).to be_nil
      end
    end
  end

  describe EO::Settings::ListForm do
    let(:form_class) do
      Class.new do
        extend EO::Settings::Registry
        include EO::Settings::ListForm

        const_set(:PAGE_ID, 'tester-setup')
        const_set(:SPINS, { tip: [100, 5, 0] }.freeze)
        const_set(:MEMBERS, { kinds: [%w[gem Gem], ['wand case', 'Wand case']] }.freeze)
        const_set(:LISTS, %i[keep].freeze)
        const_set(:SELECTS, { stance: [%w[none None], %w[offensive Offensive]] }.freeze)
        const_set(:EXCLUSIVE, {}.freeze)
        class_variable_set(:@@categories, {
          general: { tip: { default: 0 }, kinds: { default: [] }, keep: { default: [] }, stance: { default: '' },
                     note: { default: '' }, quiet: { default: false } }
        })

        def initialize(settings) = @settings = settings
        def shown_keys = self.class.categories[:general].keys
        def finish(result) = result.merge(finished: true)
        def accept_entry?(_key, text) = text != 'refused'
      end
    end

    it 'names member checkboxes without spaces' do
      expect(form_class.new({}).member_key(:kinds, 'wand case')).to eq(:'kinds-wand_case')
    end

    it 'shows an unknown choice as the first, and keeps it when left alone' do
      form = form_class.new({ stance: 'bogus', tip: 37, kinds: %w[gem custom], note: ' x ' })
      values = form.form_values
      expect(values).to include(stance: 'none', tip: 35, 'kinds-gem': true, 'kinds-wand_case': false, note: ' x ')
      result = form.normalize(values.merge(note: ' y '))
      expect(result).to include(stance: 'bogus', tip: 37, kinds: %w[custom gem], note: 'y', finished: true)
    end

    it 'adds and deletes list entries on a copy, refusing what the script refuses' do
      form = form_class.new({ keep: %w[b] })
      form.instance_variable_set(:@drafts, { keep: %w[b] })
      form.add_entry(:keep, ' a ')
      form.add_entry(:keep, 'refused')
      form.add_entry(:keep, 'b')
      expect(form.drafts[:keep]).to eq(%w[a b])
      form.delete_entry(:keep, 0)
      expect(form.list_rows(:keep)).to eq([{ 'entry' => 'b' }])
    end
  end

  describe EO::Settings::Listing do
    let(:lister) do
      Class.new do
        extend EO::Settings::Registry
        include EO::Settings::Listing

        class_variable_set(:@@categories, { general: { names: { default: [] }, tip: { default: 0 } }, internal: { debug: { default: false } } })
        attr_reader :out

        def initialize(settings) = (@settings = settings) && (@out = [])
        def _respond(line = '') = @out << line
        def monsterbold_start = '<b>'
        def monsterbold_end = '</b>'
      end
    end

    it 'prints every category, a list numbered in order, without reordering the setting' do
      names = %w[b a a]
      form = lister.new({ names: names, tip: 5, debug: true })
      $frontend = 'wizard'
      form.list
      expect(form.out).to eq(["<b>= General =</b>\n", '  names:', '    1. a', '    2. a', '    3. b', '  tip: 5',
                              "<b>= Internal =</b>\n", '  debug: true'])
      expect(names).to eq(%w[b a a])
    end

    it 'wraps the listing in a mono block for Stormfront' do
      $frontend = 'stormfront'
      form = lister.new({ debug: false })
      form.list(cat_to_list: 'internal')
      expect(form.out).to eq(["<output class=\"mono\"/>\n", "<b>= Internal =</b>\n", '  debug: false', "<output class=\"\"/>\n"])
    end
  end
end

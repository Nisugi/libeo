# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/command'
require_relative '../../scripts/eo/hands'
require_relative '../../scripts/eo/loot'
require_relative '../../scripts/eo/skinning'

RSpec.describe EO::Skinning do
  let(:obj) { Struct.new(:id, :name, :type, keyword_init: true) }

  # Lich's top-level calls the module makes, answered here.
  def lich(**answers)
    answers.each { |name, value| described_class.define_singleton_method(name) { |*| value.respond_to?(:call) ? value.call : value } }
  end

  after do
    %i[waitrt? standing? dothistimeout].each do |name|
      described_class.singleton_class.remove_method(name) if described_class.singleton_class.method_defined?(name, false)
    end
  end

  describe '.exclusions' do
    it 'joins the critter exclusions as whole words and the skin exclusions' do
      pattern = described_class.exclusions({ critter_exclude: ['rat'], skin_exclude: ['wolf'] })
      expect('giant rat').to match(pattern)
      expect('pirate').not_to match(pattern)
      expect('werewolf').to match(pattern)
    end
  end

  describe '.choose' do
    let(:rat) { obj.new(id: '1', name: 'giant rat', type: 'aggressive npc') }
    let(:urchin) { obj.new(id: '2', name: 'cavern urchin', type: 'aggressive npc') }
    let(:bandit) { obj.new(id: '3', name: 'bandit', type: 'aggressive npc bandit') }
    let(:chimera) { obj.new(id: '4', name: 'rotting chimera', type: 'aggressive npc') }

    it 'splits the candidates into edged and blunt' do
      expect(described_class.choose([rat, urchin, bandit])).to eq([[rat], [urchin]])
    end

    it 'keeps to the bounty creature when given one' do
      expect(described_class.choose([rat, urchin], creature: 'Giant Rat')).to eq([[rat], []])
    end

    it 'tries the occasional skinner even when learned unskinnable' do
      allow(EO).to receive(:command).and_return(['A huge scorpion tail rises high from the rear.'])
      expect(described_class.choose([chimera, rat], unskinnable: ['rotting chimera', 'giant rat'])).to eq([[chimera], []])
    end

    it 'leaves the chimera without the tail out' do
      allow(EO).to receive(:command).and_return(['The twisted and confused form shambles.'])
      expect(described_class.choose([chimera], unskinnable: ['rotting chimera'])).to eq([[], []])
    end
  end

  describe '.with_tool' do
    let(:knife) { obj.new(id: '9', name: 'skinning knife') }
    let(:calls) { [] }
    let(:held) { [] }

    before do
      lich(waitrt?: nil)
      allow(EO::Hands).to receive(:holding?) { |tool| held.include?(tool) }
      stub_const('GameObj', Class.new { define_singleton_method(:left_hand) { Struct.new(:id).new('0') } })
    end

    def run(blunt: false)
      described_class.with_tool(knife, blunt: blunt,
                                       free: ->(hands) { calls << [:free, hands] },
                                       draw: ->(tool) { calls << :draw; held << tool },
                                       put_away: ->(_tool) { calls << :put_away }) { |hand| calls << hand }
    end

    it 'frees a hand, draws the tool, skins and puts it back' do
      run
      expect(calls).to eq([[:free, :one], :draw, 'right', :put_away])
    end

    it 'uses an edged tool already in hand and leaves it there' do
      held << knife
      run
      expect(calls).to eq(['right'])
    end

    it 'frees both hands for a blunt tool' do
      run(blunt: true)
      expect(calls.first).to eq([:free, :both])
    end

    it 'does not skin when the tool cannot be drawn' do
      expect(described_class.with_tool(knife, blunt: false, free: ->(_) {}, draw: ->(_) {}, put_away: ->(_) { calls << :put_away }) { calls << :skinned }).to be_nil
      expect(calls).to be_empty
    end
  end

  describe '.stand_up' do
    it 'gives up after a few tries and goes back to its stance' do
      tries = 0
      lich(standing?: false, dothistimeout: -> { tries += 1 })
      stance = class_double('Lich::Gemstone::Stance', current: 'defensive', change: nil).as_stubbed_const
      stub_const('Effects::Debuffs', Module.new { define_singleton_method(:active?) { |_| false } })
      stub_const('GameObj', Class.new { define_singleton_method(:targets) { [] } })

      expect(described_class.stand_up).to be(false)
      expect(tries).to eq(5)
      expect(stance).to have_received(:change).with('offensive').ordered
      expect(stance).to have_received(:change).with('defensive').ordered
    end
  end
end

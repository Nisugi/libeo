# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/command'
require_relative '../../scripts/eo/cleanse/tables'
require_relative '../../scripts/eo/cleanse/hazards'
require_relative '../../scripts/eo/cleanse/disarms'
require_relative '../../scripts/eo/cleanse/traps'

RSpec.describe EO::Cleanse do
  let(:obj) { Struct.new(:id, :name, :noun, :type, keyword_init: true) }

  def spells(known)
    stub_const('Spell', Class.new do
      define_singleton_method(:[]) { |n| Struct.new(:num, :known?).new(n, known.include?(n)) }
    end)
  end

  def loot(*items)
    stub_const('GameObj', Class.new do
      define_singleton_method(:loot) { items }
    end)
  end

  describe EO::Cleanse::Policy do
    it 'defaults every choice off and ignores settings it does not carry' do
      policy = described_class.new(use_213: true, stop_scripts: 'bigshot', version: '2.5.0')
      expect(policy.use_213).to be(true)
      expect(policy.use_1011).to be(false)
      expect(policy.determination).to be(false)
    end
  end

  describe EO::Cleanse::BadTargets do
    it 'remembers ids as strings and drops the oldest past its size' do
      bad = described_class.new(2)
      bad << 1 << '2' << 3
      expect(bad.include?('1')).to be(false)
      expect(bad.include?(2)).to be(true)
      expect(bad.include?('3')).to be(true)
    end
  end

  it 'picks the first known spell for a job' do
    spells([1218, 119])
    expect(described_class.spell(:dispel).num).to eq(1218)
    expect(described_class.spell(:webs).num).to eq(1218)
    expect(described_class.spell(:breeze)).to be_nil
  end

  describe EO::Cleanse::Hazards do
    let(:bad) { EO::Cleanse::BadTargets.new }

    it 'finds a cloud to dispel, but not the fog, the mist, a gem or a refused one' do
      spells([])
      fog = obj.new(id: '1', name: 'cloud of thick ethereal fog', noun: 'fog', type: '')
      gem = obj.new(id: '2', name: 'cloud agate', noun: 'agate', type: 'gem')
      mist = obj.new(id: '3', name: 'cloud of acidic mist', noun: 'mist', type: '')
      dark = obj.new(id: '4', name: 'dark cloud', noun: 'cloud', type: '')
      loot(fog, gem, mist, dark)
      expect(described_class.cloud(bad)).to eq(dark)
      bad << '4'
      expect(described_class.cloud(bad)).to be_nil
    end

    it 'takes the acidic mist when a breeze is known' do
      spells([612])
      mist = obj.new(id: '3', name: 'cloud of acidic mist', noun: 'mist', type: '')
      loot(mist)
      expect(described_class.cloud(bad)).to eq(mist)
    end

    it 'finds globes, runestones and webs' do
      globe = obj.new(id: '5', name: 'chaotic spatial anomaly', noun: 'anomaly', type: '')
      stone = obj.new(id: '6', name: 'pale hovering runestone', noun: 'runestone', type: '')
      web = obj.new(id: '7', name: 'sticky web', noun: 'web', type: '')
      loot(globe, stone, web)
      expect(described_class.globe(bad)).to eq(globe)
      expect(described_class.runestone(bad)).to eq(stone)
      expect(described_class.web(bad)).to eq(web)
    end

    it 'reports a cleave or thieve only when it went into the wards' do
      globe = obj.new(id: '5', name: 'chaotic spatial anomaly', noun: 'anomaly', type: '')
      answers = {}
      cman = Module.new do
        define_singleton_method(:use) { |name, _target| answers[name] }
      end
      stub_const('Lich::Gemstone::CMan', cman)
      hit = 'You hang back for a moment and concentrate on the magical wards surrounding a globe, before unleashing your attack upon them!'
      answers['scleave'] = hit
      expect(described_class.maneuver('scleave', globe, :cleaved)).to eq(:cleaved)
      answers['scleave'] = 'You remain mentally drained from your last attempt to perceive the threads that connect a magical ward to its bearer.'
      expect(described_class.maneuver('scleave', globe, :cleaved)).to eq(:failed)
      answers['scleave'] = nil
      expect(described_class.maneuver('scleave', globe, :cleaved)).to eq(:failed)
      answers['sthieve'] = 'You hang back for a moment and concentrate on the magical wards surrounding a globe, before sneaking in an attack on them!'
      expect(described_class.maneuver('sthieve', globe, :thieved)).to eq(:thieved)
    end

    it 'aims without TARGET at the mist and the two globes that cannot be targeted' do
      allow(described_class).to receive(:target).and_return(false)
      expect(described_class.aim(obj.new(id: '1', name: 'silvery blue globe'))).to be(true)
      expect(described_class.aim(obj.new(id: '2', name: 'cloud of acidic mist'))).to be(true)
      expect(described_class.aim(obj.new(id: '3', name: 'chaotic spatial anomaly'))).to be(false)
    end
  end

  describe EO::Cleanse::Disarms do
    let(:hand) { Struct.new(:id, :name, :noun, keyword_init: true) }
    let(:vars) { Struct.new(:last_disarm).new(nil) }

    before { stub_const('UserVars', vars) }

    def hands(right, left)
      stub_const('GameObj', Class.new do
        define_singleton_method(:right_hand) { right }
        define_singleton_method(:left_hand) { left }
      end)
    end

    it 'reads what RECOVER ITEM picked up, by noun or by its words' do
      expect(described_class.spied_item(['You spy <a exist="1" noun="handaxe">a steel handaxe</a> and recover it!'])).to eq('handaxe')
      expect(described_class.spied_item(['You spy a steel handaxe and recover it!'])).to eq('a steel handaxe')
      expect(described_class.spied_item(['You find nothing recoverable.'])).to be_nil
      expect(described_class.same_item?('a steel handaxe', 'handaxe')).to be(true)
      expect(described_class.same_item?('a steel handaxe', 'axe')).to be(false)
    end

    it 'counts a weapon recovered only when it was not already in hand' do
      empty = hand.new(id: nil, name: 'Empty', noun: nil)
      axe = hand.new(id: '10', name: 'a handaxe', noun: 'handaxe')
      hands(axe, empty)
      expect(described_class.recovered?(['10'], 'handaxe')).to be(false)
      hands(axe, hand.new(id: '11', name: 'a handaxe', noun: 'handaxe'))
      expect(described_class.recovered?(['10'], 'handaxe')).to be(true)
      hands(axe, hand.new(id: '12', name: 'a dagger', noun: 'dagger'))
      expect(described_class.recovered?(['10'], 'handaxe')).to be(false)
    end

    it 'reads an old bare room number as no disarms' do
      vars.last_disarm = 1234
      expect(described_class.list).to eq([])
    end

    it 'forgets one disarm, a room, or an earlier disarm found instead' do
      vars.last_disarm = [{ id: 'a', item: 'handaxe', room: 1 }, { id: 'b', item: 'mace', room: 1 },
                          { id: 'c', item: 'sword', room: 2 }, { id: 'd', item: 'dagger', room: nil }]
      described_class.remove_found('a heavy mace', 1)
      expect(described_class.list.map { |e| e[:id] }).to eq(%w[a c d])
      described_class.remove_room(1, 'c')
      expect(described_class.list.map { |e| e[:id] }).to eq(%w[d])
      described_class.remove_room(nil, 'x')
      expect(described_class.tracked?('d')).to be(true)
      described_class.remove('d')
      expect(described_class.list).to eq([])
    end

    describe '.search' do
      let(:room) { Struct.new(:id).new(5) }

      before do
        r = room
        stub_const('Room', Class.new { define_singleton_method(:current) { r } })
        hands(hand.new(id: '10', name: 'a shield', noun: 'shield'), hand.new(id: nil, name: 'Empty', noun: nil))
        allow(described_class).to receive(:empty_hands)
        allow(described_class).to receive(:kneeling?).and_return(true)
        allow(EO).to receive(:settle)
        vars.last_disarm = [{ id: 'old', item: 'mace', room: 5 }, { id: 'new', item: 'handaxe', room: 5 }]
      end

      def answers(*replies)
        allow(EO::Cleanse).to receive(:command).with('recover item', anything).and_return(*replies)
      end

      it 'keeps looking past an earlier disarm, then finds the one it wants' do
        answers(['You spy a heavy mace and recover it!'], ['You spy a steel handaxe and recover it!'])
        seen = []
        result = described_class.search('handaxe', known_ids: ['10'], room_id: 5, id: 'new') { |e, f| seen << [e, f] }
        expect(result.outcome).to eq(:recovered)
        expect(seen).to eq([[:other, 'a heavy mace']])
        expect(described_class.list).to eq([])
      end

      it 'stops when the room holds nothing, forgetting the room' do
        answers(['You find nothing recoverable here.'])
        expect(described_class.search('handaxe', known_ids: ['10'], room_id: 5, id: 'new').outcome).to eq(:nothing_here)
        expect(described_class.list).to eq([])
      end

      it 'stops when too hurt to search, keeping the disarm' do
        answers(["You're not in any condition to be searching around."])
        expect(described_class.search('handaxe', known_ids: ['10'], room_id: 5, id: 'new').outcome).to eq(:cannot_search)
        expect(described_class.tracked?('new')).to be(true)
      end

      it 'counts each time the hands are emptied to search' do
        answers(['In order to recover something, you need a free hand.'], ['You spy a steel handaxe and recover it!'])
        expect(described_class.search('handaxe', known_ids: ['10'], room_id: 5, id: 'new').stashes).to eq(2)
      end
    end
  end

  describe EO::Cleanse::Traps do
    it 'leaves a trap to try again only when the search was cut short by something passing' do
      expect(described_class.retry?(:moved)).to be(true)
      expect(described_class.retry?(:muckled)).to be(true)
      expect(described_class.retry?(:clear)).to be(false)
    end

    it 'waits out the curse where the settings say' do
      expect(described_class.safe_room('1234')).to eq(1234)
      expect(described_class.safe_room('sanctuary')).to eq('sanctuary')
    end
  end
end

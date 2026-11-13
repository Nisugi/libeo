# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/command'
require_relative '../../scripts/eo/loot'

RSpec.describe EO::Loot do
  let(:obj) { Struct.new(:id, :name, :noun, :type, keyword_init: true) }

  def thing(name, type: 'gem', noun: name.split.last, id: '100')
    obj.new(id: id, name: name, noun: noun, type: type)
  end

  describe '.words' do
    it 'matches each entry as whole words, and nothing for an empty list' do
      pattern = described_class.words(['rat', /blue (?:crystal|gem)/])
      expect('a giant rat').to match(pattern)
      expect('a pirate').not_to match(pattern)
      expect('a blue gem').to match(pattern)
      expect('anything').not_to match(described_class.words(nil))
    end
  end

  describe 'Policy.from_settings' do
    it 'reads the policy from eloot settings' do
      policy = described_class::Policy.from_settings({ loot_types: %w[gem], loot_exclude: ['rock'], loot_keep: [],
                                                       unlootable: ['dust'], crumbly: nil }, level: 42, heirloom: 'locket')
      expect(policy.types).to eq(%w[gem])
      expect('a rock').to match(policy.exclude)
      expect('a rocky gem').not_to match(policy.exclude)
      expect(policy.keep).to be_nil
      expect(policy.unlootable).to eq(['dust'])
      expect(policy.crumbly).to eq([])
      expect([policy.level, policy.heirloom]).to eq([42, 'locket'])
    end
  end

  describe '.junk?' do
    let(:policy) { described_class::Policy.new(types: %w[gem]) }

    it 'rejects features, spell effects, disks and negative ids' do
      expect(described_class.junk?(thing('some ivy', type: nil), policy)).to be(true)
      expect(described_class.junk?(thing('golden light', type: nil), policy)).to be(true)
      expect(described_class.junk?(thing('Ann disk', type: 'box'), policy)).to be(true)
      expect(described_class.junk?(thing('wooden door', type: nil, noun: 'door'), policy)).to be(true)
      expect(described_class.junk?(thing('a diamond', id: '-5'), policy)).to be(true)
      expect(described_class.junk?(thing('a diamond'), policy)).to be(false)
    end

    it 'leaves weapons and armor to the specials, but not uncommon ones' do
      expect(described_class.junk?(thing('a broadsword', type: 'weapon'), policy)).to be(true)
      expect(described_class.junk?(thing('a gleaming broadsword', type: 'weapon,uncommon'), policy)).to be(false)
    end

    it 'remembers what crumbles, and what will not pick up when told to' do
      crumbly = described_class::Policy.new(crumbly: ['rough leather quiver'])
      expect(described_class.junk?(thing('rough leather quiver', type: 'clothing'), crumbly)).to be(true)
      stuck = described_class::Policy.new(unlootable: ['odd rock'], log_unlootables: true)
      expect(described_class.junk?(thing('odd rock', type: nil), stuck)).to be(true)
      expect(described_class.junk?(thing('odd rock', type: nil), described_class::Policy.new(unlootable: ['odd rock']))).to be(false)
    end

    it 'never rejects a kept name or the bounty heirloom' do
      keep = described_class::Policy.new(keep: /golden light/)
      expect(described_class.junk?(thing('golden light', type: nil), keep)).to be(false)
      heirloom = described_class::Policy.new(heirloom: 'silver locket')
      expect(described_class.junk?(thing('severed silver locket', type: 'jewelry'), heirloom)).to be(false)
    end
  end

  describe '.wanted?' do
    it 'takes the chosen types and refuses the unchosen' do
      policy = described_class::Policy.new(types: %w[gem box])
      expect(described_class.wanted?(thing('a diamond', type: 'gem'), policy)).to be(true)
      expect(described_class.wanted?(thing('a scroll', type: 'scroll'), policy)).to be(false)
      expect(described_class.wanted?(thing('an oddity', type: 'unknown'), policy)).to be(true)
    end

    it 'lets an exclusion win, and keeps cursed out unless chosen' do
      policy = described_class::Policy.new(types: %w[gem], exclude: /diamond/)
      expect(described_class.wanted?(thing('a diamond'), policy)).to be(false)
      expect(described_class.wanted?(thing('a ruby', type: 'gem,cursed'), described_class::Policy.new(types: %w[gem]))).to be(false)
      expect(described_class.wanted?(thing('a ruby', type: 'gem,cursed'), described_class::Policy.new(types: %w[gem cursed]))).to be(true)
    end

    it 'takes oblivion quartz only at level 100, and always the heirloom' do
      quartz = thing('shard of oblivion quartz', type: 'gem,cursed')
      expect(described_class.wanted?(quartz, described_class::Policy.new(types: %w[gem], level: 100))).to be(true)
      expect(described_class.wanted?(quartz, described_class::Policy.new(types: %w[gem], level: 99))).to be(false)
      locket = thing('a silver locket', type: 'jewelry')
      expect(described_class.wanted?(locket, described_class::Policy.new(types: %w[gem], heirloom: 'silver locket'))).to be(true)
    end
  end

  describe '.search' do
    let(:corpse) { Struct.new(:id, :name, :noun, :status, keyword_init: true) }
    let(:hand) { Struct.new(:id, :name) }
    let(:stowed) { [] }
    let(:freed) { [] }

    before do
      described_class.define_singleton_method(:waitrt?) { nil }
      game = Class.new do
        class << self
          attr_accessor :right, :left
        end
        def self.right_hand = right
        def self.left_hand = left
        def self.new(id, noun, name) = Struct.new(:id, :noun, :name).new(id, noun, name)
      end
      game.right = hand.new(nil, 'Empty')
      game.left = hand.new(nil, 'Empty')
      stub_const('GameObj', game)
    end

    after { described_class.singleton_class.remove_method(:waitrt?) }

    def search(thing, *answers, determination: false)
      allow(EO).to receive(:command).and_return(*answers)
      described_class.search(thing, free: ->(h) { freed << h }, stow: ->(item) { stowed << item.name }, determination: determination)
    end

    it 'stores what falls at your feet' do
      rat = corpse.new(id: '5', name: 'giant rat', noun: 'rat')
      search(rat, ['You search the giant rat.',
                   '<pushBold/> ** A glint of light catches your eye, and you notice an <a exist="77" noun="ruby">uncut ruby</a> at your feet! **'])
      expect(stowed).to eq(['uncut ruby'])
      expect(freed).to eq([:one])
    end

    it 'stores what a bramble puts in the left hand' do
      vine = corpse.new(id: '6', name: 'frozen vine', noun: 'vine')
      allow(EO).to receive(:command) do
        GameObj.left = hand.new('88', 'icy berry')
        ['You search the frozen vine.']
      end
      described_class.search(vine, free: ->(h) { freed << h }, stow: ->(item) { stowed << item.name })
      expect(freed).to eq([:left])
      expect(stowed).to eq(['icy berry'])
    end

    it 'tries again after Sigil of Determination when too hurt' do
      sigil = double(affordable?: true, active?: false)
      allow(sigil).to receive(:cast)
      stub_const('Spell', Class.new { define_singleton_method(:[]) { |_| sigil } })
      rat = corpse.new(id: '5', name: 'giant rat', noun: 'rat')
      search(rat, ['You are not in any condition to do that.'], ['You search the giant rat.'], determination: true)
      expect(sigil).to have_received(:cast).once
      expect(EO).to have_received(:command).twice
    end

    it 'leaves the excluded, children and the gone' do
      expect(described_class.searchable?(corpse.new(name: 'giant rat'), exclude: /rat/)).to be(false)
      expect(described_class.searchable?(corpse.new(name: 'lost child'))).to be(false)
      expect(described_class.searchable?(corpse.new(name: 'giant rat', status: 'gone'))).to be(false)
      expect(described_class.searchable?(corpse.new(name: 'giant rat', status: 'dead'))).to be(true)
    end
  end
end

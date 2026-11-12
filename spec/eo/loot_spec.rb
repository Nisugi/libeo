# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/loot'

RSpec.describe EO::Loot do
  let(:obj) { Struct.new(:id, :name, :noun, :type, keyword_init: true) }

  def thing(name, type: 'gem', noun: name.split.last, id: '100')
    obj.new(id: id, name: name, noun: noun, type: type)
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
end

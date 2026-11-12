# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/guild/tables'
require_relative '../../scripts/eo/guild/completion'

RSpec.describe EO::Guild::Completion do
  let(:fake_task) { Struct.new(:type, :requirements, keyword_init: true) }
  let(:item) { Struct.new(:id, :name, keyword_init: true) }
  let(:bag) { Struct.new(:contents, keyword_init: true) }

  def task(type, **need) = fake_task.new(type: type, requirements: need)

  def rule(type = :cull, **opts)
    described_class::Rule.new(task: task(type, **opts.delete(:need) || {}), **opts)
  end

  def done?(r, text, mind: 100, **state)
    r.complete?(bounty_text: text, mind_percent: mind, **state)
  end

  let(:succeeded) { "You have succeeded in your task and can return to the Adventurer's Guild." }
  let(:tasked) { 'You have been tasked to suppress kobold activity on Old Logging Road.' }
  let(:none) { 'You are not currently assigned a task.' }

  describe 'names' do
    it 'singularises a skin the way the items are named' do
      expect(described_class.skin_name('rolton skins')).to eq('rolton skin')
      expect(described_class.skin_name('Hooves')).to eq('hoof')
      expect(described_class.skin_name('fang teeth')).to eq('fang tooth')
      expect(described_class.skin_name('wolf ruffs')).to eq('wolf ruff')
      expect(described_class.bundle_name('soft rolton skins')).to eq('rolton skins')
      expect(described_class.bundle_name('')).to be_nil
    end
  end

  describe 'counting' do
    it 'counts loose skins and measures bundles, except while hidden' do
      bundle = item.new(id: 7, name: 'a bundle of rolton skins')
      bags = [bag.new(contents: [item.new(id: 1, name: 'a rolton skin'), bundle, item.new(id: 2, name: 'a wolf pelt')])]
      util = Class.new { def self.quiet_command_xml(_c, _r) = ['You glance through the bundle and count a total of 4 <a exist="1">rolton skins</a>.'] }
      stub_const('Lich::Util', util)
      expect(described_class.skins_held(bags, 'rolton skins')).to eq(5)
      expect(described_class.skins_held(bags, 'rolton skins', hidden: true)).to eq(1)
      expect(described_class.skins_held(bags, 'wolf pelts')).to eq(1)
    end

    it 'counts gems whose name ends with the task gem' do
      bags = [bag.new(contents: [item.new(id: 1, name: 'an uncut diamond'), item.new(id: 2, name: 'a diamond'),
                                 item.new(id: 3, name: 'a diamond ring')])]
      expect(described_class.gems_held(bags, 'an uncut diamond')).to eq(1)
      expect(described_class.gems_held(bags, 'a diamond')).to eq(2)
      expect(described_class.gems_held(bags, '')).to eq(0)
    end
  end

  describe 'Rule' do
    it 'is complete when the task text says so and the mind is rested enough' do
      r = rule
      expect(done?(r, succeeded)).to be(true)
      expect(done?(r, 'You have failed in your task.')).to be(true)
      expect(done?(r, tasked)).to be(false)
      expect(done?(rule(mind_needed: 90), succeeded, mind: 80)).to be(false)
      expect(done?(rule(mind_needed: 90), succeeded, mind: 90)).to be(true)
    end

    it 'ignores the mind for a bandit task' do
      expect(done?(rule(:bandit), succeeded, mind: 0, bandit: true)).to be(true)
      expect(done?(rule(:bandit), tasked, mind: 0, bandit: true)).to be(false)
    end

    it 'under keep_hunting waits for the mind to come off saturated' do
      r = rule(keep_hunting: true)
      expect(done?(r, succeeded, saturated: true)).to be(false)
      expect(done?(r, succeeded, saturated: false)).to be(true)
    end

    it 'is complete with no task and no cooldown, so a new one can be fetched' do
      expect(done?(rule, none)).to be(true)
      expect(done?(rule, none, cooldown: true)).to be(false)
    end

    it 'ends a rescue once the child is found and in the room' do
      r = rule(:rescue)
      child = item.new(id: 9, name: 'a young child')
      expect(done?(r, 'You have made contact with the child you are to rescue.', npcs: [child])).to be(true)
      expect(done?(r, 'You have made contact with the child you are to rescue.', npcs: [])).to be(false)
    end

    it 'ends a skin task at the number plus the extra, at the count mind' do
      r = rule(:skin, need: { number: 2, skin: 'rolton skins' }, extra_skin: 1, count_mind: 50)
      bags = ->(n) { [bag.new(contents: Array.new(n) { |i| item.new(id: i, name: 'a rolton skin') })] }
      expect(done?(r, tasked, containers: bags.call(2))).to be(false)
      expect(done?(r, tasked, containers: bags.call(3))).to be(true)
      expect(done?(r, tasked, containers: bags.call(3), mind: 40)).to be(false)
    end

    it 'ends a gem task at the number' do
      r = rule(:gem, need: { number: 2, gem: 'an uncut diamond' })
      bags = [bag.new(contents: [item.new(id: 1, name: 'an uncut diamond'), item.new(id: 2, name: 'an uncut diamond')])]
      expect(done?(r, tasked, containers: bags)).to be(true)
      expect(done?(r, tasked, containers: [])).to be(false)
    end
  end
end

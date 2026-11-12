# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/command'
require_relative '../../scripts/eo/containers'
require_relative '../../scripts/eo/hands'

module EOSpec
  # GameObj's container registry: contents by container id.
  class FakeObjs
    attr_reader :containers

    def initialize = @containers = {}
  end

  Container = Struct.new(:id, :name, :objs) do
    def contents = objs.containers[id]
  end

  InvItem = Struct.new(:closed, :locked, :children, keyword_init: true) do
    def closed? = closed
    def locked? = locked
  end
end

RSpec.describe EO::Containers do
  let(:objs) { EOSpec::FakeObjs.new }
  let(:sack) { EOSpec::Container.new('7', 'a leather sack', objs) }
  let(:sent) { [] }
  let(:answers) { {} }
  let(:snapshot) { nil }

  before do
    registry = objs
    stub_const('GameObj', Class.new { define_singleton_method(:containers) { registry.containers } })
    snap = -> { snapshot }
    stub_const('Lich::Common::Inventory', Module.new { define_singleton_method(:refresh) { |**| snap.call } })
    out = sent
    replies = answers
    allow(EO).to receive(:command) do |command, _regex, **|
      out << command
      replies.fetch(command, [])
    end
    allow(described_class).to receive(:sleep)
  end

  context 'with the inventory feed' do
    let(:item) { EOSpec::InvItem.new(closed: true, locked: false, children: []) }
    let(:snapshot) { { '7' => item } }

    it 'opens a closed container and says it did' do
      answers['open #7'] = ['You open a leather sack.']
      objs.containers['7'] = [] # Lich lists it once it is open
      expect(described_class.open(sack)).to be(true)
      expect(sent).to eq(['open #7'])
    end

    it 'leaves an open container alone, even one Lich already lists' do
      item.closed = false
      objs.containers['7'] = []
      expect(described_class.open(sack)).to be(false)
      expect(sent).to be_empty
    end

    it 'opens a closed container that Lich lists from the snapshot' do
      objs.containers['7'] = [] # Inventory lists closed containers too
      expect(described_class.open(sack)).to be(true)
      expect(sent).to eq(['open #7'])
    end

    it 'does not claim an open the game refused' do
      answers['open #7'] = ['That is already open.']
      objs.containers['7'] = []
      expect(described_class.open(sack)).to be(false)
    end

    it 'never tries a locked container' do
      item.locked = true
      expect(described_class.open(sack)).to be(false)
      expect(described_class.ensure_open(sack)).to eq(:unknown)
      expect(sent).to be_empty
    end

    it 'ensures open from the snapshot, without LOOK IN' do
      expect(described_class.ensure_open(sack)).to eq(:nothing)
      item.closed = false
      item.children = [:herb]
      expect(described_class.ensure_open(sack)).to eq(:listed)
      expect(sent).to eq(['open #7'])
    end

    it 'reads fresh contents from the snapshot' do
      objs.containers['7'] = [:herb]
      expect(described_class.fresh_contents(sack)).to eq([:herb])
      expect(sent).to be_empty
    end
  end

  context 'without the feed, or for a container not carried' do
    it 'looks in, opens, and knows it opened it' do
      answers['look in #7'] = ['That is closed.']
      answers['open #7'] = ['You open a leather sack.']
      expect(described_class.open(sack)).to be(true)
      expect(sent.first(2)).to eq(['look in #7', 'open #7'])
    end

    it 'trusts a listed container to be open' do
      objs.containers['7'] = []
      expect(described_class.open(sack)).to be(false)
      expect(sent).to be_empty
    end

    it 'looks in for fresh contents' do
      described_class.fresh_contents(sack)
      expect(sent).to eq(['look in #7'])
    end
  end
end

RSpec.describe EO::Hands do
  let(:item) { Struct.new(:id, :name).new('5', 'a gem') }
  let(:stash) { Module.new }

  before do
    stub_const('Lich::Stash', stash)
    allow(stash).to receive(:in_hand?) { |obj| obj.id == '9' }
    allow(stash).to receive(:empty_hand?) { |side| side == :left }
  end

  it 'asks Lich which hand holds what' do
    expect(described_class.holding?(Struct.new(:id).new('9'))).to be(true)
    expect(described_class.holding?(nil)).to be(false)
  end

  it 'opens the way to a carried item before taking it' do
    stub_const('Wounds', Struct.new(:leftArm, :leftHand).new(0, 0))
    stub_const('Scars', Struct.new(:leftArm, :leftHand).new(0, 0))
    allow(stash).to receive(:in_hand?).and_return(false, true)
    expect(stash).to receive(:open_path_to).with(item).ordered
    expect(EO).to receive(:result).with('_drag #5 left', anything).ordered.and_return('You remove a gem.')
    allow(described_class).to receive(:sleep)
    stub_const('GameObj', Class.new { def self.right_hand = Struct.new(:id).new('1') })
    expect(described_class.take(item, stow: ->(_) {})).to eq(:held)
  end
end

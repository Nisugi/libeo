# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/command'
require_relative '../../scripts/eo/containers'
require_relative '../../scripts/eo/hands'
require_relative '../../scripts/eo/stow'

RSpec.describe EO::Stow do
  let(:obj) { Struct.new(:id, :name, :type, keyword_init: true) }
  let(:gems) { obj.new(id: '1', name: 'gem pouch') }
  let(:sack) { obj.new(id: '2', name: 'leather sack') }
  let(:first) { obj.new(id: '3', name: 'first cloak') }
  let(:second) { obj.new(id: '4', name: 'second cloak') }
  let(:ruby) { obj.new(id: '9', name: 'blue ruby', type: 'gem') }
  let(:rock) { obj.new(id: '8', name: 'rock', type: 'junk') }
  let(:learned) { [] }
  let(:stow) do
    described_class.new(bags: { gem: gems, default: sack, overflow_container_2: second, overflow_container: first },
                        learned: ->(kind, thing) { learned << [kind, thing.name] })
  end

  before do
    stub_const('Room', Class.new { define_singleton_method(:current) { Struct.new(:id).new(100) } })
    stow.define_singleton_method(:stunned?) { false }
  end

  it 'routes an item to its type bag, the default, then the overflow in number order' do
    expect(stow.route(ruby)).to eq([gems, sack, first, second])
    expect(stow.route(rock)).to eq([nil, sack, first, second])
  end

  it 'lists the bags to open before looting once each' do
    expect(stow.bags_for([ruby, rock, ruby])).to eq([sack, first, second, gems])
  end

  it 'skips a full bag and remembers it' do
    answers = { '1' => :full, '2' => :full, '3' => :stored }
    allow(EO::Hands).to receive(:store) { |bag, _item, **| answers[bag.id] }

    expect(stow.store(ruby)).to eq(first)
    expect(stow.full.keys).to eq(['gem pouch', 'leather sack'])
    expect(stow.full?(gems)).to be(true)

    expect(stow.store(ruby)).to eq(first)
    expect(EO::Hands).to have_received(:store).with(gems, ruby, anything).once
  end

  it 'does not mark a bag full over a gold ingot' do
    allow(EO::Hands).to receive(:store).and_return(:full)
    stow.put(sack, obj.new(id: '7', name: 'gold ingot'))
    expect(stow.full).to be_empty
  end

  it 'tells the caller what a put taught it' do
    allow(EO::Hands).to receive(:store).and_return(:crumbled)
    expect(stow.store(rock)).to eq(sack)
    expect(learned).to eq([[:crumbly, 'rock']])
  end

  it 'reports a bag that closed itself while keeping its contents' do
    allow(EO::Hands).to receive(:store) { |bag, _item, on_closed:, **| on_closed.call(bag) && :stored }
    stub_const('GameObj', Class.new { define_singleton_method(:containers) { { '2' => [] } } })
    sack.define_singleton_method(:contents) { [] }
    stow.put(sack, rock)
    expect(learned).to eq([[:auto_close, 'leather sack']])
  end

  it 'tells which route slots are not set, and answers nil when nothing took it' do
    allow(EO::Hands).to receive(:store).and_return(:full)
    skipped = []
    expect(stow.store(rock, skipped: ->(index) { skipped << index })).to be_nil
    expect(skipped).to eq([0])
  end

  it 'tells a bag that closes itself from one closed by hand, and passes on what it learns' do
    stub_const('GameObj', Class.new { define_singleton_method(:containers) { { '2' => [] } } })
    sack.define_singleton_method(:contents) { [] }
    first.define_singleton_method(:contents) { nil }
    expect(stow.closes_itself?(sack)).to be(true)
    expect(stow.closes_itself?(first)).to be(false)
    stow.learn(:auto_close, sack)
    expect(learned).to eq([[:auto_close, 'leather sack']])
  end
end

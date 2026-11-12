# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/guild/tables'
require_relative '../../scripts/eo/guild/policy'
require_relative '../../scripts/eo/guild/npcs'
require_relative '../../scripts/eo/guild/taskmaster'

# The taskmaster dialogue against a scripted game: fput answers from a list,
# the task state and bounty text are set by the example as the asks go by.
RSpec.describe EO::Guild::Taskmaster do
  let(:sent) { [] }
  let(:messages) { [] }

  before do
    spec = self
    @replies = []
    @type = :none
    @bounty = 'You are not currently assigned a task.'
    @after_ask = nil
    stub_const('Lich::Messaging', Module.new { define_singleton_method(:msg) { |k, t| spec.messages << [k, t] } })
    stub_const('Bounty', Class.new { define_singleton_method(:type) { spec.instance_variable_get(:@type) } })
    stub_const('Effects::Buffs', Class.new { def self.active?(_) = false })
    allow(EO::Guild::NPCs).to receive(:taskmaster).and_return('Taskmaster')
    allow(EO).to receive(:settle)
    described_class.define_singleton_method(:checkbounty) { spec.instance_variable_get(:@bounty) }
    described_class.define_singleton_method(:fput) do |cmd|
      spec.sent << cmd
      spec.instance_variable_get(:@after_ask)&.call
      spec.instance_variable_get(:@replies).shift || ''
    end
    described_class.define_singleton_method(:sleep) { |_| nil }
  end

  after do
    %i[checkbounty fput sleep].each { |m| described_class.singleton_class.remove_method(m) }
  end

  it 'asks for a task until one is held' do
    @after_ask = -> { @type = :cull; @bounty = 'You have been tasked to suppress kobold activity.' }
    expect(described_class.ask(:get)).to eq(:done)
    expect(sent).to eq(['ask Taskmaster about bounty'])
  end

  it 'asks for the boosted type while a boost runs' do
    stub_const('Effects::Buffs', Class.new { def self.active?(_) = true })
    @after_ask = -> { @type = :cull; @bounty = 'tasked' }
    described_class.get(EO::Guild::TaskPolicy.new(boost_type: 'culling'))
    expect(sent).to eq(['ask Taskmaster about bounty culling'])
    sent.clear
    @type = :none
    described_class.get(EO::Guild::TaskPolicy.new(boost_type: 'Any'))
    expect(sent).to eq(['ask Taskmaster about bounty'])
  end

  it 'asks twice for a removal and stops once no task is held' do
    @type = :cull
    @bounty = 'tasked'
    asks = 0
    @after_ask = lambda do
      asks += 1
      next unless asks == 2
      @type = :none
      @bounty = 'You are not currently assigned a task.'
    end
    expect(described_class.ask(:remove)).to eq(:done)
    expect(sent).to eq(['ask Taskmaster about removal'] * 2)
  end

  it 'returns early when the taskmaster says a task is already held' do
    @replies = ['The Taskmaster says, "You have already been assigned a task, Nisugi."']
    expect(described_class.ask(:get)).to eq(:already_assigned)
  end

  it 'finds the taskmaster again when the ask reached nobody' do
    @replies = ['Who are you trying to ask?', '']
    @after_ask = lambda do
      next if sent.size < 2
      @type = :cull
      @bounty = 'tasked'
    end
    expect(described_class.ask(:get)).to eq(:done)
    expect(EO::Guild::NPCs).to have_received(:taskmaster).twice
    expect(sent.size).to eq(2)
  end

  it 'retries when nothing changes and gives up after five rounds with a reason' do
    expect { described_class.ask(:get) }.to raise_error(EO::Guild::Error, /did not change after 5 attempts asking the taskmaster about bounty/)
    expect(sent.size).to eq(5)
    expect(messages.count { |k, _| k == 'warn' }).to eq(4)
  end

  it 'spends a voucher after a removal only when the policy allows and no boost runs' do
    @type = :cull
    @bounty = 'tasked'
    asks = 0
    @after_ask = lambda do
      asks += 1
      if asks == 2
        @type = :none
        @bounty = 'none'
      elsif asks == 4
        @type = :cull
        @bounty = 'new task'
      end
    end
    allow(described_class).to receive(:vouchers).and_return(1)
    described_class.remove(EO::Guild::TaskPolicy.new(use_vouchers: true))
    expect(sent).to eq(['ask Taskmaster about removal'] * 2 + ['ask Taskmaster about expediting'] * 2)

    sent.clear
    asks = 0
    @type = :cull
    described_class.remove(EO::Guild::TaskPolicy.new(use_vouchers: false))
    expect(sent).to eq(['ask Taskmaster about removal'] * 2)
  end
end

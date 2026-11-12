# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/command'

RSpec.describe 'EO.command and EO.result' do
  let(:sent) { [] }
  let(:waits) { [] }

  before do
    spec = self
    log = sent
    util = Module.new do
      define_singleton_method(:issue_command) { |cmd, _regex, **| log << cmd; spec.instance_variable_get(:@answers).shift }
    end
    stub_const('Lich::Util', util)
    w = waits
    EO.define_singleton_method(:waitrt?) { w << :rt }
    EO.define_singleton_method(:dothistimeout) { |cmd, _t, _r| log << cmd; spec.instance_variable_get(:@answers).shift&.first }
  end

  after do
    EO.singleton_class.remove_method(:waitrt?)
    EO.singleton_class.remove_method(:dothistimeout)
  end

  it 'returns the answer lines of a command that ran' do
    @answers = [['You glance through the sack.']]
    expect(EO.command('look in #1', /glance/)).to eq(['You glance through the sack.'])
    expect(sent).to eq(['look in #1'])
    expect(waits).to be_empty
  end

  it 'waits out a roundtime refusal and sends the command again' do
    @answers = [['...wait 2 seconds.'], ['Roundtime: 3 sec.'], ['You glance through the sack.']]
    expect(EO.command('look in #1', /glance/)).to eq(['You glance through the sack.'])
    expect(sent).to eq(['look in #1'] * 3)
    expect(waits).to eq(%i[rt rt])
  end

  it 'does the same for a single-line result' do
    @answers = [['Roundtime: 1 sec.'], ['You remove a sack.']]
    expect(EO.result('get #1', /You remove/)).to eq('You remove a sack.')
    expect(sent).to eq(['get #1', 'get #1'])
    expect(waits).to eq([:rt])
  end

  it 'returns nil when a result never came' do
    @answers = [[nil]]
    expect(EO.result('get #1', /You remove/)).to be_nil
  end
end

RSpec.describe 'EO.stand' do
  def stub_stand(stands_after)
    sent = []
    EO.define_singleton_method(:fput) { |cmd| sent << cmd }
    EO.define_singleton_method(:standing?) { sent.size >= stands_after }
    EO.define_singleton_method(:settle) { nil }
    sent
  end

  after { %i[fput standing? settle].each { |m| EO.singleton_class.remove_method(m) } }

  it 'stands and stops once standing' do
    sent = stub_stand(2)
    expect(EO.stand).to be(true)
    expect(sent).to eq(%w[stand stand])
  end

  it 'gives up when something keeps the character down' do
    sent = stub_stand(99)
    expect(EO.stand(tries: 3)).to be(false)
    expect(sent.size).to eq(3)
  end
end

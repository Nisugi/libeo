# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/messages'

RSpec.describe 'EO.say and EO.word_wrap' do
  let(:sent) { [] }

  before do
    out = sent
    stub_const('Lich::Messaging', Module.new { define_singleton_method(:msg) { |type, text| out << [type, text] } })
  end

  it 'defuses tags and inspects hashes' do
    EO.say('yellow', 'a #<Thing>')
    EO.say('info', { a: 1 })
    EO.say('info', [1, 2])
    expect(sent).to eq([['yellow', 'a #Thing>'], ['info', { a: 1 }.inspect], ['info', '[1, 2]']])
  end

  it 'shows debug as speech' do
    EO.say('debug', 'x')
    expect(sent).to eq([%w[speech x]])
  end

  it 'wraps at spaces' do
    expect(EO.word_wrap('aaa bbb ccc', 7)).to eq("aaa bbb\nccc")
  end
end

# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/scripts'
require_relative '../../scripts/eo/travel'

RSpec.describe 'EO.run_scripts and EO.fog_wanted?' do
  it 'splits an entry into the script and its arguments' do
    expect(EO.split_script('bigshot single')).to eq(%w[bigshot single])
    expect(EO.split_script('  eherbs ')).to eq(['eherbs', nil])
    expect(EO.split_script('')).to eq([nil, nil])
  end

  it 'runs each listed script in turn, skipping blank entries' do
    ran = []
    stub_const('Script', Class.new { define_singleton_method(:run) { |*args| ran << args } })
    EO.run_scripts('eherbs, bigshot single,  , tracker a b')
    expect(ran).to eq([['eherbs'], %w[bigshot single], ['tracker', 'a b']])
  end

  it 'fogs only when the method is on, and an optional fog only for wounds or load' do
    expect(EO.fog_wanted?(0)).to be(false)
    expect(EO.fog_wanted?('3')).to be(true)
    expect(EO.fog_wanted?(3, optional: true, reason: 'mind full')).to be(false)
    expect(EO.fog_wanted?(3, optional: true, reason: :wounded)).to be(true)
    expect(EO.fog_wanted?(3, optional: true, reason: 'encumbered')).to be(true)
  end
end

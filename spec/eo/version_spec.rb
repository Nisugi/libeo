# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/version'

RSpec.describe 'EO.require' do
  let(:messages) { [] }

  before do
    msgs = messages
    messaging = Module.new { define_singleton_method(:msg) { |kind, text| msgs << [kind, text] } }
    stub_const('Lich::Messaging', messaging)
    stub_const('Script', Class.new { def self.current = nil })
  end

  it 'accepts the installed version and older supported ones' do
    expect(EO.require(EO::VERSION)).to be(true)
    expect(EO.require(EO::OLDEST_SUPPORTED)).to be(true)
    expect(messages).to be_empty
  end

  it 'refuses a script built against a newer libeo, and says how to update' do
    expect { EO.require('99.0.0') }.to raise_error(EO::VersionError, /older than 99.0.0/)
    expect(messages.first).to include('error')
    expect(messages.first.last).to include('needs libeo 99.0.0')
  end

  it 'refuses a script built against a version no longer supported' do
    expect { EO.require('0.0.1') }.to raise_error(EO::VersionError, /no longer supports 0.0.1/)
  end

  it 'reports its version' do
    expect(EO.version).to eq(EO::VERSION)
    expect(EO::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end

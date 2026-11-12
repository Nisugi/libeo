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

RSpec.describe 'EO.script_version and EO.require_lich' do
  let(:said) { [] }
  let(:header) { 'name: ebounty, version: 1.14.0, required: Lich >= 5.22.0' }

  before do
    # Lich's Script#inspect carries the header fields the version is read from.
    running = Struct.new(:name, :header) { def inspect = header }.new('ebounty', header)
    stub_const('Script', Class.new)
    Script.define_singleton_method(:current) { running }
    Script.define_singleton_method(:list) { [running] }
    out = said
    allow(EO).to receive(:_respond) { |line = ''| out << line }
    $frontend = 'wizard'
  end

  it 'reads the running script header' do
    expect(EO.script_version).to eq('1.14.0')
    expect(EO.script_version('eloot')).to be_nil
  end

  it 'passes on a new enough Lich' do
    stub_const('LICH_VERSION', '5.22.1')
    expect(EO.require_lich).to be(true)
    expect(said).to be_empty
  end

  it 'refuses an older Lich, from the header or a version given' do
    stub_const('LICH_VERSION', '5.21.0')
    expect(EO.require_lich).to be(false)
    expect(said).to include('>Script:ebounty now requires a newer version of Lich(5.22.0+) to run.')
    expect(EO.require_lich('5.20.0')).to be(true)
  end
end

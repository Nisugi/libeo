# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe 'EO::Coordination in libeo' do
  it 'loads inert: the protocol, discovery, operations and parser projection, no thread started' do
    threads = Thread.list
    %w[protocol discovery parser_projection].each do |part|
      load File.expand_path("../../../scripts/eo/coordination/#{part}.rb", __dir__)
    end

    expect(EO::Coordination::ParserProjection).to be_a(Class)
    expect(EO::Coordination::Operations::Grant).to be_a(Class)
    expect(Thread.list - threads).to be_empty
  end

  it 'is loaded by libeo.lic' do
    loader = File.read(File.expand_path('../../../scripts/libeo.lic', __dir__))
    expect(loader).to include('coordination/protocol', 'coordination/discovery', 'coordination/parser_projection')
  end
end

# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/travel'

RSpec.describe 'EO.room_id' do
  before do
    map = Class.new do
      def self.ids_from_uid(uid) = uid == 7120 ? [228] : []
    end
    stub_const('Map', map)
  end

  it 'passes a room id through, as a number or a string' do
    expect(EO.room_id(228)).to eq(228)
    expect(EO.room_id('228')).to eq(228)
    expect(EO.room_id(' 228 ')).to eq(228)
  end

  it 'resolves a uid through the map database' do
    expect(EO.room_id('u7120')).to eq(228)
    expect(EO.room_id('U7120')).to eq(228)
  end

  it 'raises for a uid the map does not know, instead of exiting the script' do
    expect { EO.room_id('u1') }.to raise_error(EO::UnknownRoom, /u1 is not in the map database/)
  end
end

RSpec.describe 'EO.at?' do
  include_context 'a fake map'

  let(:rooms) { [EOSpec::FakeRoom.new(id: 228, uid: [7120], tags: %w[town advguild])] }

  it 'matches by id, by uid, or by tag' do
    expect(EO.at?(228)).to be(true)
    expect(EO.at?('228')).to be(true)
    expect(EO.at?('u7120')).to be(true)
    expect(EO.at?('advguild')).to be(true)
    expect(EO.at?(229)).to be(false)
    expect(EO.at?('bank')).to be(false)
  end
end

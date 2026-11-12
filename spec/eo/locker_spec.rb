# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/locker'
require_relative '../../scripts/eo/skinning'
require_relative '../../scripts/eo/appraisal'

RSpec.describe EO::Locker do
  it 'names a town the way the map does' do
    expect(described_class.town_name("the town of Kraken's Fall")).to eq("kraken's fall")
    expect(described_class.town_name('Teras Isle')).to eq('kharam-dzu')
    expect(described_class.town_name('the Isle of Four Winds')).to eq('mist harbor')
    expect(described_class.town_name('the Lost Home')).to eq("ta'illistim")
  end

  it 'finds the lines that arrived since a snapshot of the last few' do
    before = %w[a b c d]
    expect(described_class.lines_since(before, %w[c d e f])).to eq(%w[e f])
    expect(described_class.lines_since(before, %w[a b c d])).to eq([])
    expect(described_class.lines_since(before, %w[x y])).to eq(%w[x y])
  end

  it 'picks the house lockers of a town, the booths before the entrances' do
    room = Struct.new(:tags, :location, :town) do
      def find_nearest_by_tag(_tag) = town
    end
    rooms = [room.new(['meta:che:brigatta:entrance_locker'], "the town of Kraken's Fall", 5),
             room.new(['meta:che:brigatta:locker'], "the town of Kraken's Fall", 5),
             room.new(['meta:che:brigatta:locker'], 'Icemule Trace', 9)]
    expect(described_class.che_rooms(rooms, 'brigatta', 5)).to eq([rooms[1]])
    expect(described_class.che_rooms(rooms, 'brigatta', 9)).to eq([rooms[2]])
    expect(described_class.che_rooms(rooms, 'none', 5)).to eq([])
    expect(described_class.che_town_id(rooms, 'brigatta', "Kraken's Fall")).to eq(5)
    expect(described_class.che_town_id(rooms, 'brigatta', 'Solhaven')).to be_nil
  end
end

RSpec.describe EO::Skinning do
  let(:dead) { Struct.new(:name, :type, keyword_init: true) }

  it 'knows who wants a blunt tool and who never skins' do
    expect(described_class.blunt?(dead.new(name: 'a krynch', type: ''))).to be(true)
    expect(described_class.blunt?(dead.new(name: 'a rolton', type: ''))).to be(false)
    objs = [dead.new(name: 'a rolton', type: ''), dead.new(name: 'a ghostly warrior', type: ''),
            dead.new(name: 'a bandit', type: 'bandit'), dead.new(name: 'a kobold', type: '')]
    expect(described_class.candidates(objs, unskinnable: ['a kobold']).map(&:name)).to eq(['a rolton'])
    expect(described_class.candidates(objs, exclude: /rolton/).map(&:name)).to eq(['a kobold'])
  end

  it 'recognises what the game says to a skin' do
    expect('You skinned the rolton quite well.').to match(described_class::RESULT)
    expect("The Krolvin Captain's skin has been ruined with alchemical components.").to match(described_class::UNSKINNABLE)
    expect('You crack open a portion of the boulder and uncover a diamond!').to match(described_class::BROKE_OPEN)
  end
end

RSpec.describe EO::Appraisal do
  it 'reads the appraisal and ignores the lowball offer after it' do
    lines = ['You ask the jeweler to appraise your diamond.',
             "The jeweler says, \"It's worth approximately 356,400 silvers, but that is out of my price range, I will offer you 10,000.\""]
    expect(described_class.parse(lines)).to eq(raw: '356,400', amount: 356_400)
    expect(described_class.parse(['The jeweler shrugs.'])).to be_nil
  end

  it 'tells too valuable from the wrong shop' do
    expect("I'm not buying anything this valuable today.").to match(described_class::TOO_VALUABLE)
    expect("That's not quite my field... I only deal in gems and jewelry.").to match(described_class::WRONG_SHOP)
  end
end

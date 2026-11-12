# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/guild/tables'

RSpec.describe EO::Guild::Tables do
  it 'maps every ready or assigned task type to a bounty_types name' do
    %i[bandit cull dangerous escort gem heirloom herb rescue skin].each do |type|
      expect(described_class::CROSSWALK[type]).to be_a(String), "no crosswalk for #{type}"
    end
    %i[bandit_assignment creature_assignment gem_assignment heirloom_assignment herb_assignment rescue_assignment skin_assignment].each do |type|
      expect(described_class::CROSSWALK[type]).to be_a(String), "no crosswalk for #{type}"
    end
  end

  it "names bounty types only from the list a settings file may hold (heirloom_both is the crosswalk's umbrella)" do
    names = described_class::CROSSWALK.values.uniq - ['heirloom_both', 'kill_creatures']
    expect(names - described_class::BOUNTY_TYPES).to eq([])
  end

  it 'knows the town square for every town the parser names, and the boat per game' do
    stub_const('XMLData', Class.new { def self.game = 'GSIV' })
    expect(described_class.town_uid("Wehnimer's Landing")).to eq('u7120')
    expect(described_class.town_uid('Vornavis')).to eq(described_class.town_uid('Solhaven'))
    expect(described_class.town_uid('Contempt')).to eq('u7150608')
    stub_const('XMLData', Class.new { def self.game = 'GSF' })
    expect(described_class.town_uid('Contempt')).to eq('u7150607')
    expect(described_class.town_uid('Atlantis')).to be_nil
  end

  it 'recognises what the taskmaster and the guards say' do
    expect('You have already been assigned a task, Nisugi.').to match(described_class::TASKMASTER_RESPONSES)
    expect('Come back in about 5 minutes if you want another task.').to match(described_class::TASKMASTER_RESPONSES)
    expect("I don't have any tasks for you right now.").to match(described_class::GUARD_NOTHING)
    expect('The guard says, "Try bugging me later."').to match(described_class::GUARD_RESPONSES)
    expect('a town guard').to match(described_class::GUARD_NAMES)
  end

  it 'recognises the people the assignments send you to' do
    expect('Furrier Bramblefist').to match(described_class::FURRIER_NAMES)
    expect('Gem dealer Zirconia').to match(described_class::JEWELER_NAMES)
    expect('Herbalist Akrash').to match(described_class::HERBALIST_NAMES)
    expect('Taskmaster').not_to match(described_class::HERBALIST_NAMES)
  end

  it 'tells a forage result from a forage injury' do
    expect('You forage briefly and manage to find some acantha leaf.').to match(described_class::FORAGE_RESULT)
    expect('You forage briefly and manage to find some acantha leaf.').not_to match(described_class::FORAGE_INJURY)
    expect('As you forage around you suddenly feel a sharp pain in your hand!').to match(described_class::FORAGE_INJURY)
  end

  it 'names escort trips from the pickup wording and the destination town' do
    pickup = described_class::ESCORT_PICKUPS['the area just inside the North Gate']
    dropoff = described_class::ESCORT_DROPOFFS['Icemule Trace']
    expect("#{pickup}_to_#{dropoff}").to eq('landing_to_icemule')
  end
end

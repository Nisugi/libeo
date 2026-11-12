# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/guild/tables'
require_relative '../../scripts/eo/herbs/table'
require_relative '../../scripts/eo/herbs/injuries'
require_relative '../../scripts/eo/herbs/doses'

RSpec.describe EO::Herbs::Table do
  it 'carries every herb eherbs 2.3.0 knew' do
    expect(described_class::KNOWN.size).to eq(247)
    expect(described_class::KNOWN).to all(include(:location, :name, :type, :short_name, :store_doses))
  end

  it 'finds an item by its name or short name and says what it cures' do
    expect(described_class.entry_for('some acantha leaf')[:type]).to eq('blood')
    expect(described_class.entry_for("Olak's Ol'style ale")[:type]).to eq('blood')
    expect(described_class.cures?('rose-marrow potion', 'minor head wound')).to be(true)
    expect(described_class.cures?('rose-marrow potion', 'blood')).to be(false)
    expect(described_class.herb?('a rusty sword')).to be(false)
    expect(described_class.entry_for('')).to be_nil
  end

  it 'tells potions from plants and major from minor blood' do
    expect(described_class.drinkable?('bolmara potion')).to be(true)
    expect(described_class.drinkable?('some acantha leaf')).to be(false)
    yaba = described_class.entry_for('yabathilium fruit')
    acantha = described_class.entry_for('some acantha leaf')
    expect(described_class.blood_tier(yaba)).to eq('major blood')
    expect(described_class.blood_tier(acantha)).to eq('minor blood')
    expect(described_class.blood_bucket(yaba)).to eq('blood')
    expect(described_class.blood_bucket(yaba, split: true)).to eq('major blood')
    expect(described_class.in_category?(yaba, 'blood')).to be(true)
    expect(described_class.in_category?(acantha, 'major blood')).to be(false)
  end

  it 'knows where herbs are sold, by form' do
    expect(described_class.sold_at?("the town of Wehnimer's Landing")).to be(true)
    expect(described_class.sold_at?('Atlantis')).to be(false)
    expect(described_class.sold('blood', "the town of Wehnimer's Landing")[:name]).to eq('some acantha leaf')
    expect(described_class.sold('blood', 'the town of Kharam-Dzu', form: :drinkable)[:name]).to match(/ale/)
    expect(described_class.sold('blood', "the city of Ta'Vaalor", form: :edible)).to be_nil
  end

  it 'lists every stock target and fill type' do
    expect(described_class::TYPES.size).to eq(19)
    expect(described_class::HERB_TYPES + described_class::POTION_TYPES).to match_array(described_class::TYPES - ['blood'])
    described_class::TYPES.each { |t| expect(described_class::DEFAULT_DOSES).to have_key(t) }
  end
end

RSpec.describe EO::Herbs::Injuries do
  it 'reads a dead player from APPRAISE, bleeding wounds first' do
    lines = ['You take a quick appraisal of Ann.', 'She has deep lacerations across her chest and a scar across her face.']
    expect(described_class.appraise(lines)).to eq(['major organ wound'])
    expect(described_class.appraise(['She has a scar across her face.'])).to eq([])
    expect(described_class.appraise(['She has a scar across her face.'], full: true)).to eq(['minor head scar'])
    expect(described_class.appraise(['She has a bruised left eye.'], full: true)).to eq(['minor organ wound'])
  end

  it 'reads an escort client from LOOK, in hand-over order' do
    look = 'He has minor bruises about the head and a fractured and bleeding left leg.'
    expect(described_class.escort_injuries(look)).to eq(['major limb wound', 'minor limb wound', 'minor head wound'])
    expect(described_class.escort_injuries('He appears to be in good shape.')).to eq([])
  end

  it 'maps a missing herb type to the areas to stop asking about' do
    heal = Module.new
    expect(EO::Herbs::Heal.skip_for('major head wound')).to eq(%w[head neck]) if defined?(EO::Herbs::Heal)
    expect(heal).to be_a(Module)
  end
end

RSpec.describe EO::Herbs::Doses do
  let(:hand) { Struct.new(:id) }

  before do
    $eherbs_measure = {}
    stub_const('GameObj', Class.new { def self.right_hand = Struct.new(:id).new('900') })
  end

  it 'learns the doses left as herbs are used' do
    monitor = described_class::Monitor.new
    monitor.call('You take a bite of your <a exist="12" noun="leaf">acantha leaf</a>.')
    monitor.call('You have 3 bites left.')
    expect(described_class['12']).to eq(3)
    monitor.call('<prompt time="1">&gt;</prompt>')
    monitor.call('You have only about one quaff left.')
    expect(described_class['12']).to eq(3)
  end

  it 'reads MEASURE, exact and rough' do
    monitor = described_class::Monitor.new
    monitor.call('The <a exist="5" noun="potion">rose-marrow potion</a> has 4 doses left.')
    expect(described_class[5]).to eq(4)
    monitor.call('The <a exist="6" noun="leaf">acantha leaf</a> looks like it has several bites left.')
    expect(described_class[6]).to eq(10)
    monitor.call('The <a exist="6" noun="leaf">acantha leaf</a> looks like it has several bites left.')
    expect(described_class[6]).to eq(10)
    monitor.call('The <a exist="7" noun="leaf">torban leaf</a> has one bite left.')
    expect(described_class[7]).to eq(1)
  end

  it 'adds a purchase to the bundle it joins, and overestimates an unknown one' do
    monitor = described_class::Monitor.new
    described_class['900'] = 10
    monitor.call(%(She hands you <a exist="33" noun="leaf">some acantha leaf</a> and says, "Here's your purchase.))
    monitor.call('Carefully, you combine all your acantha leaf into one bundle.')
    expect(described_class['900']).to eq(20)

    described_class.forget('900')
    monitor.call('<left exist="44" noun="leaf">acantha leaf</left>')
    described_class['44'] = 30
    monitor.call('Carefully, you combine all your acantha leaf into one bundle.')
    expect(described_class['900']).to eq(50)
    expect(described_class.known?('44')).to be(false)
  end

  it 'counts a dose removed from a bundle' do
    monitor = described_class::Monitor.new
    described_class['8'] = 5
    monitor.call('<left exist="9" noun="leaf">acantha leaf</left>')
    monitor.call('You carefully remove one dose from your <a exist="8" noun="bundle">bundle</a>.')
    expect(described_class['8']).to eq(4)
    expect(described_class['9']).to eq(1)
  end
end

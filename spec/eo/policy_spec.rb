# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/guild/tables'
require_relative '../../scripts/eo/guild/policy'

RSpec.describe EO::Guild::TaskPolicy do
  let(:fake_task) { Struct.new(:type, :requirements, :action, keyword_init: true) }

  def task(type, action: nil, **need)
    fake_task.new(type: type, requirements: need, action: action)
  end

  it 'takes everything by default' do
    policy = described_class.new
    expect(policy.rejected_types).to eq([])
    expect(policy.reject?(task(:cull, creature: 'kobold', area: 'Old Logging Road'))).to be_nil
    expect(policy.reject?(task(:none))).to be_nil
    expect(policy.reject?(nil)).to be_nil
  end

  it 'hands back a task whose creature, herb, gem or area is excluded, case-insensitively' do
    policy = described_class.new(creature_exclude: ['Kobold'], herb_exclude: ['acantha leaf'],
                                 gem_exclude: ['uncut diamond'], location_exclude: ['Danjirland'])
    expect(policy.reject?(task(:cull, creature: 'kobold', area: 'Old Logging Road'))).to eq('Kobold is in the excluded list')
    expect(policy.reject?(task(:herb, herb: 'some acantha leaf'))).to match(/excluded/)
    expect(policy.reject?(task(:gem, gem: 'an uncut diamond'))).to match(/excluded/)
    expect(policy.reject?(task(:bandit, creature: 'bandit', area: 'Danjirland'))).to eq('Danjirland is in the excluded list')
    expect(policy.reject?(task(:cull, creature: 'rolton', area: 'Old Logging Road'))).to be_nil
  end

  it 'does not trip over a task that lacks the excluded field' do
    policy = described_class.new(creature_exclude: ['kobold'])
    expect(policy.reject?(task(:herb, herb: 'acantha leaf'))).to be_nil
  end

  it 'hands back the types the character does not do' do
    policy = described_class.new(types: %w[culling skinning])
    expect(policy.reject?(task(:gem, gem: 'diamond'))).to eq('gem_collecting tasks are not wanted')
    expect(policy.reject?(task(:escort))).to eq('escort tasks are not wanted')
    expect(policy.reject?(task(:skin, creature: 'rolton'))).to be_nil
    expect(policy.reject?(task(:cull, creature: 'rolton'))).to be_nil
    expect(policy.reject?(task(:dangerous, creature: 'rolton'))).to eq('boss_culling tasks are not wanted')
  end

  it 'treats a creature assignment as a culling task and heirlooms by their action' do
    none = described_class.new(types: %w[gem_collecting])
    expect(none.reject?(task(:creature_assignment))).to eq('creature tasks are not wanted')
    expect(described_class.new(types: %w[culling]).reject?(task(:creature_assignment))).to be_nil
    expect(described_class.new(types: %w[boss_culling]).reject?(task(:creature_assignment))).to be_nil

    loot_only = described_class.new(types: %w[heirloom_loot])
    expect(loot_only.reject?(task(:heirloom, action: 'loot'))).to be_nil
    expect(loot_only.reject?(task(:heirloom, action: 'search'))).to eq('heirloom search tasks are not wanted')
    expect(described_class.new(types: %w[heirloom_search]).reject?(task(:heirloom, action: 'loot'))).to eq('heirloom loot tasks are not wanted')
    expect(described_class.new(types: %w[culling]).reject?(task(:heirloom_assignment))).to be_nil
  end

  it 'names the boosted type to ask for, or nothing for Any' do
    expect(described_class.new(boost_type: 'culling').boost_choice).to eq('culling')
    expect(described_class.new(boost_type: 'Any').boost_choice).to be_nil
    expect(described_class.new.boost_choice).to be_nil
  end
end

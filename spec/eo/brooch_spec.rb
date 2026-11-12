# frozen_string_literal: true

require_relative 'eo_helper'
require_relative '../../scripts/eo/command'
require_relative '../../scripts/eo/brooch'
require_relative '../../scripts/eo/chain'

# The brooch's game text is from a character's logs (2026-10-23) and an
# ANALYZE pasted by its owner.
ANALYZE = <<~TEXT.lines.map(&:chomp)
  You analyze the quintuple orb brooch and sense that the creator has provided the following information:
  The quintuple orb brooch is a Rings of Lumnis event prize.  It has been used in the following number of runs during the Rings of Lumnis:
    Planar: 105, resulting in +400 field experience capacity
    Spiritual: 1,250, resulting in the ability to instantly absorb 869 experience
    Elemental: 0, resulting in the 0% chance to reroll various checks while on Adventurer's Guild tasks
    Chaos: 105, resulting in a bonus of 400 + up to a 10% bonus when used for other orbs
    Order: 105, resulting in +400 bounty points when turning in Adventurer's Guild tasks
  These bonuses are only active while the brooch's effect is active or when triggered and it is not on cooldown.  It is currently set to Chaos, which will use the Elemental benefit when next activated.
  Daily uses reset at midnight.  You have used each orb:
    Planar: 2 out of 2
    Spiritual: 3 out of 5
    Elemental: 0 out of 0
    Chaos: 1 out of 2
    Order: 2 out of 2
  The following verbs are available to use with it: rub, turn, tap, cover, tickle, spin, push, touch, and pull.
  [SYNTAX: WHISPER {my} BROOCH [{CHAOS} or {ELEMENT} or {ORDER} or {PLANAR} or {SPIRIT}]
TEXT

RSpec.describe EO::Brooch do
  describe '.parse' do
    let(:status) { described_class.parse(ANALYZE) }

    it 'reads the orb it is on and what chaos will give' do
      expect(status.current).to eq(:chaos)
      expect(status.chaos_gives).to eq(:element)
    end

    it 'reads the rubs left today, not the run counts' do
      expect(status.left(:planar)).to eq(0)
      expect(status.left(:spirit)).to eq(2)
      expect(status.left(:element)).to eq(0)
      expect(status.left(:chaos)).to eq(1)
      expect(status.left(:order)).to eq(0)
    end
  end

  describe '.rub' do
    def rub_answer(line)
      allow(EO).to receive(:result).and_return(line)
      described_class.rub
    end

    it 'names the orb whose energy took hold' do
      expect(rub_answer('You trace the central orb of red in your brooch and your fingertips begin to tingle as planar energy flows into you.  ' \
                        "Within seconds, you feel Lumnis' Enlightenment course through your veins.")).to eq(:planar)
      expect(rub_answer('You trace the central orb of blue in your brooch and your fingertips begin to tingle as spiritual energy flows into you.')).to eq(:spirit)
    end

    it 'names the orb a chaos rub gave' do
      line = 'You trace the central orb of black in your brooch and your fingertips begin to tingle as chaotic energy flows into you.  ' \
             "Within seconds, you feel Lumnis' Divergence course through your veins, but it is fleeting as spiritual energy soon " \
             "replaces it and you feel Lumnis' Vigor take hold."
      expect(rub_answer(line)).to eq(:spirit)
    end

    it 'knows a spent orb' do
      expect(rub_answer('The quintuple orb brooch ebbs weakly, but nothing further happens.')).to eq(:spent)
    end
  end

  describe '.use' do
    let(:sent) { [] }

    before do
      spec = self
      allow(described_class).to receive(:with_brooch) { |&block| block.call }
      allow(EO).to receive(:command).and_return(ANALYZE)
      allow(EO).to receive(:result) do |cmd, _re, **|
        spec.sent << cmd
        cmd == 'rub my brooch' ? 'as spiritual energy flows into you' : '[Your quintuple orb brooch is now attuned to the spirit ring.]'
      end
    end

    it 'whispers to the orb and rubs it while it has a rub left' do
      expect(described_class.use(:spirit)).to eq(:spirit)
      expect(sent).to eq(['whisper my brooch spirit', 'rub my brooch'])
    end

    it 'does nothing when the orb is spent and chaos gives something else' do
      expect(described_class.use(:planar)).to eq(:none)
      expect(sent).to be_empty
    end

    it 'rubs chaos, already selected, when it gives the spent orb' do
      allow(EO).to receive(:command).and_return(ANALYZE.map { |l| l.sub('use the Elemental benefit', 'use the Planar benefit') })
      described_class.use(:planar)
      expect(sent).to eq(['rub my brooch'])
    end

    it 'answers :no_brooch without one' do
      allow(described_class).to receive(:with_brooch).and_return(nil)
      expect(described_class.use(:spirit)).to eq(:no_brooch)
    end
  end
end

RSpec.describe EO::Chain do
  let(:fxp) { [1800, 1800] }

  before do
    spec = self
    stub_const('Experience', Module.new do
      define_singleton_method(:fxp_current) { spec.fxp[0] }
      define_singleton_method(:fxp_max) { spec.fxp[1] }
    end)
  end

  describe '.reduce' do
    it 'does nothing at or under the cap' do
      expect(EO).not_to receive(:result)
      expect(described_class.reduce(%w[longterm spirit])).to be_nil
    end

    it 'uses one reducer, the first that works' do
      fxp[0] = 2400
      allow(EO).to receive(:result).and_return('You do not have any Long-Term Experience Boosts to redeem.')
      allow(EO::Brooch).to receive(:use).with(:spirit).and_return(:spirit)
      expect(described_class.reduce(%w[longterm spirit])).to eq(:spirit)
    end

    it 'stops after a long-term boost' do
      fxp[0] = 2400
      allow(EO).to receive(:result).and_return('You have deducted 500 experience points from your field experience and added 250 to your long-term experience.')
      expect(EO::Brooch).not_to receive(:use)
      expect(described_class.reduce(%w[longterm spirit])).to eq(:longterm)
    end
  end

  describe '.before_turn_in' do
    it 'rubs planar and order only when their effect is not up' do
      allow(EO::Brooch).to receive(:up?).with(:planar).and_return(true)
      allow(EO::Brooch).to receive(:up?).with(:order).and_return(false)
      expect(EO::Brooch).to receive(:use).with(:order).and_return(:order)
      expect(described_class.before_turn_in(planar: true, order: true)).to eq(order: :order)
    end
  end
end

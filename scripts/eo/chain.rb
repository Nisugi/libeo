# frozen_string_literal: true

module EO
  # Chaining bounties: a task turned in every ten minutes with a full head.
  # The bounty's experience fills the head to 2000 and the rest is split,
  # half absorbed at once; a task cannot be turned in while the head holds
  # more than its cap. So: planar and order rubbed right before the
  # turn-in, when their effect is not already up; one reducer right after
  # it, to get back under the cap before the next hunt fills the head
  # again; elemental's chaos roll spent when a gem or heirloom task starts.
  module Chain
    module_function

    # The reducers that can be listed, in no particular order.
    REDUCERS = %i[longterm spirit].freeze
    LONGTERM_NONE = /You do not have any Long-Term Experience Boosts to redeem\./
    LONGTERM_DONE = /You have deducted 500 experience points from your field experience/

    # @return [Integer] field experience over the cap, 0 when under it
    def excess = [Experience.fxp_current.to_i - Experience.fxp_max.to_i, 0].max

    # @return [Boolean] whether the head holds more than the cap
    def over_cap? = excess.positive?

    # Right before a turn-in: planar (the cap) and order (bounty points),
    # each only when its effect is not up, from chaos when the orb is spent.
    #
    # @param planar [Boolean]
    # @param order [Boolean]
    # @return [Hash{Symbol => Symbol}] what each rub came to
    def before_turn_in(planar: false, order: false)
      done = {}
      done[:planar] = Brooch.use(:planar) if planar && !Brooch.up?(:planar)
      done[:order] = Brooch.use(:order) if order && !Brooch.up?(:order)
      done
    end

    # Right after a turn-in: one reducer, the first in the list that works,
    # when the head is over its cap.
    #
    # @param reducers [Array<Symbol, String>] :longterm, :spirit, in order
    # @return [Symbol, nil] the reducer used, nil when none was needed or none worked
    def reduce(reducers)
      return nil unless over_cap?

      Array(reducers).map(&:to_sym).each do |reducer|
        case reducer
        when :longterm
          return :longterm if EO.result('boost longterm', Regexp.union(LONGTERM_NONE, LONGTERM_DONE)).to_s =~ LONGTERM_DONE
        when :spirit
          return :spirit if %i[spirit chaos].include?(Brooch.use(:spirit))
        end
      end
      nil
    end

    # When a gem or heirloom task starts: chaos rubbed if it will give
    # elemental and Lumnis' Fortitude is not already up, so the roll is
    # spent where its rerolls count.
    #
    # @return [Symbol, nil] as Brooch.use_chaos_if, nil when not needed
    def elemental
      return nil if Brooch.up?(:element)

      Brooch.use_chaos_if(:element)
    end
  end
end

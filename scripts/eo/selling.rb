# frozen_string_literal: true

module EO
  # Selling one item at a shop and what the shop says back. eloot 2.15.0
  # Sell sell_item (8351).
  module Selling
    module_function

    ANSWER = /You (offer to sell|ask)|What were you referring to\?/

    # A shop that will not buy: it is not here, not the shop's line, or
    # not worth anything to it.
    REFUSED = /What were you referring to\?|That's not quite my field|That's basically worthless here|Can't say I'm interested in that|This is a pawnshop, sir, not a junkshop|The company don't buy trash|as if you were a lunatic/

    # @param item [GameObj] the item, in hand
    # @return [Symbol] :sold, :refused, or :kept (no refusal, but still in hand)
    def sell(item)
      return :refused if item.nil? || item.name == 'Empty'
      lines = EO.command("sell ##{item.id}", ANSWER)
      return :refused if lines.any? { |l| l =~ REFUSED }
      20.times do
        return :sold unless Hands.holding?(item)
        sleep 0.1
      end
      :kept
    end
  end
end

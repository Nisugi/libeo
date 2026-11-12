# frozen_string_literal: true

module EO
  # Asking a shop what an item is worth, and what the answer means. eloot
  # 2.15.0 Sell parse_appraisal, the ask in appraise.
  module Appraisal
    module_function

    VALUE = /([,0-9]+) (?:silver|for it if you want to sell|for this if you'd like)/
    TOO_VALUABLE = /not buying anything this valuable today/
    WRONG_SHOP = /not quite my field|only deal in gems and jewelry/

    # amount: silver offered, 0 when none was named. raw: the figure as
    # the shop said it. too_valuable: the gemshop would not quote a price.
    # wrong_shop: the jeweler does not deal in this kind of thing at all.
    Answer = Struct.new(:amount, :raw, :too_valuable, :wrong_shop, keyword_init: true)

    # The value out of the shop's lines: the appraisal, not any lowball
    # offer that follows it ("out of my price range, I will offer you Y").
    #
    # @param lines [Array<String>]
    # @return [Hash, nil] { raw:, amount: }
    def parse(lines)
      line = Array(lines).find { |l| l =~ VALUE }
      return nil unless line && line =~ VALUE
      raw = Regexp.last_match(1)
      { raw: raw, amount: raw.delete(',').to_i }
    end

    # APPRAISE an item here and read the answer.
    #
    # @param item [GameObj]
    # @return [Answer]
    def ask(item)
      lines = EO.command("appraise ##{item.id}", /^You ask .*to appraise/)
      parsed = parse(lines) || { raw: nil, amount: 0 }
      Answer.new(amount: parsed[:amount], raw: parsed[:raw],
                 too_valuable: lines.any? { |l| l =~ TOO_VALUABLE },
                 wrong_shop: lines.any? { |l| l =~ WRONG_SHOP })
    end
  end
end

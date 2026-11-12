# frozen_string_literal: true

module EO
  module Herbs
    # The herbalist: the menu, prices, buying, bundling what was bought,
    # and stocking a sack up to its dose targets. eherbs read_menu,
    # check_prices, buy_herb, bundle_all, bundle_herb,
    # get_current_stock, stock_requested_herbs,
    # stock_storage, fill_herbs.
    module Shop
      module_function

      # ORDER, as a map of item name to menu number.
      #
      # @return [Hash{String => String}]
      def menu
        lines = EO.command('order', %r{<output class="mono"/>|<closeDialog id='dlgCustomize'/>}, silent: true, quiet: true)
        found = {}
        lines.each do |line|
          line.scan(%r{<d.*?cmd=["']order ([0-9]+).*?>(.*?)</d>}).each { |number, name| found[name.sub(/^an? /, '')] = number }
        end
        found
      end

      # Each type's price here, read once per herbalist room and kept by
      # the driver.
      #
      # @param menu [Hash] from .menu
      # @return [Hash{String => Hash}] type to { cost:, name:, short_name: }
      def prices(menu = self.menu)
        found = {}
        menu.each do |herb, number|
          lines = EO.command("order #{number}", /You ask/, silent: true, quiet: true)
          cost = lines.map { |s| s.scan(/\b([\d,]+)\s*(?:silver|silvers)\b/).flatten.first }.compact.first&.delete(',')&.to_i
          info = Table::KNOWN.find { |h| (h[:name] =~ /#{Regexp.escape(herb)}/ || h[:short_name] =~ /#{Regexp.escape(herb)}/) && !h[:location].include?('Do Not Buy') }
          next unless info
          found[info[:type]] = { cost: cost, name: info[:name], short_name: info[:short_name] }
        end
        found
      end

      # Buy an herb of a category from the menu. The driver supplies the
      # silver when the shop says there is not enough.
      #
      # @param category [String]
      # @param amount [Integer]
      # @param menu [Hash]
      # @param sack [Sack] where full hands are emptied to
      # @param more_silver [Proc, nil] fetches silver and returns to the shop; nil to give up
      # @return [GameObj, nil] what is in the right hand after
      # @raise [Guild::Error] when the menu has nothing for the category, or silver ran out
      def buy(category, amount = 1, menu:, sack:, more_silver: nil)
        name = menu.keys.find { |n| Table::KNOWN.any? { |h| Table.in_category?(h, category) && (n == h[:name] || n == h[:short_name]) } }
        number = name && menu[name]
        raise Guild::Error, "failed to find #{name || category} for #{category} in the menu (#{menu})" if number.nil?

        order = dothistimeout("order #{amount} #{number}", 3, /^You will need a free hand|BUY/)
        if order =~ /You will need a free hand/
          fput "put ##{GameObj.right_hand.id} in ##{sack.id}" if checkright
          fput "put ##{GameObj.left_hand.id} in ##{sack.id}" if checkleft
        end
        result = dothistimeout('buy', 3, /Sold for [0-9,]+ silver|^But you do not have enough silver!|You're going to need a free hand/)
        case result
        when /Sold for ([0-9,]+) silver/
          item = Sack.herb_in_hand
          entry = item && Table::KNOWN.find { |h| h[:name] == item.name }
          Doses[item.id] = entry[:store_doses] if item && entry
        when /^But you do not have enough silver!/
          raise Guild::Error, 'not enough silver for the herb' if more_silver.nil?
          more_silver.call
          return buy(category, amount, menu: menu, sack: sack, more_silver: nil)
        when /You're going to need a free hand/
          empty_hands
        end
        checkright ? GameObj.right_hand : nil
      end

      # Combine like herbs in the sack into bundles, and like potions by
      # pouring, so they take less room.
      #
      # @param sack [Sack]
      # @param herb [String, nil] one herb name, or every known one
      # @return [void]
      def bundle_all(sack, herb = nil)
        return if sack.survival_kit
        names = herb ? [herb] : Table::KNOWN.map { |e| e[:name] }.uniq
        names = names.reject { |n| n =~ /\b#{Table::CANT_BUNDLE}$/ }
        ignore = []
        names.each do |thing|
          matching = sack.obj.contents.to_a.select { |item| item.full_name.lstrip =~ /#{Regexp.escape(thing)}/ }
          next if matching.length <= 1
          bundle = matching.first
          full = false
          sack.take(bundle)
          ignore << bundle.id
          while (item = sack.obj.contents.to_a.find { |h| h.full_name.lstrip =~ /#{Regexp.escape(thing)}/ && !ignore.include?(h.id) })
            unless bundle
              bundle = item
              sack.take(item)
              ignore << item.id
              next
            end
            sack.take(item)
            if item.name =~ /potion|tincture|elixir|barrel|flagon|tea|soup/
              result = nil
              result = dothis("pour ##{item.id} in ##{bundle.id}", /You have|You only|You can|twinkling/) until result =~ /You can|twinkling/
              full = true if result =~ /You can/
            else
              result = dothis('bundle', /Carefully|If you|Try as|You can't|That is not an herb you can bundle/i)
              if result =~ /If you/
                full = true
              elsif result =~ /Try as|You can't|That is not an herb you can bundle/
                dothistimeout("measure ##{item.id}", 2, /^The .*? left/)
                sack.store(item)
                ignore << item.id
              else
                bundle = GameObj.right_hand
              end
            end
            if full
              dothistimeout("measure ##{bundle.id}", 2, /^The .*? left/)
              sack.store(bundle)
              bundle = item
              full = false
            end
            ignore << item.id
          end
          next unless bundle
          dothistimeout("measure ##{bundle.id}", 2, /^The .*? left/)
          sack.store(bundle)
        end
      end

      # Combine what is in the two hands: pour like potions together,
      # bundle like herbs.
      #
      # @return [Symbol] :poured, :bundled, :mismatch (the two herbs differ:
      #   the character has changed areas), or :nothing
      def bundle_hands
        right = GameObj.right_hand
        left = GameObj.left_hand
        return :nothing if right.name.to_s.empty? || left.name.to_s.empty?
        same = right.name.sub(right.noun, '').rstrip == left.name.sub(left.noun, '').rstrip
        both_drink = Table.drinkable?(right.noun) && Table.drinkable?(left.noun)
        both_eat = !Table.drinkable?(right.noun) && !Table.drinkable?(left.noun)
        if same && both_drink
          10.times do
            break unless GameObj.right_hand.id == right.id || GameObj.left_hand.id == left.id
            result = dothistimeout("pour ##{left.id} in ##{right.id}", 5, /^You carefully pour a little bit from your|^You can't pour|^I can't find that|^I could not find what you were referring to/)
            if result =~ /^You can't pour any more in there without spilling it\./
              Doses[right.id] = right.name =~ /barrel/ ? 10 : 7
              break
            end
            break if GameObj.left_hand.name == 'Empty' || result =~ /^You can't pour|^I can't find that|^I could not find what you were referring to/
          end
          :poured
        elsif same && both_eat
          result = dothistimeout('bundle', 5, /^Carefully, you combine|^If you add anything more to this bundle|^You do not have anything to bundle!$|^You can't put .* together in a bundle!/)
          if result =~ /^You can't put (.*)<a exist=.*noun=.*>(.*), and (.*)<a exist=.*noun=.*>(.*) together in a bundle!/
            return :mismatch if Regexp.last_match(1) + Regexp.last_match(2) != Regexp.last_match(3) + Regexp.last_match(4)
          end
          :bundled
        else
          :nothing
        end
      end

      # What the sack is short of, against its targets: for each category
      # wanted, the doses held (measuring any item whose count is not yet
      # known) against the target, and how many to buy here.
      #
      # @param sack [Sack]
      # @param categories [Array<String>]
      # @param targets [Hash{String => Integer}] doses to keep per category
      # @param location [String] where to buy, as the map names it
      # @param form [Symbol, nil] :drinkable, :edible, or nil for either (a kit stocks by form)
      # @return [Array<Hash>] { category:, herb_name:, herb_list:, needed: }
      def shopping_list(sack, categories, targets:, location:, form: nil)
        form = nil unless sack.survival_kit
        sack.kit_contents if sack.survival_kit
        sack.obj.contents.to_a.each do |obj|
          next unless Table::KNOWN.any? { |h| categories.any? { |c| Table.in_category?(h, c) } && (h[:name] == obj.name || h[:short_name] == obj.name) }
          next if Doses.known?(obj.id)
          dothistimeout("get ##{obj.id}", 10, Sack::GET)
          dothistimeout("measure ##{obj.id}", 10, /^The .*? left/)
          dothistimeout("put ##{obj.id} in ##{sack.id}", 10, Sack::PUT)
        end
        contents = sack.contents

        list = []
        categories.each do |category|
          next if Table.sold(category, location, form: form).nil?
          items = contents[form || :all].select do |obj|
            Table::KNOWN.any? do |h|
              (h[:name] =~ /#{Regexp.escape(obj.name)}/ || h[:short_name] =~ /#{Regexp.escape(obj.name)}/ || h[:short_name].include?(obj.name.sub('elixir', ''))) &&
                Table.in_category?(h, category) &&
                (form.nil? || (form == :drinkable) == Table.drinkable?(h[:name]))
            end
          end
          held = items.sum { |h| Doses[h.id].to_i }
          next unless held < targets[category].to_i
          details = Table.sold(category, location)
          if details.nil?
            list << { category: category, herb_name: 'any', herb_list: ['missing'], needed: 2 }
          else
            needed = (targets[category].to_i - held) / details[:store_doses]
            list << { category: category, herb_name: details[:short_name], herb_list: items, needed: needed } if items.empty? || needed >= 1
          end
        end
        list
      end

      # The silver a shopping list costs here, plus a tenth for luck.
      #
      # @param list [Array<Hash>]
      # @param prices [Hash] from .prices
      # @return [Integer]
      # @raise [Guild::Error] for a category with no price
      def cost(list, prices)
        total = list.sum do |line|
          key = ['minor blood', 'major blood'].include?(line[:category]) ? 'blood' : line[:category]
          unit = prices.dig(key, :cost)
          raise Guild::Error, "no price for #{line[:category]} (list #{list}, prices #{prices})" if unit.nil?
          unit * line[:needed]
        end
        (total * 1.1).to_i
      end

      # Buy everything on a shopping list at the herbalist here, store and
      # bundle it. The note paying for it rides in a hand between buys.
      #
      # @param list [Array<Hash>]
      # @param sack [Sack]
      # @param menu [Hash]
      # @param location [String]
      # @param form [Symbol, nil]
      # @param note [GameObj, nil] the bank note, kept in hand while buying
      # @param more_silver [Proc, nil] as .buy
      # @return [void]
      def buy_list(list, sack:, menu:, location:, form: nil, note: nil, more_silver: nil)
        empty_hands
        bundle_all(sack)
        sack.take(note) if note
        list.each do |line|
          raise Guild::Error, "no herb sold here for #{line[:category]} (#{form})" if Table.sold(line[:category], location, form: form).nil?
          item = nil
          (line[:needed] / 10).times do
            buy(line[:category], 10, menu: menu, sack: sack, more_silver: more_silver)
            item = put_away(sack)
          end
          if (line[:needed] % 10).positive?
            buy(line[:category], line[:needed] % 10, menu: menu, sack: sack, more_silver: more_silver)
            item = put_away(sack)
          end
          next unless line[:needed] > 1 && !sack.survival_kit && item
          sack.store(note) if note
          bundle_all(sack, item.name)
          sack.take(note) if note
        end
        sack.store(note) if note
        if (item = Sack.herb_in_hand)
          sack.store(item)
        end
        bundle_all(sack)
      end

      # Store what was just bought: an herb in hand, or a package to empty
      # into the sack.
      #
      # @param sack [Sack]
      # @return [GameObj, nil] the item stored
      def put_away(sack)
        if (item = Sack.herb_in_hand)
          sack.store(item)
          item
        elsif (pack = [GameObj.right_hand, GameObj.left_hand].find { |i| i.name =~ /package/ })
          EO.result("open ##{pack.id}", /^You open|^That is already open/)
          inside = pack.contents.to_a
          EO.result("empty ##{pack.id} in ##{sack.id}", /everything falls in/)
          EO.settle
          EO.result("throw ##{pack.id}", /^You throw away/)
          inside.first
        end
      end

      # The types the sack holds nothing for, in fill order.
      #
      # @param contents [Hash] from Sack#contents
      # @return [Array<String>]
      def missing_types(contents)
        Table::TYPES.reject { |type| contents[:all].any? { |obj| Table.cures?(obj.name, type) } }
      end
    end
  end
end

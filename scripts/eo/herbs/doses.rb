# frozen_string_literal: true

module EO
  module Herbs
    # How many doses each herb item has left, learned from what the game
    # says as herbs are eaten, measured, poured, bought and bundled. The
    # store is the `$eherbs_measure` hash, keyed by item id as a string,
    # which other scripts have read for years. eherbs exec_str.
    module Doses
      module_function

      HOOK = 'eherbs_monitor'

      # @return [Hash{String => Integer}]
      def store
        $eherbs_measure ||= {}
      end

      # @param id [String, Integer]
      # @return [Integer, nil]
      def [](id)
        store[id.to_s]
      end

      def []=(id, count)
        store[id.to_s] = count
      end

      def known?(id)
        store.key?(id.to_s)
      end

      def forget(id)
        store.delete(id.to_s)
      end

      # Watch the game for dose counts. Installed once per script; the
      # driver removes it when it dies.
      #
      # @return [void]
      def install
        DownstreamHook.remove(HOOK)
        DownstreamHook.add(HOOK, Monitor.new.to_proc)
      end

      def remove
        DownstreamHook.remove(HOOK)
      end

      # The hook's state: which item is being used (for the "N doses left"
      # that follows), the last item seen in the left hand (a bundle's
      # source), and the doses a just-bought herb holds.
      class Monitor
        def initialize
          @using = nil
          @last_left = nil
          @bought = nil
        end

        def to_proc
          method(:call).to_proc
        end

        def call(line)
          store = Doses.store
          @last_left = Regexp.last_match(1) if line =~ /<left exist="([0-9]+)"/
          if line =~ /<prompt/
            @using = nil
          elsif @using
            using_line(line, store)
          elsif line =~ /^You take a (?:drink from|bite of) your .*? exist="([0-9]+)"/
            @using = Regexp.last_match(1)
          elsif line =~ /^You carefully pour a little bit from your .*? exist="([0-9]+)" .*? into .*? exist="([0-9]+)"/
            @using = Regexp.last_match(1)
            store[Regexp.last_match(2)] += 1 if store[Regexp.last_match(2)]
          elsif line =~ /^The .*? exist="([0-9]+)" .*? has several doses left\./
            store[Regexp.last_match(1)] = 7 unless store[Regexp.last_match(1)].to_i.between?(5, 10)
          elsif line =~ /^The .*? exist="([0-9]+)" .*? has a few doses left\./
            store[Regexp.last_match(1)] = 4 unless store[Regexp.last_match(1)].to_i.between?(3, 4)
          elsif line =~ /^The .*? exist="([0-9]+)" .*? has ([0-9]+) doses left\./
            store[Regexp.last_match(1)] = Regexp.last_match(2).to_i
          elsif line =~ /^The .*? exist="([0-9]+)" .*? has 1 dose left\./
            store[Regexp.last_match(1)] = 1
          elsif line =~ /^You can't tell exactly, but .*? exist="(.*?)" .*? seems to have plenty of bites left\./
            store[Regexp.last_match(1)] = 50 unless store[Regexp.last_match(1)].to_i.between?(11, 50)
          elsif line =~ /^The .*? exist="(.*?)" .*? looks like it has several bites left\./
            store[Regexp.last_match(1)] = 10 unless store[Regexp.last_match(1)].to_i.between?(5, 10)
          elsif line =~ /^The .*? exist="(.*?)" .*? looks like it has a few bites left\./
            store[Regexp.last_match(1)] = 4 unless store[Regexp.last_match(1)].to_i.between?(3, 4)
          elsif line =~ /^The .*? exist="(.*?)" .*? has ([0-9]+) bites left\./
            store[Regexp.last_match(1)] = Regexp.last_match(2).to_i
          elsif line =~ /^The .*? exist="(.*?)" .*? has (?:one|1) bite left\./
            store[Regexp.last_match(1)] = 1
          elsif line =~ /^(?:Sh|H)e hands you <a exist="[0-9]+".*?>(.*)<\/a> and says, "Here's your purchase\./
            entry = Table::KNOWN.find { |h| h[:name] == Regexp.last_match(1) }
            @bought = entry ? entry[:store_doses] : 4
          elsif line =~ /^Carefully, you combine all your .*? into one bundle\./
            bundled(store)
          elsif line =~ /^You carefully remove one dose from your <a exist="([0-9]+)"/
            store[Regexp.last_match(1)] -= 1 if store[Regexp.last_match(1)]
            store[@last_left] = 1
          end
          line
        end

        private

        def using_line(line, store)
          if line =~ /^You have only about ([0-9]+) quaffs left\./ || line =~ /^You have (?:about )?([0-9]+) (?:doses|bites) left\./
            store[@using] = Regexp.last_match(1).to_i
          elsif line =~ /^You (?:only )?have one bite left\./ || line =~ /^You have only about one quaff left\.|You only have one (?:dose|quaff) left\./
            store[@using] = 1
          elsif line =~ /^That was the last (?:drop|of it)\./
            store[@using] = 0
          end
        end

        # A bundle just formed in the right hand: add what was bought to it,
        # or, for an unknown count, overestimate so no more is bought than
        # it can take; the exact count comes when it is used.
        def bundled(store)
          bundle = GameObj.right_hand.id
          if store[bundle] && @bought
            store[bundle] += @bought.to_i
            @bought = nil
          elsif store[@last_left].to_i > 10
            store[bundle] = 50
            store.delete(@last_left)
          else
            store.delete(bundle)
            store.delete(@last_left)
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module EO
  # Getting boxes opened: the town locksmith, who opens a locked box in
  # hand for a fee, and the locksmith pool, where boxes are left with a tip
  # for players to open and collected when ready. eloot 2.15.0 Sell:
  # locksmith (7684), locksmith_open (7727), pool_box_order (7804),
  # locksmith_pool (7808), pool_return (7903), locksmith_pool_count
  # (7961), pool_list_counts (7982), locksmith_determine_tip (7991),
  # locksmith_tip (8003), town_openable? (8149).
  module Locksmith
    module_function

    # "Case" boxes the town locksmith ignores even in hand; only the pool
    # or a player can open them.
    POOL_ONLY_NOUNS = /\Acase\z/i

    # Kraken's Fall's locksmith room is one step east of where go2 stops.
    KRAKENS_FALL_WAGON_UID = 7118381

    # @param box [GameObj]
    # @param refused [Array<String>] box names the town locksmith turned down this session
    # @return [Boolean] whether the town locksmith will work on it
    def town_openable?(box, refused: [])
      return true unless box.respond_to?(:noun)
      return false if POOL_ONLY_NOUNS.match?(box.noun.to_s)
      !refused.include?(box.name)
    end

    # How to call the town locksmith: the bell, keys or chime on the table.
    #
    # @return [String, nil] the command, nil when the table or the thing on it is missing
    def town_activator
      table = (GameObj.room_desc.to_a + GameObj.loot.to_a).find { |obj| obj.noun =~ /(?:table|counter)$/ }
      return nil if table.nil?
      EO.command("look on ##{table.id}", /On the/, silent: true, quiet: true) if table.contents.nil?
      return nil if table.contents.nil?
      return 'ring bell' if table.contents.any? { |obj| obj.noun == 'bell' }
      return 'pull keys' if table.contents.any? { |obj| obj.noun == 'keys' }
      return 'ring chime' if table.contents.any? { |obj| obj.noun == 'chime' } || GameObj.loot.to_a.any? { |obj| obj.noun == 'chime' }
      nil
    end

    # Walk to the town locksmith (the step east at Kraken's Fall included).
    #
    # @return [void]
    def go_to_town_locksmith
      EO.go2('locksmith')
      move 'east' if Room.current.uid.include?(KRAKENS_FALL_WAGON_UID)
    end

    # What the town locksmith did with a box in hand. fee: the silver quoted.
    TownResult = Struct.new(:outcome, :fee, keyword_init: true)

    # Have the town locksmith open a box held in hand. A box already open
    # is left as it is.
    #
    # @param box [GameObj] in hand, unphased
    # @param activator [String] from .town_activator
    # @return [TownResult] outcome :open (unlocked, or already open), :paid
    #   (opened for the fee), :refused (the locksmith ignores this box),
    #   :short (could not pay the quoted fee), or :unknown (no answer)
    def town_open(box, activator)
      lines = EO.command("open ##{box.id}", /That is already open|You open|You throw back|It appears to be locked/, silent: true, quiet: true)
      return TownResult.new(outcome: :open) unless lines.any? { |l| l =~ /locked/ }

      answer = dothistimeout(activator, 2, /Gimme ([\d,]+) silvers|ignores you/)
      return TownResult.new(outcome: :refused) if answer =~ /ignores you/ && Hands.holding?(box)
      return TownResult.new(outcome: :unknown) if answer.nil?

      fee = answer[/Gimme ([\d,]+) silvers/, 1]&.delete(',')&.to_i
      paid = dothistimeout('pay', 2, /accepts|have enough/)
      return TownResult.new(outcome: :paid, fee: fee) if paid =~ /accepts/
      TownResult.new(outcome: :short, fee: fee)
    end

    # @param box [GameObj]
    # @return [Boolean] whether LOOK IN says the box is shut (closed or phased)
    def shut?(box)
      lines = EO.command("look in ##{box.id}", /<container|That is closed|You see the shifting form/, silent: true, quiet: true)
      lines.any? { |l| l =~ /That is closed|You see the shifting form/i }
    end

    # The locksmith pool.
    module Pool
      module_function

      FULL = 100
      LIST_HEADER = /here's the list of boxes we have for you\.|You haven't given us any boxes to be worked on\./
      GIVE = /You want a locksmith|You don't have|takes your|already holding as many boxes|already (unlocked|open)/
      RETURN = /We don't have any boxes ready for you|We don't seem to have that box|Alright, here's your|You need to lighten your load first|You can't hold anymore items/

      # Boxes in the order to hand them in: one already in hand first, or
      # the loop hands it in on another box's turn and then cannot find it.
      #
      # @param held [Array<GameObj>] both hands
      # @param found [Array<GameObj>] boxes found in containers
      # @param passed [Array<GameObj>] boxes the caller named
      # @return [Array<GameObj>]
      def order(held:, found:, passed:)
        (held.select { |hand| hand.type =~ /box/ } + found + passed).uniq(&:id)
      end

      # The incremental tip for one box: base at an empty pool, rising to max
      # at a full one, shaped by alpha.
      #
      # @param box_no [Integer] the box's place in the pool, 1 to 100
      # @return [Integer]
      def tip(box_no, base:, max:, alpha:)
        factor = box_no.to_f / 100
        (base.to_i + (factor**alpha.to_f) * (max.to_i - base.to_i)).round
      end

      # The incremental tip for the next +count+ boxes into a pool holding
      # +depth+.
      #
      # @return [Integer]
      def tip_for(depth, count, base:, max:, alpha:)
        upper = [depth + count, FULL].min
        ((depth + 1)..upper).sum { |n| tip(n, base: base, max: max, alpha: alpha) }.ceil
      end

      # Boxes and the ones ready to return in the last pool list in lines.
      #
      # @param lines [Array<String>]
      # @return [Array(Integer, Integer)] [boxes, ready to return]
      def list_counts(lines)
        start = lines.rindex { |line| line =~ LIST_HEADER }
        return [0, 0] unless start
        list = lines.drop(start)
        total = list.reverse_each.find { |line| line =~ /^\s*\d+\.\s+An?\s/ }.to_s[/\d+/].to_i
        [total, list.count { |line| line =~ /It is ready to be RETURNED\./ }]
      end

      # Boxes in the pool not yet ready to return. A list cut short falls
      # back to the whole server buffer (reget), as long as this list's
      # header was seen; otherwise the buffer's last list may be an old one.
      #
      # @param worker [GameObj]
      # @return [Array(Integer, Boolean)] [depth, whether the list came back whole]
      def depth(worker)
        results = EO.command("ask ##{worker.id} about list", Regexp.union(LIST_HEADER, /^(\d+)\./), silent: true, quiet: true, timeout: 15)
        total, returned = list_counts(results)
        whole = results.last =~ /<prompt/ ? true : false
        if !whole && results.any? { |line| line =~ LIST_HEADER }
          buffered_total, buffered_returned = list_counts(Array(reget))
          # Lich buffers each line before the script reads it, so the buffer is at least as complete
          total, returned = buffered_total, buffered_returned if buffered_total >= total
        end
        [total - returned, whole]
      end

      # What came of handing a box in. silver: the tip taken.
      Given = Struct.new(:outcome, :silver, keyword_init: true)

      # Give the box in the right hand to the worker with a tip, and confirm.
      #
      # @param worker [GameObj]
      # @param tip [String, Integer] a silver amount, optionally "N PERCENT"
      # @return [Given] outcome :deposited (with the silver), :short (not
      #   enough silver), :full (the pool is holding as many as it will),
      #   :already_open (the box needs no locksmith), or :none
      def give(worker, tip)
        outcome = Given.new(outcome: :none)
        2.times do |i|
          result = dothistimeout("give ##{worker.id} #{tip}#{i.zero? ? '' : ' confirm'}", 3, GIVE)
          case result
          when /totaling ([\d,]+) silvers?/ then outcome = Given.new(outcome: :deposited, silver: Regexp.last_match(1).delete(',').to_i)
          when /You don't have that much/ then outcome = Given.new(outcome: :short)
          when /already holding as many boxes/ then return Given.new(outcome: :full)
          when /already (unlocked|open)/ then return Given.new(outcome: :already_open)
          end
        end
        outcome
      end

      # Ask for one box back.
      #
      # @param worker [GameObj]
      # @return [Symbol, GameObj] the box now in hand, or :none (nothing
      #   ready), :heavy (too much carried to take it), :lost (the worker
      #   said here it is and no box arrived)
      def take_one(worker)
        # long enough to outlast lag: a reply after giving up hands back a box nothing opens
        result = dothistimeout("ask ##{worker.id} for return", 15, RETURN)
        return :heavy if result =~ /You need to lighten your load first/
        return :none unless result =~ /Alright, here's your/
        20.times do
          break if [GameObj.right_hand, GameObj.left_hand].map(&:type).compact.join(',') =~ /box|plinite/
          sleep 0.1
        end
        [GameObj.right_hand, GameObj.left_hand].find { |hand| hand.type =~ /box|plinite/ } || :lost
      end
    end
  end
end

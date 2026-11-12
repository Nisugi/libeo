# frozen_string_literal: true

module EO
  # Things done to one item: throwing it away unless it is marked, phasing
  # a box, lifting a curse, and the disk that follows the character.
  # eloot 2.15.0: marked_unsellable? (3285), toss (3303), box_phase
  # (3129), box_unphase (3140), decurse (3160), disk_usage (2751),
  # wait_for_disk (3767), disk_contents (3803).
  module Items
    module_function

    # @param obj [GameObj]
    # @return [Boolean] whether MARK says the item is unsellable (kept on purpose)
    def marked?(obj)
      lines = EO.command("mark ##{obj.id} status", /is not marked as unsellable|has been marked as unsellable/, silent: true, quiet: true)
      lines.any? { |l| l =~ /has been marked as unsellable/ }
    end

    # Trash or drop an item from a hand, retrying while it stays there. An
    # item marked unsellable is never tossed.
    #
    # @param obj [GameObj]
    # @param command [String] "trash" or "drop"
    # @param attempts [Integer]
    # @param poll [Boolean] a quick in-hand poll instead of the roundtime wait
    # @return [Symbol] :tossed, :marked, or :kept (still in hand after every try)
    def toss(obj, command, attempts: 1, poll: false)
      return :marked if marked?(obj)
      attempts.times do
        break unless Hands.holding?(obj)
        fput "#{command} ##{obj.id}"
        if poll
          10.times do
            break unless Hands.holding?(obj)
            sleep 0.1
          end
        else
          EO.settle
        end
      end
      Hands.holding?(obj) ? :kept : :tossed
    end

    # Phase a box (704) so it weighs nothing, unless it is enruned or mithril.
    #
    # @param box [GameObj]
    # @return [Boolean] whether a cast was made
    def phase(box)
      return false unless box.type =~ /box/
      return false if box.name =~ /enruned|mithril/i
      return false unless Spell[704].known? && Spell[704].affordable?
      loop do
        result = Spell[704].cast("at ##{box.id}")
        break unless result =~ /^\[Spell Hindrance for/ && Spell[704].affordable?
      end
      true
    end

    # Drop a phased box so it comes back solid, and pick it up again.
    #
    # @param box [GameObj]
    # @return [GameObj, nil] the box in hand after
    def unphase(box)
      lines = EO.command("look at ##{box.id}", /You see/, silent: true, quiet: true)
      return box unless lines.any? { |l| l =~ /shifting/i }
      dothistimeout("drop ##{box.id}", 3, /flickers in and out of existence/)
      EO.settle
      EO.command('glance hands', /<(right|left)/, silent: true, quiet: true)
      [GameObj.right_hand, GameObj.left_hand].find { |hand| hand.type =~ /box/ }
    end

    # Lift a curse with 315, or by wearing an eonake gauntlet on the hand
    # that will hold the item.
    #
    # @param obj [GameObj]
    # @param gauntlet [GameObj, nil] a worn eonake gauntlet
    # @return [Symbol] :clean (not cursed), :cast, :gauntlet, :no_mana, or :cannot
    def decurse(obj, gauntlet: nil)
      return :clean unless obj.type =~ /cursed/
      if Spell[315].known?
        Lich::Gemstone::Mana.pulse(315) unless Spell[315].affordable?
        return :no_mana unless Spell[315].affordable?
        Spell[315].cast("at ##{obj.id}")
        return :cast
      end
      return :cannot if gauntlet.nil?

      lines = EO.command("look ##{gauntlet.id}", /You are currently wearing the <a exist="[^"]+" noun="gauntlet">eonake gauntlet<\/a>/, silent: true, quiet: true)
      on = lines.any? { |l| l =~ /(right|left) hand/ } ? Regexp.last_match(1) : nil
      [%w[right Empty], %w[left Empty]].each do |side, _|
        next unless (side == 'right' ? GameObj.right_hand : GameObj.left_hand).name == 'Empty'
        return :gauntlet if on == side
        next unless on
        EO.result("remove ##{gauntlet.id}", /You slip the gauntlet from/)
        held = side == 'right' ? GameObj.right_hand : GameObj.left_hand
        EO.result('swap', /You swap/) unless held.id == gauntlet.id
        EO.result("wear ##{gauntlet.id}", /You slip the eonake gauntlet over/)
        return :gauntlet
      end
      :cannot
    end

    # The disk that follows the character: a hook keeps the handle current
    # as the disk arrives, follows and disintegrates. The hook persists
    # across script runs where Lich allows, since the disk outlives them.
    module Disk
      module_function

      HOOK = 'eloot_diskintegration'

      # @return [GameObj, nil] the character's disk, now
      def mine
        ::Disk.mine.nil? ? nil : GameObj[::Disk.mine.id]
      end

      # @param on_change [Proc] called with the disk GameObj or nil as it changes
      # @return [void]
      def watch(on_change)
        return if DownstreamHook.list.include?(HOOK)
        hook = proc do |server|
          case server
          when /The <a exist="-?\d+" noun="[^"]+">[^<]+<\/a>\s+disintegrates/
            on_change.call(nil) if ::Disk.mine.nil?
          when /Your <a exist="-?\d+" noun="[^"]+">[^<]+<\/a> arrives, following you dutifully\./
            on_change.call(mine) unless ::Disk.mine.nil?
          when /A small circular container suddenly appears and floats rather serenely over to you\./
            sleep 0.2 while ::Disk.mine.nil?
            on_change.call(mine)
          end
          server
        end
        if DownstreamHook.method(:add).parameters.any? { |_t, n| n == :persist }
          DownstreamHook.add(HOOK, hook, persist: true)
        else
          DownstreamHook.add(HOOK, hook)
        end
      end

      # Wait for the disk to catch up, then see that it is open.
      #
      # @param seconds [Numeric]
      # @return [GameObj, nil] the disk, nil when it never came
      def wait(seconds: 5)
        (seconds * 10).to_i.times do
          break if ::Disk.mine
          sleep 0.1
        end
        disk = mine
        Containers.ensure_open(disk) if disk
        disk
      end

      # @return [Array<GameObj>] the disk's contents, read fresh
      def contents
        Containers.fresh_contents(wait)
      end
    end
  end
end

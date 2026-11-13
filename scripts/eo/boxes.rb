# frozen_string_literal: true

module EO
  # Treasure boxes: opening one, the coins out of it, which to keep, and
  # setting one on a disk. eloot box_loot, box_loot_ground,
  # single_drag_box and the save-box rule.
  module Boxes
    module_function

    OPENED = /open|locked/
    COINS = /You gather the remaining|Get what|You can only collect|You cannot hold any more silvers/
    # Boxes worth selling once empty.
    VALUABLE = /gold|mithril|silver/

    # OPEN a box and LOOK IN it, so its contents are known.
    #
    # @param box [GameObj]
    # @param quiet [Boolean] hide the contents from the client
    # @return [Symbol] :open, :locked, or :unknown (the contents never came)
    def open(box, quiet: true)
      return :locked if EO.result("open ##{box.id}", OPENED).to_s =~ /locked/

      EO.command("look in ##{box.id}", Containers::LOOK, silent: quiet, quiet: quiet)
      Containers.contents_ready?(box, seconds: 3) ? :open : :unknown
    end

    # Take the coins out of an open box: a coin charm's POINT, else GET
    # COINS. When the character can hold no more, +full+ is called (to
    # deposit, say) and answers whether to go on. A charm gets five tries.
    #
    # @param box [GameObj]
    # @param charm [GameObj, nil]
    # @param full [Proc, nil] answers true to try again
    # @return [Array(Symbol, Integer)] :done, :full (gave up) or :unknown
    #   (an answer not known), and the silvers taken
    def coins(box, charm: nil, full: nil)
      silver = -> { Lich::Gemstone::Currency.silver(refresh: true).to_i }
      start = silver.call
      taken = 0
      points = 0
      while box.contents.to_a.any? { |obj| obj.name =~ /silver coins/ }
        if charm
          # a charm that stops summoning would point forever
          return [:unknown, taken + silver.call - start] if (points += 1) > 5

          EO.result("point ##{charm.id} at ##{box.id}", /You summon/)
          next
        end
        res = EO.result("get coins from ##{box.id}", COINS)
        if res =~ /You gather the remaining/
          EO.settle
          break
        elsif res =~ /You can only collect|You cannot hold any more silvers/
          EO.settle
          taken += silver.call - start
          return [:full, taken] unless full&.call

          start = silver.call
        else
          return [:unknown, taken + silver.call - start]
        end
      end
      [:done, taken + silver.call - start]
    end

    # Whether an emptied box is kept rather than thrown away: a valuable one
    # when boxes are sold, and a reliquary always.
    #
    # @param box [GameObj]
    # @param sell [Boolean] boxes are on the sell list
    # @return [Boolean]
    def keep?(box, sell:)
      (sell && box.contents.to_a.empty? && box.name =~ VALUABLE) || box.name =~ /reliquary/i ? true : false
    end

    # Set a box on a disk: the character's own first, the group's when
    # allowed, past the disks known to be full; a disk that refuses it is
    # marked full.
    #
    # @param box [GameObj]
    # @param full [Hash{String => Boolean}] disks by owner, true when full
    # @param put [Proc] given (disk, box), answers whether it went in
    # @param group [Boolean] the group's disks too
    # @return [String, nil] the disk owner it went to
    def to_disk(box, full:, put:, group: false)
      disks = Group.disks
      disks = disks.select { |d| d.name == Char.name } unless group
      disks.sort_by { |d| d.name == Char.name ? 0 : 1 }.each do |disk|
        next if full[disk.name]
        next unless ::Disk.find_by_name(disk.name)
        return disk.name if put.call(GameObj[disk.id], box)

        full[disk.name] = true
      end
      nil
    end
  end
end

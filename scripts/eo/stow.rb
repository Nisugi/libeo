# frozen_string_literal: true

module EO
  # Putting an item where the STOW list says: its type's bag, else the
  # default, else the overflow bags in number order, past the bags known
  # to be full. One per script; it keeps which bags filled up. eloot
  # single_drag, store_item and open_loot_containers.
  class Stow
    OVERFLOW = /\Aoverflow_container_?(\d*)\z/

    # @return [Hash{String => Array}] full bags by name, with when, where
    #   and the item that did not fit
    attr_accessor :full

    # @param bags [Hash{Symbol => GameObj}, nil] the bags by type; nil reads
    #   Lich's StowList.stow_list afresh each time, as STOW changes
    # @param learned [Proc, nil] given (:auto_close, bag), (:crumbly, item) or
    #   (:unlootable, item) when a put teaches something worth keeping
    def initialize(bags: nil, learned: nil)
      @list = bags
      @learned = learned || ->(_kind, _obj) {}
      @full = {}
    end

    # @return [Hash{Symbol => GameObj}]
    def bags = @list || StowList.stow_list

    # @return [Array<GameObj, nil>] the overflow bags in number order, nil
    #   for one listed but not found
    def overflow
      bags.keys.select { |key| key.to_s.match?(OVERFLOW) }.sort_by { |key| key.to_s[OVERFLOW, 1].to_i }.map { |key| bags[key] }
    end

    # The bags to try for an item, in order: its type's, the default, the
    # overflow. A bag not set is nil, so the caller can tell which is missing.
    #
    # @param item [GameObj]
    # @return [Array<GameObj, nil>]
    def route(item) = [bags[item.type.to_s.to_sym], bags[:default], *overflow]

    # @param bag [GameObj, nil]
    # @return [Boolean]
    def full?(bag) = !bag.nil? && @full.key?(bag.name)

    # The bags loot is about to go into, to open before looting: the
    # default, the overflow, and each item's type bag.
    #
    # @param items [Array<GameObj>]
    # @return [Array<GameObj>]
    def bags_for(items)
      [bags[:default], *overflow, *items.map { |item| bags[item.type.to_s.to_sym] }].compact.uniq(&:id)
    end

    # Put an item in one bag. A full bag is remembered (not for a gold
    # ingot, which eloot sells instead); a bag that closed itself, a
    # crumbly item and an unlootable one are told to +learned+.
    #
    # @param bag [GameObj]
    # @param item [GameObj]
    # @param loose [Boolean] see Hands.store (a skinning tool)
    # @return [Symbol] :stored, :full, :not_yours, :unlootable or :crumbled
    #   (both gone from the hand), or what else Hands.store answered
    def put(bag, item, loose: false)
      closed = lambda do |closed_bag|
        # Must be an auto closer. Their ID and contents don't drop from GameObj.containers when closed
        @learned.call(:auto_close, closed_bag) if GameObj.containers.key?(closed_bag.id) && closed_bag.contents.is_a?(Array)
      end
      result = Hands.store(bag, item, loose: loose, on_closed: closed)
      case result
      when :gone then :stored
      when :full
        @full[bag.name] = [Time.now.strftime('%Y-%m-%d %H:%M:%S'), Room.current.id, "#{item.name}(#{item.id})"] unless item.name =~ /gold ingot/
        :full
      when :unlootable, :crumbled
        @learned.call(result == :crumbled ? :crumbly : :unlootable, item)
        result
      else result
      end
    end

    # Put an item in the first bag along its route that takes it, skipping
    # the full ones.
    #
    # @param item [GameObj]
    # @param skipped [Proc, nil] given the route index of a bag not set
    # @return [GameObj, nil] the bag it went into, nil when none took it
    def store(item, skipped: nil)
      route(item).each_with_index do |bag, index|
        wait_while { stunned? } if stunned?
        if bag.nil?
          skipped&.call(index)
          next
        end
        next if full?(bag)
        return bag if %i[stored unlootable crumbled].include?(put(bag, item))
      end
      nil
    end
  end
end

# frozen_string_literal: true

module EO
  # The hands and what moves through them: freeing a hand, taking an item
  # into one, wearing, putting into a container, and the READY list's
  # weapons. Every outcome comes back as a word for the driver to act on;
  # nothing here stops the script. eloot Inventory 2.15.0: free_hand,
  # free_hands, drag, wear, store_item,
  # stow_ready_list, return_ready_list,
  # ready_item_key, fix_item_key.
  module Hands
    module_function

    GET = Regexp.union(
      /^You (?:shield the opening of .*? from view as you |discreetly |carefully |deftly |slowly |quickly )?(?:remove|draw|equip|grab|reach|slip|tuck|retrieve|already have|unsheathe|detach|swap|sling|withdraw)/,
      /^With subtle movements, you sneak a hand/, /^Get what\?$/, /^Why don't you leave some for others\?$/,
      /^You need a free hand/, /^You already have that/, /Reaching over your shoulder/, /^As you draw/,
      /^Ribbons of.*?light/, /^You are already holding/
    )
    PUT = Regexp.union(
      /You/, /Spreading your wings/, /I could not find what you were referring to/, /Draping the/,
      /Heedful of your surroundings/, /won't fit/, /crumbles? and decays? away/, /crumbles? into a pile of dust/,
      /That is not yours/, /Hey, that belongs to/, /Get what/, /Reaching over your shoulder/, /An ethereal.*?light swirls/,
      /As you move to put away your (?:<a exist="\d+" noun="\w+">[^<]+<\/a>|[\w-]+), it reverts to its normal state\./
    )
    MISSING = /Get what|I could not find what you were referring to/
    OVERLOADED = /You are unable to handle the additional load/

    # @param obj [GameObj]
    # @return [Boolean]
    def holding?(obj)
      return false if obj.nil?
      Lich::Stash.in_hand?(obj)
    end

    # @param side [Symbol] :right or :left
    # @return [Boolean] whether that arm and hand can hold something
    def usable?(side)
      parts = side == :right ? [Wounds.rightArm, Wounds.rightHand, Scars.rightArm, Scars.rightHand] : [Wounds.leftArm, Wounds.leftHand, Scars.leftArm, Scars.leftHand]
      parts.max < 3
    end

    # @param side [Symbol]
    # @return [Boolean] empty and usable
    def free?(side)
      Lich::Stash.empty_hand?(side) && usable?(side)
    end

    # Make a hand free, putting away what is in the one chosen: the left
    # when favoured or the right arm is gone, else the right.
    #
    # @param stow [Proc] given the GameObj in the hand, puts it away
    # @param favor_left [Boolean]
    # @return [Symbol] :free, or :crippled when neither hand can be used
    def free_hand(stow:, favor_left: false)
      return :free if free?(:right) || free?(:left)
      waitrt?
      if (favor_left && usable?(:left)) || !usable?(:right)
        return :crippled unless usable?(:left)
        stow.call(GameObj.left_hand) if checkleft
      else
        stow.call(GameObj.right_hand) if checkright
      end
      :free
    end

    # Take an item from a container or the ground into a hand.
    #
    # @param item [GameObj]
    # @param to [Symbol] :hand (whichever is free), :right or :left
    # @param stow [Proc] how to put away what is in the way
    # @return [Symbol] :held, :missing (the game could not find it),
    #   :overloaded (too heavy), or :failed (no answer and not in hand)
    def take(item, to: :hand, stow:)
      return :missing if item.nil? || item.name.to_s.empty? || item.name == 'Empty'
      case to
      when :hand
        free_hand(stow: stow)
        to = GameObj.right_hand.id.nil? ? :right : :left
      when :right then stow.call(GameObj.right_hand) if checkright
      when :left then stow.call(GameObj.left_hand) if checkleft
      end
      # A carried item in a closed container: Lich's Stash opens the way.
      Lich::Stash.open_path_to(item)
      line = EO.result("_drag ##{item.id} #{to}", Regexp.union(GET, MISSING, OVERLOADED))
      20.times do
        return :held if holding?(item)
        break if line =~ MISSING || line =~ OVERLOADED
        sleep 0.1
      end
      # the first line back can be room chatter instead of the drag's reply
      unless line =~ MISSING || line =~ OVERLOADED
        30.times do
          return :held if holding?(item)
          sleep 0.1
        end
      end
      return :overloaded if line =~ OVERLOADED
      return :missing if line =~ MISSING
      :failed
    end

    # Wear an item from a hand.
    #
    # @param item [GameObj]
    # @return [Symbol] :worn, :cant, or :stuck (still in hand with no refusal)
    def wear(item)
      return :cant if item.nil? || item.name.to_s.empty? || item.name == 'Empty'
      line = EO.result("_drag ##{item.id} wear", /You can't wear that|^You/)
      20.times do
        return :worn if !holding?(item) && GameObj.inv.map(&:id).compact.include?(item.id)
        break if line =~ /You can't wear that/
        sleep 0.1
      end
      holding?(item) ? :stuck : :worn
    end

    # Put an item into a container, up to five tries, opening the
    # container when it answers closed.
    #
    # @param bag [GameObj]
    # @param item [GameObj]
    # @param loose [Boolean] the container shows no contents (a weapon
    #   display): leaving the hand is proof enough
    # @param on_closed [Proc, nil] called with the bag when it answered
    #   closed and was opened for the put (a bag that closes itself)
    # @return [Symbol] :stored, :full, :not_yours, :gone (not in hand to
    #   begin with, or already taken), :unlootable (cannot be held),
    #   :crumbled, or :failed
    def store(bag, item, loose: false, on_closed: nil)
      return :gone if item.nil? || item.name == 'Empty'
      5.times do
        lines = EO.command("_drag ##{item.id} ##{bag.id}", PUT)
        if lines.any? { |l| l =~ /You can't.*?It's closed!/ }
          on_closed&.call(bag)
          EO.result("open ##{bag.id}", Containers::OPEN)
          lines = EO.command("_drag ##{item.id} ##{bag.id}", PUT)
        end
        return :not_yours if lines.any? { |l| l =~ /Hey, that belongs to/ }
        return :gone if lines.any? { |l| l =~ /You are unable to handle|That is not yours|Get what|I could not find what you were referring/ }
        return :unlootable if lines.any? { |l| l =~ /put something that you can't hold/ }
        return :full if lines.any? { |l| l =~ /won't fit/i }
        return :crumbled if lines.any? { |l| l =~ /crumbles? and decays? away|crumbles? into a pile of dust/i }

        Containers.ensure_open(bag) unless bag.contents.is_a?(Array) || loose
        20.times do
          return :stored if !holding?(item) && (loose || bag.contents.to_a.map(&:id).include?(item.id))
          sleep 0.1
        end
        # containers the game never refreshes (a disk) keep stale contents
        unless loose || holding?(item)
          EO.command("look in ##{bag.id}", Containers::LOOK, silent: true, quiet: true)
          return :stored if bag.contents.to_a.map(&:id).include?(item.id)
        end
        waitrt?
      end
      :failed
    end

    # --- the READY list -----------------------------------------------------

    # @param key [String, Symbol] a READY list key
    # @return [String] the word READY and STORE want for it
    def ready_word(key)
      case key.to_s
      when 'secondary_weapon' then '2weapon'
      when 'ranged_weapon' then 'ranged'
      else key.to_s
      end
    end

    # @param item [GameObj]
    # @param keys [Array<Symbol>] the READY list keys to consider
    # @return [Symbol, nil] the key this item is readied as
    def ready_key(item, keys: ReadyList.ready_list.keys)
      ReadyList.ready_list.find { |key, value| keys.include?(key) && value && value.id == item.id }&.first
    end

    # STORE a readied item back where the READY list keeps it.
    #
    # @param key [Symbol]
    # @param item [GameObj]
    # @return [Boolean] whether it left the hand
    def stow_ready(key, item)
      return true if ReadyList.ready_list[key.to_sym].nil?
      if ReadyList.store_list[key.to_sym] =~ /put in sheath/
        Containers.ensure_open(ReadyList.ready_list[:sheath])
      elsif ReadyList.store_list[key.to_sym] =~ /put in secondary/
        Containers.ensure_open(ReadyList.ready_list[:secondary_sheath])
      end
      10.times do
        EO.result("store #{ready_word(key)}", PUT)
        sleep 0.2
        return true unless holding?(item)
      end
      false
    end

    # READY an item back into a hand.
    #
    # @param key [Symbol]
    # @param item [GameObj]
    # @return [Boolean] whether it is in hand
    def ready(key, item)
      return true if ReadyList.ready_list[key.to_sym].nil?
      10.times do
        EO.result("ready #{ready_word(key)}", GET)
        sleep 0.2
        return true if holding?(item)
      end
      false
    end
  end
end

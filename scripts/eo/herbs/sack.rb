# frozen_string_literal: true

module EO
  module Herbs
    # The container the herbs live in: finding it, opening it, what is in
    # it by form, putting herbs in and taking them out, and the
    # Survivalist's Kit with its doses and distiller. eherbs Inventory,
    # find_herbsack, determine_survival_kit,
    # distill, store_herb.
    class Sack
      # Raised when the sack will not take another item.
      class Full < StandardError; end

      OPEN = Regexp.union(
        /You throw back/i, /You open/i, /Oh no! It's already/i, /You pick at the knot/i, /already open/i,
        /is open already/i, /You unfasten/i, /You glance around suspiciously/i, /^What were you referring to\?/i,
        /^I could not find what you were referring to\./i, /You pull the long strips of leather/i,
        /With a flick of your wrist/i, /Sliding the lever on the side/i, /You rub your hand/i,
        /There doesn't seem to be any way/i, /(?:Roundtime:|\.\.\.wait) (\d+) [Ss]ec(?:onds)?\./i,
        /crumbles? and decays? away/, /Myriad spectral moths pull a cloakwing/, /<exposeContainer|<container/i
      )
      # An OPEN answer that means we opened it, so it wants closing after.
      NEEDS_CLOSED = Regexp.union(
        /You throw back/i, /You open/i, /You pick at the knot/i, /You unfasten/i, /With a quick glance over your shoulder/i,
        /You pull the long strips of leather/i, /With a flick of your wrist/i, /Sliding the lever on the side/i,
        /You rub your hand/i, /Myriad spectral moths pull a cloakwing moth/
      )
      LOOK = Regexp.union(
        /Peering into the <a exist=.*? noun="toolkit">/i, /That is closed/i, /is shut too tightly to see its contents/i,
        /In the(.*?)you see/i, /In the(.*?):/i, /There is nothing/i, /You glance/i, /^Attached to a.*keyring/i, /.*?[.*?]:/i,
        %r{The <a exist="\d+" noun="\w+">[^<]+</a> has (?:an? <a exist="\d+" noun="\w+">[^<]+</a> |nothing )?in.*scabbard and (?:an? <a exist="\d+" noun="\w+">[^<]+</a> |nothing )?in.*scabbard\.}i,
        /^I could not find what you were referring to\./i, /Hidden within the depths of a cloakwing moth greatcloak/,
        /<exposeContainer|<dialogData|<container/i
      )
      CLOSE = Regexp.union(/^You (?:reach over your \w+ and )?close/, /^That is already closed/, /As you push/, /You tie/)
      PUT = Regexp.union(
        /^You (?:put|(?:discreetly )?tuck|attach|toss|attempt to shield your|place|.* place|slip|wipe off the blade and sheathe|absent-mindedly drop|carefully add|find an incomplete bundle|untie your drawstring pouch)/,
        /^The .+ is already a bundle/, /^Your bundle would be too large if you tried to add that/, /^The .+ is too large to be bundled\./,
        /^As you place your .+ inside your .+, you notice another .+ inside the .+ and carefully arrange the two .+ into a neat bundle\./,
        /If you wish to continue, throw the item away again within fifteen seconds/,
        /you feel pleased with yourself at having cleaned up the surrounding area/, /over your shoulder/, /two items in that location/,
        /wear three functional items/, /^Your .*? won't fit in .*?\.$/, /You add/, /You find a suitable/,
        /^Your .+ is already fully stocked with (?:solid|liquid) \w+\.  You put .+ in your .+\.$/
      )
      GET = Regexp.union(
        /^You (?:shield the opening of .*? from view as you |discreetly |carefully |deftly|just )?(?:remove|pick up|draw|grab|reach|slip|tuck|retrieve|already have|unsheathe|detach|swap)/,
        /^Get what\?$/, /^Why don't you leave some for others\?$/, /^You need a free hand/, /^You already have that/,
        /You just poured yourself/, /You retrieve/, /You break off/
      )
      WONT_FIT = /^Your .*? won't fit in .*?\.$/
      ENOUGH = /Why don't you leave some for others?/
      NOTE = /^(?:note|scrip|chit)$/
      KIT_CONTENTS = %r{(In|On|Under|Behind) .*?exist="(%s)" noun="(.*?)">(.*?)</a|There is nothing}
      KIT_DOSES = %r{^(.*?)The.*?exist="(-?\d+)" noun="(.*?)">(.*?)</a> contains DOSEs (.*?)\.}
      KIT_TINCTURES = %r{^(.*?)The.*?exist="(-?\d+)" noun="(.*?)">(.*?)</a> contains TINCTUREs (.*?)\.}
      KIT_ITEM = %r{(:?) <a exist="(.*?)" noun="(.*?)">(.*?)</a> \((.*?)\)}

      attr_reader :obj, :preposition, :tier
      attr_accessor :close_after, :survival_kit, :distiller

      # @param obj [GameObj] the container
      # @param preposition [String] in, on, under or behind
      def initialize(obj, preposition: 'in')
        @obj = obj
        @preposition = preposition.to_s.empty? ? 'in' : preposition
        @close_after = false
        @survival_kit = nil
        @distiller = false
        @tier = nil
      end

      def id = @obj.id
      def name = @obj.name
      def noun = @obj.noun
      def to_s = @obj.to_s

      # The container named in the settings, from the inventory.
      #
      # @param name [String]
      # @return [Sack]
      # @raise [Guild::Error] when the inventory has no such container
      def self.find(name)
        obj = GameObj.inv.find { |o| o.name =~ /\b#{Regexp.escape(name.to_s)}\b/i }
        raise Guild::Error, "unable to find container \"#{name}\" in your inventory" if obj.nil?
        new(obj)
      end

      # A container by name, in the inventory or in the room (a bench, a
      # table), with its herbs read the way the game lists them.
      #
      # @param name [String]
      # @param preposition [String]
      # @return [Sack]
      # @raise [Guild::Error] when nothing by that name is here
      def self.named(name, preposition: 'in')
        obj = GameObj.inv.find { |o| o.name =~ /\b#{Regexp.escape(name)}\b/i }
        return new(obj, preposition: preposition) if obj
        obj = (GameObj.room_desc.to_a + GameObj.loot.to_a).find { |o| o.name =~ /#{Regexp.escape(name)}/i }
        raise Guild::Error, "not able to find a #{name}" if obj.nil?
        new(obj, preposition: preposition)
      end

      # @return [Boolean] whether this is a container in the inventory
      def carried?
        GameObj.inv.any? { |o| o.id == @obj.id }
      end

      # ANALYZE the sack: a Survivalist's Kit has a tier and may have the
      # Liquid Extractor. Sets survival_kit, tier and distiller.
      #
      # @return [Boolean] whether it is a kit
      def analyze!
        lines = EO.command("analyze ##{id}", /You analyze/, silent: true, quiet: true)
        if lines.any? { |l| l =~ /is a Survivalist's Kit, which is a specialized container/ }
          @survival_kit = true
          @tier = Regexp.last_match(1).to_i if lines.any? { |l| l =~ %r{Capacity: (\d+)/5 } }
          @distiller = lines.grep(/has the Liquid Extractor unlock/).any?
        else
          @survival_kit = false
          @distiller = false
        end
        @survival_kit
      end

      # The doses to keep of each type, scaled to a percent of capacity: a
      # kit's by its tier, an ordinary sack's from the defaults.
      #
      # @param percent [Numeric] 0 to 100
      # @return [Hash{String => Integer}]
      def stock_targets(percent)
        percent = [percent.to_f, 100].min
        if @survival_kit
          amount = (((@tier.to_i * 25) + 25) * (percent / 100)).to_i
          Table::DEFAULT_DOSES.transform_values { amount }
        else
          Table::DEFAULT_DOSES.transform_values { |v| (v.to_f * (percent / 100)).to_i }
        end
      end

      # Open the sack if it is closed, remembering to close it after when
      # we were the one to open it.
      #
      # @return [Symbol] :open, :locked, or :empty
      def open
        return :open if GameObj.containers.keys.include?(id) && @obj.contents.is_a?(Array)
        result = EO.command("open ##{id}", OPEN, silent: true, quiet: true)
        @close_after = true if result.grep(NEEDS_CLOSED).any?
        return :locked if result.grep(/It appears to be locked./).any?
        lines = EO.command("look in ##{id}", LOOK, silent: true, quiet: true)
        return :empty if lines.grep(/You glance|There is nothing/i).any?
        20.times do
          break if GameObj.containers.keys.include?(id) && @obj.contents.is_a?(Array)
          sleep 0.1
        end
        :open
      end

      def close
        dothistimeout("close ##{id}", 5, CLOSE)
      end

      # The herbs in the sack, by form: drinkable, edible, all. A carried
      # sack is read from what Lich knows is inside; a kit lists its doses;
      # a room container is looked at by its preposition.
      #
      # @return [Hash{Symbol => Array<GameObj>}]
      # @raise [Guild::Error] for a locked room container
      def contents
        if carried?
          open
          analyze! if @survival_kit.nil?
          return kit_contents if @survival_kit
          by_form(@obj.contents.to_a)
        else
          by_form(room_contents)
        end
      end

      # @api private
      def by_form(items)
        herbs = items.select { |h| h.type == 'herb' }
        { drinkable: herbs.select { |h| Table.drinkable?(h.name) },
          edible: herbs.reject { |h| Table.drinkable?(h.name) },
          all: herbs }
      end

      # A kit's LOOK lists DOSEs and TINCTUREs with counts; the counts go to
      # Doses and the items come back by form.
      def kit_contents
        result = EO.command("look in ##{id}", Regexp.new(format(KIT_CONTENTS.source, id)), silent: true, quiet: true).join(' ')
        items = { drinkable: [], edible: [], all: [] }
        { edible: KIT_DOSES, drinkable: KIT_TINCTURES }.each do |form, pattern|
          next unless result =~ pattern
          Regexp.last_match(5).scan(KIT_ITEM).each do |_, exist, noun, name, count|
            item = GameObj.new_inv(exist, noun, name, id.to_s)
            Doses[exist] = count.to_i
            items[form] << item
            items[:all] << item
          end
        end
        GameObj[id].contents.to_a.each do |h|
          next unless Table::KNOWN.any? { |e| e[:name] == h.name }
          form = Table.drinkable?(h.name) ? :drinkable : :edible
          items[form] << h unless items[form].include?(h)
          items[:all] << h unless items[:all].include?(h)
        end
        items
      end

      # @api private
      def room_contents
        listing = nil
        loop do
          result = EO.command("look #{@preposition} ##{id}", Regexp.new(format(KIT_CONTENTS.source, id)), silent: true, quiet: true).join(' ')
          case result
          when %r{(?:Under|Behind|On|In) .*?exist="(-?\d+)" noun="(.*?)">(.*?)</a>(?::| you see )(.*?)$}
            listing = Regexp.last_match(4)
            break
          when /That is closed./
            break unless @preposition == 'in'
            raise Guild::Error, "not able to look in #{name}: it is locked" if open == :locked
          else
            break
          end
        end
        listing.to_s.scan(%r{<a exist="(.*?)" noun="(.*?)">(.*?)</a>}).map do |exist, noun, item_name|
          GameObj.new_inv(exist, noun, item_name, id.to_s)
        end.select { |o| Table::KNOWN.any? { |e| e[:name] =~ /#{Regexp.escape(o.name)}/ } }
      end

      # Put an item in the sack.
      #
      # @param item [GameObj, String] the item, or its id
      # @return [String, nil] the game's answer
      # @raise [Full] when it will not fit
      def store(item)
        item_id = item.respond_to?(:id) ? item.id : item
        result = EO.result("put ##{item_id} #{@preposition} ##{id}", PUT)
        raise Full, "the #{noun} is full" if result =~ WONT_FIT
        result
      end

      # Take an herb out into a free hand.
      #
      # @param herb [GameObj]
      # @return [Boolean] whether the item is drunk (its name says so)
      # @raise [Guild::Error] when the game says enough has been eaten from here
      def take(herb)
        free_hand
        to = GameObj.right_hand.id.nil? ? 'right' : 'left'
        result = EO.result("_drag ##{herb.id} #{to}", GET)
        raise Guild::Error, "you have eaten enough from the #{name}" if result =~ ENOUGH
        result =~ Table::DRINKABLE ? true : false
      end

      # Make a hand free, preferring the one a wound has not crippled.
      def free_hand
        right_ok = [Wounds.rightArm, Wounds.rightHand, Scars.rightArm, Scars.rightHand].max < 3
        left_ok = [Wounds.leftArm, Wounds.leftHand, Scars.leftArm, Scars.leftHand].max < 3
        return if (GameObj.right_hand.id.nil? && right_ok) || (GameObj.left_hand.id.nil? && left_ok)
        waitrt?
        if GameObj.right_hand.id && (right_ok || !left_ok)
          fput "stow #{GameObj.right_hand}" if checkright
        else
          fput "stow #{GameObj.left_hand}" if checkleft
        end
      end

      # Whether a hand holds a known herb; that item.
      #
      # @return [GameObj, nil]
      def self.herb_in_hand
        [GameObj.right_hand, GameObj.left_hand].find { |o| !o.name.to_s.empty? && Table.herb?(o.name) }
      end

      # A bank note in a hand or in the sack.
      def note
        [GameObj.right_hand, GameObj.left_hand].find { |o| o.noun =~ NOTE } || @obj.contents.to_a.find { |o| o.noun =~ NOTE }
      end

      # A kit's distiller: point it at a solid herb that has no liquid
      # form yet, else at the liquid that is lowest.
      #
      # @return [String, nil] what the extractor was set to, nil when nothing was done
      def distill
        return nil unless @distiller && @survival_kit
        lines = EO.command("ANALYZE ##{id}", /You analyze|You can't seem to do that\./, silent: true, quiet: true)
        return nil if lines.grep(/You can't seem to do that\./).any?
        text = lines.join(' ')
        if text =~ %r{The extractor is currently targeting <pushBold/>(.*?)<popBold/>, with around (.*?) remaining}
          Lich::Messaging.msg('info', " The extractor is currently targeting #{Regexp.last_match(1)}. Nothing to do.")
          return nil
        end
        solids = text =~ KIT_DOSES ? Regexp.last_match(5).scan(KIT_ITEM).to_h { |_, _e, _n, n, c| [n, c.to_i] } : {}
        liquids = text =~ KIT_TINCTURES ? Regexp.last_match(5).scan(KIT_ITEM).to_h { |_, _e, _n, n, c| [n, c.to_i] } : {}
        target = (solids.keys - liquids.keys).first
        target ||= liquids.select { |h, _| solids.key?(h) }.min_by { |_, c| c }&.first if solids.any?
        return nil if target.nil?
        fput "point ##{id} at dose #{target}"
        target
      end
    end
  end
end

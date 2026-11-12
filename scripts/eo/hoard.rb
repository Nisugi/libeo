# frozen_string_literal: true

module EO
  # Hoarding gems and alchemy reagents in jars: what an item is called on a
  # jar's label, whether it is the kind being hoarded, reading a jar, the
  # stash's inventory by looking or from a premium locker's manifest,
  # putting an item in a jar and shaking one out. eloot 2.15.0 Hoard:
  # check_type (4422), normalize_name (4447), build_inventory (4860),
  # build_premium_locker_inventory (4899), filter_inventory (4975),
  # shake (5142), check_jar (5187), store_items (5288).
  module Hoard
    module_function

    JAR = /^(?:jar|bottle|beaker)$/

    # An inventory line for a stash with empty jars in it.
    EMPTY_JARS = '*** empty jars ***'

    # The towns a premium member has a locker in, as LOCKER MANIFEST names them.
    MANIFEST_TOWNS = ["Wehnimer's Landing", 'Teras Isle', 'Solhaven', "River's Rest", 'Icemule Trace', 'Zul Logoth',
                      "Ta'Illistim", "Ta'Vaalor", 'Mist Harbor', 'Cysaegir', "Kraken's Fall", 'Family Vault'].freeze

    # The line of a locker manifest a container's contents follow, by its name.
    MANIFEST_SECTIONS = {
      /trunk/i => 'bound in wrought iron', /chest/i => 'deep chest', /rack/i => 'weapon rack',
      /stand/i => 'armor stand', /bin/i => 'magical item bin', /wardrobe/i => 'clothing wardrobe'
    }.freeze

    PUT = /You (add|put)|The.*?is full|does not appear to be a suitable/

    # An item's name as a jar's label carries it: no article or size,
    # singular, and the few names the game spells its own way.
    #
    # @param name [String, GameObj]
    # @return [String, nil]
    def normalize(name)
      return nil if name.nil?
      if name.is_a?(String)
        case name
        when /essences? of (air|earth|water|fire)/ then return "essence of #{Regexp.last_match(1)}"
        when /golden seed/ then return 'tiny golden seed'
        when /motes? of essence/ then name = name.gsub(/motes?/, 'mote')
        end
      end
      name = name.full_name if name.respond_to?(:full_name)
      name = name.to_s.downcase
      sizes = 'tiny|small|medium|large|blue-violet|pyrite-capped vibrant'
      articles = 'some|an? |the'
      descriptors = '(?:\\w+ )*?\\w+s? of(?: polished)?|polished'
      name = name[/^\s*(?:containing )?(?:#{articles})?\s*(?:#{sizes})?\s*(?:#{descriptors})?\s*(?:#{sizes})?\s*(.*?)\s*$/, 1].to_s
      rules = { 'ies' => 'y', 'onyxes' => 'onyx', 'zes' => 'z', 's' => '' }
      m = name.match(/^(.*?)(#{rules.keys.map { |k| Regexp.escape(k) }.join('|')})$/)
      m ? "#{m[1]}#{rules[m[2]]}" : name
    end

    # Whether a jar-label name is the kind being hoarded, by Lich's type data.
    #
    # @param item [String] a normalized name
    # @param kind [String] 'gem' or 'reagent'
    # @return [Boolean]
    def kind?(item, kind)
      GameObj.load_data if GameObj.type_data.empty?
      data = GameObj.type_data[kind]
      return false if data.nil?
      item = item.gsub(/teeth/, 'tooth')
      noun = item.split.last
      return false if item =~ data[:exclusion]
      return true if data[:name].to_s.match?(/\b#{item}\b/) || data[:noun].to_s.match?(/\b#{noun}\b/)
      return true if item =~ data[:name] || noun =~ data[:noun]
      if kind == 'reagent'
        return true if item =~ /kezmonian honey beryl|faintly glimmering dust/i
        return Room.list.any? { |r| r.tags.any? { |tag| tag.end_with?(item) || (item.start_with?(tag) && item =~ /ayana/) || item.end_with?(tag) } }
      end
      kind == 'gem' && item =~ /(?:deep blue sapphire|fiery ruby|glistening onyx|sparkling emerald) talon/i ? true : false
    end

    # @param stash [GameObj]
    # @return [Array<GameObj>] the jars in it with something in them
    def jars(stash)
      stash.contents.to_a.select { |obj| obj.noun =~ JAR && !obj.after_name.nil? }
    end

    # @param stash [GameObj]
    # @return [Array<GameObj>] the empty jars in it
    def empty_jars(stash)
      stash.contents.to_a.select { |obj| obj.noun =~ JAR && obj.after_name.nil? }
    end

    # @param stash [GameObj]
    # @param name [String] a normalized name
    # @return [GameObj, nil] the jar labelled for it
    def jar_for(stash, name)
      stash.contents.to_a.find { |obj| obj.noun =~ JAR && normalize(obj.after_name) =~ /^#{Regexp.escape(name)}$/ }
    end

    # LOOK IN a jar.
    #
    # @param jar [GameObj]
    # @param from [GameObj, nil] the stash it sits in, when not in hand
    # @return [Hash, Symbol] { count:, full: }, :empty, or :unknown
    def read(jar, from: nil)
      where = from ? " from ##{from.id}" : ''
      lines = EO.command("look in ##{jar.id}#{where}", /^Inside .*? you see [0-9]+ portion|^The <a exist=".*?is empty/, silent: true, quiet: true)
      if (line = lines.find { |l| l =~ /^Inside .*? you see ([0-9]+) portion/ })
        return { count: line[/you see ([0-9]+) portion/, 1].to_i, full: lines.any? { |l| l =~ /It is full/ } }
      end
      return :empty if lines.any? { |l| l =~ /^The <a exist=".*?is empty/ }
      :unknown
    end

    # The stash's inventory by looking in every jar. An entry for the empty
    # jars comes first when there are any.
    #
    # @param stash [GameObj]
    # @param kind [String] 'gem' or 'reagent'
    # @param progress [Proc, nil] called with the percent done after each jar
    # @return [Array<Hash>] { item:, count:, full: }
    def inventory(stash, kind, progress: nil)
      EO.command("look in ##{stash.id}", /<container id='.*?' title=/, silent: true, quiet: true)
      found = []
      empties = empty_jars(stash).size
      found << { item: EMPTY_JARS, count: empties, full: '  -' } if empties.positive?
      list = jars(stash)
      list.each_with_index do |jar, index|
        state = read(jar, from: stash)
        if state.is_a?(Hash)
          item = normalize(jar.after_name).strip
          found << { item: item, count: state[:count], full: state[:full] } if kind?(item, kind)
        end
        progress&.call((((index + 1).to_f / list.size) * 100).round(2))
      end
      found
    end

    # The town a premium locker's manifest is read for, from the locker
    # city setting or the container (a trunk lives in the Family Vault).
    #
    # @param city [String]
    # @param cache [String] the container's name
    # @return [String, nil] nil when the manifest has no such town
    def manifest_town(city, cache)
      town = cache =~ /trunk/i ? 'Family Vault' : ({ 'Kharam-Dzu' => 'Teras Isle', 'the Isle of Four Winds' => 'Mist Harbor' }[city] || city)
      MANIFEST_TOWNS.include?(town) ? town : nil
    end

    # A premium locker manifest's lines for one container, as inventory.
    #
    # @param lines [Array<String>] LOCKER MANIFEST's answer
    # @param cache [String] the container's name
    # @param kind [String] 'gem' or 'reagent'
    # @return [Array<Hash>, nil] { item:, count:, full: }; nil when the
    #   container's section is not in the manifest
    def parse_manifest(lines, cache, kind)
      heading = MANIFEST_SECTIONS.find { |pattern, _| cache =~ pattern }&.last
      start = heading && lines.index { |line| line.include?(heading) }
      return nil if start.nil?
      stop = lines[(start + 1)..].index { |line| line.strip.empty? }
      stop = stop.nil? ? lines.size : stop + start + 1
      section = lines[(start + 1)...stop]

      found = []
      empties = section.count { |line| line.match?(/(?:jar|bottle|beaker)/) && !line.include?('containing') }
      found << { item: EMPTY_JARS, count: empties, full: '  -' } if empties.positive?
      section.each do |line|
        m = line.match(/containing\s(?<item>.*?)\s+\((?<stored>\d+)\/(?<capacity>\d+)\)(?:\s+\(.*?\))?\z/)
        next unless m
        item = normalize(m[:item]).strip
        found << { item: item, count: m[:stored].to_i, full: m[:stored].to_i == m[:capacity].to_i } if kind?(item, kind)
      end
      found
    end

    # @param town [String] from .manifest_town
    # @return [Array<String>] LOCKER MANIFEST's answer
    def manifest(town)
      EO.command("locker manifest #{town}", /Thinking back, you recall the contents|Looking in front of you/, silent: true, quiet: true)
    end

    # Entries whose name holds the filter as a phrase, case-insensitively.
    #
    # @param entries [Array<Hash>]
    # @param filter [String, nil]
    # @return [Array<Hash>]
    def filter(entries, filter)
      phrase = filter.to_s.downcase.split.join(' ')
      return entries if phrase.empty?
      entries.select { |entry| entry[:item].to_s.downcase.split.join(' ').include?(phrase) }
    end

    # Put an item in a jar held in the other hand.
    #
    # @param item [GameObj] in hand
    # @param jar [GameObj] in hand
    # @return [Symbol] :added, :started (it went into an empty jar), :filled
    #   (the jar is full now), :full (it was already full), or :unsuitable
    def put(item, jar)
      result = EO.result("_drag ##{item.id} ##{jar.id}", PUT)
      case result
      when /does not appear to be a suitable/ then :unsuitable
      when /is full/ then :full
      when /into your empty (?:jar|bottle|beaker)/ then :started
      when /filling it/ then :filled
      else :added
      end
    end

    # Shake one item out of a jar in hand.
    #
    # @param jar [GameObj]
    # @return [Array(GameObj, Boolean)] the item now in the other hand, and
    #   whether that was the last one
    def shake(jar)
      lines = EO.command("shake ##{jar.id}", /You give your <a exist=".*?"/)
      item = [GameObj.right_hand, GameObj.left_hand].find { |i| i.id != jar.id }
      [item, lines.any? { |l| l =~ /That was the last/ }]
    end
  end
end

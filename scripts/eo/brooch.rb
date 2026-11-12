# frozen_string_literal: true

module EO
  # The quintuple orb brooch, a Rings of Lumnis prize: five orbs, each with
  # a few rubs a day. Planar raises the field experience cap for thirty
  # minutes (Lumnis' Enlightenment), Spiritual absorbs experience at once,
  # Elemental gives rerolls on guild tasks for thirty minutes (Lumnis'
  # Fortitude), Order adds bounty points at turn-in, and Chaos gives one of
  # the other four, the one ANALYZE names, chosen again after each rub.
  #
  # The brooch must be worn or held to be used; one kept in a container is
  # taken out for the rub and put back.
  module Brooch
    module_function

    # Each orb by the name ANALYZE gives it, and the word WHISPER takes.
    ORBS = {
      planar: { name: 'Planar', whisper: 'planar' },
      spirit: { name: 'Spiritual', whisper: 'spirit' },
      element: { name: 'Elemental', whisper: 'element' },
      chaos: { name: 'Chaos', whisper: 'chaos' },
      order: { name: 'Order', whisper: 'order' },
    }.freeze

    # The Buffs entry an orb leaves, for the orbs that last. Order's is not
    # known yet.
    BUFFS = { planar: "Lumnis' Enlightenment", element: "Lumnis' Fortitude" }.freeze

    NOUN = /\bbrooch\b/
    NAME = /orb brooch/
    ANALYZE_END = /\[SYNTAX: WHISPER/
    WHISPER_DONE = /is now attuned to the (\w+) ring|already centered on|it is unresponsive/
    # A rub's answer: the energy that took hold (a chaos rub names the orb
    # it gave), or the brooch has no use left for this orb.
    RUB = /energy flows into you|ebbs weakly, but nothing further happens/
    SPENT = /ebbs weakly, but nothing further happens/
    # A chaos rub names the orb it gave after its own chaotic energy.
    REPLACED = /as (\w+) energy soon replaces it/
    FLOWS = /(\w+) energy flows into you/
    ENERGY = { 'planar' => :planar, 'spiritual' => :spirit, 'elemental' => :element, 'order' => :order, 'orderly' => :order,
               'chaotic' => :chaos }.freeze

    # What ANALYZE says: the orb the brooch is on, the orb chaos will give,
    # and each orb's rubs used and allowed today.
    Status = Struct.new(:current, :chaos_gives, :uses, keyword_init: true) do
      # @param orb [Symbol]
      # @return [Integer] rubs left today
      def left(orb)
        used, max = uses.fetch(orb, [0, 0])
        [max - used, 0].max
      end
    end

    # ANALYZE's lines as a Status.
    #
    # @param lines [Array<String>]
    # @return [Status]
    def parse(lines)
      text = lines.join("\n")
      by_name = ORBS.to_h { |key, orb| [orb[:name], key] }
      current = by_name[text[/It is currently set to (\w+)/, 1]]
      gives = by_name[text[/will use the (\w+) benefit/, 1]]
      uses = {}
      used_at = text.index('You have used each orb')
      text[used_at..].to_s.scan(/^\s*(\w+): (\d+) out of (\d+)/) { |name, used, max| uses[by_name[name]] = [used.to_i, max.to_i] if by_name[name] }
      Status.new(current: current, chaos_gives: gives, uses: uses)
    end

    # @return [GameObj, nil] the brooch worn, held or in a container
    def find
      held = [GameObj.right_hand, GameObj.left_hand].find { |obj| brooch?(obj) }
      return held if held

      GameObj.inv.to_a.find { |obj| brooch?(obj) } || containers.values.flatten.find { |obj| brooch?(obj) }
    end

    # @api private
    def brooch?(obj) = !obj.nil? && obj.noun.to_s =~ NOUN && obj.name.to_s =~ NAME

    # @api private
    def containers = GameObj.containers.to_h

    # Run the block with the brooch usable: taken out of its container into
    # an empty hand first, and put back after.
    #
    # @yield the brooch is worn or held
    # @return [Object, nil] the block's value, nil when there is no brooch
    def with_brooch
      brooch = find
      return nil if brooch.nil?

      from = containers.find { |_id, contents| Array(contents).any? { |obj| obj.id == brooch.id } }&.first
      return yield if from.nil?

      empty_hands
      EO.result("get ##{brooch.id}", /You (?:get|remove|grab|pick)|Get what\?/)
      begin
        yield
      ensure
        EO.result("put ##{brooch.id} in ##{from}", /You (?:put|place|slip|tuck|drop)|Put what\?|won't fit/)
        fill_hands
      end
    end

    # @return [Status, nil] ANALYZE MY BROOCH, nil when there is no brooch
    def status
      with_brooch { parse(EO.command('analyze my brooch', ANALYZE_END, silent: true, quiet: true)) }
    end

    # @param orb [Symbol] a key of BUFFS
    # @return [Boolean] whether that orb's effect is up
    def up?(orb)
      name = BUFFS[orb]
      !name.nil? && Effects::Buffs.active?(name)
    end

    # Rub one orb, or chaos when chaos will give it: the orb's own rub
    # first, while it has one left today.
    #
    # @param orb [Symbol] :planar, :spirit, :element or :order
    # @param chaos [Boolean] use chaos when the orb is spent and chaos gives it
    # @return [Symbol] the orb that took hold, :spent when the brooch refused,
    #   :none when neither the orb nor chaos could give it, :no_brooch
    def use(orb, chaos: true)
      result = with_brooch do
        state = parse(EO.command('analyze my brooch', ANALYZE_END, silent: true, quiet: true))
        pick = if state.left(orb).positive? then orb
               elsif chaos && state.chaos_gives == orb && state.left(:chaos).positive? then :chaos
               end
        next :none if pick.nil?

        attune(pick, state)
        rub
      end
      result || :no_brooch
    end

    # Rub chaos if it will give +orb+ now, to spend that roll where it helps.
    #
    # @param orb [Symbol]
    # @return [Symbol] as #use, :none when chaos gives something else
    def use_chaos_if(orb)
      result = with_brooch do
        state = parse(EO.command('analyze my brooch', ANALYZE_END, silent: true, quiet: true))
        next :none unless state.chaos_gives == orb && state.left(:chaos).positive?

        attune(:chaos, state)
        rub
      end
      result || :no_brooch
    end

    # WHISPER MY BROOCH to the orb, unless it is already on it.
    #
    # @api private
    def attune(orb, state)
      return if state.current == orb

      EO.result("whisper my brooch #{ORBS.fetch(orb)[:whisper]}", WHISPER_DONE)
    end

    # RUB MY BROOCH.
    #
    # @return [Symbol] the orb whose energy took hold, or :spent
    def rub
      line = EO.result('rub my brooch', RUB, timeout: 5).to_s
      return :spent if line =~ SPENT

      energy = line[REPLACED, 1] || line[FLOWS, 1]
      ENERGY.fetch(energy.to_s.downcase, :unknown)
    end
  end
end

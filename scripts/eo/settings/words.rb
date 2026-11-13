# frozen_string_literal: true

# EO::Settings: the `;<script> settings <name> <value>` command line.

module EO
  module Settings
    # The setting a command line names: "sell-gold" is :sell_gold.
    #
    # @param word [String]
    # @return [Symbol]
    def self.setting_name(word) = word.to_s.downcase.tr('-', '_').to_sym

    # Typed words as the kind of value the setting holds now.
    #
    # @param name [Symbol] the setting, for the message
    # @param current [Object] its value now
    # @param words [Array<String>] what was typed after the name
    # @return [Object]
    # @raise [ArgumentError] when the words do not fit, with a message for the player
    def self.coerce(name, current, words)
      case current
      when true, false
        { 'on' => true, 'true' => true, 'yes' => true, 'off' => false, 'false' => false, 'no' => false }.fetch(words[0]) do |word|
          raise ArgumentError, %(Expected a boolean (true/false/yes/no) value for #{name} but got "#{word}")
        end
      when Array then words
      when Integer
        raise ArgumentError, %(Expected an integer value for #{name} but got "#{words[0]}") unless words[0] =~ /\A[+-]?\d+\z/
        words[0].to_i
      when Float
        raise ArgumentError, %(Expected a decimal value for #{name} but got "#{words[0]}") unless words[0] =~ /\A[+-]?\d+(?:\.\d+)?\z/
        words[0].to_f
      when String then words.join(' ')
      else raise ArgumentError, "Recognized #{name} but don't know how to change a #{current.class} setting"
      end
    end

    # `;<script> settings <name> <value ...>`: change one setting from the
    # command line, without the window.
    #
    # @param words [Array<String>] the setting's name, then its value
    # @param settings [Hash] changed in place
    # @param say [Proc] called with a message type ('debug', 'info', 'error') and its text
    # @yield after the change, to save the settings
    # @return [Symbol, nil] the setting changed, nil when the name is not a setting
    # @raise [ArgumentError] when the value does not fit the setting
    def self.update_from_words(words, settings, say:)
      key = setting_name(words.first)
      # changing debug itself: its own debug lines would flip on or off mid-change
      note = ->(text) { say.call('debug', text) unless key == :debug }
      note.call("Normalized #{words.first} as #{key}")
      unless settings.key?(key)
        say.call('error', " #{key} is not a recognized setting. Recognized setting names:")
        say.call('error', settings.keys.sort.join("\n"))
        return nil
      end
      note.call("Recognized #{key} as a #{settings[key].class} setting")
      value = coerce(key, settings[key].dup, words[1..])
      note.call("Normalized #{words[1..]} as #{value.inspect}")
      settings[key] = value
      say.call('info', " Updated #{key} to #{value}")
      yield settings if block_given?
      key
    end
  end
end

# frozen_string_literal: true

require 'fileutils'
require 'yaml'

module EO
  # The settings every e-script carries: whether Lich can open its window,
  # the profile file they are saved to, and every script's settings held for
  # the others to read. The rest is beside this file: settings/words.rb (the
  # command line), settings/table.rb (the settings table and its listing),
  # settings/window.rb (the setup window's shared parts).
  module Settings
    # @param form [Symbol] the Lich::WebUI form class the window is built on
    # @return [Boolean] whether Lich can open a WebUI window with that form
    def self.available?(form = :SettingsForm)
      defined?(Lich::WebUI) && Lich::WebUI.respond_to?(:presentation_enabled?) && Lich::WebUI.presentation_enabled? &&
        Lich::WebUI.const_defined?(form, false) ? true : false
    end

    # The character's profile file for a script: <data>/<game>/<character>/<script>.yaml.
    #
    # @param script [String] e.g. 'ebounty'
    # @param name [String] the character
    # @return [String]
    def self.profile_path(script, name: Char.name)
      File.join(DATA_DIR, XMLData.game, name, "#{script}.yaml")
    end

    # The e-scripts with a profile file, held in memory for any script to read.
    SCRIPTS = %w[ebounty echild ecleanse eherbs eloot escortgo2 ewaggle ewander].freeze

    # What libeo holds, by script: read from the files when libeo loads, and
    # replaced whenever the script loads or saves its own.
    @held ||= {}

    # Read every e-script's profile into memory. libeo.lic calls this when
    # it loads.
    #
    # @param scripts [Array<String>]
    # @return [void]
    def self.preload(scripts = SCRIPTS) = scripts.each { |script| load_profile(script) }

    # Another script's settings, as that script last loaded or saved them.
    # Frozen: only the script itself changes its settings, and its save
    # puts the new values here.
    #
    # @param script [String, Symbol] e.g. :eloot
    # @return [Hash, nil] nil when the script has no profile
    def self.read(script)
      script = script.to_s
      load_profile(script) unless @held.key?(script)
      @held[script]
    end

    # @param script [String]
    # @param settings [Hash, nil]
    # @return [void]
    # A script's settings kept in its profile and used like CharSettings:
    # read with [], and []= saves. A list changed in place is saved by
    # #save, and again when the script exits. echild, escortgo2, ewander.
    class Store
      # @param script [String]
      # @param migrate [Array<String>] keys copied from CharSettings when the
      #   script has no profile yet; CharSettings is left as it was
      def initialize(script, migrate: [])
        @script = script
        @values = Settings.load_profile(script) || migrate.to_h { |key| [key, Settings.plain(CharSettings[key])] }
        save unless File.exist?(Settings.profile_path(script))
      end

      # @param key [String]
      def [](key) = @values[key]

      # @param key [String]
      # @param value [Object]
      def []=(key, value)
        @values[key] = value
        save
      end

      # @return [String] the file written
      def save = Settings.save_profile(@script, @values)

      # @return [Hash]
      def to_h = @values
    end

    # The script's Store, saved again when the script exits.
    #
    # @param script [String]
    # @param migrate [Array<String>] see Store#initialize
    # @return [Store]
    def self.store(script, migrate: [])
      store = Store.new(script.to_s, migrate: migrate)
      before_dying { store.save }
      store
    end

    # @api private
    def self.hold(script, settings)
      @held[script] = settings && deep_freeze(Marshal.load(Marshal.dump(settings)))
    end

    # A value with Lich's CharSettings proxies swapped for what they wrap,
    # at any depth: a proxy written to YAML cannot be read back.
    #
    # @api private
    def self.plain(value)
      value = value.target while value.class.name.to_s.end_with?('SettingsProxy') && value.respond_to?(:target)
      case value
      when Hash then value.to_h { |k, v| [plain(k), plain(v)] }
      when Array then value.map { |v| plain(v) }
      else value
      end
    end

    # @api private
    def self.deep_freeze(value)
      case value
      when Hash then value.each_value { |v| deep_freeze(v) }
      when Array then value.each { |v| deep_freeze(v) }
      end
      value.freeze
    end

    # @param script [String]
    # @param name [String] the character
    # @return [Hash, nil] the saved settings, nil when there is no profile yet
    def self.load_profile(script, name: Char.name)
      path = profile_path(script, name: name)
      settings = File.exist?(path) ? YAML.load_file(path) : nil
      hold(script, settings) if name == Char.name
      settings
    end

    # Write the settings, making the character's directory when it is new.
    #
    # @param script [String]
    # @param settings [Hash]
    # @return [String] the file written
    def self.save_profile(script, settings)
      path = profile_path(script)
      FileUtils.mkdir_p(File.dirname(path))
      settings = plain(settings)
      File.write(path, settings.to_yaml)
      hold(script, settings)
      path
    end
  end
end

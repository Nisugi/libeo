# frozen_string_literal: true

# libeo's version gate. A script calls EO.require right after
# Script.loadlib('libeo') with the libeo version it was written against.
#
# The files under scripts/eo/ are loaded by libeo.lic with `load`, so they
# run at the top level and `module EO` is ::EO, the same constant the engine
# library and scripts see. (A script body is evaluated inside Lich::Common,
# which is why libeo.lic itself never opens the module.)
module EO
  VERSION = '0.3.0'.freeze

  # The lowest version a caller may name that this library still serves. Raise it
  # when an API is removed, so a script built against the removed API fails at
  # load rather than at the call.
  OLDEST_SUPPORTED = '0.1.0'.freeze

  class VersionError < StandardError; end

  # Too new a request means the script is ahead of the library the user has;
  # too old means the library dropped something the script may use. Both are loud.
  #
  # @param wanted [String] the version the calling script was built against
  # @return [true]
  # @raise [VersionError] on a mismatch, after telling the user how to fix it
  def self.require(wanted)
    have = Gem::Version.new(VERSION)
    want = Gem::Version.new(wanted.to_s)
    caller_name = defined?(Script) && Script.current&.name || 'script'
    if want > have
      Lich::Messaging.msg('error', "#{caller_name} needs libeo #{wanted} but #{VERSION} is installed. Update libeo (;repo download libeo or ;jinx).")
      raise VersionError, "libeo #{VERSION} is older than #{wanted} required by #{caller_name}"
    elsif want < Gem::Version.new(OLDEST_SUPPORTED)
      Lich::Messaging.msg('error', "#{caller_name} was built against libeo #{wanted}, which #{VERSION} no longer supports. Update #{caller_name}.")
      raise VersionError, "libeo #{VERSION} no longer supports #{wanted} required by #{caller_name}"
    end
    true
  end

  # @return [String] the library version
  def self.version
    VERSION
  end

  # Whether the running Lich is new enough for the calling script, telling
  # the player how to update when it is not. The script exits on false:
  #
  #   exit unless EO.require_lich
  #
  # @param wanted [String, nil] the Lich version needed; nil reads the
  #   script header's "required: Lich >= x.y.z"
  # @return [Boolean]
  def self.require_lich(wanted = nil)
    name = Script.current&.name
    wanted ||= Script.list.find { |script| script.name == name }.inspect[/required: Lich >= (\d+\.\d+\.\d+)/i, 1]
    return true if wanted.nil? || Gem::Version.new(LICH_VERSION) >= Gem::Version.new(wanted)

    lines = ["Script:#{name} now requires a newer version of Lich(#{wanted}+) to run.",
             'Please update to a newer version.',
             '',
             "Currently Running Lich Version: #{Gem::Version.new(LICH_VERSION)}",
             'For help updating visit: https://gswiki.play.net/Lich_(software)/Installation']
    rule = '#' * 40
    if %w[stormfront profanity].include?($frontend)
      _respond %(<preset id="speech">#{rule}</preset>)
      lines.each { |line| _respond(line.empty? ? '' : %(<preset id="thought">#{line}</preset>)) }
      _respond %(<preset id="speech">#{rule}</preset>)
    else
      _respond "###{rule}"
      lines.each { |line| _respond ">#{line}" }
      _respond "###{rule}"
    end
    false
  end

  # The version in a running script's header, the way every e-script reads
  # its own for its titles and help.
  #
  # @param name [String] the script's name, the current script by default
  # @return [String, nil] "major.minor.patch", nil when the script is not running
  def self.script_version(name = Script.current&.name)
    Script.list.find { |script| script.name == name }.inspect[/version: (\d+\.\d+\.\d+)/i, 1]
  end
end

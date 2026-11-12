# frozen_string_literal: true

module EO
  # Roundtime or "...wait N seconds" in a command's answer: the command did
  # not run and is sent again once the wait is over.
  ROUNDTIME = /(?:Roundtime:|\.\.\.wait) (\d+) [Ss]ec(?:onds)?\./i

  # Send a command and collect its answer, re-sending after a roundtime
  # refusal. ebounty get_command.
  #
  # @param command [String]
  # @param regex [Regexp] what ends the answer
  # @param silent [Boolean, nil] hide the answer from the client
  # @param quiet [Boolean] hide the command from the client
  # @param timeout [Numeric, nil] seconds to wait for the answer, nil for Lich's default
  # @return [Array<String>] the answer's lines
  def self.command(command, regex, silent: nil, quiet: false, timeout: nil)
    stop = Regexp.union(regex, ROUNDTIME)
    opts = { silent: silent, quiet: quiet }
    opts[:timeout] = timeout if timeout
    loop do
      lines = Lich::Util.issue_command(command, stop, **opts)
      return lines unless lines.any? { |line| line.match?(ROUNDTIME) }
      waitrt?
    end
  end

  # Send a command and return the one line that answers it, re-sending after
  # a roundtime refusal. ebounty get_res.
  #
  # @param command [String]
  # @param regex [Regexp] what answers the command
  # @param timeout [Numeric] seconds to wait for the answer
  # @return [String, nil] the matching line, nil when nothing matched in time
  def self.result(command, regex, timeout: 3)
    stop = Regexp.union(regex, ROUNDTIME)
    loop do
      line = dothistimeout(command, timeout, stop)
      return line unless line.to_s.match?(ROUNDTIME)
      waitrt?
    end
  end

  # Wait out cast and hard roundtime with a short settle either side, the way
  # every e-script does between commands. ebounty wait_rt.
  #
  # @return [void]
  def self.settle
    sleep 0.2
    waitcastrt?
    waitrt?
    sleep 0.2
  end
end

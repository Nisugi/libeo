# frozen_string_literal: true

module EO
  # Send a message the way the e-scripts do: a Hash or Array is inspected,
  # "#<" is defused so the client does not read it as a tag, and a debug
  # message shows as speech.
  #
  # @param type [String] a Lich::Messaging type: yellow, orange, teal, green, plain, debug, ...
  # @param text [Object]
  # @return [void]
  def self.say(type, text)
    text = case text
           when Hash then text.inspect.gsub('#<', '#')
           when Array then text.to_s
           when String then text.gsub('#<', '#')
           else text
           end
    Lich::Messaging.msg(type == 'debug' ? 'speech' : type, text)
  end

  # Break text into lines of at most +width+ characters, at spaces.
  #
  # @param text [String]
  # @param width [Integer]
  # @return [String]
  def self.word_wrap(text, width = 60)
    text.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n").strip
  end
end

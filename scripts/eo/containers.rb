# frozen_string_literal: true

module EO
  # Containers: opening one so its contents can be read, knowing whether we
  # were the one who opened it, and reading contents the game does not
  # refresh on its own. ebounty open_container (673 in 1.13.0); eloot
  # open_single_container (4054), container_contents (3816),
  # fresh_contents (3795), close_container (3886), the regexes (651-703).
  module Containers
    module_function

    # Every answer OPEN gets, including the ones that mean it was open already.
    OPEN = Regexp.union(
      /You throw back/i, /You open/i, /Oh no! It's already/i, /You pick at the knot/i, /already open/i,
      /is open already/i, /You unfasten/i, /You glance around suspiciously/i, /^What were you referring to\?/i,
      /^I could not find what you were referring to\./i, /You pull the long strips of leather/i,
      /With a flick of your wrist/i, /Sliding the lever on the side/i, /You rub your hand/i,
      /There doesn't seem to be any way/i, /(?:Roundtime:|\.\.\.wait) (\d+) [Ss]ec(?:onds)?\./i,
      /crumbles? and decays? away/, /crumbles? into a pile of dust/, /Myriad spectral moths pull a cloakwing/,
      /<exposeContainer|<container/i, /You undo each of the/, /stuffed with a variety of shredded up paper and cloth/
    )

    # Every answer LOOK IN gets.
    LOOK = Regexp.union(
      /Peering into the <a exist=.*? noun="toolkit">/i, /That is closed/i, /is shut too tightly to see its contents/i,
      /In the(.*?)you see/i, /In the(.*?):/i, /There is nothing/i, /You glance/i, /^Attached to a.*keyring/i, /.*?[.*?]:/i,
      /The <a exist="\d+" noun="\w+">[^<]+<\/a> has (?:an? <a exist="\d+" noun="\w+">[^<]+<\/a> |nothing )?in.*scabbard and (?:an? <a exist="\d+" noun="\w+">[^<]+<\/a> |nothing )?in.*scabbard\./i,
      /^I could not find what you were referring to\./i, /Hidden within the depths of a cloakwing moth greatcloak/,
      /<exposeContainer|<dialogData|<container/i, /stuffed with a variety of shredded up paper and cloth/,
      /As much as you'd like to open it, its not closed\./, /^Looking at the .*?, you notice:/i,
      /^The .+? has .+? in its left-hand scabbard and .+? in its right-hand scabbard\.$/i
    )

    # A LOOK IN answer that shows there is nothing Lich will list: empty, or
    # a container whose contents the game never itemises.
    NOTHING_LISTED = /You glance|There is nothing|stuffed with a variety of shredded up paper and cloth|^Looking at the .*?, you notice:|^The .+? has .+? in its left-hand scabbard and .+? in its right-hand scabbard\.$/i

    CLOSE = Regexp.union(/You close .*/, /(?:That|It) is already closed/, /What were you referring to/,
                         /seem to be any way to do that/, /You tie/, /You fasten the/)

    # @param container [GameObj]
    # @return [Boolean] whether Lich has the container's contents
    def listed?(container)
      GameObj.containers.keys.include?(container.id) && container.contents.is_a?(Array)
    end

    # Open +container+ only if it is closed, and refresh what Lich knows is
    # inside. An open container answers LOOK IN with its contents, so it never
    # gets an OPEN. Custom open and close messages vary too much to trust, so
    # the only proof we opened something is LOOK IN saying it was closed and
    # OPEN not saying it was already open.
    #
    # @param container [GameObj]
    # @return [Boolean] true when this call opened it, so the caller can close
    #   it again before the script dies
    def open(container)
      id = container.id
      return false if listed?(container)
      return false if container.name =~ /keyring/

      shown = /In the <a exist="#{id}"|This <a exist="#{id}"[^>]*>.*?<\/a>.*?inside|There is nothing in there/
      look = Regexp.union(shown, /<exposeContainer id=['"]#{id}['"]|<container id=['"]#{id}['"]|\bis closed\b/i)
      lines = EO.command("look in ##{id}", look, silent: true, quiet: true)
      return false if lines.any? { |l| l =~ shown }

      was_closed = lines.any? { |l| l =~ /\bis closed\b/i }
      not_opened = /\bis (?:already open|open already)\b|There doesn't seem to be any way to do that|You can't do that|You must remove|What were you referring to|I could not find/i
      lines = EO.command("open ##{id}", Regexp.union(not_opened, /exist="#{id}"|<exposeContainer|^You\b/i), silent: true, quiet: true)
      opened = was_closed && lines.none? { |l| l =~ not_opened }

      EO.command("look in ##{id}", look, silent: true, quiet: true)
      20.times do
        break if listed?(container)
        sleep 0.1
      end
      opened
    end

    # See that a container is open and its contents known, opening it if
    # need be (the quick path: OPEN then LOOK IN, no proof of who opened it).
    #
    # @param container [GameObj]
    # @return [Symbol] :listed (contents known), :nothing (empty, or a
    #   container the game does not itemise), or :unknown
    def ensure_open(container)
      return :listed if container.nil? || listed?(container)
      EO.command("open ##{container.id}", OPEN, silent: true, quiet: true)
      lines = EO.command("look in ##{container.id}", LOOK, silent: true, quiet: true)
      return :nothing if lines.any? { |l| l =~ NOTHING_LISTED }
      listed?(container) ? :listed : :unknown
    end

    # Wait for Lich to have a container's contents, looking in once more
    # when it takes too long.
    #
    # @param container [GameObj]
    # @param seconds [Numeric]
    # @return [Boolean]
    def contents_ready?(container, seconds: 3)
      (seconds * 10).to_i.times do
        return true if listed?(container)
        sleep 0.1
      end
      lines = EO.command("look in ##{container.id}", LOOK, silent: true, quiet: true)
      (seconds * 10).to_i.times do
        return true if listed?(container)
        return true if lines.any? { |l| l =~ NOTHING_LISTED }
        sleep 0.1
      end
      false
    end

    # Lich only updates a container's contents when the game sends a
    # refresh, and some containers never get one (a disk, a sack the
    # furrier emptied). Look in, then read.
    #
    # @param container [GameObj, nil]
    # @return [Array<GameObj>]
    def fresh_contents(container)
      return [] if container.nil?
      EO.command("look in ##{container.id}", LOOK, silent: true, quiet: true)
      container.contents.to_a
    end

    # @param container [GameObj]
    # @return [String, nil] the game's answer
    def close(container)
      EO.result("close ##{container.id}", CLOSE)
    end
  end
end

# frozen_string_literal: true

module EO
  module Guild
    # Talking to the taskmaster: getting, turning in, removing and
    # expediting a task; boosts, vouchers and the cooldown. ebounty
    # ask_taskmaster, bounty_get, bounty_remove,
    # check_boost, check_voucher,
    # wait_until_next_bounty_available, bounty_change.
    module Taskmaster
      module_function

      # What to ASK ABOUT for each kind of visit, how many times to ask (a
      # removal and an expedite both want confirming), and whether success
      # means ending with no task or with one.
      ASKS = {
        get: { about: 'bounty', times: 1, ends_with_task: true },
        turn_in: { about: 'bounty', times: 1, ends_with_task: false },
        remove: { about: 'removal', times: 2, ends_with_task: false },
        expedite: { about: 'expediting', times: 2, ends_with_task: true },
        failure: { about: 'bounty', times: 1, ends_with_task: false },
      }.freeze

      ATTEMPTS = 5

      # Ask the taskmaster until the task state is what the ask should leave
      # behind, retrying when the bounty text does not change.
      #
      # @param kind [Symbol] a key of ASKS
      # @param boost_type [String, nil] with :get while a boost runs, the type to ask for
      # @return [Symbol] :done, :already_assigned (a get when a task is held),
      #   or :ready (an expedite the taskmaster answered with a fresh offer)
      # @raise [Error] when five rounds of asking changed nothing
      def ask(kind, boost_type: nil)
        spec = ASKS.fetch(kind)
        about = kind == :get && boost_type ? "bounty #{boost_type}" : spec[:about]
        before = checkbounty
        attempts = 0
        begin
          attempts += 1
          times = spec[:times]
          until spec[:ends_with_task] ? Bounty.type != :none : Bounty.type == :none
            npc = NPCs.taskmaster
            asked = 0
            while asked < times
              asked += 1
              result = fput "ask #{npc} about #{about}"
              if result =~ /Who are you trying to ask/
                # nobody by that name here: find the taskmaster again and ask once more
                npc = NPCs.taskmaster
                times += 1
              elsif result =~ /You have already been assigned a task/
                return :already_assigned
              elsif result =~ /I'm ready to assign you a new task/ && kind == :expedite
                return :ready
              end
              EO.settle
            end
            raise Error, 'the bounty did not change' unless changed?(before)
          end
          :done
        rescue Error => e
          raise Error, "#{e.message} after #{ATTEMPTS} attempts asking the taskmaster about #{about}" if attempts >= ATTEMPTS
          Lich::Messaging.msg('warn', "Bounty type did not change, retrying (attempt #{attempts})...")
          retry
        end
      end

      # Get a task, asking for the boosted type the policy names while a
      # Bounty Boost runs.
      #
      # @param policy [TaskPolicy]
      # @return [Symbol] as #ask
      def get(policy)
        choice = Effects::Buffs.active?('Bounty Boost') ? policy.boost_choice : nil
        ask(:get, boost_type: choice)
      end

      # Hand the task back, then spend a voucher on a new one when the policy
      # allows and no boost is running (a boost reassigns for free).
      #
      # @param policy [TaskPolicy]
      # @param voucher [Boolean] false to only remove
      # @return [Symbol] as #ask
      def remove(policy, voucher: true)
        result = ask(:remove)
        return result unless voucher && policy.use_vouchers && !Effects::Buffs.active?('Bounty Boost') && vouchers.positive?
        ask(:expedite)
      end

      # Start a Bounty Boost: a new task every five seconds until one is
      # completed, shared, or an hour passes.
      #
      # @return [void]
      def boost!
        fput 'boost bounty'
        sleep 4
      end

      # @return [Integer] Bounty Boosts held, from BOOST INFO
      def boosts
        lines = EO.command('boost info', /<a exist=".*?" noun=".*?">.*?<\/a>, your Login Rewards information is as follows/, silent: true, quiet: true)
        line = lines.find { |l| l =~ /<d cmd='boost bounty'>Bounty Boosts<\/d>:\s+([0-9,]+)/ }
        line ? Regexp.last_match(1).delete(',').to_i : 0
      end

      # @return [Integer] expedited task reassignment vouchers held, from BOUNTY
      def vouchers
        lines = EO.command('bounty', /<a exist=".*?" noun=".*?">.*?<\/a>, your Adventurer's Guild information is as follows/, silent: true, quiet: true)
        line = lines.find { |l| l =~ /You have ([0-9,]+) expedited task reassignment vouchers remaining/ }
        line ? Regexp.last_match(1).delete(',').to_i : 0
      end

      # @return [Boolean] whether the Next Bounty cooldown is running
      def cooldown?
        Effects::Cooldowns.active?('Next Bounty')
      end

      # Wait out the Next Bounty cooldown, saying once a minute how long is left.
      #
      # @return [void]
      def wait_for_cooldown
        next_notice = Time.now
        while cooldown?
          if Time.now >= next_notice
            remaining = Effects::Cooldowns.time_left('Next Bounty')
            if remaining&.positive?
              minutes = remaining.to_i
              seconds = ((remaining - minutes) * 60).round
              Lich::Messaging.msg('info', " Next bounty available in #{minutes} minutes and #{seconds} seconds.")
            end
            next_notice = Time.now + 60
          end
          sleep 5
        end
      end

      # Wait up to three seconds for the bounty text to change after an ask.
      #
      # @param before [String] the bounty text before the ask
      # @return [Boolean] whether it changed in time
      def changed?(before)
        deadline = Time.now + 3
        until Time.now > deadline
          return true if checkbounty != before
          sleep 0.2
        end
        false
      end
    end
  end
end

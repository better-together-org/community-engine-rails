# frozen_string_literal: true

module BetterTogether
  module BotDefenseTestHelpers
    def bot_defense_payload(form_id)
      challenge = travel_to(3.seconds.ago) do
        BetterTogether::BotDefense::Challenge.issue(form_id:)
      end

      {
        bot_defense: {
          token: challenge.token,
          trap_values: { challenge.trap_field => '' }
        }
      }
    end

    def satisfy_bot_defense_minimum_wait(form_id)
      config = BetterTogether::BotDefense::Challenge::FORM_CONFIG.fetch(form_id.to_sym)
      sleep(config[:min_submit_seconds] + 0.1)
    end
  end
end

RSpec.configure do |config|
  config.include BetterTogether::BotDefenseTestHelpers
end

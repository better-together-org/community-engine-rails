# frozen_string_literal: true

module BetterTogether
  # Per-account throttles for actions that can be used to harass or spam people.
  # Runs after authentication (so it keys on the signed-in person, not the IP) and
  # counts through the Rack::Attack cache store, so limits are shared across processes.
  # Over-limit requests get the same 503 + Retry-After as Rack::Attack's throttled responder.
  #
  # Each limit is tunable per environment: BTS_THROTTLE_<NAME>_LIMIT and BTS_THROTTLE_<NAME>_PERIOD
  # (seconds). A limit of 0 disables that throttle.
  module PerUserThrottling
    extend ActiveSupport::Concern

    DEFAULTS = {
      conversation_create: { limit: 10, period: 1.hour },
      message_send: { limit: 30, period: 1.minute },
      report_create: { limit: 10, period: 1.hour },
      block_create: { limit: 20, period: 1.hour },
      invitation_create: { limit: 30, period: 1.hour },
      comment_create: { limit: 20, period: 1.minute }
    }.freeze

    class_methods do
      # throttle_per_user :message_send, only: :create
      def throttle_per_user(name, **callback_options)
        raise ArgumentError, "Unknown throttle #{name}" unless DEFAULTS.key?(name)

        before_action(**callback_options) { enforce_user_throttle(name) }
      end
    end

    def self.settings_for(name)
      defaults = DEFAULTS.fetch(name)
      key = "BTS_THROTTLE_#{name.to_s.upcase}"
      {
        limit: ENV.fetch("#{key}_LIMIT", defaults[:limit]).to_i,
        period: ENV.fetch("#{key}_PERIOD", defaults[:period].to_i).to_i
      }
    end

    private

    def enforce_user_throttle(name)
      person = current_user&.person
      settings = PerUserThrottling.settings_for(name)
      return unless person && settings[:limit].positive? && settings[:period].positive?
      return unless throttle_exceeded?(name, person, settings)

      response.set_header('Retry-After', retry_after_seconds(settings[:period]).to_s)
      head :service_unavailable
    end

    def throttle_exceeded?(name, person, settings)
      Rack::Attack.cache.count("per-user/#{name}/#{person.id}", settings[:period]).to_i > settings[:limit]
    end

    def retry_after_seconds(period)
      period - (Time.current.to_i % period)
    end
  end
end

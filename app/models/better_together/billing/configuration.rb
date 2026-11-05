# frozen_string_literal: true

module BetterTogether
  module Billing
    # Host-supplied billing identity and locale defaults. There are no
    # built-in fallbacks: until the host sets the required keys, billing
    # entry points stay closed instead of showing another organisation's
    # name, address, support email, currency or country.
    class Configuration
      # Raised when a feature needs a host-supplied value that is not set.
      class MissingConfigurationError < StandardError; end

      REQUIRED_KEYS = %w[PAY_BUSINESS_NAME PAY_BUSINESS_ADDRESS PAY_SUPPORT_EMAIL].freeze

      class << self
        def value(key, env = ENV)
          env[key.to_s].to_s.strip.presence
        end

        def missing_keys(env = ENV)
          REQUIRED_KEYS.reject { |key| value(key, env) }
        end

        def ready?(env = ENV)
          missing_keys(env).empty?
        end

        # Optional preselect for the plan form; nil means "make the admin choose".
        def default_currency(env = ENV)
          value('BT_BILLING_DEFAULT_CURRENCY', env)&.upcase
        end

        # Required by features that must send a country to the processor.
        def default_country(env = ENV)
          value('BT_BILLING_DEFAULT_COUNTRY', env)&.upcase
        end

        def require_default_country!(env = ENV)
          default_country(env) || raise(MissingConfigurationError, 'BT_BILLING_DEFAULT_COUNTRY is not set')
        end

        def log_missing!(logger = Rails.logger)
          missing = missing_keys
          return if missing.empty?

          logger.warn("[billing] disabled until configured; missing: #{missing.join(', ')}")
        end
      end
    end
  end
end

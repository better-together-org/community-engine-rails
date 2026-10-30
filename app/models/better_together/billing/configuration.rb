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

        # True when the host has switched billing on (BT_BILLING_ENABLED).
        def requested?(env = ENV)
          ActiveModel::Type::Boolean.new.cast(value('BT_BILLING_ENABLED', env)) == true
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

        # The processor context for `platform`, or nil when that platform has none.
        #
        # Today the only credentials are the host deployment's environment, which
        # belong to the host platform. Any other platform gets nil, so it cannot
        # use the host's processor account; billing is simply off for it until it
        # has configuration of its own.
        def context_for(platform, processor)
          return if platform.nil? || !platform.host?
          return unless Billing.processor_names.include?(processor.to_sym)

          ProcessorContext.new(platform:, processor:)
        end

        # Registered processors that have a context for `platform`.
        def processors_for(platform)
          Billing.processor_names.select { |name| context_for(platform, name) }
        end

        # Platforms that have a context for this processor (the host platform, today).
        def platforms_with_context(processor)
          BetterTogether::Platform.where(host: true).select { |platform| context_for(platform, processor) }
        end

        # Which platform a webhook is for, or nil when that cannot be told.
        #
        # An event may name its platform (`platform_id`) or the processor account it came
        # from (`account_ref`). Without either, it is attributed to the only platform that
        # has a context for the processor; if more than one does, that is ambiguous and
        # nothing is guessed. A platform without a context never receives events.
        def platform_for_webhook(processor, platform_id: nil, account_ref: nil)
          candidates = platforms_with_context(processor)
          candidates = candidates.select { |platform| platform.id.to_s == platform_id.to_s } if platform_id.present?
          candidates = match_account(candidates, processor, account_ref) if account_ref.present?
          candidates.one? ? candidates.first : nil
        end

        # Warns once at boot, and only for a host that asked for billing.
        def log_missing!(logger = Rails.logger, env = ENV)
          return unless requested?(env)

          missing = missing_keys(env)
          return if missing.empty?

          logger.warn("[billing] disabled until configured; missing: #{missing.join(', ')}")
        end

        private

        # Contexts that know their processor account must match it; contexts that do
        # not (account_ref nil) are only usable when they are the single candidate.
        def match_account(candidates, processor, account_ref)
          known = candidates.select { |platform| context_for(platform, processor).account_ref.present? }
          return candidates if known.empty?

          known.select { |platform| context_for(platform, processor).account_ref.to_s == account_ref.to_s }
        end
      end
    end
  end
end

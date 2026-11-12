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

        # PAY_SUPPORT_EMAIL falls back to DEFAULT_FROM_EMAIL (see config/initializers/pay.rb), so either one is enough.
        def missing_keys(env = ENV)
          REQUIRED_KEYS.reject { |key| value(key, env) || (key == 'PAY_SUPPORT_EMAIL' && value('DEFAULT_FROM_EMAIL', env)) }
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
        # A vendor processor's credentials are the host deployment's environment, which
        # belong to the host platform. Any other platform gets nil, so it cannot use the
        # host's processor account.
        #
        # A method outside a vendor (cash, cheque, e-transfer) has no credentials. It has a
        # context for a platform (or one of its sellers) only while a steward has it enabled
        # (see ProcessorSetting), so it is installed for everyone and on for no one by default.
        def context_for(platform, processor, seller: nil)
          return if platform.nil? || Billing.processor_names.map(&:to_s).exclude?(processor.to_s)

          if Billing.local_method?(processor)
            return unless HostedBilling.permits?(platform, :local)

            return setting_context(platform, processor, seller)
          end
          return unless platform.host?

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
        # nothing is guessed. A platform without a context never receives events, and an
        # event from a processor account no context names is refused.
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

        def setting_context(platform, processor, seller)
          settings = platform.billing_processor_settings.enabled.where(processor: processor.to_s)
          settings = seller ? settings.sold_by(seller) : settings.sold_by_platform
          ProcessorContext.new(platform:, processor:, source: :setting) if settings.exists?
        end

        # An event from a processor account (a Connect account) goes only to the platform whose
        # context names that account. A context that names no account is the platform's own,
        # whose events carry no account: it never receives another account's events, so an
        # unknown account is refused rather than guessed onto the host.
        def match_account(candidates, processor, account_ref)
          candidates.select { |platform| context_for(platform, processor).account_ref.to_s == account_ref.to_s }
        end
      end
    end
  end
end

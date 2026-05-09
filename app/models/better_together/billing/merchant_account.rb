# frozen_string_literal: true

module BetterTogether
  module Billing
    # Merchant integration record owned by a person or community.
    class MerchantAccount < ApplicationRecord
      self.table_name = 'better_together_billing_merchant_accounts'

      PROVIDERS = %w[stripe_connect paypal_multiparty].freeze
      SUPPORTED_OWNER_TYPES = %w[BetterTogether::Community BetterTogether::Person].freeze
      STATUSES = %w[pending onboarding required_action active restricted disabled errored disconnected].freeze

      belongs_to :owner,
                 polymorphic: true

      validates :owner, presence: true
      validates :provider, inclusion: { in: PROVIDERS }
      validates :provider, uniqueness: { scope: %i[owner_type owner_id] }
      validates :status, inclusion: { in: STATUSES }
      validates :owner_type, inclusion: { in: SUPPORTED_OWNER_TYPES }
      validates :external_account_id, uniqueness: { scope: :provider }, allow_blank: true
      validates :charges_enabled, :payouts_enabled, inclusion: { in: [true, false] }
      validates :currency, length: { is: 3 }, allow_blank: true
      validates :country, length: { is: 2 }, allow_blank: true

      scope :for_provider, ->(provider) { where(provider:) }
      scope :active, -> { where(status: 'active') }
      scope :charges_enabled, -> { where(charges_enabled: true) }
      scope :payouts_enabled, -> { where(payouts_enabled: true) }

      def self.onboarding_enabled?
        ActiveModel::Type::Boolean.new.cast(ENV.fetch('BT_BILLING_MERCHANT_ONBOARDING_ENABLED', 'false'))
      end

      def onboarding_enabled?
        self.class.onboarding_enabled?
      end

      def stripe_connect?
        provider == 'stripe_connect'
      end

      def paypal_multiparty?
        provider == 'paypal_multiparty'
      end

      def active?
        status == 'active'
      end

      def restricted?
        status == 'restricted'
      end

      def disabled?
        status == 'disabled'
      end

      def onboarding_incomplete?
        status.in?(%w[pending onboarding required_action])
      end

      def merchant_ready?
        active? && charges_enabled? && payouts_enabled?
      end

      # rubocop:disable Metrics/CyclomaticComplexity
      def support_state
        return :disconnected if status == 'disconnected'
        return :errored if status == 'errored'
        return :restricted if status == 'restricted'
        return :disabled if status == 'disabled'
        return :required_action if onboarding_incomplete?
        return :capability_gap if active? && !merchant_ready?

        nil
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      def support_attention_needed?
        support_state.present?
      end

      def deauthorized_at
        timestamp_from_metadata('deauthorized_at')
      end

      def last_webhook_event_at
        timestamp_from_metadata('last_webhook_event_at')
      end

      def stripe_connect_account_id
        external_account_id if stripe_connect?
      end

      private

      def timestamp_from_metadata(key)
        value = metadata.to_h[key]
        return if value.blank?

        Time.zone.parse(value)
      rescue ArgumentError
        nil
      end
    end
  end
end

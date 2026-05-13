# frozen_string_literal: true

module BetterTogether
  module Billing
    # CE extension record for a pay_subscription. Status, period, and
    # processor details live on Pay::Subscription; this record stores only
    # CE billing-plan linkage and operational metadata (portal errors, sync
    # tracking, etc.).
    class Subscription < ApplicationRecord
      self.table_name = 'better_together_billing_subscriptions'

      belongs_to :pay_subscription,
                 class_name: 'Pay::Subscription',
                 inverse_of: :billing_subscription_record

      belongs_to :billing_plan,
                 class_name: 'BetterTogether::Billing::Plan',
                 inverse_of: :subscriptions

      has_many :billing_events,
               class_name: 'BetterTogether::Billing::Event',
               foreign_key: :billing_subscription_id,
               dependent: :nullify,
               inverse_of: :billing_subscription

      validates :pay_subscription, :billing_plan, presence: true

      # Delegate subscription state to pay so we can use pay's helpers.
      delegate :status, :current_period_start, :current_period_end,
               :cancel_at_period_end, :processor_id, :trial_ends_at,
               :ends_at, to: :pay_subscription, allow_nil: true

      # Pay::Subscription has no #processor instance method; processor lives
      # on the associated customer record.
      def processor
        pay_subscription&.customer&.processor
      end

      scope :activeish, lambda {
        joins(:pay_subscription).where(pay_subscriptions: { status: %w[trialing active past_due] })
      }

      def activeish?
        status.in?(%w[trialing active past_due])
      end

      def last_synced_recently?(threshold: 15.minutes.ago)
        last_synced_at.present? && last_synced_at >= threshold
      end

      def portal_access_issue?
        last_portal_error_at.present?
      end

      def last_portal_error_at
        timestamp_from_metadata('last_portal_error_at')
      end

      def last_portal_error_message
        metadata.to_h['last_portal_error_message']
      end

      def record_portal_access_failure!(message:)
        update!(metadata: metadata.to_h.merge(
          'last_portal_error_at' => Time.current.iso8601,
          'last_portal_error_message' => message
        ))
      end

      def clear_portal_access_failure!
        return unless portal_access_issue?

        update!(metadata: metadata.to_h.except('last_portal_error_at', 'last_portal_error_message'))
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

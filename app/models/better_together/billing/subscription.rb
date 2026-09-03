# frozen_string_literal: true

module BetterTogether
  module Billing
    # CE extension record for a pay_subscription. Status, period, and
    # processor details live on Pay::Subscription; this record stores only
    # CE billing-plan linkage and operational metadata (portal errors, sync
    # tracking, etc.).
    class Subscription < ApplicationRecord # rubocop:disable Metrics/ClassLength
      self.table_name = 'better_together_billing_subscriptions'

      belongs_to :pay_subscription,
                 class_name: 'Pay::Subscription',
                 autosave: true,
                 inverse_of: :billing_subscription_record

      belongs_to :billing_plan,
                 class_name: 'BetterTogether::Billing::Plan',
                 inverse_of: :subscriptions

      has_many :billing_events,
               class_name: 'BetterTogether::Billing::Event',
               foreign_key: :billing_subscription_id,
               dependent: :nullify,
               inverse_of: :billing_subscription

      before_validation :apply_virtual_billing_participants

      validates :pay_subscription, :billing_plan, presence: true

      # Delegate subscription state to pay so we can use pay's helpers.
      delegate :status, :status=, :current_period_start, :current_period_end,
               :processor_id, :trial_ends_at,
               :ends_at, to: :pay_subscription, allow_nil: true

      # Pay::Subscription has no #processor instance method; processor lives
      # on the associated customer record.
      def processor
        pay_subscription&.customer&.processor
      end

      scope :activeish, lambda {
        joins(:pay_subscription).where(pay_subscriptions: { status: %w[trialing active past_due] })
      }

      # Candidates for grace-period notification — anything ever marked
      # lapsed, whether or not it has since recovered or the grace period
      # has already expired. Cheap jsonb key-existence filter; the caller
      # narrows further via #in_grace_period?/#grace_notice_sent?.
      scope :possibly_lapsed, lambda {
        # rubocop:disable BetterTogether/NoRawSqlInQueries -- PostgreSQL JSONB ? key-existence operator has no Arel equivalent
        where(Arel.sql("metadata ? 'lapsed_at'"))
        # rubocop:enable BetterTogether/NoRawSqlInQueries
      }

      class << self
        def current_for_owner(owner)
          current_from_scope(for_owner(owner))
        end

        def for_owner(owner)
          joins(:pay_subscription)
            .where(pay_subscriptions: { customer_id: owner.pay_customers.select(:id) })
        end

        private

        # rubocop:disable Metrics/AbcSize
        def current_from_scope(scope)
          pay_subscriptions = Pay::Subscription.arel_table
          status_priority = Arel::Nodes::Case.new(pay_subscriptions[:status])
                                             .when('active').then(3)
                                             .when('trialing').then(2)
                                             .when('past_due').then(1)
                                             .else(0)
          current_reference = Arel::Nodes::NamedFunction.new(
            'COALESCE',
            [pay_subscriptions[:current_period_start], pay_subscriptions[:created_at]]
          )

          scope.includes(:billing_plan, :pay_subscription)
               .order(status_priority.desc, current_reference.desc, pay_subscriptions[:created_at].desc)
               .first
        end
        # rubocop:enable Metrics/AbcSize
      end

      def activeish?
        status.in?(%w[trialing active past_due])
      end

      # Whether this subscription currently grants access — activeish
      # (including Stripe's own past_due dunning window) OR still within
      # the app-owned grace period after a genuine lapse. Shared by
      # HostedEntitlementResolver and Billing::EntitlementGrantSync so
      # both agree on the same access boundary.
      def access_active?
        activeish? || in_grace_period?
      end

      def cancel_at_period_end
        pay_subscription&.attributes&.[]('cancel_at_period_end') || false
      end

      def cancel_at_period_end?
        cancel_at_period_end
      end

      def billable_owner
        pay_subscription&.customer&.owner
      end

      def billable_owner=(record)
        return if record.blank?

        @pending_billable_owner = record
        assign_billable_owner_customer(record)
      end

      # A subscription's owner is always its own Pay::Customer's owner — under
      # the sponsorship redesign, sponsoring never swaps who owns a
      # subscription (that ownership-swap mechanism was the double-billing
      # bug). Sponsors fund a beneficiary's own Stripe Customer Balance
      # instead (see Billing::Sponsorship/CreditBeneficiaryBalance). Kept as
      # an alias, not removed outright, since callers throughout the app
      # already read #beneficiary to mean "who this subscription is for."
      alias beneficiary billable_owner

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

      # App-owned grace period. Stripe's own dunning/retry cycle is already
      # covered by #activeish? including 'past_due' — this is the second,
      # BTS-owned buffer that applies once Stripe's retries are exhausted
      # and the subscription has genuinely lapsed, giving a beneficiary time
      # to notice and fix billing before hosted access is actually cut.
      def self.grace_period
        ActiveSupport::Duration.days(
          ENV.fetch('BT_BILLING_HOSTED_ACCESS_GRACE_PERIOD_DAYS', 7).to_i
        )
      end

      def lapsed_at
        timestamp_from_metadata('lapsed_at')
      end

      def grace_period_expires_at
        return if lapsed_at.blank?

        lapsed_at + self.class.grace_period
      end

      def in_grace_period?
        grace_period_expires_at.present? && grace_period_expires_at.future?
      end

      def grace_period_expired?
        grace_period_expires_at.present? && !grace_period_expires_at.future?
      end

      def grace_notice_sent?
        metadata.to_h['grace_notice_sent_at'].present?
      end

      def record_grace_notice_sent!
        update!(metadata: metadata.to_h.merge('grace_notice_sent_at' => Time.current.iso8601))
      end

      # Called after every subscription sync (webhook-driven status change)
      # to track when this subscription first left the activeish state, and
      # to clear that marker if it recovers. Idempotent — does not reset the
      # grace-period clock on repeated syncs while still lapsed.
      def sync_lapse_state!
        activeish? ? clear_lapse! : record_lapse!
      end

      def status_badge_class
        case status
        when 'active', 'trialing'
          'text-bg-success'
        when 'past_due', 'unpaid'
          'text-bg-warning'
        when 'canceled', 'incomplete_expired'
          'text-bg-danger'
        else # 'incomplete', 'paused'
          'text-bg-secondary'
        end
      end

      private

      def record_lapse!
        return if lapsed_at.present?

        update!(metadata: metadata.to_h.merge('lapsed_at' => Time.current.iso8601))
      end

      def clear_lapse!
        return if lapsed_at.blank? && !grace_notice_sent?

        update!(metadata: metadata.to_h.except('lapsed_at', 'grace_notice_sent_at'))
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def assign_billable_owner_customer(record)
        customer = Pay::Customer.find_or_create_by!(
          owner: record,
          processor: 'stripe'
        ) do |pay_customer|
          pay_customer.processor_id = "cus_local_#{record.class.name.demodulize.underscore}_#{record.id}"
        end

        self.pay_subscription ||= Pay::Subscription.new(
          name: 'default',
          processor_id: "sub_local_#{SecureRandom.hex(8)}",
          processor_plan: billing_plan&.stripe_price_id || 'price_local_placeholder',
          quantity: 1,
          status: 'active',
          current_period_start: Time.current.beginning_of_day,
          current_period_end: 1.month.from_now.beginning_of_day
        )
        pay_subscription.customer = customer
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      def apply_virtual_billing_participants
        assign_billable_owner_customer(@pending_billable_owner) if @pending_billable_owner.present?
      end

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

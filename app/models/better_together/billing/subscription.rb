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

      class << self
        def current_for_owner(owner)
          current_from_scope(for_owner(owner))
        end

        def current_for_beneficiary(record)
          current_from_scope(for_owner_or_beneficiary(record))
        end

        def for_owner(owner)
          joins(:pay_subscription)
            .where(pay_subscriptions: { customer_id: owner.pay_customers.select(:id) })
        end

        def for_owner_or_beneficiary(record)
          where(id: for_owner(record).select(:id))
            .or(for_beneficiary(record))
        end

        # rubocop:disable BetterTogether/NoRawSqlInQueries
        def for_beneficiary(record)
          where('better_together_billing_subscriptions.metadata @> ?', beneficiary_metadata(record).to_json)
        end
        # rubocop:enable BetterTogether/NoRawSqlInQueries

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

        def beneficiary_metadata(record)
          {
            'bt_beneficiary_type' => record.class.name,
            'bt_beneficiary_id' => record.id
          }
        end
      end

      def activeish?
        status.in?(%w[trialing active past_due])
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

      def beneficiary
        BetterTogether::Billing::OwnershipResolver.resolve_record(
          metadata.to_h['bt_beneficiary_type'],
          metadata.to_h['bt_beneficiary_id']
        ) || billable_owner
      end

      def beneficiary=(record)
        @pending_beneficiary = record
        merge_beneficiary_metadata(record)
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

      def merge_beneficiary_metadata(record)
        merged_metadata = metadata.to_h
        if record.present?
          merged_metadata['bt_beneficiary_type'] = record.class.name
          merged_metadata['bt_beneficiary_id'] = record.id
        else
          merged_metadata.except!('bt_beneficiary_type', 'bt_beneficiary_id')
        end

        self.metadata = merged_metadata
      end

      def apply_virtual_billing_participants
        assign_billable_owner_customer(@pending_billable_owner) if @pending_billable_owner.present?
        merge_beneficiary_metadata(@pending_beneficiary) if defined?(@pending_beneficiary)
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

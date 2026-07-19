# frozen_string_literal: true

module BetterTogether
  module Billing
    # Synchronizes Stripe Checkout completion into the local CE billing state.
    # Owner resolution is implicit: pay matches the Stripe customer to the
    # pay_customer record and its owner (Person or Community).
    class StripeCheckoutSessionSync # rubocop:disable Metrics/ClassLength
      Result = Struct.new(
        :synced,
        :billing_subscription,
        :billing_plan,
        :checkout_session,
        :billable_owner,
        :beneficiary,
        :reason,
        keyword_init: true
      )

      # rubocop:disable Metrics/MethodLength
      def call(checkout_session_id:, billable_owner: nil, beneficiary: nil, **)
        checkout_session = fetch_checkout_session(checkout_session_id)
        subscription = fetch_subscription(checkout_session)

        return Result.new(checkout_session:, synced: false, reason: :no_subscription) unless subscription
        if ownership_mismatch?(
          subscription:,
          checkout_session:,
          expected_billable_owner: billable_owner,
          expected_beneficiary: beneficiary
        )
          return ownership_mismatch_result(
            checkout_session,
            subscription,
            expected_billable_owner: billable_owner,
            expected_beneficiary: beneficiary
          )
        end

        build_result(
          subscription_sync.call(
            subscription:,
            source: 'checkout_return',
            checkout_session_id: checkout_session.id
          ),
          checkout_session
        )
      end
      # rubocop:enable Metrics/MethodLength

      private

      def fetch_checkout_session(checkout_session_id)
        Stripe::Checkout::Session.retrieve(
          {
            id: checkout_session_id,
            expand: %w[subscription customer line_items.data.price]
          }
        )
      end

      def fetch_subscription(checkout_session)
        return unless checkout_session.respond_to?(:subscription)

        subscription = checkout_session.subscription
        return if subscription.blank?
        return subscription unless subscription.is_a?(String)

        Stripe::Subscription.retrieve(
          {
            id: subscription,
            expand: ['items.data.price']
          }
        )
      end

      def subscription_sync
        @subscription_sync ||= BetterTogether::Billing::StripeSubscriptionSync.new
      end

      def ownership_mismatch?(subscription:, checkout_session:, expected_billable_owner:, expected_beneficiary:)
        return false if expected_billable_owner.blank? && expected_beneficiary.blank?

        actual_billable_owner = resolved_billable_owner(subscription:, checkout_session:)
        actual_beneficiary = resolved_beneficiary(subscription:, checkout_session:)

        owner_mismatch = expected_billable_owner.present? && actual_billable_owner != expected_billable_owner
        beneficiary_mismatch = expected_beneficiary.present? && actual_beneficiary != expected_beneficiary

        owner_mismatch || beneficiary_mismatch
      end

      def ownership_mismatch_result(checkout_session, subscription, expected_billable_owner:, expected_beneficiary:)
        actual_billable_owner = resolved_billable_owner(subscription:, checkout_session:)
        actual_beneficiary = resolved_beneficiary(subscription:, checkout_session:)

        Result.new(
          synced: false,
          checkout_session:,
          billable_owner: actual_billable_owner,
          beneficiary: actual_beneficiary,
          reason: mismatch_reason(
            actual_billable_owner:,
            actual_beneficiary:,
            expected_billable_owner:,
            expected_beneficiary:
          )
        )
      end

      def mismatch_reason(actual_billable_owner:, actual_beneficiary:, expected_billable_owner:, expected_beneficiary:)
        return :beneficiary_mismatch if expected_beneficiary.present? && actual_beneficiary != expected_beneficiary
        return :billable_owner_mismatch if expected_billable_owner.present? && actual_billable_owner != expected_billable_owner

        :ownership_mismatch
      end

      def resolved_billable_owner(subscription:, checkout_session:)
        metadata = merged_metadata(subscription:, checkout_session:)
        fallback_owner = pay_customer_owner_for(subscription.customer) || pay_customer_owner_for(checkout_session.customer)

        BetterTogether::Billing::OwnershipResolver.resolve_billable_owner(metadata:, fallback_owner:)
      end

      def resolved_beneficiary(subscription:, checkout_session:)
        metadata = merged_metadata(subscription:, checkout_session:)

        BetterTogether::Billing::OwnershipResolver.resolve_record(
          metadata['bt_beneficiary_type'],
          metadata['bt_beneficiary_id']
        ) || BetterTogether::Billing::OwnershipResolver.resolve_record(
          'BetterTogether::Community',
          metadata['bt_community_id']
        )
      end

      def merged_metadata(subscription:, checkout_session:)
        object_metadata(checkout_session).merge(object_metadata(subscription))
      end

      def object_metadata(object)
        return {} unless object.respond_to?(:metadata)

        object.metadata.to_h
      end

      def pay_customer_owner_for(customer_reference)
        customer_id = customer_reference.respond_to?(:id) ? customer_reference.id : customer_reference
        return if customer_id.blank?

        Pay::Customer.find_by(processor: 'stripe', processor_id: customer_id)&.owner
      end

      def build_result(sync_result, checkout_session)
        Result.new(
          synced: sync_result.synced,
          billing_subscription: sync_result.billing_subscription,
          billing_plan: sync_result.billing_plan,
          checkout_session:,
          billable_owner: sync_result.billing_subscription&.billable_owner,
          beneficiary: sync_result.billing_subscription&.beneficiary,
          reason: sync_result.reason
        )
      end
    end
  end
end

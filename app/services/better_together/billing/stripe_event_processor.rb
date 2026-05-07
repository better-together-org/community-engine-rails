# frozen_string_literal: true

module BetterTogether
  module Billing
    # Persists Stripe webhook events and syncs subscription state into BTS billing tables.
    # rubocop:disable Metrics/ClassLength
    class StripeEventProcessor
      def call(event)
        sync_result = sync_result_for(event)
        community = sync_result&.community || resolve_community(event)
        persist_success(event, sync_result, community)
      rescue StandardError => e
        persist_failure(event, e)
        raise
      end

      private

      def sync_result_for(event)
        return sync_subscription_event(event) if subscription_event?(event)
        return sync_checkout_session_event(event) if checkout_session_event?(event)

        nil
      end

      def sync_subscription_event(event)
        community = resolve_community(event)
        return unless community

        subscription_sync.call(
          subscription: event.data.object,
          community:,
          source: 'stripe_webhook',
          event:
        )
      end

      def sync_checkout_session_event(event)
        checkout_session_sync.call(
          checkout_session_id: event.data.object.id
        )
      end

      def subscription_event?(event)
        event.type.start_with?('customer.subscription.')
      end

      def checkout_session_event?(event)
        event.type == 'checkout.session.completed'
      end

      def processing_status_for(event, sync_result)
        return 'ignored' unless relevant_event?(event)
        return 'processed' if sync_result&.synced

        'ignored'
      end

      def persist_success(event, sync_result, community)
        billing_event = billing_event_for(event)
        billing_event.assign_attributes(
          event_success_attributes(billing_event, event, sync_result, community)
        )
        billing_event.save!
      end

      def billing_event_for(event)
        BetterTogether::Billing::Event.find_or_initialize_by(
          processor: 'stripe',
          event_id: event.id
        )
      end

      def persist_failure(event, error)
        billing_event = billing_event_for(event)
        billing_event.assign_attributes(
          event_failure_attributes(billing_event, event, error)
        )
        billing_event.save!
      rescue StandardError
        nil
      end

      def resolve_community(event)
        data_object = event.data.object
        metadata = object_metadata(data_object)

        BetterTogether::Community.find_by(id: metadata['bt_community_id']) ||
          pay_customer_for(data_object)&.owner
      end

      def pay_customer_for(data_object)
        customer_id = if data_object.respond_to?(:customer)
                        data_object.customer
                      elsif data_object.respond_to?(:object) && data_object.object.respond_to?(:customer)
                        data_object.object.customer
                      end
        customer_id = customer_id.id if customer_id.respond_to?(:id)
        return if customer_id.blank?

        Pay::Customer.find_by(processor: 'stripe', processor_id: customer_id)
      end

      def object_metadata(data_object)
        return {} unless data_object.respond_to?(:metadata)

        data_object.metadata.to_h
      end

      def relevant_event?(event)
        subscription_event?(event) || checkout_session_event?(event)
      end

      def event_success_attributes(billing_event, event, sync_result, community)
        base_event_attributes(billing_event, event).merge(
          community: community,
          billing_subscription: sync_result&.billing_subscription,
          processing_status: processing_status_for(event, sync_result),
          error_message: nil
        )
      end

      def event_failure_attributes(billing_event, event, error)
        base_event_attributes(billing_event, event).merge(
          processing_status: 'failed',
          error_message: error.message
        )
      end

      def base_event_attributes(billing_event, event)
        {
          event_type: event.type,
          payload: event.to_hash,
          first_received_at: billing_event.first_received_at || Time.current,
          last_attempted_at: Time.current,
          attempt_count: billing_event.attempt_count.to_i + 1,
          processed_at: Time.current
        }
      end

      def subscription_sync
        @subscription_sync ||= BetterTogether::Billing::StripeSubscriptionSync.new
      end

      def checkout_session_sync
        @checkout_session_sync ||= BetterTogether::Billing::StripeCheckoutSessionSync.new
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end

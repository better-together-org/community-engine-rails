# frozen_string_literal: true

module BetterTogether
  module Billing
    # Persists Stripe webhook events and syncs subscription state into BTS billing tables.
    # rubocop:disable Metrics/ClassLength
    class StripeEventProcessor
      MerchantSyncResult = Struct.new(:merchant_account, keyword_init: true)

      def call(event)
        sync_result = sync_result_for(event)
        billable_owner = billable_owner_for(sync_result, event)
        beneficiary = beneficiary_for(sync_result, event, billable_owner:)
        persist_success(event, sync_result, billable_owner, beneficiary)
      rescue StandardError => e
        persist_failure(event, e)
        raise
      end

      private

      def sync_result_for(event)
        return sync_subscription_event(event) if subscription_event?(event)
        return sync_checkout_session_event(event) if checkout_session_event?(event)
        return sync_merchant_event(event) if merchant_event?(event)
        return sync_financial_event(event) if financial_event?(event)

        nil
      end

      def sync_subscription_event(event)
        billable_owner = resolve_billable_owner(event)
        return unless billable_owner

        beneficiary = resolve_beneficiary(event, billable_owner:)
        return unless beneficiary

        subscription_sync.call(
          subscription: event.data.object,
          billable_owner:,
          beneficiary:,
          source: 'stripe_webhook',
          event:
        )
      end

      def sync_checkout_session_event(event)
        checkout_session_sync.call(
          checkout_session_id: event.data.object.id
        )
      end

      def sync_merchant_event(event)
        merchant_account = merchant_account_for(event)
        return if merchant_account.blank?

        return disconnect_merchant_account(merchant_account, event) if merchant_deauthorized_event?(event)

        merchant_account_sync.call(merchant_account:, stripe_account: event.data.object).tap do |result|
          annotate_merchant_account!(result.merchant_account, event)
        end
      end

      def subscription_event?(event)
        event.type.start_with?('customer.subscription.')
      end

      def checkout_session_event?(event)
        event.type == 'checkout.session.completed'
      end

      def merchant_event?(event)
        event.type.in?(%w[account.updated account.application.deauthorized])
      end

      def financial_event?(event)
        event.type.in?(BetterTogether::Billing::StripeFinancialEventSync::EVENT_TYPES)
      end

      def merchant_deauthorized_event?(event)
        event.type == 'account.application.deauthorized'
      end

      def processing_status_for(event, sync_result)
        explicit_processing_status = sync_result.try(:processing_status)
        return explicit_processing_status if explicit_processing_status.present?
        return 'ignored' unless relevant_event?(event)
        return 'processed' if processed_sync_result?(event, sync_result)

        'ignored'
      end

      def persist_success(event, sync_result, billable_owner, beneficiary)
        billing_event = billing_event_for(event)
        billing_event.assign_attributes(
          event_success_attributes(billing_event, event, sync_result, billable_owner, beneficiary)
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

      def resolve_billable_owner(event)
        data_object = event.data.object
        metadata = object_metadata(data_object)

        OwnershipResolver.resolve_billable_owner(
          metadata:,
          fallback_owner: pay_customer_for(data_object)&.owner
        )
      end

      def resolve_beneficiary(event, billable_owner:)
        OwnershipResolver.resolve_beneficiary(
          metadata: object_metadata(event.data.object),
          billable_owner:
        )
      end

      def sync_financial_event(event)
        financial_event_sync.call(event:)
      end

      def billable_owner_for(sync_result, event)
        merchant_owner_for(sync_result) || sync_result&.billable_owner || resolve_billable_owner(event)
      end

      def beneficiary_for(sync_result, event, billable_owner:)
        merchant_owner_for(sync_result) || sync_result&.beneficiary || resolve_beneficiary(event, billable_owner:)
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
        subscription_event?(event) || checkout_session_event?(event) || merchant_event?(event) || financial_event?(event)
      end

      def processed_sync_result?(event, sync_result)
        return sync_result.present? if merchant_event?(event)
        return sync_result&.synced if financial_event?(event)

        sync_result&.synced
      end

      def merchant_owner_for(sync_result)
        sync_result.try(:merchant_account)&.owner
      end

      def event_success_attributes(billing_event, event, sync_result, billable_owner, beneficiary)
        base_event_attributes(billing_event, event).merge(
          billable_owner:,
          beneficiary:,
          billing_subscription: sync_result.try(:billing_subscription),
          processing_status: processing_status_for(event, sync_result),
          error_message: sync_result.try(:error_message)
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
          payload_redacted_at: billing_event.payload_redacted_at,
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

      def merchant_account_sync
        @merchant_account_sync ||= BetterTogether::Billing::MerchantAccounts::StripeConnect::SyncAccount.new
      end

      def financial_event_sync
        @financial_event_sync ||= BetterTogether::Billing::StripeFinancialEventSync.new
      end

      def merchant_account_for(event)
        BetterTogether::Billing::MerchantAccount.find_by(
          provider: 'stripe_connect',
          external_account_id: merchant_account_id_from(event)
        )
      end

      def merchant_account_id_from(event)
        event.data.object.try(:id).presence || event.try(:account).presence
      end

      def annotate_merchant_account!(merchant_account, event)
        merchant_account.update!(
          metadata: merchant_account.metadata.merge(
            'last_webhook_event_id' => event.id,
            'last_webhook_event_type' => event.type
          )
        )
      end

      def disconnect_merchant_account(merchant_account, event)
        merchant_account.update!(
          status: 'disconnected',
          charges_enabled: false,
          payouts_enabled: false,
          last_synced_at: Time.current,
          metadata: merchant_account.metadata.merge(
            'deauthorized_at' => Time.current.iso8601,
            'last_webhook_event_id' => event.id,
            'last_webhook_event_type' => event.type
          )
        )

        MerchantSyncResult.new(merchant_account:)
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end

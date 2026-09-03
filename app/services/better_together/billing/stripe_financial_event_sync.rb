# frozen_string_literal: true

module BetterTogether
  module Billing
    # Resolves Stripe invoice/charge lifecycle events onto local billing records.
    # rubocop:disable Metrics/ClassLength
    class StripeFinancialEventSync
      ALERT_EVENT_TYPES = %w[
        invoice.payment_failed
        invoice.payment_action_required
        invoice.marked_uncollectible
        charge.dispute.created
        charge.dispute.funds_withdrawn
      ].freeze

      EVENT_TYPES = (
        ALERT_EVENT_TYPES + %w[
          invoice.finalized
          invoice.paid
          invoice.payment_succeeded
          charge.dispute.closed
          charge.refunded
        ]
      ).freeze

      ALERT_MESSAGES = {
        'invoice.payment_failed' => 'Stripe reported that an invoice payment failed.',
        'invoice.payment_action_required' => 'Stripe requires customer action before the invoice can be paid.',
        'invoice.marked_uncollectible' => 'Stripe marked the invoice as uncollectible.',
        'charge.dispute.created' => 'Stripe opened a dispute for a related charge.',
        'charge.dispute.funds_withdrawn' => 'Stripe withdrew disputed funds for a related charge.'
      }.freeze

      Result = Struct.new(
        :synced,
        :billable_owner,
        :billing_subscription,
        :processing_status,
        :error_message,
        :reason,
        keyword_init: true
      )

      # rubocop:disable Metrics/CyclomaticComplexity
      def call(event:)
        billing_subscription = resolve_billing_subscription(event)
        synchronize_billing_subscription!(billing_subscription, event) if billing_subscription.present?

        billable_owner = billing_subscription&.pay_subscription&.owner || resolve_billable_owner(event)
        context_present = billable_owner.present? || billing_subscription.present?

        Result.new(
          synced: context_present,
          billable_owner:,
          billing_subscription:,
          processing_status: processing_status_for(event, context_present:),
          error_message: error_message_for(event, context_present:),
          reason: context_present ? :synced : :billing_record_not_found
        )
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      private

      def resolve_billing_subscription(event)
        subscription_id = subscription_id_from(event_object(event))
        return billing_subscription_for_processor_id(subscription_id) if subscription_id.present?

        charge_id = charge_id_from(event_object(event))
        return billing_subscription_for_charge(charge_id) if charge_id.present?

        customer_id = customer_id_from(event_object(event))
        return if customer_id.blank?

        billing_subscription_for_customer(customer_id)
      end

      def billing_subscription_for_processor_id(subscription_id)
        Pay::Subscription.stripe.find_by(processor_id: subscription_id)
                         &.billing_subscription_record
      end

      def billing_subscription_for_charge(charge_id)
        pay_charge = Pay::Charge.includes(:subscription, :customer).find_by(processor_id: charge_id)
        pay_subscription_id = pay_charge&.subscription&.processor_id
        return billing_subscription_for_processor_id(pay_subscription_id) if pay_subscription_id.present?

        billing_subscription_for_customer(pay_charge&.customer&.processor_id)
      end

      def billing_subscription_for_customer(customer_id)
        return if customer_id.blank?

        pay_customer = Pay::Customer.find_by(processor: 'stripe', processor_id: customer_id)
        return unless pay_customer

        bt_subs = pay_customer.subscriptions
                              .includes(:billing_subscription_record)
                              .filter_map(&:billing_subscription_record)
        return bt_subs.first if bt_subs.one?

        bt_subs.max_by(&:updated_at)
      end

      def resolve_billable_owner(event)
        data_object = event_object(event)

        OwnershipResolver.resolve_billable_owner(
          metadata: object_metadata(data_object),
          fallback_owner: pay_customer_for(data_object)&.owner
        )
      end

      def pay_customer_for(data_object)
        customer_id = customer_id_from(data_object)
        return if customer_id.blank?

        Pay::Customer.find_by(processor: 'stripe', processor_id: customer_id)
      end

      def synchronize_billing_subscription!(billing_subscription, event)
        billing_subscription.update!(
          last_synced_at: Time.current,
          sync_source: 'stripe_financial_event',
          latest_processor_event_id: event.id,
          metadata: billing_subscription.metadata.to_h.merge(financial_metadata(event))
        )
      end

      # rubocop:disable Metrics/AbcSize
      def financial_metadata(event)
        data_object = event_object(event)
        metadata = {
          'last_financial_event_id' => event.id,
          'last_financial_event_type' => event.type
        }

        invoice_id = invoice_id_from(data_object)
        metadata['last_invoice_id'] = invoice_id if invoice_id.present?

        invoice_status = extract_value(data_object, :status)
        metadata['last_invoice_status'] = invoice_status if invoice_status.present?

        charge_id = charge_id_from(data_object)
        metadata['last_charge_id'] = charge_id if charge_id.present?

        dispute_reason = extract_value(data_object, :reason)
        metadata['last_dispute_reason'] = dispute_reason if dispute_reason.present?
        metadata
      end
      # rubocop:enable Metrics/AbcSize

      def processing_status_for(event, context_present:)
        return 'ignored' unless context_present

        ALERT_EVENT_TYPES.include?(event.type) ? 'failed' : 'processed'
      end

      def error_message_for(event, context_present:)
        return unless context_present
        return unless ALERT_EVENT_TYPES.include?(event.type)

        base_message = ALERT_MESSAGES.fetch(event.type)
        detail_message = financial_detail_message(event_object(event))
        return base_message if detail_message.blank?

        "#{base_message} #{detail_message}"
      end

      def financial_detail_message(data_object)
        payment_error = extract_value(data_object, :last_payment_error)
        return extract_value(payment_error, :message) if extract_value(payment_error, :message).present?
        return extract_value(data_object, :failure_message) if extract_value(data_object, :failure_message).present?

        dispute_reason = extract_value(data_object, :reason)
        return "Reason: #{dispute_reason}." if dispute_reason.present?

        nil
      end

      def event_object(event)
        event.data.object
      end

      def object_metadata(data_object)
        metadata = extract_value(data_object, :metadata)
        metadata.respond_to?(:to_h) ? metadata.to_h : {}
      end

      def subscription_id_from(data_object)
        nested_ids = [
          extract_id(extract_value(data_object, :subscription)),
          extract_id(extract_value(extract_value(data_object, :invoice), :subscription))
        ]

        nested_ids.compact.first
      end

      def invoice_id_from(data_object)
        return extract_id(data_object) if invoice_event_object?(data_object)

        extract_id(extract_value(data_object, :invoice))
      end

      def invoice_event_object?(data_object)
        extract_value(data_object, :object) == 'invoice'
      end

      def customer_id_from(data_object)
        [
          extract_id(extract_value(data_object, :customer)),
          extract_id(extract_value(extract_value(data_object, :invoice), :customer)),
          customer_id_for_charge(charge_id_from(data_object))
        ].compact.first
      end

      def customer_id_for_charge(charge_id)
        return if charge_id.blank?

        Pay::Charge.includes(:customer).find_by(processor_id: charge_id)&.customer&.processor_id
      end

      def charge_id_from(data_object)
        extract_id(extract_value(data_object, :charge))
      end

      def extract_value(object, key)
        return if object.nil?
        return object.public_send(key) if object.respond_to?(key)

        if object.respond_to?(:[])
          object[key.to_s] || object[key.to_sym]
        end
      rescue StandardError
        nil
      end

      def extract_id(object)
        return if object.nil?
        return object.id if object.respond_to?(:id)
        return object if object.is_a?(String)

        extract_value(object, :id)
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end

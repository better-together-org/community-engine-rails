# frozen_string_literal: true

module BetterTogether
  module Billing
    # Retains only the Stripe event fields CE needs for audit and repair after
    # the raw payload retention window expires.
    # rubocop:disable Metrics/ClassLength
    class StripeEventPayloadSanitizer
      ROOT_KEYS = %w[
        id
        object
        type
        account
        api_version
        created
        livemode
        pending_webhooks
        request
        data
      ].freeze
      REQUEST_KEYS = %w[id idempotency_key].freeze
      EVENT_DATA_KEYS = %w[object previous_attributes].freeze
      OBJECT_KEYS = {
        'subscription' => %w[
          id
          object
          customer
          status
          metadata
          current_period_start
          current_period_end
          cancel_at_period_end
          items
          latest_invoice
        ].freeze,
        'checkout.session' => %w[
          id
          object
          customer
          subscription
          mode
          payment_status
          status
          metadata
          amount_subtotal
          amount_total
          currency
        ].freeze,
        'account' => %w[
          id
          object
          metadata
          country
          default_currency
          business_type
          charges_enabled
          payouts_enabled
          details_submitted
          capabilities
          requirements
        ].freeze,
        'invoice' => %w[
          id
          object
          customer
          subscription
          status
          metadata
          amount_due
          amount_paid
          amount_remaining
          currency
          collection_method
        ].freeze
      }.freeze

      def call(payload)
        payload_hash = normalize_hash(payload)
        payload_hash.slice(*ROOT_KEYS).compact.tap do |sanitized|
          sanitized['request'] = sanitize_request(payload_hash['request'])
          sanitized['data'] = sanitize_data(payload_hash['data'])
          sanitized['bt_payload_redacted'] = true
          sanitized['bt_payload_redaction_version'] = 1
        end
      end

      private

      def normalize_hash(value)
        case value
        when Hash
          value.deep_stringify_keys
        else
          {}
        end
      end

      def sanitize_request(request_payload)
        normalize_hash(request_payload).slice(*REQUEST_KEYS).compact
      end

      def sanitize_data(data_payload)
        normalize_hash(data_payload).slice(*EVENT_DATA_KEYS).compact.tap do |data|
          data['object'] = sanitize_object(data['object'])
          data['previous_attributes'] = sanitize_previous_attributes(data['previous_attributes'])
        end
      end

      def sanitize_object(object_payload)
        object_hash = normalize_hash(object_payload)
        object_type = object_hash['object']
        permitted_keys = OBJECT_KEYS.fetch(object_type, %w[id object metadata])

        object_hash.slice(*permitted_keys).compact.tap do |sanitized|
          sanitized['items'] = sanitize_items(sanitized['items'])
          sanitized['requirements'] = sanitize_requirements(sanitized['requirements'])
          sanitized['capabilities'] = sanitize_capabilities(sanitized['capabilities'])
        end
      end

      def sanitize_previous_attributes(previous_attributes_payload)
        previous_attributes = normalize_hash(previous_attributes_payload)
        return {} if previous_attributes.blank?

        previous_attributes.slice(
          'status',
          'charges_enabled',
          'payouts_enabled',
          'details_submitted',
          'current_period_end',
          'cancel_at_period_end'
        ).compact
      end

      def sanitize_items(items_payload)
        items_hash = normalize_hash(items_payload)
        data_rows = Array(items_hash['data']).filter_map do |item|
          item_hash = normalize_hash(item)
          next if item_hash.blank?

          {
            'id' => item_hash['id'],
            'object' => item_hash['object'],
            'price' => normalize_hash(item_hash['price']).slice('id', 'object')
          }.compact
        end

        return items_payload unless items_hash.present?

        { 'object' => items_hash['object'], 'data' => data_rows }.compact
      end

      def sanitize_requirements(requirements_payload)
        normalize_hash(requirements_payload).slice(
          'currently_due',
          'eventually_due',
          'past_due',
          'pending_verification',
          'disabled_reason'
        ).compact
      end

      def sanitize_capabilities(capabilities_payload)
        normalize_hash(capabilities_payload)
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end

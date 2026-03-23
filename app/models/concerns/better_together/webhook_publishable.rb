# frozen_string_literal: true

module BetterTogether
  # Concern for publishing webhook events when models are created, updated, or destroyed.
  #
  # Include in any model that should trigger outbound webhook deliveries:
  #
  #   class Community < ApplicationRecord
  #     include WebhookPublishable
  #     webhook_events :created, :updated, :destroyed
  #   end
  #
  # Events follow the pattern: "model_name.action" (e.g., "community.created").
  # Payloads include the record's ID, type, and key attributes.
  module WebhookPublishable
    extend ActiveSupport::Concern

    included do
      class_attribute :_webhook_event_types, default: %i[created updated destroyed]

      after_create_commit :publish_webhook_created
      after_update_commit :publish_webhook_updated
      after_destroy_commit :publish_webhook_destroyed
    end

    class_methods do
      # Configure which events this model publishes
      # @param events [Array<Symbol>] one or more of :created, :updated, :destroyed
      def webhook_events(*events)
        self._webhook_event_types = events.map(&:to_sym)
      end

      # The event prefix for this model (e.g., "community" for BetterTogether::Community)
      # @return [String]
      def webhook_event_prefix
        name.demodulize.underscore
      end
    end

    private

    def publish_webhook_created
      return unless self.class._webhook_event_types.include?(:created)

      publish_webhook_event('created')
    end

    def publish_webhook_updated
      return unless self.class._webhook_event_types.include?(:updated)

      publish_webhook_event('updated')
    end

    def publish_webhook_destroyed
      return unless self.class._webhook_event_types.include?(:destroyed)

      publish_webhook_event('destroyed')
    end

    def publish_webhook_event(action)
      event_name = "#{self.class.webhook_event_prefix}.#{action}"
      payload = webhook_payload(action)

      WebhookEndpoint.for_event(event_name).find_each do |endpoint|
        delivery = endpoint.webhook_deliveries.create!(
          event: event_name,
          payload: payload,
          status: 'pending'
        )
        WebhookDeliveryJob.perform_later(delivery.id)
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      Rails.logger.error("Failed to publish webhook event #{event_name}: #{e.message}")
    end

    # Build the webhook payload for this record.
    # Override in models for custom payload structure.
    # @param action [String] "created", "updated", or "destroyed"
    # @return [Hash]
    def webhook_payload(action)
      {
        event: "#{self.class.webhook_event_prefix}.#{action}",
        timestamp: Time.current.iso8601,
        data: {
          id: id,
          type: self.class.name,
          attributes: webhook_attributes
        }
      }
    end

    # Default attributes to include in webhook payloads.
    # Override in models for custom attribute selection.
    # @return [Hash]
    # rubocop:disable Metrics/AbcSize
    def webhook_attributes
      attrs = {}
      attrs[:created_at] = created_at&.iso8601 if respond_to?(:created_at)
      attrs[:updated_at] = updated_at&.iso8601 if respond_to?(:updated_at)
      attrs[:name] = try(:name)
      attrs[:slug] = try(:slug)
      attrs[:identifier] = try(:identifier)
      attrs[:privacy] = try(:privacy)
      attrs.compact
    end
    # rubocop:enable Metrics/AbcSize
  end
end

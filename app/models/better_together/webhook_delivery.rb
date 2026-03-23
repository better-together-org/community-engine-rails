# frozen_string_literal: true

module BetterTogether
  # Tracks individual webhook delivery attempts.
  # Each delivery represents one POST to a WebhookEndpoint for a specific event.
  #
  # Statuses:
  # - pending:   queued for delivery
  # - delivered:  successfully delivered (2xx response)
  # - failed:    delivery failed after all retries
  # - retrying:  will be retried
  class WebhookDelivery < ApplicationRecord
    self.table_name = 'better_together_webhook_deliveries'

    belongs_to :webhook_endpoint,
               class_name: 'BetterTogether::WebhookEndpoint'

    validates :event, presence: true

    enum :status, {
      pending: 'pending',
      delivered: 'delivered',
      failed: 'failed',
      retrying: 'retrying'
    }

    validates :status, presence: true

    scope :recent, -> { order(created_at: :desc) }

    # Mark as successfully delivered
    # @param code [Integer] HTTP response code
    # @param body [String] response body
    def mark_delivered!(code:, body: nil)
      update!(
        status: 'delivered',
        response_code: code,
        response_body: body&.truncate(1000),
        delivered_at: Time.current,
        attempts: attempts + 1
      )
    end

    # Mark as failed
    # @param code [Integer, nil] HTTP response code
    # @param body [String, nil] response body or error message
    def mark_failed!(code: nil, body: nil)
      update!(
        status: 'failed',
        response_code: code,
        response_body: body&.truncate(1000),
        attempts: attempts + 1
      )
    end

    # Mark for retry
    def mark_retrying!
      update!(
        status: 'retrying',
        attempts: attempts + 1
      )
    end
  end
end

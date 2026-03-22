# frozen_string_literal: true

module BetterTogether
  # Delivers a webhook payload to a registered endpoint via HTTP POST.
  #
  # Signs the payload body with HMAC-SHA256 using the endpoint's secret.
  # Retries up to 3 times with exponential backoff on failure.
  #
  # Headers sent:
  # - Content-Type: application/json
  # - X-BT-Webhook-Event: the event name
  # - X-BT-Webhook-Signature: HMAC-SHA256 hex digest
  # - X-BT-Webhook-Timestamp: ISO8601 timestamp
  # - X-BT-Webhook-Delivery-Id: UUID of the delivery record
  class WebhookDeliveryJob < ApplicationJob
    queue_as :webhooks

    retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
      delivery = WebhookDelivery.find_by(id: job.arguments.first)
      delivery&.mark_failed!(body: "Final retry failed: #{error.message}")
      Rails.logger.error(
        "WebhookDeliveryJob permanently failed for delivery #{job.arguments.first}: #{error.message}"
      )
    end

    # @param delivery_id [String] UUID of the WebhookDelivery record
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def perform(delivery_id)
      delivery = WebhookDelivery.find(delivery_id)
      endpoint = delivery.webhook_endpoint

      unless endpoint.active?
        delivery.mark_failed!(body: 'Endpoint is inactive')
        return
      end

      body = delivery.payload.to_json
      timestamp = Time.current.iso8601
      signature = compute_signature(body, timestamp, endpoint.secret)

      response = post_webhook(
        url: endpoint.url,
        body: body,
        headers: build_headers(delivery, timestamp, signature)
      )

      handle_response(delivery, response)
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn("WebhookDeliveryJob: delivery #{delivery_id} not found, skipping")
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    private

    def compute_signature(body, timestamp, secret)
      payload = "#{timestamp}.#{body}"
      OpenSSL::HMAC.hexdigest('sha256', secret, payload)
    end

    def build_headers(delivery, timestamp, signature)
      {
        'Content-Type' => 'application/json',
        'X-BT-Webhook-Event' => delivery.event,
        'X-BT-Webhook-Signature' => signature,
        'X-BT-Webhook-Timestamp' => timestamp,
        'X-BT-Webhook-Delivery-Id' => delivery.id,
        'User-Agent' => "BetterTogether/#{BetterTogether::VERSION} Webhooks"
      }
    end

    def post_webhook(url:, body:, headers:)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.body = body

      http.request(request)
    end

    def handle_response(delivery, response)
      code = response.code.to_i

      if code >= 200 && code < 300
        delivery.mark_delivered!(code: code, body: response.body)
      else
        delivery.mark_retrying!
        raise "Webhook delivery failed with HTTP #{code}: #{response.body&.truncate(200)}"
      end
    end
  end
end

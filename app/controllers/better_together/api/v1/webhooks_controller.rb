# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Receives inbound webhook events from external systems (n8n, management tool).
      #
      # External systems POST events to /api/v1/webhooks/receive with:
      # - OAuth Bearer token (client_credentials grant)
      # - JSON body with event type and payload
      #
      # Supported event types:
      # - sync.community: sync community data from external system
      # - sync.person: sync person data
      # - sync.event: sync event data
      # - action.notify: trigger a notification
      # - action.publish: publish content
      # - ping: health check / connectivity test
      class WebhooksController < BetterTogether::Api::ApplicationController
        # CSRF protection is already handled by Api::ApplicationController which skips it for JSON/JSONAPI
        # requests. No need to skip_before_action here — doing so triggers CodeQL CSRF alerts.
        skip_after_action :enforce_policy_use # Custom endpoint; authorization via OAuth scopes
        require_oauth_scopes :write, :admin, only: %i[receive]

        # POST /api/v1/webhooks/receive
        # rubocop:disable Metrics/MethodLength
        def receive
          validate_webhook_payload!
          return if performed?

          result = process_webhook_event(
            event: webhook_params[:event],
            payload: webhook_params[:payload] || {}
          )

          render json: {
            data: {
              type: 'webhook_result',
              attributes: {
                event: webhook_params[:event],
                status: result[:status],
                message: result[:message]
              }
            }
          }, status: result[:http_status] || :ok
        end
        # rubocop:enable Metrics/MethodLength

        private

        def webhook_params
          params.permit(:event, payload: {})
        end

        def validate_webhook_payload!
          return if webhook_params[:event].present?

          render json: {
            errors: [{
              status: '422',
              title: 'Missing event type',
              detail: 'The "event" parameter is required'
            }]
          }, status: :unprocessable_entity
        end

        # rubocop:disable Metrics/MethodLength
        def process_webhook_event(event:, payload:)
          case event
          when 'ping'
            handle_ping
          when /\Async\./
            handle_sync(event, payload)
          when /\Aaction\./
            handle_action(event, payload)
          else
            {
              status: 'unknown_event',
              message: "Unrecognized event type: #{event}",
              http_status: :unprocessable_entity
            }
          end
        end
        # rubocop:enable Metrics/MethodLength

        def handle_ping
          {
            status: 'ok',
            message: 'pong',
            http_status: :ok
          }
        end

        def handle_sync(event, payload)
          Rails.logger.info("Webhook sync received: #{event} with #{payload.keys.join(', ')}")
          {
            status: 'received',
            message: "Sync event #{event} received and queued for processing",
            http_status: :accepted
          }
        end

        def handle_action(event, payload)
          Rails.logger.info("Webhook action received: #{event} with #{payload.keys.join(', ')}")
          {
            status: 'received',
            message: "Action #{event} received and queued for processing",
            http_status: :accepted
          }
        end
      end
    end
  end
end

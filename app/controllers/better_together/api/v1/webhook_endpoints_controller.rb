# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource controller for webhook endpoints.
      # Allows platform managers and endpoint owners to manage
      # outbound webhook subscriptions.
      #
      # Also provides a test ping action to verify endpoint connectivity.
      class WebhookEndpointsController < BetterTogether::Api::ApplicationController
        require_oauth_scopes :admin, only: %i[create update destroy test]
        require_oauth_scopes :admin, :read, only: %i[index show]

        # GET /api/v1/webhook_endpoints
        def index
          super
        end

        # GET /api/v1/webhook_endpoints/:id
        def show
          super
        end

        # POST /api/v1/webhook_endpoints
        def create
          super
        end

        # PATCH /api/v1/webhook_endpoints/:id
        def update
          super
        end

        # DELETE /api/v1/webhook_endpoints/:id
        def destroy
          super
        end

        # POST /api/v1/webhook_endpoints/:id/test
        # Sends a test ping event to verify the endpoint is reachable
        # rubocop:disable Metrics/MethodLength
        def test
          endpoint = BetterTogether::WebhookEndpoint.find(params[:id])
          authorize endpoint, :test?
          @policy_used = true

          delivery = endpoint.webhook_deliveries.create!(
            event: 'webhook.test',
            payload: {
              event: 'webhook.test',
              timestamp: Time.current.iso8601,
              data: { message: 'Test webhook delivery from Better Together' }
            },
            status: 'pending'
          )

          WebhookDeliveryJob.perform_later(delivery.id)

          render json: {
            data: {
              type: 'webhook_test',
              id: delivery.id,
              attributes: {
                status: 'queued',
                message: 'Test webhook delivery has been queued'
              }
            }
          }, status: :accepted
        end
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end

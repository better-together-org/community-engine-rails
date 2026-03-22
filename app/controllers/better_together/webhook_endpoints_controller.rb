# frozen_string_literal: true

module BetterTogether
  # Web UI controller for managing webhook endpoints.
  # Platform managers can manage all endpoints; owners can manage their own.
  # Available under the host dashboard.
  class WebhookEndpointsController < ResourceController
    before_action :set_oauth_applications, only: %i[new edit]

    # POST /host/webhook_endpoints/:id/test
    def test
      set_resource_instance
      authorize @resource, :test?

      delivery = @resource.webhook_deliveries.create!(
        event: 'webhook.test',
        payload: {
          event: 'webhook.test',
          timestamp: Time.current.iso8601,
          data: { message: 'Test webhook delivery from Better Together' }
        },
        status: 'pending'
      )

      WebhookDeliveryJob.perform_later(delivery.id)

      redirect_to url_for(@resource),
                  notice: t('.test_queued', default: 'Test webhook delivery has been queued.')
    end

    protected

    def resource_class
      ::BetterTogether::WebhookEndpoint
    end

    def resource_collection
      policy_scope(resource_class).order(created_at: :desc)
    end

    # Auto-assign the current user's person as the webhook owner on create
    def resource_instance(attrs = {})
      @resource ||= resource_class.new(attrs)
      @resource.person ||= current_user.person if current_user&.person
      instance_variable_set("@#{resource_name}", @resource)
    end

    private

    def set_oauth_applications
      @oauth_applications = policy_scope(BetterTogether::OauthApplication).order(:name)
    end
  end
end

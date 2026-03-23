# frozen_string_literal: true

module BetterTogether
  # Web UI controller for managing community-scoped webhook endpoints.
  # Community admins can manage webhooks that fire for events in their community.
  # Mounted under: /c/:community_id/webhook_endpoints
  class CommunityWebhookEndpointsController < BetterTogether::WebhookEndpointsController
    # Must run before ResourceController's set_resource_instance so @community is available
    # when resource_collection is called during find.
    prepend_before_action :set_community
    before_action :authorize_community_admin!

    protected

    def resource_collection
      policy_scope(resource_class)
        .where(community: @community)
        .order(created_at: :desc)
    end

    def resource_instance(attrs = {})
      @resource ||= resource_class.new(attrs)
      @resource.person ||= current_user.person if current_user&.person
      @resource.community ||= @community
      instance_variable_set("@#{resource_name}", @resource)
    end

    private

    def set_community
      @community = BetterTogether::Community.friendly.find(params[:community_id])
    end

    def authorize_community_admin!
      authorize @community, :manage_integrations?
    end
  end
end

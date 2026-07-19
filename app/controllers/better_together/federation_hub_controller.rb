# frozen_string_literal: true

module BetterTogether
  # Top-level, any-authenticated-person landing page summarizing the
  # person's own content federation status, plus (when permitted) network
  # connection health for the host platform. A sibling to HubController and
  # Joatu::HubController, not a Host Dashboard tab — everyone can see their
  # own content's federation status here, not just platform managers.
  class FederationHubController < ApplicationController
    def index
      authorize [:federation_hub], :show?, policy_class: FederationHubPolicy

      @my_federation_summary = FederationHub::PersonalContentSummaryService.call(person: helpers.current_person)
      @show_connection_health_section = show_connection_health_section?
      @connection_health_summary = build_connection_health_summary if @show_connection_health_section
    end

    def activity
      authorize [:federation_hub], :activity?, policy_class: FederationHubPolicy

      @show_connection_health_section = show_connection_health_section?
      @activities = FederationHub::ActivityFeedService.call(
        person: helpers.current_person,
        include_admin_feed: @show_connection_health_section,
        filters: activity_filter_params,
        page: params[:page]
      )
    end

    private

    def activity_filter_params
      params.permit(:platform_id, :direction, :content_type).to_h.symbolize_keys
    end

    def show_connection_health_section?
      FederationHubPolicy.new(pundit_user, :federation_hub).manage_connections_section?
    end

    def build_connection_health_summary
      FederationHub::ConnectionHealthSummaryService.call(platform: host_platform)
    end

    def host_platform
      @host_platform ||= ::BetterTogether::Platform.find_by(host: true)
    end
  end
end

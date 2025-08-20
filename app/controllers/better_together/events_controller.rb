# frozen_string_literal: true

module BetterTogether
  # CRUD for BetterTogether::Event
  class EventsController < FriendlyResourceController
    before_action if: -> { Rails.env.development? } do
      # Make sure that all subclasses are loaded in dev to generate type selector
      Rails.application.eager_load!
    end

    before_action :build_event_hosts, only: :new

    def index
      @draft_events = @events.draft
      @upcoming_events = @events.upcoming
      @past_events = @events.past
    end

    protected

    def build_event_hosts # rubocop:disable Metrics/AbcSize
      return unless params[:host_id].present? && params[:host_type].present?

      return unless event_host_class

      policy_scope = Pundit.policy_scope!(current_user, event_host_class)
      host_record = policy_scope.find_by(id: params[:host_id])
      return unless host_record

      resource_instance.event_hosts.build(
        host_id: params[:host_id],
        host_type: params[:host_type]
      )
    end

    def event_host_class
      param_type = params[:host_type]

      # Allow-list only specific classes to be set as host for an event
      valid_host_types = BetterTogether::HostsEvents.included_in_models
      valid_host_types.find { |klass| klass.to_s == param_type }
    end

    def resource_class
      ::BetterTogether::Event
    end
  end
end

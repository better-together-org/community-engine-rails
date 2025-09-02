# frozen_string_literal: true

module BetterTogether
  # View helpers for events
  module EventsHelper
    # Return hosts for an event that the current user is authorized to view.
    # Keeps view markup small and centralizes the policy logic for testing.
    def visible_event_hosts(event)
      return [] unless event.respond_to?(:event_hosts)

      event.event_hosts.map { |eh| eh.host if policy(eh.host).show? }.compact
    end
  end
end

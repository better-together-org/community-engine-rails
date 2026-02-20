# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to get detailed information about a specific event
    # Includes attendee count, hosts, and full description
    class GetEventDetailTool < ApplicationTool
      description 'Get detailed information about a specific event by ID'

      arguments do
        required(:event_id)
          .filled(:string)
          .description('The UUID of the event to retrieve')
      end

      # Get event details with authorization
      # @param event_id [String] The event UUID
      # @return [String] JSON object with event details
      def call(event_id:)
        with_timezone_scope do
          event = policy_scope(BetterTogether::Event)
                  .includes(:creator, :attendees, :event_hosts, :calendars)
                  .find_by(id: event_id)

          unless event
            result = JSON.generate({ error: 'Event not found or not accessible' })
            log_invocation('get_event_detail', { event_id: event_id }, result.bytesize)
            return result
          end

          result = JSON.generate(serialize_event_detail(event))
          log_invocation('get_event_detail', { event_id: event_id }, result.bytesize)
          result
        end
      end

      private

      def serialize_event_detail(event)
        event_core_attributes(event)
          .merge(event_temporal_attributes(event))
          .merge(event_relationship_attributes(event))
      end

      def event_core_attributes(event)
        {
          id: event.id,
          name: event.name,
          description: event.description.to_s,
          slug: event.slug,
          privacy: event.privacy,
          registration_url: event.registration_url,
          url: BetterTogether::Engine.routes.url_helpers.event_path(event, locale: I18n.locale)
        }
      end

      def event_temporal_attributes(event)
        {
          starts_at: event.starts_at&.iso8601,
          ends_at: event.ends_at&.iso8601,
          local_starts_at: event.local_starts_at&.iso8601,
          local_ends_at: event.local_ends_at&.iso8601,
          duration_minutes: event.duration_minutes,
          timezone: event.timezone,
          timezone_display: event.timezone_display
        }
      end

      def event_relationship_attributes(event)
        {
          creator: serialize_person(event.creator),
          attendee_count: event.attendees.size,
          host_names: event.event_hosts.includes(:host).map { |eh| eh.host&.name }.compact
        }
      end

      def serialize_person(person)
        return nil unless person

        {
          id: person.id,
          name: person.name
        }
      end
    end
  end
end

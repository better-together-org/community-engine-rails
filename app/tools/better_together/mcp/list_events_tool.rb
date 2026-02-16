# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to list events with privacy-aware filtering
    # Supports scope filtering (upcoming, past, ongoing, draft) and privacy filtering
    class ListEventsTool < ApplicationTool
      description 'List events accessible to the current user, with optional scope and privacy filters'

      arguments do
        optional(:scope)
          .filled(:string)
          .description('Filter by scope: upcoming, past, ongoing, draft, scheduled')
        optional(:privacy_filter)
          .filled(:string)
          .description('Filter by privacy level: public or private')
        optional(:limit)
          .filled(:integer)
          .description('Maximum number of results to return (default: 20)')
      end

      # List events with authorization and privacy filtering
      # @param scope [String, nil] Optional scope filter
      # @param privacy_filter [String, nil] Optional privacy level filter
      # @param limit [Integer] Maximum results (default: 20)
      # @return [String] JSON array of event objects
      def call(scope: nil, privacy_filter: nil, limit: 20)
        with_timezone_scope do
          events = policy_scope(BetterTogether::Event)
                   .includes(:creator, :event_hosts)

          # Apply scope filter
          events = apply_scope(events, scope) if scope.present?

          # Apply privacy filter
          events = events.where(privacy: privacy_filter) if privacy_filter.present?

          # Order and limit
          events = events.order(starts_at: :asc).limit([limit, 100].min)

          result = JSON.generate(events.map { |event| serialize_event(event) })
          log_invocation('list_events', { scope: scope, privacy_filter: privacy_filter, limit: limit },
                         result.bytesize)
          result
        end
      end

      private

      def apply_scope(events, scope)
        case scope
        when 'upcoming' then events.upcoming
        when 'past' then events.past
        when 'ongoing' then events.ongoing
        when 'draft' then events.draft
        when 'scheduled' then events.scheduled
        else events
        end
      end

      def serialize_event(event)
        event_attributes(event).merge(event_metadata(event))
      end

      def event_attributes(event)
        {
          id: event.id,
          name: event.name,
          description: event.description.to_s.truncate(200),
          privacy: event.privacy,
          timezone: event.timezone,
          registration_url: event.registration_url
        }
      end

      def event_metadata(event)
        {
          starts_at: event.starts_at&.iso8601,
          ends_at: event.ends_at&.iso8601,
          local_starts_at: event.local_starts_at&.iso8601,
          local_ends_at: event.local_ends_at&.iso8601,
          creator_name: event.creator&.name,
          url: BetterTogether::Engine.routes.url_helpers.event_path(event, locale: I18n.locale)
        }
      end
    end
  end
end

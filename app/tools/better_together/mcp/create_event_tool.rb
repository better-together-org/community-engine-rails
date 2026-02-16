# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to create events (write tool)
    # Requires authentication and event creation permissions
    class CreateEventTool < ApplicationTool
      description 'Create a new event with the specified details'

      arguments do
        required(:name).filled(:string).description('Event name')
        required(:description).filled(:string).description('Event description')
        required(:starts_at).filled(:string).description('Start time (ISO 8601)')
        required(:ends_at).filled(:string).description('End time (ISO 8601)')
        optional(:timezone).filled(:string).description('Event timezone (IANA, e.g. America/New_York)')
        optional(:privacy).filled(:string).description('Privacy level: public or private (default: public)')
        optional(:registration_url).filled(:string).description('External registration URL')
      end

      # Create an event
      # @return [String] JSON with created event or error
      def call(**params) # rubocop:disable Metrics/MethodLength
        return auth_required_response unless current_user

        with_timezone_scope do
          event = build_event(params)
          authorize event, :create?

          result = if event.save
                     JSON.generate(success_response(event))
                   else
                     JSON.generate({ error: 'Validation failed', details: event.errors.full_messages })
                   end

          log_invocation('create_event', params.except(:description), result.bytesize)
          result
        end
      rescue Pundit::NotAuthorizedError
        JSON.generate({ error: 'Not authorized to create events' })
      end

      private

      def auth_required_response
        JSON.generate({ error: 'Authentication required' })
      end

      def build_event(params) # rubocop:disable Metrics/MethodLength
        BetterTogether::Event.new(
          name: params[:name],
          description: params[:description],
          starts_at: parse_time(params[:starts_at]),
          ends_at: parse_time(params[:ends_at]),
          timezone: params[:timezone] || 'UTC',
          privacy: params[:privacy] || 'public',
          registration_url: params[:registration_url],
          creator: current_user.person
        )
      end

      def parse_time(value)
        Time.zone.parse(value)
      rescue ArgumentError, TypeError
        nil
      end

      def success_response(event)
        {
          id: event.id,
          name: event.name,
          starts_at: event.starts_at&.iso8601,
          ends_at: event.ends_at&.iso8601,
          privacy: event.privacy,
          url: BetterTogether::Engine.routes.url_helpers.event_path(event, locale: I18n.locale)
        }
      end
    end
  end
end

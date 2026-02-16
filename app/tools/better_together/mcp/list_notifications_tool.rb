# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to list notifications for the current user
    # Supports filtering by read/unread status
    class ListNotificationsTool < ApplicationTool
      description 'List notifications for the current user, with optional read/unread filter'

      arguments do
        optional(:unread_only)
          .filled(:bool)
          .description('If true, return only unread notifications (default: false)')
        optional(:limit)
          .filled(:integer)
          .description('Maximum number of results to return (default: 20)')
      end

      # List notifications for the current user
      # @param unread_only [Boolean] Filter to unread only
      # @param limit [Integer] Maximum results (default: 20)
      # @return [String] JSON array of notification objects
      def call(unread_only: false, limit: 20)
        with_timezone_scope do
          person = agent
          return auth_required_response unless person

          notifications = fetch_notifications(person, unread_only: unread_only, limit: limit)

          result = JSON.generate({
                                   notifications: notifications.map { |n| serialize_notification(n) },
                                   unread_count: unread_count_for(person)
                                 })
          log_invocation('list_notifications', { unread_only: unread_only, limit: limit }, result.bytesize)
          result
        end
      end

      private

      def auth_required_response
        result = JSON.generate({ error: 'Authentication required to view notifications' })
        log_invocation('list_notifications', {}, result.bytesize)
        result
      end

      def fetch_notifications(person, unread_only:, limit:)
        notifications = Noticed::Notification
                        .where(recipient_type: 'BetterTogether::Person', recipient_id: person.id)
                        .order(created_at: :desc)

        notifications = notifications.where(read_at: nil) if unread_only
        notifications.limit([limit, 100].min)
      end

      def serialize_notification(notification)
        {
          id: notification.id,
          type: notification.type.to_s.demodulize.underscore,
          read: notification.read_at.present?,
          read_at: notification.read_at&.iso8601,
          created_at: notification.created_at.in_time_zone.iso8601,
          params: safe_params(notification)
        }
      end

      def safe_params(notification)
        params = notification.params&.dup || {}
        params.except('_aj_serialized', '_aj_globalid')
      end

      def unread_count_for(person)
        Noticed::Notification
          .where(recipient_type: 'BetterTogether::Person', recipient_id: person.id, read_at: nil)
          .count
      end
    end
  end
end

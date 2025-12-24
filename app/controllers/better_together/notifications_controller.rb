# frozen_string_literal: true

module BetterTogether
  # handles rendering and marking notifications as read
  class NotificationsController < ApplicationController
    include BetterTogether::NotificationReadable

    before_action :authenticate_user!
    before_action :disallow_robots

    def index
      @notifications = helpers.current_person.notifications.includes(:event).order(created_at: :desc)
      @unread_count = helpers.current_person.notifications.unread.size
    end

    def dropdown # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      # Get basic info needed for cache key (minimal queries)
      max_updated_at = helpers.current_person.notifications.maximum(:updated_at)
      unread_count = helpers.current_person.notifications.unread.size

      # Create cache key based on max updated_at of user's notifications
      cache_key = "notifications_dropdown/#{helpers.current_person.id}/#{max_updated_at&.to_i}/#{unread_count}"

      cached_content = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        # Only fetch detailed data when cache misses
        notifications = helpers.recent_notifications

        # Warm up fragment caches for individual notifications in background
        warm_notification_fragment_caches(notifications) if Rails.env.production?

        render_to_string(
          partial: 'better_together/notifications/dropdown_content',
          locals: { notifications: notifications, unread_count: unread_count }
        )
      end

      render html: cached_content.html_safe
    end

    # TODO: Make a Stimulus controller to dispatch this action async when messages are viewed
    def mark_as_read
      process_mark_as_read_request

      respond_to do |format|
        format.html { redirect_to notifications_path }
        format.turbo_stream { render_turbo_stream_response }
      end
    end

    private

    def process_mark_as_read_request
      if params[:id]
        mark_notification_as_read(params[:id])
      elsif params[:record_id]
        mark_record_notification_as_read(params[:record_id])
      else
        helpers.current_person.notifications.unread.update_all(read_at: Time.current)
      end
    end

    def render_turbo_stream_response
      if @notification
        render_notification_turbo_stream
      else
        render_notifications_list_turbo_stream
      end
    end

    def render_notification_turbo_stream
      # Get the notifier instance from the event
      notifier = @notification.event

      render turbo_stream: turbo_stream.replace(
        helpers.dom_id(@notification),
        partial: 'better_together/notifications/notification',
        locals: {
          notification: @notification,
          notification_title: notifier&.title || 'Notification',
          notification_url: (notifier&.respond_to?(:url) ? notifier.url : nil)
        }
      )
    end

    def render_notifications_list_turbo_stream
      render turbo_stream: turbo_stream.replace(
        'notifications',
        partial: 'better_together/notifications/notifications',
        locals: { notifications: helpers.current_person.notifications, unread_count: 0 }
      )
    end

    def mark_notification_as_read(id)
      @notification = helpers.current_person.notifications.find(id)
      @notification.update(read_at: Time.current)
    end

    def mark_record_notification_as_read(id)
      mark_notifications_read_for_record_id(id)
    end

    # Warm fragment caches for notifications to improve subsequent renders
    def warm_notification_fragment_caches(notifications)
      notifications.each do |notification|
        next unless helpers.should_cache_notification?(notification)

        # Pre-warm the fragment cache keys
        fragment_key = helpers.notification_fragment_cache_key(notification)
        type_key = helpers.notification_type_fragment_cache_key(notification)

        # Check if fragments are already cached to avoid unnecessary work
        unless Rails.cache.exist?(fragment_key) && Rails.cache.exist?(type_key)
          # This could be moved to a background job for better performance
          Rails.logger.debug "Warming fragment cache for notification #{notification.id}"
        end
      end
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  # handles rendering and marking notifications as read
  class NotificationsController < ApplicationController
    before_action :authenticate_user!

    def index
      @notifications = helpers.group_notifications(helpers.current_person.notifications)
      @unread_count = helpers.current_person.notifications.unread.size
    end

    # TODO: Make a Stimulus controller to dispatch this action async when messages are viewed
    # rubocop:todo Metrics/MethodLength
    def mark_as_read # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      if params[:id]
        @notification = helpers.current_person.notifications.includes(:event).find(params[:id])
        related_scope = helpers.current_person.notifications.joins(:event).where(
          noticed_events: {
            record_type: @notification.event.record_type,
            record_id: @notification.event.record_id
          }
        )
        @count = related_scope.count
        related_scope.update_all(read_at: Time.current)
        @notification = related_scope.order(created_at: :desc).first
      else
        helpers.current_person.notifications.unread.update_all(read_at: Time.current)
      end

      respond_to do |format|
        format.html { redirect_to notifications_path }
        format.turbo_stream do
          if @notification
            render turbo_stream: turbo_stream.replace(
              helpers.dom_id(@notification),
              helpers.render(@notification, count: @count)
            )
          else
            render turbo_stream: turbo_stream.replace(
              'notifications',
              partial: 'better_together/notifications/notifications',
              locals: {
                notifications: helpers.group_notifications(helpers.current_person.notifications),
                unread_count: 0
              }
            )
          end
        end
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end

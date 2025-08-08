# frozen_string_literal: true

module BetterTogether
  # handles rendering and marking notifications as read
  class NotificationsController < ApplicationController
    before_action :authenticate_user!

    def index
      @notifications = helpers.current_person.notifications.includes(:event).order(created_at: :desc)
      @unread_count = helpers.current_person.notifications.unread.size
    end

    # TODO: Make a Stimulus controller to dispatch this action async when messages are viewed
    def mark_as_read # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      if params[:id]
        mark_notification_as_read(params[:id])
      elsif params[:message_id]
        mark_message_as_read(params[:message_id])
      else
        helpers.current_person.notifications.unread.update_all(read_at: Time.current)
      end

      respond_to do |format|
        format.html { redirect_to notifications_path }
        format.turbo_stream do
          if @notification
            render turbo_stream: turbo_stream.replace(helpers.dom_id(@notification), @notification)
          else
            render turbo_stream: turbo_stream.replace(
              'notifications',
              partial: 'better_together/notifications/notifications',
              locals: { notifications: helpers.current_person.notifications, unread_count: 0 }
            )
          end
        end
      end
    end

    def mark_notification_as_read(id)
      @notification = helpers.current_person.notifications.find(id)
      @notification.update(read_at: Time.current)
    end

    def mark_message_as_read(id)
      @notification = helpers.current_person.notifications.unread.includes(
        :event
      ).references(:event).where(event: { record_id: id })
      @notification.update(read_at: Time.current)
    end
  end
end

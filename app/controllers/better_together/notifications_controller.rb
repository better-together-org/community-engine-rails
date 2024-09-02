# frozen_string_literal: true

module BetterTogether
  class NotificationsController < ApplicationController
    before_action :authenticate_user!

    def index
      @notifications = helpers.current_person.notifications.includes(:event).order(created_at: :desc)
      @unread_count = helpers.current_person.notifications.unread.size
    end

    def mark_as_read
      if params[:id]
        @notification = helpers.current_person.notifications.find(params[:id])
        @notification.update(read_at: Time.current)
      else
        helpers.current_person.notifications.unread.update_all(read_at: Time.current)
      end

      respond_to do |format|
        format.html { redirect_to notifications_path }
        format.turbo_stream do
          if @notification
            render turbo_stream: turbo_stream.replace(helpers.dom_id(@notification), @notification)
          else
            render turbo_stream: turbo_stream.replace('notifications',
                                                      partial: 'better_together/notifications/notifications', locals: { notifications: helpers.current_person.notifications, unread_count: 0 })
          end
        end
      end
    end
  end
end

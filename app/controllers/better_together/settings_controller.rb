# frozen_string_literal: true

module BetterTogether
  # Settings controller manages user preferences and settings
  # Provides endpoints for viewing and updating user preferences including:
  # - Language/locale selection
  # - Time zone preferences
  # - Notification preferences
  # - Messaging privacy settings
  class SettingsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_person

    def index
      # Settings page with various tabs
    end

    def mark_integration_notifications_read
      return head :unauthorized unless @person.present?

      # Find all unread notifications for PersonPlatformIntegration events
      # Only mark notifications older than 5 seconds to avoid marking just-created integrations
      threshold_time = 5.seconds.ago

      integration_notification_ids = Noticed::Notification
                                     .joins(:event)
                                     .where(recipient: @person)
                                     .where(read_at: nil)
                                     .where('noticed_notifications.created_at < ?', threshold_time)
                                     .where(noticed_events: { type: 'BetterTogether::PersonPlatformIntegrationCreatedNotifier' })
                                     .pluck(:id)

      # Mark them as read
      count = 0
      if integration_notification_ids.any?
        count = Noticed::Notification.where(id: integration_notification_ids).update_all(read_at: Time.current)
      end

      render json: { success: true, marked_read: count }
    end

    def update_preferences
      if @person.update(person_params)
        redirect_to settings_path(locale: I18n.locale),
                    notice: t('flash.generic.updated', resource: Person.model_name.human)
      else
        render :index, status: :unprocessable_entity
      end
    end

    private

    def set_person
      @person = current_user.person
    end

    def person_params
      params.require(:person).permit(
        :locale,
        :time_zone,
        :receive_messages_from_members,
        :notify_by_email,
        :show_conversation_details
      )
    end
  end
end

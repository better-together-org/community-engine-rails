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
      load_developer_tab_data
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

    def my_data
      @person_data_exports = @person.person_data_exports.with_attached_export_file.latest_first.limit(10)
      @show_person_links = policy(::BetterTogether::PersonLink).index?
      @show_person_access_grants = policy(::BetterTogether::PersonAccessGrant).index?
      @show_person_linked_seeds = policy(::BetterTogether::PersonLinkedSeed).index?
      @show_person_seeds = ::BetterTogether::PersonSeedPolicy.new(current_user, Seed).index?

      render 'better_together/my_data/show', layout: false
    end

    def update_preferences
      if @person.update(person_params)
        redirect_to settings_path(locale: I18n.locale),
                    notice: t('flash.generic.updated', resource: Person.model_name.human)
      else
        load_developer_tab_data
        render :index, status: :unprocessable_entity
      end
    end

    private

    def load_developer_tab_data
      @person_oauth_apps = OauthApplication.where(owner: @person).order(created_at: :desc)
      @access_tokens = OauthAccessToken
                       .where(resource_owner_id: current_user.id)
                       .where(revoked_at: nil)
                       .includes(:application)
                       .order(created_at: :desc)
    end

    def set_person
      @person = current_user.person
    end

    def person_params
      params.require(:person).permit(
        :locale,
        :time_zone,
        :receive_messages_from_members,
        :federate_content,
        :notify_by_email,
        :show_conversation_details
      )
    end
  end
end

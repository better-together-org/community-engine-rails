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

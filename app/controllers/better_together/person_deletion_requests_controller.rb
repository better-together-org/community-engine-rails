# frozen_string_literal: true

module BetterTogether
  # Handles member-submitted deletion requests and cancellations.
  class PersonDeletionRequestsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_person_deletion_request, only: :destroy

    def create
      current_user.person.person_deletion_requests.create!(
        requested_at: Time.current,
        requested_reason: params.dig(:person_deletion_request, :requested_reason)
      )

      redirect_to settings_my_data_path(locale: I18n.locale),
                  notice: t('better_together.settings.index.my_data.deletion_request_created'),
                  status: :see_other
    rescue ActiveRecord::RecordInvalid
      redirect_to settings_my_data_path(locale: I18n.locale),
                  alert: t('better_together.settings.index.my_data.deletion_request_failed'),
                  status: :see_other
    end

    def destroy
      @person_deletion_request.cancel!
      redirect_to settings_my_data_path(locale: I18n.locale),
                  notice: t('better_together.settings.index.my_data.deletion_request_cancelled'),
                  status: :see_other
    end

    private

    def set_person_deletion_request
      @person_deletion_request = current_user.person.person_deletion_requests.active.find(params[:id])
    end
  end
end

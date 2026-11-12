# frozen_string_literal: true

module BetterTogether
  # Handles member-submitted deletion requests and cancellations.
  class PersonDeletionRequestsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_person_deletion_request, only: :destroy

    def create
      return redirect_to_platform_request if current_user.person.last_platform_steward?

      create_request!

      redirect_to edit_user_registration_path(locale: I18n.locale),
                  notice: t('better_together.settings.index.my_data.deletion_request_created'),
                  status: :see_other
    rescue ActiveRecord::RecordInvalid
      redirect_to edit_user_registration_path(locale: I18n.locale),
                  alert: t('better_together.settings.index.my_data.deletion_request_failed'),
                  status: :see_other
    end

    def destroy
      @person_deletion_request.cancel!
      redirect_to edit_user_registration_path(locale: I18n.locale),
                  notice: t('better_together.settings.index.my_data.deletion_request_cancelled'),
                  status: :see_other
    end

    private

    def create_request!
      current_user.person.person_deletion_requests.create!(
        requested_at: Time.current, requested_reason: deletion_request_params[:requested_reason]
      )
    end

    def redirect_to_platform_request
      redirect_to new_platform_deletion_request_path(locale: I18n.locale),
                  notice: t('better_together.platform_deletion_requests.redirected'),
                  status: :see_other
    end

    def set_person_deletion_request
      @person_deletion_request = current_user.person.person_deletion_requests.active.find(params[:id])
    end

    def deletion_request_params
      params.require(:person_deletion_request).permit(:requested_reason)
    end
  end
end

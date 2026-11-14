# frozen_string_literal: true

module BetterTogether
  # Lets the last steward of a platform ask host stewards to remove the platform, instead of
  # deleting their own account and leaving the platform without a steward.
  class PlatformDeletionRequestsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_platform
    before_action :require_steward

    def new
      @platform_deletion_request = PlatformDeletionRequest.new
      load_requests
    end

    def create
      @platform_deletion_request = PlatformDeletionRequest.new(
        platform: @platform, requested_by: current_user.person, requested_at: Time.current,
        requested_reason: params.dig(:platform_deletion_request, :requested_reason)
      )
      if @platform_deletion_request.save
        redirect_to new_platform_deletion_request_path(locale: I18n.locale),
                    notice: t('better_together.platform_deletion_requests.created'), status: :see_other
      else
        load_requests
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      PlatformDeletionRequest.pending.find_by!(id: params[:id], platform: @platform).cancel!
      redirect_to new_platform_deletion_request_path(locale: I18n.locale),
                  notice: t('better_together.platform_deletion_requests.cancelled'), status: :see_other
    end

    private

    def set_platform
      @platform = current_user.person.account_platform
      raise ActiveRecord::RecordNotFound if @platform.nil?
    end

    def require_steward
      raise ActiveRecord::RecordNotFound unless @platform.steward?(current_user.person)
    end

    def load_requests
      @platform_deletion_requests = PlatformDeletionRequest.where(platform: @platform).latest_first.limit(10)
    end
  end
end

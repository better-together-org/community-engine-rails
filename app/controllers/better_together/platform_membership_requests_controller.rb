# frozen_string_literal: true

module BetterTogether
  # Admin-facing controller for reviewing and acting on community membership requests.
  # Nested under Platform so admins manage requests for communities on their platform.
  class PlatformMembershipRequestsController < ApplicationController
    before_action :set_platform
    before_action :set_membership_request, only: %i[show destroy]
    after_action :verify_authorized

    # GET /platforms/:platform_id/membership_requests
    def index
      authorize BetterTogether::Joatu::MembershipRequest

      @membership_requests = base_collection
      @membership_requests = apply_status_filter(@membership_requests)
      @membership_requests = @membership_requests.order(created_at: :desc)
                                                 .page(params[:page]).per(25)
    end

    # GET /platforms/:platform_id/membership_requests/:id
    def show
      authorize @membership_request
    end

    # DELETE /platforms/:platform_id/membership_requests/:id
    def destroy
      authorize @membership_request

      if @membership_request.destroy
        flash.now[:notice] = t('flash.generic.removed',
                                resource: t('better_together.resources.membership_request'))
        respond_to do |format|
          format.html { redirect_to platform_membership_requests_path(@platform) }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove(helpers.dom_id(@membership_request)),
              turbo_stream.replace('flash_messages',
                                   partial: 'layouts/better_together/flash_messages',
                                   locals: { flash: })
            ]
          end
        end
      else
        flash.now[:alert] = t('flash.generic.error_remove',
                               resource: t('better_together.resources.membership_request'))
        respond_to do |format|
          format.html { redirect_to platform_membership_requests_path(@platform), alert: flash.now[:alert] }
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace('flash_messages',
                                                      partial: 'layouts/better_together/flash_messages',
                                                      locals: { flash: })
          end
        end
      end
    end

    private

    def set_platform
      @platform = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.where(
        translatable_type: 'BetterTogether::Platform',
        key: 'slug',
        value: params[:platform_id],
        locale: I18n.available_locales
      ).includes(:translatable).last&.translatable
    end

    def set_membership_request
      @membership_request = base_collection.find(params[:id])
    end

    def base_collection
      # Platform managers see all membership requests (policy scope handles authorization)
      policy_scope(BetterTogether::Joatu::MembershipRequest)
        .where(target_type: 'BetterTogether::Community')
    end

    def apply_status_filter(collection)
      status = params[:status]
      return collection.where(status: status) if status.present?

      # Default to open requests
      collection.where(status: 'open')
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  # Public-facing controller for submitting community membership requests.
  #
  # Accessible without authentication. Nested under a community so the target
  # community is unambiguous:
  #
  #   GET  /c/:community_id/membership_requests/new
  #   POST /c/:community_id/membership_requests
  #
  # Host apps may override +validate_captcha_if_enabled?+ to add Turnstile or
  # other captcha validation (same pattern as UsersRegistrationsController).
  class MembershipRequestsController < ApplicationController
    skip_before_action :authenticate_user!, raise: false
    skip_before_action :check_platform_privacy

    before_action :set_community
    after_action :verify_authorized

    # GET /c/:community_id/membership_requests/new
    def new
      @membership_request = BetterTogether::Joatu::MembershipRequest.new(
        target: @community
      )
      authorize @membership_request
    end

    # POST /c/:community_id/membership_requests
    def create # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      @membership_request = BetterTogether::Joatu::MembershipRequest.new(
        membership_request_params.merge(
          target: @community,
          status: 'open',
          urgency: 'normal',
          name: "Membership request from #{membership_request_params[:requestor_name]}"
        )
      )
      authorize @membership_request

      unless validate_captcha_if_enabled?
        handle_captcha_validation_failure(@membership_request)
        render :new, status: :unprocessable_entity
        return
      end

      if @membership_request.save
        respond_to do |format|
          format.html { render :success }
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              'membership_request_form',
              partial: 'better_together/membership_requests/success'
            )
          end
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.turbo_stream do
            render status: :unprocessable_entity,
                   turbo_stream: turbo_stream.replace(
                     'membership_request_form',
                     partial: 'better_together/membership_requests/form',
                     locals: { membership_request: @membership_request, community: @community }
                   )
          end
        end
      end
    end

    private

    def set_community
      @community = ::BetterTogether::Community.friendly.find(params[:community_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: t('globals.not_found', default: 'Not found.')
    end

    def membership_request_params
      params.require(:joatu_membership_request).permit(
        :requestor_name,
        :requestor_email,
        :referral_source,
        :description
      )
    end

    # Hook for host applications to implement captcha validation.
    # Override in the host app to add Turnstile or other captcha logic.
    # @return [Boolean] true if captcha is valid or not enabled
    def validate_captcha_if_enabled?
      true
    end

    # Hook for captcha failure handling. Override to customise the error message.
    def handle_captcha_validation_failure(resource)
      resource.errors.add(
        :base,
        I18n.t('better_together.registrations.captcha_validation_failed',
               default: 'Security verification failed. Please try again.')
      )
    end
  end
end

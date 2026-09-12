# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Public JSON:API endpoint for submitting community membership requests.
      #
      # create is intentionally unauthenticated — visitors submit requests before
      # they have an account. All other actions require authentication via the
      # parent ApplicationController before_action.
      #
      # Host apps must override +validate_captcha_if_enabled?+ to enforce captcha.
      class MembershipRequestsController < BetterTogether::Api::ApplicationController
        include BetterTogether::BotProtectedSubmissions

        skip_before_action :authenticate_api_user!, only: :create, raise: false

        def create # rubocop:todo Metrics/MethodLength
          membership_request = BetterTogether::Joatu::MembershipRequest.new
          unless bot_protected_submission_valid?(form_id: :membership_request_api, resource: membership_request)
            return render json: {
              errors: [{ title: membership_request.errors.full_messages.first }]
            }, status: :unprocessable_entity
          end

          unless validate_captcha_if_enabled?
            return render json: {
              errors: [{ title: I18n.t(
                'better_together.membership_requests.captcha_failed',
                default: 'Security verification failed. Please try again.'
              ) }]
            }, status: :unprocessable_entity
          end

          super
        end

        def index = super
        def show  = super
        def update = super
        def destroy = super

        private

        # Hook for host applications to enforce captcha on public POST.
        # Override this method and return false to block the request.
        def validate_captcha_if_enabled?
          true
        end
      end
    end
  end
end

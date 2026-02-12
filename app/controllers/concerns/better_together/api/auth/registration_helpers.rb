# frozen_string_literal: true

module BetterTogether
  module Api
    module Auth
      # Shared helpers for API registration controllers
      module RegistrationHelpers
        extend ActiveSupport::Concern

        protected

        def sign_up_params
          user_params = params[:user] || params.dig(:registration, :user) || {}
          user_params = user_params.to_unsafe_h if user_params.is_a?(ActionController::Parameters)
          ActionController::Parameters.new(user_params).permit(
            :email,
            :password,
            :password_confirmation,
            :invitation_code,
            person_attributes: %i[identifier name description]
          )
        end

        def configure_permitted_parameters
          # for user account creation i.e sign up
          devise_parameter_sanitizer.permit(:sign_up,
                                            keys: [:email, :password, :password_confirmation, :invitation_code,
                                                   { person_attributes: %i[identifier name description] }])
        end

        def person_params
          user_params = params[:user] || params.dig(:registration, :user)
          return {} unless user_params && user_params[:person_attributes]

          user_params = user_params.to_unsafe_h if user_params.is_a?(ActionController::Parameters)
          ActionController::Parameters.new(user_params)
                                      .require(:person_attributes)
                                      .permit(%i[identifier name description])
        rescue ActionController::ParameterMissing => e
          Rails.logger.error "Missing person parameters: #{e.message}"
          {}
        end

        # Validate platform invitation requirement for API registrations
        def validate_invitation_requirement
          return unless helpers.host_platform&.requires_invitation?

          invitation_code = params.dig(:user, :invitation_code) || params[:invitation_code]
          return if invitation_code.present? && valid_invitation_code?(invitation_code)

          render json: {
            error: I18n.t('devise.registrations.invitation_required',
                          default: 'Registration requires a valid invitation code')
          }, status: :forbidden
        end

        # Check if invitation code is valid
        def valid_invitation_code?(code)
          BetterTogether::Invitation.pending.not_expired.exists?(token: code)
        end

        # Load invitations from request params instead of session (API is stateless)
        def load_invitations_from_params
          invitation_code = params.dig(:user, :invitation_code) || params[:invitation_code]
          return unless invitation_code.present?

          invitation = BetterTogether::Invitation.pending.not_expired.find_by(token: invitation_code)
          return unless invitation

          # Determine type and store in instance variables for use during registration
          case invitation
          when BetterTogether::CommunityInvitation
            @community_invitation = invitation
          when BetterTogether::EventInvitation
            @event_invitation = invitation
          when BetterTogether::PlatformInvitation
            @platform_invitation = invitation
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  module Api
    module Auth
      # JSONAPI resource for user registrations
      class RegistrationsController < BetterTogether::Users::RegistrationsController
        include InvitationSessionManagement

        respond_to :json

        skip_before_action :check_platform_privacy, raise: false
        before_action :configure_permitted_parameters
        before_action :validate_invitation_requirement, only: %i[create]
        before_action :load_invitations_from_params, only: %i[create]
        before_action :set_required_agreements, only: %i[create]

        # rubocop:todo Metrics/PerceivedComplexity
        # rubocop:todo Metrics/MethodLength
        # rubocop:todo Metrics/AbcSize
        def create # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
          # Check agreements acceptance (matches parent behavior)
          unless agreements_accepted?
            build_resource(sign_up_params)
            resource.errors.add(:base, I18n.t('devise.registrations.new.agreements_required'))
            return render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
          end

          # Validate captcha if enabled by host application
          unless validate_captcha_if_enabled?
            build_resource(sign_up_params)
            resource.errors.add(:base, I18n.t('better_together.registrations.captcha_validation_failed',
                                              default: 'Security verification failed. Please try again.'))
            return render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
          end

          # Use transaction for all user creation and associated records (matches parent)
          ActiveRecord::Base.transaction do
            build_resource(sign_up_params)

            # Setup user from invitations before saving (matches parent)
            setup_user_from_invitations(resource)
            resource.build_person(person_params) unless resource.person

            resource.save
            yield resource if block_given?

            if resource.persisted? && resource.errors.empty?
              # Handle post-registration setup (matches parent behavior)
              handle_user_creation(resource)

              if resource.active_for_authentication?
                sign_up(resource_name, resource)
                render json: {
                  message: I18n.t('devise.registrations.signed_up'),
                  data: {
                    type: 'users',
                    id: resource.id,
                    attributes: {
                      email: resource.email,
                      confirmed: resource.confirmed_at.present?
                    }
                  }
                }, status: :created
              else
                expire_data_after_sign_in!
                render json: {
                  message: I18n.t('devise.registrations.signed_up_but_inactive'),
                  data: {
                    type: 'users',
                    id: resource.id,
                    attributes: {
                      email: resource.email,
                      confirmed: resource.confirmed_at.present?
                    }
                  }
                }, status: :created
              end
            elsif resource.persisted?
              # User was created but has errors - rollback to maintain consistency
              raise ActiveRecord::Rollback
            else
              clean_up_passwords resource
              set_minimum_password_length
              render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
            end
          end
        rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey => e
          # Clean up and show user-friendly error
          Rails.logger.error "API Registration failed: #{e.message}"
          build_resource(sign_up_params) if resource.nil?
          resource&.errors&.add(:base, 'Registration could not be completed. Please try again.')
          render json: { errors: resource&.errors&.full_messages || ['Registration failed'] }, status: :unprocessable_entity
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/MethodLength
        # rubocop:enable Metrics/PerceivedComplexity

        protected

        def configure_permitted_parameters
          # for user account creation i.e sign up
          devise_parameter_sanitizer.permit(:sign_up,
                                            keys: [:email, :password, :password_confirmation, :invitation_code,
                                                   { person_attributes: %i[identifier name description] }])
        end

        def person_params
          return {} unless params[:user] && params[:user][:person_attributes]

          params.require(:user).require(:person_attributes).permit(%i[identifier name description])
        rescue ActionController::ParameterMissing => e
          Rails.logger.error "Missing person parameters: #{e.message}"
          {}
        end

        def after_inactive_sign_up_path_for(resource); end

        def after_sign_up_path_for(resource); end

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

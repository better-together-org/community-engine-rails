# frozen_string_literal: true

module BetterTogether
  module Api
    module Auth
      # JSONAPI resource for user registrations
      class RegistrationsController < BetterTogether::Users::RegistrationsController
        include InvitationSessionManagement
        include BetterTogether::Api::Auth::RegistrationHelpers

        respond_to :json

        skip_before_action :check_platform_privacy, raise: false
        before_action :configure_permitted_parameters
        before_action :validate_invitation_requirement, only: %i[create]
        before_action :load_invitations_from_params, only: %i[create]
        before_action :set_required_agreements, only: %i[create]

        # rubocop:todo Metrics/PerceivedComplexity
        # rubocop:todo Metrics/MethodLength
        # rubocop:todo Metrics/AbcSize
        def create(&) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
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
          ActiveRecord::Base.transaction { register_user!(&) }
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

        def after_inactive_sign_up_path_for(resource); end

        def after_sign_up_path_for(resource); end

        private

        def register_user! # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
          build_resource(sign_up_params)

          # Setup user from invitations before saving (matches parent)
          setup_user_from_invitations(resource)
          resource.build_person(person_params) unless resource.person

          resource.save
          yield resource if block_given?

          return handle_successful_registration if registration_successful?
          return rollback_persisted_with_errors if resource.persisted?

          handle_failed_registration
        end

        def registration_successful?
          resource.persisted? && resource.errors.empty?
        end

        def rollback_persisted_with_errors
          # User was created but has errors - rollback to maintain consistency
          raise ActiveRecord::Rollback
        end

        def handle_successful_registration
          # Handle post-registration setup (matches parent behavior)
          handle_user_creation(resource)
          send_confirmation_if_needed(resource)
          render_signed_up_response(resource)
        end

        def send_confirmation_if_needed(resource)
          return unless resource.respond_to?(:send_confirmation_instructions) &&
                        resource.respond_to?(:confirmation_sent_at) &&
                        resource.confirmation_sent_at.blank?

          resource.send_confirmation_instructions
        end

        def render_signed_up_response(resource)
          if resource.active_for_authentication?
            sign_up(resource_name, resource)
            render json: signed_up_payload(resource, I18n.t('devise.registrations.signed_up')),
                   status: :created
          else
            expire_data_after_sign_in!
            render json: signed_up_payload(resource, I18n.t('devise.registrations.signed_up_but_inactive')),
                   status: :created
          end
        end

        def signed_up_payload(resource, message)
          {
            message:,
            data: {
              type: 'users',
              id: resource.id,
              attributes: {
                email: resource.email,
                confirmed: resource.confirmed_at.present?
              }
            }
          }
        end

        def handle_failed_registration
          clean_up_passwords resource
          set_minimum_password_length
          render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end
end

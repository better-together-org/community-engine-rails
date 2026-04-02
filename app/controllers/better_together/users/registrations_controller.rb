# frozen_string_literal: true

module BetterTogether
  module Users
    # Extends Devise registration flows with BTS-specific profile and deletion-request handling.
    # rubocop:disable Metrics/ClassLength
    class RegistrationsController < Devise::RegistrationsController
      before_action :configure_permitted_parameters, if: :devise_controller?
      before_action :configure_account_update_params, only: [:update]
      before_action :set_required_agreements, only: %i[new create]

      # GET /resource/sign_up
      def new
        super do |resource|
          resource.build_person if resource.person.blank?
        end
      end

      # POST /resource
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      def create
        build_resource(sign_up_params)
        resource.build_person(identifier: resource.email.split('@').first.titleize) if resource.person.blank?

        # Ensure agreements are properly initialized
        initialize_agreements

        ActiveRecord::Base.transaction do
          # Save the user first
          resource.save!

          # Create or find the person if not already created through nested attributes
          person = resource.person || BetterTogether::Person.find_or_create_by!(name: resource.email.split('@').first.titleize) do |p|
            p.identifier = resource.email.split('@').first.titleize
            p.description = "User profile for #{resource.email}"
          end

          # Ensure user has an identification
          unless resource.person_identification
            person_identification = BetterTogether::PersonIdentification.create!(person: person, identifier: resource.email)
            resource.build_person_identification(person_identification: person_identification)
            resource.save!
          end

          # Handle agreements if they exist
          handle_agreements_creation(person)

          if resource.persisted?
            # Sign out any existing session before signing in the new user
            sign_out(current_user) if user_signed_in?
            sign_up(resource_name, resource)
            respond_with resource, location: after_sign_up_path_for(resource)
          else
            # This should not happen with save!, but handle it defensively
            clean_up_passwords resource
            set_minimum_password_length
            respond_with resource
          end
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey => e
        Rails.logger.error "Registration failed: #{e.message}"
        build_resource(sign_up_params) if resource.nil?
        resource&.errors&.add(:base, 'Registration could not be completed. Please try again.')
        respond_with resource
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      # rubocop:disable Metrics/AbcSize
      def update
        self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
        prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)

        resource_updated = update_resource(resource, account_update_params)
        yield resource if block_given?

        if resource_updated
          bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?
          set_flash_message_for_update(resource, prev_unconfirmed_email)
          respond_with resource, location: after_update_path_for(resource)
        else
          clean_up_passwords resource
          set_minimum_password_length
          respond_with resource
        end
      end
      # rubocop:enable Metrics/AbcSize

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      def create_admin
        build_resource(admin_sign_up_params)
        resource.build_person if resource.person.blank?

        # Ensure agreements are properly initialized
        initialize_agreements

        ActiveRecord::Base.transaction do
          # Save the user first
          resource.save!

          # Handle agreements if they exist
          handle_agreements_creation(resource.person) if resource.person

          raise ActiveRecord::Rollback unless resource.persisted?

          handle_user_creation(resource)
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey => e
        # Clean up and show user-friendly error
        Rails.logger.error "Registration failed: #{e.message}"
        build_resource(sign_up_params) if resource.nil?
        resource&.errors&.add(:base, 'Registration could not be completed. Please try again.')
        respond_with resource
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      def destroy
        active_request = find_or_create_deletion_request

        redirect_to settings_my_data_path(locale: I18n.locale),
                    notice: deletion_request_notice(active_request),
                    status: :see_other
      end

      protected

      def account_update_params
        devise_parameter_sanitizer.sanitize(:account_update)
      end

      def configure_account_update_params
        devise_parameter_sanitizer.permit(:account_update,
                                          keys: %i[email password password_confirmation current_password])
      end

      def configure_permitted_parameters
        devise_parameter_sanitizer.permit(:sign_up, keys: [{ person_attributes: %i[identifier name description] }])
      end

      def set_required_agreements
        @privacy_policy_agreement = BetterTogether::Agreement.find_by(identifier: 'privacy_policy')
        @terms_of_service_agreement = BetterTogether::Agreement.find_by(identifier: 'terms_of_service')
        @code_of_conduct_agreement = BetterTogether::Agreement.find_by(identifier: 'code_of_conduct')
      end

      def find_or_create_deletion_request
        current_user.person.person_deletion_requests.active.first ||
          current_user.person.person_deletion_requests.create!(
            requested_at: Time.current,
            requested_reason: 'Requested from account settings'
          )
      end

      def deletion_request_notice(active_request)
        return I18n.t('better_together.settings.index.my_data.deletion_request_created') if active_request.previously_new_record?

        I18n.t(
          'better_together.settings.index.my_data.deletion_request_exists',
          default: 'Your deletion request is already pending review.'
        )
      end

      # Hook method for host applications to implement captcha validation
      def valid_captcha?
        true
      end

      # Hook method for host applications to handle user creation
      def handle_user_creation(user)
        sign_up(resource_name, user)
        respond_with user, location: after_sign_up_path_for(user)
      end

      private

      def admin_sign_up_params
        params.require(:user).permit(:email, :password, :password_confirmation,
                                     person_attributes: %i[name identifier description])
      end

      def initialize_agreements
        return unless resource&.person

        person = resource.person
        person.build_privacy_policy_agreement if person.privacy_policy_agreement.blank?
        person.build_terms_of_service_agreement if person.terms_of_service_agreement.blank?
        person.build_code_of_conduct_agreement if person.code_of_conduct_agreement.blank?
      end

      # rubocop:disable Metrics/CyclomaticComplexity
      def handle_agreements_creation(person)
        return unless person

        # Create privacy policy agreement acceptance if present
        if @privacy_policy_agreement && params[:privacy_policy_accepted] == '1'
          person.create_privacy_policy_agreement!(agreement: @privacy_policy_agreement, accepted: true, accepted_at: Time.current)
        end

        # Create terms of service agreement acceptance if present
        if @terms_of_service_agreement && params[:terms_of_service_accepted] == '1'
          person.create_terms_of_service_agreement!(agreement: @terms_of_service_agreement, accepted: true, accepted_at: Time.current)
        end

        # Create code of conduct agreement acceptance if present
        return unless @code_of_conduct_agreement && params[:code_of_conduct_accepted] == '1'

        person.create_code_of_conduct_agreement!(agreement: @code_of_conduct_agreement, accepted: true, accepted_at: Time.current)
      end
      # rubocop:enable Metrics/CyclomaticComplexity
    end
    # rubocop:enable Metrics/ClassLength
  end
end

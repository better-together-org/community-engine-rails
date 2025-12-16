# frozen_string_literal: true

module BetterTogether
  module Users
    # Override default Devise registrations controller
    class RegistrationsController < ::Devise::RegistrationsController # rubocop:todo Metrics/ClassLength
      include DeviseLocales
      include InvitationSessionManagement

      skip_before_action :check_platform_privacy
      before_action :configure_permitted_parameters
      # Process invitation code parameters before loading from session
      before_action :process_invitation_code_parameters, only: %i[new create]
      # rubocop:todo Metrics/PerceivedComplexity
      # rubocop:todo Metrics/AbcSize
      # rubocop:todo Lint/CopDirectiveSyntax
      before_action :set_required_agreements, only: %i[new create]
      # rubocop:enable Lint/CopDirectiveSyntax
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/PerceivedComplexity
      before_action :load_all_invitations_from_session, only: %i[new create]
      before_action :configure_account_update_params, only: [:update]

      # PUT /resource
      # We need to use a copy of the resource because we don't want to change
      # the current user in place.
      def update # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
        prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)

        resource_updated = update_resource(resource, account_update_params)
        yield resource if block_given?
        if resource_updated
          set_flash_message_for_update(resource, prev_unconfirmed_email)
          bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?

          respond_to do |format|
            format.html { respond_with resource, location: after_update_path_for(resource) }
            format.turbo_stream do
              flash.now[:notice] = I18n.t('devise.registrations.updated')
              render turbo_stream: [
                turbo_stream.replace(
                  'flash_messages',
                  partial: 'layouts/better_together/flash_messages',
                  locals: { flash: }
                ),
                turbo_stream.replace(
                  'account-settings',
                  partial: 'devise/registrations/edit_form'
                )
              ]
            end
          end
        else
          clean_up_passwords resource
          set_minimum_password_length

          respond_to do |format|
            format.html { respond_with resource, location: after_update_path_for(resource) }
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.replace('form_errors', partial: 'layouts/better_together/errors',
                                                    locals: { object: resource }),
                turbo_stream.replace(
                  'account-settings',
                  partial: 'devise/registrations/edit_form'
                )
              ]
            end
          end
        end
      end

      def new
        super do |user|
          setup_user_from_invitations(user)
          user.build_person unless user.person
        end
      end

      def create # rubocop:todo Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        unless agreements_accepted?
          handle_agreements_not_accepted
          return
        end

        # Validate captcha if enabled by host application
        unless validate_captcha_if_enabled?
          build_resource(sign_up_params)
          handle_captcha_validation_failure(resource)
          return
        end

        # Use transaction for all user creation and associated records
        ActiveRecord::Base.transaction do
          # Call Devise's default create behavior
          super

          # Handle post-registration setup if user was created successfully
          if resource.persisted? && resource.errors.empty?
            handle_user_creation(resource)
          elsif resource.persisted?
            # User was created but has errors - rollback to maintain consistency
            raise ActiveRecord::Rollback
          end
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey => e
        # Clean up and show user-friendly error
        Rails.logger.error "Registration failed: #{e.message}"
        build_resource(sign_up_params) if resource.nil?
        resource&.errors&.add(:base, 'Registration could not be completed. Please try again.')
        respond_with resource
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
        devise_parameter_sanitizer.permit(:sign_up, keys: [person_attributes: %i[identifier name description]])
      end

      def set_required_agreements
        @privacy_policy_agreement = BetterTogether::Agreement.find_by(identifier: 'privacy_policy')
        @terms_of_service_agreement = BetterTogether::Agreement.find_by(identifier: 'terms_of_service')
        @code_of_conduct_agreement = BetterTogether::Agreement.find_by(identifier: 'code_of_conduct')
      end

      # Hook method for host applications to implement captcha validation
      # Override this method in host applications to add Turnstile or other captcha validation
      # @return [Boolean] true if captcha is valid or not enabled, false if validation fails
      def validate_captcha_if_enabled?
        # Default implementation - no captcha validation
        # Host applications should override this method to implement their captcha logic
        true
      end

      # Hook method for host applications to handle captcha validation failures
      # Override this method in host applications to customize error handling
      # @param resource [User] the user resource being created
      def handle_captcha_validation_failure(resource)
        # Default implementation - adds a generic error message
        resource.errors.add(:base, I18n.t('better_together.registrations.captcha_validation_failed',
                                          default: 'Security verification failed. Please try again.'))
        respond_with resource
      end

      def after_sign_up_path_for(resource) # rubocop:todo Metrics/CyclomaticComplexity
        # Try to get redirect path from invitations
        invitation_path = after_sign_up_path_from_invitations
        return invitation_path if invitation_path

        if is_navigational_format? && helpers.host_platform&.privacy_private?
          return better_together.new_user_session_path
        end

        super
      end

      def determine_community_role
        determine_community_role_from_invitations
      end

      def handle_agreements_not_accepted
        build_resource(sign_up_params)
        resource.errors.add(:base, I18n.t('devise.registrations.new.agreements_required'))
        respond_with resource
      end

      def handle_user_creation(user)
        # Ensure person exists - either update existing from invitation or create new
        return unless ensure_person_exists?(user)

        # Reload user to ensure all nested attributes and associations are properly loaded
        user.reload
        person = user.person

        return unless person_persisted?(user, person)

        setup_community_membership(user, person)
        handle_all_invitations(user)
        create_agreement_participants(person)
      end

      def ensure_person_exists?(user)
        # If user already has a person (from invitation with existing user), keep it as-is
        if user.person.present? && person_comes_from_invitation?(user)
          Rails.logger.info "Using existing person from invitation: #{user.person.identifier}"
          return true
        elsif user.person.present?
          # Person exists but not from invitation - update with form params
          return update_person_from_invitation_params?(user, person_params)
        end

        # Otherwise, set up person for user (either from invitation or create new)
        setup_person_for_user(user)
        true
      end

      def person_comes_from_invitation?(user)
        # Check if the current person is the invitee from any invitation type
        [@community_invitation, @event_invitation, @platform_invitation].any? do |invitation|
          invitation&.invitee == user.person
        end
      end

      def invitation_person_updated?(user) # rubocop:todo Metrics/AbcSize
        update_person_from_invitation_params?(user, person_params)
      end

      def person_persisted?(user, person)
        return true if person&.persisted?

        Rails.logger.error "Person not found or not persisted for user #{user.id}"
        false
      end

      def setup_person_for_user(user)
        # Check all invitation types for existing invitee
        if @event_invitation&.invitee.present?
          return update_existing_person_for_event(user)
        elsif @community_invitation&.invitee.present?
          return update_existing_person_for_community(user)
        elsif @platform_invitation&.invitee.present?
          return update_existing_person_for_platform(user)
        end

        create_new_person_for_user(user)
      end

      def update_existing_person_for_community(user)
        user.person = @community_invitation.invitee
        return if user.person.update(person_params)

        Rails.logger.error "Failed to update person for community invitation: #{user.person.errors.full_messages}"
        user.errors.add(:person, 'Could not update person information')
      end

      def update_existing_person_for_platform(user)
        user.person = @platform_invitation.invitee
        return if user.person.update(person_params)

        Rails.logger.error "Failed to update person for platform invitation: #{user.person.errors.full_messages}"
        user.errors.add(:person, 'Could not update person information')
      end

      def update_existing_person_for_event(user)
        user.person = @event_invitation.invitee
        return if user.person.update(person_params)

        Rails.logger.error "Failed to update person for event invitation: #{user.person.errors.full_messages}"
        user.errors.add(:person, 'Could not update person information')
      end

      def create_new_person_for_user(user)
        return handle_empty_person_params(user) if person_params.empty?

        user.build_person(person_params)
        return unless person_validated_and_saved?(user)

        save_person_identification(user)
      end

      def handle_empty_person_params(user)
        Rails.logger.error 'Person params are empty, cannot build person'
        user.errors.add(:person, 'Person information is required')
      end

      def person_validated_and_saved?(user)
        # Try to save the person even if validation fails - some validation errors
        # shouldn't prevent account creation (e.g., empty names can be fixed later)
        return save_person?(user) if user.person.valid?

        # For invalid persons, try to save anyway but fix critical issues
        fix_critical_person_validation_issues(user)
        save_person_without_validation?(user)
      end

      def fix_critical_person_validation_issues(user)
        # Set a temporary name if it's empty to pass validation
        return unless user.person.name.blank?

        user.person.name = "User #{SecureRandom.hex(4)}"
        Rails.logger.info "Set temporary name for person: #{user.person.name}"
      end

      def save_person_without_validation?(user)
        return true if user.person.save(validate: false)

        Rails.logger.error "Failed to save person without validation: #{user.person.errors.full_messages}"
        user.errors.add(:person, 'Could not save person information')
        false
      end

      def save_person?(user)
        return true if user.person.save

        Rails.logger.error "Failed to save person: #{user.person.errors.full_messages}"
        user.errors.add(:person, 'Could not save person information')
        false
      end

      def save_person_identification(user)
        person_identification = user.person_identification
        return if person_identification&.save

        Rails.logger.error "Failed to save person identification: #{person_identification&.errors&.full_messages}"
        user.errors.add(:person, 'Could not link person to user')
      end

      def setup_community_membership(user, person_param = nil)
        person = person_param || user.person
        community_role = determine_community_role

        begin
          helpers.host_community.person_community_memberships.find_or_create_by!(
            member: person,
            role: community_role
          )
        rescue ActiveRecord::InvalidForeignKey => e
          Rails.logger.error "Foreign key violation creating community membership: #{e.message}"
          raise e
        rescue StandardError => e
          Rails.logger.error "Unexpected error creating community membership: #{e.message}"
          raise e
        end
      end

      def after_inactive_sign_up_path_for(resource)
        if is_navigational_format? && helpers.host_platform&.privacy_private?
          return better_together.new_user_session_path
        end

        super
      end

      def after_update_path_for(_resource)
        better_together.edit_user_registration_path
      end

      def person_params
        return {} unless params[:user] && params[:user][:person_attributes]

        params.require(:user).require(:person_attributes).permit(%i[identifier name description])
      rescue ActionController::ParameterMissing => e
        Rails.logger.error "Missing person parameters: #{e.message}"
        {}
      end

      def agreements_accepted?
        # Ensure required agreements are set
        set_required_agreements if @privacy_policy_agreement.nil?

        required = [params[:privacy_policy_agreement], params[:terms_of_service_agreement]]
        # If a code of conduct agreement exists, require it as well
        required << params[:code_of_conduct_agreement] if @code_of_conduct_agreement.present?

        required.all? { |v| v == '1' }
      end

      # Process invitation_code parameter and store in session if present
      def process_invitation_code_parameters
        return unless params[:invitation_code].present?

        # Find the invitation by token
        invitation = BetterTogether::Invitation.find_by(token: params[:invitation_code])
        return unless invitation

        # Determine invitation type and store both in session and instance variables
        invitation_type = determine_invitation_type(invitation)
        return unless invitation_type

        store_invitation_token_in_session(invitation, invitation_type)
        # Also directly set the instance variable for immediate use
        store_invitation_instance(invitation_type, invitation)
      end

      # Determine the invitation type from the invitation class
      def determine_invitation_type(invitation)
        case invitation
        when BetterTogether::CommunityInvitation
          :community
        when BetterTogether::EventInvitation
          :event
        when BetterTogether::PlatformInvitation
          :platform
        end
      end

      def create_agreement_participants(person)
        unless person&.persisted?
          Rails.logger.error 'Cannot create agreement participants - person not persisted'
          return
        end

        identifiers = %w[privacy_policy terms_of_service]
        identifiers << 'code_of_conduct' if BetterTogether::Agreement.exists?(identifier: 'code_of_conduct')
        agreements = BetterTogether::Agreement.where(identifier: identifiers)

        agreements.find_each do |agreement|
          BetterTogether::AgreementParticipant.create!(
            agreement: agreement,
            person: person,
            accepted_at: Time.current
          )
        end
      end
    end
  end
end

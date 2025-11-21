# frozen_string_literal: true

module BetterTogether
  module Users
    # Override default Devise registrations controller
    class RegistrationsController < ::Devise::RegistrationsController # rubocop:todo Metrics/ClassLength
      include DeviseLocales

      skip_before_action :check_platform_privacy
      before_action :configure_permitted_parameters
      before_action :set_required_agreements, only: %i[new create]
      before_action :set_event_invitation_from_session, only: %i[new create]
      before_action :set_community_invitation_from_session, only: %i[new create]
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

      def after_sign_up_path_for(resource)
        # Redirect to community if signed up via community invitation
        return better_together.community_path(@community_invitation.invitable) if @community_invitation&.invitable

        # Redirect to event if signed up via event invitation
        return better_together.event_path(@event_invitation.event) if @event_invitation&.event

        if is_navigational_format? && helpers.host_platform&.privacy_private?
          return better_together.new_user_session_path
        end

        super
      end

      def set_event_invitation_from_session
        return unless session[:event_invitation_token].present?

        # Check if session token is still valid
        return if session[:event_invitation_expires_at].present? &&
                  Time.current > session[:event_invitation_expires_at]

        @event_invitation = ::BetterTogether::EventInvitation.pending.not_expired
                                                             .find_by(token: session[:event_invitation_token])

        nil if @event_invitation
      end

      def set_community_invitation_from_session
        return unless session[:community_invitation_token].present?

        # Check if session token is still valid
        return if session[:community_invitation_expires_at].present? &&
                  Time.current > session[:community_invitation_expires_at]

        @community_invitation = ::BetterTogether::CommunityInvitation.pending.not_expired
                                                                     .find_by(token: session[:community_invitation_token])

        nil if @community_invitation
      end

      def determine_community_role
        return @platform_invitation.community_role if @platform_invitation

        # For community invitations, use the invitation's role
        return @community_invitation.role if @community_invitation && @community_invitation.role.present?

        # For event invitations, use the event creator's community
        return @event_invitation.role if @event_invitation && @event_invitation.role.present?

        # Default role
        ::BetterTogether::Role.find_by(identifier: 'community_member')
      end

      def handle_agreements_not_accepted
        build_resource(sign_up_params)
        resource.errors.add(:base, I18n.t('devise.registrations.new.agreements_required'))
        respond_with resource
      end

      def setup_user_from_invitations(user)
        # Pre-fill email from platform invitation
        user.email = @platform_invitation.invitee_email if @platform_invitation && user.email.empty?

        # Pre-fill email from community invitation
        if @community_invitation
          user.email = @community_invitation.invitee_email if @community_invitation && user.email.empty?
          user.person = @community_invitation.invitee if @community_invitation.invitee.present?
          return
        end

        return unless @event_invitation

        # Pre-fill email from event invitation
        user.email = @event_invitation.invitee_email if @event_invitation && user.email.empty?
        user.person = @event_invitation.invitee if @event_invitation.invitee.present?
      end

      def handle_user_creation(user)
        return unless invitation_person_updated?(user)

        # Reload user to ensure all nested attributes and associations are properly loaded
        user.reload
        person = user.person

        return unless person_persisted?(user, person)

        setup_community_membership(user, person)
        handle_platform_invitation(user)
        handle_community_invitation(user)
        handle_event_invitation(user)
        create_agreement_participants(person)
      end

      def invitation_person_updated?(user)
        # Check community invitation first
        if @community_invitation&.invitee.present?
          return true if user.person.update(person_params)

          Rails.logger.error "Failed to update person for community invitation: #{user.person.errors.full_messages}"
          return false

        end

        # Check event invitation
        if @event_invitation&.invitee.present?
          return true if user.person.update(person_params)

          Rails.logger.error "Failed to update person for event invitation: #{user.person.errors.full_messages}"
          return false

        end

        true
      end

      def event_invitation_person_updated?(user)
        return true unless @event_invitation&.invitee.present?

        return true if user.person.update(person_params)

        Rails.logger.error "Failed to update person for event invitation: #{user.person.errors.full_messages}"
        false
      end

      def person_persisted?(user, person)
        return true if person&.persisted?

        Rails.logger.error "Person not found or not persisted for user #{user.id}"
        false
      end

      def setup_person_for_user(user)
        return update_existing_person_for_event(user) if @event_invitation&.invitee.present?

        create_new_person_for_user(user)
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
        return save_person?(user) if user.person.valid?

        Rails.logger.error "Person validation failed: #{user.person.errors.full_messages}"
        user.errors.add(:person, 'Person information is invalid')
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

      def handle_platform_invitation(user)
        return unless @platform_invitation

        if @platform_invitation.platform_role
          helpers.host_platform.person_platform_memberships.create!(
            member: user.person,
            role: @platform_invitation.platform_role
          )
        end

        @platform_invitation.accept!(invitee: user.person)
      end

      def handle_event_invitation(user)
        return unless @event_invitation

        @event_invitation.update!(invitee: user.person)
        @event_invitation.accept!(invitee_person: user.person)

        # Clear session data
        session.delete(:event_invitation_token)
        session.delete(:event_invitation_expires_at)
      end

      def handle_community_invitation(user)
        return unless @community_invitation

        @community_invitation.update!(invitee: user.person)
        @community_invitation.accept!(invitee_person: user.person)

        # Clear session data
        session.delete(:community_invitation_token)
        session.delete(:community_invitation_expires_at)
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

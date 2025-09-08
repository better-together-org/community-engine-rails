# frozen_string_literal: true

module BetterTogether
  module Users
    # Override default Devise registrations controller
    class RegistrationsController < ::Devise::RegistrationsController # rubocop:todo Metrics/ClassLength
      include DeviseLocales

      skip_before_action :check_platform_privacy
      before_action :set_required_agreements, only: %i[new create]
      before_action :set_event_invitation_from_session, only: %i[new create]
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
          # Pre-fill email from platform invitation
          user.email = @platform_invitation.invitee_email if @platform_invitation && user.email.empty?

          if @event_invitation
            # Pre-fill email from event invitation
            user.email = @event_invitation.invitee_email if @event_invitation && user.email.empty?
            user.person = @event_invitation.invitee if @event_invitation.invitee.present?
          end
        end
      end

      def create # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
        unless agreements_accepted?
          build_resource(sign_up_params)
          resource.errors.add(:base, I18n.t('devise.registrations.new.agreements_required'))
          respond_with resource
          return
        end

        ActiveRecord::Base.transaction do # rubocop:todo Metrics/BlockLength
          super do |user|
            return unless user.persisted?

            if @event_invitation && @event_invitation.invitee.present?
              user.person = @event_invitation.invitee
              user.person.update(person_params)
            else
              user.build_person(person_params)
            end

            if user.save!
              user.reload

              # Handle community membership based on invitation type
              community_role = determine_community_role

              helpers.host_community.person_community_memberships.find_or_create_by!(
                member: user.person,
                role: community_role
              )

              # Handle platform invitation
              if @platform_invitation
                if @platform_invitation.platform_role
                  helpers.host_platform.person_platform_memberships.create!(
                    member: user.person,
                    role: @platform_invitation.platform_role
                  )
                end

                @platform_invitation.accept!(invitee: user.person)
              end

              # Handle event invitation
              if @event_invitation
                @event_invitation.update!(invitee: user.person)
                @event_invitation.accept!(invitee_person: user.person)

                # Clear session data
                session.delete(:event_invitation_token)
                session.delete(:event_invitation_expires_at)
              end

              create_agreement_participants(user.person)
            end
          end
        end
      end

      protected

      def account_update_params
        devise_parameter_sanitizer.sanitize(:account_update)
      end

      def configure_account_update_params
        devise_parameter_sanitizer.permit(:account_update,
                                          keys: %i[email password password_confirmation current_password])
      end

      def set_required_agreements
        @privacy_policy_agreement = BetterTogether::Agreement.find_by(identifier: 'privacy_policy')
        @terms_of_service_agreement = BetterTogether::Agreement.find_by(identifier: 'terms_of_service')
        @code_of_conduct_agreement = BetterTogether::Agreement.find_by(identifier: 'code_of_conduct')
      end

      def after_sign_up_path_for(resource)
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

      def determine_community_role
        return @platform_invitation.community_role if @platform_invitation

        # For event invitations, use the event creator's community
        return @event_invitation.role if @event_invitation && @event_invitation.role.present?

        # Default role
        ::BetterTogether::Role.find_by(identifier: 'community_member')
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
        params.require(:user).require(:person_attributes).permit(%i[identifier name description])
      end

      def agreements_accepted?
        required = [params[:privacy_policy_agreement], params[:terms_of_service_agreement]]
        # If a code of conduct agreement exists, require it as well
        required << params[:code_of_conduct_agreement] if @code_of_conduct_agreement.present?

        required.all? { |v| v == '1' }
      end

      def create_agreement_participants(person)
        identifiers = %w[privacy_policy terms_of_service]
        identifiers << 'code_of_conduct' if BetterTogether::Agreement.exists?(identifier: 'code_of_conduct')
        agreements = BetterTogether::Agreement.where(identifier: identifiers)
        agreements.find_each do |agreement|
          BetterTogether::AgreementParticipant.create!(agreement: agreement, person: person, accepted_at: Time.current)
        end
      end
    end
  end
end

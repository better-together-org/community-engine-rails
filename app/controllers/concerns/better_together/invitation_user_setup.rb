# frozen_string_literal: true

module BetterTogether
  # Module for setting up users from invitation data
  # Handles pre-filling user information and person assignment from invitations
  module InvitationUserSetup
    extend ActiveSupport::Concern

    private

    # Unified user setup from any invitation type
    def setup_user_from_invitations(user)
      invitation_types = %i[platform community event]

      # Find first available invitation and set it up
      invitation_types.find do |type|
        invitation = instance_variable_get("@#{type}_invitation")
        next unless invitation

        setup_user_from_invitation(user, invitation, type)
        true # Signal we found and processed an invitation
      end
    end

    # Setup user from specific invitation
    def setup_user_from_invitation(user, invitation, invitation_type)
      prefill_user_email(user, invitation, invitation_type)
      assign_existing_person_if_available(user, invitation, invitation_type)
    end

    # Pre-fill user email from invitation if user email is empty
    def prefill_user_email(user, invitation, invitation_type)
      return unless user.email.empty?

      case invitation_type
      when :platform
        # Platform invitations use email as-is
      end
      user.email = invitation.invitee_email if invitation.invitee_email.present?
    end

    # Assign existing person from invitation if available
    def assign_existing_person_if_available(user, invitation, invitation_type)
      return unless %i[community event].include?(invitation_type)
      return unless invitation.invitee.present?

      user.person = invitation.invitee
    end

    # Update person from invitation parameters
    # @param user [User] The user whose person should be updated
    # @param person_params [Hash] The parameters for updating the person
    # @return [Boolean] true if update succeeded or not needed, false if failed
    def update_person_from_invitation_params?(user, person_params = {})
      invitation_types = %i[community event]

      invitation_types.each do |type|
        invitation = instance_variable_get("@#{type}_invitation")
        next unless invitation&.invitee.present?

        return true if user.person.update(person_params)

        Rails.logger.error "Failed to update person for #{type} invitation: #{user.person.errors.full_messages}"
        return false
      end

      true # No invitation person updates needed
    end

    # Determine community role from any available invitation
    def determine_community_role_from_invitations
      return @platform_invitation.community_role if @platform_invitation&.community_role
      return @community_invitation.role if @community_invitation&.role.present?
      return @event_invitation.role if @event_invitation&.role.present?

      # Default role
      ::BetterTogether::Role.find_by(identifier: 'community_member')
    end

    # Get redirect path after sign up based on available invitations
    def after_sign_up_path_from_invitations
      # Priority order: community, event, default
      return better_together.community_path(@community_invitation.invitable) if @community_invitation&.invitable
      return better_together.event_path(@event_invitation.invitable) if @event_invitation&.invitable

      nil # Let calling controller handle default
    end
  end
end

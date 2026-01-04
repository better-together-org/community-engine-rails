# frozen_string_literal: true

module BetterTogether
  # Concern for managing invitation tokens in user sessions across all invitation types
  # Provides unified session handling for registration and authentication flows
  # This module coordinates multiple invitation concerns and provides a unified interface
  # rubocop:disable Metrics/ModuleLength
  module InvitationSessionManagement
    extend ActiveSupport::Concern

    include InvitationTokenSession
    include InvitationUserSetup

    included do
      # Add before_action hooks for controllers that need invitation session management
      # Individual controllers can selectively include these
    end

    private

    # Unified method to load invitation from session for any invitation type
    # @param invitation_type [Symbol] The type of invitation (:event, :community, :platform)
    # @return [Object, nil] The invitation instance or nil
    def load_invitation_from_session(invitation_type)
      token_key = "#{invitation_type}_invitation_token"
      expires_key = "#{invitation_type}_invitation_expires_at"

      return unless valid_session_token?(token_key, expires_key)

      invitation = find_invitation_by_token(invitation_type, session[token_key])
      store_invitation_instance(invitation_type, invitation) if invitation
      invitation
    end

    # Load all invitation types from session
    def load_all_invitations_from_session
      %i[event community platform].each do |type|
        load_invitation_from_session(type)
      end
    end

    # Check if any valid invitation exists in session
    def valid_invitation_in_session?
      %i[community event platform].any? do |type|
        valid_invitation_for_type?(type)
      end
    end

    # Check if specific invitation type is valid in session
    def valid_invitation_for_type?(invitation_type)
      token_key = "#{invitation_type}_invitation_token"
      expires_key = "#{invitation_type}_invitation_expires_at"

      token = session[token_key]
      return false unless token.present?

      # Check expiry
      expires_at = session[expires_key]
      return false if expires_at.present? && Time.current > expires_at

      # Check invitation exists and is valid
      invitation_class = invitation_class_for_type(invitation_type)
      invitation_class.pending.not_expired.exists?(token: token)
    end

    # Unified invitation handling in user creation
    def handle_all_invitations(user)
      %i[platform community event].each do |type|
        invitation = instance_variable_get("@#{type}_invitation")
        next unless invitation

        handle_invitation_by_type(user, invitation, type)
      end
    end

    # Handle specific invitation type
    def handle_invitation_by_type(user, invitation, invitation_type)
      case invitation_type
      when :platform
        handle_platform_invitation_acceptance(user, invitation)
      when :community
        handle_community_invitation_acceptance(user, invitation)
      when :event
        handle_event_invitation_acceptance(user, invitation)
      end

      clear_invitation_session_data(invitation_type)
    end

    # Generic invitation acceptance handling
    def handle_invitation_acceptance(user, invitation, invitation_type)
      # Update invitee if needed
      invitation.update!(invitee: user.person) unless invitation.invitee == user.person

      # Accept the invitation
      invitation.accept!(invitee_person: user.person)

      # Clear session data
      clear_invitation_session_data(invitation_type)
    end

    # Platform-specific invitation acceptance
    def handle_platform_invitation_acceptance(user, invitation)
      if invitation.platform_role
        helpers.host_platform.person_platform_memberships.create!(
          member: user.person,
          role: invitation.platform_role
        )
      end

      invitation.accept!(invitee: user.person)
    end

    # Community-specific invitation acceptance
    def handle_community_invitation_acceptance(user, invitation)
      handle_invitation_acceptance(user, invitation, :community)
    end

    # Event-specific invitation acceptance
    def handle_event_invitation_acceptance(user, invitation)
      handle_invitation_acceptance(user, invitation, :event)
    end

    # Unified invitation token processing for privacy checks
    def process_invitation_token_for_privacy(invitation_type, resource)
      invitation_token = params[:invitation_token] || session["#{invitation_type}_invitation_token"]
      return unless invitation_token.present?

      invitation_class = invitation_class_for_type(invitation_type)
      invitation = invitation_class.pending.not_expired.find_by(
        token: invitation_token,
        invitable: resource
      )

      if invitation
        store_invitation_token_in_session(invitation, invitation_type)
      else
        clear_invitation_session_data(invitation_type)
      end

      invitation
    end

    # Check if session token exists and is not expired
    def valid_session_token?(token_key, expires_key)
      return false unless session[token_key].present?
      return false if session_token_expired?(expires_key)

      true
    end

    # Check if session token has expired
    def session_token_expired?(expires_key)
      expires_at = session[expires_key]
      expires_at.present? && Time.current > expires_at
    end

    # Find invitation by token for given type
    def find_invitation_by_token(invitation_type, token)
      invitation_class = invitation_class_for_type(invitation_type)
      invitation_class.pending.not_expired.find_by(token: token)
    end

    # Store invitation instance in instance variable
    def store_invitation_instance(invitation_type, invitation)
      instance_variable_set("@#{invitation_type}_invitation", invitation)
    end

    # Get invitation class for invitation type
    def invitation_class_for_type(invitation_type)
      case invitation_type.to_sym
      when :event
        ::BetterTogether::EventInvitation
      when :community
        ::BetterTogether::CommunityInvitation
      when :platform
        ::BetterTogether::PlatformInvitation
      else
        raise ArgumentError, "Unknown invitation type: #{invitation_type}"
      end
    end

    # Class methods for setting up invitation session management in controllers
    module ClassMethods
      # Define before_action hooks for different invitation scenarios
      def setup_invitation_session_management_for_registration
        before_action :load_all_invitations_from_session, only: %i[new create]
      end

      def setup_invitation_token_processing_for_privacy(invitation_type)
        before_action -> { process_invitation_token_for_privacy(invitation_type, instance_variable_get("@#{invitation_type.to_s.singularize}")) }
      end
    end
  end
  # rubocop:enable Metrics/ModuleLength
end

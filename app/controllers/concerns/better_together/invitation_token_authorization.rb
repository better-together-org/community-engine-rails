# frozen_string_literal: true

module BetterTogether
  # Concern to override Pundit's authorize method to support invitation token authorization
  # This allows policies to receive invitation tokens for context-aware authorization
  # Also provides shared invitation token handling methods for controllers
  module InvitationTokenAuthorization
    extend ActiveSupport::Concern

    included do
      attr_reader :current_invitation_token
    end

    private

    # Override Pundit's authorize method to pass invitation token to policies
    # @param record [Object] The record to authorize
    # @param query [Symbol] The policy method to call (defaults to action query) - can be positional or keyword arg
    # @param policy_class [Class] Optional policy class override
    # @return [Object] The authorized record
    def authorize(record, query = nil, policy_class: nil)
      # Handle both old syntax: authorize(record, :query?) and new syntax: authorize(record, query: :query?)
      query ||= "#{action_name}?"
      policy_class ||= policy_class_for(record)

      # Create policy instance with invitation token
      policy = policy_class.new(current_user, record, invitation_token: current_invitation_token)

      # Check authorization
      raise Pundit::NotAuthorizedError, query: query, record: record, policy: policy unless policy.public_send(query)

      # Mark that authorization was performed (required for verify_authorized)
      @_pundit_policy_authorized = true

      record
    end

    # Override Pundit's policy_scope method to pass invitation token to policy scopes
    # @param scope [Class] The scope class (typically a model class)
    # @param policy_scope_class [Class] Optional policy scope class override
    # @return [Object] The scoped collection
    def policy_scope(scope, policy_scope_class: nil, invitation_token: nil)
      policy_scope_class ||= policy_scope_class_for(scope)

      # Use provided invitation token or fall back to current
      token = invitation_token || current_invitation_token

      # Create policy scope instance with invitation token
      scope = policy_scope_class.new(current_user, scope, invitation_token: token).resolve

      @_pundit_policy_scoped = true

      scope
    end

    # Set the current invitation token for use in authorization
    # @param token [String] The invitation token
    def current_invitation_token=(token)
      @current_invitation_token = token
    end

    # Common invitation token handling methods

    # Extract invitation token from params or current token
    def extract_invitation_token
      params[:invitation_token].presence || params[:token].presence || current_invitation_token
    end

    # Find valid invitation by token for the current resource
    def find_valid_invitation(token)
      resource = instance_variable_get("@#{invitation_resource_name}")
      invitation_class = invitation_class_for_resource

      if resource
        invitation_class.pending.not_expired.find_by(token: token, invitable: resource)
      else
        invitation_class.pending.not_expired.find_by(token: token)
      end
    end

    # Persist invitation to session if token came from params
    def persist_invitation_to_session(invitation, _token)
      return unless token_came_from_params?

      store_invitation_in_session(invitation)
      locale_from_invitation(invitation)
      self.current_invitation_token = invitation.token
    end

    # Check if token came from request parameters
    def token_came_from_params?
      params[:invitation_token].present? || params[:token].present?
    end

    # Store invitation in session with resource-specific key
    def store_invitation_in_session(invitation)
      session_key = "#{invitation_resource_name}_invitation_token"
      expires_key = "#{invitation_resource_name}_invitation_expires_at"

      session[session_key] = invitation.token
      session[expires_key] = platform_invitation_expiry_time.from_now
    end

    # Set locale from invitation
    def locale_from_invitation(invitation)
      return unless invitation.locale.present?

      I18n.locale = invitation.locale
      session[:locale] = I18n.locale
    end

    # Common privacy check override pattern
    def extract_invitation_token_for_privacy
      session_key = "#{invitation_resource_name}_invitation_token"
      params[:invitation_token].presence || params[:token].presence || session[session_key].presence
    end

    def platform_public_or_user_authenticated?
      helpers.host_platform.privacy_public? || current_user.present?
    end

    def token_and_params_present?(token)
      token.present? && params[:id].present?
    end

    def find_any_invitation_by_token(token)
      invitation_class_for_resource.find_by(token: token)
    end

    # Template methods - controllers should implement these

    # Return the resource name (e.g., 'event', 'community')
    def invitation_resource_name
      raise NotImplementedError, 'Subclasses must implement invitation_resource_name'
    end

    # Return the invitation class for this resource type
    def invitation_class_for_resource
      raise NotImplementedError, 'Subclasses must implement invitation_class_for_resource'
    end

    # Helper method to determine policy class for a record
    # @param record [Object] The record to find policy for
    # @return [Class] The policy class
    def policy_class_for(record)
      if record.is_a?(Class)
        "#{record.name}Policy".constantize
      else
        "#{record.class.name}Policy".constantize
      end
    end

    # Helper method to determine policy scope class for a scope
    # @param scope [Class] The scope class
    # @return [Class] The policy scope class
    def policy_scope_class_for(scope)
      "#{scope.name}Policy::Scope".constantize
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  # Concern to override Pundit's authorize method to support invitation token authorization
  # This allows policies to receive invitation tokens for context-aware authorization
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
      policy_scope_class.new(current_user, scope, invitation_token: token).resolve
    end

    # Set the current invitation token for use in authorization
    # @param token [String] The invitation token
    def set_current_invitation_token(token)
      @current_invitation_token = token
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

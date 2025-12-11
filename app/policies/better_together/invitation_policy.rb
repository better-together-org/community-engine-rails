# frozen_string_literal: true

module BetterTogether
  # Base invitation policy class providing common authorization logic for invitation-related resources
  # This class defines standard invitation operations and delegates invitable-specific logic to subclasses
  class InvitationPolicy < ApplicationPolicy
    def create?
      return false unless user.present?

      # Check specific permissions for the invitable resource
      return true if allowed_on_invitable?

      permitted_to?('manage_platform')
    end

    def destroy?
      user.present? && record.status_pending? && allowed_on_invitable?
    end

    def resend?
      user.present? && record.status_pending? && allowed_on_invitable?
    end

    # Base scope class for invitation policies providing common filtering logic
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless user.present?
        return scope.all if permitted_to?('manage_platform')

        # Users see invitations for resources they can manage
        filtered_invitations_scope
      end

      protected

      # Template method to be implemented by subclasses
      def filtered_invitations_scope
        raise NotImplementedError, "#{self.class} must implement #filtered_invitations_scope"
      end

      # Helper method for building invitable type conditions
      def invitable_type_condition(type_class)
        scope.joins(:invitable)
             .where(better_together_invitations: { invitable_type: type_class.name })
      end
    end

    protected

    # Template method to be implemented by subclasses
    def allowed_on_invitable?
      raise NotImplementedError, "#{self.class} must implement #allowed_on_invitable?"
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  # Base invitation policy class providing common authorization logic for invitation-related resources
  # This class defines standard invitation operations and delegates invitable-specific logic to subclasses
  class InvitationPolicy < ApplicationPolicy
    def create?
      return false unless user.present?

      allowed_on_invitable?
    end

    def destroy?
      user.present? && record.status_pending? && allowed_on_invitable?
    end

    def resend?
      return false unless user.present? && allowed_on_invitable?

      # Allow resending for pending or declined invitations
      record.status_pending? || record.status_declined?
    end

    # Base scope class for invitation policies providing common filtering logic
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless user.present?

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
        scope.where(invitable_type: type_class.name)
      end
    end

    protected

    def allowed_on_invitable?
      invitable = resolved_invitable
      return false unless invitable

      community_invitable_allowed?(invitable) || event_invitable_allowed?(invitable)
    end

    def resolved_invitable
      return record.invitable if record.respond_to?(:invitable) && record.invitable.present?

      invitable_type = record.try(:invitable_type)
      invitable_id = record.try(:invitable_id)
      return nil if invitable_type.blank? || invitable_id.blank?

      invitable_type.constantize.find_by(id: invitable_id)
    rescue NameError
      nil
    end

    def event_host_match?(event)
      return false unless agent&.valid_event_host_ids&.any?

      event.event_hosts.where(host_id: agent.valid_event_host_ids).exists?
    end

    def community_invitable_allowed?(invitable)
      return false unless invitable.is_a?(BetterTogether::Community)

      permitted_to?('invite_community_members', invitable) ||
        permitted_to?('manage_community_members', invitable) ||
        permitted_to?('manage_community_roles', invitable)
    end

    def event_invitable_allowed?(invitable)
      return false unless invitable.is_a?(BetterTogether::Event) && agent.present?

      invitable.creator == agent || event_host_match?(invitable)
    end
  end
end

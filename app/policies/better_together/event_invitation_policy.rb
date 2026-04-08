# frozen_string_literal: true

module BetterTogether
  # Authorization policy for event invitations
  # Defines who can view, create, update, and manage event invitations
  class EventInvitationPolicy < InvitationPolicy
    # Scope class for filtering event invitations based on user permissions
    class Scope < InvitationPolicy::Scope
      private

      def filtered_invitations_scope
        return scope.none unless user&.person

        invitable_type_condition(BetterTogether::Event)
          .where(invitable_id: manageable_event_ids)
      end

      def manageable_event_ids
        person_event_ids = BetterTogether::Event.where(creator_id: agent.id).select(:id)
        hosted_event_ids = BetterTogether::EventHost.where(host_id: agent.valid_event_host_ids).select(:event_id)

        person_event_ids.or(BetterTogether::Event.where(id: hosted_event_ids)).select(:id)
      end
    end

    private

    def allowed_on_invitable?
      event = record.invitable
      return false unless event.is_a?(BetterTogether::Event)
      return false unless agent

      event.creator == agent || event_host_match?(event)
    end

    def event_host_match?(event)
      return false unless agent.valid_event_host_ids.any?

      event.event_hosts.where(host_id: agent.valid_event_host_ids).exists?
    end
  end
end

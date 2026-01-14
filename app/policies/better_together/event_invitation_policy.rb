# frozen_string_literal: true

module BetterTogether
  # Authorization policy for event invitations
  # Defines who can view, create, update, and manage event invitations
  class EventInvitationPolicy < InvitationPolicy
    # Scope class for filtering event invitations based on user permissions
    class Scope < InvitationPolicy::Scope
      private

      def filtered_invitations_scope
        invitable_type_condition(BetterTogether::Event)
          .where(manageable_events_condition)
      end

      def manageable_events_condition
        [
          'better_together_events.creator_id = ? OR ' \
          'EXISTS (SELECT 1 FROM better_together_event_hosts ' \
          'WHERE better_together_event_hosts.event_id = better_together_events.id ' \
          'AND better_together_event_hosts.host_type = ? ' \
          'AND better_together_event_hosts.host_id = ?)',
          user.person&.id, 'BetterTogether::Person', user.person&.id
        ]
      end
    end

    private

    def allowed_on_invitable?
      event = record.invitable
      return false unless event.is_a?(BetterTogether::Event)

      # Platform managers may act across events
      return true if permitted_to?('manage_platform')

      ep = BetterTogether::EventPolicy.new(user, event)
      # Event hosts or event creator
      ep.event_host_member? || (user.present? && event.creator == agent)
    end

    def event_host_member?
      return false unless user&.person && record.invitable.is_a?(BetterTogether::Event)

      record.invitable.event_hosts.exists?(host_type: 'BetterTogether::Person', host_id: user.person.id)
    end
  end
end

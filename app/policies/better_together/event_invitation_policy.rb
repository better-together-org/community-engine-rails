# frozen_string_literal: true

module BetterTogether
  class EventInvitationPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def create?
      return false unless user.present?

      # Event creator and hosts can invite people
      return true if allowed_on_event?

      permitted_to?('manage_platform') || event_host_member?
    end

    def destroy?
      user.present? && record.status == 'pending' && allowed_on_event?
    end

    def resend?
      user.present? && record.status == 'pending' && allowed_on_event?
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        return scope.none unless user.present?
        return scope.all if permitted_to?('manage_platform')

        # Users see invitations for events they can manage
        event_invitations_scope
      end

      private

      def event_invitations_scope
        scope.joins(:invitable)
             .where(better_together_invitations: { invitable_type: 'BetterTogether::Event' })
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

    def allowed_on_event?
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

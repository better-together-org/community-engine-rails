# frozen_string_literal: true

module BetterTogether
  class EventInvitationPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    # Only platform managers may create event invitations for now
    def create?
      user.present? && permitted_to?('manage_platform')
    end

    def destroy?
      user.present? && record.status == 'pending' && allowed_on_event?
    end

    def resend?
      user.present? && record.status == 'pending' && allowed_on_event?
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        scope
      end
    end

    private

    def allowed_on_event?
      event = record.invitable
      return false unless event.is_a?(BetterTogether::Event)

      # Platform managers may act across events
      return true if permitted_to?('manage_platform')

      ep = BetterTogether::EventPolicy.new(user, event)
      # Organizer-only: event hosts or event creator (exclude platform-manager-only path)
      ep.event_host_member? || (user.present? && event.creator == agent)
    end
  end
end

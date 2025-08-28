# frozen_string_literal: true

module BetterTogether
  class EventInvitationPolicy < ApplicationPolicy
    def create?
      user.present? && allowed_on_event?
    end

    def destroy?
      user.present? && record.status == 'pending' && allowed_on_event?
    end

    def resend?
      user.present? && record.status == 'pending' && allowed_on_event?
    end

    class Scope < Scope
      def resolve
        scope
      end
    end

    private

    def allowed_on_event?
      event = record.invitable
      return false unless event.is_a?(BetterTogether::Event)

      ep = BetterTogether::EventPolicy.new(user, event)
      # Organizer-only: event hosts or event creator (exclude platform-manager-only path)
      ep.event_host_member? || (user.present? && event.creator == agent)
    end
  end
end

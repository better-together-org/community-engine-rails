# frozen_string_literal: true

module BetterTogether
  # Access control for event attendance (RSVPs)
  class EventAttendancePolicy < ApplicationPolicy
    def create?
      user.present?
    end

    def update?
      user.present? && record.person_id == agent&.id
    end

    alias rsvp_interested? update?
    alias rsvp_going? update?

    def destroy?
      update?
    end
  end
end

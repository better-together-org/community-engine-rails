# frozen_string_literal: true

module BetterTogether
  # Access control for event attendance (RSVPs)
  class EventAttendancePolicy < ApplicationPolicy
    def create?
      user.present? && event_allows_rsvp?
    end

    def update?
      user.present? && record.person_id == agent&.id && event_allows_rsvp?
    end

    alias rsvp_interested? update?
    alias rsvp_going? update?

    def destroy?
      update?
    end

    private

    def event_allows_rsvp?
      event = record&.event || record
      return false unless event

      # Don't allow RSVP for draft events (no start date)
      event.scheduled?
    end
  end
end

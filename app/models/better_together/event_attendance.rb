# frozen_string_literal: true

module BetterTogether
  # Tracks a person's RSVP to an event
  class EventAttendance < ApplicationRecord
    STATUS = {
      interested: 'interested',
      going: 'going'
    }.freeze

    belongs_to :event, class_name: 'BetterTogether::Event'
    belongs_to :person, class_name: 'BetterTogether::Person'

    validates :status, inclusion: { in: STATUS.values }
    validates :event_id, uniqueness: { scope: :person_id }
    validate :event_must_be_scheduled

    private

    def event_must_be_scheduled
      return unless event

      return if event.scheduled?

      errors.add(:event, 'must be scheduled to allow RSVPs')
    end
  end
end

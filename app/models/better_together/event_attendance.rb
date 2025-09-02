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
  end
end

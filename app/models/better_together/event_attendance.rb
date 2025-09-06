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

    after_save :manage_calendar_entry
    after_destroy :remove_calendar_entry

    private

    def event_must_be_scheduled
      return unless event

      return if event.scheduled?

      errors.add(:event, 'must be scheduled to allow RSVPs')
    end

    def manage_calendar_entry
      return unless saved_change_to_status? || saved_change_to_id?

      if status == 'going'
        create_calendar_entry
      else
        remove_calendar_entry
      end
    end

    def create_calendar_entry
      return if calendar_entry_exists?

      person.primary_calendar.calendar_entries.create!(
        event: event,
        starts_at: event.starts_at,
        ends_at: event.ends_at,
        duration_minutes: event.duration_minutes
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "Failed to create calendar entry for attendance #{id}: #{e.message}"
    end

    def remove_calendar_entry
      calendar_entry = person.primary_calendar.calendar_entries.find_by(event: event)
      calendar_entry&.destroy
    end

    def calendar_entry_exists?
      person.primary_calendar.calendar_entries.exists?(event: event)
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  # A thin, lazily-created override/attachment point for one specific
  # occurrence of a recurring Event. Only created when a session is actually
  # interacted with (RSVP, comment, or an organizer override) — most
  # occurrences of a series never get a row. Never duplicates hosting or
  # authorization data; EventOccurrencePolicy delegates those checks back to
  # the parent Event.
  class EventOccurrence < ApplicationRecord
    include Commentable
    include Geography::Locatable::One

    belongs_to :event, class_name: 'BetterTogether::Event', inverse_of: :event_occurrences

    has_rich_text :description_override

    has_many :event_attendances, class_name: 'BetterTogether::EventAttendance',
                                 foreign_key: :event_occurrence_id, inverse_of: :event_occurrence,
                                 dependent: :destroy

    validates :occurrence_date, presence: true, uniqueness: { scope: :event_id }
    validate :occurrence_date_matches_schedule

    after_commit :refresh_event_next_occurrence_at

    # Effective start time: the override if one has been set, else the
    # computed default from the parent's recurrence schedule for this date.
    def effective_starts_at
      starts_at || computed_starts_at
    end

    def effective_ends_at
      return ends_at if ends_at.present?
      return nil unless effective_starts_at && event&.duration_minutes.present?

      effective_starts_at + event.duration_minutes.minutes
    end

    def effective_location
      location.presence || event&.location
    end

    def effective_description
      description_override.present? ? description_override : event&.description
    end

    def self.permitted_attributes(id: false, destroy: false)
      attrs = %i[starts_at ends_at cancelled description_override]
      attrs << :id if id
      attrs << :_destroy if destroy
      attrs + [{
        location_attributes: BetterTogether::Geography::LocatableLocation.permitted_attributes(id: true, destroy: true)
      }]
    end

    private

    def computed_starts_at
      return nil unless occurrence_date && event&.recurrence

      # .to_time: coerce IceCube::Occurrence (a Time-like SimpleDelegator, not
      # a literal ::Time — see RecurringSchedulable#build_occurrence_for) so
      # every caller of effective_starts_at gets a genuine Time.
      event.recurrence.occurrences_between(occurrence_date.beginning_of_day, occurrence_date.end_of_day).first&.to_time
    end

    def occurrence_date_matches_schedule
      return if occurrence_date.blank? || event.blank?

      unless event.recurring?
        errors.add(:event, 'must be a recurring event to have occurrences')
        return
      end

      return if scheduled_dates_on(occurrence_date).include?(occurrence_date)

      errors.add(:occurrence_date, "is not a real occurrence of this event's recurrence rule")
    end

    def scheduled_dates_on(date)
      event.recurrence.occurrences_between(date.beginning_of_day, date.end_of_day).map(&:to_date)
    end

    def refresh_event_next_occurrence_at
      event&.refresh_next_occurrence_at!
    end
  end
end

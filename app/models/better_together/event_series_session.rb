# frozen_string_literal: true

module BetterTogether
  # Puts one event (the session) in a series (see EventSeries). A session belongs to one series; sessions on the
  # same day are fine, so nothing here looks at dates. Unlike EventOccurrence, which is one computed date of a
  # recurrence rule, a session is a full event of its own.
  class EventSeriesSession < ApplicationRecord
    belongs_to :series, class_name: 'BetterTogether::Event', inverse_of: :series_session_links
    belongs_to :session, class_name: 'BetterTogether::Event', inverse_of: :series_link

    validates :session_id, uniqueness: true
    validate :series_must_be_a_series
    validate :session_must_be_a_plain_event

    after_commit :refresh_series_span

    private

    def series_must_be_a_series
      errors.add(:series, :invalid) unless series&.series?
    end

    def session_must_be_a_plain_event
      return if session.blank?

      errors.add(:session, :invalid) if session.series? || session_id == series_id
    end

    def refresh_series_span
      series&.refresh_series_span!
    end
  end
end

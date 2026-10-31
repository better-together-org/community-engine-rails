# frozen_string_literal: true

module BetterTogether
  # A series is an event that groups the sessions of a run of dates, such as a play on several nights. Each session
  # is a full event (its own page, hosts, RSVPs, cover, tickets) linked through EventSeriesSession; the series
  # itself has no dates, hosts' RSVPs or recurrence of its own.
  #
  # * The series' starts_at, ends_at, duration_minutes and next_occurrence_at are a cache computed from its sessions
  #   (see #refresh_series_span!), never set by hand.
  # * A series is never sent to other platforms until federation understands it (federation_visibility is forced).
  # * Cancelling or deleting a series needs a choice for its sessions (see #session_disposition): cancel or delete
  #   them, or promote them to standalone events.
  # * +session_of+ (a series identifier) makes a new event a session of that series and fills in its hosts,
  #   categories, description, privacy and timezone from the series where it gave none. On an existing event
  #   that is in no series it only links it, changing nothing else (an ingester uses this to group events it first
  #   saw as single ones).
  # * Whether an event is a series is fixed when it is created.
  module EventSeries
    extend ActiveSupport::Concern

    # The hourly scan and every save call this; for a series the span is the answer, not its own starts_at.
    module SpanRefresh
      def refresh_next_occurrence_at!
        series? ? refresh_series_span! : super
      end
    end

    included do
      include BetterTogether::EventSeriesDisposition
      prepend SpanRefresh

      has_many :series_session_links, -> { order(:position, :created_at) },
               class_name: 'BetterTogether::EventSeriesSession', foreign_key: :series_id,
               inverse_of: :series, dependent: :destroy
      has_many :sessions, through: :series_session_links, source: :session
      has_one :series_link, class_name: 'BetterTogether::EventSeriesSession', foreign_key: :session_id,
                            inverse_of: :session, dependent: :destroy
      has_one :parent_series, through: :series_link, source: :series

      attr_accessor :session_of

      before_validation :join_series_from_session_of, prepend: true
      after_save { self.session_of = nil }
      before_validation :keep_series_private_to_federation, if: :series?
      after_commit :refresh_parent_series_span

      validate :series_has_no_dates_of_its_own, :series_does_not_recur, :series_is_not_a_session
      validate :session_of_must_name_a_series, :session_of_must_be_joinable, :series_flag_is_fixed
    end

    def session?
      series_link.present?
    end

    def refresh_series_span!
      return unless series? && persisted?

      span = series_span
      update_columns(span.merge(updated_at: Time.current))
    end

    private

    def live_sessions
      sessions.reject(&:status_cancelled?)
    end

    def series_span
      sessions.reload
      counted = live_sessions.presence || sessions.to_a
      starts = counted.filter_map(&:starts_at).min
      ends = counted.filter_map { |session| session.ends_at || session.starts_at }.max
      { starts_at: starts, ends_at: ends, duration_minutes: minutes_between(starts, ends),
        next_occurrence_at: next_session_start(counted) }
    end

    def minutes_between(starts, ends)
      ((ends - starts) / 60).round if starts && ends
    end

    def next_session_start(counted)
      starts = counted.filter_map(&:starts_at)
      starts.select { |time| time >= Time.current }.min || starts.max
    end

    def refresh_parent_series_span
      series_link&.series&.refresh_series_span!
    end

    def keep_series_private_to_federation
      self.federation_visibility = 'no_federate'
    end

    def series_has_no_dates_of_its_own
      return unless series? && (will_save_change_to_starts_at? || will_save_change_to_ends_at?)

      errors.add(:base, 'A series has no dates of its own; they come from its sessions')
    end

    def series_does_not_recur
      errors.add(:base, 'A series does not recur; its sessions are separate events') if series? && recurring?
    end

    def series_is_not_a_session
      errors.add(:base, 'A session cannot be a series') if series? && series_link.present?
    end

    def session_of_must_name_a_series
      return if session_of.blank? || series_named_by_session_of

      errors.add(:session_of, 'is not the identifier of a series')
    end

    def series_named_by_session_of
      self.class.find_by(identifier: session_of.to_s.downcase, series: true)
    end

    def session_of_must_be_joinable
      return if session_of.blank?

      errors.add(:session_of, 'is not allowed on a series') if series?
      errors.add(:session_of, 'is already a session of a series') if series_link&.persisted?
    end

    def series_flag_is_fixed
      errors.add(:series, 'cannot change once the event exists') if persisted? && will_save_change_to_series?
    end

    def join_series_from_session_of
      series = session_of.present? && series_named_by_session_of
      return unless series && !series? && series_link.blank?

      new_record = new_record?
      build_series_link(series:, position: series.series_session_links.count)
      copy_series_defaults(series) if new_record
    end

    def copy_series_defaults(series)
      series.event_hosts.each { |event_host| event_hosts.build(host: event_host.host) } if event_hosts.empty?
      self.category_ids = series.category_ids if category_ids.empty?
      copy_series_text_defaults(series)
    end

    def copy_series_text_defaults(series)
      self.privacy = series.privacy unless will_save_change_to_privacy?
      self.description = series.description.body if description.blank?
      self.timezone = series.timezone if timezone.blank?
    end
  end
end

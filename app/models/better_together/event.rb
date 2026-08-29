# frozen_string_literal: true

module BetterTogether
  # A Schedulable Event
  # rubocop:disable Metrics/ClassLength
  class Event < PlatformRecord
    include Attachments::Images
    include Categorizable
    include Creatable
    include Federatable
    include FriendlySlug
    include Identifier
    include Geography::Geospatial::One
    include Geography::Locatable::One
    include Invitable
    include Metrics::Shareable
    include Metrics::Viewable
    include Privacy
    include RecurringSchedulable
    include Reportable
    include Searchable
    include Seedable
    include Shortlinkable
    include TimezoneAttributeAliasing
    include TrackedActivity

    attachable_cover_image

    has_many :event_attendances, class_name: 'BetterTogether::EventAttendance',
                                 foreign_key: :event_id, inverse_of: :event, dependent: :destroy
    has_many :invitations, -> { includes(:invitee, :inviter) },
             class_name: 'BetterTogether::EventInvitation',
             foreign_key: :invitable_id, inverse_of: :invitable, dependent: :destroy
    has_many :attendees, through: :event_attendances, source: :person

    has_many :calendar_entries, class_name: 'BetterTogether::CalendarEntry', dependent: :destroy
    has_many :calendars, through: :calendar_entries

    # Lazily-created per-occurrence overrides (attendance/comments/location-
    # time-cancellation) for a recurring series — see EventOccurrence. Most
    # occurrences of a series never get a row; find_or_create_occurrence_for
    # below is the only intended write path.
    has_many :event_occurrences, class_name: 'BetterTogether::EventOccurrence', dependent: :destroy

    categorizable(class_name: 'BetterTogether::EventCategory')

    has_many :event_hosts, dependent: :destroy

    # belongs_to :address, -> { where(physical: true, primary_flag: true) }
    # accepts_nested_attributes_for :address, allow_destroy: true, reject_if: :blank?
    # delegate :geocoding_string, to: :address, allow_nil: true
    # geocoded_by :geocoding_string

    translates :name, type: :string
    translates :description, backend: :action_text

    slugged :name

    # Explicit lifecycle status, orthogonal to the timing-derived scopes below
    # (draft/scheduled/upcoming/ongoing/past): an event can be confirmed AND
    # past, or cancelled AND upcoming. Prefixed accessors (status_draft?,
    # Event.status_confirmed, ...) avoid colliding with the timing-based
    # `draft` scope and `#draft?` predicate that other callers rely on.
    STATUS_VALUES = { draft: 'draft', confirmed: 'confirmed', cancelled: 'cancelled' }.freeze
    enum :status, STATUS_VALUES, prefix: :status

    searchable pg_search: {
      against: [:identifier],
      using: {
        tsearch: {
          prefix: true,
          dictionary: 'simple'
        }
      }
    }

    validates :name, presence: true
    validates :registration_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true,
                                 allow_nil: true
    validates :duration_minutes, presence: true, numericality: { greater_than: 0 }, if: :starts_at?
    validates :timezone, presence: true, inclusion: {
      in: -> { TZInfo::Timezone.all_identifiers },
      message: '%<value>s is not a valid timezone'
    }
    validates :event_hosts, length: { minimum: 1 }
    validates :platform_id, presence: true
    validates :source_id, uniqueness: { scope: :platform_id }, allow_blank: true
    validate :ends_at_after_starts_at
    validate :validate_recurrence_end_condition_present
    validate :validate_recurrence_exception_dates_present

    # Transient, not persisted. Set by EventsController#process_recurrence_attributes
    # when the submitted recurrence end_type ('until'/'count') is missing its
    # paired ends_on/count value. Surfaced here (rather than relying on the
    # nested Recurrence's own errors to bubble up) so the message reliably
    # appears in the shared errors partial, which only reads @resource's own
    # errors.full_messages.
    attr_accessor :end_condition_error

    # Transient, not persisted. Set when one or more submitted recurrence
    # exception dates could not be parsed. Same rationale as
    # end_condition_error above.
    attr_accessor :exception_dates_error

    before_validation :set_host
    before_validation :set_default_duration
    before_validation :sync_time_duration_relationship

    accepts_nested_attributes_for :event_hosts, allow_destroy: true, reject_if: :all_blank

    # Timezone helper methods

    # Returns starts_at in the event's timezone
    def local_starts_at
      return nil if starts_at.nil?

      starts_at.in_time_zone(timezone)
    end

    # Returns ends_at in the event's timezone
    def local_ends_at
      return nil if ends_at.nil?

      ends_at.in_time_zone(timezone)
    end

    # Returns starts_at in a specified timezone
    def starts_at_in_zone(zone)
      return nil if starts_at.nil?

      starts_at.in_time_zone(zone)
    end

    # Returns ends_at in a specified timezone
    def ends_at_in_zone(zone)
      return nil if ends_at.nil?

      ends_at.in_time_zone(zone)
    end

    # Returns a human-friendly timezone display
    def timezone_display
      tz = ActiveSupport::TimeZone[timezone]
      if tz
        "#{tz} (#{timezone})"
      else
        timezone
      end
    end

    scope :draft, lambda {
      start_query = arel_table[:starts_at].eq(nil)
      where(start_query)
    }

    scope :scheduled, lambda {
      start_query = arel_table[:starts_at].not_eq(nil)
      where(start_query)
    }

    # Compares next_occurrence_at (denormalized, override- and recurrence-
    # aware) rather than starts_at, so a recurring event whose original
    # starts_at is long past still shows as upcoming for as long as it keeps
    # recurring. See Event#refresh_next_occurrence_at!.
    scope :upcoming, lambda {
      where(arel_table[:next_occurrence_at].gteq(Time.current))
    }

    scope :ongoing, lambda {
      now = Time.current
      starts = arel_table[:starts_at]
      ends = arel_table[:ends_at]
      duration = arel_table[:duration_minutes]

      # Event is ongoing if:
      # 1. It has started (starts_at <= now)
      # 2. AND either:
      #    a. It has ends_at and hasn't ended yet (ends_at >= now)
      #    b. OR it has no ends_at but has duration_minutes and calculated end time is in future

      started = starts.lteq(now)
      has_explicit_end = ends.not_eq(nil).and(ends.gteq(now))

      # For events without ends_at but with duration: starts_at + (duration_minutes minutes) >= now
      # Using PostgreSQL: starts_at + (duration_minutes * interval '1 minute') >= now
      calculated_end_in_future = ends.eq(nil)
                                     .and(duration.not_eq(nil))
                                     .and(
                                       Arel.sql(
                                         "#{table_name}.starts_at + (#{table_name}.duration_minutes * interval '1 minute')"
                                       ).gteq(now)
                                     )

      where(started).where(has_explicit_end.or(calculated_end_in_future))
    }

    scope :past, lambda {
      now = Time.current
      starts = arel_table[:starts_at]
      ends = arel_table[:ends_at]
      duration = arel_table[:duration_minutes]
      next_occurrence = arel_table[:next_occurrence_at]

      # A recurring event is never "past" while it still has a future
      # occurrence, no matter how stale its own original starts_at/ends_at
      # are — gate the whole decision on next_occurrence_at first, then
      # apply the existing ends_at/duration-based "has it truly ended" logic
      # (unchanged for non-recurring events, where next_occurrence_at ==
      # starts_at).
      recurrence_exhausted_or_absent = next_occurrence.lt(now).or(next_occurrence.eq(nil))

      explicit_end_passed = ends.not_eq(nil).and(ends.lt(now))
      no_end_no_duration = ends.eq(nil).and(duration.eq(nil)).and(starts.lt(now))

      # For events with duration but no ends_at: starts_at + (duration_minutes minutes) < now
      calculated_end_passed = ends.eq(nil)
                                  .and(duration.not_eq(nil))
                                  .and(
                                    Arel.sql(
                                      "#{table_name}.starts_at + (#{table_name}.duration_minutes * interval '1 minute')"
                                    ).lt(now)
                                  )

      where(recurrence_exhausted_or_absent)
        .where(explicit_end_passed.or(no_end_no_duration).or(calculated_end_passed))
    }

    def self.permitted_attributes(id: false, destroy: false)
      super + %i[
        starts_at ends_at duration_minutes registration_url timezone status end_condition_error
        exception_dates_error
      ] + [
        {
          location_attributes: BetterTogether::Geography::LocatableLocation.permitted_attributes(id: id,
                                                                                                 destroy: destroy),
          address_attributes: BetterTogether::Address.permitted_attributes(id: id),
          event_hosts_attributes: BetterTogether::EventHost.permitted_attributes(id: id, destroy: destroy),
          recurrence_attributes: BetterTogether::Recurrence.permitted_attributes(id: id, destroy: destroy)
        }
      ]
    end

    def set_host
      return if event_hosts.any?

      event_hosts.build(host: creator)
    end

    def schedule_address_geocoding
      return unless should_geocode?

      BetterTogether::Geography::GeocodingJob.perform_later(self)
    end

    def should_geocode?
      return false if geocoding_string.blank?

      # space.reload # in case it has been geocoded since last load

      (address_changed? or !geocoded?)
    end

    def to_s
      name
    end

    def mirrored?
      source_id.present? || last_synced_at.present? || platform&.external?
    end

    def preserved_remote_uuid?
      source_id.blank? && platform&.external?
    end

    def source_identifier
      source_id.presence || id
    end

    def local_to_platform?(local_platform = Current.platform)
      return true if platform_id.blank?
      return false unless local_platform

      platform_id == local_platform.id
    end

    def remote_to_platform?(local_platform = Current.platform)
      mirrored? && !local_to_platform?(local_platform)
    end

    # Minimal iCalendar representation for export
    def to_ics
      BetterTogether::Ics::Generator.new(self).generate
    end

    configure_attachment_cleanup

    # Callbacks for notifications and reminders
    after_update :send_update_notifications
    after_update :schedule_reminder_notifications, if: :should_schedule_reminders_after_save?
    after_update :sync_calendar_entry_times, if: :saved_change_to_temporal_fields?
    # after_save (not after_update): must run on initial create too, so a
    # freshly-created event's next_occurrence_at is correct from the start
    # rather than only after its first edit.
    after_save :refresh_next_occurrence_at!, if: :saved_change_to_temporal_fields?

    # Finds or lazily creates the EventOccurrence override row for one
    # specific session of this recurring series. This is the only intended
    # write path onto event_occurrences — call it when something needs to
    # attach to a specific date (RSVP, comment, organizer override), never
    # from a read/display path.
    # @param date [Date] must be a date the recurrence rule actually produces
    # @return [EventOccurrence]
    def find_or_create_occurrence_for(date)
      event_occurrences.find_or_create_by!(occurrence_date: date)
    end

    # Denormalized "when does this event next occur" scalar (see
    # next_occurrence_at column), kept fresh here plus by
    # EventNextOccurrenceRefreshScanJob for the passage of time itself.
    # RecurringSchedulable#next_occurrence returns nil for non-recurring
    # events (it doesn't fall back to starts_at) — branch explicitly rather
    # than bare-delegating.
    #
    # Reloads the recurrence association first if it's already been loaded:
    # a Recurrence is very often attached in a separate step after the Event
    # itself is created/saved (a bare Recurrence.create!(schedulable: event),
    # not through event.build_recurrence — this is the common factory/service
    # pattern throughout the app), so an already-cached "no recurrence" read
    # from an earlier call on this same in-memory Event would otherwise never
    # see the recurrence that now exists.
    def refresh_next_occurrence_at!
      association(:recurrence).reload if association(:recurrence).loaded?

      # .to_time: IceCube's Schedule#next_occurrence returns an
      # IceCube::Occurrence — a SimpleDelegator around Time that spoofs
      # class.name == "Time"/is_a?(Time) for compatibility, but isn't a
      # literal ::Time instance. Every other caller of Recurrence#next_occurrence
      # only ever calls further Time-ish methods on the result (harmless), but
      # the Postgres adapter's strict type-check rejects it outright when
      # persisting via update_column — coerce to a real Time here, the one
      # place this value gets written to the database.
      new_value = recurring? ? next_occurrence(after: Time.current)&.starts_at&.to_time : starts_at
      return if next_occurrence_at == new_value

      update_column(:next_occurrence_at, new_value) # rubocop:disable Rails/SkipsModelValidations
    end

    # Get the host community for calendar functionality
    def host_community
      @host_community ||= BetterTogether::Community.host.first
    end

    # Check if event requires reminder scheduling
    def requires_reminder_scheduling?
      starts_at.present? && attendees.reload.any?
    end

    # Get significant changes for notifications
    def significant_changes_for_notifications
      changes_to_check = saved_changes.presence || previous_changes
      return [] unless changes_to_check.present?

      significant_attrs = %w[name name_en name_es name_fr starts_at ends_at location_id description description_en
                             description_es description_fr]
      changes_to_check.keys & significant_attrs
    end

    def start_time
      starts_at
    end

    def end_time
      ends_at
    end

    # Check if event has location
    def location?
      location.present?
    end

    # State methods
    def draft?
      starts_at.blank?
    end

    def scheduled?
      starts_at.present?
    end

    def upcoming?
      starts_at.present? && starts_at > Time.current
    end

    def ongoing?
      starts_at.present? && ends_at.present? && starts_at <= Time.current && ends_at >= Time.current
    end

    def past?
      ends_at.present? ? ends_at < Time.current : (starts_at.present? && starts_at < Time.current)
    end

    # Duration calculation
    def duration_in_hours
      return nil unless starts_at.present? && ends_at.present?

      (ends_at - starts_at) / 1.hour
    end

    # Delegate location methods
    delegate :display_name, to: :location, prefix: true, allow_nil: true
    delegate :geocoding_string, to: :location, prefix: true, allow_nil: true

    # Public URL to this event for use in ICS export
    def url
      BetterTogether::Engine.routes.url_helpers.event_url(self, locale: I18n.locale)
    end

    private

    # Set default duration if not set and start time is present
    def set_default_duration
      return unless starts_at.present?
      return if duration_minutes.present?

      # If we have both starts_at and ends_at, calculate duration from them
      if ends_at.present? && ends_at > starts_at
        self.duration_minutes = ((ends_at - starts_at) / 60.0).round
        return
      end

      self.duration_minutes = 30 # Default to 30 minutes
    end

    # Synchronize the relationship between start time, end time, and duration
    def sync_time_duration_relationship # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      return unless starts_at.present?

      # Priority 1: If ends_at changed explicitly, recalculate duration
      if ends_at_changed? && !duration_minutes_changed?
        if ends_at.present?
          # Validate end time is after start time
          if ends_at <= starts_at
            errors.add(:ends_at, 'must be after start time')
            return
          end
          # Update duration based on new end time
          self.duration_minutes = ((ends_at - starts_at) / 60.0).round
        elsif duration_minutes.present?
          # ends_at was cleared but we have duration - recalculate ends_at
          update_end_time_from_duration
        end
        return
      end

      # Priority 2: If duration changed explicitly, update ends_at
      if duration_minutes_changed? && !ends_at_changed? && duration_minutes.present?
        update_end_time_from_duration
        return
      end

      # Priority 3: If starts_at changed, update ends_at to maintain duration
      if starts_at_changed? && !ends_at_changed?
        if duration_minutes.present?
          # We have duration, update ends_at
          update_end_time_from_duration
        elsif ends_at.present?
          # We have ends_at but no duration, calculate duration first then update ends_at
          self.duration_minutes = ((ends_at - starts_at_was.to_time) / 60.0).round if starts_at_was.present?
          update_end_time_from_duration
        end
        return
      end

      # Priority 4: Ensure ends_at is set if we have duration but no ends_at
      return unless ends_at.blank? && duration_minutes.present?

      update_end_time_from_duration
    end

    def update_end_time_from_duration
      return unless starts_at.present? && duration_minutes.present?

      self.ends_at = starts_at + duration_minutes.minutes
    end

    # Send update notifications
    def send_update_notifications
      changes = significant_changes_for_notifications
      return unless changes.any? && attendees.reload.any?

      BetterTogether::EventUpdateNotifier.with(event: self, changed_attributes: changes).deliver_later
    end

    # Schedule reminder notifications
    def schedule_reminder_notifications
      return unless requires_reminder_scheduling?

      BetterTogether::EventReminderSchedulerJob.perform_later(id)
    end

    # Sync temporal data to calendar entries when event times change
    def sync_calendar_entry_times
      calendar_entries.update_all(
        starts_at: starts_at,
        ends_at: ends_at,
        duration_minutes: duration_minutes
      )
    end

    # Check if temporal fields changed
    def saved_change_to_temporal_fields?
      saved_change_to_starts_at? || saved_change_to_ends_at? || saved_change_to_duration_minutes?
    end

    # Check if we should schedule reminders after save (for updates)
    def should_schedule_reminders_after_save?
      saved_change_to_temporal_fields? && requires_reminder_scheduling?
    end

    # Check if we should schedule reminders after commit (for creates with attendees)
    def should_schedule_reminders_after_commit?
      starts_at.present? && attendees.reload.any?
    end

    def ends_at_after_starts_at
      return if ends_at.blank? || starts_at.blank?
      return if ends_at > starts_at

      errors.add(:ends_at, I18n.t('errors.models.ends_at_before_starts_at'))
    end

    def validate_recurrence_end_condition_present
      case end_condition_error
      when :ends_on_blank
        errors.add(:base, 'Recurrence end date must be set when "On date" is selected as the end type')
      when :count_blank
        errors.add(:base, 'Recurrence occurrence count must be set when "After occurrences" is selected as the end type')
      when :ends_on_invalid
        errors.add(:base, 'Recurrence end date is not a valid date')
      end
    end

    def validate_recurrence_exception_dates_present
      return unless exception_dates_error

      errors.add(:base, 'One or more recurrence exception dates could not be understood')
    end
  end
  # rubocop:enable Metrics/ClassLength
end

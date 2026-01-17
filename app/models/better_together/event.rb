# frozen_string_literal: true

module BetterTogether
  # A Schedulable Event
  # rubocop:disable Metrics/ClassLength
  class Event < ApplicationRecord
    include Attachments::Images
    include Categorizable
    include Creatable
    include FriendlySlug
    include Identifier
    include Geography::Geospatial::One
    include Geography::Locatable::One
    include Invitable
    include Metrics::Viewable
    include Privacy
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

    categorizable(class_name: 'BetterTogether::EventCategory')

    has_many :event_hosts

    # belongs_to :address, -> { where(physical: true, primary_flag: true) }
    # accepts_nested_attributes_for :address, allow_destroy: true, reject_if: :blank?
    # delegate :geocoding_string, to: :address, allow_nil: true
    # geocoded_by :geocoding_string

    translates :name, type: :string
    translates :description, backend: :action_text

    slugged :name

    validates :name, presence: true
    validates :registration_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true,
                                 allow_nil: true
    validates :duration_minutes, presence: true, numericality: { greater_than: 0 }, if: :starts_at?
    validates :timezone, presence: true, inclusion: {
      in: -> { TZInfo::Timezone.all_identifiers },
      message: '%<value>s is not a valid timezone'
    }
    validate :ends_at_after_starts_at

    before_validation :set_host
    before_validation :set_default_duration
    before_validation :sync_time_duration_relationship

    accepts_nested_attributes_for :event_hosts, reject_if: :all_blank

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

    scope :upcoming, lambda {
      start_query = arel_table[:starts_at].gteq(Time.current)
      where(start_query)
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
                                       Arel.sql("starts_at + (duration_minutes * interval '1 minute')").gteq(now)
                                     )

      where(started).where(has_explicit_end.or(calculated_end_in_future))
    }

    scope :past, lambda {
      now = Time.current
      starts = arel_table[:starts_at]
      ends = arel_table[:ends_at]
      duration = arel_table[:duration_minutes]

      # Events are past if they have ended:
      # 1. Has explicit ends_at that is in the past (ends_at < now)
      # 2. OR has no ends_at, no duration, but has started (legacy events)
      # 3. OR has duration but calculated end time is in the past

      explicit_end_passed = ends.not_eq(nil).and(ends.lt(now))
      no_end_no_duration = ends.eq(nil).and(duration.eq(nil)).and(starts.lt(now))

      # For events with duration but no ends_at: starts_at + (duration_minutes minutes) < now
      calculated_end_passed = ends.eq(nil)
                                  .and(duration.not_eq(nil))
                                  .and(
                                    Arel.sql("starts_at + (duration_minutes * interval '1 minute')").lt(now)
                                  )

      where(explicit_end_passed.or(no_end_no_duration).or(calculated_end_passed))
    }

    def self.permitted_attributes(id: false, destroy: false)
      super + %i[
        starts_at ends_at duration_minutes registration_url timezone
      ] + [
        {
          location_attributes: BetterTogether::Geography::LocatableLocation.permitted_attributes(id: true,
                                                                                                 destroy: true),
          address_attributes: BetterTogether::Address.permitted_attributes(id: true),
          event_hosts_attributes: BetterTogether::EventHost.permitted_attributes(id: true)
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

    # Minimal iCalendar representation for export
    def to_ics
      lines = ics_header_lines + ics_event_lines + ics_footer_lines
      ics_content = "#{lines.join("\r\n")}\r\n"

      # Ensure all lines use \r\n endings
      ics_content.gsub!(/(?<!\r)\n/, "\r\n")

      # Debugging: Log final ICS content
      puts "ICS Content:\n#{ics_content}"

      ics_content
    end

    configure_attachment_cleanup

    # Callbacks for notifications and reminders
    after_update :send_update_notifications
    after_update :schedule_reminder_notifications, if: :requires_reminder_scheduling?

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

    # Check if we should schedule reminders after save (for updates)
    def should_schedule_reminders_after_save?
      !new_record? && requires_reminder_scheduling?
    end

    # Check if we should schedule reminders after commit (for creates with attendees)
    def should_schedule_reminders_after_commit?
      starts_at.present? && attendees.reload.any?
    end

    def ics_header_lines
      lines = [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//Better Together Community Engine//EN',
        'CALSCALE:GREGORIAN',
        'METHOD:PUBLISH'
      ]
      # Add VTIMEZONE component before VEVENT if event has a non-UTC timezone
      lines.concat(ics_vtimezone_lines) if event_has_timezone? && !event_uses_utc?
      lines << 'BEGIN:VEVENT'
      lines
    end

    def ics_event_lines
      lines = []
      lines.concat(ics_basic_event_info)
      lines << ics_description_line if ics_description_present?
      lines.concat(ics_timing_info)
      lines << "URL:#{url}"
      lines
    end

    def ics_basic_event_info
      [
        "DTSTAMP:#{ics_timestamp}",
        "UID:event-#{id}@better-together",
        "SUMMARY:#{name}"
      ]
    end

    def ics_timing_info # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      lines = []
      if starts_at
        lines << if event_has_timezone? && !event_uses_utc?
                   "DTSTART;TZID=#{timezone}:#{ics_local_time(starts_at)}"
                 else
                   "DTSTART:#{ics_start_time}"
                 end
      end
      if ends_at
        lines << if event_has_timezone? && !event_uses_utc?
                   "DTEND;TZID=#{timezone}:#{ics_local_time(ends_at)}"
                 else
                   "DTEND:#{ics_end_time}"
                 end
      end
      lines
    end

    def ics_footer_lines
      ['END:VEVENT', 'END:VCALENDAR']
    end

    def ics_timestamp
      Time.current.utc.strftime('%Y%m%dT%H%M%SZ')
    end

    def ics_start_time
      starts_at&.utc&.strftime('%Y%m%dT%H%M%SZ')
    end

    def ics_end_time
      ends_at&.utc&.strftime('%Y%m%dT%H%M%SZ')
    end

    def ics_description_present?
      respond_to?(:description) && description
    end

    def ics_description_line
      desc_text = ActionView::Base.full_sanitizer.sanitize(description.to_plain_text)
      desc_text += "\n\n#{I18n.t('better_together.events.ics.view_details_url', url: url)}"
      "DESCRIPTION:#{desc_text}"
    end

    # Generate VTIMEZONE component for ICS export
    def ics_vtimezone_lines # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      return [] unless event_has_timezone?

      tz = ActiveSupport::TimeZone[timezone]
      return [] unless tz

      tzinfo = tz.tzinfo
      # Get the timezone period for the event start time
      period = tzinfo.period_for_utc(starts_at.utc)

      lines = [
        'BEGIN:VTIMEZONE',
        "TZID:#{timezone}"
      ]

      # Determine if timezone uses DST in a modern window around the event (ignore historic anomalies)
      window_start = starts_at.utc - 10.years
      window_end = starts_at.utc + 10.years
      has_recent_dst = tzinfo.transitions_up_to(window_end, window_start).any? do |t|
        (t.offset&.std_offset && t.offset.std_offset != 0) || (t.previous_offset && t.previous_offset.std_offset != 0)
      end

      lines.concat(ics_standard_time_component(tzinfo, period))
      lines.concat(ics_daylight_time_component(tzinfo, period)) if has_recent_dst

      lines << 'END:VTIMEZONE'
      lines
    end

    # Generate STANDARD time component
    def ics_standard_time_component(tzinfo, period) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      offset = period.offset
      offset.observed_utc_offset
      base_offset = offset.base_utc_offset

      # Find most recent standard time transition (if any)
      transitions = tzinfo.transitions_up_to(starts_at.utc)

      # Prefer the previous offset from a recent transition when it represents a genuine
      # recent offset change (e.g., DST <-> STANDARD). Otherwise, fall back to the
      # current period's observed offset so non-DST zones don't pick up historic anomalies.
      transition = transitions.reverse.find do |t|
        # consider transitions within a 10 year window of the event
        transition_time = Time.at(t.timestamp_value)
        (starts_at.utc - transition_time).abs <= 10.years
      end

      if transition&.previous_offset
        prev_seconds = transition.previous_offset.observed_utc_offset
        # If the previous offset is meaningfully different, use it; otherwise fall back
        from_offset = if prev_seconds == period.offset.observed_utc_offset
                        format_utc_offset(period.offset.observed_utc_offset)
                      else
                        format_utc_offset(prev_seconds)
                      end
      else
        from_offset = format_utc_offset(period.offset.observed_utc_offset)
      end

      [
        'BEGIN:STANDARD',
        "DTSTART:#{starts_at.strftime('%Y%m%dT%H%M%S')}",
        "TZOFFSETFROM:#{from_offset}",
        "TZOFFSETTO:#{format_utc_offset(base_offset)}",
        'END:STANDARD'
      ]
    end

    # Generate DAYLIGHT time component (for DST-observing timezones)
    def ics_daylight_time_component(_tzinfo, period)
      offset = period.offset
      utc_offset = offset.observed_utc_offset
      base_offset = offset.base_utc_offset

      return [] if utc_offset == base_offset

      from_offset = format_utc_offset(base_offset)
      to_offset = format_utc_offset(utc_offset)

      [
        'BEGIN:DAYLIGHT',
        "DTSTART:#{starts_at.strftime('%Y%m%dT%H%M%S')}",
        "TZOFFSETFROM:#{from_offset}",
        "TZOFFSETTO:#{to_offset}",
        'END:DAYLIGHT'
      ]
    end

    # Format UTC offset in ICS format (+HHMM or -HHMM)
    def format_utc_offset(seconds)
      hours = seconds / 3600
      minutes = (seconds.abs % 3600) / 60
      sign = seconds.negative? ? '-' : '+'
      format('%<sign>s%<hours>02d%<minutes>02d', sign: sign, hours: hours.abs, minutes: minutes)
    end

    # Format time in local timezone for ICS (without Z suffix)
    def ics_local_time(time)
      event_tz = ActiveSupport::TimeZone[timezone]
      local_time = time.in_time_zone(event_tz)
      local_time.strftime('%Y%m%dT%H%M%S')
    end

    # Check if event has a timezone set
    def event_has_timezone?
      timezone.present?
    end

    # Check if event uses UTC timezone
    def event_uses_utc?
      ['UTC', 'Etc/UTC'].include?(timezone)
    end

    def ends_at_after_starts_at
      return if ends_at.blank? || starts_at.blank?
      return if ends_at > starts_at

      errors.add(:ends_at, I18n.t('errors.models.ends_at_before_starts_at'))
    end

    # Public URL to this event for use in ICS export
    def url
      BetterTogether::Engine.routes.url_helpers.event_url(self, locale: I18n.locale)
    end
  end
  # rubocop:enable Metrics/ClassLength
end

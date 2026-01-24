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
    include RecurringSchedulable
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
          location_attributes: BetterTogether::Geography::LocatableLocation.permitted_attributes(id: id,
                                                                                                 destroy: destroy),
          address_attributes: BetterTogether::Address.permitted_attributes(id: id),
          event_hosts_attributes: BetterTogether::EventHost.permitted_attributes(id: id),
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

    # Minimal iCalendar representation for export
    def to_ics
      BetterTogether::Ics::Generator.new(self).generate
    end

    configure_attachment_cleanup

    # Callbacks for notifications and reminders
    after_update :send_update_notifications
    after_update :schedule_reminder_notifications, if: :requires_reminder_scheduling?
    after_update :sync_calendar_entry_times, if: :saved_change_to_temporal_fields?

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
      !new_record? && requires_reminder_scheduling?
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
  end
  # rubocop:enable Metrics/ClassLength
end

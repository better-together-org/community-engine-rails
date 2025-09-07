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
    include Metrics::Viewable
    include Privacy
    include TrackedActivity

    attachable_cover_image

    has_many :event_attendances, class_name: 'BetterTogether::EventAttendance',
                                 foreign_key: :event_id, inverse_of: :event, dependent: :destroy
    has_many :invitations, -> { includes(:invitee, :inviter) }, class_name: 'BetterTogether::EventInvitation',
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

    translates :name
    translates :description, backend: :action_text

    slugged :name

    validates :name, presence: true
    validates :registration_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true,
                                 allow_nil: true
    validates :duration_minutes, presence: true, numericality: { greater_than: 0 }, if: :starts_at?
    validate :ends_at_after_starts_at

    before_validation :set_host
    before_validation :set_default_duration
    before_validation :sync_time_duration_relationship

    accepts_nested_attributes_for :event_hosts, reject_if: :all_blank

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

    scope :past, lambda {
      start_query = arel_table[:starts_at].lt(Time.current)
      where(start_query)
    }

    def self.permitted_attributes(id: false, destroy: false)
      super + %i[
        starts_at ends_at duration_minutes registration_url
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
      "#{lines.join("\r\n")}\r\n"
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

    def past?
      starts_at.present? && starts_at < Time.current
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

      self.duration_minutes = 30 # Default to 30 minutes
    end

    # Synchronize the relationship between start time, end time, and duration
    def sync_time_duration_relationship # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      return unless starts_at.present?

      if starts_at_changed? && !ends_at_changed? && duration_minutes.present?
        # Start time changed, update end time based on duration
        update_end_time_from_duration
      elsif ends_at_changed? && !starts_at_changed? && ends_at.present?
        # End time changed, update duration and validate end time is after start time
        if ends_at <= starts_at
          errors.add(:ends_at, 'must be after start time')
          return
        end
        self.duration_minutes = ((ends_at - starts_at) / 60.0).round
      elsif duration_minutes_changed? && !starts_at_changed? && !ends_at_changed? # rubocop:todo Lint/DuplicateBranch
        # Duration changed, update end time
        update_end_time_from_duration
      end
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
      [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//Better Together Community Engine//EN',
        'CALSCALE:GREGORIAN',
        'METHOD:PUBLISH',
        'BEGIN:VEVENT'
      ]
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

    def ics_timing_info
      lines = []
      lines << "DTSTART:#{ics_start_time}" if starts_at
      lines << "DTEND:#{ics_end_time}" if ends_at
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

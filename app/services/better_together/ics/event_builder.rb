# frozen_string_literal: true

module BetterTogether
  module Ics
    # Builds VEVENT components for ICS calendar export
    # Handles event-specific information including timing, description, and URL
    class EventBuilder # rubocop:disable Metrics/ClassLength
      def initialize(schedulable)
        @schedulable = schedulable
      end

      # Generate VEVENT component lines
      def build
        lines = []
        lines.concat(basic_event_info)
        lines << description_line if description_present?
        lines.concat(timing_info)
        lines << "URL:#{schedulable.url}" if schedulable.respond_to?(:url)
        lines
      end

      # Build event using icalendar gem's event object
      # @param cal_event [Icalendar::Event] The icalendar event object to populate
      # rubocop:disable Metrics/AbcSize
      def build_icalendar_event(cal_event)
        cal_event.dtstart = icalendar_datetime(schedulable.starts_at)
        cal_event.dtend = icalendar_datetime(schedulable.ends_at) if schedulable.ends_at
        cal_event.summary = schedulable.name
        cal_event.uid = event_uid
        cal_event.dtstamp = Icalendar::Values::DateTime.new(Time.current.utc)

        if description_present?
          cal_event.description = format_description_for_icalendar
        end

        cal_event.url = schedulable.url if schedulable.respond_to?(:url)

        # Add recurrence rule if event is recurring
        add_recurrence_rule(cal_event) if schedulable.respond_to?(:recurring?) && schedulable.recurring?

        # Add reminder alarms
        add_reminders(cal_event)
      end
      # rubocop:enable Metrics/AbcSize

      private

      attr_reader :schedulable

      # Basic event information: timestamp, UID, and summary
      def basic_event_info
        [
          "DTSTAMP:#{Formatter.timestamp}",
          "UID:#{event_uid}",
          "SUMMARY:#{schedulable.name}"
        ]
      end

      # Generate unique identifier for the event
      def event_uid
        "event-#{schedulable.id}@better-together"
      end

      # Check if description is present and accessible
      def description_present?
        schedulable.respond_to?(:description) && schedulable.description
      end

      # Format description with URL reference
      def description_line
        desc_text = ActionView::Base.full_sanitizer.sanitize(schedulable.description.to_plain_text)
        if schedulable.respond_to?(:url)
          desc_text += "\n\n#{I18n.t('better_together.events.ics.view_details_url', url: schedulable.url)}"
        end
        "DESCRIPTION:#{desc_text}"
      end

      # Generate timing information (DTSTART and DTEND)
      def timing_info # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        lines = []

        if schedulable.starts_at
          lines << if non_utc_timezone?
                     "DTSTART;TZID=#{schedulable.timezone}:#{local_start_time}"
                   else
                     "DTSTART:#{Formatter.utc_time(schedulable.starts_at)}"
                   end
        end

        if schedulable.ends_at
          lines << if non_utc_timezone?
                     "DTEND;TZID=#{schedulable.timezone}:#{local_end_time}"
                   else
                     "DTEND:#{Formatter.utc_time(schedulable.ends_at)}"
                   end
        end

        lines
      end

      # Check if event has a non-UTC timezone
      def non_utc_timezone?
        schedulable.respond_to?(:timezone) &&
          schedulable.timezone.present? &&
          !['UTC', 'Etc/UTC'].include?(schedulable.timezone)
      end

      # Format start time in local timezone
      def local_start_time
        Formatter.local_time(schedulable.starts_at, schedulable.timezone)
      end

      # Format end time in local timezone
      def local_end_time
        Formatter.local_time(schedulable.ends_at, schedulable.timezone)
      end

      # Convert datetime to icalendar format with timezone
      def icalendar_datetime(datetime)
        return nil unless datetime

        if non_utc_timezone?
          # Convert to local timezone before creating icalendar datetime
          local_time = datetime.in_time_zone(schedulable.timezone)
          Icalendar::Values::DateTime.new(local_time, 'tzid' => schedulable.timezone)
        else
          # For UTC times, use the utc_time method which adds the Z suffix
          Icalendar::Values::DateTime.new(datetime.utc, 'tzid' => 'UTC')
        end
      end

      # Format description for icalendar gem
      def format_description_for_icalendar
        desc_text = ActionView::Base.full_sanitizer.sanitize(schedulable.description.to_plain_text)
        if schedulable.respond_to?(:url)
          desc_text += "\n\n#{I18n.t('better_together.events.ics.view_details_url', url: schedulable.url)}"
        end
        desc_text
      end

      # Add recurrence rule to the icalendar event
      # @param cal_event [Icalendar::Event] The icalendar event object
      def add_recurrence_rule(cal_event)
        return unless schedulable.schedule

        # Convert ice_cube schedule to RRULE format
        cal_event.rrule = schedulable.schedule.to_ical

        # Add exception dates if any
        add_exception_dates(cal_event)
      end

      # Add exception dates (EXDATE) to the icalendar event
      # @param cal_event [Icalendar::Event] The icalendar event object
      def add_exception_dates(cal_event)
        return unless schedulable.recurrence&.exception_dates&.any?

        schedulable.recurrence.exception_dates.each do |exdate|
          cal_event.append_custom_property('EXDATE', exdate)
        end
      end

      # Add reminder alarms (VALARM) to the icalendar event
      # Creates three default reminders: 24 hours, 1 hour, and at start time
      # @param cal_event [Icalendar::Event] The icalendar event object
      # rubocop:todo Lint/CopDirectiveSyntax
      def add_reminders(cal_event) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength, Lint/CopDirectiveSyntax, Metrics/MethodLength
        # rubocop:enable Lint/CopDirectiveSyntax
        # 24 hour reminder
        cal_event.alarm do |alarm|
          alarm.action = 'DISPLAY'
          alarm.trigger = '-PT24H'
          alarm.description = I18n.t('better_together.events.ics.reminders.24_hours',
                                     event_name: schedulable.name)
        end

        # 1 hour reminder
        cal_event.alarm do |alarm|
          alarm.action = 'DISPLAY'
          alarm.trigger = '-PT1H'
          alarm.description = I18n.t('better_together.events.ics.reminders.1_hour',
                                     event_name: schedulable.name)
        end

        # At start reminder
        cal_event.alarm do |alarm|
          alarm.action = 'DISPLAY'
          alarm.trigger = 'PT0S'
          alarm.description = I18n.t('better_together.events.ics.reminders.at_start',
                                     event_name: schedulable.name)
        end
      end
    end
  end
end

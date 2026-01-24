# frozen_string_literal: true

module BetterTogether
  # View helpers for events
  module EventsHelper
    # Return hosts for an event that the current user is authorized to view.
    # Keeps view markup small and centralizes the policy logic for testing.
    def visible_event_hosts(event)
      return [] unless event.respond_to?(:event_hosts)

      event.event_hosts.map { |eh| eh.host if policy(eh.host).show? }.compact
    end

    # Intelligently displays event time based on duration and date span
    #
    # Rules:
    # - Under 1 hour: "Sept 4, 2:00 PM (30 minutes)" or "Sept 4, 2025 2:00 PM (30 minutes)" if not current year
    # - 1-5 hours (same day): "Sept 4, 2:00 PM (3 hours)" or "Sept 4, 2025 2:00 PM (3 hours)" if not current year
    # - Same day, over 5 hours: "Sept 4, 2:00 PM - 8:00 PM" or "Sept 4, 2025 2:00 PM - 8:00 PM" if not current year
    # rubocop:todo Layout/LineLength
    # - Different days: "Sept 4, 2:00 PM - Sept 5, 10:00 AM" or "Sept 4, 2025 2:00 PM - Sept 5, 2025 10:00 AM" if not current year
    # rubocop:enable Layout/LineLength
    #
    # @param event [Event] The event object with starts_at and ends_at
    # @return [String] Formatted time display
    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/AbcSize
    def display_event_time(event) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      return '' unless event&.starts_at

      # Convert times to event timezone for display
      event_tz = ActiveSupport::TimeZone[event.timezone] || Time.zone
      start_time = event.starts_at.in_time_zone(event_tz)
      end_time = event.ends_at&.in_time_zone(event_tz)
      current_year = Time.current.year

      # Determine format based on whether year differs from current
      start_format = start_time.year == current_year ? :event_date_time : :event_date_time_with_year
      time_only_format = :time_only
      time_only_with_year_format = :time_only_with_year

      # No end time
      return l(start_time, format: start_format) unless end_time

      duration_minutes = ((end_time - start_time) / 60).round
      duration_hours = duration_minutes / 60.0
      same_day = start_time.to_date == end_time.to_date

      if duration_minutes < 60
        # Under 1 hour: show minutes
        "#{l(start_time, format: start_format)} (#{duration_minutes} #{t('better_together.events.time.minutes')})"
      elsif duration_hours <= 5 && same_day
        # 1-5 hours, same day: show hours
        # rubocop:todo Layout/LineLength
        hours_text = duration_hours == 1 ? t('better_together.events.time.hour') : t('better_together.events.time.hours')
        # rubocop:enable Layout/LineLength
        "#{l(start_time, format: start_format)} (#{duration_hours.to_i} #{hours_text})"
      elsif same_day
        # Same day, over 5 hours: show start and end times
        # If start and end are different years, show year for both
        end_time_format = if start_time.year == end_time.year
                            current_year == end_time.year ? time_only_format : time_only_with_year_format
                          else
                            time_only_with_year_format
                          end
        "#{l(start_time, format: start_format)} - #{l(end_time, format: end_time_format)}"
      else
        # Different days: show full dates for both
        # If start and end are different years, show year for both
        end_format = if start_time.year == end_time.year
                       current_year == end_time.year ? :event_date_time : :event_date_time_with_year
                     else
                       :event_date_time_with_year
                     end
        "#{l(start_time, format: start_format)} - #{l(end_time, format: end_format)}"
      end
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

    # Display timezone badge with optional offset
    # @param event [Event] The event with timezone
    # @param show_offset [Boolean] Whether to show GMT offset
    # @return [String] HTML badge with timezone info
    def event_timezone_badge(event, show_offset: true)
      return '' unless event&.timezone

      tz = ActiveSupport::TimeZone[event.timezone]
      return '' unless tz

      # Find the Rails timezone name that maps to this IANA identifier
      # ActiveSupport::TimeZone.all maps Rails names to IANA identifiers
      rails_tz = ActiveSupport::TimeZone.all.find { |z| z.tzinfo.identifier == event.timezone }
      timezone_name = rails_tz&.name || event.timezone

      offset_text = if show_offset
                      offset = tz.formatted_offset
                      " (GMT#{offset})"
                    else
                      ''
                    end

      content_tag(:span, class: 'badge bg-secondary ms-2') do
        "#{timezone_name}#{offset_text}"
      end
    end

    # Display time in viewer's timezone if different from event timezone
    # @param event [Event] The event
    # @param person [Person] The current viewer
    # @return [String] Conversion message or empty string
    def viewer_timezone_conversion(event, person = nil)
      return '' unless event&.timezone && person&.time_zone
      return '' if event.timezone == person.time_zone

      viewer_tz = ActiveSupport::TimeZone[person.time_zone]
      return '' unless viewer_tz

      start_in_viewer_tz = event.starts_at.in_time_zone(viewer_tz)

      content_tag(:div, class: 'text-muted small mt-1') do
        "#{l(start_in_viewer_tz, format: :time_only)} #{viewer_tz.tzinfo.abbreviation} (Your Time)"
      end
    end
  end
end

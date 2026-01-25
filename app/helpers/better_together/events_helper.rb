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

      timezone_name = display_timezone_name_for(event.timezone)
      offset_text = show_offset ? " (GMT#{tz.formatted_offset})" : ''

      content_tag(:span, class: 'badge bg-secondary ms-2') do
        "#{timezone_name}#{offset_text}"
      end
    end

    # Find Rails timezone name from IANA identifier
    # @param iana_identifier [String] IANA timezone identifier
    # @return [String] Rails timezone name or IANA identifier if not found
    def rails_timezone_name_for(iana_identifier)
      rails_tz = ActiveSupport::TimeZone.all.find { |z| z.tzinfo.identifier == iana_identifier }
      rails_tz&.name
    end

    def display_timezone_name_for(iana_identifier)
      return '' if iana_identifier.blank?

      rails_name = rails_timezone_name_for(iana_identifier)
      return rails_name if rails_name.present?

      return iana_identifier if iana_identifier == 'UTC'

      iana_identifier.split('/').last.to_s.tr('_', ' ')
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

    # Display event hosts with avatars and names
    # @param event [Event] The event object
    # @param max_avatars [Integer] Maximum number of avatars to show
    # @return [String] HTML for hosts display or empty string
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def event_hosts_display(event, max_avatars: 3)
      hosts = visible_event_hosts(event)
      return '' if hosts.empty?

      content_tag(:div, class: 'event-hosts card-text text-muted mt-2') do
        concat(content_tag(:i, '', class: 'fas fa-user me-2 icon-above-stretched-link', 'aria-hidden': 'true', 'data-bs-toggle': 'tooltip',
                                   title: t('better_together.events.hosted_by')))
        concat(
          content_tag(:span, class: 'd-inline-flex align-items-center flex-wrap gap-2') do
            hosts.take(max_avatars).each do |host|
              concat(render('better_together/events/host', host: host, size: 24, show_name: false))
            end
            concat(
              content_tag(:span, class: 'small') do
                names = hosts.take(max_avatars).map(&:name).join(', ')
                overflow = hosts.count > max_avatars ? " + #{hosts.count - max_avatars} more" : ''
                "#{names}#{overflow}"
              end
            )
          end
        )
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # Returns the appropriate Font Awesome icon class for a host type
    # @param host_type_key [String] The underscored host type (e.g., 'person', 'community')
    # @return [String] Font Awesome icon class
    def host_type_icon(host_type_key)
      case host_type_key
      when 'better_together/person'
        'fas fa-user'
      when 'better_together/community'
        'fas fa-users'
      when 'better_together/organization'
        'fas fa-building'
      when 'better_together/venue'
        'fas fa-map-marker-alt'
      else
        'fas fa-star'
      end
    end

    # Returns the appropriate Bootstrap color class for a host type badge
    # @param host_type_key [String] The underscored host type (e.g., 'person', 'community')
    # @return [String] Bootstrap color class (without 'bg-' prefix)
    def host_type_badge_color(host_type_key)
      case host_type_key
      when 'better_together/person'
        'info'
      when 'better_together/community'
        'success'
      when 'better_together/organization'
        'primary'
      when 'better_together/venue'
        'warning'
      else
        'secondary'
      end
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  # Formatting for the settlement weather panel. A nil measurement renders as
  # "Not reported", never as zero.
  module WeatherHelper
    UNIT_KEYS = {
      celsius: 'celsius', kmh: 'kmh', kpa: 'kpa', percent: 'percent', km: 'km', mm: 'mm', cm: 'cm'
    }.freeze
    CHART_MEASURES = {
      'temperature' => %i[temperature_max_c temperature_min_c temperature_mean_c],
      'precipitation' => %i[precip_mm],
      'wind' => %i[wind_speed_kmh wind_gust_kmh]
    }.freeze
    CHART_SERIES = %i[temperature_max_c temperature_min_c temperature_mean_c precip_mm snow_cm
                      wind_speed_kmh wind_gust_kmh].freeze

    # Panel for the current-conditions card, or nil when the settlement has no enabled location or no
    # stored current conditions. Reads stored rows only.
    def weather_summary_panel(settlement)
      location = @weather_location if @weather_location&.settlement_id == settlement.id
      location ||= BetterTogether::Weather::Location.enabled.includes(:source, :current_condition)
                                                     .find_by(settlement: settlement)
      return unless location&.current_condition

      BetterTogether::Weather::SettlementPanel.new(location)
    end

    def weather_value(value, unit, digits: 0)
      return t('better_together.weather.panel.not_reported') if value.nil?

      formatted = number_with_precision(value, precision: digits, strip_insignificant_zeros: true)
      t("better_together.weather.panel.units.#{UNIT_KEYS.fetch(unit)}", value: formatted)
    end

    def weather_time(time, zone, format: '%H:%M')
      return if time.blank?

      I18n.l(parse_weather_time(time).in_time_zone(zone), format: format)
    end

    def weather_datetime(time, zone)
      weather_time(time, zone, format: :short)
    end

    def weather_period_time(period, zone)
      weather_time(period['starts_at'], zone)
    end

    def weather_day_label(date, partial: false)
      label = I18n.l(date, format: '%b %-d')
      partial ? "#{label} (#{t('better_together.weather.panel.history.so_far')})" : label
    end

    def weather_chart_data(series)
      values = CHART_SERIES.index_with { |measure| series.days.map { |day| day[measure] } }
      {
        labels: series.days.map { |day| weather_day_label(day.date, partial: day.partial?) },
        dates: series.days.map { |day| day.date.iso8601 }
      }.merge(values)
    end

    def weather_chart_reported?(series, chart)
      CHART_MEASURES.fetch(chart).any? { |measure| series.reported?(measure) }
    end

    def weather_chart_labels
      CHART_SERIES.index_with { |measure| t("better_together.weather.panel.history.series.#{measure}") }
    end

    private

    def parse_weather_time(time)
      time.respond_to?(:in_time_zone) ? time : Time.iso8601(time.to_s)
    end
  end
end

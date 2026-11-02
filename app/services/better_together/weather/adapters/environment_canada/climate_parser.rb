# frozen_string_literal: true

module BetterTogether
  module Weather
    module Adapters
      class EnvironmentCanada
        # Pure parser for MSC GeoMet OGC API climate-hourly / climate-daily feature properties.
        class ClimateParser
          HOURLY_FIELDS = {
            'TEMP' => :temperature_c, 'DEW_POINT_TEMP' => :dew_point_c, 'HUMIDEX' => :humidex,
            'WINDCHILL' => :wind_chill, 'RELATIVE_HUMIDITY' => :humidity_pct,
            'STATION_PRESSURE' => :pressure_kpa, 'WIND_SPEED' => :wind_speed_kmh,
            'VISIBILITY' => :visibility_km, 'PRECIP_AMOUNT' => :precip_mm
          }.freeze

          DAILY_FIELDS = {
            'MEAN_TEMPERATURE' => :temperature_c, 'MIN_TEMPERATURE' => :temperature_min_c,
            'MAX_TEMPERATURE' => :temperature_max_c, 'TOTAL_PRECIPITATION' => :precip_mm,
            'TOTAL_SNOW' => :snow_cm, 'SPEED_MAX_GUST' => :wind_gust_kmh
          }.freeze

          NO_CONDITION = %w[NA ND].freeze

          # Hourly wind direction is reported in tens of degrees.
          def self.hourly(properties_list)
            properties_list.filter_map do |props|
              observed_at = parse_utc(props['UTC_DATE'])
              next if observed_at.nil?

              values = extract(props, HOURLY_FIELDS)
              direction = props['WIND_DIRECTION']
              values[:wind_direction_deg] = direction * 10.0 if direction.is_a?(Numeric)
              row(props, observed_at, values, props['WEATHER_ENG_DESC'])
            end
          end

          # Daily rows with no measurements at all (the in-progress day) are dropped.
          def self.daily(properties_list)
            properties_list.filter_map do |props|
              date = props['LOCAL_DATE'].to_s[0, 10]
              observed_at = parse_utc("#{date}T00:00:00") if date.present?
              values = extract(props, DAILY_FIELDS)
              next if observed_at.nil? || values.values.all?(&:nil?)

              row(props, observed_at, values, nil)
            end
          end

          def self.row(props, observed_at, values, condition)
            flags = props.select { |key, value| key.end_with?('_FLAG') && !value.nil? }
            { observed_at: observed_at, values: values, flags: flags,
              condition: (condition unless condition.blank? || NO_CONDITION.include?(condition)) }
          end

          def self.extract(props, mapping)
            mapping.to_h { |source, name| [name, props[source].is_a?(Numeric) ? props[source].to_f : nil] }
          end

          def self.parse_utc(value)
            Time.find_zone!('UTC').parse(value.to_s) if value.present?
          rescue ArgumentError
            nil
          end

          private_class_method :row, :extract, :parse_utc
        end
      end
    end
  end
end

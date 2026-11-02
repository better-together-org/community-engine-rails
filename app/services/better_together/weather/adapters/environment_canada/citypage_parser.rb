# frozen_string_literal: true

require 'nokogiri'

module BetterTogether
  module Weather
    module Adapters
      class EnvironmentCanada
        # Pure parser for an MSC Datamart citypage_weather XML document. Does no I/O.
        # Missing or non-numeric values come back as nil, never as zero.
        class CitypageParser # rubocop:disable Metrics/ClassLength
          TIMESTAMP_FORMATS = { 14 => '%Y%m%d%H%M%S', 12 => '%Y%m%d%H%M' }.freeze

          def self.parse(xml)
            new(xml).parse
          end

          def initialize(xml)
            @doc = Nokogiri::XML(xml) { |c| c.strict.nonet }
            @doc.remove_namespaces!
          end

          def parse
            {
              created_at: utc_stamp(@doc.at_xpath("/siteData/dateTime[@name='xmlCreation'][@zone='UTC']/timeStamp")),
              current: current,
              forecasts: [hourly_forecast, daily_forecast].compact
            }
          end

          private

          def current
            node = @doc.at_xpath('/siteData/currentConditions')
            observed_at = utc_stamp(node&.at_xpath("dateTime[@name='observation'][@zone='UTC']/timeStamp"))
            return if observed_at.nil?

            {
              observed_at: observed_at,
              station_ref: node.at_xpath('station/@code')&.value,
              values: current_values(node),
              condition: text(node, 'condition'),
              icon_code: text(node, 'iconCode'),
              extras: current_extras(node)
            }
          end

          def current_values(node)
            {
              temperature_c: number(node, 'temperature'), dew_point_c: number(node, 'dewpoint'),
              humidex: number(node, 'humidex'), wind_chill: number(node, 'windChill'),
              humidity_pct: number(node, 'relativeHumidity'), pressure_kpa: number(node, 'pressure'),
              wind_speed_kmh: number(node, 'wind/speed'), wind_gust_kmh: number(node, 'wind/gust'),
              wind_direction_deg: number(node, 'wind/bearing'), visibility_km: number(node, 'visibility')
            }
          end

          def current_extras(node)
            {
              wind_direction: text(node, 'wind/direction'),
              pressure_tendency: node.at_xpath('pressure/@tendency')&.value.presence,
              sunrise: sun_time('sunrise'), sunset: sun_time('sunset')
            }.compact
          end

          def sun_time(name)
            utc_stamp(@doc.at_xpath("/siteData/riseSet/dateTime[@name='#{name}'][@zone='UTC']/timeStamp"))&.iso8601
          end

          def hourly_forecast
            group = @doc.at_xpath('/siteData/hourlyForecastGroup')
            issued_at = utc_stamp(group&.at_xpath("dateTime[@name='forecastIssue'][@zone='UTC']/timeStamp"))
            periods = group ? group.xpath('hourlyForecast').filter_map { |node| hourly_period(node) } : []
            return if issued_at.nil? || periods.empty?

            { kind: 'hourly', issued_at: issued_at, periods: periods }
          end

          def hourly_period(node)
            starts_at = utc_stamp(node.at_xpath('@dateTimeUTC'))
            return if starts_at.nil?

            {
              starts_at: starts_at.iso8601, condition: text(node, 'condition'), icon_code: text(node, 'iconCode'),
              temperature_c: number(node, 'temperature'), pop_pct: number(node, 'lop'),
              wind_speed_kmh: number(node, 'wind/speed'), wind_gust_kmh: number(node, 'wind/gust'),
              wind_direction: text(node, 'wind/direction'),
              humidex: number(node, 'humidex'), wind_chill: number(node, 'windChill')
            }
          end

          def daily_forecast
            group = @doc.at_xpath('/siteData/forecastGroup')
            issued_at = utc_stamp(group&.at_xpath("dateTime[@name='forecastIssue'][@zone='UTC']/timeStamp"))
            periods = group ? group.xpath('forecast').map { |node| daily_period(node) } : []
            return if issued_at.nil? || periods.empty?

            { kind: 'daily', issued_at: issued_at, periods: periods }
          end

          def daily_period(node)
            wind = node.at_xpath('winds/wind')
            {
              name: node.at_xpath('period/@textForecastName')&.value, label: text(node, 'period'),
              summary: text(node, 'textSummary'), short_summary: text(node, 'abbreviatedForecast/textSummary'),
              icon_code: text(node, 'abbreviatedForecast/iconCode'), pop_pct: number(node, 'abbreviatedForecast/pop'),
              temperature_c: number(node, 'temperatures/temperature'),
              temperature_class: node.at_xpath('temperatures/temperature/@class')&.value,
              wind_speed_kmh: number(wind, 'speed'), wind_gust_kmh: number(wind, 'gust'),
              wind_direction: text(wind, 'direction'), uv_index: number(node, 'uv/index'),
              humidity_pct: number(node, 'relativeHumidity')
            }
          end

          def text(node, path)
            raw = node&.at_xpath(path)&.text
            raw.strip.presence if raw
          end

          def number(node, path)
            raw = text(node, path)
            Float(raw, exception: false) if raw
          end

          def utc_stamp(node)
            raw = node&.text&.strip
            format = TIMESTAMP_FORMATS[raw&.length]
            Time.strptime("#{raw} UTC", "#{format} %Z").utc if format
          rescue ArgumentError
            nil
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  module Weather
    module Adapters
      class EnvironmentCanada
        # Downloads the newest citypage_weather XML for a site from the MSC Datamart.
        class CitypageClient
          BASE_URL = 'https://dd.weather.gc.ca/today/citypage_weather'
          HOURS_BACK = 2
          MAX_AGE = 3.hours

          # The newest file is older than MAX_AGE, so the feed is lagging.
          class StaleData < Http::Error; end

          def initialize(http: Http.new)
            @http = http
          end

          # site_ref is "NL/s0000221". Returns the XML string.
          def fetch(site_ref:, language: 'en', now: Time.current)
            province, site = site_ref.split('/', 2)
            raise ArgumentError, "site_ref must look like NL/s0000221: #{site_ref}" if site.blank?

            hour, name = newest_file(province, site, language, now.utc)
            xml = @http.get("#{BASE_URL}/#{province}/#{hour}/#{name}")
            ensure_fresh!(xml, now)
            xml
          end

          private

          # Returns [hour_directory, file_name] for the newest file in the last few hour directories.
          def newest_file(province, site, language, now)
            pattern = /\d{8}T\d{6}\.\d{3}Z_MSC_CitypageWeather_#{Regexp.escape(site)}_#{language}\.xml/
            found = (0..HOURS_BACK).flat_map { |back| files_in_hour(province, now - back.hours, pattern) }
            raise Http::Error, "No citypage file found for #{province}/#{site}" if found.empty?

            found.max_by(&:last)
          end

          def files_in_hour(province, time, pattern)
            hour = format('%02d', time.hour)
            @http.get("#{BASE_URL}/#{province}/#{hour}/").scan(pattern).uniq.map { |name| [hour, name] }
          rescue Http::NotFound
            []
          end

          def ensure_fresh!(xml, now)
            created = CitypageParser.parse(xml)[:created_at]
            return if created && created > now - MAX_AGE

            raise StaleData, "Citypage document created #{created&.iso8601 || 'at an unknown time'}"
          end
        end
      end
    end
  end
end

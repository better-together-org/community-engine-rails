# frozen_string_literal: true

require 'json'

module BetterTogether
  module Weather
    module Adapters
      class EnvironmentCanada
        # Reads station climate observations from the MSC GeoMet OGC API.
        class ClimateClient
          BASE_URL = 'https://api.weather.gc.ca/collections'
          PAGE_SIZE = 1000
          MAX_PAGES = 20
          WINDOW_PAD = 12.hours
          COLLECTIONS = { 'hourly' => 'climate-hourly', 'daily' => 'climate-daily' }.freeze

          def initialize(http: Http.new)
            @http = http
          end

          # Returns the feature properties for a climate station between from and to (Times).
          def fetch(granularity:, climate_id:, from:, to:)
            collection = COLLECTIONS.fetch(granularity.to_s)
            window = datetime_window(granularity, from, to)
            rows = []
            MAX_PAGES.times do |page|
              batch = page_of(collection, climate_id, window, page * PAGE_SIZE)
              rows.concat(batch)
              break if batch.size < PAGE_SIZE
            end
            rows
          end

          private

          def page_of(collection, climate_id, window, offset)
            body = @http.get("#{BASE_URL}/#{collection}/items",
                             params: { f: 'json', CLIMATE_IDENTIFIER: climate_id, datetime: window,
                                       sortby: 'LOCAL_DATE', limit: PAGE_SIZE, offset: offset })
            JSON.parse(body).fetch('features', []).map { |feature| feature['properties'] || {} }
          rescue JSON::ParserError => e
            raise Http::Error, "Invalid climate JSON: #{e.message}"
          end

          # The API filters on station local time, so pad the UTC window to keep edge hours.
          def datetime_window(granularity, from, to)
            from = from.utc - WINDOW_PAD
            to = to.utc + WINDOW_PAD
            if granularity.to_s == 'daily'
              "#{from.to_date.iso8601}/#{to.to_date.iso8601}"
            else
              "#{from.iso8601}/#{to.iso8601}"
            end
          end
        end
      end
    end
  end
end

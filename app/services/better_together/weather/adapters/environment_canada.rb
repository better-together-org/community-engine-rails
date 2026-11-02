# frozen_string_literal: true

module BetterTogether
  module Weather
    module Adapters
      # Environment and Climate Change Canada (MSC) adapter. Current conditions and
      # forecasts come from the Datamart citypage XML; station history from the
      # GeoMet OGC API. Licence: ECCC Data Services End-use Licence (attribution required).
      class EnvironmentCanada < Base
        ATTRIBUTION = 'Data Source: Environment and Climate Change Canada'
        LICENCE_URL = 'https://eccc-msc.github.io/open-data/licence/readme_en/'

        def initialize(config = {}, citypage: CitypageClient.new, climate: ClimateClient.new)
          super(config)
          @citypage = citypage
          @climate = climate
        end

        def capabilities
          %i[current hourly_forecast daily_forecast observations]
        end

        def attribution
          ATTRIBUTION
        end

        def licence_url
          LICENCE_URL
        end

        def fetch_snapshot(location)
          xml = @citypage.fetch(site_ref: location.external_ref, language: language)
          parsed = CitypageParser.parse(xml)
          { current: parsed[:current], forecasts: parsed[:forecasts] }
        end

        def fetch_observations(location, granularity:, from:, to:, station_ref: nil)
          climate_id = station_ref.presence || location.observation_station_ref.presence
          raise ArgumentError, 'A climate station id is required for observations' if climate_id.nil?

          rows = @climate.fetch(granularity: granularity, climate_id: climate_id, from: from, to: to)
          ClimateParser.public_send(granularity.to_sym, rows)
        end

        private

        def language
          config[:language].presence || 'en'
        end
      end
    end
  end
end

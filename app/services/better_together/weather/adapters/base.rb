# frozen_string_literal: true

module BetterTogether
  module Weather
    module Adapters
      # Contract for weather adapters. Adapters return plain Hashes in the
      # normalised shape and never touch the database; ingest services persist them.
      #
      # fetch_snapshot(location) =>
      #   { current: { observed_at:, station_ref:, values: {measurement => Float}, condition:, icon_code:, extras: {} },
      #     forecasts: [{ kind: 'hourly'|'daily', issued_at:, periods: [Hash] }] }
      # fetch_observations(location, granularity:, from:, to:, station_ref: nil) =>
      #   [{ observed_at:, values: {measurement => Float}, condition:, flags: {} }]
      class Base
        CAPABILITIES = %i[current hourly_forecast daily_forecast observations].freeze

        attr_reader :config

        def initialize(config = {})
          @config = (config || {}).with_indifferent_access
        end

        def capabilities
          []
        end

        def supports?(capability)
          capabilities.include?(capability.to_sym)
        end

        def fetch_snapshot(_location)
          raise NotImplementedError, "#{self.class} must implement #fetch_snapshot"
        end

        def fetch_observations(_location, granularity:, from:, to:, station_ref: nil) # rubocop:disable Lint/UnusedMethodArgument
          raise NotImplementedError, "#{self.class} must implement #fetch_observations"
        end
      end
    end
  end
end

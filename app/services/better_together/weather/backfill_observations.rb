# frozen_string_literal: true

module BetterTogether
  module Weather
    # Fills gaps in the stored observation history from the source's history API.
    # Pages read only stored rows; this is the only path that asks the API for past data.
    # It creates missing hours, fills measurements the live feed lacked, and applies
    # source corrections to rows it created itself. It never replaces live_feed values.
    class BackfillObservations
      DEFAULT_DAYS = 15
      PRECIP_ONLY = %i[precip_mm].freeze

      def self.call(location, days: DEFAULT_DAYS, now: Time.current)
        new(location, days: days, now: now).call
      end

      def initialize(location, days: DEFAULT_DAYS, now: Time.current)
        @location = location
        @now = now.utc
        @from = (@now - days.days).beginning_of_hour
        @to = @now.beginning_of_hour
        @stats = Hash.new(0)
      end

      def call
        return unless eligible?

        merge_all
        @location.record_success!(last_observations_backfilled_at: @now)
        @stats
      rescue Http::Error => e
        Rails.logger.warn("[Weather] backfill failed location=#{@location.id} #{e.class}: #{e.message}")
        @location.record_error!(e)
        nil
      end

      private

      def adapter
        @adapter ||= @location.adapter
      end

      def eligible?
        adapter.supports?(:observations) && @location.observation_station_ref.present?
      end

      def merge_all
        merge(fetch('hourly'), 'hourly')
        merge(fetch('hourly', station_ref: @location.precip_station_ref), 'hourly', only: PRECIP_ONLY) if secondary?
        merge(fetch('daily'), 'daily')
      end

      def secondary?
        @location.precip_station_ref.present? && @location.precip_station_ref != @location.observation_station_ref
      end

      def fetch(granularity, station_ref: nil)
        adapter.fetch_observations(@location, granularity: granularity, from: @from, to: @to, station_ref: station_ref)
      end

      def merge(rows, granularity, only: nil)
        existing = @location.observations.where(granularity: granularity, observed_at: rows.pluck(:observed_at))
                            .index_by { |observation| observation.observed_at.to_i }
        ActiveRecord::Base.transaction do
          rows.each do |row|
            values = only ? row[:values].slice(*only) : row[:values]
            apply(existing[row[:observed_at].to_i], row, granularity, values, only)
          end
        end
      end

      def apply(observation, row, granularity, values, only)
        if observation.nil?
          return if only

          create(granularity, row, values)
        elsif observation.origin == 'live_feed' || only
          enrich(observation, values)
        else
          correct(observation, values)
        end
      end

      def create(granularity, row, values)
        @location.observations.create!(granularity: granularity, observed_at: row[:observed_at],
                                       origin: 'backfill_api', condition: row[:condition],
                                       source_flags: row[:flags], **values)
        @stats[:created] += 1
      end

      def enrich(observation, values)
        filled = observation.fill_missing_from(values)
        return if filled.empty?

        observation.source_flags = observation.source_flags.merge('enriched' => (observation.source_flags['enriched'].to_a | filled.map(&:to_s)))
        observation.save!
        @stats[:enriched] += 1
      end

      def correct(observation, values)
        observation.assign_attributes(values.compact)
        return unless observation.changed?

        observation.save!
        @stats[:updated] += 1
      end
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  module Weather
    # Pulls the live feed for one location and stores current conditions, forecasts
    # and the hourly observation. Source failures keep the previously stored data
    # and are recorded on the location; they never delete anything.
    class RefreshLocation
      def self.call(location, now: Time.current)
        new(location, now: now).call
      end

      def initialize(location, now: Time.current)
        @location = location
        @now = now
      end

      def call
        snapshot = @location.adapter.fetch_snapshot(@location)
        ActiveRecord::Base.transaction do
          store_current(snapshot[:current])
          Array(snapshot[:forecasts]).each { |forecast| store_forecast(forecast) }
        end
        @location.record_success!(last_current_fetched_at: @now, last_forecast_fetched_at: @now)
        snapshot
      rescue Http::Error => e
        Rails.logger.warn("[Weather] refresh failed location=#{@location.id} #{e.class}: #{e.message}")
        @location.record_error!(e)
        nil
      end

      private

      def store_current(current)
        return if current.nil?

        condition = @location.current_condition || @location.build_current_condition
        condition.update!(observed_at: current[:observed_at], fetched_at: @now,
                          payload: current.slice(:station_ref, :values, :condition, :icon_code, :extras))
        store_live_observation(current)
      end

      # Official backfilled rows are authoritative and are never replaced by the live feed.
      def store_live_observation(current)
        observation = @location.observations.hourly.find_or_initialize_by(observed_at: current[:observed_at].utc.beginning_of_hour)
        return if observation.persisted? && observation.origin == 'backfill_api'

        assign_live_values(observation, current)
        observation.save!
      end

      def assign_live_values(observation, current)
        observation.origin = 'live_feed'
        observation.assign_attributes(current[:values].compact)
        observation.condition = current[:condition] if current[:condition].present?
        observation.source_flags = observation.source_flags.merge('station_ref' => current[:station_ref]).compact
      end

      def store_forecast(forecast)
        record = @location.forecasts.find_or_initialize_by(kind: forecast[:kind], issued_at: forecast[:issued_at])
        record.update!(fetched_at: @now, payload: { periods: forecast[:periods] })
      end
    end
  end
end

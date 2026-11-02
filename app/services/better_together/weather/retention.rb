# frozen_string_literal: true

module BetterTogether
  module Weather
    # Applies retention windows: old observations are deleted, and superseded
    # forecasts are deleted while the newest issue of each kind is always kept.
    class Retention
      DEFAULT_OBSERVATION_DAYS = 400
      DEFAULT_FORECAST_DAYS = 7

      def initialize(observation_days: DEFAULT_OBSERVATION_DAYS, forecast_days: DEFAULT_FORECAST_DAYS, dry_run: false)
        @observation_days = Integer(observation_days)
        @forecast_days = Integer(forecast_days)
        @dry_run = dry_run
      end

      def call
        { dry_run: @dry_run, observations: purge(stale_observations), forecasts: purge(stale_forecasts) }
      end

      private

      def stale_observations
        Observation.where(Observation.arel_table[:observed_at].lt(@observation_days.days.ago))
      end

      def stale_forecasts
        latest = Forecast.group(:location_id, :kind).maximum(:issued_at)
        scope = Forecast.where(Forecast.arel_table[:fetched_at].lt(@forecast_days.days.ago))
        latest.reduce(scope) do |relation, ((location_id, kind), issued_at)|
          relation.where.not(location_id: location_id, kind: kind, issued_at: issued_at)
        end
      end

      def purge(relation)
        eligible = relation.count
        { eligible_count: eligible, deleted_count: @dry_run ? 0 : relation.in_batches.delete_all }
      end
    end
  end
end

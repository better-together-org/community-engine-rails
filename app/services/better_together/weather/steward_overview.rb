# frozen_string_literal: true

module BetterTogether
  module Weather
    # Read model for the host steward Weather tab: the feature switch state, one row per
    # source with location counts and refresh times, and the recent change trail. Source
    # counts come from one grouped query, so the list costs the same for any number of sources.
    class StewardOverview
      STALE_AFTER = 1.hour
      AUDIT_LIMIT = 20

      SourceRow = Struct.new(:source, :locations_total, :locations_enabled, :last_refresh_at,
                             :last_success_at, :stale, keyword_init: true) do
        alias_method :stale?, :stale
      end

      EMPTY_STATS = { total: 0, enabled: 0, last_success_at: nil, last_error_at: nil }.freeze

      attr_reader :now

      def initialize(now: Time.current)
        @now = now
      end

      def env_forced_off?
        Weather.env_forced_off?
      end

      def setting_enabled?
        host_platform.nil? || host_platform.weather_enabled != false
      end

      def feature_enabled?
        !env_forced_off? && setting_enabled?
      end

      def source_rows
        @source_rows ||= begin
          stats = location_stats
          Source.order(:identifier).map { |source| build_row(source, stats.fetch(source.id, EMPTY_STATS)) }
        end
      end

      # Locations of one source with their settlement names preloaded.
      def locations_for(source)
        source.locations.includes(settlement: :string_translations).to_a
              .sort_by { |location| location.settlement&.name.to_s.downcase }
      end

      def location_stale?(location, source)
        source.enabled? && location.enabled? && stale_time?(location.last_refreshed_at)
      end

      def self.last_refresh_at(location)
        [location.last_refreshed_at, location.last_error_at].compact.max
      end

      def audit_entries
        return [] unless host_platform

        BetterTogether::Activity.for_platform(host_platform)
                                .where(key: StewardToggle::KEYS.values)
                                .includes(:owner)
                                .order(created_at: :desc)
                                .limit(AUDIT_LIMIT)
      end

      def host_platform
        @host_platform ||= Current.host_platform
      end

      private

      def build_row(source, stats)
        SourceRow.new(source:, locations_total: stats[:total], locations_enabled: stats[:enabled],
                      last_success_at: stats[:last_success_at],
                      last_refresh_at: [stats[:last_success_at], stats[:last_error_at]].compact.max,
                      stale: source.enabled? && stats[:enabled].positive? && stale_time?(stats[:last_success_at]))
      end

      def stale_time?(time)
        time.nil? || time < now - STALE_AFTER
      end

      def location_stats
        table = Location.arel_table
        Location.group(:source_id)
                .pluck(:source_id, table[:id].count, enabled_count(table),
                       table[:last_refreshed_at].maximum, table[:last_error_at].maximum)
                .to_h do |source_id, total, enabled, success_at, error_at|
                  [source_id, { total:, enabled: enabled.to_i, last_success_at: success_at, last_error_at: error_at }]
                end
      end

      def enabled_count(table)
        Arel::Nodes::Sum.new([Arel::Nodes::Case.new.when(table[:enabled].eq(true)).then(1).else(0)])
      end
    end
  end
end

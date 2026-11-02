# frozen_string_literal: true

module BetterTogether
  module Weather
    # One local calendar day of stored weather. Every measurement is nil when no
    # stored row reported it; nil is never shown or charted as zero.
    DailySummary = Struct.new(
      :date, :temperature_min_c, :temperature_max_c, :temperature_mean_c,
      :precip_mm, :snow_cm, :wind_speed_kmh, :wind_gust_kmh, :partial,
      keyword_init: true
    ) do
      def self.measures
        %i[temperature_min_c temperature_max_c temperature_mean_c precip_mm snow_cm wind_speed_kmh wind_gust_kmh]
      end

      def partial?
        partial == true
      end

      def reported?(measure)
        !self[measure].nil?
      end

      def empty?
        self.class.measures.none? { |measure| reported?(measure) }
      end
    end
  end
end

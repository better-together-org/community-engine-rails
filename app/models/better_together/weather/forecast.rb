# frozen_string_literal: true

module BetterTogether
  module Weather
    # One forecast issue (hourly or daily) for a location, as an ordered list of periods.
    class Forecast < ApplicationRecord
      KINDS = %w[hourly daily].freeze
      STALE_AFTER = 6.hours

      belongs_to :location, class_name: 'BetterTogether::Weather::Location', inverse_of: :forecasts

      validates :kind, inclusion: { in: KINDS }
      validates :issued_at, :fetched_at, presence: true

      scope :hourly, -> { where(kind: 'hourly') }
      scope :daily, -> { where(kind: 'daily') }
      scope :latest_first, -> { order(issued_at: :desc) }

      def periods
        payload.fetch('periods', [])
      end

      def stale?(now: Time.current)
        fetched_at < now - STALE_AFTER
      end
    end
  end
end

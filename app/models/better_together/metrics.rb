# frozen_string_literal: true

module BetterTogether
  # Metrics tracking and reporting module
  module Metrics
    def self.table_name_prefix
      'better_together_metrics_'
    end

    # Default result level thresholds for search result counts
    # These are used as fallback when no data is available
    # In practice, levels should be calculated dynamically based on data distribution
    DEFAULT_RESULT_LEVELS = [
      {
        level: :none,
        min: 0,
        max: 0.99,
        color_rgb: '220, 38, 38',
        i18n_key: 'no_results'
      },
      {
        level: :low,
        min: 1,
        max: 4.99,
        color_rgb: '234, 88, 12',
        i18n_key: 'low_results'
      },
      {
        level: :medium,
        min: 5,
        max: 14.99,
        color_rgb: '202, 138, 4',
        i18n_key: 'medium_results'
      },
      {
        level: :high,
        min: 15,
        max: 24.99,
        color_rgb: '101, 163, 13',
        i18n_key: 'high_results'
      },
      {
        level: :excellent,
        min: 25,
        max: Float::INFINITY,
        color_rgb: '22, 163, 74',
        i18n_key: 'excellent_results'
      }
    ].freeze

    # Generate dynamic result levels based on percentile distribution
    # @param avg_results [Array<Float>] Array of average result counts
    # @return [Array<Hash>] Array of level configurations
    def self.generate_result_levels(avg_results)
      non_zero_results = avg_results.reject(&:zero?)
      return DEFAULT_RESULT_LEVELS if non_zero_results.empty?

      sorted = non_zero_results.sort
      percentiles = calculate_percentiles(sorted)

      build_result_levels(percentiles)
    end

    # Calculate percentiles for result levels
    # @param sorted [Array<Float>] Sorted array of non-zero results
    # @return [Hash] Percentile values
    def self.calculate_percentiles(sorted)
      {
        p25: percentile(sorted, 25),
        p50: percentile(sorted, 50),
        p75: percentile(sorted, 75)
      }
    end

    # Build result level configurations from percentiles
    # @param percentiles [Hash] Percentile values
    # @return [Array<Hash>] Array of level configurations
    def self.build_result_levels(percentiles)
      [
        { level: :none, min: 0, max: 0.99, color_rgb: '220, 38, 38', i18n_key: 'no_results' },
        { level: :low, min: 1, max: percentiles[:p25] - 0.01, color_rgb: '234, 88, 12', i18n_key: 'low_results' },
        { level: :medium, min: percentiles[:p25], max: percentiles[:p50] - 0.01, color_rgb: '202, 138, 4', i18n_key: 'medium_results' },
        { level: :high, min: percentiles[:p50], max: percentiles[:p75] - 0.01, color_rgb: '101, 163, 13', i18n_key: 'high_results' },
        { level: :excellent, min: percentiles[:p75], max: Float::INFINITY, color_rgb: '22, 163, 74', i18n_key: 'excellent_results' }
      ]
    end

    # Calculate percentile from sorted array
    # @param sorted_array [Array<Numeric>] Sorted array of numbers
    # @param percentile [Integer] Percentile to calculate (0-100)
    # @return [Float] The percentile value
    def self.percentile(sorted_array, percentile)
      return 0 if sorted_array.empty?

      k = (percentile / 100.0) * (sorted_array.length - 1)
      f = k.floor
      c = k.ceil

      return sorted_array[f].to_f if f == c

      # Linear interpolation
      interpolate_percentile(sorted_array, f, c, k)
    end

    # Interpolate between two values for percentile calculation
    # @param sorted_array [Array<Numeric>] Sorted array
    # @param floor_index [Integer] Floor index
    # @param ceil_index [Integer] Ceiling index
    # @param position_value [Float] Exact percentile position
    # @return [Float] Interpolated value
    def self.interpolate_percentile(sorted_array, floor_index, ceil_index, position_value)
      lower_contribution = sorted_array[floor_index] * (ceil_index - position_value)
      upper_contribution = sorted_array[ceil_index] * (position_value - floor_index)
      (lower_contribution + upper_contribution).round(1)
    end

    # Returns the range label for display (e.g., "1-4", "25+")
    def self.range_label_for(level)
      if level[:max] == Float::INFINITY
        "#{level[:min].to_i}+"
      elsif level[:min].zero? && level[:max] < 1
        '0'
      else
        "#{level[:min].to_i}-#{level[:max].to_i}"
      end
    end
  end
end

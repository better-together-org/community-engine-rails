# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a grid of impact statistics (label + value + optional icon).
    # stats_json stores a JSON array of {label:, value:, icon:} objects.
    class StatisticsBlock < Block
      COLUMN_OPTIONS = %w[2 3 4].freeze

      store_attributes :content_data do
        heading    String, default: ''
        stats_json String, default: '[]'
        columns    String, default: '3'
      end

      validates :columns, inclusion: { in: COLUMN_OPTIONS }

      # Returns an array of stat hashes with symbolized keys, or [] on parse failure.
      def parsed_stats
        JSON.parse(stats_json).map(&:symbolize_keys)
      rescue JSON::ParserError
        []
      end

      def self.content_addable?
        true
      end

      def self.extra_permitted_attributes
        super + %i[heading stats_json columns]
      end
    end
  end
end

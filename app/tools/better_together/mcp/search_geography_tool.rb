# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to search geography locations
    # Searches across continents, countries, states, regions, and settlements
    class SearchGeographyTool < ApplicationTool
      description 'Search geography locations by name across all location types'

      arguments do
        required(:query)
          .filled(:string)
          .description('Search query to match against location names')
        optional(:location_type)
          .filled(:string)
          .description('Filter by type: continent, country, state, region, settlement')
        optional(:limit)
          .filled(:integer)
          .description('Maximum number of results to return (default: 20)')
      end

      LOCATION_TYPES = {
        'continent' => BetterTogether::Geography::Continent,
        'country' => BetterTogether::Geography::Country,
        'state' => BetterTogether::Geography::State,
        'region' => BetterTogether::Geography::Region,
        'settlement' => BetterTogether::Geography::Settlement
      }.freeze

      # Search geography by name
      # @param query [String] The search query
      # @param location_type [String] Optional type filter
      # @param limit [Integer] Maximum results (default: 20)
      # @return [String] JSON array of location objects
      def call(query:, location_type: nil, limit: 20)
        with_timezone_scope do
          results = search_locations(query, location_type, limit)
          result = JSON.generate(results)

          log_invocation('search_geography',
                         { query: query, location_type: location_type, limit: limit },
                         result.bytesize)
          result
        end
      end

      private

      def search_locations(query, location_type, limit)
        models = location_type.present? ? [LOCATION_TYPES[location_type]].compact : LOCATION_TYPES.values
        per_type_limit = [limit / [models.size, 1].max, 1].max

        models.flat_map do |model|
          search_model(model, query, per_type_limit)
        end.first([limit, 100].min)
      end

      def search_model(model, query, limit)
        policy_scope(model)
          .where('identifier ILIKE ?', "%#{query}%")
          .limit(limit)
          .map { |loc| serialize_location(loc) }
      end

      def serialize_location(location)
        {
          id: location.id,
          name: location.name,
          identifier: location.identifier,
          type: location.class.name.demodulize.underscore,
          slug: location.slug
        }
      end
    end
  end
end

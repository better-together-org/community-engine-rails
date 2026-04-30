# frozen_string_literal: true

module BetterTogether
  module Search
    # Builds Elasticsearch query and suggestion payloads for CE search.
    module ElasticsearchQuery
      module_function

      def build(query)
        {
          query: query_payload(query),
          suggest: suggest_payload(query)
        }
      end

      def suggestions(response)
        (response.response.dig('suggest', 'suggestions') || []).flat_map do |entry|
          entry.fetch('options', []).map { |option| option['text'] }
        end
      end

      def query_payload(query)
        {
          bool: {
            must: [
              {
                multi_match: {
                  query:,
                  type: 'best_fields',
                  operator: 'and'
                }
              }
            ]
          }
        }
      end

      def suggest_payload(query)
        {
          text: query,
          suggestions: {
            term: {
              field: 'name',
              suggest_mode: 'always'
            }
          }
        }
      end
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  module Elasticsearch
    module Documents
      module Joatu
        # Elasticsearch document mapping for JOATU requests.
        module Request
          extend ActiveSupport::Concern
          include BetterTogether::Elasticsearch::Document

          included do
            settings index: default_elasticsearch_index
          end

          def as_indexed_json(_options = {})
            {
              id:,
              name:,
              slug:,
              description: description.present? ? search_text_value(description) : nil,
              status:,
              urgency:
            }.compact.as_json
          end
        end
      end
    end
  end
end

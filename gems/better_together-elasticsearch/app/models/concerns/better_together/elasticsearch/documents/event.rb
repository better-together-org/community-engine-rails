# frozen_string_literal: true

module BetterTogether
  module Elasticsearch
    module Documents
      module Event
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
            identifier:,
            description: description.present? ? search_text_value(description) : nil
          }.compact.as_json
        end
      end
    end
  end
end

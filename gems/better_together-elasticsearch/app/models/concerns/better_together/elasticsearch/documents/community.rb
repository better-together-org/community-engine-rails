# frozen_string_literal: true

module BetterTogether
  module Elasticsearch
    module Documents
      # Elasticsearch document mapping for community records.
      module Community
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
            description:,
            description_html: description_html.present? ? search_text_value(description_html) : nil
          }.compact.as_json
        end
      end
    end
  end
end

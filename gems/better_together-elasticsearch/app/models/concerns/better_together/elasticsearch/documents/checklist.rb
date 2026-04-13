# frozen_string_literal: true

module BetterTogether
  module Elasticsearch
    module Documents
      module Checklist
        extend ActiveSupport::Concern
        include BetterTogether::Elasticsearch::Document

        included do
          settings index: default_elasticsearch_index
        end

        def as_indexed_json(_options = {})
          {
            id:,
            title:,
            slug:,
            identifier:
          }.compact.as_json
        end
      end
    end
  end
end

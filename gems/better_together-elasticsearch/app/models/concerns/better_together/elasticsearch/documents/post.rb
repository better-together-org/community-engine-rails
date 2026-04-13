# frozen_string_literal: true

module BetterTogether
  module Elasticsearch
    module Documents
      module Post
        extend ActiveSupport::Concern
        include BetterTogether::Elasticsearch::Document

        included do
          settings index: default_elasticsearch_index
        end

        def as_indexed_json(_options = {})
          as_json(
            only: [:id],
            methods: [:title, :name, :slug, *self.class.localized_attribute_names_for_search.select do |attribute|
              attribute.start_with?('title', 'slug', 'content')
            end]
          )
        end
      end
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  module Elasticsearch
    module Documents
      # Elasticsearch document mapping for page records.
      module Page
        extend ActiveSupport::Concern
        include BetterTogether::Elasticsearch::Document

        included do
          settings index: default_elasticsearch_index
        end

        def as_indexed_json(_options = {}) # rubocop:todo Metrics/MethodLength
          json = as_json(
            only: [:id],
            methods: [:title, :name, :slug, *self.class.localized_attribute_names_for_search.select do |attribute|
              attribute.start_with?('title', 'slug', 'content')
            end],
            include: {
              markdown_blocks: {
                only: %i[id],
                methods: [:indexed_elasticsearch_content]
              },
              rich_text_blocks: {
                only: %i[id],
                methods: [:indexed_elasticsearch_content]
              },
              template_blocks: {
                only: %i[id],
                methods: [:indexed_elasticsearch_content]
              }
            }
          )

          json['template_content'] = BetterTogether::TemplateRendererService.new(template).render_for_all_locales if template.present?
          json
        end
      end
    end
  end
end

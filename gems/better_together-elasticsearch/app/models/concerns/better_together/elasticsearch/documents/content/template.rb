# frozen_string_literal: true

module BetterTogether
  module Elasticsearch
    module Documents
      module Content
        # Elasticsearch document mapping for template blocks.
        module Template
          extend ActiveSupport::Concern

          def indexed_elasticsearch_content
            {
              id:,
              localized_content: BetterTogether::TemplateRendererService.new(template_path).render_for_all_locales
            }
          end
        end
      end
    end
  end
end

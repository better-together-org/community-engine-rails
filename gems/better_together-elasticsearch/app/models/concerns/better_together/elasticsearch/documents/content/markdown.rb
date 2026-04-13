# frozen_string_literal: true

module BetterTogether
  module Elasticsearch
    module Documents
      module Content
        module Markdown
          extend ActiveSupport::Concern

          def indexed_elasticsearch_content
            {
              id:,
              localized_content: I18n.available_locales.index_with do |locale|
                I18n.with_locale(locale) { rendered_plain_text }
              end
            }
          end
        end
      end
    end
  end
end

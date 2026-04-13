# frozen_string_literal: true

module BetterTogether
  module Elasticsearch
    module Documents
      module Content
        module RichText
          extend ActiveSupport::Concern

          def indexed_elasticsearch_content
            {
              id:,
              localized_content: self.class.localized_attribute_list.map do |attr|
                value = public_send(attr)&.to_plain_text
                value.gsub(/\n+/, ' ').strip if value.present?
              end.compact
            }
          end
        end
      end
    end
  end
end

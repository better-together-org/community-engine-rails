# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a collapsible accordion of FAQ-style question/answer pairs.
    # accordion_items_json stores a JSON array of {question:, answer:} objects.
    class AccordionBlock < Block
      store_attributes :content_data do
        heading               String, default: ''
        accordion_items_json  String, default: '[]'
        open_first            String, default: 'true'
      end

      # Returns an array of item hashes with symbolized keys, or [] on parse failure.
      def parsed_accordion_items
        JSON.parse(accordion_items_json).map(&:symbolize_keys)
      rescue JSON::ParserError
        []
      end

      def open_first?
        open_first == 'true'
      end

      def self.content_addable?
        true
      end

      def self.extra_permitted_attributes
        super + %i[heading accordion_items_json open_first]
      end
    end
  end
end

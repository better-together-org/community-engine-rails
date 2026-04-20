# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a highlighted pull quote or testimonial with attribution.
    class QuoteBlock < Block
      store_attributes :content_data do
        quote_text               String, default: ''
        attribution_name         String, default: ''
        attribution_title        String, default: ''
        attribution_organization String, default: ''
      end

      validates :quote_text, presence: true

      def self.content_addable?
        false
      end

      def self.extra_permitted_attributes
        super + %i[quote_text attribution_name attribution_title attribution_organization]
      end
    end
  end
end

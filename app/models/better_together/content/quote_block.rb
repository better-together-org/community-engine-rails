# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a highlighted pull quote or testimonial with attribution.
    class QuoteBlock < Block
      include Translatable

      translates :attribution_name, :attribution_title, :attribution_organization, type: :string
      translates :quote_text, type: :text

      validates :quote_text, presence: true

      def self.content_addable?(actor: nil)
        BetterTogether::FeatureGate.enabled?('new_content_blocks', actor:, platform: Current.platform)
      rescue KeyError
        false
      end

      def self.extra_permitted_attributes
        super + %i[quote_text attribution_name attribution_title attribution_organization]
      end
    end
  end
end

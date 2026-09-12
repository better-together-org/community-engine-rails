# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a prominent call-to-action panel with heading, body text, and up to two buttons.
    class CallToActionBlock < Block
      include Translatable

      LAYOUTS = %w[centered left right split].freeze

      translates :heading, :subheading, :primary_button_label, :secondary_button_label,
                 :primary_button_url, :secondary_button_url, type: :string
      translates :body_text, type: :text

      store_attributes :content_data do
        layout String, default: 'centered'
      end

      validates :layout, inclusion: { in: LAYOUTS }

      def self.content_addable?(actor: nil)
        BetterTogether::FeatureGate.enabled?('new_content_blocks', actor:, platform: Current.platform)
      rescue KeyError
        false
      end

      def self.extra_permitted_attributes
        super + %i[heading subheading body_text primary_button_label primary_button_url
                   secondary_button_label secondary_button_url layout]
      end
    end
  end
end

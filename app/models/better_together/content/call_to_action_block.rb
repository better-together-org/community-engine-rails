# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a prominent call-to-action panel with heading, body text, and up to two buttons.
    class CallToActionBlock < Block
      LAYOUTS = %w[centered left right split].freeze

      store_attributes :content_data do
        heading               String, default: ''
        subheading            String, default: ''
        body_text             String, default: ''
        primary_button_label  String, default: ''
        primary_button_url    String, default: ''
        secondary_button_label String, default: ''
        secondary_button_url  String, default: ''
        layout                String, default: 'centered'
      end

      validates :layout, inclusion: { in: LAYOUTS }

      def self.content_addable?
        true
      end

      def self.extra_permitted_attributes
        super + %i[heading subheading body_text primary_button_label primary_button_url
                   secondary_button_label secondary_button_url layout]
      end
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders raw html from an attribute
    class Css < Block
      translates :content, type: :text

      store_attributes :css_settings do
        general_styling_enabled String, default: 'false'
      end
    end
  end
end

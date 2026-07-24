# frozen_string_literal: true

module BetterTogether
  module Content
    # Uses Trix editor and Active Storage to allow user to create and display rich text content
    class RichText < Block
      include Translatable

      translates :content, backend: :action_text

      store_attributes :css_settings do
        css_classes String, default: 'my-5'
      end

      # Plain-text content per locale, HTML stripped, for search indexing.
      def indexed_localized_content
        I18n.available_locales.filter_map do |locale|
          Mobility.with_locale(locale) { content&.to_plain_text.presence }
        end
      end
    end
  end
end

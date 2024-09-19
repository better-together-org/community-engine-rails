# frozen_string_literal: true

module BetterTogether
  module Content
    # Uses Trix editor and Active Storage to allow user to create and display rich text content
    class Hero < Block
      include Translatable

      has_many :page_blocks, foreign_key: :block_id, dependent: :destroy
      has_many :pages, through: :page_blocks

      translates :heading, :subheading, :cta_text, type: :string
      translates :content, backend: :action_text

      has_one_attached :background_image

      store_attributes :content_data do
        cta_url String, default: ''
      end

      store_attributes :css_settings do
        overlay_color String, default: '#000'
        overlay_opacity Float, default: 0.25
        heading_color String, default: ''
        paragraph_color String, default: ''
      end

      def self.extra_permitted_attributes
        %i[ background_image ]
      end

      def overlay_styles
        {
          background_color: overlay_color,
          opacity: overlay_opacity
        }
      end

      def inline_overlay_styles
        inline_styles(overlay_styles)
      end
    end
  end
end

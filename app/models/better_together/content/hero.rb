# frozen_string_literal: true

module BetterTogether
  module Content
    # Uses Trix editor and Active Storage to allow user to create and display rich text content
    class Hero < Block
      include Translatable

      has_many :page_blocks, foreign_key: :block_id, dependent: :destroy
      has_many :pages, through: :page_blocks

      translates :heading, :cta_text, type: :string
      translates :content, backend: :action_text

      AVAILABLE_BTN_CLASSES = {
        primary: 'btn-primary',
        primary_outline: 'btn-outline-primary',
        secondary: 'btn-secondary',
        secondary_outline: 'btn-outline-secondary',
        success: 'btn-success',
        success_outline: 'btn-outline-success',
        info: 'btn-info',
        info_outline: 'btn-outline-info',
        warning: 'btn-warning',
        warning_outline: 'btn-outline-warning',
        danger: 'btn-danger',
        danger_outline: 'btn-outline-danger',
        light: 'btn-light',
        light_outline: 'btn-outline-light',
        dark: 'btn-dark',
        dark_outline: 'btn-outline-dark'
      }

      store_attributes :content_data do
        cta_url String, default: ''
      end

      store_attributes :css_settings do
        container_class String, default: ''
        overlay_color String, default: '#000'
        overlay_opacity Float, default: 0.25
        heading_color String, default: ''
        paragraph_color String, default: ''
        cta_button_style String, default: 'btn-primary'
      end

      validates :cta_button_style, inclusion: { in: AVAILABLE_BTN_CLASSES.values }

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

      include ::BetterTogether::RemoveableAttachment
    end
  end
end

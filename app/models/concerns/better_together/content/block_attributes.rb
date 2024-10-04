module BetterTogether
  module Content
    module BlockAttributes
      extend ActiveSupport::Concern

      VALID_CONTAINER_CLASSES = %w[ container container-fluid]
      VALID_DIMENSION_UNITS = /\A[0-9]+(px|%|vh|vw|em|rem)?\z/.freeze
      DIMENSION_ATTRIBUTES = %w[ height max_height ]
      MARGIN_PADDING_ATTRIBUTES = %w[margin_top margin_right margin_bottom margin_left padding_top padding_right padding_bottom padding_left].freeze

      included do
        require 'storext'
        include ::Storext.model

        include BetterTogether::Creatable
        include BetterTogether::Privacy
        include BetterTogether::Translatable
        include BetterTogether::Visible

        validate :validate_css_units

        validates :container_class, inclusion: { in: VALID_CONTAINER_CLASSES, message: 'must be a valid Bootstrap container class (container, container-fluid) or none.' }, allow_blank: true
        validates :height, format: { with: VALID_DIMENSION_UNITS, message: 'must be a valid unit (px, %, vh, vw, em, rem)' }, allow_blank: true
        validates :max_height, format: { with: VALID_DIMENSION_UNITS, message: 'must be a valid unit (px, %, vh, vw, em, rem)' }, allow_blank: true

        store_attributes :accessibility_attributes do
          aria_label String, default: ''
          # aria_hidden Boolean, default: false
          aria_describedby String, default: ''
          aria_live String, default: 'polite' # 'polite' or 'assertive'
          aria_role String, default: ''
          aria_controls String, default: ''
          # aria_expanded Boolean, default: false
          aria_tabindex Integer, default: 0
        end

        store_attributes :content_data do
          # Add content-specific attributes here
        end

        store_attributes :content_settings do
          # Add content-specific settings here
        end

        store_attributes :data_attributes do
          data_controller String, default: ''
          data_action String, default: ''
          data_target String, default: ''
        end

        store_attributes :html_attributes do
          # Add HTML attributes here
        end

        store_attributes :layout_settings do
          # Add layout-related settings here
        end

        store_attributes :css_settings do
          css_classes String, default: ''
          css_styles String, default: ''
          container_class String, default: 'container'

          height String, default: ''
          max_height String, default: ''

          # General Block Styling Attributes
          background_color String, default: ''
          text_color String, default: ''

          margin_top String, default: ''
          margin_right String, default: ''
          margin_bottom String, default: ''
          margin_left String, default: ''

          padding_top String, default: ''
          padding_right String, default: ''
          padding_bottom String, default: ''
          padding_left String, default: ''
        end
      end

      def block_styles
        {
          background_color: background_color,
          color: text_color,
          margin_top: margin_top,
          margin_bottom: margin_bottom,
          margin_left: margin_left,
          margin_right: margin_right,
          padding_top: padding_top,
          padding_bottom: padding_bottom,
          padding_left: padding_left,
          padding_right: padding_right,
          height: height,
          max_height: max_height
        }
      end

      def has_custom_styling?
        MARGIN_PADDING_ATTRIBUTES.any? { |attr| send(attr).present? } ||
        DIMENSION_ATTRIBUTES.any? { |attr| send(attr).present? } ||
        background_color.present? || text_color.present? || css_classes.present?
      end

      def inline_block_styles
        inline_styles(block_styles)
      end

      def inline_classes
        classes = ['']

        classes.concat([(container_class if container_class.present?), (css_classes if css_classes.present?)])

        return classes.compact.join(' ')
      end

      def inline_styles(styles_hash)
        styles_hash.map { |k, v| "#{k.to_s.dasherize}: #{v};" if v.present? }.compact.join(' ').strip
      end

      private

      def validate_css_units
        MARGIN_PADDING_ATTRIBUTES.each do |attribute|
          value = send(attribute)
          unless value.blank? || value.match?(VALID_DIMENSION_UNITS)
            errors.add(attribute, "must be a valid CSS unit (e.g., '10px', '1em')")
          end
        end
      end
    end
  end
end

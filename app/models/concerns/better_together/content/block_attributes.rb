# frozen_string_literal: true

require 'storext'

module BetterTogether
  module Content
    module BlockAttributes
      extend ActiveSupport::Concern

      included do
        require 'storext'
        include ::Storext.model
        validate :validate_css_units

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
  
        store_attributes :media_settings do
          attribution_url String, default: ''
        end
  
        store_attributes :css_settings do
          css_classes String, default: ''
          css_styles String, default: ''
  
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
          padding_right: padding_right
        }
      end

      def has_custom_styling?
        background_color.present? || text_color.present? || 
        margin_top.present? || margin_right.present? || 
        margin_bottom.present? || margin_left.present? || 
        padding_top.present? || padding_right.present? || 
        padding_bottom.present? || padding_left.present? || 
        css_classes.present?
      end      

      def inline_block_styles
        inline_styles(block_styles)
      end

      def inline_styles(styles_hash)
        styles_hash.map { |k, v| next unless v.present?; "#{k.to_s.dasherize}: #{v};" }.join(' ').strip
      end

      private

      def validate_css_units
        %w[margin_top margin_right margin_bottom margin_left padding_top padding_right padding_bottom padding_left].each do |attribute|
          value = send(attribute)
          unless value.blank? || value.match?(/\A\d+(px|em|rem|%)?\z/)
            errors.add(attribute, "must be a valid CSS unit (e.g., '10px', '1em')")
          end
        end
      end
    end
  end
end

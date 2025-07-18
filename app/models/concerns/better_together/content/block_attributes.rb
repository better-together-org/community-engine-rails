# frozen_string_literal: true

module BetterTogether
  module Content
    # rubocop:todo Style/Documentation
    module BlockAttributes # rubocop:todo Metrics/ModuleLength, Style/Documentation
      # rubocop:enable Style/Documentation
      extend ActiveSupport::Concern

      VALID_CONTAINER_CLASSES = %w[container container-fluid].freeze
      VALID_DIMENSION_UNITS = /\A[0-9]+(px|%|vh|vw|em|rem)?\z/
      DIMENSION_ATTRIBUTES = %w[min_height height max_height].freeze
      BACKGROUND_ATTRIBUTES = %w[background_color background_size background_repeat background_position].freeze
      BORDER_ATTRIBUTES = %w[border_top_left_radius border_top_right_radius border_bottom_right_radius
                             border_bottom_left_radius].freeze
      MARGIN_PADDING_ATTRIBUTES = %w[margin_top margin_right margin_bottom margin_left padding_top padding_right
                                     padding_bottom padding_left].freeze

      included do # rubocop:todo Metrics/BlockLength
        require 'storext'
        include ::Storext.model

        include ::BetterTogether::Creatable
        include ::BetterTogether::Privacy
        include ::BetterTogether::Translatable
        include ::BetterTogether::Visible

        has_one_attached :background_image_file do |attachable|
          attachable.variant :optimized_jpeg, resize_to_limit: [1920, 1080],
                                              # rubocop:todo Layout/LineLength
                                              saver: { strip: true, quality: 90, interlace: true, optimize_coding: true, trellis_quant: true, quant_table: 3 }, format: 'jpg'
          # rubocop:enable Layout/LineLength
          attachable.variant :optimized_png, resize_to_limit: [1920, 1080], saver: { strip: true, quality: 90 },
                                             format: 'png'
        end

        validates :background_image_file,
                  content_type: CONTENT_TYPES,
                  size: { less_than: 20.megabytes, message: 'is too large' }

        validate :validate_css_units

        validates :container_class,
                  # rubocop:todo Layout/LineLength
                  inclusion: { in: VALID_CONTAINER_CLASSES, message: 'must be a valid Bootstrap container class (container, container-fluid) or none.' }, allow_blank: true
        # rubocop:enable Layout/LineLength

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

          general_styling_enabled String, default: 'true'

          height String, default: ''
          min_height String, default: ''
          max_height String, default: ''

          # General Block Styling Attributes
          text_color String, default: ''

          background_color String, default: ''
          background_image String, default: ''
          background_size String, default: ''
          background_repeat String, default: ''
          background_position String, default: ''

          border_top_left_radius String, default: ''
          border_top_right_radius String, default: ''
          border_bottom_right_radius String, default: ''
          border_bottom_left_radius String, default: ''

          margin_top String, default: ''
          margin_right String, default: ''
          margin_bottom String, default: ''
          margin_left String, default: ''

          padding_top String, default: ''
          padding_right String, default: ''
          padding_bottom String, default: ''
          padding_left String, default: ''
        end

        include ::BetterTogether::RemoveableAttachment
      end

      # rubocop:todo Metrics/MethodLength
      def block_styles # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        styles = {
          background_color:,
          background_image:,
          background_position:,
          background_repeat:,
          background_size:,
          color: text_color,
          border_top_left_radius:,
          border_bottom_right_radius:,
          border_bottom_left_radius:,
          border_top_right_radius:,
          margin_top:,
          margin_bottom:,
          margin_left:,
          margin_right:,
          padding_top:,
          padding_bottom:,
          padding_left:,
          padding_right:,
          height:,
          min_height:,
          max_height:
        }

        if background_image_file.attached?
          ActiveStorage::Current.url_options = { host: BetterTogether.base_url }

          bg_image_style = [
            # rubocop:todo Layout/LineLength
            "url(#{Rails.application.routes.url_helpers.rails_storage_proxy_url(optimized_background_image)})", background_image.presence
            # rubocop:enable Layout/LineLength
          ].reject(&:blank?).join(', ')
          styles = styles.merge({
                                  background_image: bg_image_style,
                                  background_size: (background_size.present? ? background_size : 'cover')
                                })
        end

        styles
      end
      # rubocop:enable Metrics/MethodLength

      # rubocop:todo Metrics/PerceivedComplexity
      # rubocop:todo Metrics/AbcSize
      # rubocop:todo Naming/PredicatePrefix
      def has_custom_styling? # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/PerceivedComplexity
        BACKGROUND_ATTRIBUTES.any? { |attr| send(attr).present? } ||
          BORDER_ATTRIBUTES.any? { |attr| send(attr).present? } ||
          MARGIN_PADDING_ATTRIBUTES.any? { |attr| send(attr).present? } ||
          DIMENSION_ATTRIBUTES.any? { |attr| send(attr).present? } ||
          text_color.present? || css_classes.present?
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/PerceivedComplexity
      # rubocop:enable Naming/PredicatePrefix

      def inline_block_styles
        inline_styles(block_styles)
      end

      def inline_classes
        classes = ['']

        classes.push((container_class if container_class.present?), (css_classes if css_classes.present?))

        classes.compact.join(' ')
      end

      def inline_styles(styles_hash)
        styles_hash.map { |k, v| "#{k.to_s.dasherize}: #{v};" if v.present? }.compact.join(' ').strip
      end

      def optimized_background_image
        if background_image_file.content_type == 'image/svg+xml'
          # If SVG, return the original without transformation
          background_image_file
        else
          # For other formats, analyze to determine transparency
          metadata = background_image_file.metadata
          if background_image_file.content_type == 'image/png' && metadata[:alpha]
            # If PNG with transparency, return the optimized PNG variant
            background_image_file.variant(:optimized_png)
          else
            # Otherwise, use the optimized JPG variant
            background_image_file.variant(:optimized_jpeg)
          end
        end
      end

      private

      # rubocop:todo Metrics/PerceivedComplexity
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      def validate_css_units # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        BORDER_ATTRIBUTES.each do |attribute|
          value = send(attribute)
          unless value.blank? || value.match?(VALID_DIMENSION_UNITS)
            errors.add(attribute, "must be a valid CSS unit (e.g., '10px', '1em')")
          end
        end
        DIMENSION_ATTRIBUTES.each do |attribute|
          value = send(attribute)
          unless value.blank? || value.match?(VALID_DIMENSION_UNITS)
            errors.add(attribute, "must be a valid CSS unit (e.g., '10px', '1em')")
          end
        end

        MARGIN_PADDING_ATTRIBUTES.each do |attribute|
          value = send(attribute)
          unless value.blank? || value.match?(VALID_DIMENSION_UNITS)
            errors.add(attribute, "must be a valid CSS unit (e.g., '10px', '1em')")
          end
        end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity
    end
  end
end

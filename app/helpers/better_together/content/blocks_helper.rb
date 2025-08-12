# frozen_string_literal: true

require 'css_parser'

module BetterTogether
  module Content
    # Helpers for Content Blocks
    module BlocksHelper
      ALLOWED_CSS_PROPERTIES = %w[
        align-items background background-color border border-color border-radius border-style
        border-width color display flex flex-direction font-size font-weight height justify-content
        line-height margin margin-bottom margin-left margin-right margin-top max-height max-width
        min-height min-width padding padding-bottom padding-left padding-right padding-top text-align
        text-decoration width
      ].freeze

      # Returns an array of acceptable image file types
      def acceptable_image_file_types
        BetterTogether::Attachments::Images::VALID_IMAGE_CONTENT_TYPES
      end

      # Helper to generate a unique temp_id for a model
      def temp_id_for(model, temp_id: SecureRandom.uuid)
        model.persisted? ? model.id : temp_id
      end

      # Sanitize css content by only allowing whitelisted properties
      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/AbcSize
      def sanitize_css(content)
        return if content.blank?

        parser = CssParser::Parser.new
        parser.add_block!(content)
        safe_css = ''

        parser.each_selector do |selector, declarations, _specificity, media_types|
          safe_decls = declarations.split(';').filter_map do |decl|
            property, value = decl.split(':', 2)
            next unless property && value

            property = property.strip.downcase
            value = value.strip
            next unless ALLOWED_CSS_PROPERTIES.include?(property)

            "#{property}: #{value}"
          end
          next if safe_decls.empty?

          if media_types&.any?
            safe_css << "@media #{media_types.join(', ')} { #{selector} { #{safe_decls.join('; ')} } }\n"
          else
            safe_css << "#{selector} { #{safe_decls.join('; ')} }\n"
          end
        end
        # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/AbcSize

        safe_css.presence
      rescue CssParser::ParserError
        nil
      end
    end
  end
end

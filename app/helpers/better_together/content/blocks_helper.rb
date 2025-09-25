# frozen_string_literal: true

require 'css_parser'

module BetterTogether
  module Content
    # Helpers for Content Blocks
    module BlocksHelper
      ALLOWED_CSS_PROPERTIES = %w[
        align-items aspect-ratio background background-color border border-color border-radius
        border-style border-width box-shadow color content display flex flex-direction font-family
        font-size font-weight height justify-content left line-height margin margin-bottom margin-left
        margin-right margin-top max-height max-width min-height min-width object-fit overflow
        overflow-y padding padding-bottom padding-left padding-right padding-top position text-align
        text-decoration text-shadow width z-index
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
            raw_property, value = decl.split(':', 2)
            next unless raw_property && value

            property = raw_property.strip
            normalized = property.downcase
            value = value.strip
            next unless ALLOWED_CSS_PROPERTIES.include?(normalized) || property.start_with?('--')

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

      # Sanitize HTML content for safe rendering in custom blocks
      def sanitize_block_html(html)
        allowed_tags = %w[p br strong em b i ul ol li a span h1 h2 h3 h4 h5 h6 img figure figcaption blockquote pre
                          code iframe div]
        allowed_attrs = %w[href src alt style title class target rel]
        sanitize(html.to_s, tags: allowed_tags, attributes: allowed_attrs)
      end

      # Very basic CSS sanitizer: strips dangerous patterns
      def sanitize_block_css(css)
        return '' if css.blank?

        sanitized = css.to_s.dup
        # Remove expression() and javascript: and url(javascript:...) patterns
        sanitized.gsub!(/expression\s*\(/i, '')
        sanitized.gsub!(/url\s*\(\s*javascript:[^)]*\)/i, 'url("")')
        sanitized
      end
    end
  end
end

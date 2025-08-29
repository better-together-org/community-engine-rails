# frozen_string_literal: true

module BetterTogether
  module Content
    # Helpers for Content Blocks
    module BlocksHelper
      # Returns an array of acceptable image file types
      def acceptable_image_file_types
        BetterTogether::Attachments::Images::VALID_IMAGE_CONTENT_TYPES
      end

      # Helper to generate a unique temp_id for a model
      def temp_id_for(model, temp_id: SecureRandom.uuid)
        model.persisted? ? model.id : temp_id
      end

      # Sanitize HTML content for safe rendering in custom blocks
      def sanitize_block_html(html)
        allowed_tags = %w[p br strong em b i ul ol li a span h1 h2 h3 h4 h5 h6 img figure figcaption blockquote pre
                          code]
        allowed_attrs = %w[href src alt title class target rel]
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

# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Rich-text scrubber that keeps Action Text's allowed tags and attributes and additionally lets through the
    # privacy-enhanced YouTube iframe a video attachment renders. Any other iframe, and any iframe outside an
    # attachment, is still removed. Opt in with:
    #
    #   ActionText::ContentHelper.scrubber = BetterTogether::ContentSecurity::VideoEmbedScrubber.new
    class VideoEmbedScrubber < Rails::HTML::PermitScrubber
      EXTRA_ATTRIBUTES = %w[allow allowfullscreen frameborder referrerpolicy].freeze

      def initialize
        super
        self.tags = base_tags + [ActionText::Attachment.tag_name, 'figure', 'figcaption', 'iframe']
        self.attributes = base_attributes + EXTRA_ATTRIBUTES
      end

      def allowed_node?(node)
        return video_embed_iframe?(node) if node.name == 'iframe'

        super
      end

      private

      def base_tags
        (ActionText::ContentHelper.allowed_tags || ActionText::ContentHelper.sanitizer.class.allowed_tags).to_a
      end

      def base_attributes
        (ActionText::ContentHelper.allowed_attributes ||
         ActionText::ContentHelper.sanitizer.class.allowed_attributes).to_a
      end

      # The iframe sits inside figure > div, not directly under the attachment, so check every ancestor.
      def video_embed_iframe?(node)
        node.ancestors.any? { |ancestor| ancestor.name == ActionText::Attachment.tag_name } &&
          node['src'].to_s.start_with?(BetterTogether::Content::VideoBlock::PRIVACY_EMBED_HOST)
      end
    end
  end
end

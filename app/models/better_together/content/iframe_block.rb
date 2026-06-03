# frozen_string_literal: true

module BetterTogether
  module Content
    # Generic iframe embed block with CSP-aware rendering and validation.
    class IframeBlock < Block
      include Translatable

      ASPECT_RATIOS = %w[16x9 4x3 1x1 21x9].freeze

      translates :title, :caption, type: :string

      store_attributes :content_data do
        iframe_url String, default: ''
        aspect_ratio String, default: '16x9'
      end

      validates :iframe_url, presence: true
      validates :aspect_ratio, inclusion: { in: ASPECT_RATIOS }
      validate :iframe_url_must_be_https

      def embed_url
        iframe_url
      end

      def embed_title
        title.presence || I18n.t('better_together.content.blocks.iframe_block.default_title')
      end

      def self.content_addable?
        true
      end

      def self.extra_permitted_attributes
        super + %i[iframe_url aspect_ratio title caption]
      end

      private

      def iframe_url_must_be_https
        return if iframe_url.blank?
        return if BetterTogether::ContentSecurityPolicySources.origin_for_url(iframe_url).present?

        errors.add(:iframe_url, :invalid)
      end
    end
  end
end

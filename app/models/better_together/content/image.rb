# frozen_string_literal: true

require 'storext'

module BetterTogether
  module Content
    # Allows the user to ceate and display image content
    class Image < Block
      include ::Storext.model
      include Base64ImageInput
      include AttachableBlock

      CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp image/svg+xml].freeze

      has_one_attached :media

      delegate :url, to: :media

      # API clients send the image as base64 (media_data); the caption is then required, as it is the image's text.
      accepts_base64_image :media_data, attachment: :media, filename_field: :media_filename, default_name: 'image'
      validate :caption_required_for_api_images

      translates :attribution, :alt_text, :caption, :attribution_url, type: :string

      validates :attribution_url,
                format: {
                  with: %r{\A(http|https)://[a-zA-Z0-9\-.]+\.[a-z]{2,}(/\S*)?\z},
                  allow_blank: true,
                  message: 'must be a valid URL starting with "http" or "https"'
                }

      validates :media,
                presence: true,
                attached: true,
                content_type: CONTENT_TYPES,
                size: { less_than: 100.megabytes, message: 'is too large' }

      def self.content_addable?(actor: nil) # rubocop:disable Lint/UnusedMethodArgument
        true
      end

      def self.extra_permitted_attributes
        super + %i[media]
      end

      def attachable_plain_text_representation(_caption = nil)
        caption.presence || '[Image]'
      end

      private

      def caption_required_for_api_images
        errors.add(:caption, :blank) if (media_data.present? || media_data_received?) && caption.blank?
      end
    end
  end
end

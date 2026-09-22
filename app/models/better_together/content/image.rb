# frozen_string_literal: true

require 'storext'

module BetterTogether
  module Content
    # Allows the user to ceate and display image content
    class Image < Block
      include ::Storext.model

      CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp image/svg+xml].freeze

      has_one_attached :media

      delegate :url, to: :media

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
    end
  end
end

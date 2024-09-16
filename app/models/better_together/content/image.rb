# frozen_string_literal: true

module BetterTogether
  module Content
    # Allows the user to ceate and display image content
    class Image < Block
      include Translatable

      CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp image/svg+xml].freeze

      has_one_attached :media
      has_many :page_blocks, foreign_key: :block_id, dependent: :destroy

      delegate :url, to: :media

      translates :attribution, type: :string
      translates :alt_text, type: :string
      translates :caption, type: :string

      validates :media,
                presence: true,
                attached: true,
                processable_image: true,
                content_type: CONTENT_TYPES,
                size: { less_than: 100.megabytes, message: 'is too large' }

      validates :attribution_url,
                format: {
                  with: %r{\A(http|https)://[a-zA-Z0-9\-\.]+\.[a-z]{2,}(/\S*)?\z},
                  allow_blank: true,
                  message: 'must be a valid URL starting with "http" or "https"'
                }
      
      def self.extra_permitted_attributes
        %i[ media ]
      end
    end
  end
end

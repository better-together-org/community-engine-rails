# frozen_string_literal: true

require 'storext'

module BetterTogether
  module Content
    # Allows the user to ceate and display image content
    class Image < Block
      include ::Storext.model

      CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp image/svg+xml].freeze

      has_one_attached :media
      has_many :page_blocks, foreign_key: :block_id, dependent: :destroy
      has_many :pages, through: :page_blocks

      delegate :url, to: :media

      translates :attribution, type: :string
      translates :alt_text, type: :string
      translates :caption, type: :string

      store_attributes :media_settings do
        attribution_url String, default: ''
      end

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

      include ::BetterTogether::RemoveableAttachment

      def self.content_addable?
        true
      end

      def self.extra_permitted_attributes
        super + %i[media]
      end
    end
  end
end

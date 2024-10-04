# frozen_string_literal: true

module BetterTogether
  module Content
    # Allows the user to ceate and display image content
    class Image < Medium
      # include Translatable
      # include ::BetterTogether::Content::BlockAttributes

      CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp image/svg+xml].freeze

      has_one_attached :media
      has_many :page_blocks, foreign_key: :block_id, dependent: :destroy
      has_many :pages, through: :page_blocks

      delegate :url, to: :media

      validates :media,
                presence: true,
                attached: true,
                content_type: CONTENT_TYPES,
                size: { less_than: 100.megabytes, message: 'is too large' }

      def self.content_addable?
        true
      end

      def self.extra_permitted_attributes
        super + %i[ media ]
      end
    end
  end
end

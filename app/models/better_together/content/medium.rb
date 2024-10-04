
require 'storext'

module BetterTogether
  module Content
    class Medium < Block
      # CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp image/svg+xml].freeze

      include ::Storext.model

      has_one_attached :media

      delegate :url, to: :media

      translates :attribution, type: :string
      translates :alt_text, type: :string
      translates :caption, type: :string

      store_attributes :media_settings do
        attribution_url String, default: ''
      end

      # validates :media,
      #       presence: true,
      #       attached: true,
      #       processable_image: true,
      #       content_type: CONTENT_TYPES,
      #       size: { less_than: 100.megabytes, message: 'is too large' }

      validates :attribution_url,
            format: {
              with: %r{\A(http|https)://[a-zA-Z0-9\-\.]+\.[a-z]{2,}(/\S*)?\z},
              allow_blank: true,
              message: 'must be a valid URL starting with "http" or "https"'
            }

      def self.extra_permitted_attributes
        super + %i[ media ]
      end

      include ::BetterTogether::RemoveableAttachment

      def self.content_addable?
        false
      end
    end
  end
end

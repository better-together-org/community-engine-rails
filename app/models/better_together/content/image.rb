
module BetterTogether
  module Content
    class Image < Block
      include Translatable

      has_one_attached :media
      
      delegate :url, to: :media

      translates :attribution, type: :string
      translates :alt_text, type: :string
      translates :caption, type: :string

      validate :acceptable_media

      validates :attribution_url,
                format: {
                  with: %r{\A(http|https):\/\/[a-zA-Z0-9\-\.]+\.[a-z]{2,}(\/\S*)?\z},
                  allow_blank: true,
                  message: 'must be a valid URL starting with "http" or "https"'
                }

      def acceptable_media
        return unless media.attached?
      end
    end
  end
end

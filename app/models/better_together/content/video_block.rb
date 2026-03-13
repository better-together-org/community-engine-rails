# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders an embedded video from YouTube, Vimeo, or a raw iframe URL.
    class VideoBlock < Block
      ASPECT_RATIOS = %w[16x9 4x3 1x1].freeze

      YOUTUBE_PATTERN = %r{
        (?:youtube\.com/(?:watch\?(?:.*&)?v=|embed/|shorts/) |
           youtu\.be/)
        ([A-Za-z0-9_-]{11})
      }x

      VIMEO_PATTERN = %r{vimeo\.com/(?:video/)?(\d+)}

      store_attributes :content_data do
        video_url    String, default: ''
        caption      String, default: ''
        aspect_ratio String, default: '16x9'
      end

      validates :video_url, presence: true
      validates :aspect_ratio, inclusion: { in: ASPECT_RATIOS }

      def provider
        return :youtube if video_url.match?(YOUTUBE_PATTERN)
        return :vimeo   if video_url.match?(VIMEO_PATTERN)

        :raw
      end

      # Returns a clean embed URL usable in an iframe src attribute.
      def embed_url
        case provider
        when :youtube
          id = video_url.match(YOUTUBE_PATTERN)&.captures&.first
          "https://www.youtube.com/embed/#{id}"
        when :vimeo
          id = video_url.match(VIMEO_PATTERN)&.captures&.first
          "https://player.vimeo.com/video/#{id}"
        else
          video_url
        end
      end

      def self.content_addable?
        true
      end

      def self.extra_permitted_attributes
        super + %i[video_url caption aspect_ratio]
      end
    end
  end
end

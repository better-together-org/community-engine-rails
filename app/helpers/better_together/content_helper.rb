# frozen_string_literal: true

require 'nokogiri'
require 'uri'

module BetterTogether
  # Helper methods for content rendering
  module ContentHelper
    ALLOWED_TAGS = %w[
      a abbr b blockquote br cite code dd dl dt em i li ol p pre q s small strong sub sup u ul
      h1 h2 h3 h4 h5 h6 img span div iframe
    ].freeze

    ALLOWED_ATTRIBUTES = %w[
      href title target rel src alt class id width height frameborder allow allowfullscreen
    ].freeze

    YOUTUBE_DOMAINS = %w[
      youtube.com www.youtube.com m.youtube.com youtu.be
    ].freeze

    def safe_html(html)
      sanitized = sanitize(html.to_s, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
      fragment = Nokogiri::HTML::DocumentFragment.parse(sanitized)
      fragment.css('iframe').each do |iframe|
        src = iframe['src']
        next unless src

        uri = URI.parse(src) rescue nil
        iframe.remove unless uri && YOUTUBE_DOMAINS.include?(uri.host)
      end
      fragment.to_html.html_safe
    end
  end
end

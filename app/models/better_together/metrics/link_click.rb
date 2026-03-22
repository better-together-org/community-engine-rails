# frozen_string_literal: true

# app/models/better_together/metrics/link_click.rb
module BetterTogether
  module Metrics
    class LinkClick < ApplicationRecord # rubocop:todo Style/Documentation
      include Utf8UrlHandler

      # Validations
      VALID_URL_SCHEMES = %w[http https tel mailto].freeze

      validates :url, presence: true
      validates :page_url, presence: true
      validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }
      validates :clicked_at, presence: true
      validates :internal, inclusion: { in: [true, false] }

      # Custom validation for UTF-8 URL support
      validate :url_must_be_valid
      validate :page_url_must_be_valid

      private

      def url_must_be_valid
        return if url.blank?

        return if valid_utf8_url?(url)

        errors.add(:url, 'must be a valid URL or tel/mailto link')
      end

      def page_url_must_be_valid
        return if page_url.blank?

        # For page_url, we're more lenient - it can be a relative path or full URL
        uri = safe_parse_uri(page_url)

        # If it parses as a URI and either has no scheme (relative) or has http/https scheme
        return if uri && (uri.scheme.nil? || %w[http https].include?(uri.scheme&.downcase))

        errors.add(:page_url, 'must be a valid URL')
      end
    end
  end
end

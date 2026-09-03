# frozen_string_literal: true

require 'stringio'
require 'cgi'

module BetterTogether
  module Sitemaps
    # Builds a per-platform <sitemapindex> document that points at the
    # controller-served locale sitemap URLs (BetterTogether::SitemapsController#show),
    # not at sitemap_generator's on-disk file layout. The locale sitemap files are
    # streamed from Active Storage via the controller, so the index has to reference
    # the public routes (`<resolved_host_url>/<locale>/sitemap.xml.gz`) rather than
    # any static path.
    class IndexBuilder
      SITEMAP_NS = 'http://www.sitemaps.org/schemas/sitemap/0.9'

      # @param platform [BetterTogether::Platform] the platform this index belongs to
      # @param locales [Array<String, Symbol>] locales that have an attached per-locale sitemap
      def initialize(platform:, locales:)
        @platform = platform
        @locales = Array(locales).map(&:to_s).uniq.sort
      end

      # @return [String] the uncompressed sitemap index XML
      def to_xml
        entries = @locales.map { |locale| sitemap_entry(locale) }.join

        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <sitemapindex xmlns="#{SITEMAP_NS}">
          #{entries}</sitemapindex>
        XML
      end

      # @return [StringIO] gzip-compressed index XML, rewound and ready to attach
      def to_gzipped_io
        StringIO.new(BetterTogether::Sitemaps.gzip(to_xml))
      end

      private

      def sitemap_entry(locale)
        loc = "#{base_url}/#{locale}/sitemap.xml.gz"
        lastmod = lastmod_for(locale)
        lastmod_tag = lastmod ? "    <lastmod>#{lastmod.iso8601}</lastmod>\n" : ''

        "  <sitemap>\n    <loc>#{CGI.escapeHTML(loc)}</loc>\n#{lastmod_tag}  </sitemap>\n"
      end

      def base_url
        @base_url ||= @platform.resolved_host_url.to_s.chomp('/')
      end

      def lastmod_for(locale)
        record = BetterTogether::Sitemap.find_by(platform: @platform, locale: locale)
        record&.file&.attached? ? record.file.blob.created_at : nil
      end
    end
  end
end

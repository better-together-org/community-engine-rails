# frozen_string_literal: true

require 'sitemap_generator'
require 'uri'
require 'stringio'
require 'fileutils'

module BetterTogether
  module Sitemaps
    # Generates the full sitemap set (one file per available locale plus an index)
    # for a single locally-hosted platform and attaches each file to the matching
    # BetterTogether::Sitemap record.
    #
    # URLs are hosted on the platform's own canonical domain
    # (Platform#resolved_host_url, i.e. its primary PlatformDomain), so every
    # tenant's sitemap advertises that tenant's own domain rather than the host
    # platform's.
    #
    # @example
    #   BetterTogether::Sitemaps::Generator.new(platform).call
    class Generator
      class NotLocalHostedError < ArgumentError; end

      # @param platform [BetterTogether::Platform]
      def initialize(platform)
        @platform = platform
        raise NotLocalHostedError, 'platform must be a locally-hosted platform' unless platform&.local_hosted?
      end

      # Build and attach every locale sitemap plus the index for this platform.
      # @return [Array<String>] the locales that ended up with an attached sitemap
      def call
        FileUtils.rm_rf(tmp_root)
        FileUtils.mkdir_p(tmp_root)

        attached = I18n.available_locales.filter_map { |locale| generate_locale(locale) }
        attach_index(attached)
        attached.map(&:to_s)
      ensure
        FileUtils.rm_rf(tmp_root)
      end

      private

      attr_reader :platform

      # @return [Symbol, nil] the locale if a file was generated and attached
      def generate_locale(locale)
        # `create` runs the block via instance_eval, so `self` is the sitemap
        # interpreter inside it — capture the platform in a local first.
        scoped_platform = platform
        build_link_set(locale).create do
          BetterTogether::SitemapHelper.add_better_together_resources(self, locale, platform: scoped_platform)
        end

        file_path = tmp_root.join(locale.to_s, 'sitemap.xml.gz')
        return nil unless File.exist?(file_path)

        attach(BetterTogether::Sitemap.current(platform, locale), deterministic_gz(file_path),
               "sitemap_#{platform.id}_#{locale}.xml.gz")
        locale
      end

      # Re-gzip the gem's output deterministically so an unchanged sitemap produces
      # identical bytes and attach_file_if_changed? can skip the re-upload.
      def deterministic_gz(path)
        StringIO.new(BetterTogether::Sitemaps.gzip(BetterTogether::Sitemaps.gunzip(File.binread(path))))
      end

      def attach(record, io, filename)
        record.attach_file_if_changed?(io: io, filename: filename, content_type: 'application/gzip')
        record.save!
      end

      def build_link_set(locale)
        SitemapGenerator::LinkSet.new(
          default_host: default_host,
          public_path: tmp_root.to_s,
          sitemaps_path: "#{locale}/",
          include_index: false,
          include_root: false, # SitemapHelper adds the localized home page itself
          create_index: false,
          verbose: false,
          search_engines: {} # never ping search engines from here
        )
      end

      def attach_index(locales)
        return if locales.empty?

        io = BetterTogether::Sitemaps::IndexBuilder.new(platform: platform, locales: locales).to_gzipped_io
        attach(BetterTogether::Sitemap.current_index(platform), io, "sitemap_index_#{platform.id}.xml.gz")
      end

      # sitemap_generator wants "scheme://host[:port]" with no path.
      def default_host
        uri = URI.parse(platform.resolved_host_url.to_s)
        port = uri.port
        standard = (uri.scheme == 'https' && port == 443) || (uri.scheme == 'http' && port == 80)
        "#{uri.scheme}://#{uri.host}#{":#{port}" unless standard || port.nil?}"
      end

      def tmp_root
        @tmp_root ||= Rails.root.join('tmp', 'sitemaps', platform.id.to_s)
      end
    end
  end
end

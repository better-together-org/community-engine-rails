# frozen_string_literal: true

# Base sitemap configuration for Better Together Community Engine
# This file demonstrates the default sitemap structure for the engine.
# Host applications should create their own config/sitemap.rb and use
# BetterTogether::SitemapHelper to include engine resources along with
# their own custom resources.
#
# @see BetterTogether::SitemapHelper for usage examples

require_relative '../lib/better_together/sitemap_helper'

SitemapGenerator::Sitemap.default_host =
  "#{ENV.fetch('APP_PROTOCOL', 'http')}://#{ENV.fetch('APP_HOST', 'localhost:3000')}"

# sitemap.rake and SitemapsController currently only generate and serve one
# sitemap set, attributed to the host platform - resolve it explicitly here
# rather than relying on SitemapHelper's own host-platform default, so this
# stays correct if either of those callers ever passes a platform through.
host_platform = BetterTogether::Platform.find_by(host: true)

# Generate sitemaps for all available locales
I18n.available_locales.each do |locale|
  SitemapGenerator::Sitemap.create(default_host: SitemapGenerator::Sitemap.default_host, sitemaps_path: "sitemaps/#{locale}/") do
    # Add all Better Together core resources for this locale, scoped to the host platform
    BetterTogether::SitemapHelper.add_better_together_resources(self, locale, platform: host_platform)
  end
end

# Create sitemap index that references all locale-specific sitemaps
SitemapGenerator::Sitemap.create_index

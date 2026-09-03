# frozen_string_literal: true

# Host-app compatibility shim for the `sitemap_generator` gem's own
# `rake sitemap:refresh` / `SitemapGenerator::Interpreter` entry point.
#
# The engine's real, multi-platform entry point is:
#
#   rake better_together:sitemap:refresh      (BetterTogether::Sitemaps::Generator)
#
# which generates one sitemap set per locally-hosted platform, hosted on each
# platform's own canonical domain, and serves them through
# BetterTogether::SitemapsController. This file only exists so host apps that
# still drive the gem's Interpreter directly keep working; it generates for the
# host platform only, scoped to the host platform's own content.
#
# Host apps that want their own custom URLs can create their own config/sitemap.rb
# and call BetterTogether::SitemapHelper.add_better_together_resources(self, locale, platform:)
# alongside their own `add` calls.

require_relative '../lib/better_together/sitemap_helper'

host_platform = BetterTogether::Platform.find_by(host: true)

SitemapGenerator::Sitemap.default_host =
  host_platform&.resolved_host_url ||
  "#{ENV.fetch('APP_PROTOCOL', 'http')}://#{ENV.fetch('APP_HOST', 'localhost:3000')}"

I18n.available_locales.each do |locale|
  SitemapGenerator::Sitemap.create(
    default_host: SitemapGenerator::Sitemap.default_host,
    sitemaps_path: "sitemaps/#{locale}/"
  ) do
    BetterTogether::SitemapHelper.add_better_together_resources(self, locale, platform: host_platform)
  end
end

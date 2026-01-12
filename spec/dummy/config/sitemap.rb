# frozen_string_literal: true

# Sitemap configuration for the dummy test application
# This demonstrates how a host application can extend the Better Together
# sitemap with custom resources.
#
# Host applications should:
# 1. Create their own config/sitemap.rb
# 2. Use BetterTogether::SitemapHelper to include core engine resources
# 3. Add their own application-specific resources

require_relative '../../../lib/better_together/sitemap_helper'

SitemapGenerator::Sitemap.default_host =
  "#{ENV.fetch('APP_PROTOCOL', 'http')}://#{ENV.fetch('APP_HOST', 'localhost:3000')}"

SitemapGenerator::Sitemap.create do
  # Include all Better Together core resources (communities, posts, events, pages, etc.)
  BetterTogether::SitemapHelper.add_better_together_resources(self)

  # Host applications can add their own resources here:
  # Example:
  # MyCustomModel.published.find_each do |record|
  #   add my_custom_path(record), lastmod: record.updated_at
  # end
  #
  # Or selectively include only needed Better Together resources:
  # BetterTogether::SitemapHelper.add_pages(self)
  # BetterTogether::SitemapHelper.add_posts(self)
end

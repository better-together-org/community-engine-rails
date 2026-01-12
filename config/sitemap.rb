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

SitemapGenerator::Sitemap.create do
  # Add all Better Together core resources
  BetterTogether::SitemapHelper.add_better_together_resources(self)
end

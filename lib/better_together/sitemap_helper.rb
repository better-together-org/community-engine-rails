# frozen_string_literal: true

module BetterTogether
  # Helper module for building sitemaps that include Better Together engine resources
  # Host apps can include this module in their config/sitemap.rb to easily add
  # core platform resources to their sitemap.
  #
  # @example Basic usage in host app's config/sitemap.rb
  #   SitemapGenerator::Sitemap.default_host = "https://example.com"
  #
  #   SitemapGenerator::Sitemap.create do
  #     # Add all Better Together core resources
  #     BetterTogether::SitemapHelper.add_better_together_resources(self)
  #
  #     # Add host app specific resources
  #     MyModel.find_each do |record|
  #       add my_model_path(record), lastmod: record.updated_at
  #     end
  #   end
  #
  # @example Selective inclusion
  #   SitemapGenerator::Sitemap.create do
  #     BetterTogether::SitemapHelper.add_pages(self)
  #     BetterTogether::SitemapHelper.add_posts(self)
  #     # Skip communities, conversations, events if not needed
  #   end
  module SitemapHelper
    class << self
      # Add all Better Together core resources to the sitemap
      # @param sitemap [SitemapGenerator::Builder::SitemapFile] The sitemap builder instance
      def add_better_together_resources(sitemap)
        add_home_page(sitemap)
        add_communities(sitemap)
        add_posts(sitemap)
        add_events(sitemap)
        add_pages(sitemap)
      end

      # Add the home page to the sitemap
      # @param sitemap [SitemapGenerator::Builder::SitemapFile] The sitemap builder instance
      def add_home_page(sitemap)
        sitemap.add helpers.home_page_path(locale: I18n.default_locale)
      end

      # Add communities index and individual community pages
      # @param sitemap [SitemapGenerator::Builder::SitemapFile] The sitemap builder instance
      def add_communities(sitemap)
        sitemap.add helpers.communities_path(locale: I18n.default_locale)
        BetterTogether::Community.find_each do |community|
          sitemap.add helpers.community_path(community, locale: I18n.default_locale),
                      lastmod: community.updated_at
        end
      end

      # Add posts index and individual published post pages
      # @param sitemap [SitemapGenerator::Builder::SitemapFile] The sitemap builder instance
      def add_posts(sitemap)
        sitemap.add helpers.posts_path(locale: I18n.default_locale)
        BetterTogether::Post.published.find_each do |post|
          sitemap.add helpers.post_path(post, locale: I18n.default_locale),
                      lastmod: post.updated_at
        end
      end

      # Add events index and individual event pages
      # @param sitemap [SitemapGenerator::Builder::SitemapFile] The sitemap builder instance
      def add_events(sitemap)
        sitemap.add helpers.events_path(locale: I18n.default_locale)
        BetterTogether::Event.find_each do |event|
          sitemap.add helpers.event_path(event, locale: I18n.default_locale),
                      lastmod: event.updated_at
        end
      end

      # Add public published pages
      # @param sitemap [SitemapGenerator::Builder::SitemapFile] The sitemap builder instance
      def add_pages(sitemap)
        BetterTogether::Page.published.privacy_public.find_each do |page|
          sitemap.add helpers.render_page_path(path: page.slug, locale: I18n.default_locale),
                      lastmod: page.updated_at
        end
      end

      private

      # @return [Module] URL helpers from the Better Together engine
      def helpers
        @helpers ||= BetterTogether::Engine.routes.url_helpers
      end
    end
  end
end

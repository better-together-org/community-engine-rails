# frozen_string_literal: true

# Sitemap configuration for the dummy app
# This file is loaded by sitemap_generator and the SitemapRefreshJob

SitemapGenerator::Sitemap.default_host =
  "#{ENV.fetch('APP_PROTOCOL', 'http')}://#{ENV.fetch('APP_HOST', 'localhost:3000')}"

helpers = BetterTogether::Engine.routes.url_helpers

SitemapGenerator::Sitemap.create do
  add helpers.home_page_path(locale: I18n.default_locale)

  add helpers.communities_path(locale: I18n.default_locale)
  BetterTogether::Community.find_each do |community|
    add helpers.community_path(community, locale: I18n.default_locale), lastmod: community.updated_at
  end

  add helpers.conversations_path(locale: I18n.default_locale)
  BetterTogether::Conversation.find_each do |conversation|
    add helpers.conversation_path(conversation, locale: I18n.default_locale), lastmod: conversation.updated_at
  end

  add helpers.posts_path(locale: I18n.default_locale)
  BetterTogether::Post.published.find_each do |post|
    add helpers.post_path(post, locale: I18n.default_locale), lastmod: post.updated_at
  end

  add helpers.events_path(locale: I18n.default_locale)
  BetterTogether::Event.find_each do |event|
    add helpers.event_path(event, locale: I18n.default_locale), lastmod: event.updated_at
  end

  BetterTogether::Page.published.privacy_public.find_each do |page|
    add helpers.render_page_path(path: page.slug, locale: I18n.default_locale), lastmod: page.updated_at
  end
end

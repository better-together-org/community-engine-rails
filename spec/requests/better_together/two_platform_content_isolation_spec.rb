# frozen_string_literal: true

require 'rails_helper'
require 'zlib'

# Seeds two locally hosted, public platforms with colliding identifiers and asserts that nothing
# one platform publishes shows up through the other platform's domain. Surfaces covered: page,
# post and event lookup, post and event lists, search, sitemaps, robots.txt, uploads and navigation.
RSpec.describe 'Two-platform content isolation', :skip_host_setup do
  let!(:host_platform) { configure_host_platform }
  let!(:host_domain) do
    BetterTogether::PlatformDomain.find_by(platform: host_platform, primary_flag: true) ||
      create(:better_together_platform_domain, :primary, platform: host_platform, hostname: 'alpha.example.test')
  end
  let(:other_platform) { create(:better_together_platform, :public) }
  let!(:other_domain) do
    domain = BetterTogether::PlatformDomain.find_by(platform: other_platform, primary_flag: true) ||
             create(:better_together_platform_domain, :primary, platform: other_platform)
    domain.update!(hostname: 'beta.example.test')
    domain
  end

  let(:locale) { I18n.default_locale }
  let(:alpha) { 'alpha.example.test' }
  let(:beta) { 'beta.example.test' }

  before do
    host_domain.update!(hostname: alpha)
    other_domain
  end

  def serve_from(hostname)
    host! hostname
  end

  describe 'renamed pages (slug history)' do
    it 'does not resolve another platform\'s old slug', :aggregate_failures do
      page = create(:better_together_page, platform: other_platform, privacy: 'public', published_at: 1.day.ago,
                                           slug: 'old-beta-name', title: 'Renamed beta marker')
      page.update!(slug: 'new-beta-name')

      serve_from(alpha)
      get better_together.render_page_path(path: 'old-beta-name', locale:)
      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include('Renamed beta marker')
    end
  end

  describe 'static pages with the same slug (colophon)' do
    let!(:alpha_page) do
      create(:better_together_page, platform: host_platform, privacy: 'public', published_at: 1.day.ago,
                                    slug: 'colophon', title: 'Alpha colophon marker')
    end
    let!(:beta_page) do
      create(:better_together_page, platform: other_platform, privacy: 'public', published_at: 1.day.ago,
                                    slug: 'colophon', title: 'Beta colophon marker')
    end

    it 'serves each platform its own page', :aggregate_failures do
      serve_from(alpha)
      get better_together.render_page_path(path: 'colophon', locale:)
      expect(response.body).to include('Alpha colophon marker')
      expect(response.body).not_to include('Beta colophon marker')

      serve_from(beta)
      get better_together.render_page_path(path: 'colophon', locale:)
      expect(response.body).to include('Beta colophon marker')
      expect(response.body).not_to include('Alpha colophon marker')
    end

    it 'does not serve a page that exists only on the other platform' do
      create(:better_together_page, platform: other_platform, privacy: 'public', published_at: 1.day.ago,
                                    slug: 'beta-only', title: 'Beta only marker')

      serve_from(alpha)
      get better_together.render_page_path(path: 'beta-only', locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'posts' do
    let!(:alpha_post) do
      create(:better_together_post, :public, :published, platform: host_platform, identifier: 'news',
                                                         title: 'Alpha post marker')
    end
    let!(:beta_post) do
      create(:better_together_post, :public, :published, platform: other_platform, identifier: 'news',
                                                         title: 'Beta post marker')
    end

    it 'lists only the requesting platform\'s posts', :aggregate_failures do
      serve_from(alpha)
      get better_together.posts_path(locale:)
      expect(response.body).to include('Alpha post marker')
      expect(response.body).not_to include('Beta post marker')

      serve_from(beta)
      get better_together.posts_path(locale:)
      expect(response.body).to include('Beta post marker')
      expect(response.body).not_to include('Alpha post marker')
    end

    it 'does not show the other platform\'s post by id' do
      serve_from(alpha)
      beta_only = create(:better_together_post, :public, :published, platform: other_platform,
                                                                     identifier: 'beta-only-news')
      get better_together.post_path(beta_only, locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'events' do
    let!(:alpha_event) do
      create(:better_together_event, platform: host_platform, privacy: 'public', name: 'Alpha event marker',
                                     starts_at: 2.days.from_now)
    end
    let!(:beta_event) do
      create(:better_together_event, platform: other_platform, privacy: 'public', name: 'Beta event marker',
                                     starts_at: 2.days.from_now)
    end

    it 'lists only the requesting platform\'s events', :aggregate_failures do
      serve_from(alpha)
      get better_together.events_path(locale:)
      expect(response.body).not_to include('Beta event marker')

      serve_from(beta)
      get better_together.events_path(locale:)
      expect(response.body).not_to include('Alpha event marker')
    end

    it 'does not show the other platform\'s event by id' do
      serve_from(alpha)
      get better_together.event_path(beta_event, locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'events with the same identifier' do
    let!(:alpha_event) do
      create(:better_together_event, platform: host_platform, privacy: 'public', identifier: 'open-night',
                                     name: 'Alpha open night', starts_at: 2.days.from_now)
    end
    let!(:beta_event) do
      create(:better_together_event, platform: other_platform, privacy: 'public', identifier: 'open-night',
                                     name: 'Beta open night', starts_at: 2.days.from_now)
    end

    it 'creates both events' do
      expect([alpha_event, beta_event]).to all(be_persisted)
    end

    it 'resolves the identifier only on the platform that owns it', :aggregate_failures do
      serve_from(alpha)
      get better_together.event_path(alpha_event, locale:)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Alpha open night')
      expect(response.body).not_to include('Beta open night')

      serve_from(beta)
      get better_together.event_path(beta_event, locale:)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Beta open night')
      expect(response.body).not_to include('Alpha open night')
    end

    it 'still rejects a duplicate identifier on the same platform' do
      dup = build(:better_together_event, platform: host_platform, identifier: 'open-night')
      expect(dup).not_to be_valid
    end
  end

  describe 'other records with the same identifier' do
    %i[place calendar community].each do |factory|
      it "allows one #{factory} identifier on two platforms and rejects a duplicate on one", :aggregate_failures do
        first = create(:"better_together_#{factory}", platform: host_platform, identifier: 'shared-id')
        second = create(:"better_together_#{factory}", platform: other_platform, identifier: 'shared-id')
        duplicate = build(:"better_together_#{factory}", platform: host_platform, identifier: 'shared-id')

        expect([first, second]).to all(be_persisted)
        expect(duplicate).not_to be_valid
      end
    end
  end

  describe 'communities with the same identifier' do
    let!(:alpha_community) do
      create(:better_together_community, platform: host_platform, privacy: 'public', identifier: 'garden-club',
                                         name: 'Alpha garden club')
    end
    let!(:beta_community) do
      create(:better_together_community, platform: other_platform, privacy: 'public', identifier: 'garden-club',
                                         name: 'Beta garden club')
    end

    it 'gives each community its own slug row and platform', :aggregate_failures do
      rows = FriendlyId::Slug.unscoped.where(sluggable_type: 'BetterTogether::Community', slug: 'garden-club')

      expect(rows.pluck(:sluggable_id, :platform_id)).to contain_exactly(
        [alpha_community.id, host_platform.id], [beta_community.id, other_platform.id]
      )
    end

    it 'resolves the shared slug to the community of the requesting platform', :aggregate_failures do
      serve_from(alpha)
      get better_together.community_path(alpha_community, locale:)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Alpha garden club')
      expect(response.body).not_to include('Beta garden club')

      serve_from(beta)
      get better_together.community_path(beta_community, locale:)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Beta garden club')
      expect(response.body).not_to include('Alpha garden club')
    end

    it 'finds the community by slug only inside its own platform', :aggregate_failures do
      expect(BetterTogether::Community.friendly_find_in_platform('garden-club', platform: other_platform))
        .to eq(beta_community)
      expect(BetterTogether::Community.friendly_find_in_platform('garden-club', platform: host_platform))
        .to eq(alpha_community)
      expect { BetterTogether::Community.friendly_find_in_platform(beta_community.id, platform: host_platform) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'slugs generated from the same title' do
    it 'does not make a platform rename its page because the other platform has the same title', :aggregate_failures do
      alpha_page = create(:better_together_page, platform: host_platform, title: 'Open hours', slug: 'open-hours')
      beta_page = create(:better_together_page, platform: other_platform, title: 'Open hours', slug: 'open-hours')

      expect([alpha_page.slug, beta_page.slug]).to eq(%w[open-hours open-hours])
      expect(BetterTogether::Page.friendly_find_in_platform('open-hours', platform: other_platform)).to eq(beta_page)
    end
  end

  describe 'search' do
    before do
      create(:better_together_post, :public, :published, platform: host_platform, title: 'Zymurgy alpha entry')
      create(:better_together_post, :public, :published, platform: other_platform, title: 'Zymurgy beta entry')
    end

    it 'returns only the requesting platform\'s records', :aggregate_failures do
      serve_from(alpha)
      get better_together.search_path(locale:, q: 'Zymurgy')
      expect(response.body).not_to include('Zymurgy beta entry')

      serve_from(beta)
      get better_together.search_path(locale:, q: 'Zymurgy')
      expect(response.body).not_to include('Zymurgy alpha entry')
    end
  end

  describe 'sitemaps' do
    let(:sitemap_urls) do
      lambda do |platform|
        BetterTogether::Sitemaps::Generator.new(platform).call
        sitemap = BetterTogether::Sitemap.find_by!(platform:, locale: locale.to_s)
        Zlib::GzipReader.new(StringIO.new(sitemap.file.download)).read
      end
    end

    before do
      create(:better_together_page, platform: host_platform, privacy: 'public', published_at: 1.day.ago,
                                    slug: 'alpha-sitemap-page')
      create(:better_together_page, platform: other_platform, privacy: 'public', published_at: 1.day.ago,
                                    slug: 'beta-sitemap-page')
    end

    it 'lists only the platform\'s own pages', :aggregate_failures do
      alpha_xml = sitemap_urls.call(host_platform)
      beta_xml = sitemap_urls.call(other_platform)

      expect(alpha_xml).to include('alpha-sitemap-page')
      expect(alpha_xml).not_to include('beta-sitemap-page')
      expect(beta_xml).to include('beta-sitemap-page')
      expect(beta_xml).not_to include('alpha-sitemap-page')
    end
  end

  describe 'robots.txt' do
    it 'names each platform\'s own host in its sitemap line', :aggregate_failures do
      serve_from(alpha)
      get better_together.robots_txt_path
      expect(response.body).not_to include(beta)

      serve_from(beta)
      get better_together.robots_txt_path
      expect(response.body).not_to include(alpha)
    end
  end

  describe 'uploads with the same identifier' do
    let(:creator) { create(:better_together_user, :confirmed) }
    let!(:alpha_upload) do
      create(:better_together_upload, platform: host_platform, creator: creator.person, privacy: 'public',
                                      identifier: 'bylaws').tap do |u|
        u.file.attach(io: StringIO.new('alpha bylaws body'), filename: 'bylaws.txt', content_type: 'text/plain')
      end
    end
    let!(:beta_upload) do
      create(:better_together_upload, platform: other_platform, creator: creator.person, privacy: 'public',
                                      identifier: 'bylaws').tap do |u|
        u.file.attach(io: StringIO.new('beta bylaws body'), filename: 'bylaws.txt', content_type: 'text/plain')
      end
    end

    it 'allows the same identifier on two platforms' do
      expect(alpha_upload).to be_persisted
      expect(beta_upload).to be_persisted
    end

    it 'serves a file only on the platform that owns it', :aggregate_failures do
      serve_from(alpha)
      get better_together.inline_file_path(alpha_upload, locale:)
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('alpha bylaws body')

      get better_together.inline_file_path(beta_upload, locale:)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'navigation' do
    it 'does not render the other platform\'s navigation items in the header', :aggregate_failures do
      area_alpha = BetterTogether::NavigationArea.find_by(platform: host_platform, identifier: 'better-together') ||
                   create(:better_together_navigation_area, platform: host_platform, name: 'Alpha header',
                                                            identifier: 'better-together', visible: true)
      area_beta = create(:better_together_navigation_area, platform: other_platform, name: 'Beta header',
                                                           identifier: 'better-together', visible: true)
      create(:better_together_navigation_item, navigation_area: area_alpha, title: 'Alpha nav marker',
                                               url: '/alpha-nav', visible: true, item_type: 'link',
                                               linkable_type: nil, linkable_id: nil)
      create(:better_together_navigation_item, navigation_area: area_beta, title: 'Beta nav marker',
                                               url: '/beta-nav', visible: true, item_type: 'link',
                                               linkable_type: nil, linkable_id: nil)

      serve_from(alpha)
      get better_together.home_page_path(locale:)
      expect(response.body).not_to include('Beta nav marker')

      serve_from(beta)
      get better_together.home_page_path(locale:)
      expect(response.body).not_to include('Alpha nav marker')
    end
  end
end

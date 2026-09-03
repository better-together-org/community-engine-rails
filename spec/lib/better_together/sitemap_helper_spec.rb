# frozen_string_literal: true

require 'rails_helper'

# Minimal stand-in for SitemapGenerator::Builder::SitemapFile - just records
# every path #add is called with so specs can assert on what got indexed.
class RecordingSitemap
  attr_reader :paths

  def initialize
    @paths = []
  end

  def add(path, **_options)
    @paths << path
  end
end

RSpec.describe BetterTogether::SitemapHelper do
  let(:sitemap) { RecordingSitemap.new }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
  let(:other_platform) { create(:better_together_platform, :public) }

  before { host_platform }

  describe '.add_communities' do
    it "only indexes the given platform's own public communities by default" do
      own = create(:better_together_community, platform: host_platform, privacy: 'public')
      create(:better_together_community, platform: other_platform, privacy: 'public')

      described_class.add_communities(sitemap)

      expect(sitemap.paths.join).to include(own.slug)
    end

    it "excludes another platform's public communities when given an explicit platform" do
      create(:better_together_community, platform: host_platform, privacy: 'public')
      other = create(:better_together_community, platform: other_platform, privacy: 'public')

      described_class.add_communities(sitemap, I18n.default_locale, platform: host_platform)

      expect(sitemap.paths.join).not_to include(other.slug)
    end
  end

  describe '.add_posts' do
    it "excludes another platform's published public posts" do
      own = create(:better_together_post, :public, :published, platform: host_platform)
      other = create(:better_together_post, :public, :published, platform: other_platform)

      described_class.add_posts(sitemap, I18n.default_locale, platform: host_platform)

      paths = sitemap.paths.join
      expect(paths).to include(own.slug)
      expect(paths).not_to include(other.slug)
    end
  end

  describe '.add_events' do
    it "excludes another platform's public events" do
      own = create(:better_together_event, platform: host_platform)
      other = create(:better_together_event, platform: other_platform)

      described_class.add_events(sitemap, I18n.default_locale, platform: host_platform)

      paths = sitemap.paths.join
      expect(paths).to include(own.slug)
      expect(paths).not_to include(other.slug)
    end
  end

  describe '.add_pages' do
    it "excludes another platform's published public pages" do
      own = create(:better_together_page, platform: host_platform)
      other = create(:better_together_page, platform: other_platform)

      described_class.add_pages(sitemap, I18n.default_locale, platform: host_platform)

      paths = sitemap.paths.join
      expect(paths).to include(own.slug)
      expect(paths).not_to include(other.slug)
    end
  end

  describe '.add_better_together_resources' do
    it 'defaults to the host platform when no platform is given' do
      create(:better_together_community, platform: host_platform, privacy: 'public')
      other = create(:better_together_community, platform: other_platform, privacy: 'public')

      described_class.add_better_together_resources(sitemap, I18n.default_locale)

      expect(sitemap.paths.join).not_to include(other.slug)
    end
  end
end

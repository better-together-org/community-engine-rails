# frozen_string_literal: true

require 'rails_helper'
require 'better_together/sitemap_helper'

RSpec.describe BetterTogether::SitemapHelper do
  let(:sitemap) { double('SitemapBuilder') } # rubocop:disable RSpec/VerifiedDoubles
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    allow(sitemap).to receive(:add)
  end

  describe '.add_pages' do
    context 'with pages at multiple slug depths' do
      let(:top_page) do
        build_stubbed(:better_together_page, title: 'Arrival', slug: 'arrival',
                                             published_at: 1.day.ago, privacy: 'public')
      end
      let(:child_page) do
        build_stubbed(:better_together_page, title: 'Transportation', slug: 'arrival/transportation',
                                             published_at: 1.day.ago, privacy: 'public')
      end
      let(:deep_page) do
        build_stubbed(:better_together_page, title: 'Bus Routes', slug: 'arrival/transportation/bus-routes',
                                             published_at: 1.day.ago, privacy: 'public')
      end
      let(:test_pages) { [child_page, deep_page, top_page] } # deliberately unsorted

      before do
        scope = double('PageScope') # rubocop:disable RSpec/VerifiedDoubles
        allow(BetterTogether::Page).to receive(:published).and_return(scope)
        allow(scope).to receive_messages(privacy_public: scope, to_a: test_pages.dup)
      end

      it 'adds all published public pages' do
        described_class.add_pages(sitemap, locale)

        expect(sitemap).to have_received(:add).exactly(3).times
      end

      it 'orders pages by slug depth then alphabetically' do
        calls = []
        allow(sitemap).to receive(:add) { |path, **_opts| calls << path }

        described_class.add_pages(sitemap, locale)

        # The top-level page (depth 1) should come first
        expect(calls.first).to include('arrival')
        expect(calls.first).not_to include('transportation')
        # The deepest page should come last
        expect(calls.last).to include('bus-routes')
      end

      it 'assigns higher priority to top-level pages' do
        calls = []
        allow(sitemap).to receive(:add) { |_path, **opts| calls << opts }

        described_class.add_pages(sitemap, locale)

        priorities = calls.map { |c| c[:priority] }
        # depth 1 -> 0.8, depth 2 -> 0.6, depth 3 -> 0.4
        expect(priorities).to eq([0.8, 0.6, 0.4])
      end

      it 'assigns changefreq based on depth' do
        calls = []
        allow(sitemap).to receive(:add) { |_path, **opts| calls << opts }

        described_class.add_pages(sitemap, locale)

        changefreqs = calls.map { |c| c[:changefreq] }
        expect(changefreqs).to eq(%w[weekly monthly monthly])
      end
    end

    context 'with sibling pages at the same depth' do
      let(:page_a) do
        build_stubbed(:better_together_page, title: 'About', slug: 'about',
                                             published_at: 1.day.ago, privacy: 'public')
      end
      let(:page_z) do
        build_stubbed(:better_together_page, title: 'Zebra', slug: 'zebra',
                                             published_at: 1.day.ago, privacy: 'public')
      end

      before do
        scope = double('PageScope') # rubocop:disable RSpec/VerifiedDoubles
        allow(BetterTogether::Page).to receive(:published).and_return(scope)
        allow(scope).to receive_messages(privacy_public: scope, to_a: [page_z, page_a]) # deliberately reversed
      end

      it 'sorts pages alphabetically within the same depth' do
        calls = []
        allow(sitemap).to receive(:add) { |path, **_opts| calls << path }

        described_class.add_pages(sitemap, locale)

        slugs = calls.map { |p| p.split('/').last }
        expect(slugs).to eq(%w[about zebra])
      end
    end

    context 'with unpublished and private pages' do
      let(:published_public) do
        build_stubbed(:better_together_page, title: 'Visible', slug: 'visible',
                                             published_at: 1.day.ago, privacy: 'public')
      end

      before do
        # Only the published+public page passes through the scope
        scope = double('PageScope') # rubocop:disable RSpec/VerifiedDoubles
        allow(BetterTogether::Page).to receive(:published).and_return(scope)
        allow(scope).to receive_messages(privacy_public: scope, to_a: [published_public])
      end

      it 'only includes published public pages' do
        described_class.add_pages(sitemap, locale)

        expect(sitemap).to have_received(:add).once
      end
    end
  end

  describe '.add_better_together_resources' do
    it 'calls all resource methods' do
      allow(described_class).to receive(:add_home_page)
      allow(described_class).to receive(:add_communities)
      allow(described_class).to receive(:add_posts)
      allow(described_class).to receive(:add_events)
      allow(described_class).to receive(:add_pages)

      described_class.add_better_together_resources(sitemap, locale)

      expect(described_class).to have_received(:add_home_page).with(sitemap, locale)
      expect(described_class).to have_received(:add_communities).with(sitemap, locale)
      expect(described_class).to have_received(:add_posts).with(sitemap, locale)
      expect(described_class).to have_received(:add_events).with(sitemap, locale)
      expect(described_class).to have_received(:add_pages).with(sitemap, locale)
    end
  end

  describe '.add_posts' do
    let!(:published_post) do
      create(:better_together_post, published_at: 1.day.ago, privacy: 'public')
    end
    let!(:draft_post) do # rubocop:disable RSpec/LetSetup
      create(:better_together_post, published_at: nil, privacy: 'public')
    end

    it 'adds the posts index and published public posts' do
      described_class.add_posts(sitemap, locale)

      # 1 for the index path + at least 1 for the published post
      expect(sitemap).to have_received(:add).at_least(:twice)
    end
  end

  describe '.add_communities' do
    let!(:public_community) do
      create(:better_together_community, privacy: 'public')
    end

    it 'adds the communities index and public communities' do
      described_class.add_communities(sitemap, locale)

      # index + host community (from configure_host_platform) + our public community
      expect(sitemap).to have_received(:add).at_least(:twice)
    end
  end
end

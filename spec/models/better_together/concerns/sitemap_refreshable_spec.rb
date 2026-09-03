# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribedClass -- these run inside nested model describe
# blocks where `described_class` resolves to the model, not the concern.
RSpec.describe BetterTogether::SitemapRefreshable do # rubocop:todo RSpec/SpecFilePathFormat
  let!(:host_platform) do
    BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host, :public)
  end

  before do
    BetterTogether::SitemapRefreshable.enabled = true
    allow(BetterTogether::SitemapRefreshJob).to receive(:enqueue_unless_pending)
  end

  after { BetterTogether::SitemapRefreshable.enabled = nil }

  shared_examples 'a sitemap-refreshing model' do
    it 'registers the after_commit hook' do
      filters = model_class._commit_callbacks.map(&:filter)
      expect(filters).to include(:enqueue_sitemap_refresh)
    end

    it 'enqueues a platform-scoped refresh for a new record' do
      allow(record).to receive(:previously_new_record?).and_return(true)

      record.send(:enqueue_sitemap_refresh)

      expect(BetterTogether::SitemapRefreshJob)
        .to have_received(:enqueue_unless_pending).with(record.platform_id)
    end

    it 'enqueues when an SEO-relevant column changed' do
      allow(record).to receive_messages(previously_new_record?: false, saved_change_to_slug?: true)

      record.send(:enqueue_sitemap_refresh)

      expect(BetterTogether::SitemapRefreshJob)
        .to have_received(:enqueue_unless_pending).with(record.platform_id)
    end

    it 'does not enqueue when no indexed column changed' do
      allow(record).to receive(:previously_new_record?).and_return(false)
      BetterTogether::SitemapRefreshable::SITEMAP_RELEVANT_COLUMNS.each do |col|
        next unless record.respond_to?(:"saved_change_to_#{col}?")

        allow(record).to receive(:"saved_change_to_#{col}?").and_return(false)
      end

      record.send(:enqueue_sitemap_refresh)

      expect(BetterTogether::SitemapRefreshJob).not_to have_received(:enqueue_unless_pending)
    end

    it 'does not enqueue for a record on an external platform' do
      external = create(:better_together_platform, :external)
      allow(record).to receive_messages(previously_new_record?: true, platform_id: external.id)

      record.send(:enqueue_sitemap_refresh)

      expect(BetterTogether::SitemapRefreshJob).not_to have_received(:enqueue_unless_pending)
    end
  end

  describe BetterTogether::Page do
    let(:model_class) { described_class }
    let(:record) { build(:better_together_page, platform: host_platform, privacy: 'public') }

    it_behaves_like 'a sitemap-refreshing model'
  end

  describe BetterTogether::Post do
    let(:model_class) { described_class }
    let(:record) { build(:better_together_post, :public, :published, platform: host_platform) }

    it_behaves_like 'a sitemap-refreshing model'
  end

  describe BetterTogether::Event do
    let(:model_class) { described_class }
    let(:record) { build(:better_together_event, platform: host_platform) }

    it_behaves_like 'a sitemap-refreshing model'
  end

  describe BetterTogether::Community do
    let(:model_class) { described_class }
    let(:record) { build(:better_together_community, platform: host_platform, privacy: 'public') }

    it_behaves_like 'a sitemap-refreshing model'
  end
end
# rubocop:enable RSpec/DescribedClass

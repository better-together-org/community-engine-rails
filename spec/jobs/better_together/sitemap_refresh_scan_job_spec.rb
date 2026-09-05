# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SitemapRefreshScanJob do
  let!(:host_platform) do
    BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host, :public)
  end
  let!(:tenant_platform) { create(:better_together_platform, host: false, external: false) }
  let!(:external_platform) { create(:better_together_platform, :external) }

  it 'uses the maintenance queue' do
    expect(described_class.new.queue_name).to eq('maintenance')
  end

  it 'enqueues one scoped refresh per locally-hosted platform and none for external peers' do
    allow(BetterTogether::SitemapRefreshJob).to receive(:enqueue_unless_pending)

    described_class.new.perform

    expect(BetterTogether::SitemapRefreshJob).to have_received(:enqueue_unless_pending).with(host_platform.id)
    expect(BetterTogether::SitemapRefreshJob).to have_received(:enqueue_unless_pending).with(tenant_platform.id)
    expect(BetterTogether::SitemapRefreshJob).not_to have_received(:enqueue_unless_pending).with(external_platform.id)
  end
end

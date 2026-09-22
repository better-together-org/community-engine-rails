# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join(
  'db/migrate/20260717120000_correct_platform_id_mismatch_for_downloads_and_page_views'
)

RSpec.describe 'Downloads and page views platform_id mismatch correction migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { CorrectPlatformIdMismatchForDownloadsAndPageViews.new }
  let(:federated_platform) { create(:better_together_platform, :public, host: false) }
  let(:viewer_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }

  it "corrects a download's mismatched platform_id to its downloadable page's real platform" do
    federated_page = create(:better_together_page, platform: federated_platform)
    download = create(:metrics_download, downloadable: federated_page, platform: viewer_platform)

    migration.up

    expect(download.reload.platform_id).to eq(federated_platform.id)
  end

  it "corrects a page_view's mismatched platform_id to its pageable page's real platform" do
    federated_page = create(:better_together_page, platform: federated_platform)
    page_view = create(:metrics_page_view, pageable: federated_page, platform: viewer_platform)

    migration.up

    expect(page_view.reload.platform_id).to eq(federated_platform.id)
  end

  it 'leaves already-correct rows untouched' do
    federated_page = create(:better_together_page, platform: federated_platform)
    download = create(:metrics_download, downloadable: federated_page, platform: federated_platform)

    expect { migration.up }.not_to(change { download.reload.platform_id })
  end
end

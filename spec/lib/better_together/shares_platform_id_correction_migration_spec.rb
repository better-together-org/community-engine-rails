# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260717140200_correct_platform_id_mismatch_for_metrics_shares')

RSpec.describe 'Metrics shares platform_id mismatch correction migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { CorrectPlatformIdMismatchForMetricsShares.new }

  it "corrects a share's mismatched platform_id to its shareable page's real platform" do
    federated_platform = create(:better_together_platform, :public, host: false)
    viewer_platform = BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host)
    federated_page = create(:better_together_page, platform: federated_platform)
    share = create(:metrics_share, shareable: federated_page, platform: viewer_platform)

    migration.up

    expect(share.reload.platform_id).to eq(federated_platform.id)
  end

  it 'leaves already-correct rows untouched' do
    federated_platform = create(:better_together_platform, :public, host: false)
    federated_page = create(:better_together_page, platform: federated_platform)
    share = create(:metrics_share, shareable: federated_page, platform: federated_platform)

    expect { migration.up }.not_to(change { share.reload.platform_id })
  end

  it 'is a no-op for shares with no shareable' do
    viewer_platform = BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host)
    share = create(:metrics_share, shareable: nil, platform: viewer_platform)

    expect { migration.up }.not_to(change { share.reload.platform_id })
  end
end

# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260605004003_backfill_platform_id_for_reports')

RSpec.describe 'Reports platform_id backfill migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { BackfillPlatformIdForReports.new }

  it "derives a report's platform_id from its reportable Page rather than defaulting to host" do
    federated_platform = create(:better_together_platform, :public, host: false)
    federated_page = create(:better_together_page, platform: federated_platform)

    report = create(:report, reportable: federated_page)
    report.update_column(:platform_id, nil)

    migration.up

    expect(report.reload.platform_id).to eq(federated_platform.id)
  end

  it 'falls back to the host platform for reportable types with no platform_id (e.g. Person)' do
    report = create(:report) # default factory reportable is a Person, which has no platform_id
    report.update_column(:platform_id, nil)

    migration.up

    expect(report.reload.platform_id).to eq(BetterTogether::Platform.find_by(host: true).id)
  end
end

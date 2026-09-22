# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join(
  'db/migrate/20260717120200_backfill_platform_id_for_link_checker_and_user_account_reports'
)

RSpec.describe 'Link checker and user account reports platform_id backfill migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { BackfillPlatformIdForLinkCheckerAndUserAccountReports.new }
  let(:connection) { ActiveRecord::Base.connection }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }

  around do |example|
    connection.change_column_null(:better_together_metrics_link_checker_reports, :platform_id, true)
    connection.change_column_null(:better_together_metrics_user_account_reports, :platform_id, true)
    example.run
    connection.change_column_null(:better_together_metrics_link_checker_reports, :platform_id, false)
    connection.change_column_null(:better_together_metrics_user_account_reports, :platform_id, false)
  end

  def null_platform_id!(table, id)
    connection.execute("UPDATE #{table} SET platform_id = NULL WHERE id = #{connection.quote(id)}")
  end

  it "derives a link checker report's platform_id from its creator's platform membership" do
    federated_platform = create(:better_together_platform, :public, host: false)
    creator = create(:better_together_person)
    create(:better_together_person_platform_membership, member: creator, joinable: federated_platform)
    report = BetterTogether::Metrics::LinkCheckerReport.create!(creator: creator, file_format: 'csv')
    null_platform_id!('better_together_metrics_link_checker_reports', report.id)

    migration.up

    expect(report.reload.platform_id).to eq(federated_platform.id)
  end

  it 'falls back to host platform for a user account report with no creator' do
    host_platform
    report = BetterTogether::Metrics::UserAccountReport.new(filters: {}, file_format: 'csv')
    report.save!(validate: false)
    null_platform_id!('better_together_metrics_user_account_reports', report.id)

    migration.up

    expect(report.reload.platform_id).to eq(host_platform.id)
  end
end

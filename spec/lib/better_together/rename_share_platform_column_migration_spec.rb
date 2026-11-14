# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join(
  'db/migrate/20260717140100_rename_platform_to_platform_name_on_metrics_shares'
)

RSpec.describe 'Rename Metrics::Share platform column migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { RenamePlatformToPlatformNameOnMetricsShares.new }
  let(:connection) { ActiveRecord::Base.connection }

  after do
    unless connection.column_exists?(:better_together_metrics_shares, :platform)
      migration.down
    end
  end

  it 'renames the column and preserves existing data' do
    share = create(:metrics_share, platform_name: 'facebook')

    migration.down
    expect(connection.column_exists?(:better_together_metrics_shares, :platform)).to be(true)
    expect(connection.column_exists?(:better_together_metrics_shares, :platform_name)).to be(false)

    migration.up
    expect(connection.column_exists?(:better_together_metrics_shares, :platform_name)).to be(true)
    expect(share.reload.platform_name).to eq('facebook')
  end

  it 'is idempotent when run twice' do
    expect { migration.up }.not_to raise_error
  end
end

# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260330172000_add_platform_and_logged_in_to_metrics')

RSpec.describe 'Metrics platform_id backfill migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { AddPlatformAndLoggedInToMetrics.new }
  let(:connection) { ActiveRecord::Base.connection }

  around do |example|
    connection.change_column_null(:better_together_metrics_page_views, :platform_id, true)
    connection.change_column_null(:better_together_metrics_link_clicks, :platform_id, true)
    example.run
    connection.change_column_null(:better_together_metrics_page_views, :platform_id, false)
    connection.change_column_null(:better_together_metrics_link_clicks, :platform_id, false)
  end

  it "derives a page_view's platform_id from its pageable Page rather than defaulting to host" do
    federated_platform = create(:better_together_platform, :public, host: false)
    federated_page = create(:better_together_page, platform: federated_platform)

    page_view = create(:metrics_page_view, :with_page, pageable: federated_page)
    page_view.update_column(:platform_id, nil)

    migration.send(:backfill_platform_ids!)

    expect(page_view.reload.platform_id).to eq(federated_platform.id)
  end

  it 'falls back to the host platform for link_clicks, which have no content reference by design' do
    click = create(:metrics_link_click)
    click.update_column(:platform_id, nil)

    migration.send(:backfill_platform_ids!)

    expect(click.reload.platform_id).to eq(BetterTogether::Platform.find_by(host: true).id)
  end
end

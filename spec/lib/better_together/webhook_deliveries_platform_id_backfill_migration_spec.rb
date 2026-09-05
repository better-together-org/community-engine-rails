# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join(
  'db/migrate/20260716120100_backfill_platform_id_for_better_together_webhook_deliveries'
)

RSpec.describe 'Webhook deliveries platform_id backfill migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { BackfillPlatformIdForBetterTogetherWebhookDeliveries.new }
  let(:connection) { ActiveRecord::Base.connection }

  around do |example|
    connection.change_column_null(:better_together_webhook_deliveries, :platform_id, true)
    example.run
    connection.change_column_null(:better_together_webhook_deliveries, :platform_id, false)
  end

  it "derives an existing delivery's platform_id from its webhook_endpoint" do
    federated_platform = create(:better_together_platform, :public, host: false)
    endpoint = create(:webhook_endpoint, platform: federated_platform)
    delivery = create(:better_together_webhook_delivery, webhook_endpoint: endpoint)
    delivery.update_column(:platform_id, nil)

    migration.up

    expect(delivery.reload.platform_id).to eq(federated_platform.id)
  end

  it 'is a no-op for deliveries that already have a platform_id' do
    endpoint = create(:webhook_endpoint)
    delivery = create(:better_together_webhook_delivery, webhook_endpoint: endpoint)

    migration.up

    expect(delivery.reload.platform_id).to eq(endpoint.platform_id)
  end

  it 'enforces NOT NULL after backfill when no rows remain unresolved' do
    endpoint = create(:webhook_endpoint)
    delivery = create(:better_together_webhook_delivery, webhook_endpoint: endpoint)
    delivery.update_column(:platform_id, nil)

    migration.up

    expect(
      connection.columns(:better_together_webhook_deliveries).find { |c| c.name == 'platform_id' }
    ).to have_attributes(null: false)
  end
end

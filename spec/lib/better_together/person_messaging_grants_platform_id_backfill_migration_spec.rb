# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join(
  'db/migrate/20260716120000_add_platform_to_better_together_person_messaging_grants'
)

RSpec.describe 'Person messaging grants platform_id backfill migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { AddPlatformToBetterTogetherPersonMessagingGrants.new }
  let(:connection) { ActiveRecord::Base.connection }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, host: true) }

  around do |example|
    connection.change_column_null(:better_together_person_messaging_grants, :platform_id, true)
    example.run
    connection.change_column_null(:better_together_person_messaging_grants, :platform_id, false)
  end

  it 'backfills existing NULL platform_id rows to the host platform' do
    host_platform
    grant = create(:better_together_person_messaging_grant)
    grant.update_column(:platform_id, nil)

    migration.up

    expect(grant.reload.platform_id).to eq(host_platform.id)
  end

  it 'is a no-op for rows that already have a platform_id' do
    federated_platform = create(:better_together_platform, :public, host: false)
    grant = create(:better_together_person_messaging_grant, platform: federated_platform)

    migration.up

    expect(grant.reload.platform_id).to eq(federated_platform.id)
  end

  it 'enforces NOT NULL after backfill' do
    host_platform
    grant = create(:better_together_person_messaging_grant)
    grant.update_column(:platform_id, nil)

    migration.up

    expect(
      connection.columns(:better_together_person_messaging_grants).find { |c| c.name == 'platform_id' }
    ).to have_attributes(null: false)
  end
end

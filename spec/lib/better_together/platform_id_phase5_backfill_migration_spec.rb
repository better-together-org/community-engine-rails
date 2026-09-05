# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260606002001_backfill_platform_id_phase5')

RSpec.describe 'Phase 5 platform_id backfill migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { BackfillPlatformIdPhase5.new }

  it "derives a content block's platform_id from its creator's platform membership" do
    federated_platform = create(:better_together_platform, host: false)
    federated_person = create(:better_together_person)
    create(:better_together_person_platform_membership, joinable: federated_platform, member: federated_person)

    block = create(:content_alert_block)
    block.update_columns(creator_id: federated_person.id, platform_id: nil)

    migration.up

    expect(block.reload.platform_id).to eq(federated_platform.id)
  end

  it "derives a call_for_interest's platform_id from its interestable Page before falling back to its creator" do
    federated_platform = create(:better_together_platform, :public, host: false)
    federated_page = create(:better_together_page, platform: federated_platform)

    call = create(:better_together_call_for_interest, interestable: federated_page)
    call.update_column(:platform_id, nil)

    migration.up

    expect(call.reload.platform_id).to eq(federated_platform.id)
  end
end

# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join(
  'db/migrate/20260716120200_add_platform_to_better_together_person_purge_audits'
)

RSpec.describe 'Person purge audits platform_id backfill migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { AddPlatformToBetterTogetherPersonPurgeAudits.new }

  it "derives platform_id from the audit's person_deletion_request when present" do
    federated_platform = create(:better_together_platform, :public, host: false)
    person = create(:better_together_person, platform: federated_platform)
    deletion_request = create(:better_together_person_deletion_request, person: person, platform: federated_platform)
    audit = create(:better_together_person_purge_audit, person: person, person_deletion_request: deletion_request)
    audit.update_column(:platform_id, nil)

    migration.up

    expect(audit.reload.platform_id).to eq(federated_platform.id)
  end

  it 'falls back to the person when there is no person_deletion_request' do
    federated_platform = create(:better_together_platform, :public, host: false)
    person = create(:better_together_person, platform: federated_platform)
    audit = create(:better_together_person_purge_audit, person: person, person_deletion_request: nil)
    audit.update_column(:platform_id, nil)

    migration.up

    expect(audit.reload.platform_id).to eq(federated_platform.id)
  end

  it 'leaves platform_id NULL when neither source can resolve one' do
    audit = create(:better_together_person_purge_audit, person: nil, person_deletion_request: nil)
    audit.update_column(:platform_id, nil)

    migration.up

    expect(audit.reload.platform_id).to be_nil
  end
end

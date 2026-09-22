# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260321000003_backfill_content_platform_id')
require BetterTogether::Engine.root.join('db/migrate/20260321000004_enforce_platform_id_not_null_on_content_tables')

RSpec.describe 'Content platform_id backfill migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { BackfillContentPlatformId.new }
  let(:not_null_migration) { EnforcePlatformIdNotNullOnContentTables.new }

  before { not_null_migration.down } # relax NOT NULL so platform_id can be nulled for the test
  after { not_null_migration.up } # restore the constraint

  it "derives platform_id from the record's creator platform membership before defaulting to host" do
    federated_platform = create(:better_together_platform, host: false)
    federated_person = create(:better_together_person)
    create(:better_together_person_platform_membership, joinable: federated_platform, member: federated_person)

    federated_page = create(:better_together_page, creator: federated_person)
    federated_page.update_column(:platform_id, nil)

    orphan_page = create(:better_together_page)
    orphan_page.update_column(:platform_id, nil)

    migration.up

    expect(federated_page.reload.platform_id).to eq(federated_platform.id)
    expect(orphan_page.reload.platform_id).to eq(BetterTogether::Platform.find_by(host: true).id)
  end
end

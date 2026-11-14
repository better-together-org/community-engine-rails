# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260605003003_backfill_platform_id_for_categories_and_joatu')

RSpec.describe 'Categories/joatu platform_id backfill migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { BackfillPlatformIdForCategoriesAndJoatu.new }

  it "derives a categorization's platform_id from its categorizable Page" do
    federated_platform = create(:better_together_platform, :public, host: false)
    federated_page = create(:better_together_page, platform: federated_platform)

    categorization = create(:categorization, categorizable: federated_page)
    categorization.update_column(:platform_id, nil)

    migration.up

    expect(categorization.reload.platform_id).to eq(federated_platform.id)
  end

  it "derives a joatu offer's platform_id from its creator's platform membership" do
    federated_platform = create(:better_together_platform, host: false)
    federated_person = create(:better_together_person)
    create(:better_together_person_platform_membership, joinable: federated_platform, member: federated_person)

    offer = create(:better_together_joatu_offer, creator: federated_person)
    offer.update_column(:platform_id, nil)

    migration.up

    expect(offer.reload.platform_id).to eq(federated_platform.id)
  end
end

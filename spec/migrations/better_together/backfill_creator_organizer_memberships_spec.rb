# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261125005637_backfill_creator_organizer_memberships')

RSpec.describe BackfillCreatorOrganizerMemberships do
  let(:migration) { described_class.new }
  let(:creator) { create(:better_together_person) }
  let(:community) { create(:better_together_community, creator:) }

  before do
    BetterTogether::AccessControlBuilder.build(clear: false)
    community.person_community_memberships.where(member: creator).destroy_all
  end

  def active_creator_memberships
    community.person_community_memberships.active.where(member: creator)
  end

  it 'grants a creator without a membership an Organizer membership' do
    migration.up

    expect(active_creator_memberships.map { |m| m.role.identifier }).to eq(['community_organizer'])
  end

  it 'is idempotent' do
    migration.up

    expect { migration.up }.not_to(change { community.person_community_memberships.count })
  end

  it 'leaves an existing active membership alone' do
    creator.reload
    community.person_community_memberships.create!(
      member: creator, role: BetterTogether::Role.find_default('community_member', platform: community.platform),
      status: 'active'
    )

    expect { migration.up }.not_to(change { community.person_community_memberships.count })
  end

  it 'fails closed when the platform has no Organizer role' do
    community
    allow(BetterTogether::Role).to receive(:find_default).with('community_organizer', anything).and_return(nil)

    expect { migration.up }.to raise_error(/could not grant/)
  end
end

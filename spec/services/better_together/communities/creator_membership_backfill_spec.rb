# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Communities::CreatorMembershipBackfill do
  let(:creator) { create(:better_together_person) }
  let!(:community) { create(:better_together_community, creator:) }

  before do
    # Simulate a community created before creators were given explicit memberships.
    community.person_community_memberships.where(member: creator).destroy_all
  end

  it 'lists the creator without changing anything on a dry run' do
    entries = described_class.call

    expect(entries.map(&:community_id)).to include(community.id)
    expect(entries.find { |e| e.community_id == community.id }.status).to eq('would_grant')
    expect(community.person_community_memberships.where(member: creator)).to be_empty
  end

  it 'grants an active Organizer membership when applied, silently' do
    expect { described_class.call(apply: true) }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)

    membership = community.person_community_memberships.find_by!(member: creator)
    expect(membership).to be_active
    expect(membership.role.identifier).to eq('community_organizer')
  end

  it 'is idempotent' do
    described_class.call(apply: true)

    expect { described_class.call(apply: true) }.not_to change(BetterTogether::PersonCommunityMembership, :count)
    expect(described_class.call.map(&:community_id)).not_to include(community.id)
  end

  it 'skips creators who already hold an active membership' do
    other = create(:better_together_community, creator: creator.reload)

    expect(described_class.call.map(&:community_id)).not_to include(other.id)
  end
end

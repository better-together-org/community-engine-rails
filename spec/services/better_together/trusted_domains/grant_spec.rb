# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::TrustedDomains::Grant do
  let!(:platform) { configure_host_platform }
  let(:community) { platform.community }
  let(:trusted_domain) { create(:platform_trusted_domain, platform:, domain: 'trusted.example') }
  let(:person) { create(:better_together_person) }

  def grant(created_account: false)
    described_class.call(trusted_domain:, person:, via: 'oauth', created_account:)
  end

  it 'creates an active membership with the domain role and one audit entry', :aggregate_failures do
    result = grant(created_account: true)

    expect(result).to be_granted
    expect(community.person_community_memberships.find_by(member: person)).to have_attributes(
      role: trusted_domain.role, status: 'active'
    )
    expect(BetterTogether::TrustedDomainEvent.last).to have_attributes(event_type: 'account_created')
  end

  it 'records membership_granted when the account already existed' do
    grant

    expect(BetterTogether::TrustedDomainEvent.last.event_type).to eq('membership_granted')
  end

  it 'leaves an existing active membership untouched', :aggregate_failures do
    steward_role = BetterTogether::Role.find_by!(identifier: 'community_facilitator')
    community.person_community_memberships.create!(member: person, role: steward_role, status: 'active')

    expect { expect(grant.status).to eq(:already_member) }.not_to change(BetterTogether::PersonCommunityMembership, :count)
    expect(BetterTogether::TrustedDomainEvent.count).to eq(0)
  end

  it 'activates a pending membership' do
    community.person_community_memberships.create!(member: person, role: trusted_domain.role, status: 'pending')

    expect { grant }.to change { community.person_community_memberships.find_by(member: person).status }
      .from('pending').to('active')
  end
end

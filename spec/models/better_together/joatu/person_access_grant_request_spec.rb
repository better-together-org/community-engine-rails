# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::PersonAccessGrantRequest do
  it 'creates an active access grant with conservative default scopes on acceptance' do
    source_platform = create(:better_together_platform)
    target_platform = create(:better_together_platform)
    create(:better_together_platform_connection, :active, source_platform:, target_platform:)
    source_person = create(:better_together_person)
    target_person = create(:better_together_person)

    source_platform.person_platform_memberships.create!(member: source_person, role: create(:better_together_role), status: 'active')
    target_platform.person_platform_memberships.create!(member: target_person, role: create(:better_together_role), status: 'active')

    offer = create(:better_together_joatu_offer, creator: source_person, target: source_person)
    request = create(:better_together_joatu_person_access_grant_request, creator: target_person, target: target_person)
    agreement = create(:better_together_joatu_agreement, offer:, request:)

    expect { agreement.accept! }.to change(BetterTogether::PersonAccessGrant.active, :count).by(1)

    grant = BetterTogether::PersonAccessGrant.order(:created_at).last
    expect(grant.person_link).to be_active
    expect(grant.allow_profile_read).to be(true)
    expect(grant.allow_private_posts).to be(false)
    expect(grant.allow_private_pages).to be(false)
    expect(grant.allow_private_events).to be(false)
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonAccessGrant do
  it 'defaults to a fail-closed grant with only profile read enabled' do
    grant = build(:better_together_person_access_grant)

    expect(grant).to be_valid
    expect(grant.allow_profile_read).to be(true)
    expect(grant.allow_private_posts).to be(false)
    expect(grant.allow_private_pages).to be(false)
    expect(grant.allow_private_events).to be(false)
    expect(grant.allow_private_messages).to be(false)
  end

  it 'requires the grantor and grantee to match the linked people' do
    grant = build(:better_together_person_access_grant)
    grant.grantee_person = create(:better_together_person)

    expect(grant).not_to be_valid
    expect(grant.errors[:grantee_person]).to include('must match the person link target person')
  end

  it 'checks scope access explicitly' do
    grant = build(:better_together_person_access_grant, allow_private_posts: true)

    expect(grant.allows_scope?('profile_read')).to be(true)
    expect(grant.allows_scope?('private_posts')).to be(true)
    expect(grant.allows_scope?('private_events')).to be(false)
  end
end

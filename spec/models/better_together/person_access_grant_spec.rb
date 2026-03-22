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

  it 'treats revoked grants as inactive immediately' do
    grant = create(:better_together_person_access_grant)

    grant.revoke!

    expect(grant.reload.active_now?).to be(false)
    expect(described_class.current_active).not_to include(grant)
  end

  it 'treats expired grants as inactive immediately' do
    grant = create(:better_together_person_access_grant, expires_at: 1.minute.ago)

    expect(grant.active_now?).to be(false)
    expect(described_class.current_active).not_to include(grant)
  end

  it 'encrypts remote_grantee_identifier and remote_grantee_name at rest' do
    grant = create(
      :better_together_person_access_grant,
      grantee_person: nil,
      remote_grantee_identifier: 'remote-grantee@example.com',
      remote_grantee_name: 'Remote Grantee'
    )

    raw = described_class.connection
                         .select_one("SELECT remote_grantee_identifier FROM better_together_person_access_grants WHERE id='#{grant.id}'")
    expect(raw['remote_grantee_identifier']).not_to eq('remote-grantee@example.com')
    expect(grant.reload.remote_grantee_identifier).to eq('remote-grantee@example.com')
  end
end

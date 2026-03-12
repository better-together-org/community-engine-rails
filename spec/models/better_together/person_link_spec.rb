# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonLink do
  it 'is valid when both people belong to the connected platforms' do
    person_link = build(:better_together_person_link)

    expect(person_link).to be_valid
    expect(person_link).to be_active
  end

  it 'requires a source person membership on the source platform' do
    person_link = build(:better_together_person_link)
    person_link.source_person.person_platform_memberships.where(joinable: person_link.platform_connection.source_platform).delete_all

    expect(person_link).not_to be_valid
    expect(person_link.errors[:source_person]).to include('must belong to the source platform')
  end

  it 'can represent a remote target with an identifier instead of a local person' do
    person_link = build(
      :better_together_person_link,
      target_person: nil,
      remote_target_identifier: 'remote-person-123',
      remote_target_name: 'Remote Person'
    )

    expect(person_link).to be_valid
    expect(person_link).to be_remote_target
  end

  it 'revokes linked access grants when the person link is revoked' do
    person_link = create(:better_together_person_link)
    grant = create(:better_together_person_access_grant, person_link:)

    person_link.revoke!

    expect(person_link.reload).to be_revoked
    expect(grant.reload).to be_revoked
  end
end

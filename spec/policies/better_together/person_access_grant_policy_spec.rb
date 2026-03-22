# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonAccessGrantPolicy do
  subject(:policy) { described_class.new(user, grant) }

  let(:grant) { create(:better_together_person_access_grant) }
  let(:grantor) { grant.grantor_person }
  let(:grantee) { grant.grantee_person }
  let!(:grantor_user) { create(:better_together_user, :confirmed, person: grantor) }
  let!(:grantee_user) { create(:better_together_user, :confirmed, person: grantee) }
  let(:user) { grantor_user }

  it 'allows the grantor to show, update, and revoke the grant' do
    expect(policy.show?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.revoke?).to be(true)
  end

  it 'allows the grantee to show but not update or revoke the grant' do
    grantee_policy = described_class.new(grantee_user, grant)

    expect(grantee_policy.show?).to be(true)
    expect(grantee_policy.update?).to be(false)
    expect(grantee_policy.revoke?).to be(false)
  end

  it 'scopes grants to participants only' do
    other_grant = create(:better_together_person_access_grant)

    resolved = BetterTogether::PersonAccessGrantPolicy::Scope.new(user, BetterTogether::PersonAccessGrant.all).resolve

    expect(resolved).to include(grant)
    expect(resolved).not_to include(other_grant)
  end
end

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

  describe 'Scope' do
    let(:source_platform) { grant.person_link.platform_connection.source_platform }

    it 'scopes grants to participants on the current platform' do
      other_grant = create(:better_together_person_access_grant)

      Current.platform = source_platform
      resolved = BetterTogether::PersonAccessGrantPolicy::Scope.new(user, BetterTogether::PersonAccessGrant.all).resolve

      expect(resolved).to include(grant)
      expect(resolved).not_to include(other_grant)
    ensure
      Current.platform = nil
    end

    it 'excludes grants from other platform connections when platform changes' do
      other_platform = create(:better_together_platform, host: false)
      Current.platform = other_platform

      resolved = BetterTogether::PersonAccessGrantPolicy::Scope.new(user, BetterTogether::PersonAccessGrant.all).resolve

      expect(resolved).not_to include(grant)
    ensure
      Current.platform = nil
    end

    it 'returns no grants when the feature rollout is disabled' do
      Current.platform = source_platform
      source_platform.update!(feature_gate_rollouts: { 'person_access_grants' => 'off' })

      resolved = BetterTogether::PersonAccessGrantPolicy::Scope.new(user, BetterTogether::PersonAccessGrant.all).resolve

      expect(resolved).to be_empty
    ensure
      Current.platform = nil
    end
  end
end

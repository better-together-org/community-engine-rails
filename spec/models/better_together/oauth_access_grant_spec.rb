# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::OauthAccessGrant do
  let(:platform) { configure_host_platform }

  before { platform }

  describe 'associations' do
    subject(:access_grant) { build(:oauth_access_grant) }

    it { is_expected.to belong_to(:application).class_name('BetterTogether::OauthApplication').optional }

    it 'tracks resource_owner_id' do
      expect(access_grant.resource_owner_id).to be_present
    end
  end

  describe 'grant lifecycle' do
    it 'generates a unique token on creation' do
      grant = create(:oauth_access_grant)
      expect(grant.token).to be_present
    end

    it 'has an expiry time' do
      grant = create(:oauth_access_grant, expires_in: 600)
      expect(grant.expires_in).to eq(600)
    end

    it 'can be revoked' do
      grant = create(:oauth_access_grant)
      grant.revoke
      expect(grant.revoked?).to be true
    end
  end
end

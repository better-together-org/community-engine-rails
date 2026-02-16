# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::OauthAccessToken do
  let(:platform) { configure_host_platform }

  before { platform }

  describe 'associations' do
    subject(:access_token) { build(:oauth_access_token) }

    it { is_expected.to belong_to(:application).class_name('BetterTogether::OauthApplication').optional }

    it 'tracks resource_owner_id' do
      expect(access_token.resource_owner_id).to be_present
    end
  end

  describe 'token lifecycle' do
    it 'generates a unique token on creation' do
      token = create(:oauth_access_token)
      expect(token.token).to be_present
    end

    it 'can have a refresh token' do
      token = create(:oauth_access_token)
      expect(token).to respond_to(:refresh_token)
    end

    it 'can be revoked' do
      token = create(:oauth_access_token)
      token.revoke
      expect(token.revoked?).to be true
    end

    it 'can be checked for expiry' do
      token = create(:oauth_access_token, expires_in: 7200)
      expect(token.expired?).to be false
    end

    it 'detects expired tokens' do
      token = create(:oauth_access_token, :expired)
      expect(token.expired?).to be true
    end
  end

  describe 'scope checking' do
    it 'validates token has required scopes' do
      token = create(:oauth_access_token, scopes: 'read write')
      expect(token.acceptable?(%w[read])).to be true
    end

    it 'rejects tokens without required scopes' do
      token = create(:oauth_access_token, scopes: 'read')
      expect(token.acceptable?(%w[write])).to be false
    end

    it 'supports MCP access scope' do
      token = create(:oauth_access_token, :with_mcp_scope)
      expect(token.acceptable?(%w[mcp_access])).to be true
    end
  end

  describe 'client credentials tokens' do
    it 'can exist without a resource owner' do
      token = create(:oauth_access_token, :client_credentials)
      expect(token.resource_owner_id).to be_nil
      expect(token).to be_valid
    end
  end
end

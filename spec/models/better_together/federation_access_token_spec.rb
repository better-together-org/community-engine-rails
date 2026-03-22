# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederationAccessToken do
  it 'has a valid factory' do
    expect(build(:better_together_federation_access_token)).to be_valid
  end

  it 'generates an encrypted token and digest on create' do
    token = create(:better_together_federation_access_token)

    expect(token.token).to be_present
    expect(token.token_digest).to eq(described_class.digest(token.token))
  end

  it 'finds active tokens by plaintext token value' do
    token = create(:better_together_federation_access_token)

    expect(described_class.find_active_by_plaintext(token.token)).to eq(token)
  end

  it 'does not resolve expired or revoked tokens as active' do
    expired = create(:better_together_federation_access_token, expires_at: 1.minute.ago)
    revoked = create(:better_together_federation_access_token)
    revoked.revoke!

    expect(described_class.find_active_by_plaintext(expired.token)).to be_nil
    expect(described_class.find_active_by_plaintext(revoked.token)).to be_nil
  end

  it 'parses scopes and checks inclusion' do
    token = create(:better_together_federation_access_token, scopes: 'content.feed.read linked_content.read')

    expect(token.scope_list).to contain_exactly('content.feed.read', 'linked_content.read')
    expect(token.includes_scope?('linked_content.read')).to be true
    expect(token.includes_scope?('content.publish.write')).to be false
  end
end

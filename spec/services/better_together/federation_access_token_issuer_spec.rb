# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederationAccessTokenIssuer do
  describe '#call' do
    let(:source_platform) { create(:better_together_platform) }
    let(:target_platform) { create(:better_together_platform) }
    let(:connection) do
      create(
        :better_together_platform_connection,
        :active,
        source_platform:,
        target_platform:,
        federation_auth_policy: 'api_read',
        content_sharing_policy: 'mirror_network_feed',
        share_posts: true,
        allow_identity_scope: true,
        allow_content_read_scope: true
      )
    end

    it 'issues a scoped access token when the requested scope is authorized' do
      result = described_class.call(connection:, requested_scopes: 'content.feed.read')

      expect(result.access_token).to be_present
      expect(result.scope).to eq('content.feed.read')
      expect(result.access_token_record).to be_persisted
      expect(result.access_token_record.platform_connection).to eq(connection)
    end

    it 'fails closed when the requested scope is not authorized' do
      expect do
        described_class.call(connection:, requested_scopes: 'linked_content.read')
      end.to raise_error(ArgumentError, /authorized/)
    end
  end
end

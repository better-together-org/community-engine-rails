# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederationScopeAuthorizer do
  describe '.call' do
    let(:source_platform) { create(:better_together_platform) }
    let(:target_platform) { create(:better_together_platform, :community_engine_peer) }

    it 'grants scopes that match the directed active platform connection policy' do
      create(
        :better_together_platform_connection,
        :active,
        source_platform:,
        target_platform:,
        content_sharing_policy: 'mirrored_publish_back',
        federation_auth_policy: 'api_write',
        share_posts: true,
        allow_identity_scope: true,
        allow_profile_read_scope: true,
        allow_content_read_scope: true,
        allow_content_write_scope: true
      )

      result = described_class.call(
        source_platform:,
        target_platform:,
        requested_scopes: %w[
          identity.read
          person.profile.read
          content.read
          content.feed.read
          content.mirror.write
          content.publish.write
        ]
      )

      expect(result).to be_allowed
      expect(result.granted_scopes).to contain_exactly(
        'identity.read',
        'person.profile.read',
        'content.read',
        'content.feed.read',
        'content.mirror.write',
        'content.publish.write'
      )
      expect(result.denied_scopes).to be_empty
      expect(result.unsupported_scopes).to be_empty
      expect(result.connection).to be_present
    end

    it 'denies scopes when the directed connection is missing or inactive' do
      create(
        :better_together_platform_connection,
        source_platform: target_platform,
        target_platform: source_platform,
        status: 'active',
        federation_auth_policy: 'api_write',
        allow_identity_scope: true,
        allow_content_read_scope: true,
        allow_content_write_scope: true
      )

      result = described_class.call(
        source_platform:,
        target_platform:,
        requested_scopes: 'identity.read content.read'
      )

      expect(result.allowed?).to be false
      expect(result.connection).to be_nil
      expect(result.granted_scopes).to be_empty
      expect(result.denied_scopes).to contain_exactly('identity.read', 'content.read')
      expect(result.unsupported_scopes).to be_empty
    end

    it 'splits granted, denied, and unsupported scopes' do
      create(
        :better_together_platform_connection,
        :active,
        source_platform:,
        target_platform:,
        content_sharing_policy: 'mirror_network_feed',
        federation_auth_policy: 'login_only',
        share_posts: true,
        allow_identity_scope: true
      )

      result = described_class.call(
        source_platform:,
        target_platform:,
        requested_scopes: 'identity.read content.read unsupported.scope'
      )

      expect(result.allowed?).to be false
      expect(result.granted_scopes).to contain_exactly('identity.read')
      expect(result.denied_scopes).to contain_exactly('content.read')
      expect(result.unsupported_scopes).to contain_exactly('unsupported.scope')
    end
  end
end

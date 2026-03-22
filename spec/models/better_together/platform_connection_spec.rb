# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformConnection do
  it 'has a valid factory' do
    connection = build(:better_together_platform_connection)

    expect(connection).to be_valid
  end

  describe 'validations' do
    it 'requires source and target platforms to differ' do
      platform = create(:better_together_platform)
      connection = build(:better_together_platform_connection, source_platform: platform, target_platform: platform)

      expect(connection).not_to be_valid
      expect(connection.errors[:target_platform_id]).to include('must differ from source platform')
    end

    it 'does not allow duplicate directed edges' do
      source_platform = create(:better_together_platform)
      target_platform = create(:better_together_platform)
      create(:better_together_platform_connection, source_platform:, target_platform:)

      duplicate = build(:better_together_platform_connection, source_platform:, target_platform:)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:source_platform_id]).to be_present
    end
  end

  describe '#peer_for' do
    it 'returns the opposite platform for the source platform' do
      connection = create(:better_together_platform_connection)

      expect(connection.peer_for(connection.source_platform)).to eq(connection.target_platform)
    end

    it 'returns the opposite platform for the target platform' do
      connection = create(:better_together_platform_connection)

      expect(connection.peer_for(connection.target_platform)).to eq(connection.source_platform)
    end
  end

  describe '.for_platform' do
    it 'returns incoming and outgoing connections for a platform' do
      platform = create(:better_together_platform)
      outgoing = create(:better_together_platform_connection, source_platform: platform)
      incoming = create(:better_together_platform_connection, target_platform: platform)
      create(:better_together_platform_connection)

      expect(described_class.for_platform(platform)).to contain_exactly(outgoing, incoming)
    end
  end

  describe 'policy settings' do
    it 'derives compatibility booleans from explicit policy modes' do
      connection = create(
        :better_together_platform_connection,
        content_sharing_policy: 'mirror_network_feed',
        federation_auth_policy: 'api_read',
        share_posts: true,
        allow_identity_scope: true,
        allow_content_read_scope: true
      )

      expect(connection.content_sharing_enabled).to be true
      expect(connection.federation_auth_enabled).to be true
      expect(connection.shared_content_types).to include('posts')
      expect(connection.federation_scope_types).to include('identity', 'content_read')
      expect(connection.oauth_client_id).to be_present
      expect(connection.oauth_client_secret).to be_present
    end

    it 'clears scoped flags when the policy mode is none' do
      connection = create(
        :better_together_platform_connection,
        content_sharing_policy: 'none',
        federation_auth_policy: 'none',
        share_posts: true,
        allow_identity_scope: true
      )

      expect(connection.content_sharing_enabled).to be false
      expect(connection.federation_auth_enabled).to be false
      expect(connection.shared_content_types).to be_empty
      expect(connection.federation_scope_types).to be_empty
    end

    it 'exposes explicit runtime capability helpers for sync and auth' do
      connection = create(
        :better_together_platform_connection,
        content_sharing_policy: 'mirrored_publish_back',
        federation_auth_policy: 'api_write',
        share_posts: true,
        share_events: true,
        allow_identity_scope: true,
        allow_content_read_scope: true,
        allow_linked_content_read_scope: true,
        allow_content_write_scope: true
      )

      expect(connection.allows_content_type?('posts')).to be true
      expect(connection.allows_content_type?(:events)).to be true
      expect(connection.allows_content_type?(:pages)).to be false
      expect(connection.allows_federation_scope?('identity')).to be true
      expect(connection.allows_federation_scope?(:content_write)).to be true
      expect(connection.allows_federation_scope?(:linked_content_read)).to be true
      expect(connection.mirrored_content_enabled?).to be true
      expect(connection.publish_back_enabled?).to be true
      expect(connection.login_enabled?).to be true
      expect(connection.api_read_enabled?).to be true
      expect(connection.linked_content_read_enabled?).to be true
      expect(connection.api_write_enabled?).to be true
    end

    it 'tracks sync lifecycle state in settings' do
      connection = create(:better_together_platform_connection)

      connection.mark_sync_started!(cursor: 'cursor-1', started_at: Time.zone.parse('2026-03-12 12:00:00 UTC'))
      expect(connection.reload).to be_sync_running
      expect(connection.sync_cursor).to eq('cursor-1')
      expect(connection.last_sync_started_at_time).to be_present

      connection.mark_sync_succeeded!(cursor: 'cursor-2', item_count: 3, synced_at: Time.zone.parse('2026-03-12 12:05:00 UTC'))
      expect(connection.reload).to be_sync_succeeded
      expect(connection.sync_cursor).to eq('cursor-2')
      expect(connection.last_sync_item_count).to eq(3)
      expect(connection.last_synced_at_time).to be_present
      expect(connection.last_sync_error_message).to be_blank
    end

    it 'records sync failures without clearing the last successful completion' do
      connection = create(:better_together_platform_connection)
      connection.mark_sync_succeeded!(item_count: 1, synced_at: Time.zone.parse('2026-03-12 12:05:00 UTC'))

      connection.mark_sync_failed!(message: 'Remote timeout', cursor: 'cursor-3', failed_at: Time.zone.parse('2026-03-12 12:10:00 UTC'))

      expect(connection.reload).to be_sync_failed
      expect(connection.sync_cursor).to eq('cursor-3')
      expect(connection.last_sync_error_message).to eq('Remote timeout')
      expect(connection.last_sync_error_at_time).to be_present
      expect(connection.last_synced_at_time).to be_present
    end
  end

  describe 'oauth credentials encryption' do
    it 'stores oauth_client_secret encrypted at rest' do
      connection = create(:better_together_platform_connection)
      plaintext_secret = connection.oauth_client_secret

      raw = described_class.connection
                           .select_one("SELECT oauth_client_secret FROM better_together_platform_connections WHERE id='#{connection.id}'")

      # AR::Encryption stores JSON ciphertext in the same column — never plaintext
      expect(raw['oauth_client_secret']).not_to eq(plaintext_secret)
      expect(raw['oauth_client_secret']).to match(/\A\{.*"p"/)

      # Model decrypts transparently
      expect(connection.reload.oauth_client_secret).to eq(plaintext_secret)
    end

    it 'stores a BCrypt digest for inbound verification' do
      connection = create(:better_together_platform_connection)

      expect(connection.oauth_client_secret_digest).to be_present
      # BCrypt digest format: $2a$12$...
      expect(connection.oauth_client_secret_digest).to match(/\A\$2[aby]\$/)
    end

    it 'authenticates a correct secret and rejects an incorrect one' do
      connection = create(:better_together_platform_connection)
      good = connection.oauth_client_secret

      expect(connection.authenticate_oauth_secret(good)).to be true
      expect(connection.authenticate_oauth_secret('wrong-secret')).to be false
    end

    it 'authenticates via BCrypt digest when digest is present' do
      connection = create(:better_together_platform_connection)
      good = connection.oauth_client_secret

      # Verify it takes the BCrypt path (digest present)
      expect(connection.oauth_client_secret_digest).to be_present
      expect(connection.authenticate_oauth_secret(good)).to be true
      expect(connection.authenticate_oauth_secret('bad')).to be false
    end

    it 'falls back to SHA-256 comparison when digest is absent' do
      connection = create(:better_together_platform_connection)
      good = connection.oauth_client_secret
      connection.update_column(:oauth_client_secret_digest, nil)

      expect(connection.authenticate_oauth_secret(good)).to be true
      expect(connection.authenticate_oauth_secret('bad')).to be false
    end

    it 'rotates the client secret and updates the BCrypt digest' do
      connection = create(:better_together_platform_connection)
      old_id     = connection.oauth_client_id
      old_secret = connection.oauth_client_secret

      connection.rotate_oauth_client_secret!
      connection.reload

      expect(connection.oauth_client_id).to eq(old_id)
      expect(connection.oauth_client_secret).not_to eq(old_secret)
      expect(connection.oauth_client_secret_digest).to be_present
      expect(connection.authenticate_oauth_secret(old_secret)).to be false
      expect(connection.authenticate_oauth_secret(connection.oauth_client_secret)).to be true
    end
  end
end

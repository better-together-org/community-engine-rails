# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::FederatedContentAuthorizer do
  describe '.call' do
    let(:connection) { create(:better_together_platform_connection, :active) }

    it 'allows mirroring for content types enabled on the connection' do
      connection.update!(
        content_sharing_policy: 'mirror_network_feed',
        share_posts: true,
        share_events: true
      )

      post_result = described_class.call(connection:, content_or_type: BetterTogether::Post, action: :mirror)
      event_result = described_class.call(connection:, content_or_type: create(:better_together_event), action: :mirror)
      page_result = described_class.call(connection:, content_or_type: BetterTogether::Page, action: :mirror)

      expect(post_result).to be_allowed
      expect(post_result.normalized_type).to eq('posts')
      expect(event_result).to be_allowed
      expect(page_result.allowed?).to be false
      expect(page_result.reason).to eq('content mirroring not enabled for type')
    end

    it 'allows publish back only when publish-back policy and content type are both enabled' do
      connection.update!(
        content_sharing_policy: 'mirrored_publish_back',
        federation_auth_policy: 'api_write',
        share_posts: true,
        allow_content_write_scope: true
      )

      post_result = described_class.call(connection:, content_or_type: 'post', action: :publish_back)
      event_result = described_class.call(connection:, content_or_type: 'event', action: :publish_back)

      expect(post_result).to be_allowed
      expect(event_result.allowed?).to be false
      expect(event_result.reason).to eq('publish back not enabled for type')
    end

    it 'rejects unsupported content types and unsupported actions' do
      unsupported_type = described_class.call(connection:, content_or_type: 'community', action: :mirror)
      unsupported_action = described_class.call(connection:, content_or_type: 'post', action: :sync)

      expect(unsupported_type.allowed?).to be false
      expect(unsupported_type.reason).to eq('unsupported content type')
      expect(unsupported_action.allowed?).to be false
      expect(unsupported_action.reason).to eq('unsupported action')
    end

    it 'rejects inactive connections' do
      connection.update!(status: 'suspended', content_sharing_policy: 'mirror_network_feed', share_posts: true)

      result = described_class.call(connection:, content_or_type: BetterTogether::Post, action: :mirror)

      expect(result.allowed?).to be false
      expect(result.reason).to eq('connection is not active')
    end
  end
end

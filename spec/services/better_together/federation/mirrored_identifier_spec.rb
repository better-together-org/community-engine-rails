# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Federation::MirroredIdentifier, type: :service do
  let(:source_platform) { create(:better_together_platform, identifier: 'source-platform') }

  describe '.canonical' do
    it 'builds a canonical identifier from the source platform slug and remote identifier' do
      result = described_class.canonical(
        source_platform: source_platform,
        remote_identifier: 'my-post',
        remote_id: '42',
        content_type: 'post'
      )

      expect(result).to start_with('source-platform--')
      expect(result).to include('my-post')
    end

    it 'normalizes the remote_identifier slug fragment' do
      result = described_class.canonical(
        source_platform: source_platform,
        remote_identifier: 'My Post Title!',
        remote_id: '1',
        content_type: 'post'
      )

      expect(result).to eq('source-platform--my-post-title')
    end

    it 'uses fallback remote key when remote_identifier is blank' do
      result = described_class.canonical(
        source_platform: source_platform,
        remote_identifier: nil,
        remote_id: '99',
        content_type: 'post'
      )

      expect(result).to start_with('source-platform--federated-post-')
    end

    it 'falls back to remote source slug when source_platform is nil' do
      result = described_class.canonical(
        source_platform: nil,
        remote_identifier: 'some-page',
        remote_id: '5',
        content_type: 'page'
      )

      expect(result).to start_with('remote--')
    end

    it 'preserves namespace separators in the source platform identifier' do
      platform = create(:better_together_platform, identifier: 'org--community')
      result = described_class.canonical(
        source_platform: platform,
        remote_identifier: 'article',
        remote_id: '10',
        content_type: 'article'
      )

      expect(result).to start_with('org--community--')
    end
  end

  describe '.remote_identifier_base' do
    it 'returns the normalized remote_identifier when present and normalizable' do
      result = described_class.remote_identifier_base(
        remote_identifier: 'hello-world',
        remote_id: '1',
        content_type: 'post'
      )

      expect(result).to eq('hello-world')
    end

    it 'falls back to a prefixed fallback key when remote_identifier is blank' do
      result = described_class.remote_identifier_base(
        remote_identifier: '',
        remote_id: '123',
        content_type: 'comment'
      )

      expect(result).to start_with('federated-comment-')
    end

    it 'falls back to a prefixed fallback key when remote_identifier normalizes to blank' do
      result = described_class.remote_identifier_base(
        remote_identifier: '!!!',
        remote_id: 'abc',
        content_type: 'event'
      )

      expect(result).to start_with('federated-event-')
    end
  end

  describe '.fallback_remote_key' do
    it 'returns the normalized remote_id when normalizable' do
      result = described_class.fallback_remote_key('my-slug-42')
      expect(result).to eq('my-slug-42')
    end

    it 'returns a SHA256 prefix when remote_id cannot be normalized to a slug' do
      result = described_class.fallback_remote_key('!@#$%')
      expect(result).to match(/\A[0-9a-f]{12}\z/)
    end

    it 'produces a 12-character hex digest from the SHA256 of the remote_id' do
      raw_id = '!@#$%^&*()'
      expected_hex = Digest::SHA256.hexdigest(raw_id)[0, 12]
      expect(described_class.fallback_remote_key(raw_id)).to eq(expected_hex)
    end

    it 'is deterministic for the same remote_id' do
      result1 = described_class.fallback_remote_key('same-id')
      result2 = described_class.fallback_remote_key('same-id')
      expect(result1).to eq(result2)
    end
  end
end

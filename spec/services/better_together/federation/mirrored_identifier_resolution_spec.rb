# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Federation::MirroredIdentifierResolution, type: :service do
  # Minimal anonymous host class that includes the module and exposes a connection.
  # All module methods are private, so we access them via send in examples.
  subject(:host) { host_class.new(connection) }

  let(:host_class) do
    Class.new do
      include BetterTogether::Federation::MirroredIdentifierResolution

      attr_reader :connection

      def initialize(connection)
        @connection = connection
      end
    end
  end

  let(:source_platform) { create(:better_together_platform, identifier: 'source-host') }
  let(:target_platform) { create(:better_together_platform, identifier: 'target-host') }

  let(:connection) do
    Struct.new(:source_platform, :target_platform).new(source_platform, target_platform)
  end

  describe '#identifier_candidates' do
    it 'returns the base identifier as the first candidate' do
      candidates = host.send(:identifier_candidates, 'my-slug')
      expect(candidates.first).to eq('my-slug')
    end

    it 'returns a source-prefixed candidate second' do
      candidates = host.send(:identifier_candidates, 'my-slug')
      expect(candidates[1]).to eq('source-host-my-slug')
    end

    it 'returns a target-source-prefixed candidate third' do
      candidates = host.send(:identifier_candidates, 'my-slug')
      expect(candidates[2]).to eq('target-host-source-host-my-slug')
    end

    it 'produces exactly 3 candidates' do
      expect(host.send(:identifier_candidates, 'article').size).to eq(3)
    end
  end

  describe '#platform_identifier_slug' do
    it 'returns the parameterized platform identifier' do
      result = host.send(:platform_identifier_slug, source_platform, fallback: 'remote')
      expect(result).to eq('source-host')
    end

    it 'returns the fallback when the platform identifier is blank' do
      blank_platform = build(:better_together_platform, identifier: '')
      result = host.send(:platform_identifier_slug, blank_platform, fallback: 'remote')
      expect(result).to eq('remote')
    end
  end

  describe '#mirrored_identifier_for' do
    it 'returns a canonical identifier prefixed with the source platform slug' do
      result = host.send(:mirrored_identifier_for,
                         content_type: 'post',
                         remote_identifier: 'imported-post',
                         remote_id: '42')
      expect(result).to start_with('source-host--')
      expect(result).to include('imported-post')
    end

    it 'is deterministic for the same inputs' do
      args = { content_type: 'post', remote_identifier: 'same-slug', remote_id: '1' }
      first_result = host.send(:mirrored_identifier_for, **args)
      second_result = host.send(:mirrored_identifier_for, **args)
      expect(first_result).to eq(second_result)
    end

    it 'uses a fallback hash when remote_identifier is blank' do
      result = host.send(:mirrored_identifier_for,
                         content_type: 'post',
                         remote_identifier: nil,
                         remote_id: '99')
      expect(result).to start_with('source-host--federated-post-')
    end
  end

  describe '#identifier_taken?' do
    let(:platform) { create(:better_together_platform, :public) }
    let!(:existing_post) { create(:better_together_post, platform:, privacy: 'public') }

    it 'returns true when a record with the given identifier exists' do
      taken = host.send(:identifier_taken?, BetterTogether::Post, existing_post.identifier, nil)
      expect(taken).to be true
    end

    it 'returns false when no record has that identifier' do
      taken = host.send(:identifier_taken?, BetterTogether::Post, 'nonexistent-slug-xyz', nil)
      expect(taken).to be false
    end

    it 'excludes the record with exclude_id when checking' do
      taken = host.send(:identifier_taken?, BetterTogether::Post, existing_post.identifier, existing_post.id)
      expect(taken).to be false
    end
  end

  describe '#identifier_or_namespaced' do
    let(:platform) { create(:better_together_platform, :public) }
    let!(:existing_post) { create(:better_together_post, platform:, privacy: 'public') }

    it 'returns the base identifier when it is not taken' do
      result = host.send(:identifier_or_namespaced, BetterTogether::Post, 'fresh-unique-slug', nil)
      expect(result).to eq('fresh-unique-slug')
    end

    it 'returns the source-prefixed identifier when base is already taken' do
      base = existing_post.identifier
      result = host.send(:identifier_or_namespaced, BetterTogether::Post, base, nil)
      expect(result).to eq("source-host-#{base}")
    end

    it 'skips to the third candidate when the first two are taken' do
      base = existing_post.identifier
      prefixed = create(:better_together_post, platform:, privacy: 'public').tap do |p|
        p.update_columns(identifier: "source-host-#{base}")
      end

      result = host.send(:identifier_or_namespaced, BetterTogether::Post, base, nil)
      expect(result).to eq("target-host-source-host-#{base}")
    ensure
      prefixed&.destroy
    end

    it 'returns nil when all three candidates are taken' do
      base = existing_post.identifier
      [
        "source-host-#{base}",
        "target-host-source-host-#{base}"
      ].each_with_index do |ident, _i|
        post = create(:better_together_post, platform:, privacy: 'public')
        post.update_columns(identifier: ident)
      end

      result = host.send(:identifier_or_namespaced, BetterTogether::Post, base, nil)
      expect(result).to be_nil
    end
  end

  describe '#existing_identifier_conflict_for' do
    let(:platform) { create(:better_together_platform, :public) }
    let!(:existing_post) { create(:better_together_post, platform:, privacy: 'public') }

    let(:canonical_identifier) do
      host.send(:mirrored_identifier_for,
                content_type: 'post',
                remote_identifier: 'conflict-slug',
                remote_id: '5')
    end

    before { existing_post.update_columns(identifier: canonical_identifier) }

    it 'returns the conflicting record when one exists' do
      conflict = host.send(:existing_identifier_conflict_for,
                           BetterTogether::Post,
                           content_type: 'post',
                           remote_identifier: 'conflict-slug',
                           remote_id: '5')
      expect(conflict).to eq(existing_post)
    end

    it 'returns nil when no conflict exists' do
      conflict = host.send(:existing_identifier_conflict_for,
                           BetterTogether::Post,
                           content_type: 'post',
                           remote_identifier: 'no-conflict-here',
                           remote_id: '99')
      expect(conflict).to be_nil
    end

    it 'ignores the excluded record when exclude_id is set' do
      conflict = host.send(:existing_identifier_conflict_for,
                           BetterTogether::Post,
                           content_type: 'post',
                           remote_identifier: 'conflict-slug',
                           remote_id: '5',
                           exclude_id: existing_post.id)
      expect(conflict).to be_nil
    end
  end
end

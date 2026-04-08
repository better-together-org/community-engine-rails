# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::Builder do
  describe 'generic seedable subjects' do
    let(:person) { create(:better_together_person) }

    it 'builds and persists a personal export seed for a person' do
      result = described_class.call(
        subject: person,
        profile: :personal_export,
        persist: true,
        creator_id: person.id
      )

      seed_hash = result.seed_hash
      root = seed_hash[BetterTogether::Seed::DEFAULT_ROOT_KEY]

      expect(result.seed_record).to be_a(BetterTogether::Seed)
      expect(root[:seed][:origin][:profile]).to eq('personal_export')
      expect(root[:seed][:origin][:lane]).to eq('personal_export')
      expect(root[:record]).to eq(person.plant)
      expect(result.seed_record.creator_id).to eq(person.id)
    end

    it 'can build without persisting' do
      result = described_class.call(subject: person, profile: :manual_export, persist: false)

      expect(result.seed_record).to be_nil
      expect(result.seed_hash[BetterTogether::Seed::DEFAULT_ROOT_KEY][:record]).to eq(person.plant)
    end
  end

  describe 'federated content subjects' do
    it 'builds a deterministic platform-shared seed envelope for a post' do
      source_platform = create(:better_together_platform, :community_engine_peer)
      target_platform = create(:better_together_platform)
      connection = create(:better_together_platform_connection, :active, source_platform:, target_platform:)
      post = create(:better_together_post, platform: source_platform, privacy: 'public', published_at: 1.day.ago)

      result = described_class.call(
        subject: post,
        profile: :platform_shared,
        context: { connection: connection },
        persist: false
      )

      seed = result.seed_hash

      expect(seed['better_together'][:seed][:origin][:lane]).to eq('platform_shared')
      expect(seed['better_together'][:seed][:origin][:profile]).to eq('platform_shared')
      expect(seed['better_together'][:payload][:type]).to eq('post')
      expect(seed['better_together'][:payload][:id]).to eq(post.id)
    end
  end
end

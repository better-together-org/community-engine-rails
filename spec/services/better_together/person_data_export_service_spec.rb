# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonDataExportService do
  describe '#call' do
    let(:person) { create(:better_together_person) }

    before do
      create(:better_together_person_platform_membership, member: person)
      create(:person_block, blocker: person)
      create(:better_together_seed, :personal_export, person: person)
    end

    it 'returns a seed-backed personal export package and persists the export seed' do
      result = described_class.new(person: person).call
      seed_hash = result.seed_hash
      root = seed_hash[BetterTogether::Seed::DEFAULT_ROOT_KEY]
      payload = root[:payload]

      expect(payload[:person]).to include(
        id: person.id,
        identifier: person.identifier,
        name: person.name,
        privacy: person.privacy
      )
      expect(payload[:memberships][:platforms]).not_to be_empty
      expect(payload[:blocks][:blocked_people]).not_to be_empty
      expect(payload[:seeds]).not_to be_empty
      expect(root[:seed][:origin][:profile]).to eq('personal_export')
      expect(result.seed_record).to be_a(BetterTogether::Seed)
      expect(result.seed_record.creator_id).to eq(person.id)
    end
  end
end

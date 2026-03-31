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

    it 'returns a portable hash with core person data' do
      payload = described_class.new(person: person).call

      expect(payload[:person]).to include(
        id: person.id,
        identifier: person.identifier,
        name: person.name,
        privacy: person.privacy
      )
      expect(payload[:memberships][:platforms]).not_to be_empty
      expect(payload[:blocks][:blocked_people]).not_to be_empty
      expect(payload[:seeds]).not_to be_empty
    end
  end
end

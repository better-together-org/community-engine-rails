# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::OneTimePrekey do
  subject(:prekey) do
    described_class.new(person: person, key_id: 1, public_key: 'base64encodedpublickey==')
  end

  let(:person) { create(:better_together_person) }

  describe 'validations' do
    it 'is valid with required attributes' do
      expect(prekey).to be_valid
    end

    it 'requires key_id' do
      prekey.key_id = nil
      expect(prekey).not_to be_valid
    end

    it 'requires key_id to be a positive integer' do
      prekey.key_id = 0
      expect(prekey).not_to be_valid
      prekey.key_id = -1
      expect(prekey).not_to be_valid
    end

    it 'requires public_key' do
      prekey.public_key = nil
      expect(prekey).not_to be_valid
    end

    it 'requires key_id to be unique per person' do
      create(:better_together_one_time_prekey, person: person, key_id: 1)
      expect(prekey).not_to be_valid
      expect(prekey.errors[:key_id]).to be_present
    end

    it 'allows the same key_id for different people' do
      other_person = create(:better_together_person)
      create(:better_together_one_time_prekey, person: other_person, key_id: 1)
      expect(prekey).to be_valid
    end
  end

  describe '.unconsumed scope' do
    it 'returns only unconsumed prekeys ordered by id ascending' do
      unconsumed = create(:better_together_one_time_prekey, person: person, key_id: 10, consumed: false)
      consumed = create(:better_together_one_time_prekey, person: person, key_id: 11, consumed: true)
      result = described_class.unconsumed
      expect(result).to include(unconsumed)
      expect(result).not_to include(consumed)
    end
  end

  describe '.consumed scope' do
    it 'returns only consumed prekeys' do
      unconsumed = create(:better_together_one_time_prekey, person: person, key_id: 20, consumed: false)
      consumed = create(:better_together_one_time_prekey, person: person, key_id: 21, consumed: true)
      result = described_class.consumed
      expect(result).to include(consumed)
      expect(result).not_to include(unconsumed)
    end
  end
end

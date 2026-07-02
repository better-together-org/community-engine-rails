# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::C3::Token do
  subject(:token) { build(:c3_token) }

  describe 'constants' do
    it 'defines MILLITOKEN_SCALE as 1_000' do
      expect(described_class::MILLITOKEN_SCALE).to eq(1_000)
    end

    it 'defines MAX_SINGLE_TRANSACTION_MILLITOKENS as 10_000_000' do
      expect(described_class::MAX_SINGLE_TRANSACTION_MILLITOKENS).to eq(10_000_000)
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:earner) }
    it { is_expected.to belong_to(:community).optional }
    it { is_expected.to belong_to(:origin_platform).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:contribution_type) }
    it { is_expected.to validate_presence_of(:source_ref) }
    it { is_expected.to validate_presence_of(:source_system) }

    it 'is valid with required attributes' do
      expect(token).to be_valid
    end

    it 'requires c3_millitokens to be >= 0' do
      token.c3_millitokens = -1
      expect(token).not_to be_valid
      expect(token.errors[:c3_millitokens]).to be_present
    end

    it 'accepts c3_millitokens of 0' do
      token.c3_millitokens = 0
      expect(token).to be_valid
    end

    it 'rejects c3_millitokens above MAX_SINGLE_TRANSACTION_MILLITOKENS' do
      token.c3_millitokens = described_class::MAX_SINGLE_TRANSACTION_MILLITOKENS + 1
      expect(token).not_to be_valid
      expect(token.errors[:c3_millitokens]).to be_present
    end

    it 'accepts c3_millitokens equal to MAX_SINGLE_TRANSACTION_MILLITOKENS' do
      token.c3_millitokens = described_class::MAX_SINGLE_TRANSACTION_MILLITOKENS
      expect(token).to be_valid
    end

    it 'validates status is in allowed set' do
      token.status = 'invalid_status'
      expect(token).not_to be_valid
      expect(token.errors[:status]).to be_present
    end

    describe 'source_ref uniqueness within source_system' do
      it 'rejects a duplicate source_ref for the same source_system' do
        person = create(:better_together_person)
        create(:c3_token, earner: person, source_ref: 'ref-001', source_system: 'borgberry')

        duplicate = build(:c3_token, earner: person, source_ref: 'ref-001', source_system: 'borgberry')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:source_ref]).to be_present
      end

      it 'allows the same source_ref for a different source_system' do
        person = create(:better_together_person)
        create(:c3_token, earner: person, source_ref: 'ref-001', source_system: 'borgberry')

        other_system = build(:c3_token, earner: person, source_ref: 'ref-001', source_system: 'external')
        expect(other_system).to be_valid
      end
    end
  end

  describe 'enums' do
    it 'supports compute_cpu contribution type' do
      token.contribution_type = :compute_cpu
      expect(token.contribution_type).to eq('compute_cpu')
    end

    it 'supports all contribution types defined in CONTRIBUTION_TYPES' do
      described_class::CONTRIBUTION_TYPES.each_key do |type|
        token.contribution_type = type
        expect(token.contribution_type).to eq(type.to_s)
      end
    end
  end

  describe 'scopes' do
    let(:person) { create(:better_together_person) }

    before do
      create(:c3_token, :confirmed, earner: person, source_ref: 'confirmed-1')
      create(:c3_token, earner: person, status: 'pending', source_ref: 'pending-1')
    end

    it '.confirmed returns only confirmed tokens' do
      expect(described_class.confirmed.pluck(:status)).to all(eq('confirmed'))
    end

    it '.pending returns only pending tokens' do
      expect(described_class.pending.pluck(:status)).to all(eq('pending'))
    end

    it '.local returns tokens with federated false' do
      local = create(:c3_token, earner: person, federated: false, source_ref: 'local-1')
      expect(described_class.local).to include(local)
    end

    it '.federated returns tokens with federated true' do
      fed = create(:c3_token, earner: person, federated: true, source_ref: 'fed-1')
      expect(described_class.federated).to include(fed)
    end

    describe '.for_source' do
      it 'finds a token by source_system and source_ref' do
        target = create(:c3_token, earner: person, source_system: 'borgberry', source_ref: 'job-abc-99')
        result = described_class.for_source('borgberry', 'job-abc-99')
        expect(result).to include(target)
      end

      it 'does not match a different source_ref' do
        create(:c3_token, earner: person, source_system: 'borgberry', source_ref: 'job-other-1')
        result = described_class.for_source('borgberry', 'job-abc-99')
        expect(result).to be_empty
      end
    end
  end

  describe 'polymorphic earner' do
    it 'accepts a Person as earner' do
      person = create(:better_together_person)
      token = create(:c3_token, earner: person)
      expect(token.earner).to eq(person)
      expect(token.earner_type).to eq('BetterTogether::Person')
    end

    it 'accepts a Fleet::Node as earner' do
      node = create(:better_together_fleet_node)
      token = create(:c3_token, earner: node)
      expect(token.earner).to eq(node)
      expect(token.earner_type).to eq('BetterTogether::Fleet::Node')
    end
  end

  describe '#confirm!' do
    let(:pending_token) { create(:c3_token) }

    it 'sets status to confirmed' do
      pending_token.confirm!
      expect(pending_token.reload.status).to eq('confirmed')
    end

    it 'sets confirmed_at to current time' do
      travel_to(Time.current) do
        pending_token.confirm!
        expect(pending_token.reload.confirmed_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe '#c3_amount=' do
    it 'converts the C3 amount to millitokens using the class method' do
      token.c3_amount = 2.5
      expect(token.c3_millitokens).to eq(2_500)
    end
  end

  describe '#c3_amount' do
    it 'returns the float representation of stored millitokens' do
      token.c3_millitokens = 3_750
      expect(token.c3_amount).to eq(3.75)
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::C3::TokenSeed do # rubocop:todo RSpec/MultipleMemoizedHelpers
  let(:earner_did) { "did:key:z6MkEarner#{SecureRandom.hex(4)}" }
  let(:payer_did)  { "did:key:z6MkPayer#{SecureRandom.hex(4)}" }
  let(:earner)     { create(:better_together_person, borgberry_did: earner_did) }
  let(:payer)      { create(:better_together_person, borgberry_did: payer_did) }

  def build_token_seed(payload_override = {}) # rubocop:todo Metrics/MethodLength
    seed = described_class.new(
      identifier: "c3_token:#{SecureRandom.uuid}",
      version: described_class::VERSION,
      created_by: 'test_platform',
      seeded_at: Time.current,
      description: 'test token seed',
      origin: { lane: described_class::LANE },
      payload: {
        earner_did: earner_did,
        c3_millitokens: 1_000,
        contribution_type: 'compute_cpu',
        source_ref: "borgberry-task-#{SecureRandom.hex(8)}",
        source_system: 'borgberry'
      }.merge(payload_override)
    )
    seed.save!(validate: false)
    seed
  end

  describe 'constants' do
    it 'LANE is c3_transfer' do
      expect(described_class::LANE).to eq('c3_transfer')
    end

    it 'VERSION is 1.0' do
      expect(described_class::VERSION).to eq('1.0')
    end
  end

  describe 'Result struct' do
    it 'exposes applied and reason' do
      result = described_class::Result.new(true, nil)
      expect(result.applied).to be true
      expect(result.reason).to be_nil
    end

    it 'carries a failure reason' do
      result = described_class::Result.new(false, :earner_did_not_found_locally)
      expect(result.applied).to be false
      expect(result.reason).to eq(:earner_did_not_found_locally)
    end
  end

  describe '.from_token' do
    it 'builds an unsaved TokenSeed from a C3::Token' do
      token = create(:c3_token, :confirmed,
                     earner: earner,
                     source_ref: "settlement:#{SecureRandom.hex(6)}",
                     source_system: 'borgberry')
      source_platform = create(:better_together_platform)

      seed = described_class.from_token(token, source_platform: source_platform)

      expect(seed).to be_a(described_class)
      expect(seed).not_to be_persisted
      expect(seed.identifier).to eq("c3_token-#{token.id}")
      expect(seed.version).to eq(described_class::VERSION)
    end

    it 'replaces source_ref with a SHA-256 hash to prevent internal ref leakage' do
      token = create(:c3_token, :confirmed,
                     earner: earner,
                     source_ref: "agreement:secret-#{SecureRandom.hex(6)}",
                     source_system: 'borgberry')
      source_platform = create(:better_together_platform)

      seed = described_class.from_token(token, source_platform: source_platform)

      expect(seed.payload[:source_ref_hash]).to match(/\A[0-9a-f]{64}\z/)
      expect(seed.payload[:source_ref_hash]).not_to include('secret')
    end

    it 'sets seeded_at from token.emitted_at' do
      emitted = 2.days.ago.beginning_of_hour
      token = create(:c3_token, :confirmed,
                     earner: earner,
                     source_ref: "ref-#{SecureRandom.hex(6)}",
                     source_system: 'borgberry',
                     emitted_at: emitted)
      source_platform = create(:better_together_platform)

      seed = described_class.from_token(token, source_platform: source_platform)
      expect(seed.seeded_at).to be_within(1.second).of(emitted)
    end
  end

  describe '.from_wire_params' do
    let(:source_platform) { create(:better_together_platform) }
    let(:token_id)        { SecureRandom.uuid }

    it 'builds an unsaved TokenSeed from wire params' do
      params = {
        token_id: token_id,
        earner_did: earner_did,
        contribution_type: 'volunteer',
        c3_millitokens: 2_000,
        source_ref: "ref-#{SecureRandom.hex(4)}",
        source_system: 'ce_joatu',
        emitted_at: Time.current.iso8601
      }

      seed = described_class.from_wire_params(params, source_platform: source_platform)

      expect(seed).to be_a(described_class)
      expect(seed).not_to be_persisted
      expect(seed.identifier).to eq("c3_token-#{token_id}")
    end

    it 'stores earner_did and c3_millitokens in the payload' do
      params = {
        token_id: token_id,
        earner_did: earner_did,
        c3_millitokens: 500,
        source_ref: "ref-#{SecureRandom.hex(4)}",
        source_system: 'borgberry',
        emitted_at: Time.current.iso8601
      }

      seed = described_class.from_wire_params(params, source_platform: source_platform)

      expect(seed.payload[:earner_did]).to eq(earner_did)
      expect(seed.payload[:c3_millitokens]).to eq(500)
    end
  end

  describe '#apply_to_recipient_balance!' do
    context 'with invalid payload' do
      it 'returns invalid_payload when earner_did is blank' do
        seed = build_token_seed(earner_did: '')
        result = seed.apply_to_recipient_balance!(origin_platform: nil)
        expect(result.applied).to be false
        expect(result.reason).to eq(:invalid_payload)
      end

      it 'returns invalid_payload when c3_millitokens is zero' do
        seed = build_token_seed(c3_millitokens: 0)
        result = seed.apply_to_recipient_balance!(origin_platform: nil)
        expect(result.applied).to be false
        expect(result.reason).to eq(:invalid_payload)
      end

      it 'returns invalid_payload when c3_millitokens is negative' do
        seed = build_token_seed(c3_millitokens: -500)
        result = seed.apply_to_recipient_balance!(origin_platform: nil)
        expect(result.applied).to be false
        expect(result.reason).to eq(:invalid_payload)
      end
    end

    context 'when already applied' do
      it 'returns applied=true, reason=:already_applied without creating a second token' do
        source_ref = "borgberry-task-#{SecureRandom.hex(8)}"
        create(:c3_token, :confirmed,
               earner: earner,
               source_ref: source_ref,
               source_system: 'borgberry')

        seed = build_token_seed(source_ref: source_ref, source_system: 'borgberry')
        expect { seed.apply_to_recipient_balance!(origin_platform: nil) }
          .not_to(change(BetterTogether::C3::Token, :count))

        result = seed.apply_to_recipient_balance!(origin_platform: nil)
        expect(result.applied).to be true
        expect(result.reason).to eq(:already_applied)
      end
    end

    context 'when earner DID is not enrolled locally' do
      it 'returns applied=false, reason=:earner_did_not_found_locally' do
        seed = build_token_seed(earner_did: 'did:key:z6MkNobody')
        result = seed.apply_to_recipient_balance!(origin_platform: nil)
        expect(result.applied).to be false
        expect(result.reason).to eq(:earner_did_not_found_locally)
      end
    end

    context 'with direct credit (origin_platform: nil, no payer_did)' do
      before { earner }

      it 'returns applied=true' do
        seed = build_token_seed
        result = seed.apply_to_recipient_balance!(origin_platform: nil)
        expect(result.applied).to be true
        expect(result.reason).to be_nil
      end

      it 'creates a C3::Balance for the earner' do
        seed = build_token_seed
        expect { seed.apply_to_recipient_balance!(origin_platform: nil) }
          .to change(BetterTogether::C3::Balance, :count).by(1)
      end

      it 'creates a confirmed C3::Token for the earner' do
        seed = build_token_seed(source_ref: "unique-#{SecureRandom.hex(8)}")
        seed.apply_to_recipient_balance!(origin_platform: nil)

        token = BetterTogether::C3::Token.last
        expect(token.earner).to eq(earner)
        expect(token.status).to eq('confirmed')
        expect(token.federated).to be true
        expect(token.c3_millitokens).to eq(1_000)
      end

      it 'credits the millitokens to the earner balance' do
        seed = build_token_seed(c3_millitokens: 3_000, source_ref: "ref-#{SecureRandom.hex(8)}")
        seed.apply_to_recipient_balance!(origin_platform: nil)

        balance = BetterTogether::C3::Balance.find_by(holder: earner, community: nil,
                                                      origin_platform: nil)
        expect(balance.available_millitokens).to eq(3_000)
      end
    end

    context 'with payer_did and locked settlement (origin_platform: nil)' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:payer_balance) do
        create(:c3_balance, holder: payer, available_millitokens: 5_000, locked_millitokens: 0)
      end
      let(:lock_ref) { payer_balance.lock_millitokens!(1_000) }

      before do
        earner
        payer
        payer_balance
      end

      it 'returns applied=false, reason=:payer_not_found_locally when payer not enrolled' do
        seed = build_token_seed(payer_did: 'did:key:z6MkUnknown', lock_ref: 'someref')
        result = seed.apply_to_recipient_balance!(origin_platform: nil)
        expect(result.applied).to be false
        expect(result.reason).to eq(:payer_not_found_locally)
      end

      it 'returns applied=false, reason=:payer_balance_not_found when payer has no balance' do
        payer_no_bal_did = "did:key:z6MkNoBalance#{SecureRandom.hex(4)}"
        create(:better_together_person, borgberry_did: payer_no_bal_did)

        seed = build_token_seed(payer_did: payer_no_bal_did, lock_ref: 'someref')
        result = seed.apply_to_recipient_balance!(origin_platform: nil)
        expect(result.applied).to be false
        expect(result.reason).to eq(:payer_balance_not_found)
      end

      it 'returns applied=false, reason=:lock_ref_required when lock_ref is blank' do
        seed = build_token_seed(payer_did: payer_did, lock_ref: '')
        result = seed.apply_to_recipient_balance!(origin_platform: nil)
        expect(result.applied).to be false
        expect(result.reason).to eq(:lock_ref_required)
      end

      it 'returns applied=false, reason=:lock_ref_not_found when lock_ref does not match' do
        seed = build_token_seed(payer_did: payer_did, lock_ref: 'nonexistent-lock-ref')
        result = seed.apply_to_recipient_balance!(origin_platform: nil)
        expect(result.applied).to be false
        expect(result.reason).to eq(:lock_ref_not_found)
      end

      it 'returns applied=true for a valid locked settlement' do
        ref = lock_ref
        seed = build_token_seed(
          payer_did: payer_did,
          lock_ref: ref,
          c3_millitokens: 1_000,
          source_ref: "settlement-#{SecureRandom.hex(8)}",
          source_system: 'borgberry'
        )
        result = seed.apply_to_recipient_balance!(origin_platform: nil)
        expect(result.applied).to be true
        expect(result.reason).to be_nil
      end

      it 'credits earner and debits payer locked balance on settlement' do
        ref = lock_ref
        seed = build_token_seed(
          payer_did: payer_did,
          lock_ref: ref,
          c3_millitokens: 1_000,
          source_ref: "settlement-#{SecureRandom.hex(8)}",
          source_system: 'borgberry'
        )
        seed.apply_to_recipient_balance!(origin_platform: nil)

        earner_balance = BetterTogether::C3::Balance.find_by(holder: earner, community: nil)
        expect(earner_balance).to be_present
        expect(earner_balance.available_millitokens).to be >= 1_000

        payer_balance.reload
        expect(payer_balance.locked_millitokens).to eq(0)
      end
    end
  end
end

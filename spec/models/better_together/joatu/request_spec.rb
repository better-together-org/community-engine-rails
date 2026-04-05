# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::Request do
  subject(:request_model) { build(:better_together_joatu_request) }

  it_behaves_like 'an indexed searchable model', :better_together_joatu_request

  describe 'Factory' do
    it 'has a valid factory' do
      expect(request_model).to be_valid
    end

    describe 'traits' do
      describe ':with_target' do
        subject(:request_with_target) { build(:better_together_joatu_request, :with_target) }

        it 'creates a request with a target person' do
          expect(request_with_target.target).to be_present
          expect(request_with_target.target).to be_a(BetterTogether::Person)
        end

        it 'is valid' do
          expect(request_with_target).to be_valid
        end
      end

      describe ':with_target_type' do
        subject(:request_with_type) { build(:better_together_joatu_request, :with_target_type) }

        it 'sets the target_type attribute' do
          expect(request_with_type.target_type).to eq('BetterTogether::Invitation')
        end

        it 'is valid' do
          expect(request_with_type).to be_valid
        end
      end

      describe 'combined traits' do
        it 'with_target and with_target_type are mutually exclusive' do
          # When both traits are used, :with_target_type overwrites target_type
          # but doesn't set target, so they should not be combined
          request_with_target = build(:better_together_joatu_request, :with_target)
          request_with_type = build(:better_together_joatu_request, :with_target_type)

          expect(request_with_target.target).to be_present
          expect(request_with_type.target_type).to eq('BetterTogether::Invitation')
        end
      end
    end
  end

  it 'is invalid without a creator' do
    request_model.creator = nil
    expect(request_model).not_to be_valid
  end

  it 'is invalid without target_type when target_id is set' do # rubocop:todo RSpec/NoExpectationExample
    request_model.target_id = SecureRandom.uuid
    request_model.target_type = nil
  end

  it 'is invalid without categories' do
    request_model.categories = []
    expect(request_model).not_to be_valid
  end

  it 'records creator contribution as an exchange initiator' do
    request_record = create(:better_together_joatu_request)

    expect(request_record.contributions.count).to eq(1)
    expect(request_record.contributions.first.role).to eq('exchange_initiator')
    expect(request_record.contributions.first.contribution_type).to eq('community_exchange')
    expect(request_record.contributors_for(:exchange_initiator)).to contain_exactly(request_record.creator)
  end

  it 'supports citations and claims on the exchange record' do
    request_record = create(:better_together_joatu_request)
    citation = create(:better_together_citation, citeable: request_record, reference_key: 'request_source')
    claim = create(:better_together_claim, claimable: request_record, claim_key: 'request_claim')
    create(:better_together_evidence_link, claim:, citation:)

    expect(request_record.citations).to contain_exactly(citation)
    expect(request_record.claims).to contain_exactly(claim)
    expect(claim.citations).to contain_exactly(citation)
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::Offer do
  subject(:offer) { build(:better_together_joatu_offer) }

  it_behaves_like 'an indexed searchable model', :better_together_joatu_offer

  describe 'Factory' do
    it 'has a valid factory' do
      expect(offer).to be_valid
    end

    describe 'traits' do
      describe ':with_target' do
        subject(:offer_with_target) { build(:better_together_joatu_offer, :with_target) }

        it 'creates an offer with a target person' do
          expect(offer_with_target.target).to be_present
          expect(offer_with_target.target).to be_a(BetterTogether::Person)
        end

        it 'is valid' do
          expect(offer_with_target).to be_valid
        end
      end

      describe ':with_target_type' do
        subject(:offer_with_type) { build(:better_together_joatu_offer, :with_target_type) }

        it 'sets the target_type attribute' do
          expect(offer_with_type.target_type).to eq('BetterTogether::Invitation')
        end

        it 'is valid' do
          expect(offer_with_type).to be_valid
        end
      end

      describe 'combined traits' do
        it 'with_target and with_target_type are mutually exclusive' do
          # When both traits are used, :with_target_type overwrites target_type
          # but doesn't set target, so they should not be combined
          offer_with_target = build(:better_together_joatu_offer, :with_target)
          offer_with_type = build(:better_together_joatu_offer, :with_target_type)

          expect(offer_with_target.target).to be_present
          expect(offer_with_type.target_type).to eq('BetterTogether::Invitation')
        end
      end
    end
  end

  it 'is invalid without a creator' do
    offer.creator = nil
    expect(offer).not_to be_valid
  end

  it 'is invalid without target_type when target_id is set' do # rubocop:todo RSpec/NoExpectationExample
    offer.target_id = SecureRandom.uuid
    offer.target_type = nil
  end

  describe 'translations validation side-effects' do
    it 'does not instantiate blank string translations for other locales when assigning name_en and validating' do
      prev_locales = I18n.available_locales

      begin
        offer = build(:better_together_joatu_offer)

        # Assign only the English translation
        offer.name_en = 'hello world'

        # Validate; should not spawn other-locale translations as a side effect
        offer.valid?
        other_locale_translations = offer.string_translations.select do |t|
          %w[name slug].include?(t.key) && t.locale != 'en'
        end
        expect(other_locale_translations).to be_empty

        # Ensure we did set the English name translation in-memory
        en_name = offer.string_translations.detect { |t| t.key == 'name' && t.locale == 'en' }
        expect(en_name&.value).to eq('hello world')
      ensure
        I18n.available_locales = prev_locales
      end
    end
  end

  it 'is invalid without categories' do
    offer.categories = []
    expect(offer).not_to be_valid
  end

  it 'records creator contribution as an exchange initiator' do
    offer_record = create(:better_together_joatu_offer)

    expect(offer_record.contributions.count).to eq(1)
    expect(offer_record.contributions.first.role).to eq('exchange_initiator')
    expect(offer_record.contributions.first.contribution_type).to eq('community_exchange')
    expect(offer_record.contributors_for(:exchange_initiator)).to contain_exactly(offer_record.creator)
  end

  it 'supports citations and claims on the exchange record' do
    offer_record = create(:better_together_joatu_offer)
    citation = create(:better_together_citation, citeable: offer_record, reference_key: 'offer_source')
    claim = create(:better_together_claim, claimable: offer_record, claim_key: 'offer_claim')
    create(:better_together_evidence_link, claim:, citation:)

    expect(offer_record.citations).to contain_exactly(citation)
    expect(offer_record.claims).to contain_exactly(claim)
    expect(claim.citations).to contain_exactly(citation)
  end
end

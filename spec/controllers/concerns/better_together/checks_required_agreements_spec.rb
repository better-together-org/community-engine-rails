# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe ChecksRequiredAgreements do
    let!(:privacy_policy) { BetterTogether::Agreement.find_or_create_by!(identifier: 'privacy_policy') { |a| a.slug = 'privacy-policy' } }
    let!(:terms_of_service) { BetterTogether::Agreement.find_or_create_by!(identifier: 'terms_of_service') { |a| a.slug = 'terms-of-service' } }
    let!(:code_of_conduct) { BetterTogether::Agreement.find_or_create_by!(identifier: 'code_of_conduct') { |a| a.slug = 'code-of-conduct' } }

    describe '.unaccepted_required_agreements' do
      let(:person) { create(:person) }

      context 'when no agreements have been accepted' do
        it 'returns all required agreements' do
          result = described_class.unaccepted_required_agreements(person)
          expect(result.pluck(:identifier)).to match_array(%w[privacy_policy terms_of_service code_of_conduct])
        end
      end

      context 'when some agreements have been accepted' do
        before do
          create(:better_together_agreement_participant, person: person, agreement: privacy_policy, accepted_at: Time.current)
        end

        it 'returns only unaccepted required agreements' do
          result = described_class.unaccepted_required_agreements(person)
          expect(result.pluck(:identifier)).to match_array(%w[terms_of_service code_of_conduct])
        end
      end

      context 'when all required agreements have been accepted' do
        before do
          create(:better_together_agreement_participant, person: person, agreement: privacy_policy, accepted_at: Time.current)
          create(:better_together_agreement_participant, person: person, agreement: terms_of_service, accepted_at: Time.current)
          create(:better_together_agreement_participant, person: person, agreement: code_of_conduct, accepted_at: Time.current)
        end

        it 'returns empty relation' do
          result = described_class.unaccepted_required_agreements(person)
          expect(result).to be_empty
        end
      end
    end

    describe '.person_has_unaccepted_required_agreements?' do
      context 'when person has unaccepted required agreements' do
        let(:person) { create(:person) }

        it 'returns true' do
          expect(described_class.person_has_unaccepted_required_agreements?(person)).to be true
        end
      end

      context 'when person has accepted all required agreements' do
        let(:person_with_agreements) do
          p = create(:person)
          create(:better_together_agreement_participant, person: p, agreement: privacy_policy, accepted_at: Time.current)
          create(:better_together_agreement_participant, person: p, agreement: terms_of_service, accepted_at: Time.current)
          create(:better_together_agreement_participant, person: p, agreement: code_of_conduct, accepted_at: Time.current)
          p
        end

        it 'returns false' do
          expect(described_class.person_has_unaccepted_required_agreements?(person_with_agreements)).to be false
        end
      end
    end
  end
end

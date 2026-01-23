# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe Person do
    subject(:person) { build(:person) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(person).to be_valid
      end
    end

    it_behaves_like 'a friendly slugged record'
    it_behaves_like 'an identity'
    it_behaves_like 'has_id'
    it_behaves_like 'an author model'
    it_behaves_like 'a seedable model'

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:name) }
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:identifier) }
      it { is_expected.to respond_to(:name) }
      it { is_expected.to respond_to(:description) }
      # Test other attributes
    end

    describe 'Methods' do
      it { is_expected.to respond_to(:to_s) }
      # Add checks for any other instance methods
    end

    describe '#to_s' do
      it 'returns the name as a string representation' do
        expect(person.to_s).to eq(person.name)
      end
    end

    describe '#unaccepted_required_agreements' do
      let(:person) { create(:person) }

      it 'delegates to ChecksRequiredAgreements.unaccepted_required_agreements' do
        expect(BetterTogether::ChecksRequiredAgreements)
          .to receive(:unaccepted_required_agreements).with(person)
        person.unaccepted_required_agreements
      end

      context 'when no agreements have been accepted' do
        let!(:privacy_policy) { BetterTogether::Agreement.find_or_create_by!(identifier: 'privacy_policy') { |a| a.title = 'Privacy Policy' } }
        let!(:terms_of_service) { BetterTogether::Agreement.find_or_create_by!(identifier: 'terms_of_service') { |a| a.title = 'Terms of Service' } }
        let!(:code_of_conduct) { BetterTogether::Agreement.find_or_create_by!(identifier: 'code_of_conduct') { |a| a.title = 'Code of Conduct' } }
        let!(:optional_agreement) { create(:agreement, identifier: "community_guidelines_#{SecureRandom.hex(4)}") }

        it 'returns all required agreements' do
          unaccepted = person.unaccepted_required_agreements

          expect(unaccepted).to include(privacy_policy, terms_of_service, code_of_conduct)
          expect(unaccepted).not_to include(optional_agreement)
        end

        it 'returns exactly 3 agreements when code_of_conduct exists' do
          expect(person.unaccepted_required_agreements.count).to eq(3)
        end
      end

      context 'when some agreements have been accepted' do
        let!(:privacy_policy) { BetterTogether::Agreement.find_or_create_by!(identifier: 'privacy_policy') { |a| a.title = 'Privacy Policy' } }
        let!(:terms_of_service) { BetterTogether::Agreement.find_or_create_by!(identifier: 'terms_of_service') { |a| a.title = 'Terms of Service' } }
        let!(:code_of_conduct) { BetterTogether::Agreement.find_or_create_by!(identifier: 'code_of_conduct') { |a| a.title = 'Code of Conduct' } }

        before do
          create(:better_together_agreement_participant, person: person, agreement: privacy_policy, accepted_at: Time.current)
        end

        it 'returns only unaccepted required agreements' do
          unaccepted = person.unaccepted_required_agreements

          expect(unaccepted).to include(terms_of_service, code_of_conduct)
          expect(unaccepted).not_to include(privacy_policy)
        end

        it 'returns 2 agreements when one is accepted' do
          expect(person.unaccepted_required_agreements.count).to eq(2)
        end
      end

      context 'when all required agreements have been accepted' do
        let!(:privacy_policy) { BetterTogether::Agreement.find_or_create_by!(identifier: 'privacy_policy') { |a| a.title = 'Privacy Policy' } }
        let!(:terms_of_service) { BetterTogether::Agreement.find_or_create_by!(identifier: 'terms_of_service') { |a| a.title = 'Terms of Service' } }
        let!(:code_of_conduct) { BetterTogether::Agreement.find_or_create_by!(identifier: 'code_of_conduct') { |a| a.title = 'Code of Conduct' } }

        before do
          [privacy_policy, terms_of_service, code_of_conduct].each do |agreement|
            create(:better_together_agreement_participant, person: person, agreement: agreement, accepted_at: Time.current)
          end
        end

        it 'returns an empty relation' do
          expect(person.unaccepted_required_agreements).to be_empty
        end
      end

      context 'when code_of_conduct does not exist' do
        let!(:privacy_policy) { BetterTogether::Agreement.find_or_create_by!(identifier: 'privacy_policy') { |a| a.title = 'Privacy Policy' } }
        let!(:terms_of_service) { BetterTogether::Agreement.find_or_create_by!(identifier: 'terms_of_service') { |a| a.title = 'Terms of Service' } }

        before do
          # Ensure code_of_conduct doesn't exist for this test
          BetterTogether::Agreement.where(identifier: 'code_of_conduct').delete_all
        end

        it 'returns only privacy_policy and terms_of_service' do
          unaccepted = person.unaccepted_required_agreements

          expect(unaccepted).to include(privacy_policy, terms_of_service)
          expect(unaccepted.count).to eq(2)
        end
      end
    end

    describe '#unaccepted_required_agreements?' do
      let(:person) { create(:person) }

      before do
        # Clear any agreement participants for this person from previous tests
        person.agreement_participants.destroy_all
      end

      it 'delegates to ChecksRequiredAgreements.person_has_unaccepted_required_agreements?' do
        expect(BetterTogether::ChecksRequiredAgreements)
          .to receive(:person_has_unaccepted_required_agreements?).with(person)
        person.unaccepted_required_agreements?
      end

      context 'when person has unaccepted required agreements' do
        let!(:privacy_policy) { BetterTogether::Agreement.find_or_create_by!(identifier: 'privacy_policy') { |a| a.title = 'Privacy Policy' } }
        let!(:terms_of_service) { BetterTogether::Agreement.find_or_create_by!(identifier: 'terms_of_service') { |a| a.title = 'Terms of Service' } }

        it 'returns true' do
          expect(person.unaccepted_required_agreements?).to be true
        end
      end

      context 'when person has accepted all required agreements' do
        let!(:privacy_policy) { BetterTogether::Agreement.find_or_create_by!(identifier: 'privacy_policy') { |a| a.title = 'Privacy Policy' } }
        let!(:terms_of_service) { BetterTogether::Agreement.find_or_create_by!(identifier: 'terms_of_service') { |a| a.title = 'Terms of Service' } }

        before do
          # Reload person to ensure we have current association state
          person.reload

          # Create participants for the two agreements we explicitly create
          [privacy_policy, terms_of_service].each do |agreement|
            create(:better_together_agreement_participant, person: person, agreement: agreement, accepted_at: Time.current)
          end

          # If code_of_conduct exists (from seeds), create a participant for it too
          code_of_conduct = BetterTogether::Agreement.find_by(identifier: 'code_of_conduct')
          if code_of_conduct
            create(:better_together_agreement_participant, person: person, agreement: code_of_conduct, accepted_at: Time.current)
          end

          # Reload person again to ensure associations are current
          person.reload
        end

        it 'returns false' do
          expect(person.unaccepted_required_agreements?).to be false
        end
      end
    end

    # Additional method tests
    # Example:
    # describe '#method_name' do
    #   it 'performs expected behavior' do
    #     # Test custom method behavior
    #   end
    # end
  end
end

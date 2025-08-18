# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe AgreementTerm, type: :model do
    subject(:agreement_term) { build(:agreement_term) }

    describe 'factory' do
      it 'is valid' do
        expect(agreement_term).to be_valid
      end
    end

    describe 'associations' do
      it { is_expected.to belong_to(:agreement).class_name('BetterTogether::Agreement') }
    end

    describe 'validations' do
      it 'requires a unique identifier' do
        create(:agreement_term, identifier: 'dup-id')
        duplicate = build(:agreement_term, identifier: 'dup-id')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:identifier]).to include('has already been taken')
      end

      it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }
      it { is_expected.to validate_inclusion_of(:protected).in_array([true, false]) }
    end

    describe 'callbacks' do
      it 'assigns sequential positions within an agreement' do
        agreement = create(:agreement)
        first_term = create(:agreement_term, agreement:)
        second_term = create(:agreement_term, agreement:)
        expect(second_term.position).to eq(first_term.position + 1)
      end
    end

    describe 'protected records' do
      it 'cannot be destroyed when protected' do
        term = create(:agreement_term, protected: true)
        expect(term.destroy).to be_falsey
        expect(term.errors[:base]).to include('This record is protected and cannot be destroyed.')
      end
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Agreement, type: :model do # rubocop:todo Metrics/BlockLength
    subject(:agreement) { build(:agreement) }

    describe 'factory' do
      it 'is valid' do
        expect(agreement).to be_valid
      end
    end

    describe 'associations' do
      it { is_expected.to have_many(:agreement_terms).class_name('BetterTogether::AgreementTerm') }
      it { is_expected.to belong_to(:creator).class_name('BetterTogether::Person').optional }
    end

    describe 'validations' do
      it 'requires a unique identifier' do
        create(:agreement, identifier: 'dup-id')
        duplicate = build(:agreement, identifier: 'dup-id')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:identifier]).to include('has already been taken')
      end

      it 'requires a valid privacy value' do
        expect { build(:agreement, privacy: 'invalid') }.to raise_error(ArgumentError)
      end

      it { is_expected.to validate_inclusion_of(:protected).in_array([true, false]) }
    end

    describe 'callbacks' do
      it 'generates a slug from the title' do
        agreement = build(:agreement, title: 'My Title', slug: nil)
        agreement.save!
        expect(agreement.slug).to eq('my-title')
      end
    end

    describe 'protected records' do
      it 'cannot be destroyed when protected' do
        agreement = create(:agreement, protected: true)
        expect(agreement.destroy).to be_falsey
        expect(agreement.errors[:base]).to include('This record is protected and cannot be destroyed.')
      end
    end
  end
end

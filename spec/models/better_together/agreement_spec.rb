# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Agreement do
  subject(:agreement) { build(:agreement) }

  describe 'factory' do
    it 'is valid' do
      expect(agreement).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:agreement_terms).class_name('BetterTogether::AgreementTerm') }
    it { is_expected.to belong_to(:creator).class_name('BetterTogether::Person').optional }
    it { is_expected.to have_many(:citations).dependent(:destroy) }
    it { is_expected.to have_many(:claims).dependent(:destroy) }
  end

  describe 'validations' do
    it 'requires a unique identifier' do
      # Use unique identifier to avoid pollution from parallel workers
      unique_id = "dup-id-#{SecureRandom.hex(4)}"
      create(:agreement, identifier: unique_id)
      duplicate = build(:agreement, identifier: unique_id)
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
      agreement = build(:agreement, title: "My Title #{SecureRandom.hex(4)}", slug: nil)
      agreement.save!
      expect(agreement.slug).to start_with('my-title')
    end
  end

  describe 'protected records' do
    it 'cannot be destroyed when protected' do
      agreement = create(:agreement, protected: true)
      expect(agreement.destroy).to be_falsey
      expect(agreement.errors[:base]).to include('This record is protected and cannot be destroyed.')
    end
  end

  describe 'evidence selector options' do
    it 'includes the description rich text selector' do
      expect(agreement.evidence_selector_options).to include(
        include(value: 'rich_text:description', label: 'Description rich text')
      )
    end
  end
end

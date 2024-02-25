# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Person, type: :model do # rubocop:todo Metrics/BlockLength
    subject(:person) { build(:person) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(person).to be_valid
      end
    end

    it_behaves_like 'a friendly slugged record'
    it_behaves_like 'an identity'
    it_behaves_like 'has_id'
    # it_behaves_like 'an author model'

    describe 'ActiveRecord associations' do
      # Add associations tests here
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:name) }
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:name) }
      it { is_expected.to respond_to(:description) }
      it { is_expected.to respond_to(:slug) }
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

    # Additional method tests
    # Example:
    # describe '#method_name' do
    #   it 'performs expected behavior' do
    #     # Test custom method behavior
    #   end
    # end
  end
end

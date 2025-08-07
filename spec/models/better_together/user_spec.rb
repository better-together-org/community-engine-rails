# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe User, type: :model do # rubocop:todo Metrics/BlockLength
    subject(:user) { build(:user) }
    let(:existing_user) { create(:user) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(user).to be_valid
      end
    end

    describe 'ActiveRecord associations' do
      it {
        is_expected.to have_one(:person_identification).conditions(identity_type: 'BetterTogether::Person',
                                                                   active: true)
      }
      it { is_expected.to have_one(:person).through(:person_identification) }
      it { is_expected.to accept_nested_attributes_for(:person) }
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:email) }
      it { is_expected.to validate_presence_of(:password) }
      it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:email) }
      it { is_expected.to respond_to(:encrypted_password) }
      it { is_expected.to respond_to(:slug) }
      # Test other attributes
    end

    describe 'Methods' do # rubocop:todo Metrics/BlockLength
      it { is_expected.to respond_to(:build_person) }
      it { is_expected.to respond_to(:person_attributes=) }

      describe '#build_person' do
        it 'builds a new person identification and person' do
          user.build_person
          # byebug
          expect(user.person).to be_a(BetterTogether::Person)
          expect(user.person_identification).to be_a(BetterTogether::Identification)
        end
      end

      describe '#person_attributes=' do
        let(:person_attributes) { attributes_for(:better_together_person) }

        context 'when person exists' do
          before do
            user.build_person(person_attributes)
            user.save
          end

          it 'updates the existing person' do
            # byebug
            new_attributes = { name: 'New Name' }
            user.person_attributes = new_attributes
            expect(user.person.name).to eq('New Name')
          end
        end

        context 'when person does not exist' do
          it 'builds a new person' do
            user.person_attributes = person_attributes
            expect(user.person).to be_present
          end
        end
      end
    end
  end
end

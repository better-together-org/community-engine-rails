# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe User do
    subject(:user) { build(:user) }
    let(:existing_user) { create(:user) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(user).to be_valid
      end

      describe 'traits' do
        describe ':confirmed' do
          subject(:confirmed_user) { create(:user, :confirmed) }

          it 'creates a confirmed user' do
            expect(confirmed_user.confirmed_at).to be_present
            expect(confirmed_user.confirmation_sent_at).to be_present
            expect(confirmed_user.confirmation_token).to be_present
            expect(confirmed_user).to be_confirmed
          end
        end

        describe ':oauth_user' do
          subject(:oauth_user) { create(:user, :oauth_user) }

          it 'creates an OauthUser with correct type' do
            expect(oauth_user.type).to eq('BetterTogether::OauthUser')
          end

          it 'has a random password' do
            expect(oauth_user.encrypted_password).to be_present
          end
        end

        describe ':platform_manager' do
          subject(:manager) { create(:user, :platform_manager) }

          it 'creates a user with platform manager role' do
            expect(manager.person).to be_present
            platform = BetterTogether::Platform.find_by(host: true)
            expect(platform).to be_present

            membership = platform.person_platform_memberships.find_by(member: manager.person)
            expect(membership).to be_present
            expect(membership.role.identifier).to eq('platform_manager')
          end

          it 'has manage_platform permission' do
            expect(manager.person.permitted_to?('manage_platform')).to be true
          end
        end

        describe 'combined traits' do
          it 'works with :confirmed and :platform_manager' do
            user = create(:user, :confirmed, :platform_manager)
            expect(user).to be_confirmed
            expect(user.person.permitted_to?('manage_platform')).to be true
          end
        end
      end
    end

    describe 'ActiveRecord associations' do
      it {
        # rubocop:todo RSpec/NamedSubject
        expect(subject).to have_one(:person_identification).conditions(identity_type: 'BetterTogether::Person',
                                                                       # rubocop:enable RSpec/NamedSubject
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

    describe 'Methods' do
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

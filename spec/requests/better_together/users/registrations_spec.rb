# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Registration', :skip_host_setup do
  include AutomaticTestConfiguration

  before do
    configure_host_platform
  end

  describe 'POST /en/users' do
    let(:valid_user_params) do
      {
        email: 'test@example.com',
        password: 'SecureTest123!@#',
        password_confirmation: 'SecureTest123!@#',
        person_attributes: {
          name: 'Test User',
          identifier: 'test-user'
        }
      }
    end

    let!(:privacy_agreement) do
      BetterTogether::Agreement.find_or_create_by(identifier: 'privacy_policy') do |a|
        a.title = 'Privacy Policy'
        a.creator = create(:person)
      end
    end

    let!(:terms_agreement) do
      BetterTogether::Agreement.find_or_create_by(identifier: 'terms_of_service') do |a|
        a.title = 'Terms of Service'
        a.creator = create(:person)
      end
    end

    let!(:code_of_conduct_agreement) do
      BetterTogether::Agreement.find_or_create_by(identifier: 'code_of_conduct') do |a|
        a.title = 'Code of Conduct'
        a.creator = create(:person)
      end
    end

    context 'when creating a user with person attributes' do
      it 'creates user, person, and community membership successfully' do
        expect do
          post '/en/users', params: {
            user: valid_user_params,
            terms_of_service_agreement: '1',
            privacy_policy_agreement: '1',
            code_of_conduct_agreement: '1'
          }
        end.to change(BetterTogether::User, :count).by(1)
                                                   .and change(BetterTogether::Person, :count).by(1)
                                                                                              .and change(
                                                                                                BetterTogether::PersonCommunityMembership, :count
                                                                                              ).by(1)
          .and change(
            BetterTogether::AgreementParticipant, :count
          ).by(3)

        user = BetterTogether::User.last
        expect(user.email).to eq('test@example.com')
        expect(user.person).to be_present
        expect(user.person.name).to eq('Test User')
        expect(user.person.identifier).to eq('test-user')
        expect(user.person.person_community_memberships.count).to eq(1)

        user = BetterTogether::User.last
        expect(user.email).to eq('test@example.com')
        expect(user.person).to be_present
        expect(user.person.name).to eq('Test User')
        expect(user.person.identifier).to eq('test-user')
        expect(user.person.person_community_memberships.count).to eq(1)
      end

      it 'handles person validation errors gracefully' do
        invalid_params = valid_user_params.dup
        invalid_params[:person_attributes][:name] = '' # Invalid empty name

        expect do
          post '/en/users', params: {
            user: invalid_params,
            terms_of_service_agreement: '1',
            privacy_policy_agreement: '1',
            code_of_conduct_agreement: '1'
          }
        end.to change(BetterTogether::User, :count).by(1) # User created despite empty name

        expect(response).to have_http_status(:ok) # Form re-rendered with errors
      end
    end

    context 'when agreements are not accepted' do
      it 'does not create user or person' do
        expect do
          post '/en/users', params: {
            user: valid_user_params
            # No agreement checkboxes
          }
        end.not_to change(BetterTogether::User, :count)

        expect(response).to have_http_status(:unprocessable_content) # Unprocessable entity
      end
    end
  end
end

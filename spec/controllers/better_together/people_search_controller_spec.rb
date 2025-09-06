# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe PeopleSearchController, type: :controller do
    routes { BetterTogether::Engine.routes }

    let(:community) { create(:better_together_community) }
    let(:user) { create(:better_together_user) }
    let(:person) { user.person }

    before do
      # Set up user with community membership
      community.person_community_memberships.create!(
        member: person,
        role: create(:better_together_role, identifier: 'community_member')
      )
      sign_in user
    end

    describe 'GET #index' do
      let!(:searchable_person) { create(:better_together_person, name: 'John Doe', identifier: 'johndoe') }
      let!(:other_person) { create(:better_together_person, name: 'Jane Smith', identifier: 'janesmith') }

      before do
        # Add searchable people to the same community
        community.person_community_memberships.create!(
          member: searchable_person,
          role: create(:better_together_role, identifier: 'community_member')
        )
        community.person_community_memberships.create!(
          member: other_person,
          role: create(:better_together_role, identifier: 'community_member')
        )
      end

      context 'with valid search query' do
        it 'returns matching people' do
          get :index, params: { q: 'John' }, format: :json

          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)

          expect(json_response).to be_an(Array)
          expect(json_response.length).to eq(1)
          expect(json_response.first['name']).to eq('John Doe')
          expect(json_response.first['identifier']).to eq('johndoe')
        end

        it 'searches by identifier' do
          get :index, params: { q: 'jane' }, format: :json

          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)

          expect(json_response.length).to eq(1)
          expect(json_response.first['name']).to eq('Jane Smith')
        end
      end

      context 'with short query' do
        it 'returns empty results for queries less than 2 characters' do
          get :index, params: { q: 'J' }, format: :json

          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          expect(json_response).to be_empty
        end
      end

      context 'without authentication' do
        before { sign_out user }

        it 'returns unauthorized' do
          get :index, params: { q: 'John' }, format: :json
          expect(response).to have_http_status(:redirect)
        end
      end

      context 'with HTML format' do
        it 'redirects to root' do
          get :index, params: { q: 'John' }
          expect(response).to redirect_to(root_path)
        end
      end
    end
  end
end

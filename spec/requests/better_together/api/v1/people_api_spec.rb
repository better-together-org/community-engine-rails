# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::People', type: :request do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { sign_in_and_get_token(user) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/vnd.api+json' } }

  describe 'GET /api/v1/people' do
    let(:url) { '/en/api/v1/people' }
    let!(:public_person) { create(:better_together_person, privacy: 'public') }
    let!(:private_person) { create(:better_together_person, privacy: 'private') }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted data' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)
        expect(json['data'].first).to include('type' => 'people')
      end

      it 'includes public people in results' do
        json = JSON.parse(response.body)
        person_ids = json['data'].map { |p| p['id'] }

        expect(person_ids).to include(public_person.id)
      end

      it 'excludes private people from results' do
        json = JSON.parse(response.body)
        person_ids = json['data'].map { |p| p['id'] }

        expect(person_ids).not_to include(private_person.id)
      end

      it 'includes own profile in results' do
        json = JSON.parse(response.body)
        person_ids = json['data'].map { |p| p['id'] }

        expect(person_ids).to include(person.id)
      end

      it 'does not expose sensitive attributes' do
        json = JSON.parse(response.body)

        json['data'].each do |person_data|
          expect(person_data['attributes']).not_to have_key('password')
          expect(person_data['attributes']).not_to have_key('encrypted_password')
        end
      end
    end

    context 'when not authenticated' do
      before { get url, headers: { 'Content-Type' => 'application/vnd.api+json' } }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'only includes public people' do
        json = JSON.parse(response.body)
        person_ids = json['data'].map { |p| p['id'] }

        expect(person_ids).to include(public_person.id)
        expect(person_ids).not_to include(private_person.id)
      end
    end
  end

  describe 'GET /api/v1/people/:id' do
    let(:url) { "/en/api/v1/people/#{public_person.id}" }
    let(:public_person) { create(:better_together_person, privacy: 'public') }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted person data' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to include(
          'type' => 'people',
          'id' => public_person.id
        )
      end

      it 'includes person attributes' do
        json = JSON.parse(response.body)

        expect(json['data']['attributes']).to include(
          'name' => public_person.name,
          'privacy' => 'public'
        )
      end
    end

    context 'when viewing private person without permission' do
      let(:private_person) { create(:better_together_person, privacy: 'private') }
      let(:url) { "/en/api/v1/people/#{private_person.id}" }

      before { get url, headers: auth_headers }

      it 'returns forbidden status' do
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when viewing own profile' do
      let(:url) { "/en/api/v1/people/#{person.id}" }

      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'includes all person attributes' do
        json = JSON.parse(response.body)

        expect(json['data']['attributes']).to include(
          'name' => person.name,
          'email' => person.email
        )
      end
    end
  end

  describe 'GET /api/v1/people/me' do
    let(:url) { '/en/api/v1/people/me' }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns current user\'s person data' do
        json = JSON.parse(response.body)

        expect(json['data']['id']).to eq(person.id)
        expect(json['data']['attributes']).to include('name' => person.name)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: { 'Content-Type' => 'application/vnd.api+json' } }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/people' do
    let(:url) { '/en/api/v1/people' }
    let(:valid_params) do
      {
        data: {
          type: 'people',
          attributes: {
            name: 'New Person',
            privacy: 'public'
          }
        }
      }
    end

    context 'when authenticated with permission' do
      before do
        # Grant permission to create people
        allow_any_instance_of(BetterTogether::PersonPolicy).to receive(:create?).and_return(true)
        post url, params: valid_params.to_json, headers: auth_headers
      end

      it 'creates a new person' do
        expect(response).to have_http_status(:created)
      end

      it 'returns JSONAPI-formatted person data' do
        json = JSON.parse(response.body)

        expect(json['data']['type']).to eq('people')
        expect(json['data']['attributes']).to include('name' => 'New Person')
      end
    end

    context 'when not authenticated' do
      before { post url, params: valid_params.to_json, headers: { 'Content-Type' => 'application/vnd.api+json' } }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/people/:id' do
    let(:url) { "/en/api/v1/people/#{person.id}" }
    let(:update_params) do
      {
        data: {
          type: 'people',
          id: person.id,
          attributes: {
            name: 'Updated Name'
          }
        }
      }
    end

    context 'when updating own profile' do
      before { patch url, params: update_params.to_json, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'updates the person' do
        expect(person.reload.name).to eq('Updated Name')
      end
    end

    context 'when updating another person without permission' do
      let(:other_person) { create(:better_together_person) }
      let(:url) { "/en/api/v1/people/#{other_person.id}" }

      before do
        update_params[:data][:id] = other_person.id
        patch url, params: update_params.to_json, headers: auth_headers
      end

      it 'returns forbidden status' do
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /api/v1/people/:id' do
    let(:url) { "/en/api/v1/people/#{person.id}" }

    context 'when not authorized' do
      before { delete url, headers: auth_headers }

      it 'returns forbidden status' do
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  def sign_in_and_get_token(user)
    post '/api/auth/sign-in', params: {
      user: {
        email: user.email,
        password: 'Password123!'
      }
    }, as: :json

    response.headers['Authorization'].sub('Bearer ', '')
  end
end

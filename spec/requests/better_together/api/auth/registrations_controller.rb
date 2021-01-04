
require 'rails_helper'

describe BetterTogether::RegistrationsController, type: :request do

  let(:user) { build(:user) }
  let (:existing_user) { create(:user, :confirmed) }
  let (:signup_url) { better_together.user_registration_path }

  context 'When creating a new user' do
    before do
      post signup_url, params: {
        user: {
          email: user.email,
          password: user.password
        }
      }
    end

    it 'returns 200' do
      expect(response.status).to eq(201)
    end

    it 'returns a token' do
      expect(response.headers['Authorization']).to be_present
    end

    it 'returns the user email' do
      expect(json["email"]).to eq(user.email)
    end
  end

  context 'When an email already exists' do
    before do
      post signup_url, params: {
        user: {
          email: existing_user.email,
          password: existing_user.password
        }
      }
    end

    it 'returns 422' do
      expect(response.status).to eq(422)
    end
  end

end

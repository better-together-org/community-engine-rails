# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::SeedsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:platform_manager) { BetterTogether::User.find_by(email: 'manager@example.test') }
  let(:regular_user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let!(:seed) { create(:better_together_seed, identifier: 'managed-seed') }

  def create_params(origin:, payload:)
    {
      seed: {
        identifier: 'new-managed-seed',
        type: 'BetterTogether::Seed',
        version: '1.0',
        created_by: platform_manager.person.id,
        seeded_at: Time.current.iso8601,
        description: 'Managed seed from request spec',
        privacy: 'private',
        origin:,
        payload:
      }
    }
  end

  describe 'GET /host/seeds' do
    it 'renders for platform managers' do
      get better_together.seeds_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(seed.identifier)
    end

    it 'returns not found for signed-in non-managers' do
      sign_in regular_user

      get better_together.seeds_path(locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /host/seeds/:id' do
    it 'renders for platform managers' do
      get better_together.seed_path(seed.id, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(seed.identifier)
    end

    it 'returns not found for signed-in non-managers' do
      sign_in regular_user

      get better_together.seed_path(seed.id, locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /host/seeds/:id/edit' do
    it 'returns not found for signed-in non-managers' do
      sign_in regular_user

      get better_together.edit_seed_path(seed.id, locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /host/seeds' do
    it 'surfaces invalid origin JSON as an unprocessable form error' do
      expect do
        post better_together.seeds_path(locale:),
             params: create_params(origin: '{bad json', payload: '{"generic_data":{"name":"payload ok"}}')
      end.not_to change(BetterTogether::Seed, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t('seeds.errors.invalid_json'))
    end
  end

  describe 'PATCH /host/seeds/:id' do
    it 'surfaces invalid payload JSON as an unprocessable form error' do
      patch better_together.seed_path(seed.id, locale:),
            params: {
              seed: {
                identifier: seed.identifier,
                type: seed.type,
                version: seed.version,
                created_by: seed.created_by,
                seeded_at: seed.seeded_at.iso8601,
                description: seed.description,
                privacy: seed.privacy,
                origin: seed.origin.to_json,
                payload: '{bad json'
              }
            }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t('seeds.errors.invalid_json'))
      expect(seed.reload.payload).not_to eq('{bad json')
    end
  end
end

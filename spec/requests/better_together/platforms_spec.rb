# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Platforms', :no_auth do
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let(:network_admin) do
    create(:better_together_user, :confirmed, :network_admin, email: 'platforms-network-admin@example.test')
  end
  let(:regular_user) { find_or_create_test_user('platforms-regular-user@example.test', 'SecureTest123!@#', :user) }

  describe 'GET /host/platforms/new' do
    it 'renders the registration form for network admins' do
      sign_in network_admin

      get better_together.new_platform_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Register External Platform')
    end

    it 'denies the form to regular users' do
      sign_in regular_user

      get better_together.new_platform_path(locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /host/platforms' do
    let(:valid_params) do
      {
        platform: {
          name_en: "Peer Platform #{SecureRandom.hex(4)}",
          identifier: "peer-#{SecureRandom.hex(4)}",
          host_url: "https://peer-#{SecureRandom.hex(4)}.example.com",
          time_zone: 'America/New_York',
          external: true
        }
      }
    end

    it 'creates an external platform as network admin' do
      sign_in network_admin

      expect do
        post better_together.platforms_path(locale:), params: valid_params
      end.to change(BetterTogether::Platform, :count).by(1)

      expect(response).to have_http_status(:see_other)
      platform = BetterTogether::Platform.last
      expect(platform.external).to be true
    end

    it 'denies creation to regular users' do
      sign_in regular_user

      expect do
        post better_together.platforms_path(locale:), params: valid_params
      end.not_to change(BetterTogether::Platform, :count)

      expect(response).to have_http_status(:not_found)
    end

    it 'renders new with errors on invalid params' do
      sign_in network_admin

      expect do
        post better_together.platforms_path(locale:),
             params: { platform: { identifier: '', host_url: 'not-a-url', time_zone: 'Invalid', external: true } }
      end.not_to change(BetterTogether::Platform, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end

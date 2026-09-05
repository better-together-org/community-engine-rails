# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Hub' do
  let(:locale) { I18n.default_locale }
  let(:user) { find_or_create_test_user('hub-user@example.test', 'SecureTest123!@#', :user) }

  before do
    configure_host_platform
    sign_in user
  end

  describe 'GET /hub' do
    it 'renders successfully for a signed-in user when activities resolve to an array' do
      get better_together.hub_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(assigns(:activities)).to be_an(Array)
    end
  end
end

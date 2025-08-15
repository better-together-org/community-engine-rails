# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::UsersController', type: :request do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('manager@example.test', 'password12345')
  end

  describe 'GET /:locale/.../host/users' do
    it 'renders index' do
      get better_together.users_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'renders show for the current user' do
      user = BetterTogether::User.find_by(email: 'manager@example.test')
      get better_together.user_path(locale:, id: user.id)
      expect(response).to have_http_status(:ok)
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::RolesController', type: :request do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('manager@example.test', 'password12345')
  end

  describe 'GET /:locale/.../host/roles' do
    it 'renders index' do
      get better_together.roles_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'renders show for a role' do
      role = create(:better_together_role)
      get better_together.role_path(locale:, id: role.slug)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /:locale/.../host/roles/:id' do
    it 'updates and redirects' do
      role = create(:better_together_role, protected: false)
      patch better_together.role_path(locale:, id: role.slug), params: {
        role: { name: 'New Name' }
      }
      expect(response).to have_http_status(:see_other)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end
end

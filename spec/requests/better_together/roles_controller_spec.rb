# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::RolesController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
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
    # rubocop:todo RSpec/MultipleExpectations
    it 'updates and redirects' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
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

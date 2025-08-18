# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::ResourcePermissionsController', type: :request do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('manager@example.test', 'password12345')
  end

  describe 'GET /:locale/.../host/permissions' do
    it 'renders index' do
      get better_together.resource_permissions_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'renders show for a permission' do
      permission = create(:better_together_resource_permission)
      get better_together.resource_permission_path(locale:, id: permission.slug)
      expect(response).to have_http_status(:ok)
    end
  end
end

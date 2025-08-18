# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::PlatformsController', type: :request do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('manager@example.test', 'password12345')
  end

  describe 'GET /:locale/.../host/platforms' do
    it 'renders index' do
      get better_together.platforms_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'renders show for host platform' do
      host_platform = BetterTogether::Platform.find_by(host: true)
      get better_together.platform_path(locale:, id: host_platform.slug)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /:locale/.../host/platforms/:id' do
    it 'updates settings and redirects' do
      host_platform = BetterTogether::Platform.find_by(host: true)
      patch better_together.platform_path(locale:, id: host_platform.slug), params: {
        platform: { url: host_platform.url, time_zone: host_platform.time_zone, requires_invitation: true }
      }
      expect(response).to have_http_status(:see_other)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end
end

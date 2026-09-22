# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonBlocksController, :as_user do
  include Devise::Test::ControllerHelpers
  include AutomaticTestConfiguration

  render_views
  routes { BetterTogether::Engine.routes }

  let(:locale) { I18n.default_locale }
  let(:user) { find_or_create_test_user('blocked-people-settings@example.test', 'SecureTest123!@#', :user) }

  before { sign_in user }

  describe 'GET #index in embedded settings mode' do
    before do
      request.headers['Turbo-Frame'] = 'blocked-people-settings'
    end

    it 'hides the duplicate frame heading while keeping the action button' do
      get :index, params: { locale: locale }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(%(<h2 class="h4 mb-0">#{I18n.t('better_together.person_blocks.index.title')}</h2>))
      expect(response.body).to include(I18n.t('better_together.person_blocks.index.block_person'))
    end
  end
end

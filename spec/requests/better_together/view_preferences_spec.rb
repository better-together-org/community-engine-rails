# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::ViewPreferencesController', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  describe 'POST /:locale/.../view_preferences' do
    it 'persists a valid view preference' do
      post better_together.view_preferences_path(locale:), params: {
        key: 'roles_index',
        view_type: 'table',
        allowed: %w[card table]
      }

      expect(response).to have_http_status(:found)
      expect(flash[:notice]).to eq(I18n.t('better_together.view_switcher.flash.updated'))
      expect(session.dig(:view_preferences, 'roles_index')).to eq('table')
    end

    it 'rejects an invalid view preference' do
      post better_together.view_preferences_path(locale:), params: {
        key: 'roles_index',
        view_type: 'calendar',
        allowed: %w[card table]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end

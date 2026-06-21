# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::ViewPreferencesController' do
  let(:locale) { I18n.default_locale }

  describe 'POST /:locale/.../view_preferences' do
    context 'when unauthenticated', :unauthenticated do
      it 'persists a valid view preference' do
        post better_together.view_preferences_path(locale:),
             params: { key: 'index_view', view_type: 'table', allowed: %w[card table] },
             headers: { 'HTTP_REFERER' => better_together.roles_path(locale:) }

        expect(response).to have_http_status(:see_other)
        expect(flash[:notice]).to eq(I18n.t('better_together.view_switcher.flash.updated'))
        expect(session.dig(:view_preferences, 'index_view')).to eq('table')
      end
    end

    context 'when authenticated', :as_platform_manager do
      it 'persists a valid view preference' do
        post better_together.view_preferences_path(locale:), params: {
          key: 'index_view',
          view_type: 'table',
          allowed: %w[card table]
        }

        expect(response).to have_http_status(:see_other)
        expect(flash[:notice]).to eq(I18n.t('better_together.view_switcher.flash.updated'))
        expect(session.dig(:view_preferences, 'index_view')).to eq('table')
      end

      it 'returns ok for valid json requests while persisting the preference' do
        post better_together.view_preferences_path(locale:), params: {
          key: 'index_view',
          view_type: 'table',
          allowed: %w[card table]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.body).to be_blank
        expect(session.dig(:view_preferences, 'index_view')).to eq('table')
      end

      it 'rejects a non-allowlisted key' do
        post better_together.view_preferences_path(locale:), params: {
          key: 'roles_index',
          view_type: 'table',
          allowed: %w[card table]
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(session[:view_preferences]).to be_nil
      end

      it 'drops non-allowlisted keys from the session' do
        session[:view_preferences] = { 'roles_index' => 'table', 'index_view' => 'card' }

        post better_together.view_preferences_path(locale:), params: {
          key: 'index_view',
          view_type: 'table',
          allowed: %w[card table]
        }

        expect(session[:view_preferences]).to eq('index_view' => 'table')
      end
    end
  end
end

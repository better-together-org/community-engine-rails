# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Host::TranslationManagementController' do
  let(:locale) { I18n.default_locale }

  describe 'GET /host/translation-management', :as_platform_manager do
    it 'renders the recovery namespace landing page' do
      get better_together.translation_management_path(locale:)

      expect(response).to have_http_status(:ok)
      expect_html_content('Translation Management')
      expect_html_content('Readonly recovery namespace')
      expect_html_content('Translation records by backend')
      expect_html_content('Locale coverage snapshot')
    end

    it 'assigns readonly overview statistics for the dashboard' do
      get better_together.translation_management_path(locale:)

      expect(assigns(:backend_stats).map { |stat| stat[:key] }).to eq(%i[string text rich_text file])
      expect(assigns(:backend_stats)).to all(include(:record_count, :model_count))
      expect(assigns(:locale_stats)).to all(be_an(Array))
      expect(assigns(:translatable_type_stats)).to all(be_an(Array))
    end
  end
end

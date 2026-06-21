# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonDataExportsController, :as_user do
  include Devise::Test::ControllerHelpers
  include BetterTogether::Engine.routes.url_helpers
  include AutomaticTestConfiguration

  routes { BetterTogether::Engine.routes }

  let(:locale) { I18n.default_locale }
  let(:user) { find_or_create_test_user('data-export-user@example.test', 'SecureTest123!@#', :user) }

  before { sign_in user }

  describe 'POST #create' do
    it 'creates a new export for the signed-in person' do
      expect do
        post :create, params: { locale: locale }
      end.to change(BetterTogether::PersonDataExport, :count).by(1)

      expect(response).to redirect_to(BetterTogether::Engine.routes.url_helpers.settings_my_data_path(locale: locale))
    end
  end

  describe 'GET #show' do
    let(:export) { create(:better_together_person_data_export, :completed, person: user.person) }

    before do
      export.export_file.attach(io: StringIO.new('{"ok":true}'), filename: 'export.json', content_type: 'application/json')
    end

    it 'downloads the current person export' do
      get :show, params: { locale: locale, id: export.id }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
    end
  end
end

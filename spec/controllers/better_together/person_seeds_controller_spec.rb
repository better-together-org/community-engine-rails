# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonSeedsController, :as_user do
  include Devise::Test::ControllerHelpers
  include BetterTogether::Engine.routes.url_helpers
  include AutomaticTestConfiguration

  routes { BetterTogether::Engine.routes }

  let(:locale) { I18n.default_locale }
  let(:user) { find_or_create_test_user('person-seed-user@example.test', 'SecureTest123!@#', :user) }

  before { sign_in user }

  describe 'GET #show' do
    let!(:seed) do
      BetterTogether::Seeds::Builder.call(
        subject: user.person,
        profile: :personal_export,
        persist: true,
        creator_id: user.person.id,
        context: {
          created_by: 'ControllerSpec',
          description: 'Controller spec personal export',
          payload: { sample: 'payload' }
        }
      ).seed_record
    end

    it 'loads the current person seed by slug param' do
      get :show, params: { locale: locale, id: seed.to_param }

      expect(response).to have_http_status(:ok)
      expect(assigns(:seed)).to eq(seed)
    end
  end
end

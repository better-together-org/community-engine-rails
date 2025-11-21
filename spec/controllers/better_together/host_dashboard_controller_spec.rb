# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::HostDashboardController, type: :controller do
  include Devise::Test::ControllerHelpers
  include BetterTogether::DeviseSessionHelpers

  routes { BetterTogether::Engine.routes }

  before do
    configure_host_platform
    @request.env['devise.mapping'] = Devise.mappings[:user]
  end

  describe 'GET #index' do
    context 'when user can manage platform' do
      let(:user) { BetterTogether::User.find_by(email: 'manager@example.test') }

      before { sign_in user }

      it 'returns http success' do
        get :index, params: { locale: I18n.default_locale }
        expect(response).to be_successful
      end
    end

    context 'when user cannot manage platform' do
      let(:user) { create(:user, :confirmed) }

      before { sign_in user }

      it 'raises Pundit::NotAuthorizedError' do
        expect do
          get :index, params: { locale: I18n.default_locale }
        end.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Users::RegistrationsController, :skip_host_setup do
  include Devise::Test::ControllerHelpers
  include BetterTogether::Engine.routes.url_helpers
  include AutomaticTestConfiguration

  render_views
  routes { BetterTogether::Engine.routes }

  let(:locale) { I18n.default_locale }
  let(:user) { create(:better_together_user, :confirmed) }

  before do
    configure_host_platform
    request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user
  end

  describe 'DELETE #destroy' do
    it 'creates a deletion request instead of deleting the user account' do
      starting_user_count = BetterTogether::User.count
      starting_request_count = user.person.person_deletion_requests.active.count

      delete :destroy, params: { locale: locale }

      expect(response).to redirect_to(BetterTogether::Engine.routes.url_helpers.edit_user_registration_path(locale: locale))
      expect(BetterTogether::User.count).to eq(starting_user_count)
      expect(user.reload).to be_present
      expect(user.person.person_deletion_requests.active.count).to eq(starting_request_count.zero? ? 1 : starting_request_count)
    end
  end

  describe 'GET #edit' do
    it 'shows the deletion request UI in account settings' do
      create(:better_together_person_deletion_request, person: user.person)

      get :edit, params: { locale: locale }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.deletion.title'))
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.deletion.submit'))
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.deletion.cancel'))
    end
  end
end

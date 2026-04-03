# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonDeletionRequestsController, :as_user do
  include Devise::Test::ControllerHelpers
  include BetterTogether::Engine.routes.url_helpers
  include AutomaticTestConfiguration

  routes { BetterTogether::Engine.routes }

  let(:locale) { I18n.default_locale }
  let(:user) { find_or_create_test_user('deletion-request-user@example.test', 'SecureTest123!@#', :user) }

  before { sign_in user }

  describe 'POST #create' do
    it 'creates a pending deletion request' do
      expect do
        post :create, params: { locale: locale, person_deletion_request: { requested_reason: 'Please remove my data.' } }
      end.to change(BetterTogether::PersonDeletionRequest, :count).by(1)

      expect(response).to redirect_to(BetterTogether::Engine.routes.url_helpers.edit_user_registration_path(locale: locale))
    end
  end

  describe 'DELETE #destroy' do
    it 'cancels the pending deletion request' do
      deletion_request = create(:better_together_person_deletion_request, person: user.person)

      delete :destroy, params: { locale: locale, id: deletion_request.id }
      deletion_request.reload

      expect(deletion_request).to be_cancelled
      expect(response).to redirect_to(BetterTogether::Engine.routes.url_helpers.edit_user_registration_path(locale: locale))
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

# Specs for personal OAuth application management at /settings/applications
# Regular users can CRUD their own OAuth apps; platform managers still have /host/oauth_applications
RSpec.describe 'Personal OAuth Applications (/settings/applications)' do
  let(:locale) { I18n.default_locale }
  let!(:regular_user) { BetterTogether::User.find_by(email: 'user@example.test') }
  let(:person) { regular_user.person }

  describe 'access by authenticated regular users', :as_user do
    describe 'GET /settings/applications (index)' do
      it 'returns 200' do
        get better_together.personal_oauth_applications_path(locale:)
        expect(response).to have_http_status(:ok)
      end

      context 'when the user has no apps' do
        it 'renders the empty index' do
          get better_together.personal_oauth_applications_path(locale:)
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when the user has an app' do
        let!(:oauth_app) do
          create(:better_together_oauth_application, name: 'Personal CLI', owner: person)
        end

        it 'shows the app name' do
          get better_together.personal_oauth_applications_path(locale:)
          expect_html_content('Personal CLI')
        end

        it 'does not show apps owned by other people' do
          other = create(:better_together_person)
          other_app = create(:better_together_oauth_application, name: 'Other App', owner: other)
          get better_together.personal_oauth_applications_path(locale:)
          expect(response.body).not_to include(other_app.name)
        end
      end
    end

    describe 'GET /settings/applications/new' do
      it 'renders the new app form' do
        get better_together.new_personal_oauth_application_path(locale:)
        expect(response).to have_http_status(:ok)
      end

      it 'includes required form fields' do
        get better_together.new_personal_oauth_application_path(locale:)
        expect(response.body).to include('oauth_application[name]')
        expect(response.body).to include('oauth_application[redirect_uri]')
      end
    end

    describe 'POST /settings/applications (create)' do
      let(:valid_params) do
        {
          oauth_application: {
            name: 'My New Bot',
            redirect_uri: 'https://example.com/callback',
            scopes: 'read'
          }
        }
      end

      it 'creates a new OAuth application' do
        expect do
          post better_together.personal_oauth_applications_path(locale:), params: valid_params
        end.to change(BetterTogether::OauthApplication, :count).by(1)
      end

      it 'assigns current person as owner' do
        post better_together.personal_oauth_applications_path(locale:), params: valid_params
        new_app = BetterTogether::OauthApplication.last
        expect(new_app.owner).to eq(person)
      end

      it 'redirects after successful creation' do
        post better_together.personal_oauth_applications_path(locale:), params: valid_params
        expect(response).to have_http_status(:found)
      end

      context 'with invalid params (missing name)' do
        it 'does not create an application' do
          expect do
            post better_together.personal_oauth_applications_path(locale:),
                 params: { oauth_application: { name: '', redirect_uri: '' } }
          end.not_to change(BetterTogether::OauthApplication, :count)
        end

        it 'returns unprocessable entity' do
          post better_together.personal_oauth_applications_path(locale:),
               params: { oauth_application: { name: '', redirect_uri: '' } }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    describe 'GET /settings/applications/:id (show)' do
      let!(:oauth_app) do
        create(:better_together_oauth_application, name: 'Show Me', owner: person)
      end

      it 'renders the app details' do
        get better_together.personal_oauth_application_path(locale:, id: oauth_app.id)
        expect(response).to have_http_status(:ok)
      end

      it 'displays the client UID' do
        get better_together.personal_oauth_application_path(locale:, id: oauth_app.id)
        expect_html_content(oauth_app.uid)
      end
    end

    describe 'GET /settings/applications/:id/edit' do
      let!(:oauth_app) do
        create(:better_together_oauth_application, name: 'Edit Me', owner: person)
      end

      it 'renders the edit form' do
        get better_together.edit_personal_oauth_application_path(locale:, id: oauth_app.id)
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'PATCH /settings/applications/:id (update)' do
      let!(:oauth_app) do
        create(:better_together_oauth_application, name: 'Old Name', owner: person)
      end

      it 'updates the app name' do
        patch better_together.personal_oauth_application_path(locale:, id: oauth_app.id),
              params: { oauth_application: { name: 'New Name' } }
        expect(oauth_app.reload.name).to eq('New Name')
      end

      it 'redirects after update' do
        patch better_together.personal_oauth_application_path(locale:, id: oauth_app.id),
              params: { oauth_application: { name: 'New Name' } }
        expect(response).to have_http_status(:found)
      end
    end

    describe 'DELETE /settings/applications/:id (destroy)' do
      let!(:oauth_app) do
        create(:better_together_oauth_application, name: 'Delete Me', owner: person)
      end

      it 'deletes the app' do
        expect do
          delete better_together.personal_oauth_application_path(locale:, id: oauth_app.id)
        end.to change(BetterTogether::OauthApplication, :count).by(-1)
      end

      it 'redirects after deletion' do
        delete better_together.personal_oauth_application_path(locale:, id: oauth_app.id)
        expect(response).to have_http_status(:found)
      end
    end

    describe 'ownership isolation' do
      let!(:other_person) { create(:better_together_person) }
      let!(:other_app) do
        create(:better_together_oauth_application, name: "Other's App", owner: other_person)
      end

      it 'cannot show another user\'s app (RecordNotFound from scoped collection)' do
        expect do
          get better_together.personal_oauth_application_path(locale:, id: other_app.id)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'cannot edit another user\'s app' do
        expect do
          get better_together.edit_personal_oauth_application_path(locale:, id: other_app.id)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'cannot delete another user\'s app' do
        expect do
          delete better_together.personal_oauth_application_path(locale:, id: other_app.id)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'access control for unauthenticated users', :unauthenticated do
    it 'blocks unauthenticated index' do
      get better_together.personal_oauth_applications_path(locale:)
      expect(response).to have_http_status(:not_found)
    end

    it 'blocks unauthenticated new form' do
      get better_together.new_personal_oauth_application_path(locale:)
      expect(response).to have_http_status(:not_found)
    end
  end
end

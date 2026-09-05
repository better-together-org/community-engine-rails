# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether self-service data requests', :as_user do
  let(:locale) { I18n.default_locale }
  let!(:user) { BetterTogether::User.find_by(email: 'user@example.test') }
  let(:person) { user.person }
  let(:other_user) { create(:better_together_user, :confirmed) }

  describe 'POST /person_data_exports' do
    it 'raises a routing error for unauthenticated users because the route is constrained' do
      logout

      expect do
        post better_together.person_data_exports_path(locale:)
      end.to raise_error(ActionController::RoutingError)
    end

    it 'creates a new export for the signed-in person' do
      expect do
        post better_together.person_data_exports_path(locale:)
      end.to change(BetterTogether::PersonDataExport, :count).by(1)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(better_together.settings_my_data_path(locale:))
      expect(BetterTogether::PersonDataExport.order(:created_at).last.person).to eq(person)
    end
  end

  describe 'GET /person_data_exports/:id' do
    let!(:export) { create(:better_together_person_data_export, :completed, person:) }

    before do
      export.export_file.attach(
        io: StringIO.new('{"ok":true}'),
        filename: 'export.json',
        content_type: 'application/json'
      )
    end

    it 'returns 404 for unauthenticated users' do
      logout

      get better_together.person_data_export_path(export, locale:)

      expect(response).to have_http_status(:not_found)
    end

    it 'downloads the current person export' do
      get better_together.person_data_export_path(export, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
    end

    it 'returns not found for another person export' do
      other_export = create(:better_together_person_data_export, :completed, person: other_user.person)
      other_export.export_file.attach(
        io: StringIO.new('{"other":true}'),
        filename: 'other-export.json',
        content_type: 'application/json'
      )

      get better_together.person_data_export_path(other_export, locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /person_deletion_requests' do
    it 'raises a routing error for unauthenticated users because the route is constrained' do
      logout

      expect do
        post better_together.person_deletion_requests_path(locale:),
             params: { person_deletion_request: { requested_reason: 'Please remove my data.' } }
      end.to raise_error(ActionController::RoutingError)
    end

    it 'creates a pending deletion request for the signed-in person' do
      expect do
        post better_together.person_deletion_requests_path(locale:),
             params: { person_deletion_request: { requested_reason: 'Please remove my data.' } }
      end.to change(BetterTogether::PersonDeletionRequest, :count).by(1)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(better_together.edit_user_registration_path(locale:))
      expect(BetterTogether::PersonDeletionRequest.order(:created_at).last.person).to eq(person)
    end
  end

  describe 'DELETE /person_deletion_requests/:id' do
    let!(:deletion_request) { create(:better_together_person_deletion_request, person:) }

    it 'raises a routing error for unauthenticated users because the route is constrained' do
      logout

      expect do
        delete better_together.person_deletion_request_path(deletion_request, locale:)
      end.to raise_error(ActionController::RoutingError)
    end

    it 'cancels the current person deletion request' do
      delete better_together.person_deletion_request_path(deletion_request, locale:)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(better_together.edit_user_registration_path(locale:))
      expect(deletion_request.reload).to be_cancelled
    end

    it 'returns not found for another person deletion request' do
      other_request = create(:better_together_person_deletion_request, person: other_user.person)

      delete better_together.person_deletion_request_path(other_request, locale:)

      expect(response).to have_http_status(:not_found)
      expect(other_request.reload).to be_pending
    end
  end
end

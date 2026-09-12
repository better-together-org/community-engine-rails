# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether settings data surfaces', :as_user do
  let(:locale) { I18n.default_locale }
  let!(:user) { BetterTogether::User.find_by(email: 'user@example.test') }
  let(:person) { user.person }

  describe 'GET /settings/my_data' do
    it 'returns 404 for unauthenticated users' do
      logout

      get better_together.settings_my_data_path(locale:)

      expect(response).to have_http_status(:not_found)
    end

    it 'renders the my data view for the signed-in user' do
      create(:better_together_person_data_export, :completed, person:)
      create(:better_together_seed, :personal_export, person:)

      get better_together.settings_my_data_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.exports.title'))
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.connections.title'))
      expect(response.body).to include(better_together.person_links_path(locale:))
      expect(response.body).to include(better_together.person_access_grants_path(locale:))
      expect(response.body).to include(better_together.person_linked_seeds_path(locale:))
    end
  end

  describe 'POST /settings/mark_integration_notifications_read' do
    it 'raises a routing error for unauthenticated users because the route is constrained' do
      logout

      expect do
        post better_together.mark_integration_notifications_read_path(locale:)
      end.to raise_error(ActionController::RoutingError)
    end

    it 'marks only older unread integration notifications as read' do
      stale_integration_notification = create(
        :noticed_notification,
        recipient: person,
        event: create(:noticed_event, type: 'BetterTogether::PersonPlatformIntegrationCreatedNotifier'),
        created_at: 1.hour.ago
      )
      recent_integration_notification = create(
        :noticed_notification,
        recipient: person,
        event: create(:noticed_event, type: 'BetterTogether::PersonPlatformIntegrationCreatedNotifier'),
        created_at: 2.seconds.ago
      )
      unrelated_notification = create(
        :noticed_notification,
        recipient: person,
        event: create(:noticed_event, type: 'BetterTogether::TestNotifier'),
        created_at: 1.hour.ago
      )

      post better_together.mark_integration_notifications_read_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true, 'marked_read' => 1)
      expect(stale_integration_notification.reload.read_at).to be_present
      expect(recent_integration_notification.reload.read_at).to be_nil
      expect(unrelated_notification.reload.read_at).to be_nil
    end
  end
end
